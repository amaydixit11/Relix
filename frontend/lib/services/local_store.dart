import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalStore {
  static const _baseUrlKey = 'relix.base_url';
  static const _notesKey = 'relix.cached_notes';
  static const _queueKey = 'relix.mutation_queue';
  static const _stuckKey = 'relix.stuck_mutations';
  static const _peersKey = 'relix.peers_meta';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> readBaseUrl() async => (await _prefs).getString(_baseUrlKey);

  Future<void> writeBaseUrl(String value) async =>
      (await _prefs).setString(_baseUrlKey, value);

  Future<List<NoteEntry>> readNotes() async {
    final raw = (await _prefs).getString(_notesKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return decoded.map(NoteEntry.fromJson).toList();
  }

  Future<void> writeNotes(List<NoteEntry> notes) async {
    await (await _prefs).setString(
      _notesKey,
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
  }

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

  Future<void> writeStuckMutations(List<MutationPayload> queue) async {
    await (await _prefs).setString(
      _stuckKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearStuckMutations() async => (await _prefs).remove(_stuckKey);

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
}
