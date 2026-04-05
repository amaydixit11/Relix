import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/relix_controller.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  bool _uploading = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final files = widget.controller.snapshot.notes
        .where((entry) => entry.type == 'file' && entry.content is FileContent)
        .where((entry) {
          if (_query.trim().isEmpty) return true;
          final file = entry.content as FileContent;
          final lower = _query.toLowerCase();
          return file.name.toLowerCase().contains(lower) ||
              file.mimeType.toLowerCase().contains(lower) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(lower));
        })
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BLOB ARCHIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF7B88FF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Attachment Registry',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${files.length} FILE_ENTRIES_AVAILABLE',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            hintText: 'FILTER_ARCHIVE...',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: widget.controller.refresh,
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('REFRESH'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _uploading ? null : _uploadFile,
                        icon: Icon(
                          _uploading
                              ? Icons.hourglass_top_rounded
                              : Icons.upload_file_rounded,
                        ),
                        label: Text(_uploading ? 'UPLOADING...' : 'ADD_FILE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            sliver: files.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'NO_FILES_INDEXED',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white24,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = files[index];
                      final file = entry.content as FileContent;
                      return _FileRow(
                        entry: entry,
                        file: file,
                        onShare: () => widget.controller.shareFile(entry),
                        onCopyCid: () => _copyCid(file.cid),
                      );
                    }, childCount: files.length),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Future<void> _uploadFile() async {
    setState(() => _uploading = true);
    try {
      final created = await widget.controller.uploadFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == null ? 'UPLOAD_CANCELLED' : 'FILE_UPLINK_COMPLETE',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('FILE_UPLOAD_FAILED: $error')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _copyCid(String cid) async {
    await Clipboard.setData(ClipboardData(text: cid));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CID_COPIED')));
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.file,
    required this.onShare,
    required this.onCopyCid,
  });

  final NoteEntry entry;
  final FileContent file;
  final VoidCallback onShare;
  final VoidCallback onCopyCid;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF7B88FF)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${file.mimeType} • ${_formatBytes(file.size)} • CID ${file.cid}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'UPDATED_AT ${entry.updatedAt}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.white10,
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF7B88FF,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(
                                  0xFF7B88FF,
                                ).withValues(alpha: 0.24),
                              ),
                            ),
                            child: Text(
                              tag.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFB7C0FF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onCopyCid,
            tooltip: 'COPY_CID',
            icon: const Icon(Icons.content_copy_rounded, color: Colors.white38),
          ),
          IconButton(
            onPressed: onShare,
            tooltip: 'DOWNLOAD_OR_SHARE',
            icon: const Icon(Icons.download_rounded, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
