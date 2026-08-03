import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'acorde_client.dart';
import 'export_service.dart';
import 'file_service.dart';
import 'graph_service.dart';
import 'note_service.dart';
import 'vault_store.dart';

class RelixController extends ChangeNotifier {
  RelixController({
    AcordeClient? client,
    VaultStore? store,
  })  : _client = client ?? AcordeClient(),
        _vault = store ?? VaultStore() {
    _note = NoteService(_vault, _client);
    _graph = GraphService(_vault);
    _export = ExportService();
    _file = FileService(_client);
  }

  final AcordeClient _client;
  final VaultStore _vault;

  late final NoteService _note;
  late final GraphService _graph;
  late final ExportService _export;
  late final FileService _file;

  GraphService get graph => _graph;
  ExportService get export => _export;
  FileService get file => _file;
  NoteService get note => _note;
  VaultStore get vault => _vault;

  SyncSnapshot _snapshot = const SyncSnapshot();
  SyncSnapshot get snapshot => _snapshot;

  Timer? _pollTimer;
  bool _refreshing = false;
  bool _draining = false;
  Future<void> _queueWrite = Future.value();

  Future<void> initialize() async {
    final baseUrl = await _vault.readBaseUrl() ?? 'http://localhost:7331';
    final notes = await _vault.readAll();
    final peers = await _vault.readPeers();
    final stuck = await _vault.readStuckMutations();
    _client.setBaseUrl(baseUrl);
    _snapshot = _snapshot.copyWith(
      baseUrl: baseUrl,
      notes: notes,
      peers: peers,
      stuckMutations: stuck.length,
      initialized: true,
      errorMessage: null,
    );
    notifyListeners();

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh());
    });

    await refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim();
    _client.setBaseUrl(trimmed);
    await _vault.writeBaseUrl(trimmed);
    _snapshot = _snapshot.copyWith(baseUrl: trimmed, errorMessage: null);
    notifyListeners();
    await refresh();
  }

  Future<void> setVaultPath(String path) async {
    await _vault.setVaultPath(path);
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final healthy = await _client.healthCheck();

      // Always read from local vault (source of truth)
      final localNotes = await _vault.readAll();

      if (!healthy) {
        final queue = await _vault.readQueue();
        final stuck = await _vault.readStuckMutations();
        final needsUpdate = !_snapshot.daemonReachable ||
            _snapshot.pendingChanges != queue.length ||
            _snapshot.stuckMutations != stuck.length ||
            _snapshot.notes.length != localNotes.length;
        if (needsUpdate) {
          _snapshot = _snapshot.copyWith(
            daemonReachable: false,
            notes: localNotes,
            pendingChanges: queue.length,
            stuckMutations: stuck.length,
            errorMessage: null,
          );
          notifyListeners();
        }
        return;
      }

      // Daemon is reachable — sync bidirectional
      final results = await Future.wait<Object?>([
        _client
            .getIdentity()
            .then<Object?>((value) => value)
            .catchError((_) => null),
        _client.getPeers().catchError((_) => <RemotePeer>[]),
        _client.getStatus().catchError((_) => <String, dynamic>{}),
        _client.listEntries().then<Object?>((value) => value).catchError((_) => null),
      ]);

      final identity = results[0] as LocalIdentity?;
      final incomingPeers = results[1] as List<RemotePeer>;
      final status = results[2] as Map<String, dynamic>;
      final remoteNotes = results[3] as List<NoteEntry>?;

      // Merge remote ACORDE notes into local vault
      if (remoteNotes != null && remoteNotes.isNotEmpty) {
        for (final remote in remoteNotes) {
          if (remote.deleted) continue;
          // Only merge if remote is newer
          final local = await _vault.getNote(remote.id);
          if (local == null || remote.updatedAt > local.updatedAt) {
            await _vault.write(remote);
          }
        }
      }

      // Re-read merged vault state
      final mergedPeers = await _mergePeers(incomingPeers, status['last_sync'] as int?);

      // Drain mutation queue (push local changes to ACORDE)
      await _drainQueue();

      final pending = await _vault.readQueue();
      final settledNotes = await _vault.readAll();
      final finalStuck = await _vault.readStuckMutations();

      _snapshot = _snapshot.copyWith(
        identity: identity,
        peers: mergedPeers,
        notes: settledNotes,
        daemonReachable: true,
        pendingChanges: pending.length,
        stuckMutations: finalStuck.length,
        lastSyncAt: status['last_sync'] as int?,
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      // On error, still show local vault
      final localNotes = await _vault.readAll();
      _snapshot = _snapshot.copyWith(
        notes: localNotes,
        errorMessage: error.toString(),
      );
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> renamePeer(String peerId, String nickname) async {
    final peers = _snapshot.peers
        .map(
          (peer) => peer.id == peerId
              ? peer.copyWith(
                  nickname: nickname.trim().isEmpty ? null : nickname.trim(),
                )
              : peer,
        )
        .toList();
    await _vault.writePeers(peers);
    _snapshot = _snapshot.copyWith(peers: peers);
    notifyListeners();
  }

  Future<String> generateInvite() async {
    final invite = await _client.generateInvite();
    _snapshot = _snapshot.copyWith(inviteCode: invite, errorMessage: null);
    notifyListeners();
    return invite;
  }

  Future<void> pairDevice(String code) async {
    await _client.pairDevice(code);
    await refresh();
  }

  Future<void> clearStuckMutations() async {
    await _vault.clearStuckMutations();
    _snapshot = _snapshot.copyWith(stuckMutations: 0);
    notifyListeners();
  }

  Future<NoteEntry> createNote({
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    final note = await _note.create(title: title, body: body, tags: tags);

    // Update snapshot optimistically
    final notes = await _vault.readAll();
    _snapshot = _snapshot.copyWith(notes: notes);
    notifyListeners();

    unawaited(refresh());
    return note;
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    await _note.update(id: id, title: title, body: body, tags: tags);

    final notes = await _vault.readAll();
    _snapshot = _snapshot.copyWith(notes: notes);
    notifyListeners();

    unawaited(refresh());
  }

  Future<List<NoteEntry>> getBacklinks(String id) => _note.getBacklinks(id);

  Future<List<NoteEntry>> searchEntries(String query, {String? type}) =>
      _note.search(query, type: type);

  Future<List<NoteEntry>> listFiles() => _file.listFiles();

  Future<NoteEntry?> uploadFile() async {
    final created = await _file.pickAndUpload();
    if (created != null) {
      await refresh();
    }
    return created;
  }

  Future<void> shareFile(NoteEntry entry) async {
    if (entry.content is! FileContent) return;
    await _file.shareFile(entry.content as FileContent);
  }

  Future<void> deleteNote(String id) async {
    // Delete from local vault
    await _note.delete(id);

    // Queue for ACORDE deletion
    await _enqueueMutation(MutationPayload(type: 'delete', noteId: id));

    final notes = await _vault.readAll();
    _snapshot = _snapshot.copyWith(notes: notes);
    notifyListeners();

    unawaited(refresh());
  }

  Future<NoteEntry?> fetchLatestRemoteNote(String id) async {
    return _note.fetchFromAcorde(id);
  }

  Future<void> applyRemoteNote(NoteEntry remote) async {
    await _withQueueWriteLock(() async {
      final queue = await _vault.readQueue();
      final filteredQueue = queue
          .where((mutation) => mutation.noteId != remote.id)
          .toList();
      await _vault.writeQueue(filteredQueue);
    });

    await _note.mergeRemote(remote);

    final notes = await _vault.readAll();
    _snapshot = _snapshot.copyWith(
      notes: notes,
      pendingChanges: (await _vault.readQueue()).length,
      errorMessage: null,
    );
    notifyListeners();
  }

  Future<void> _enqueueMutation(MutationPayload mutation) async {
    await _withQueueWriteLock(() async {
      final queue = await _vault.readQueue();
      queue.add(mutation);
      await _vault.writeQueue(queue);
      _snapshot = _snapshot.copyWith(pendingChanges: queue.length);
    });
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      await _withQueueWriteLock(() async {
        final queue = await _vault.readQueue();
        if (queue.isEmpty) {
          _snapshot = _snapshot.copyWith(pendingChanges: 0);
          return;
        }

        final remaining = <MutationPayload>[];
        final stuck = await _vault.readStuckMutations();

        for (var index = 0; index < queue.length; index++) {
          final mutation = queue[index];
          try {
            if (mutation.type == 'create' || mutation.type == 'update') {
              // Push local note to ACORDE
              final note = await _vault.getNote(mutation.noteId);
              if (note != null && note.content is NoteContent) {
                final pushed = await _note.pushToAcorde(note);

                // If it was a create with a temp ID, update the local file with the real ACORDE ID
                if (mutation.type == 'create' && mutation.noteId.startsWith('local-')) {
                  // Delete old local file, write new one with real ID
                  await _vault.delete(mutation.noteId);
                  final normalized = pushed.copyWith(
                    baselineUpdatedAt: pushed.updatedAt,
                    pendingSync: false,
                  );
                  await _vault.write(normalized);

                  // Rewrite queued note IDs that referenced the temp ID
                  _rewriteQueuedNoteId(
                    queue,
                    oldId: mutation.noteId,
                    newId: pushed.id,
                    startIndex: index + 1,
                  );
                  _rewriteQueuedNoteId(
                    remaining,
                    oldId: mutation.noteId,
                    newId: pushed.id,
                  );
                } else {
                  // Update was successful, mark as synced
                  final synced = note.copyWith(pendingSync: false);
                  await _vault.write(synced);
                }
              }
            } else if (mutation.type == 'delete') {
              await _note.deleteOnAcorde(mutation.noteId);
            }
          } catch (_) {
            final retried = mutation.copyWith(
              retryCount: mutation.retryCount + 1,
            );
            if (retried.retryCount >= 5) {
              stuck.add(retried);
            } else {
              remaining.add(retried);
            }
          }
        }

        // Only update pending_sync flags for affected notes
        final pendingIds = remaining.map((m) => m.noteId).toSet();
        final notes = await _vault.readAll();
        final changedNotes = <NoteEntry>[];
        for (final note in notes) {
          if (pendingIds.contains(note.id) || note.pendingSync) {
            changedNotes.add(note.copyWith(pendingSync: pendingIds.contains(note.id)));
          }
        }

        // Write only changed notes back
        for (final n in changedNotes) {
          await _vault.write(n);
        }

        await _vault.writeQueue(remaining);
        await _vault.writeStuckMutations(stuck);

        _snapshot = _snapshot.copyWith(
          notes: notes,
          pendingChanges: remaining.length,
          stuckMutations: stuck.length,
        );
      });
    } finally {
      _draining = false;
    }
  }

  void _rewriteQueuedNoteId(
    List<MutationPayload> queue, {
    required String oldId,
    required String newId,
    int startIndex = 0,
  }) {
    for (var i = startIndex; i < queue.length; i++) {
      final item = queue[i];
      if (item.noteId == oldId) {
        queue[i] = item.copyWith(noteId: newId);
      }
    }
  }

  Future<List<RemotePeer>> _mergePeers(
    List<RemotePeer> incoming,
    int? lastSyncAt,
  ) async {
    final stored = await _vault.readPeers();
    final storedById = {for (final peer in stored) peer.id: peer};
    final merged = <RemotePeer>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final peer in incoming) {
      final previous = storedById[peer.id];
      merged.add(
        peer.copyWith(
          nickname: previous?.nickname,
          firstPairedAt: previous?.firstPairedAt ?? now,
          lastSeenAt: now,
          lastSyncAt: lastSyncAt ?? previous?.lastSyncAt,
        ),
      );
    }

    for (final storedPeer in stored) {
      if (merged.any((peer) => peer.id == storedPeer.id)) continue;
      merged.add(storedPeer);
    }

    await _vault.writePeers(merged);
    return merged;
  }

  Future<void> _withQueueWriteLock(Future<void> Function() operation) {
    final next = _queueWrite.then((_) => operation());
    _queueWrite = next.catchError((_) {});
    return next;
  }
}
