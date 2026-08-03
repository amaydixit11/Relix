import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Toolbar for markdown formatting that operates on a [TextEditingController].
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  void _wrapSelection(String before, [String? after]) {
    final text = controller.text;
    final start = controller.selection.baseOffset;
    final end = controller.selection.extentOffset;
    if (start < 0 || end < 0) {
      // No selection — insert at cursor
      final pos = controller.selection.baseOffset;
      if (pos < 0) return;
      final newText = text.replaceRange(pos, pos, before);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + before.length),
      );
      return;
    }
    final selStart = start < end ? start : end;
    final selEnd = start < end ? end : start;
    final wrapped = '$before${text.substring(selStart, selEnd)}${after ?? before}';
    controller.value = TextEditingValue(
      text: text.replaceRange(selStart, selEnd, wrapped),
      selection: TextSelection(
        baseOffset: selStart + before.length,
        extentOffset: selStart + before.length + (selEnd - selStart),
      ),
    );
  }

  void _insertAtStartOfLine(String prefix) {
    final text = controller.text;
    final pos = controller.selection.baseOffset;
    if (pos < 0) return;

    // Find start of current line
    var lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final lineText = text.substring(lineStart);
    // Remove existing prefix of the same type if present
    final cleanLine = lineText.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    final newText = text.replaceRange(lineStart, lineStart + lineText.length, '$prefix$cleanLine');
    final newPos = pos + prefix.length - (lineText.length - cleanLine.length);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPos),
    );
  }

  void _insertLine(String text) {
    final pos = controller.selection.baseOffset;
    if (pos < 0) return;
    final current = controller.text;
    // Ensure newline before/after
    var newText = current;
    if (pos > 0 && !current.startsWith('\n', pos - 1)) {
      newText = current.replaceRange(pos, pos, '\n');
    }
    final insertPos = pos > 0 && current.startsWith('\n', pos - 1) ? pos : pos + 1;
    newText = newText.replaceRange(insertPos, insertPos, '$text\n');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertPos + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF131313),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Bold (Ctrl+B)',
              onTap: () => _wrapSelection('**'),
              shortcut: LogicalKeyboardKey.keyB,
              controller: controller,
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Italic (Ctrl+I)',
              onTap: () => _wrapSelection('*'),
              shortcut: LogicalKeyboardKey.keyI,
              controller: controller,
            ),
            _ToolbarButton(
              icon: Icons.strikethrough_s,
              tooltip: 'Strikethrough',
              onTap: () => _wrapSelection('~~'),
            ),
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.title,
              tooltip: 'Heading',
              onTap: () => _insertAtStartOfLine('## '),
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet list',
              onTap: () => _insertLine('- '),
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered list',
              onTap: () => _insertLine('1. '),
            ),
            _ToolbarButton(
              icon: Icons.checklist,
              tooltip: 'Checkbox',
              onTap: () => _insertLine('- [ ] '),
            ),
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.code,
              tooltip: 'Inline code',
              onTap: () => _wrapSelection('`'),
            ),
            _ToolbarButton(
              icon: Icons.code_rounded,
              tooltip: 'Code block',
              onTap: () => _insertLine('```\n\n```'),
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              tooltip: 'Blockquote',
              onTap: () => _insertAtStartOfLine('> '),
            ),
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.link,
              tooltip: 'Link',
              onTap: () => _wrapSelection('[', '](url)'),
            ),
            _ToolbarButton(
              icon: Icons.auto_awesome,
              tooltip: 'Wikilink (Ctrl+L)',
              onTap: () => _wrapSelection('[[', ']]'),
              shortcut: LogicalKeyboardKey.keyL,
              controller: controller,
              color: const Color(0xFF7B88FF),
            ),
            _ToolbarButton(
              icon: Icons.horizontal_rule,
              tooltip: 'Horizontal rule',
              onTap: () => _insertLine('\n---\n'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.shortcut,
    this.controller,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final LogicalKeyboardKey? shortcut;
  final TextEditingController? controller;
  final Color? color;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.shortcut != null && widget.controller != null) {
      // We rely on the parent's keyboard listener for shortcuts.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered ? Colors.white.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.color ?? Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}
