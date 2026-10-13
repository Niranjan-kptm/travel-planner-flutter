import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/trip.dart';
import '../services/recommendation_service.dart';
import '../utils/format.dart';
import 'trip_form_screen.dart';

/// Read view of a trip; updates live when the trip changes on another device.
class TripDetailsScreen extends StatelessWidget {
  final String tripId;
  const TripDetailsScreen({Key? key, required this.tripId}) : super(key: key);

  Future<void> _delete(BuildContext context, Trip t) async {
    final s = AppScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text('Remove "${t.destination}" from this device and the cloud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final ok = await s.trips.delete(t.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Trip deleted' : 'Deleted on device - cloud delete will retry when online'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).trips;
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final t = repo.byId(tripId);
        if (t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This trip no longer exists.')),
          );
        }
        final emoji = RecommendationService.findByName(t.destination)?.emoji ?? '🧳';
        final scheme = Theme.of(context).colorScheme;
        final ratio = t.estimatedCost > 0 && t.budget > 0 ? t.estimatedCost / t.budget : 0.0;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.destination),
            actions: [
              IconButton(
                key: const Key('details_edit'),
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TripFormScreen(initial: t, isNew: false)),
                ),
              ),
              IconButton(
                key: const Key('details_delete'),
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, t),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(emoji, style: const TextStyle(fontSize: 40)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.destination,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                Text(formatDateRange(t.start, t.end)),
                              ]),
                            ),
                            Chip(
                              avatar: Icon(t.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                                  size: 18, color: t.synced ? Colors.green : Colors.orange),
                              label: Text(t.synced ? 'Synced' : 'Pending'),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            Chip(label: Text('${t.days} day(s)')),
                            Chip(label: Text('${t.travellers} traveller(s)')),
                            Chip(label: Text(t.travelType)),
                            for (final p in t.preferences) Chip(label: Text(p)),
                          ]),
                          const SizedBox(height: 12),
                          Text('Budget: ${formatInr(t.budget)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (t.estimatedCost > 0) ...[
                            const SizedBox(height: 4),
                            Text('Estimated cost: ${formatInr(t.estimatedCost)} '
                                '(${(ratio * 100).round()}% of budget)'),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0).toDouble(),
                              color: ratio > 1 ? scheme.error : scheme.primary,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          if (t.notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(t.notes),
                          ],
                        ]),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Text('Itinerary',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (t.itinerary.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No itinerary yet. Tap Edit to generate one.'),
                        ),
                      ),
                    for (final d in t.itinerary)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${d.day}')),
                          title: Text('Day ${d.day}: ${d.title}'),
                          subtitle: Text(d.activities.map((a) => '• $a').join('\n')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
