import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/markdown_toolbar.dart';

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
  late FocusNode _bodyFocusNode;
  int? _baselineUpdatedAt;
  bool _saving = false;
  bool _isPreview = false;
  List<NoteEntry> _backlinks = [];
  bool _showBacklinks = false;

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
    _bodyFocusNode = FocusNode();
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
    _bodyFocusNode.dispose();
    super.dispose();
  }

  /// Handle markdown keyboard shortcuts
  bool _handleBodyKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMod = isMeta || isCtrl;

    // Ctrl/Cmd + B → bold
    if (isMod && event.logicalKey == LogicalKeyboardKey.keyB) {
      _wrapBodySelection('**');
      return true;
    }
    // Ctrl/Cmd + I → italic
    if (isMod && event.logicalKey == LogicalKeyboardKey.keyI) {
      _wrapBodySelection('*');
      return true;
    }
    // Ctrl/Cmd + S → Save
    if (isMod && event.logicalKey == LogicalKeyboardKey.keyS) {
      _save();
      return true;
    }
    // Ctrl/Cmd + Shift + K → inline code (avoid conflict with Cmd+K command palette)
    if (isMod && HardwareKeyboard.instance.isShiftPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
      _wrapBodySelection('`');
      return true;
    }
    // Ctrl/Cmd + Shift + L → wikilink
    if (isMod &&
        HardwareKeyboard.instance.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyL) {
      _wrapBodySelection('[[', ']]');
      return true;
    }
    // Tab → indent or insert code block marker
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (!HardwareKeyboard.instance.isShiftPressed) {
        _insertBodyText('  ');
      }
      return true;
    }

    return false;
  }

  void _wrapBodySelection(String before, [String? after]) {
    final text = _bodyController.text;
    final start = _bodyController.selection.baseOffset;
    final end = _bodyController.selection.extentOffset;
    if (start < 0 || end < 0) {
      final pos = _bodyController.selection.baseOffset;
      if (pos < 0) return;
      final newText = text.replaceRange(pos, pos, before);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + before.length),
      );
      return;
    }
    final selStart = start < end ? start : end;
    final selEnd = start < end ? end : start;
    final wrapped = '$before${text.substring(selStart, selEnd)}${after ?? before}';
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(selStart, selEnd, wrapped),
      selection: TextSelection(
        baseOffset: selStart + before.length,
        extentOffset: selStart + before.length + (selEnd - selStart),
      ),
    );
  }

  void _insertBodyText(String text) {
    final pos = _bodyController.selection.baseOffset;
    if (pos < 0) return;
    final current = _bodyController.text;
    final newText = current.replaceRange(pos, pos, text);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + text.length),
    );
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
              tooltip: 'Delete note',
            ),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12),
          IconButton(
            onPressed: () => setState(() => _showBacklinks = !_showBacklinks),
            icon: Badge(
              isLabelVisible: _backlinks.isNotEmpty,
              label: Text('${_backlinks.length}'),
              child: const Icon(Icons.arrow_left_rounded, size: 20),
            ),
            tooltip: 'Backlinks',
          ),
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
        child: Row(
          children: [
            // Main editor/preview
            Expanded(
              child: Column(
                children: [
                  if (!_isPreview)
                    MarkdownToolbar(
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                    ),
                  Expanded(
                    child: _isPreview ? _buildPreview() : _buildEditor(),
                  ),
                ],
              ),
            ),
            // Backlinks sidebar
            if (_showBacklinks && _backlinks.isNotEmpty)
              Container(
                width: 280,
                decoration: const BoxDecoration(
                  color: Color(0xFF131313),
                  border: Border(left: BorderSide(color: Color(0xFF1F1F1F))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'BACKLINKS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white24,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_backlinks.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7B88FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF1F1F1F)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: _backlinks.map(_backlinkCard).toList(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_handleBodyKey(event)) return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.existing == null,
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
              focusNode: _bodyFocusNode,
              maxLines: null,
              autofocus: widget.existing != null,
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
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text;
    final body = _bodyController.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Untitled Trace' : title,
            style: const TextStyle(
              fontSize: 32,
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
              children: _backlinks.map(_buildBacklinkCard).toList(),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _backlinkCard(NoteEntry note) {
    final content = note.content as NoteContent;
    return InkWell(
      onTap: () {
        // Navigate to the backlinking note by updating the editor
        _close();
        // Signal through controller to open this note
        // For now, we can't directly navigate from here, so show it in preview
        setState(() {
          _titleController.text = content.title;
          _bodyController.text = content.body;
          _tagsController.text = note.tags
              .where((tag) => !_isSystemTag(tag))
              .join(', ');
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF7B88FF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              content.body.length > 80
                  ? '${content.body.substring(0, 80)}...'
                  : content.body,
              style: const TextStyle(fontSize: 10, color: Colors.white24),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
    final localTime = _formatTimestamp(_baselineUpdatedAt ?? 0);
    final remoteTime = _formatTimestamp(latest.updatedAt);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text('CONFLICT_DETECTED', style: TextStyle(fontSize: 12)),
        content: Text(
          'A newer version of this note exists on another device.\n\n'
          'Remote: $remoteTime\n'
          'Local baseline: $localTime\n\n'
          'How would you like to resolve this?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard local'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'overwrite'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Overwrite remote'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'load_remote'),
            child: const Text('Load remote copy'),
          ),
        ],
      ),
    );
    return res ?? 'cancel';
  }

  String _formatTimestamp(int seconds) {
    if (seconds <= 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
