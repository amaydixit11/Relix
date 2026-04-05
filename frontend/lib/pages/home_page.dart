import 'package:flutter/material.dart';
import '../services/relix_controller.dart';
import '../widgets/connection_banner.dart';
import 'notes_page.dart';
import 'graph_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;

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
    final useRail = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (useRail) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    ConnectionBanner(snapshot: snapshot),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(_tabIndex),
                          child: _buildBody(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: useRail
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                elevation: 0,
                backgroundColor: const Color(0xFF020617),
                indicatorColor: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                selectedIndex: _tabIndex,
                onDestinationSelected: (value) =>
                    setState(() => _tabIndex = value),
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  _navDestination(
                    Icons.auto_awesome_mosaic_outlined,
                    Icons.auto_awesome_mosaic_rounded,
                    'Vault',
                  ),
                  _navDestination(
                    Icons.webhook_outlined,
                    Icons.webhook_rounded,
                    'Neural',
                  ),
                  _navDestination(
                    Icons.hub_outlined,
                    Icons.hub_rounded,
                    'Fleet',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return NotesPage(controller: widget.controller);
      case 1:
        return GraphPage(controller: widget.controller);
      case 2:
        return SettingsPage(controller: widget.controller);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSidebar() {
    return NavigationRail(
      selectedIndex: _tabIndex,
      onDestinationSelected: (value) => setState(() => _tabIndex = value),
      extended: true,
      backgroundColor: Colors.transparent,
      indicatorColor: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
      selectedLabelTextStyle: const TextStyle(
        color: Color(0xFF2DD4BF),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: Colors.white24,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Color(0xFF2DD4BF),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'RELIX',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      destinations: [
        _railDestination(
          Icons.auto_awesome_mosaic_outlined,
          Icons.auto_awesome_mosaic_rounded,
          'Memory Vault',
        ),
        _railDestination(
          Icons.webhook_outlined,
          Icons.webhook_rounded,
          'Neural Map',
        ),
        _railDestination(Icons.hub_outlined, Icons.hub_rounded, 'Neural Fleet'),
      ],
    );
  }

  NavigationDestination _navDestination(
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    return NavigationDestination(
      icon: Icon(icon, color: Colors.white24),
      selectedIcon: Icon(activeIcon, color: const Color(0xFF2DD4BF)),
      label: label,
    );
  }

  NavigationRailDestination _railDestination(
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    return NavigationRailDestination(
      padding: const EdgeInsets.symmetric(vertical: 12),
      icon: Icon(icon, color: Colors.white24, size: 24),
      selectedIcon: Icon(activeIcon, color: const Color(0xFF2DD4BF), size: 24),
      label: Text(label),
    );
  }
}
