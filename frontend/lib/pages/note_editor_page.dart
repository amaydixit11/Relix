import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models.dart';
import '../services/relix_controller.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    required this.controller,
    this.existing,
    this.onClose,
  });

  final RelixController controller;
  final NoteEntry? existing;
  final VoidCallback? onClose;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _tagsController;
  int? _baselineUpdatedAt;
  bool _saving = false;
  bool _isPreview = false;
  List<NoteEntry> _backlinks = [];

  @override
  void initState() {
    super.initState();
    final note = widget.existing?.content as NoteContent?;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _tagsController = TextEditingController(
      text: widget.existing?.tags
              .where((tag) => !_isSystemTag(tag))
              .join(', ') ??
          '',
    );
    _baselineUpdatedAt =
        widget.existing?.baselineUpdatedAt ?? widget.existing?.updatedAt;
    if (widget.existing != null) {
      _loadBacklinks();
    }
  }

  Future<void> _loadBacklinks() async {
    try {
      final bl = await widget.controller.getBacklinks(widget.existing!.id);
      if (mounted) setState(() => _backlinks = bl);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: _close,
            ),
            const SizedBox(width: 4),
            Text(
              widget.existing == null ? 'NEW_TRACE' : 'EDIT_TRACE',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: 'DESTROY_trace',
            ),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12),
          TextButton(
            onPressed: () => setState(() => _isPreview = !_isPreview),
            child: Text(
              _isPreview ? 'EDITOR' : 'PREVIEW',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _save,
                child: const Text(
                  'COMMIT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: const Color(0xFF0F0F0F),
        child: _isPreview ? _buildPreview() : _buildEditor(),
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter title...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsController,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFFA267F6),
            ),
            decoration: const InputDecoration(
              hintText: 'tags, separated, by, commas',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              prefixIcon: Icon(
                Icons.tag_rounded,
                size: 14,
                color: Colors.white10,
              ),
            ),
          ),
          const Divider(height: 48),
          TextField(
            controller: _bodyController,
            maxLines: null,
            style: const TextStyle(fontSize: 15, height: 1.6),
            decoration: const InputDecoration(
              hintText: 'Begin cognitive recording...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text;
    final body = _bodyController.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Untitled Trace' : title,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          MarkdownBody(
            data: body,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: Colors.white70,
              ),
              h1: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
              h2: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              code: const TextStyle(
                fontFamily: 'monospace',
                backgroundColor: Color(0xFF131313),
                color: Color(0xFF2DD4BF),
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF131313),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1F1F1F)),
              ),
            ),
          ),
          if (_backlinks.isNotEmpty) ...[
            const SizedBox(height: 64),
            const Text(
              'LINKED REFERENCES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _backlinks.map((bl) => _buildBacklinkCard(bl)).toList(),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBacklinkCard(NoteEntry note) {
    final content = note.content as NoteContent;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[[${content.title}]]',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF7B88FF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.body.length > 60
                ? '${content.body.substring(0, 60)}...'
                : content.body,
            style: const TextStyle(fontSize: 10, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !_isSystemTag(e))
        .toList();

    if (title.isEmpty) return;

    if (widget.existing != null &&
        widget.existing!.id.startsWith('local-') == false) {
      final latest = await widget.controller.fetchLatestRemoteNote(
        widget.existing!.id,
      );
      if (latest != null &&
          _baselineUpdatedAt != null &&
          latest.updatedAt > _baselineUpdatedAt!) {
        final resolution = await _showConflictDialog(latest);
        if (resolution == 'cancel') return;
        if (resolution == 'discard') {
          _close();
          return;
        }
        if (resolution == 'load_remote') {
          _titleController.text = latest.asNote?.title ?? _titleController.text;
          _bodyController.text = latest.asNote?.body ?? _bodyController.text;
          _tagsController.text = latest.tags.join(', ');
          setState(() {
            _baselineUpdatedAt = latest.updatedAt;
          });
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.controller.createNote(
          title: title,
          body: body,
          tags: tags,
        );
      } else {
        await widget.controller.updateNote(
          id: widget.existing!.id,
          title: title,
          body: body,
          tags: tags,
        );
      }
      _baselineUpdatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (mounted) _close();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF131313),
        title: const Text(
          'PURGE_TRACE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        content: const Text(
          'This action will permanently delete this cognitive artifact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ABORT', style: TextStyle(color: Colors.white24)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existing != null) {
      await widget.controller.deleteNote(widget.existing!.id);
      _close();
    }
  }

  Future<String> _showConflictDialog(NoteEntry latest) async {
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text('CONFLICT_DETECTED', style: TextStyle(fontSize: 12)),
        content: Text(
          'SERVER_VERSION_NEWER (ID: ${latest.id}).\n'
          'REMOTE_TS: ${latest.updatedAt}\n'
          'LOCAL_BL: $_baselineUpdatedAt\n\n'
          'PROCEED_WITH_OVERWRITE?',
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DISCARD_LOCAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'overwrite'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('OVERWRITE_REMOTE'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'load_remote'),
            child: const Text('LOAD_REMOTE_COPY'),
          ),
        ],
      ),
    );
    return res ?? 'cancel';
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  bool _isSystemTag(String tag) =>
      tag.startsWith('outlink:') || tag.startsWith('backlink:');
}
