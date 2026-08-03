import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import 'note_editor_page.dart';

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({
    super.key,
    required this.controller,
    required this.noteId,
  });

  final RelixController controller;
  final String noteId;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  bool _checking = false;
  bool _hasConflict = false;
  String _searchQuery = '';
  NoteEntry? _remoteConflict;

  @override
  Widget build(BuildContext context) {
    final note = widget.controller.snapshot.notes
        .where((entry) => entry.id == widget.noteId)
        .cast<NoteEntry?>()
        .firstOrNull;

    if (note == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Entry'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Entry not found',
            style: TextStyle(color: Colors.white24),
          ),
        ),
      );
    }

    final noteContent = note.content as NoteContent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NoteEditorPage(
                    controller: widget.controller,
                    existing: note,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, note.id),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              if (note.pendingSync)
                _Banner(
                  color: Colors.amber,
                  text: 'Changes queued for local P2P sync',
                  icon: Icons.sync,
                ),

              if (_hasConflict)
                _Banner(
                  color: Colors.orangeAccent,
                  text: 'Conflict: Remote modification detected.',
                  actionLabel: 'Review',
                  icon: Icons.priority_high_rounded,
                  onAction: _remoteConflict == null
                      ? null
                      : () => _reviewConflict(_remoteConflict!),
                ),

              Text(
                noteContent.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: _formatDate(note.updatedAt),
                  ),
                  ...note.tags
                      .where((t) => !t.contains(':'))
                      .map(
                        (tag) => _InfoChip(
                          icon: Icons.tag_rounded,
                          label: tag,
                          color: const Color(0xFF2DD4BF),
                        ),
                      ),
                  ...note.tags
                      .where((t) => t.startsWith('outlink:'))
                      .map(
                        (tag) => _InfoChip(
                          icon: Icons.link_rounded,
                          label: 'Outlink: ${tag.replaceFirst('outlink:', '')}',
                          color: Colors.blueAccent,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 32),
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'SEARCH_WITHIN_NOTE...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 20),

              SelectableText.rich(
                TextSpan(
                  children: _highlightMatches(
                    noteContent.body,
                    _searchQuery,
                    Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                          height: 1.6,
                          fontSize: 17,
                        ) ??
                        const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                          fontSize: 17,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              _MetadataSection(
                id: note.id,
                owner: note.owner,
                createdAt: note.createdAt,
              ),

              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _checking ? null : _checkUpdates,
                icon: Icon(_checking ? Icons.loop : Icons.sync),
                label: Text(_checking ? 'Syncing...' : 'Sync Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white38,
                  side: const BorderSide(color: Colors.white10),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkUpdates() async {
    setState(() => _checking = true);
    final latest = await widget.controller.fetchLatestRemoteNote(widget.noteId);
    if (mounted) {
      if (latest != null && latest.updatedAt > _currentBaseline()) {
        _hasConflict = true;
        _remoteConflict = latest;
        await _reviewConflict(latest);
      } else {
        _hasConflict = false;
        _remoteConflict = null;
      }
      _checking = false;
      setState(() {});
    }
  }

  Future<void> _reviewConflict(NoteEntry latest) async {
    final current = widget.controller.snapshot.notes
        .where((entry) => entry.id == widget.noteId)
        .cast<NoteEntry?>()
        .firstOrNull;
    final local = current?.asNote;
    final remote = latest.asNote;
    if (local == null || remote == null || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text(
          'REMOTE_CHANGE_DETECTED',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: min(720, MediaQuery.of(context).size.width * 0.85),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOCAL_COPY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _ConflictPane(
                  title: local.title,
                  body: local.body,
                  updatedAt: current!.updatedAt,
                ),
                const SizedBox(height: 20),
                const Text(
                  'REMOTE_COPY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _ConflictPane(
                  title: remote.title,
                  body: remote.body,
                  updatedAt: latest.updatedAt,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: const Text('KEEP_LOCAL'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, 'load_remote'),
            child: const Text('LOAD_REMOTE_COPY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'open_editor'),
            child: const Text('OPEN_EDITOR'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'load_remote') {
      await widget.controller.applyRemoteNote(latest);
      if (!mounted) return;
      setState(() {
        _hasConflict = false;
        _remoteConflict = null;
      });
    } else if (action == 'open_editor') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteEditorPage(
            controller: widget.controller,
            existing: latest,
          ),
        ),
      );
      final refreshed = widget.controller.snapshot.notes
          .where((entry) => entry.id == latest.id)
          .cast<NoteEntry?>()
          .firstOrNull;
      final resolved = refreshed?.baselineUpdatedAt == latest.updatedAt ||
          refreshed?.updatedAt == latest.updatedAt;
      if (mounted && resolved) {
        setState(() {
          _hasConflict = false;
          _remoteConflict = null;
        });
      }
    }
  }

  int _currentBaseline() {
    final note = widget.controller.snapshot.notes
        .where((entry) => entry.id == widget.noteId)
        .cast<NoteEntry?>()
        .firstOrNull;
    return note?.baselineUpdatedAt ?? note?.updatedAt ?? 0;
  }

  List<TextSpan> _highlightMatches(
    String source,
    String query,
    TextStyle baseStyle,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [TextSpan(text: source, style: baseStyle)];

    final spans = <TextSpan>[];
    final lowerSource = source.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    var cursor = 0;

    while (true) {
      final match = lowerSource.indexOf(lowerQuery, cursor);
      if (match < 0) {
        spans.add(TextSpan(text: source.substring(cursor), style: baseStyle));
        break;
      }
      if (match > cursor) {
        spans.add(
          TextSpan(text: source.substring(cursor, match), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: source.substring(match, match + trimmed.length),
          style: baseStyle.copyWith(
            backgroundColor: const Color(
              0xFF7B88FF,
            ).withValues(alpha: 0.24),
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match + trimmed.length;
    }

    return spans;
  }

  void _confirmDelete(BuildContext context, String id) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Entry?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove it from all synced devices. If offline, the deletion is queued.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteNote(id);
      if (mounted) navigator.pop();
    }
  }

  String _formatDate(int seconds) {
    if (seconds <= 0) return 'Just now';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ConflictPane extends StatelessWidget {
  const _ConflictPane({
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String title;
  final String body;
  final int updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'UPDATED_AT $updatedAt',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            body.isEmpty ? '(empty body)' : body,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.white24,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color == Colors.white24 ? Colors.white54 : color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color == Colors.white24 ? Colors.white54 : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
    required this.id,
    required this.owner,
    required this.createdAt,
  });
  final String id;
  final String owner;
  final int createdAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'METADATA',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.white24,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          'ID: $id\nOWNER: ${owner.isEmpty ? "Local" : owner}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white24,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.text,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });
  final Color color;
  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
