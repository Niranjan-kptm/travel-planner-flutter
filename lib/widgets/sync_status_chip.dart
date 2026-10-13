import 'package:flutter/material.dart';

import '../services/trip_repository.dart';

/// Small indicator of the cloud connection state.
class SyncStatusChip extends StatelessWidget {
  final TripRepository repo;
  const SyncStatusChip({Key? key, required this.repo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final pending = repo.pendingCount;
        late final IconData icon;
        late final Color color;
        late String text;
        switch (repo.cloudState) {
          case CloudState.notConfigured:
            icon = Icons.cloud_off;
            color = Colors.grey;
            text = 'Offline only';
            break;
          case CloudState.connecting:
            icon = Icons.cloud_sync;
            color = Colors.blueGrey;
            text = 'Syncing...';
            break;
          case CloudState.live:
            icon = Icons.cloud_done;
            color = Colors.green;
            text = 'Live';
            break;
          case CloudState.synced:
            icon = Icons.cloud_done;
            color = Colors.teal;
            text = 'Synced';
            break;
          case CloudState.offline:
            icon = Icons.cloud_off;
            color = Colors.orange;
            text = 'Offline';
            break;
        }
        if (pending > 0) text = '$text · $pending pending';
        return Tooltip(
          message: repo.lastError.isEmpty ? text : '$text\n${repo.lastError}',
          child: Chip(
            avatar: Icon(icon, size: 18, color: color),
            label: Text(text, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }
}
