import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/connection_banner.dart';
import 'graph_page.dart';
import 'history_page.dart';
import 'files_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final RelixController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _LeftNav { notes, history, graph, files, settings }

class _HomePageState extends State<HomePage> {
  _LeftNav _leftNav = _LeftNav.notes;
  String? _selectedNoteId;
  bool _showCommandPalette = false;

  // Editor state
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _tagsController;
  late FocusNode _titleFocus;
  late FocusNode _bodyFocus;
  Timer? _saveDebounce;
  bool _isPreview = false;
  List<NoteEntry> _backlinks = [];

  // Notes list state
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _tagsController = TextEditingController();
    _titleFocus = FocusNode();
    _bodyFocus = FocusNode();
    _titleController.addListener(_onEditorChange);
    _bodyController.addListener(_onEditorChange);
    _tagsController.addListener(_onEditorChange);
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searchDebounce?.cancel();
    widget.controller.removeListener(_onStateChanged);
    _titleController.removeListener(_onEditorChange);
    _bodyController.removeListener(_onEditorChange);
    _tagsController.removeListener(_onEditorChange);
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onEditorChange() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_selectedNoteId == null || _selectedNoteId == 'new') return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty) return;

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !_isSystemTag(e))
        .toList();

    try {
      await widget.controller.updateNote(
        id: _selectedNoteId!,
        title: title,
        body: body,
        tags: tags,
      );
    } catch (_) {}
  }

  void _selectNote(String? id) {
    if (_selectedNoteId != null && _selectedNoteId != 'new') {
      _saveDebounce?.cancel();
      _autoSave();
    }

    setState(() {
      _selectedNoteId = id;
      _isPreview = false;
    });

    if (id != null && id != 'new') {
      final note = widget.controller.snapshot.notes
          .cast<NoteEntry?>()
          .firstWhere((n) => n?.id == id, orElse: () => null);
      if (note != null && note.content is NoteContent) {
        final nc = note.content as NoteContent;
        _titleController.text = nc.title;
        _bodyController.text = nc.body;
        _tagsController.text = note.tags
            .where((t) => !_isSystemTag(t))
            .join(', ');
      }
      _loadBacklinks(id);
    }
  }

  void _createNote() {
    _selectNote('new');
    _titleController.clear();
    _bodyController.clear();
    _tagsController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocus.requestFocus();
    });
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBacklinks(String id) async {
    try {
      final bl = await widget.controller.getBacklinks(id);
      if (mounted && _selectedNoteId == id) {
        setState(() => _backlinks = bl);
      }
    } catch (_) {
      if (mounted) setState(() => _backlinks = []);
    }
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isMod = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (isMod && key == LogicalKeyboardKey.keyK && !_showCommandPalette) {
      setState(() => _showCommandPalette = true);
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.keyN) {
      _createNote();
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.keyG) {
      setState(() => _leftNav = _LeftNav.graph);
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.keyH) {
      setState(() => _leftNav = _LeftNav.history);
      return true;
    }
    if (isMod && isShift && key == LogicalKeyboardKey.keyF) {
      setState(() => _leftNav = _LeftNav.files);
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.comma) {
      setState(() => _leftNav = _LeftNav.settings);
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.keyL) {
      setState(() => _leftNav = _LeftNav.notes);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_showCommandPalette) {
        setState(() => _showCommandPalette = false);
      } else if (_selectedNoteId != null) {
        _selectNote(null);
      }
      return true;
    }
    if (isMod && key == LogicalKeyboardKey.keyP) {
      setState(() => _isPreview = !_isPreview);
      return true;
    }
    return false;
  }

  List<NoteEntry> get _filteredNotes {
    final notes = widget.controller.snapshot.notes
        .where((e) => e.type == 'note')
        .toList();
    if (_searchQuery.isEmpty) return notes;
    final q = _searchQuery.toLowerCase();
    return notes.where((e) {
      final c = e.content as NoteContent?;
      if (c == null) return false;
      return c.title.toLowerCase().contains(q) ||
          c.body.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_handleGlobalKey(event)) return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Row(
          children: [
            // LEFT: Navigation rail (60px)
            _buildNavRail(),
            const VerticalDivider(width: 1, color: Color(0xFF1F1F1F)),
            // MIDDLE: Notes list (280px) or full page for other views
            SizedBox(
              width: _leftNav == _LeftNav.notes ? 280 : 220,
              child: _buildMiddlePanel(),
            ),
            const VerticalDivider(width: 1, color: Color(0xFF1F1F1F)),
            // RIGHT: Editor or specialized view
            Expanded(child: _buildRightPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildNavRail() {
    return Container(
      width: 60,
      color: const Color(0xFF131313),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.auto_awesome_mosaic, color: Color(0xFF7B88FF), size: 24),
          const SizedBox(height: 24),
          _navRailItem(Icons.article_outlined, _LeftNav.notes, 'Notes'),
          _navRailItem(Icons.history_rounded, _LeftNav.history, 'History'),
          _navRailItem(Icons.hub_outlined, _LeftNav.graph, 'Graph'),
          _navRailItem(Icons.folder_outlined, _LeftNav.files, 'Files'),
          const Spacer(),
          _navRailItem(Icons.settings_outlined, _LeftNav.settings, 'Settings'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _navRailItem(IconData icon, _LeftNav nav, String label) {
    final active = _leftNav == nav;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() => _leftNav = nav),
        child: Container(
          width: 60,
          height: 48,
          decoration: BoxDecoration(
            border: active
                ? const Border(left: BorderSide(color: Color(0xFF7B88FF), width: 2))
                : null,
          ),
          child: Icon(icon, size: 20,
              color: active ? Colors.white : Colors.white38),
        ),
      ),
    );
  }

  Widget _buildMiddlePanel() {
    switch (_leftNav) {
      case _LeftNav.notes:
        return _buildNotesList();
      case _LeftNav.history:
        return HistoryPage(controller: widget.controller);
      case _LeftNav.graph:
        return GraphPage(controller: widget.controller);
      case _LeftNav.files:
        return FilesPage(controller: widget.controller);
      case _LeftNav.settings:
        return SettingsPage(controller: widget.controller);
    }
  }

  Widget _buildNotesList() {
    final notes = _filteredNotes;
    return Container(
      color: const Color(0xFF131313),
      child: Column(
        children: [
          // Search + New
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 150), () {
                        if (mounted) setState(() => _searchQuery = v);
                      });
                    },
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF7B88FF)),
                  onPressed: _createNote,
                  tooltip: 'New note (Ctrl+N)',
                ),
              ],
            ),
          ),
          // Connection status
          ConnectionBanner(snapshot: widget.controller.snapshot),
          // Notes
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty ? 'No matches' : 'No notes yet',
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, i) {
                      final note = notes[i];
                      final nc = note.content as NoteContent?;
                      if (nc == null) return const SizedBox.shrink();
                      final isSelected = _selectedNoteId == note.id;
                      return InkWell(
                        onTap: () => _selectNote(note.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7B88FF).withValues(alpha: 0.12)
                                : null,
                            border: Border(
                              left: isSelected
                                  ? const BorderSide(color: Color(0xFF7B88FF), width: 2)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      nc.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                  ),
                                  if (note.pendingSync)
                                    const Icon(Icons.circle, size: 6, color: Colors.amber),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nc.body.isEmpty ? '(empty)' : nc.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white24, height: 1.4),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(note.updatedAt),
                                style: const TextStyle(fontSize: 10, color: Colors.white10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_leftNav != _LeftNav.notes) return const SizedBox.shrink();

    if (_selectedNoteId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text('Select a note or create a new one', style: TextStyle(color: Colors.white24)),
            SizedBox(height: 8),
            Text('Ctrl+N for new note  •  Ctrl+K for search', style: TextStyle(color: Colors.white10, fontSize: 11)),
          ],
        ),
      );
    }

    if (_isPreview) {
      return _buildPreview();
    }

    return _buildEditor();
  }

  Widget _buildEditor() {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        children: [
          // Toolbar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                  onPressed: () => _selectNote(null),
                  tooltip: 'Close (Esc)',
                ),
                const SizedBox(width: 8),
                if (_selectedNoteId != 'new')
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                    onPressed: _deleteCurrentNote,
                    tooltip: 'Delete',
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isPreview = true),
                  child: const Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // Editor
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _tagsController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFA267F6)),
                    decoration: const InputDecoration(
                      hintText: 'tags, separated, by, commas',
                      prefixIcon: Icon(Icons.tag_rounded, size: 14, color: Colors.white10),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _bodyController,
                    focusNode: _bodyFocus,
                    maxLines: null,
                    style: const TextStyle(fontSize: 14, height: 1.7),
                    decoration: const InputDecoration(
                      hintText: 'Start writing... (Markdown supported)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Backlinks bar
          if (_backlinks.isNotEmpty && _selectedNoteId != 'new')
            Container(
              height: 120,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('${_backlinks.length} BACKLINK', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white24)),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _backlinks.take(5).map((bl) {
                        final nc = bl.content as NoteContent?;
                        if (nc == null) return const SizedBox.shrink();
                        return InkWell(
                          onTap: () => _selectNote(bl.id),
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131313),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1F1F1F)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nc.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7B88FF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(nc.body, style: const TextStyle(fontSize: 10, color: Colors.white24), maxLines: 3, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                  onPressed: () => _selectNote(null),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isPreview = false),
                  child: const Text('EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  if (_tagsController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: _tagsController.text.split(',').map((t) => _tagChip(t.trim())).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  MarkdownBody(
                    data: _bodyController.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 15, height: 1.7, color: Colors.white70),
                      h1: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                      h2: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                      code: const TextStyle(fontFamily: 'monospace', backgroundColor: Color(0xFF131313), color: Color(0xFF2DD4BF)),
                      codeblockDecoration: BoxDecoration(color: const Color(0xFF131313), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1F1F1F))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFA267F6).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA267F6).withValues(alpha: 0.3)),
      ),
      child: Text('#$tag', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA267F6))),
    );
  }

  Future<void> _deleteCurrentNote() async {
    if (_selectedNoteId == null || _selectedNoteId == 'new') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF131313),
        title: const Text('Delete note?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will permanently delete this note.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteNote(_selectedNoteId!);
      _selectNote(null);
    }
  }

  String _timeAgo(int seconds) {
    if (seconds <= 0) return 'just now';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}';
  }

  bool _isSystemTag(String tag) => tag.startsWith('outlink:') || tag.startsWith('backlink:');
}
