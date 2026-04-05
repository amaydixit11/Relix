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

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final notes = snapshot.notes.where((e) => e.type == 'note').where((e) {
      if (_searchQuery.isEmpty) return true;
      final content = e.content as NoteContent;
      final q = _searchQuery.toLowerCase();
      return content.title.toLowerCase().contains(q) ||
          content.body.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

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
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
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
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
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
        onChanged: (v) => setState(() => _searchQuery = v),
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
}
