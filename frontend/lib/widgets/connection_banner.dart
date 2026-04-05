import 'package:flutter/material.dart';
import '../models.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.snapshot});

  final SyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final online = snapshot.daemonReachable;
    final color = online ? Colors.greenAccent : Colors.redAccent;
    final message = online
        ? snapshot.pendingChanges > 0
              ? 'Connected • ${snapshot.pendingChanges} changes pending sync'
              : 'Connected • ${snapshot.peers.where((peer) => peer.isConnected).length} peer(s) online'
        : 'Offline • working from local cache';

    return Container(
      width: double.infinity,
      color: color.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
