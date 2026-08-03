import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../services/relix_controller.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final RelixController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final notes = [...snapshot.notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEMPORAL LOG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF7B88FF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recording Archive',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _statusChip(
                        'DAEMON_${snapshot.daemonReachable ? "ONLINE" : "OFFLINE"}',
                        snapshot.daemonReachable
                            ? const Color(0xFF2DD4BF)
                            : Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      _statusChip(
                        '${snapshot.pendingChanges} PENDING_MUTATIONS',
                        snapshot.pendingChanges > 0
                            ? Colors.amber
                            : Colors.white10,
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
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'NO_RECORDS_YET',
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
                final note = notes[index];
                return _buildHistoryEntry(context, note);
              }, childCount: notes.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(BuildContext context, NoteEntry note) {
    final title = note.asNote?.title ?? 'Untitled Trace';
    final date = DateTime.fromMillisecondsSinceEpoch(note.updatedAt * 1000);
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 20),
            decoration: BoxDecoration(
              color: note.pendingSync
                  ? Colors.amber
                  : const Color(0xFF7B88FF).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'TRACE_ID: ${note.id.substring(0, min(8, note.id.length))}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.white10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: note.tags
                      .map(
                        (t) => Text(
                          '#$t',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFA267F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          if (note.pendingSync)
            const Icon(
              Icons.sync_problem_rounded,
              size: 14,
              color: Colors.amber,
            ),
        ],
      ),
    );
  }
}
