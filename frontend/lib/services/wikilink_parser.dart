import 'package:collection/collection.dart';

import '../models.dart';

/// Parses `[[wikilinks]]` from local markdown content and resolves
/// them to note IDs by matching against the local vault index.
class WikilinkParser {
  static const _wikilinkPattern = r'\[\[(.*?)\]\]';

  /// Extract all wikilink identifiers from a markdown body.
  List<String> extractWikilinks(String body) {
    final regex = RegExp(_wikilinkPattern);
    return regex.allMatches(body).map((m) => m.group(1)!).toList();
  }

  /// Resolve wikilink identifiers to note IDs.
  /// An identifier can be a note title (case-insensitive match) or
  /// a raw UUID (passed through directly).
  List<String> resolveToIds(
    List<String> identifiers,
    List<NoteEntry> allNotes,
  ) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    final resolved = <String>[];
    for (final iden in identifiers) {
      if (uuidRegex.hasMatch(iden)) {
        resolved.add(iden);
        continue;
      }
      final match = allNotes.firstWhere(
        (n) {
          final title = n.content is NoteContent
              ? (n.content as NoteContent).title.toLowerCase()
              : '';
          return title == iden.toLowerCase();
        },
        orElse: () => allNotes.first,
      );
      // Check if it actually matched
      final title = match.content is NoteContent
          ? (match.content as NoteContent).title.toLowerCase()
          : '';
      if (title == iden.toLowerCase()) {
        resolved.add(match.id);
      }
    }
    return resolved;
  }

  /// Build the outlink tags for a note given its body and the vault index.
  /// Returns tags to add (prefixed with `outlink:`).
  List<String> buildOutlinkTags(String body, List<NoteEntry> allNotes) {
    final wikilinks = extractWikilinks(body);
    final resolvedIds = resolveToIds(wikilinks, allNotes);
    return resolvedIds.map((id) => 'outlink:$id').toList();
  }

  /// Given a note ID, find all notes that link to it (backlinks).
  List<NoteEntry> findBacklinks(String id, List<NoteEntry> allNotes) {
    return allNotes
        .where((n) => n.tags.contains('outlink:$id'))
        .toList();
  }

  /// Given a note ID, find all notes it links to (outlinks).
  List<NoteEntry> findOutlinks(String id, List<NoteEntry> allNotes) {
    final entry = allNotes.firstWhereOrNull((n) => n.id == id);
    if (entry == null) return [];
    final targetIds = entry.tags
        .where((t) => t.startsWith('outlink:'))
        .map((t) => t.replaceFirst('outlink:', ''));
    return allNotes.where((n) => targetIds.contains(n.id)).toList();
  }
}
