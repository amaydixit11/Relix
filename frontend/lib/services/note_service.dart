import '../models.dart';
import 'acorde_client.dart';
import 'vault_store.dart';
import 'wikilink_parser.dart';

/// NoteService operates on the local vault as the primary source of truth.
/// ACORDE is used for P2P sync (mirror), not as the storage backend.
class NoteService {
  NoteService(this.vault, this.client);

  final VaultStore vault;
  final AcordeClient client;
  final wikilinks = WikilinkParser();

  // ── Local CRUD (vault-first) ───────────────────────────────────

  Future<List<NoteEntry>> listNotes() async => vault.readAll();

  Future<NoteEntry?> getNote(String id) async => vault.getNote(id);

  Future<NoteEntry> create({
    required String title,
    required String body,
    List<String> tags = const [],
  }) async {
    final allNotes = await listNotes();
    final outlinkTags = wikilinks.buildOutlinkTags(body, allNotes);

    final allTags = <String>{
      ...tags,
      ...outlinkTags,
    };

    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecondsSinceEpoch % 100000)}';

    final note = NoteEntry(
      id: tempId,
      type: 'note',
      content: NoteContent(title: title, body: body),
      tags: allTags.toList(),
      createdAt: createdAt,
      updatedAt: createdAt,
      deleted: false,
      owner: '',
      pendingSync: true,
    );

    await vault.write(note);
    return note;
  }

  Future<NoteEntry> update({
    required String id,
    required String title,
    required String body,
    List<String>? tags,
  }) async {
    final existing = await vault.getNote(id);
    if (existing == null) {
      throw Exception('Note not found: $id');
    }

    final allNotes = await listNotes();
    final userTags = tags ?? existing.tags.where((t) => !t.startsWith('outlink:')).toList();
    final outlinkTags = wikilinks.buildOutlinkTags(body, allNotes);

    final allTags = <String>{
      ...userTags,
      ...outlinkTags,
    };

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final updated = existing.copyWith(
      content: NoteContent(title: title, body: body),
      tags: allTags.toList(),
      updatedAt: now,
      baselineUpdatedAt: existing.baselineUpdatedAt ?? existing.updatedAt,
      pendingSync: true,
    );

    await vault.write(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    await vault.delete(id);
  }

  // ── Wikilinks & Backlinks ──────────────────────────────────────

  List<String> extractWikilinks(String body) => wikilinks.extractWikilinks(body);

  Future<List<NoteEntry>> getBacklinks(String id) async {
    final allNotes = await listNotes();
    return wikilinks.findBacklinks(id, allNotes);
  }

  Future<List<NoteEntry>> getOutlinks(String id) async {
    final allNotes = await listNotes();
    return wikilinks.findOutlinks(id, allNotes);
  }

  Future<List<String>> resolveTitlesToIds(List<String> identifiers) async {
    final allNotes = await listNotes();
    return wikilinks.resolveToIds(identifiers, allNotes);
  }

  // ── Search (local) ─────────────────────────────────────────────

  Future<List<NoteEntry>> search(String query, {String? type}) async {
    final allNotes = await listNotes();
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return allNotes.where((n) => type == null || n.type == type).toList();

    return allNotes.where((entry) {
      if (type != null && entry.type != type) return false;
      final content = entry.content;
      if (content is NoteContent) {
        return content.title.toLowerCase().contains(lower) ||
            content.body.toLowerCase().contains(lower);
      }
      return entry.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }

  // ── ACORDE Sync (mirror local ↔ remote) ────────────────────────

  /// Push a local note to ACORDE. Used by the mutation queue drain.
  Future<NoteEntry> pushToAcorde(NoteEntry note) async {
    final noteContent = note.content as NoteContent;

    if (note.id.startsWith('local-')) {
      // New note — create on ACORDE
      final created = await client.createNote(
        title: noteContent.title,
        body: noteContent.body,
        tags: note.tags,
      );
      return created;
    } else {
      // Existing note — update on ACORDE
      return await client.updateNote(
        id: note.id,
        title: noteContent.title,
        body: noteContent.body,
        tags: note.tags,
      );
    }
  }

  /// Delete a note on ACORDE.
  Future<void> deleteOnAcorde(String id) async {
    await client.deleteNote(id);
  }

  /// Fetch a note from ACORDE for conflict detection / sync.
  Future<NoteEntry?> fetchFromAcorde(String id) async {
    try {
      return await client.getNote(id);
    } catch (_) {
      return null;
    }
  }

  /// Merge a remote note from ACORDE into the local vault.
  Future<NoteEntry> mergeRemote(NoteEntry remote) async {
    final local = await vault.getNote(remote.id);

    if (local == null) {
      // New remote note — write to vault
      await vault.write(remote);
      return remote;
    }

    // Conflict resolution: last-write-wins based on updated_at
    if (remote.updatedAt > local.updatedAt) {
      await vault.write(remote);
      return remote;
    }

    // Local is newer or equal — keep local
    return local;
  }
}
