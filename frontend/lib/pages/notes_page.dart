import 'dart:async';

import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/note_card.dart';
import 'note_editor_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.controller, this.onNoteSelected});

  final RelixController controller;
  final Function(String)? onNoteSelected;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _searchQuery = '';
  bool _exporting = false;
  List<NoteEntry>? _cachedNotes;
  String? _lastSnapshotId;
  Timer? _debounceTimer;

  List<NoteEntry> _getFilteredNotes() {
    final snapshot = widget.controller.snapshot;
    final cacheKey = '${_searchQuery}_${snapshot.notes.length}_${snapshot.lastSyncAt ?? 0}';
    if (cacheKey == _lastSnapshotId && _cachedNotes != null) {
      return _cachedNotes!;
    }

    final notes = snapshot.notes.where((e) => e.type == 'note').where((e) {
      if (_searchQuery.isEmpty) return true;
      final content = e.content as NoteContent;
      final q = _searchQuery.toLowerCase();
      return content.title.toLowerCase().contains(q) ||
          content.body.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    _cachedNotes = notes;
    _lastSnapshotId = cacheKey;
    return notes;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final notes = _getFilteredNotes();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: widget.controller.refresh,
        displacement: 40,
        color: const Color(0xFF7B88FF),
        backgroundColor: const Color(0xFF0F0F0F),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEURAL REPOSITORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF7B88FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Memoranda Index',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notes.isEmpty
                          ? 'INITIALIZING_NEURAL_VAULT...'
                          : '${notes.length} SECURE_ENTRIES_INDEXED',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white10,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSearchBar(context),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _exporting ? null : _exportAll,
                          icon: Icon(
                            _exporting
                                ? Icons.hourglass_top_rounded
                                : Icons.file_download_rounded,
                            size: 16,
                          ),
                          label: Text(_exporting ? 'EXPORTING...' : 'EXPORT'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7B88FF),
                            side: const BorderSide(
                              color: Color(0xFF7B88FF),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: notes.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_awesome_mosaic_outlined,
                              size: 48,
                              color: Colors.white10,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              snapshot.daemonReachable
                                  ? 'NO_DATA_INDEXED'
                                  : 'UPLINK_IN_PROGRESS...',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white10,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          timeLabel: _formatTime(note.updatedAt),
                          onTap: () {
                            if (widget.onNoteSelected != null) {
                              widget.onNoteSelected!(note.id);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NoteEditorPage(
                                    controller: widget.controller,
                                    existing: note,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      }, childCount: notes.length),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: TextField(
        onChanged: (v) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _searchQuery = v);
          });
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'RECALL_SEQUENCES...',
          hintStyle: const TextStyle(
            color: Colors.white10,
            fontSize: 11,
            letterSpacing: 1,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return 'Just now';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}';
  }

  Future<void> _exportAll() async {
    setState(() => _exporting = true);
    try {
      final notes = widget.controller.snapshot.notes
          .where((e) => e.type == 'note')
          .toList();
      if (notes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NO_NOTES_TO_EXPORT')),
        );
        return;
      }
      await widget.controller.export.shareAll(notes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EXPORT_FAILED: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
