import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// A dropdown that appears when the user types `[[` in the editor,
/// offering note title completions.
class WikilinkAutocomplete extends StatefulWidget {
  const WikilinkAutocomplete({
    super.key,
    required this.notes,
    required this.controller,
    required this.focusNode,
    required this.onInsert,
  });

  final List<NoteEntry> notes;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String noteId) onInsert;

  @override
  State<WikilinkAutocomplete> createState() => _WikilinkAutocompleteState();
}

class _WikilinkAutocompleteState extends State<WikilinkAutocomplete> {
  List<NoteEntry> _matches = [];
  int _selectedIndex = 0;
  int? _wikiStartPos;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final pos = widget.controller.selection.baseOffset;
    if (pos < 0) {
      if (mounted) {
        setState(() {
          _matches = [];
          _wikiStartPos = null;
        });
      }
      return;
    }

    // Look back for `[[`
    final beforeCursor = text.substring(0, pos);
    // Find the most recent `[[` that hasn't been closed
    var searchFrom = pos;
    while (searchFrom > 0) {
      final openBracket = beforeCursor.lastIndexOf('[[', searchFrom - 1);
      if (openBracket < 0) break;

      // Check there's no `]]` between the open bracket and cursor
      between: {
        final between = beforeCursor.substring(openBracket + 2, pos);
        if (between.contains(']]')) break between;
        // Check there's no newline between (wikilinks can't span lines)
        if (between.contains('\n')) break;

        // We found an active wikilink
        final query = between.trim();
        if (mounted) {
          setState(() {
            _wikiStartPos = openBracket;
            _query = query;
            _matches = widget.notes
                .where((n) {
                  final title = n.content is NoteContent
                      ? (n.content as NoteContent).title
                      : '';
                  return title.toLowerCase().contains(query.toLowerCase()) ||
                      query.isEmpty;
                })
                .take(8)
                .toList();
            _selectedIndex = 0;
          });
        }
        return;
      }
      searchFrom = openBracket;
    }

    // No active wikilink
    if (mounted) {
      setState(() {
        _matches = [];
        _wikiStartPos = null;
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_matches.isEmpty) return;
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _matches.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + _matches.length) % _matches.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _selectMatch(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _matches = [];
        _wikiStartPos = null;
      });
    }
  }

  void _selectMatch(int index) {
    if (index < 0 || index >= _matches.length || _wikiStartPos == null) return;
    final note = _matches[index];
    widget.onInsert(note.id);
    // We let the parent handle the actual insertion
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 48,
      top: 200,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF131313),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F1F1F)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    'LINK TO NOTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final note = _matches[index];
                      final isSelected = index == _selectedIndex;
                      final title = note.content is NoteContent
                          ? (note.content as NoteContent).title
                          : 'Untitled';
                      final body = note.content is NoteContent
                          ? (note.content as NoteContent).body
                          : '';

                      return InkWell(
                        onTap: () => _selectMatch(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7B88FF).withValues(alpha: 0.1)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                  color: isSelected
                                      ? const Color(0xFF7B88FF)
                                      : Colors.white,
                                ),
                              ),
                              if (body.isNotEmpty)
                                Text(
                                  body.length > 50
                                      ? '${body.substring(0, 50)}...'
                                      : body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
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
          ),
        ),
      ),
    );
  }

  /// Returns the current wikilink query state for the parent editor to use.
  ({int wikiStartPos, String query})? get activeWikilink {
    if (_wikiStartPos == null || _query.isEmpty) return null;
    return (wikiStartPos: _wikiStartPos!, query: _query);
  }
}
