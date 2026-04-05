import '../models.dart';
import 'acorde_client.dart';

class NoteService {
  NoteService(this.client);

  final AcordeClient client;

  List<String> extractWikilinks(String body) {
    final RegExp regex = RegExp(r'\[\[(.*?)\]\]');
    return regex.allMatches(body).map((match) => match.group(1)!).toList();
  }

  Future<List<String>> resolveTitlesToIds(List<String> identifiers) async {
    final allEntries = await client.listNotes();
    final allNotes = allEntries.where((e) => e.type == 'note').toList();
    final resolved = <String>{};

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    for (final iden in identifiers) {
      if (uuidRegex.hasMatch(iden)) {
        resolved.add(iden);
        continue;
      }

      final actualMatch = allNotes.any(
        (n) =>
            (n.content as NoteContent).title.toLowerCase() ==
            iden.toLowerCase(),
      );

      if (actualMatch) {
        final note = allNotes.firstWhere(
          (n) =>
              (n.content as NoteContent).title.toLowerCase() ==
              iden.toLowerCase(),
        );
        resolved.add(note.id);
      }
    }

    return resolved.toList();
  }

  Future<NoteEntry> create(
    String title,
    String body, {
    List<String> tags = const [],
  }) async {
    final wikilinkTitles = extractWikilinks(body);
    final resolvedIds = await resolveTitlesToIds(wikilinkTitles);

    final allTags = <String>{
      ...tags,
      ...resolvedIds.map((id) => 'outlink:$id'),
    };

    return await client.createNote(
      title: title,
      body: body,
      tags: allTags.toList(),
    );
  }

  Future<NoteEntry> update(
    String id, {
    String? title,
    String? body,
    List<String>? tags,
  }) async {
    final existing = await client.getNote(id);
    final existingNote = existing.content as NoteContent;

    final newTitle = title ?? existingNote.title;
    final newBody = body ?? existingNote.body;

    final newWikilinks = extractWikilinks(newBody);
    final resolvedIds = await resolveTitlesToIds(newWikilinks);

    final finalTags = <String>{
      ...(tags ?? existing.tags.where((t) => !t.startsWith('outlink:'))),
      ...resolvedIds.map((id) => 'outlink:$id'),
    };

    return await client.updateNote(
      id: id,
      title: newTitle,
      body: newBody,
      tags: finalTags.toList(),
    );
  }

  Future<List<NoteEntry>> getBacklinks(String id) async {
    return await client.listEntries(type: 'note', tag: 'outlink:$id');
  }

  Future<List<NoteEntry>> search(String query, {String? type}) async {
    return await client.searchEntries(query, type: type);
  }

  Future<List<NoteEntry>> getOutlinks(String id) async {
    final entry = await client.getNote(id);
    final outlinkIds = entry.tags
        .where((tag) => tag.startsWith('outlink:'))
        .map((tag) => tag.replaceFirst('outlink:', ''));

    final targets = await Future.wait(
      outlinkIds.map((targetId) async {
        try {
          return await client.getNote(targetId);
        } catch (_) {
          return null;
        }
      }),
    );

    return targets.whereType<NoteEntry>().toList();
  }
}
