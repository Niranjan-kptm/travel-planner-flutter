import 'package:flutter/material.dart';

import '../services/trip_repository.dart';
import '../utils/format.dart';

/// Shows which storage engines are active and the sync state.
class StorageStatusCard extends StatelessWidget {
  final TripRepository repo;

  const StorageStatusCard({Key? key, required this.repo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final cloudOn = repo.cloud.isConfigured;
        final last = repo.lastSyncAt;
        String cloudText;
        switch (repo.cloudState) {
          case CloudState.notConfigured:
            cloudText = 'Cloud: not configured - offline-only mode';
            break;
          case CloudState.live:
            cloudText = 'Cloud: Firebase Realtime Database - live updates on';
            break;
          case CloudState.synced:
            cloudText = 'Cloud: Firebase Realtime Database - synced';
            break;
          case CloudState.connecting:
            cloudText = 'Cloud: connecting to Firebase...';
            break;
          case CloudState.offline:
            cloudText = 'Cloud: offline - changes will sync automatically';
            break;
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.storage, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Local: ${repo.local.label}')),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(cloudOn ? Icons.cloud_done : Icons.cloud_off,
                      size: 18, color: cloudOn ? Colors.green : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cloudText)),
                ]),
                if (repo.pendingCount > 0 || last != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${repo.pendingCount} change(s) waiting to upload'
                    '${last != null ? ' · last sync ${formatDate(last)} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (repo.lastError.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(repo.lastError,
                      style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
