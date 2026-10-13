import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/recommendation_service.dart';
import '../utils/format.dart';

/// Compact card for a trip in lists.
class TripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final Widget? trailing;

  const TripTile({Key? key, required this.trip, required this.onTap, this.trailing})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final emoji = RecommendationService.findByName(t.destination)?.emoji ?? '🧳';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(formatDateRange(t.start, t.end),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    '${t.days} day(s) · ${t.travellers} traveller(s) · ${t.travelType} · ${formatInr(t.budget)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: t.synced ? 'Synced to Firebase' : 'Saved on device - waiting to sync',
              child: Icon(t.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                  size: 20, color: t.synced ? Colors.green : Colors.orange),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}
