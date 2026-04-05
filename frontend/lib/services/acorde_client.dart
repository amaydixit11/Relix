import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';

class AcordeClient {
  AcordeClient({String baseUrl = 'http://localhost:7331'}) : _baseUrl = baseUrl;

  String _baseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    _baseUrl = value;
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/status'));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<LocalIdentity> getIdentity() async {
    final response = await http.get(Uri.parse('$_baseUrl/identity'));
    _ensureOk(response, 'Failed to get identity');
    return LocalIdentity.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<RemotePeer>> getPeers() async {
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

  Future<List<NoteEntry>> listNotes() async {
    final response = await http.get(Uri.parse('$_baseUrl/entries?type=note'));
    _ensureOk(response, 'Failed to list notes');
    final data = (jsonDecode(response.body) as List).cast<dynamic>();
    return data
        .map((item) => _decodeEntry(item as Map<String, dynamic>))
        .where((note) => !note.deleted)
        .toList();
  }

  Future<NoteEntry> getNote(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/entries/$id'));
    _ensureOk(response, 'Failed to fetch note');
    return _decodeEntry(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NoteEntry> createNote({
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/entries'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'note',
        'content': jsonEncode({'title': title, 'body': body}),
        'tags': tags,
      }),
    );
    _ensureOk(response, 'Failed to create note');
    return _decodeEntry(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NoteEntry> updateNote({
    required String id,
    required String title,
    required String body,
    List<String>? tags,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/entries/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': jsonEncode({'title': title, 'body': body}),
        if (tags != null) 'tags': tags,
      }),
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
    final response = await http.post(Uri.parse('$_baseUrl/invite'));
    _ensureOk(response, 'Failed to generate invite');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['code'] ?? '') as String;
  }

  Future<void> pairDevice(String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/pair'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    _ensureOk(response, 'Failed to pair device');
  }

  Future<String> uploadBlob(Uint8List bytes) async {
    final response = await http.post(Uri.parse('$_baseUrl/blobs'), body: bytes);
    _ensureOk(response, 'Failed to upload blob');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['cid'] ?? '') as String;
  }

  Future<Uint8List> getBlob(String cid) async {
    final response = await http.get(Uri.parse('$_baseUrl/blobs/$cid'));
    _ensureOk(response, 'Failed to download blob');
    return response.bodyBytes;
  }

  Future<List<NoteEntry>> searchEntries(String query, {String? type}) async {
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
    final rawContent = data['content'] ?? data['Content'];
    return NoteEntry(
      id: (data['id'] ?? data['ID'] ?? '') as String,
      type: (data['type'] ?? data['Type'] ?? 'note') as String,
      content: _decodeContent(rawContent),
      tags: ((data['tags'] ?? data['Tags'] ?? const []) as List).cast<String>(),
      createdAt: (data['created_at'] ?? data['CreatedAt'] ?? 0) as int,
      updatedAt: (data['updated_at'] ?? data['UpdatedAt'] ?? 0) as int,
      deleted: (data['deleted'] ?? data['Deleted'] ?? false) as bool,
      owner: (data['owner'] ?? data['Owner'] ?? '') as String,
    );
  }

  NoteContent _decodeContent(dynamic rawContent) {
    if (rawContent is Map<String, dynamic>) {
      return NoteContent.fromJson(rawContent);
    }

    if (rawContent is String) {
      try {
        final bytes = base64Decode(rawContent);
        final decoded = utf8.decode(Uint8List.fromList(bytes));
        return NoteContent.fromJson(
          jsonDecode(decoded) as Map<String, dynamic>,
        );
      } catch (_) {
        try {
          return NoteContent.fromJson(
            jsonDecode(rawContent) as Map<String, dynamic>,
          );
        } catch (_) {
          return NoteContent(title: 'Untitled', body: rawContent);
        }
      }
    }

    return const NoteContent(title: 'Untitled', body: '');
  }
}
