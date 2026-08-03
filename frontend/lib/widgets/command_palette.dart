import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relix_controller.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.controller,
    required this.onNoteSelected,
    required this.onClose,
  });

  final RelixController controller;
  final Function(String noteId) onNoteSelected;
  final VoidCallback onClose;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_CommandResult> _getResults(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      // Show recent notes
      return widget.controller.snapshot.notes
          .where((e) => e.type == 'note')
          .take(8)
          .map((e) => _CommandResult(
                type: 'note',
                id: e.id,
                title: e.asNote?.title ?? 'Untitled',
                subtitle: (e.asNote != null && e.asNote!.body.isNotEmpty)
                    ? (e.asNote!.body.length > 50
                        ? '${e.asNote!.body.substring(0, 50)}...'
                        : e.asNote!.body)
                    : '',
                icon: Icons.description_outlined,
              ))
          .toList();
    }

    final results = <_CommandResult>[];

    // Search notes
    for (final note in widget.controller.snapshot.notes) {
      if (note.type != 'note') continue;
      final content = note.asNote;
      if (content == null) continue;

      final titleMatch = content.title.toLowerCase().contains(trimmed);
      final bodyMatch = content.body.toLowerCase().contains(trimmed);
      final tagMatch = note.tags.any((t) => t.toLowerCase().contains(trimmed));

      if (titleMatch || bodyMatch || tagMatch) {
        results.add(_CommandResult(
          type: 'note',
          id: note.id,
          title: content.title,
          subtitle: bodyMatch || titleMatch
              ? content.body.length > 60
                  ? '${content.body.substring(0, 60)}...'
                  : content.body
              : 'Tags: ${note.tags.where((t) => t.toLowerCase().contains(trimmed)).join(', ')}',
          icon: Icons.description_outlined,
          score: (titleMatch ? 3 : 0) + (bodyMatch ? 1 : 0) + (tagMatch ? 2 : 0),
        ));
      }
    }

    // Sort by score
    results.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    // Add commands
    final commandResults = [
      _CommandResult(
        type: 'command',
        id: 'cmd_new_note',
        title: 'Create New Note',
        subtitle: 'Open a blank note editor',
        icon: Icons.note_add_rounded,
        action: () {
          widget.onClose();
          widget.onNoteSelected('new');
        },
      ),
      _CommandResult(
        type: 'command',
        id: 'cmd_graph',
        title: 'Open Graph View',
        subtitle: 'View knowledge topology',
        icon: Icons.hub_outlined,
        action: () {
          widget.onClose();
          // Navigate to graph - we'll signal via special ID
          widget.onNoteSelected('__graph__');
        },
      ),
      _CommandResult(
        type: 'command',
        id: 'cmd_files',
        title: 'Open Files',
        subtitle: 'Browse attachments',
        icon: Icons.folder_open_rounded,
        action: () {
          widget.onClose();
          widget.onNoteSelected('__files__');
        },
      ),
      _CommandResult(
        type: 'command',
        id: 'cmd_settings',
        title: 'Open Settings',
        subtitle: 'Fleet control & pairing',
        icon: Icons.settings_outlined,
        action: () {
          widget.onClose();
          widget.onNoteSelected('__settings__');
        },
      ),
      _CommandResult(
        type: 'command',
        id: 'cmd_export',
        title: 'Export All Notes',
        subtitle: 'Download as ZIP archive',
        icon: Icons.file_download_rounded,
        action: () async {
          widget.onClose();
          final notes = widget.controller.snapshot.notes
              .where((e) => e.type == 'note')
              .toList();
          if (notes.isNotEmpty) {
            await widget.controller.export.shareAll(notes);
          }
        },
      ),
    ];

    // Filter commands by query
    final matchingCommands = commandResults.where((cmd) {
      return cmd.title.toLowerCase().contains(trimmed) ||
          cmd.subtitle.toLowerCase().contains(trimmed);
    }).toList();

    return [...results, ...matchingCommands];
  }

  @override
  Widget build(BuildContext context) {
    final results = _getResults(_searchController.text);
    _selectedIndex = _selectedIndex.clamp(0, results.isNotEmpty ? results.length - 1 : 0);

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF131313),
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    setState(() => _selectedIndex = (_selectedIndex + 1).clamp(0, results.length - 1));
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    setState(() => _selectedIndex = (_selectedIndex - 1).clamp(0, results.length - 1));
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.enter && results.isNotEmpty) {
                    _selectResult(results[_selectedIndex]);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    widget.onClose();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: (v) => setState(() => _selectedIndex = 0),
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search notes, commands...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white24),
                            onPressed: widget.onClose,
                          ),
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF1F1F1F)),
                    Flexible(
                      child: results.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No results found', style: TextStyle(color: Colors.white24)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final result = results[index];
                                final isSelected = index == _selectedIndex;
                                return ListTile(
                                  leading: Icon(
                                    result.icon,
                                    color: result.type == 'command' ? const Color(0xFF2DD4BF) : const Color(0xFF7B88FF),
                                  ),
                                  title: Text(
                                    result.title,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    result.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                  tileColor: isSelected ? const Color(0xFF7B88FF).withValues(alpha: 0.1) : null,
                                  onTap: () => _selectResult(result),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1, color: Color(0xFF1F1F1F)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _keyHint('↑↓', 'navigate'),
                          const SizedBox(width: 12),
                          _keyHint('↵', 'open'),
                          const SizedBox(width: 12),
                          _keyHint('esc', 'close'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectResult(_CommandResult result) {
    if (result.action != null) {
      result.action!();
    } else if (result.type == 'note') {
      widget.onClose();
      widget.onNoteSelected(result.id);
    }
  }

  Widget _keyHint(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Colors.white54,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }
}

class _CommandResult {
  _CommandResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    this.score,
  });

  final String type; // 'note' or 'command'
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? action;
  final int? score;
}
