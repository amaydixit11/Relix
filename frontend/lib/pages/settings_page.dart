import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models.dart';
import '../services/relix_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _inviteController;
  late final TextEditingController _vaultPathController;
  bool _pairing = false;
  bool _inviting = false;
  bool _exporting = false;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.controller.snapshot.baseUrl,
    );
    _inviteController = TextEditingController();
    _vaultPathController = TextEditingController(
      text: 'Loading...',
    );
    _loadVaultPathDisplay();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _inviteController.dispose();
    _vaultPathController.dispose();
    super.dispose();
  }

  Future<void> _loadVaultPathDisplay() async {
    try {
      final dir = await widget.controller.vault.vaultDir;
      if (mounted) {
        setState(() => _vaultPathController.text = dir.path);
      }
    } catch (_) {}
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FLEET COMMAND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFFA267F6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Network Protocols',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),

                  // Core Identity Section
                  _techSection(
                    title: 'CORE IDENTITY',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshot.identity != null) ...[
                          _identityRow('PEER_ID', snapshot.identity!.peerId),
                          const SizedBox(height: 16),
                          _statusLine(
                            snapshot.connectionType == 'relay'
                                ? 'ROUTING_VIA_RELAY'
                                : snapshot.connectionType == 'direct'
                                ? 'P2P_DIRECT_ESTABLISHED'
                                : 'LOCAL_STANDALONE',
                            snapshot.connectionType != 'offline'
                                ? const Color(0xFF2DD4BF)
                                : Colors.white24,
                            snapshot.connectionType != 'offline'
                                ? Icons.cell_tower_rounded
                                : Icons.offline_bolt_outlined,
                          ),
                        ] else
                          const Text(
                            'DAEMON UNREACHABLE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Connection Config
                  _techSection(
                    title: 'CONNECTION CONFIG',
                    child: TextField(
                      controller: _baseUrlController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'DAEMON_UPLINK_ENDPOINT',
                        hintText: 'http://localhost:7331',
                        prefixIcon: Icon(Icons.lan_rounded, size: 16),
                      ),
                      onSubmitted: (v) async {
                        await widget.controller.setBaseUrl(v);
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Local Vault Path
                  _techSection(
                    title: 'LOCAL VAULT',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes are stored as .md files in your local vault. '
                          'Changes are synced to ACORDE for P2P sharing.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vaultPathController,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                          decoration: InputDecoration(
                            labelText: 'VAULT_DIRECTORY',
                            hintText: '(default — app documents)',
                            prefixIcon: const Icon(Icons.folder_rounded, size: 16),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check_rounded, size: 18),
                              onPressed: _setVaultPath,
                              tooltip: 'SET_VAULT_PATH',
                            ),
                          ),
                          onSubmitted: (v) => _setVaultPath(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Connection Protocols
                  _techSection(
                    title: 'PEER ACQUISITION',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteController,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'INPUT_INVITE_SEQUENCE...',
                                  suffixIcon: IconButton(
                                    onPressed: _pairing ? null : _pairDevice,
                                    icon: Icon(
                                      _pairing
                                          ? Icons.sync_rounded
                                          : Icons.link_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _pairing ? null : _scanQr,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              tooltip: 'SCAN_QR',
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: _inviting ? null : _generateInvite,
                                icon: Icon(
                                  _inviting
                                      ? Icons.hourglass_empty
                                      : Icons.qr_code_2_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _inviting ? 'GENERATING...' : 'GENERATE_CODE',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Fleet Status Grid
                  Row(
                    children: [
                      _infoCard(
                        'FLEET_NODES',
                        peers.length.toString(),
                        Icons.hub_outlined,
                      ),
                      const SizedBox(width: 16),
                      _infoCard(
                        'LATENCY_MS',
                        snapshot.daemonReachable ? '<50' : '—',
                        Icons.speed_rounded,
                        color: snapshot.daemonReachable
                            ? Colors.blueAccent
                            : Colors.white24,
                      ),
                      const SizedBox(width: 16),
                      _infoCard(
                        'PENDING_OPS',
                        snapshot.pendingChanges.toString(),
                        Icons.queue_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  if (peers.isNotEmpty) ...[
                    const Text(
                      'ACTIVE FLEET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...peers.map((p) => _peerItem(p)),
                  ],

                  if (snapshot.stuckMutations > 0) ...[
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: widget.controller.clearStuckMutations,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'WIPE_STUCK_OPERATIONS (${snapshot.stuckMutations})',
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Data Management Section
                  _techSection(
                    title: 'DATA MANAGEMENT',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _dataActionCard(
                                'EXPORT_ALL_NOTES',
                                'Download all notes as ZIP',
                                Icons.file_download_rounded,
                                _exporting,
                                _exportAll,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dataActionCard(
                                'FORCE_SYNC',
                                'Refresh from daemon',
                                Icons.sync_rounded,
                                _clearingCache,
                                _forceSync,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _techSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _identityRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.white10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white54,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('ID COPIED')));
          },
          icon: const Icon(
            Icons.copy_all_rounded,
            size: 14,
            color: Colors.white10,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, {Color? color}) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: themeColor),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peerItem(RemotePeer peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Row(
        children: [
          Icon(
            peer.isConnected
                ? Icons.sensors_rounded
                : Icons.sensors_off_rounded,
            size: 18,
            color: peer.isConnected ? const Color(0xFF2DD4BF) : Colors.white10,
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  peer.id.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: Colors.white10,
                  ),
                ),
              ],
            ),
          ),
          if (peer.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'UPLINK_ACTIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2DD4BF),
                ),
              ),
            ),
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('DEVICE_PAIRED')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PAIR_ERR: $e')));
      }
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  void _scanQr() async {
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text('SCAN_INVITE_TARGET', style: TextStyle(fontSize: 12)),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  Navigator.pop(c, barcodes.first.rawValue);
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );

    if (code != null && mounted) {
      _inviteController.text = code;
      _pairDevice();
    }
  }

  Widget _statusLine(String text, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _dataActionCard(
    String title,
    String subtitle,
    IconData icon,
    bool loading,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: loading
                      ? Colors.white10
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EXPORT_COMPLETE')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EXPORT_FAILED: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _forceSync() async {
    setState(() => _clearingCache = true);
    try {
      await widget.controller.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SYNC_COMPLETE')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SYNC_FAILED: $e')),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _setVaultPath() async {
    final path = _vaultPathController.text.trim();
    if (path.isEmpty || path.startsWith('(')) return;
    try {
      await widget.controller.setVaultPath(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VAULT_PATH_SET — refreshing...')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VAULT_PATH_ERROR: $e')),
      );
    }
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
