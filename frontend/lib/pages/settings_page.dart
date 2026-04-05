import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/glass_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _inviteController;
  final Map<String, TextEditingController> _peerControllers = {};
  bool _advancedOpen = false;
  bool _pairing = false;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.controller.snapshot.baseUrl,
    );
    _inviteController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _inviteController.dispose();
    for (final controller in _peerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final peers = snapshot.peers;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet Settings',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your private P2P network',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('IDENTITY'),
                    if (snapshot.identity != null) ...[
                      SelectableText(
                        snapshot.identity!.peerId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statusLine(
                        snapshot.connectionType == 'relay'
                            ? 'Synced via relay'
                            : snapshot.connectionType == 'direct'
                            ? 'Synced directly'
                            : 'Standalone connection',
                        snapshot.connectionType != 'offline'
                            ? Colors.greenAccent
                            : Colors.white24,
                        snapshot.connectionType != 'offline'
                            ? Icons.sensors_rounded
                            : Icons.offline_bolt_outlined,
                      ),
                    ] else
                      const Text(
                        'Daemon Offline. Please check base URL.',
                        style: TextStyle(color: Colors.redAccent),
                      ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _inviting ? null : _generateInvite,
                            icon: Icon(
                              _inviting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.person_add_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _inviting ? 'Generating...' : 'Add Peer',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2DD4BF),
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () =>
                              setState(() => _advancedOpen = !_advancedOpen),
                          icon: Icon(
                            _advancedOpen
                                ? Icons.info_outline
                                : Icons.settings_input_component_outlined,
                            color: Colors.white70,
                          ),
                          tooltip: 'Advanced Settings',
                        ),
                      ],
                    ),

                    if (_advancedOpen) ...[
                      const SizedBox(height: 24),
                      TextField(
                        controller: _baseUrlController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          labelText: 'ACORDE API URL',
                          labelStyle: const TextStyle(color: Colors.white24),
                          hintText: 'http://localhost:7331',
                          hintStyle: const TextStyle(color: Colors.white10),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => widget.controller.setBaseUrl(
                          _baseUrlController.text,
                        ),
                        child: const Text(
                          'UPDATE BASE URL',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    _sectionLabel('PAIRING'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter invite code from another device...',
                        hintStyle: const TextStyle(color: Colors.white10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _pairing ? null : _pairDevice,
                          icon: Icon(
                            _pairing ? Icons.refresh : Icons.link_rounded,
                            color: const Color(0xFF2DD4BF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('SYNC STATUS'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statusCard(
                        'Peers',
                        '${peers.where((p) => p.isConnected).length}',
                        Icons.group_rounded,
                        Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      _statusCard(
                        'Pending',
                        '${snapshot.pendingChanges}',
                        Icons.cloud_sync_rounded,
                        Colors.amberAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (peers.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(child: _sectionLabel('PAIRED FLEET')),
            ),

          if (peers.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final peer = peers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: peer.isConnected
                                  ? Colors.greenAccent.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              peer.isConnected
                                  ? Icons.language_rounded
                                  : Icons.public_off_rounded,
                              size: 20,
                              color: peer.isConnected
                                  ? Colors.greenAccent
                                  : Colors.white12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  peer.effectiveName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  peer.id.substring(0, 8) + '...',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (peer.isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ONLINE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }, childCount: peers.length),
              ),
            ),

          if (snapshot.stuckMutations > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: OutlinedButton(
                  onPressed: widget.controller.clearStuckMutations,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                  ),
                  child: Text(
                    'WIPE STUCK MUTATIONS (${snapshot.stuckMutations})',
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _generateInvite() async {
    setState(() => _inviting = true);
    final invite = await widget.controller.generateInvite();
    if (mounted) {
      setState(() => _inviting = false);
      showDialog(
        context: context,
        builder: (c) => _InviteDialog(invite: invite),
      );
    }
  }

  void _pairDevice() async {
    setState(() => _pairing = true);
    try {
      await widget.controller.pairDevice(_inviteController.text.trim());
      _inviteController.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device paired successfully')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pairing failed: $e')));
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: Colors.white24,
      ),
    );
  }

  Widget _statusLine(String text, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statusCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteDialog extends StatelessWidget {
  const _InviteDialog({required this.invite});
  final String invite;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'PAIRED INVITE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: invite,
            version: QrVersions.auto,
            size: 200,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.white,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SelectableText(
            invite,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: invite));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Invite code copied')));
          },
          child: const Text(
            'COPY CODE',
            style: TextStyle(color: Color(0xFF2DD4BF)),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            foregroundColor: const Color(0xFF0F172A),
          ),
          child: const Text('DONE'),
        ),
      ],
    );
  }
}
