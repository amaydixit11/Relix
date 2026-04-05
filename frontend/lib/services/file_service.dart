import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import 'acorde_client.dart';

class FileService {
  FileService(this.client);

  final AcordeClient client;

  Future<List<NoteEntry>> listFiles() async {
    final entries = await client.listEntries(type: 'file');
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<NoteEntry?> pickAndUpload() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final cid = await client.uploadBlob(bytes);

    final response = await client.createEntry(
      type: 'file',
      content: FileContent(
        name: file.name,
        cid: cid,
        size: file.size,
        mimeType: _getMimeType(file.name),
      ).toJson(),
      tags: ['file'],
    );

    return response;
  }

  String _getMimeType(String name) {
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.txt')) return 'text/plain';
    if (name.endsWith('.md')) return 'text/markdown';
    return 'application/octet-stream';
  }

  Future<Uint8List> download(String cid) async {
    return await client.getBlob(cid);
  }

  Future<XFile> downloadToTempFile(FileContent file) async {
    final bytes = await download(file.cid);
    final directory = await getTemporaryDirectory();
    final out = File('${directory.path}/${file.name}');
    await out.writeAsBytes(bytes);
    return XFile(out.path, name: file.name, mimeType: file.mimeType);
  }

  Future<void> shareFile(FileContent file) async {
    final out = await downloadToTempFile(file);
    await Share.shareXFiles([out], text: 'Relix attachment: ${file.name}');
  }

  Future<NoteEntry> addAnnotation(String entryId, Annotation annotation) async {
    final entry = await client.getNote(entryId);
    return entry; // Placeholder until generic update is ready
  }
}
