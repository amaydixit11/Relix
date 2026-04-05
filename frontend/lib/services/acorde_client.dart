import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';

class AcordeClient {
  AcordeClient({String baseUrl = 'http://localhost:7331'}) : _baseUrl = baseUrl;

  String _baseUrl;

  final Map<String, bool> _capabilities = {};

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    _baseUrl = value;
    _capabilities.clear();
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/status'));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) {
        _capabilities['status'] = true;
        // Assume basic routes if status is ok
        _capabilities['entries'] = true;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasCapability(String route) async {
    if (_capabilities.containsKey(route)) return _capabilities[route]!;

    try {
      // Standard probe: OPTIONS if supported, or just a safe GET/HEAD
      final response = await http.get(Uri.parse('$_baseUrl/$route'));
      // 404 means not supported, other codes (even 401/400) suggest route exists
      final supported = response.statusCode != 404;
      _capabilities[route] = supported;
      return supported;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> getCapabilities() async {
    const routes = [
      'identity',
      'peers',
      'invite',
      'pair',
      'search',
      'blobs',
      'events',
    ];
    for (final route in routes) {
      await hasCapability(route);
    }
    return Map.unmodifiable(_capabilities);
  }

  Future<void> _requireCapability(String route, String message) async {
    if (await hasCapability(route)) return;
    throw UnsupportedError(message);
  }

  Future<LocalIdentity> getIdentity() async {
    await _requireCapability(
      'identity',
      'This ACORDE runtime does not expose /identity.',
    );
    final response = await http.get(Uri.parse('$_baseUrl/identity'));
    _ensureOk(response, 'Failed to get identity');
    return LocalIdentity.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<RemotePeer>> getPeers() async {
    await _requireCapability(
      'peers',
      'This ACORDE runtime does not expose /peers.',
    );
    final response = await http.get(Uri.parse('$_baseUrl/peers'));
    _ensureOk(response, 'Failed to get peers');
    final data = (jsonDecode(response.body) as List)
        .cast<Map<String, dynamic>>();
    return data
        .map(
          (item) => RemotePeer(
            id: (item['id'] ?? item['peer_id'] ?? '') as String,
            displayName:
                (item['display_name'] ?? item['peer_id'] ?? item['id'] ?? '')
                    as String,
            connectionType: item['connection_type'] as String?,
            isConnected: (item['is_connected'] ?? true) as bool,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> getStatus() async {
    final response = await http.get(Uri.parse('$_baseUrl/status'));
    _ensureOk(response, 'Failed to get status');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<NoteEntry>> listEntries({
    String? type,
    String? tag,
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (limit != null) params['limit'] = '$limit';
    if (offset != null) params['offset'] = '$offset';
    final uri = Uri.parse('$_baseUrl/entries').replace(queryParameters: params);
    final response = await http.get(uri);
    _ensureOk(response, 'Failed to list entries');
    final data = (jsonDecode(response.body) as List).cast<dynamic>();
    return data
        .map((item) => _decodeEntry(item as Map<String, dynamic>))
        .where((note) => !note.deleted)
        .toList();
  }

  Future<List<NoteEntry>> listNotes() async => listEntries(type: 'note');

  Future<NoteEntry> getNote(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/entries/$id'));
    _ensureOk(response, 'Failed to fetch note');
    return _decodeEntry(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NoteEntry> createEntry({
    required String type,
    required Object content,
    required List<String> tags,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/entries'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'content': jsonEncode(content),
        'tags': tags,
      }),
    );
    _ensureOk(response, 'Failed to create entry');
    return _decodeEntry(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NoteEntry> createNote({
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    return createEntry(
      type: 'note',
      content: {'title': title, 'body': body},
      tags: tags,
    );
  }

  Future<NoteEntry> updateNote({
    required String id,
    required String title,
    required String body,
    List<String>? tags,
  }) async {
    final payload = <String, dynamic>{
      'content': jsonEncode({'title': title, 'body': body}),
    };
    if (tags != null) {
      payload['tags'] = tags;
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/entries/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _ensureOk(response, 'Failed to update note');
    if (response.body.trim().isEmpty) return getNote(id);
    return _decodeEntry(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteNote(String id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/entries/$id'));
    _ensureOk(response, 'Failed to delete note');
  }

  Future<String> generateInvite() async {
    await _requireCapability(
      'invite',
      'This ACORDE runtime does not expose /invite.',
    );
    final response = await http.post(Uri.parse('$_baseUrl/invite'));
    _ensureOk(response, 'Failed to generate invite');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['code'] ?? '') as String;
  }

  Future<void> pairDevice(String code) async {
    await _requireCapability(
      'pair',
      'This ACORDE runtime does not expose /pair.',
    );
    final response = await http.post(
      Uri.parse('$_baseUrl/pair'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    _ensureOk(response, 'Failed to pair device');
  }

  Future<String> uploadBlob(Uint8List bytes) async {
    await _requireCapability(
      'blobs',
      'This ACORDE runtime does not expose /blobs.',
    );
    final response = await http.post(Uri.parse('$_baseUrl/blobs'), body: bytes);
    _ensureOk(response, 'Failed to upload blob');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['cid'] ?? '') as String;
  }

  Future<Uint8List> getBlob(String cid) async {
    await _requireCapability(
      'blobs',
      'This ACORDE runtime does not expose /blobs.',
    );
    final response = await http.get(Uri.parse('$_baseUrl/blobs/$cid'));
    _ensureOk(response, 'Failed to download blob');
    return response.bodyBytes;
  }

  Future<List<NoteEntry>> searchEntries(String query, {String? type}) async {
    if (!await hasCapability('search')) {
      final entries = await listEntries(type: type);
      final lower = query.trim().toLowerCase();
      if (lower.isEmpty) return entries;
      return entries.where((entry) {
        final haystack = _searchText(entry).toLowerCase();
        return haystack.contains(lower);
      }).toList();
    }
    final params = {'q': query};
    if (type != null) params['type'] = type;
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: params);
    final response = await http.get(uri);
    _ensureOk(response, 'Search failed');
    final data = (jsonDecode(response.body) as List).cast<dynamic>();
    return data
        .map((item) => _decodeEntry(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> authorizeWriter(String entryId, String peerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/entries/$entryId/authorize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'peer_id': peerId}),
    );
    _ensureOk(response, 'Failed to authorize writer');
  }

  static void _ensureOk(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      '$fallback (${response.statusCode} ${response.reasonPhrase ?? ''})',
    );
  }

  NoteEntry _decodeEntry(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['Type'] ?? 'note') as String;
    final rawContent = data['content'] ?? data['Content'];
    return NoteEntry(
      id: (data['id'] ?? data['ID'] ?? '') as String,
      type: type,
      content: _decodeContent(type, rawContent),
      tags: ((data['tags'] ?? data['Tags'] ?? const []) as List).cast<String>(),
      createdAt: (data['created_at'] ?? data['CreatedAt'] ?? 0) as int,
      updatedAt: (data['updated_at'] ?? data['UpdatedAt'] ?? 0) as int,
      baselineUpdatedAt: (data['updated_at'] ?? data['UpdatedAt'] ?? 0) as int,
      deleted: (data['deleted'] ?? data['Deleted'] ?? false) as bool,
      owner: (data['owner'] ?? data['Owner'] ?? '') as String,
    );
  }

  dynamic _decodeContent(String type, dynamic rawContent) {
    Map<String, dynamic>? parsed;
    if (rawContent is Map<String, dynamic>) {
      parsed = rawContent;
    } else if (rawContent is String) {
      try {
        final bytes = base64Decode(rawContent);
        final decoded = utf8.decode(Uint8List.fromList(bytes));
        parsed = jsonDecode(decoded) as Map<String, dynamic>;
      } catch (_) {
        try {
          parsed = jsonDecode(rawContent) as Map<String, dynamic>;
        } catch (_) {
          parsed = null;
        }
      }
    }

    if (parsed == null) {
      if (type == 'note') {
        return NoteContent(
          title: 'Untitled',
          body: rawContent is String ? rawContent : '',
        );
      }
      return {'raw': rawContent};
    }

    switch (type) {
      case 'log':
        return LogContent.fromJson(parsed);
      case 'file':
        return FileContent.fromJson(parsed);
      case 'link':
        return LinkContent.fromJson(parsed);
      case 'note':
      default:
        return NoteContent.fromJson(parsed);
    }
  }

  String _searchText(NoteEntry entry) {
    final content = entry.content;
    final fields = <String>[entry.id, entry.type, ...entry.tags];
    if (content is NoteContent) {
      fields.addAll([content.title, content.body]);
    } else if (content is FileContent) {
      fields.addAll([content.name, content.cid, content.mimeType]);
    } else if (content is LogContent) {
      fields.addAll([content.date, content.body]);
    } else if (content is LinkContent) {
      fields.addAll([content.url, content.title, content.excerpt ?? '']);
    }
    return fields.join(' ');
  }
}
