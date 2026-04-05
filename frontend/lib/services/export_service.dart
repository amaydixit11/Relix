import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';

class ExportService {
  String noteToMarkdown(NoteEntry entry) {
    if (entry.type != 'note') return 'Not a note entry.';
    final note = entry.content as NoteContent;

    final userTags = entry.tags
        .where((t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
        .toList();

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      entry.createdAt * 1000,
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      entry.updatedAt * 1000,
    );
    final isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

    final frontmatter = [
      '---',
      'title: "${note.title}"',
      'created: ${isoFormat.format(createdAt.toUtc())}',
      'updated: ${isoFormat.format(updatedAt.toUtc())}',
      if (userTags.isNotEmpty)
        'tags: [${userTags.map((t) => '"$t"').join(', ')}]',
      '---',
      '',
    ].join('\n');

    return frontmatter + note.body;
  }

  Future<Uint8List> exportToZip(List<NoteEntry> notes) async {
    final archive = Archive();

    for (final note in notes) {
      if (note.type != 'note') continue;
      final content = note.content as NoteContent;

      final safeName = content.title
          .replaceAll(RegExp(r'[/\\?%*:|"<> \.]'), '-')
          .substring(0, content.title.length > 50 ? 50 : content.title.length);

      final fileName = '${safeName.isEmpty ? 'note' : safeName}-${note.id}.md';
      final bytes = Uint8List.fromList(utf8.encode(noteToMarkdown(note)));
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }

    final encoder = ZipEncoder();
    return Uint8List.fromList(encoder.encode(archive));
  }

  Future<void> shareNote(NoteEntry note) async {
    final content = noteToMarkdown(note);
    final noteContent = note.content as NoteContent;
    final safeName = noteContent.title
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .toLowerCase();

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            name: '${safeName.isEmpty ? 'relix-note' : safeName}-${note.id}.md',
            mimeType: 'text/markdown',
          ),
        ],
        text: 'Relix Export: ${noteContent.title}',
      ),
    );
  }

  Future<void> shareAll(List<NoteEntry> notes) async {
    final zipBuffer = await exportToZip(notes);
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            zipBuffer,
            name: 'relix-export-$date.zip',
            mimeType: 'application/zip',
          ),
        ],
        text: 'Relix Backup ($date)',
      ),
    );
  }
}
