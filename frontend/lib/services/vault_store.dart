import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Manages a local vault of `.md` files with YAML frontmatter.
///
/// Each note is stored as `<vault>/<slug>-<id>.md` with frontmatter:
/// ```yaml
/// ---
/// id: <uuid or local-temp-id>
/// type: note
/// tags: [tag1, tag2]
/// created_at: 1700000000
/// updated_at: 1700000001
/// baseline_updated_at: 1700000001
/// owner: ''
/// pending_sync: false
/// acorde_entry_id: <real ACORDE id, if synced>
/// ---
/// # Title
///
/// body markdown content...
/// ```
class VaultStore {
  static const _vaultPathKey = 'relix.vault_path';
  static const _queueKey = 'relix.mutation_queue';
  static const _stuckKey = 'relix.stuck_mutations';
  static const _peersKey = 'relix.peers_meta';
  static const _onboardingKey = 'relix.onboarding_complete';
  static const _baseUrlKey = 'relix.base_url';

  Directory? _cachedVaultDir;

  Future<Directory> get vaultDir async {
    if (_cachedVaultDir != null) return _cachedVaultDir!;
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_vaultPathKey);
    if (customPath != null && customPath.isNotEmpty) {
      _cachedVaultDir = Directory(customPath);
      if (!await _cachedVaultDir!.exists()) {
        await _cachedVaultDir!.create(recursive: true);
      }
      return _cachedVaultDir!;
    }
    // Default: application documents directory / relix_vault
    // On web, path_provider returns browser storage — fall back to temp
    if (kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      _cachedVaultDir = Directory('${tempDir.path}/relix_vault');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _cachedVaultDir = Directory('${appDir.path}/relix_vault');
    }
    if (!await _cachedVaultDir!.exists()) {
      await _cachedVaultDir!.create(recursive: true);
    }
    return _cachedVaultDir!;
  }

  Future<void> setVaultPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vaultPathKey, path);
    _cachedVaultDir = Directory(path);
    if (!await _cachedVaultDir!.exists()) {
      await _cachedVaultDir!.create(recursive: true);
    }
  }

  // ── Note CRUD ──────────────────────────────────────────────────

  /// Read all notes from the vault.
  Future<List<NoteEntry>> readAll() async {
    final dir = await vaultDir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    final notes = <NoteEntry>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final entry = _parseMarkdownFile(content);
        if (entry != null) notes.add(entry);
      } catch (_) {
        // Skip malformed files
      }
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Write a note as a `.md` file.
  Future<void> write(NoteEntry note) async {
    final dir = await vaultDir;
    final slug = _slugify(note.content is NoteContent
        ? (note.content as NoteContent).title
        : 'untitled');
    final fileName = '${slug.isEmpty ? 'note' : slug}-${note.id}.md';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(_toMarkdownFile(note));
  }

  /// Delete a note file.
  Future<void> delete(String noteId) async {
    final dir = await vaultDir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md') && f.path.contains(noteId))
        .toList();
    for (final file in files) {
      await file.delete();
    }
  }

  /// Get a single note by ID.
  Future<NoteEntry?> getNote(String id) async {
    final notes = await readAll();
    return notes.where((n) => n.id == id).firstOrNull;
  }

  // ── Mutation Queue (SharedPreferences) ─────────────────────────

  Future<List<MutationPayload>> readQueue() async {
    final raw = (await _prefs).getString(_queueKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return decoded.map(MutationPayload.fromJson).toList();
  }

  Future<void> writeQueue(List<MutationPayload> queue) async {
    await (await _prefs).setString(
      _queueKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<MutationPayload>> readStuckMutations() async {
    final raw = (await _prefs).getString(_stuckKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return decoded.map(MutationPayload.fromJson).toList();
  }

  Future<void> writeStuckMutations(List<MutationPayload> stuck) async {
    await (await _prefs).setString(
      _stuckKey,
      jsonEncode(stuck.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearStuckMutations() async => (await _prefs).remove(_stuckKey);

  // ── Peer Metadata ──────────────────────────────────────────────

  Future<List<RemotePeer>> readPeers() async {
    final raw = (await _prefs).getString(_peersKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return decoded.map(RemotePeer.fromJson).toList();
  }

  Future<void> writePeers(List<RemotePeer> peers) async {
    await (await _prefs).setString(
      _peersKey,
      jsonEncode(peers.map((peer) => peer.toJson()).toList()),
    );
  }

  // ── Settings ───────────────────────────────────────────────────

  Future<String?> readBaseUrl() async =>
      (await _prefs).getString(_baseUrlKey);

  Future<void> writeBaseUrl(String value) async =>
      (await _prefs).setString(_baseUrlKey, value);

  Future<bool> readOnboardingComplete() async =>
      (await _prefs).getBool(_onboardingKey) ?? false;

  Future<void> writeOnboardingComplete(bool value) async =>
      (await _prefs).setBool(_onboardingKey, value);

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // ── Markdown File Parsing ──────────────────────────────────────

  static const _frontmatterDelimiter = '---';

  NoteEntry? _parseMarkdownFile(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith(_frontmatterDelimiter)) return null;

    final secondDelimiter = trimmed.indexOf(
      _frontmatterDelimiter,
      _frontmatterDelimiter.length,
    );
    if (secondDelimiter < 0) return null;

    final frontmatterRaw = trimmed.substring(
      _frontmatterDelimiter.length,
      secondDelimiter,
    );
    final body = trimmed.substring(secondDelimiter + _frontmatterDelimiter.length).trim();

    // Simple YAML-like parsing (no external dependency)
    final frontmatter = _parseFrontmatter(frontmatterRaw);

    final id = frontmatter['id'] as String?;
    if (id == null || id.isEmpty) return null;

    final type = (frontmatter['type'] as String?) ?? 'note';
    final tags = (frontmatter['tags'] as List?)?.cast<String>() ?? [];
    final createdAt = (frontmatter['created_at'] as num?)?.toInt() ?? 0;
    final updatedAt = (frontmatter['updated_at'] as num?)?.toInt() ?? 0;
    final baselineUpdatedAt =
        (frontmatter['baseline_updated_at'] as num?)?.toInt();
    final owner = (frontmatter['owner'] as String?) ?? '';
    final pendingSync =
        (frontmatter['pending_sync'] as bool?) ?? false;

    // Body starts with title as heading
    String title = 'Untitled';
    String noteBody = body;
    if (body.startsWith('# ')) {
      final firstLineEnd = body.indexOf('\n');
      if (firstLineEnd > 0) {
        title = body.substring(2, firstLineEnd).trim();
        noteBody = body.substring(firstLineEnd).trim();
      }
    }

    return NoteEntry(
      id: id,
      type: type,
      content: NoteContent(title: title, body: noteBody),
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      baselineUpdatedAt: baselineUpdatedAt,
      deleted: false,
      owner: owner,
      pendingSync: pendingSync,
    );
  }

  Map<String, dynamic> _parseFrontmatter(String raw) {
    final result = <String, dynamic>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex < 0) continue;
      final key = trimmed.substring(0, colonIndex).trim();
      final valueStr = trimmed.substring(colonIndex + 1).trim();

      result[key] = _parseYamlValue(valueStr);
    }
    return result;
  }

  dynamic _parseYamlValue(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    if (value == '' || value == 'null') return null;

    // Integer
    final intVal = int.tryParse(value);
    if (intVal != null) return intVal;

    // Double
    final doubleVal = double.tryParse(value);
    if (doubleVal != null) return doubleVal;

    // Array: [a, b, c]
    if (value.startsWith('[') && value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      if (inner.trim().isEmpty) return <String>[];
      return inner
          .split(',')
          .map((e) {
            final trimmed = e.trim();
            // Strip quotes
            if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
                (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
              return trimmed.substring(1, trimmed.length - 1);
            }
            return trimmed;
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // String (strip quotes)
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }

  String _toMarkdownFile(NoteEntry note) {
    final noteContent = note.content is NoteContent
        ? note.content as NoteContent
        : NoteContent(title: 'Untitled', body: '');

    final tags = note.tags
        .where((t) => !t.startsWith('outlink:') && !t.startsWith('backlink:'))
        .toList();

    final frontmatter = [
      _frontmatterDelimiter,
      'id: ${note.id}',
      'type: ${note.type}',
      if (tags.isNotEmpty)
        'tags: [${tags.map((t) => '"$t"').join(', ')}]'
      else
        'tags: []',
      'created_at: ${note.createdAt}',
      'updated_at: ${note.updatedAt}',
      if (note.baselineUpdatedAt != null)
        'baseline_updated_at: ${note.baselineUpdatedAt}',
      'owner: ${note.owner.isEmpty ? "''" : note.owner}',
      'pending_sync: ${note.pendingSync}',
      _frontmatterDelimiter,
    ].join('\n');

    return '$frontmatter\n\n# ${noteContent.title}\n\n${noteContent.body}\n';
  }

  String _slugify(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .substring(0, title.length > 40 ? 40 : title.length)
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
