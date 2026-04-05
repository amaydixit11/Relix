import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/connection_banner.dart';
import 'notes_page.dart';
import 'note_editor_page.dart';
import 'settings_page.dart';
import 'graph_page.dart';
import 'history_page.dart';

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
  GraphData? _activeGraphData;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  void _onActiveNoteChanged(String? id) {
    setState(() {
      _activeNoteId = id;
      _activeGraphData = null;
    });
    if (id != null && id != 'new') {
      _loadActiveGraph(id);
    }
  }

  Future<void> _loadActiveGraph(String id) async {
    try {
      final data = await widget.controller.graph.getNeighbors(id, depth: 1);
      if (mounted && _activeNoteId == id) {
        setState(() => _activeGraphData = data);
      }
    } catch (_) {}
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
        return 'TEMPORAL LOG';
      default:
        return 'Workstation';
    }
  }

  Widget _buildWorkbenchTabs(BuildContext context, SyncSnapshot snapshot) {
    NoteEntry? activeNote;
    if (_activeNoteId != null && _activeNoteId != 'new') {
      activeNote = snapshot.notes.cast<NoteEntry?>().firstWhere(
        (n) => n?.id == _activeNoteId,
        orElse: () => null,
      );
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF131313),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          if (_activeNoteId != null)
            _tabItem(
              _activeNoteId == 'new'
                  ? 'New Trace.md'
                  : '${activeNote?.asNote?.title ?? 'Refreshing'}.md',
              active: true,
              onClose: () => _onActiveNoteChanged(null),
            ),
          if (_activeNoteId == null)
            _tabItem('Neural Repository', active: true),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: Colors.white24,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _tabItem(String label, {bool active = false, VoidCallback? onClose}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0F0F0F) : Colors.transparent,
        border: active
            ? const Border(
                top: BorderSide(color: Color(0xFF7B88FF), width: 2),
                left: BorderSide(color: Color(0xFF1F1F1F)),
                right: BorderSide(color: Color(0xFF1F1F1F)),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 14,
            color: Colors.white30,
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
            const SizedBox(width: 12),
            InkWell(
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                size: 10,
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          const Text(
            'LEXICON EDITOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Color(0xFF7B88FF),
            ),
          ),
          const SizedBox(width: 48),
          _menuItem('File'),
          _menuItem('Edit', active: true),
          _menuItem('View'),
          _menuItem('Go'),
          _menuItem('Tools'),
          _menuItem('Help'),
        ],
      ),
    );
  }

  Widget _menuItem(String label, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: active ? Colors.white : Colors.white24,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          decoration: active ? TextDecoration.underline : null,
          decorationThickness: 1,
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
        return HistoryPage(controller: widget.controller);
      case HomeView.workstation:
        if (_activeNoteId == 'new') {
          return NoteEditorPage(
            controller: widget.controller,
            onClose: () => _onActiveNoteChanged(null),
          );
        }
        if (_activeNoteId == null) {
          return NotesPage(
            controller: widget.controller,
            onNoteSelected: _onActiveNoteChanged,
          );
        }
        final activeNote = widget.controller.snapshot.notes
            .cast<NoteEntry?>()
            .firstWhere((n) => n?.id == _activeNoteId, orElse: () => null);
        if (activeNote == null) {
          return NotesPage(
            controller: widget.controller,
            onNoteSelected: _onActiveNoteChanged,
          );
        }
        return NoteEditorPage(
          controller: widget.controller,
          onClose: () => _onActiveNoteChanged(null),
          existing: activeNote,
        );
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: const Color(0xFF131313),
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
          _sidebarItem(Icons.search_rounded, 'Search', active: false),
          _sidebarItem(
            Icons.settings_outlined,
            'Settings',
            active: _currentView == HomeView.settings,
            onTap: () => setState(() => _currentView = HomeView.settings),
          ),
          _sidebarItem(Icons.archive_outlined, 'Archive'),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'PERSONAL VAULT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white24,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _onActiveNoteChanged('new'),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildFileTree()),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => _onActiveNoteChanged('new'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B88FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF7B88FF).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: Color(0xFF7B88FF)),
                    SizedBox(width: 8),
                    Text(
                      'New Entry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7B88FF),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'THE ARCHIVIST',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF2DD4BF),
                child: const Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Primary Vault',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white24,
              fontWeight: FontWeight.w600,
            ),
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
            color: active ? Colors.white.withOpacity(0.05) : null,
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
    final notes = widget.controller.snapshot.notes
        .where((n) => n.type == 'note')
        .toList();
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        _treeFolder('Projects', open: true),
        ...notes.map((n) => _treeItem(n.asNote?.title ?? 'Untitled', n.id)),
        _treeFolder('Archive'),
        _treeItem('Daily Journal', 'journal'),
      ],
    );
  }

  Widget _treeFolder(String name, {bool open = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            open
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_right_rounded,
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
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeItem(String title, String id) {
    final active = _activeNoteId == id;
    return InkWell(
      onTap: () => _onActiveNoteChanged(id),
      child: Container(
        height: 32,
        margin: const EdgeInsets.only(left: 44, right: 12, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7B88FF).withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(4),
          border: active
              ? Border.all(color: const Color(0xFF7B88FF).withOpacity(0.2))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 14,
              color: active ? const Color(0xFF7B88FF) : Colors.white24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white54,
                  letterSpacing: -0.2,
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
      return Container(
        color: const Color(0xFF131313),
        child: const Center(
          child: Text(
            'Target an indexed note to inspect',
            style: TextStyle(color: Colors.white10, fontSize: 11),
          ),
        ),
      );
    }

    final note = widget.controller.snapshot.notes.cast<NoteEntry?>().firstWhere(
      (n) => n?.id == _activeNoteId,
      orElse: () => null,
    );

    if (note == null) return const SizedBox();

    return Container(
      color: const Color(0xFF131313),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSPECTOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Text(
                'METADATA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7B88FF),
                ),
              ),
              SizedBox(width: 24),
              Text(
                'LINKS',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
              SizedBox(width: 24),
              Text(
                'OUTLINE',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
            ],
          ),
          const Divider(height: 32),
          _inspectorField('Created', _formatDate(note.createdAt)),
          _inspectorField('Last Modified', 'Just now'),
          const SizedBox(height: 16),
          const Text(
            'Keywords',
            style: TextStyle(fontSize: 10, color: Colors.white24),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inspectorTag('Vault', active: true),
              _inspectorTag('Neural'),
              _inspectorTag('Distributed'),
            ],
          ),
          const SizedBox(height: 40),
          const Text(
            'GRAPH PREVIEW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 16),
          _buildGraphPlaceholder(),
          const SizedBox(height: 40),
          const Text(
            '2 BACKLINKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 16),
          _backlinkItem('Index of Cognitive Tools'),
          _backlinkItem('Weekly Research Log #4'),
          const Spacer(),
          const Row(
            children: [
              Text(
                'Show raw JSON metadata',
                style: TextStyle(fontSize: 11, color: Colors.white24),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1F1F1F)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
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
            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
            : Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: active
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
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
              color: Colors.white.withOpacity(0.1),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphPlaceholder() {
    if (_activeGraphData == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white10,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _GraphPainter(const Color(0xFF7B88FF), _activeGraphData!),
        ),
      ),
    );
  }

  String _formatDate(int seconds) {
    if (seconds <= 0) return '2024-05-12T14:20:00Z';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:00Z';
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.primary, this.data);
  final Color primary;
  final GraphData data;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    if (data.nodes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final nodePositions = <String, Offset>{};

    // Focus node at center
    final focusNode = data.nodes.first;
    nodePositions[focusNode.id] = center;

    // Neighbors in a circle
    final neighborNodes = data.nodes.skip(1).toList();
    for (int i = 0; i < neighborNodes.length; i++) {
      final angle = (2 * pi / neighborNodes.length) * i;
      final radius = min(size.width, size.height) * 0.35;
      nodePositions[neighborNodes[i].id] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    }

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    for (final edge in data.edges) {
      final p1 = nodePositions[edge.source];
      final p2 = nodePositions[edge.target];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    for (final nodeId in nodePositions.keys) {
      final pos = nodePositions[nodeId]!;
      final isFocus = nodeId == focusNode.id;
      if (isFocus) {
        canvas.drawCircle(pos, 6, Paint()..color = primary.withOpacity(0.2));
        canvas.drawCircle(pos, 3, Paint()..color = primary);
      } else {
        canvas.drawCircle(pos, 2, Paint()..color = Colors.white24);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
