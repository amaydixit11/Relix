import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'acorde_client.dart';
import 'export_service.dart';
import 'file_service.dart';
import 'graph_service.dart';
import 'local_store.dart';
import 'note_service.dart';

class RelixController extends ChangeNotifier {
  RelixController({AcordeClient? client, LocalStore? store})
    : _client = client ?? AcordeClient(),
      _store = store ?? LocalStore() {
    _graph = GraphService(_client);
    _export = ExportService();
    _file = FileService(_client);
    _note = NoteService(_client);
  }

  final AcordeClient _client;
  final LocalStore _store;
  final Random _random = Random();

  late final GraphService _graph;
  late final ExportService _export;
  late final FileService _file;
  late final NoteService _note;

  GraphService get graph => _graph;
  ExportService get export => _export;
  FileService get file => _file;
  NoteService get note => _note;

  SyncSnapshot _snapshot = const SyncSnapshot();
  SyncSnapshot get snapshot => _snapshot;

  Timer? _pollTimer;
  bool _refreshing = false;
  bool _draining = false;
  Future<void> _queueWrite = Future.value();

  Future<void> initialize() async {
    final baseUrl = await _store.readBaseUrl() ?? 'http://localhost:7331';
    final notes = await _store.readNotes();
    final peers = await _store.readPeers();
    final stuck = await _store.readStuckMutations();
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
    await _store.writeBaseUrl(trimmed);
    _snapshot = _snapshot.copyWith(baseUrl: trimmed, errorMessage: null);
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final healthy = await _client.healthCheck();
      if (!healthy) {
        final queue = await _store.readQueue();
        final stuck = await _store.readStuckMutations();
        _snapshot = _snapshot.copyWith(
          daemonReachable: false,
          pendingChanges: queue.length,
          stuckMutations: stuck.length,
          errorMessage: null,
        );
        notifyListeners();
        return;
      }

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

      final mergedPeers = await _mergePeers(
        incomingPeers,
        status['last_sync'] as int?,
      );
      final queue = await _store.readQueue();
      final cachedNotes = await _store.readNotes();
      final mergedNotes = _mergeRemoteNotes(remoteNotes ?? cachedNotes, queue);
      await _store.writeNotes(mergedNotes);
      await _drainQueue();
      final stuck = await _store.readStuckMutations();
      final pending = await _store.readQueue();
      final settledNotes = await _store.readNotes();

      _snapshot = _snapshot.copyWith(
        identity: identity,
        peers: mergedPeers,
        notes: settledNotes,
        daemonReachable: true,
        pendingChanges: pending.length,
        stuckMutations: stuck.length,
        lastSyncAt: status['last_sync'] as int?,
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      _snapshot = _snapshot.copyWith(errorMessage: error.toString());
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
    await _store.writePeers(peers);
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
    await _store.clearStuckMutations();
    _snapshot = _snapshot.copyWith(stuckMutations: 0);
    notifyListeners();
  }

  Future<NoteEntry> createNote({
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    final createdAt = _unixNow();
    final tempId = 'local-$createdAt-${_random.nextInt(100000)}';

    // We can't resolve IDs offline easily without a full cache,
    // but we can add the outlink tags if they look like IDs or we just wait for the daemon.

    final optimistic = NoteEntry(
      id: tempId,
      type: 'note',
      content: NoteContent(title: title, body: body),
      tags: tags,
      createdAt: createdAt,
      updatedAt: createdAt,
      deleted: false,
      owner: '',
      pendingSync: true,
    );

    final notes = [optimistic, ..._snapshot.notes];
    await _store.writeNotes(notes);
    await _enqueueMutation(
      MutationPayload(
        type: 'create',
        noteId: tempId,
        title: title,
        body: body,
        tags: tags,
        createdAt: createdAt,
      ),
    );
    _snapshot = _snapshot.copyWith(notes: notes);
    notifyListeners();
    unawaited(refresh());
    return optimistic;
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String body,
    required List<String> tags,
  }) async {
    final notes = _snapshot.notes
        .map(
          (note) => note.id == id
              ? note.copyWith(
                  content: NoteContent(title: title, body: body),
                  tags: tags,
                  updatedAt: _unixNow(),
                  baselineUpdatedAt:
                      note.baselineUpdatedAt ?? note.updatedAt,
                  pendingSync: true,
                )
              : note,
        )
        .toList();
    await _store.writeNotes(notes);
    await _enqueueMutation(
      MutationPayload(
        type: 'update',
        noteId: id,
        title: title,
        body: body,
        tags: tags,
      ),
    );
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
    final notes = _snapshot.notes.where((note) => note.id != id).toList();
    await _store.writeNotes(notes);
    await _enqueueMutation(MutationPayload(type: 'delete', noteId: id));
    _snapshot = _snapshot.copyWith(notes: notes);
    notifyListeners();
    unawaited(refresh());
  }

  Future<NoteEntry?> fetchLatestRemoteNote(String id) async {
    try {
      final latest = await _client.getNote(id);
      return latest.copyWith(baselineUpdatedAt: latest.updatedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> applyRemoteNote(NoteEntry remote) async {
    await _withQueueWriteLock(() async {
      final queue = await _store.readQueue();
      final filteredQueue = queue
          .where((mutation) => mutation.noteId != remote.id)
          .toList();
      await _store.writeQueue(filteredQueue);
    });

    final notes = _snapshot.notes
        .map(
          (note) => note.id == remote.id
              ? remote.copyWith(
                  pendingSync: false,
                  baselineUpdatedAt: remote.updatedAt,
                )
              : note,
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    await _store.writeNotes(notes);
    _snapshot = _snapshot.copyWith(
      notes: notes,
      pendingChanges: (await _store.readQueue()).length,
      errorMessage: null,
    );
    notifyListeners();
  }

  Future<void> _enqueueMutation(MutationPayload mutation) async {
    await _withQueueWriteLock(() async {
      final queue = await _store.readQueue();
      queue.add(mutation);
      await _store.writeQueue(queue);
      _snapshot = _snapshot.copyWith(pendingChanges: queue.length);
    });
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      await _withQueueWriteLock(() async {
        final queue = await _store.readQueue();
        if (queue.isEmpty) {
          _snapshot = _snapshot.copyWith(pendingChanges: 0);
          return;
        }

        final remaining = <MutationPayload>[];
        final stuck = await _store.readStuckMutations();
        var notes = await _store.readNotes();

        for (var index = 0; index < queue.length; index++) {
          final mutation = queue[index];
          try {
            if (mutation.type == 'create') {
              final created = await _note.create(
                mutation.title ?? 'Untitled',
                mutation.body ?? '',
                tags: mutation.tags,
              );
              final normalized = created.copyWith(
                baselineUpdatedAt: created.updatedAt,
              );
              notes = notes
                  .map((note) => note.id == mutation.noteId ? normalized : note)
                  .toList();
              _rewriteQueuedNoteId(
                queue,
                oldId: mutation.noteId,
                newId: created.id,
                startIndex: index + 1,
              );
              _rewriteQueuedNoteId(
                remaining,
                oldId: mutation.noteId,
                newId: created.id,
              );
            } else if (mutation.type == 'update') {
              final updated = await _note.update(
                mutation.noteId,
                title: mutation.title,
                body: mutation.body,
                tags: mutation.tags,
              );
              final normalized = updated.copyWith(
                baselineUpdatedAt: updated.updatedAt,
              );
              notes = notes
                  .map((note) => note.id == mutation.noteId ? normalized : note)
                  .toList();
            } else if (mutation.type == 'delete') {
              await _client.deleteNote(mutation.noteId);
              notes = notes.where((note) => note.id != mutation.noteId).toList();
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

        notes = notes.map((note) {
          final pending = remaining.any((mutation) => mutation.noteId == note.id);
          return note.copyWith(pendingSync: pending);
        }).toList();

        await _store.writeQueue(remaining);
        await _store.writeStuckMutations(stuck);
        await _store.writeNotes(notes);
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

  List<NoteEntry> _mergeRemoteNotes(
    List<NoteEntry> remoteNotes,
    List<MutationPayload> queue,
  ) {
    final remoteById = {for (final note in remoteNotes) note.id: note};

    for (final mutation in queue) {
      if (mutation.type == 'create') {
        remoteById[mutation.noteId] = NoteEntry(
          id: mutation.noteId,
          type: 'note',
          content: NoteContent(
            title: mutation.title ?? 'Untitled',
            body: mutation.body ?? '',
          ),
          tags: mutation.tags,
          createdAt: mutation.createdAt ?? _unixNow(),
          updatedAt: mutation.createdAt ?? _unixNow(),
          baselineUpdatedAt: null,
          deleted: false,
          owner: '',
          pendingSync: true,
        );
      } else if (mutation.type == 'update') {
        final existing = remoteById[mutation.noteId];
        if (existing != null && existing.content is NoteContent) {
          remoteById[mutation.noteId] = existing.copyWith(
            content: NoteContent(
              title: mutation.title ?? (existing.content as NoteContent).title,
              body: mutation.body ?? (existing.content as NoteContent).body,
            ),
            tags: mutation.tags,
            baselineUpdatedAt: existing.baselineUpdatedAt ?? existing.updatedAt,
            pendingSync: true,
          );
        }
      } else if (mutation.type == 'delete') {
        remoteById.remove(mutation.noteId);
      }
    }

    final notes = remoteById.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<void> _withQueueWriteLock(Future<void> Function() operation) {
    final next = _queueWrite.then((_) => operation());
    _queueWrite = next.catchError((_) {});
    return next;
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
    final stored = await _store.readPeers();
    final storedById = {for (final peer in stored) peer.id: peer};
    final merged = <RemotePeer>[];
    final now = _unixNow();

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

    await _store.writePeers(merged);
    return merged;
  }

  int _unixNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
