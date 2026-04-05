import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/connection_banner.dart';
import 'notes_page.dart';
import 'note_editor_page.dart';
import 'settings_page.dart';
import 'graph_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum HomeView { workstation, graph, settings, history }

class _HomePageState extends State<HomePage> {
  String? _activeNoteId;
  HomeView _currentView = HomeView.workstation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      body: Row(
        children: [
          // 1. Sidebar (Fixed Left)
          SizedBox(width: 260, child: _buildSidebar(context)),
          const VerticalDivider(width: 1),

          // 2. Workbench (Central Editor/Explorer or Specialized View)
          Expanded(
            child: Column(
              children: [
                _buildWorkbenchHeader(context, snapshot),
                const Divider(),
                if (_currentView == HomeView.workstation) ...[
                  ConnectionBanner(snapshot: snapshot),
                  _buildWorkbenchBreadcrumbs(context, snapshot),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(_activeNoteId ?? _currentView.name),
                      child: _buildWorkbenchBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Inspector (Fixed Right) - Desktop Only
          if (isDesktop && _currentView == HomeView.workstation) ...[
            const VerticalDivider(width: 1),
            SizedBox(width: 300, child: _buildInspector(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkbenchHeader(BuildContext context, SyncSnapshot snapshot) {
    if (_currentView != HomeView.workstation) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Theme.of(context).cardTheme.color,
        child: Row(
          children: [_tabItem(_getViewTitle(), active: true), const Spacer()],
        ),
      );
    }
    return _buildWorkbenchTabs(context, snapshot);
  }

  String _getViewTitle() {
    switch (_currentView) {
      case HomeView.graph:
        return 'Neural Topology';
      case HomeView.settings:
        return 'Fleet Control';
      case HomeView.history:
        return 'Temporal Log';
      default:
        return 'Workstation';
    }
  }

  Widget _buildWorkbenchTabs(BuildContext context, SyncSnapshot snapshot) {
    NoteEntry? activeNote;
    if (_activeNoteId != null) {
      activeNote = snapshot.notes.cast<NoteEntry?>().firstWhere(
        (n) => n?.id == _activeNoteId,
        orElse: () => null,
      );
    }

    return Container(
      height: 40,
      color: Theme.of(context).cardTheme.color,
      child: Row(
        children: [
          const SizedBox(width: 8),
          if (_activeNoteId != null)
            _tabItem(
              _activeNoteId == 'new'
                  ? 'New Trace*'
                  : (activeNote?.content.title ?? 'Refreshing...'),
              active: true,
              onClose: () => setState(() => _activeNoteId = null),
            ),
          if (_activeNoteId == null) _tabItem('Memory Explorer', active: true),
          const Spacer(),
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 14,
              color: Colors.white24,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _tabItem(String label, {bool active = false, VoidCallback? onClose}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).scaffoldBackgroundColor : null,
        border: active
            ? Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                left: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 14,
            color: active ? Colors.white70 : Colors.white24,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : Colors.white24,
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: Colors.white24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkbenchBreadcrumbs(
    BuildContext context,
    SyncSnapshot snapshot,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'LEXICON EDITOR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Color(0xFFA267F6), // Secondary Purple
            ),
          ),
          const SizedBox(width: 16),
          _breadcrumbItem('File'),
          _breadcrumbItem('Edit'),
          _breadcrumbItem('View'),
          _breadcrumbItem('Go'),
          _breadcrumbItem('Tools'),
          _breadcrumbItem('Help'),
        ],
      ),
    );
  }

  Widget _breadcrumbItem(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildWorkbenchBody() {
    switch (_currentView) {
      case HomeView.graph:
        return GraphPage(controller: widget.controller);
      case HomeView.settings:
        return SettingsPage(controller: widget.controller);
      case HomeView.history:
        return const Center(
          child: Text(
            'Temporal Logs Loading...',
            style: TextStyle(color: Colors.white12),
          ),
        );
      case HomeView.workstation:
        if (_activeNoteId == 'new') {
          return NoteEditorPage(
            controller: widget.controller,
            onClose: () => setState(() => _activeNoteId = null),
          );
        }
        if (_activeNoteId == null) {
          return NotesPage(
            controller: widget.controller,
            onNoteSelected: (id) => setState(() => _activeNoteId = id),
          );
        }
        final activeNote = widget.controller.snapshot.notes
            .cast<NoteEntry?>()
            .firstWhere((n) => n?.id == _activeNoteId, orElse: () => null);
        if (activeNote == null) {
          return NotesPage(
            controller: widget.controller,
            onNoteSelected: (id) => setState(() => _activeNoteId = id),
          );
        }
        return NoteEditorPage(
          controller: widget.controller,
          onClose: () => setState(() => _activeNoteId = null),
          existing: activeNote,
        );
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Theme.of(context).cardTheme.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBranding(),
          _sidebarItem(
            Icons.auto_awesome_mosaic_outlined,
            'Vaults',
            active: _currentView == HomeView.workstation,
            onTap: () => setState(() => _currentView = HomeView.workstation),
          ),
          _sidebarItem(
            Icons.history_rounded,
            'History',
            active: _currentView == HomeView.history,
            onTap: () => setState(() => _currentView = HomeView.history),
          ),
          _sidebarItem(
            Icons.hub_outlined,
            'Neural Map',
            active: _currentView == HomeView.graph,
            onTap: () => setState(() => _currentView = HomeView.graph),
          ),
          _sidebarItem(
            Icons.settings_outlined,
            'Settings',
            active: _currentView == HomeView.settings,
            onTap: () => setState(() => _currentView = HomeView.settings),
          ),
          _sidebarItem(Icons.archive_outlined, 'Archive'),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'PERSONAL VAULT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white24,
                  ),
                ),
                Spacer(),
                Icon(Icons.add_box_outlined, size: 14, color: Colors.white24),
              ],
            ),
          ),
          Expanded(child: _buildFileTree()),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _activeNoteId = 'new'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Entry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE ARCHIVIST',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Primary Vault',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2DD4BF),
            child: Icon(Icons.person, size: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.05) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : Colors.white24,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTree() {
    final notes = widget.controller.snapshot.notes;
    return ListView(
      children: [
        _treeFolder('Projects'),
        ...notes.take(5).map((n) => _treeItem(n.content.title, n.id)),
        _treeFolder('Archive'),
        _treeItem('Daily Journal', 'journal'),
      ],
    );
  }

  Widget _treeFolder(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.white24,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.folder_rounded, size: 16, color: Colors.white24),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeItem(String title, String id) {
    final active = _activeNoteId == id;
    return InkWell(
      onTap: () => setState(() => _activeNoteId = id),
      child: Padding(
        padding: const EdgeInsets.only(left: 44, top: 4, bottom: 4, right: 16),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 14,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspector(BuildContext context) {
    if (_activeNoteId == null || _activeNoteId == 'new') {
      return const Center(
        child: Text(
          'Target an indexed note to inspect',
          style: TextStyle(color: Colors.white10),
        ),
      );
    }

    final note = widget.controller.snapshot.notes.cast<NoteEntry?>().firstWhere(
      (n) => n?.id == _activeNoteId,
      orElse: () => null,
    );

    if (note == null) {
      return const Center(
        child: Text(
          'Indexing active note...',
          style: TextStyle(color: Colors.white10),
        ),
      );
    }

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSPECTOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white24,
            ),
          ),
          const Text(
            'Contextual Details',
            style: TextStyle(fontSize: 10, color: Colors.white10),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Text(
                'METADATA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'LINKS',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
              SizedBox(width: 16),
              Text(
                'OUTLINE',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 24),
          _inspectorField('Created', _formatDate(note.createdAt)),
          _inspectorField('Last Modified', 'Just now'),
          const SizedBox(height: 24),
          const Text(
            'Keywords',
            style: TextStyle(fontSize: 10, color: Colors.white24),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _inspectorTag('Vault', active: true),
              _inspectorTag('Relix'),
              _inspectorTag('Distributed'),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'GRAPH PREVIEW',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white24,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildGraphPlaceholder(),
          const SizedBox(height: 32),
          const Text(
            '2 BACKLINKS',
            style: TextStyle(fontSize: 9, color: Colors.white24),
          ),
          const SizedBox(height: 12),
          _backlinkItem('Index of Cognitive Tools'),
          _backlinkItem('Weekly Research Log #4'),
          const Spacer(),
          const Row(
            children: [
              Text(
                'Show raw JSON metadata',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                size: 12,
                color: Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inspectorField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white24),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspectorTag(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: active
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.white54,
        ),
      ),
    );
  }

  Widget _backlinkItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"...essential to explore this system for the next sprint..."',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.1),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: CustomPaint(
        painter: _GraphPainter(Theme.of(context).colorScheme.primary),
      ),
    );
  }

  String _formatDate(int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:00Z';
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.primary);
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw grid
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    final rng = Random(42);
    final nodes = List.generate(
      5,
      (_) =>
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
    );

    final nodePaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        if (rng.nextDouble() > 0.6)
          canvas.drawLine(nodes[i], nodes[j], linePaint);
      }
    }

    for (final node in nodes) {
      canvas.drawCircle(node, 3, nodePaint);
    }

    // Highlight center node
    canvas.drawCircle(nodes[0], 5, Paint()..color = primary);
    canvas.drawCircle(
      nodes[0],
      12,
      Paint()..color = primary.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
