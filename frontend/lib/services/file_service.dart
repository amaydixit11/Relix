import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import 'acorde_client.dart';

class FileService {
  FileService(this.client);

  final AcordeClient client;

  Future<NoteEntry?> pickAndUpload() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    final bytes = await File(path).readAsBytes();
    final cid = await client.uploadBlob(bytes);

    // Create entry in ACORDE
    final response = await client.createNote(
      title: file.name,
      body: 'File: ${file.name}\nCID: $cid',
      tags: ['file'],
    );

    return response;
  }

  Future<Uint8List> download(String cid) async {
    return await client.getBlob(cid);
  }

  Future<NoteEntry> addAnnotation(String entryId, Annotation annotation) async {
    final entry = await client.getNote(entryId);
    return entry; // Placeholder until generic update is ready
  }
}
