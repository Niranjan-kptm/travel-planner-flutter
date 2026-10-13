import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/trip.dart';
import '../widgets/sync_status_chip.dart';
import '../widgets/trip_tile.dart';
import 'trip_details_screen.dart';
import 'trip_form_screen.dart';

enum _Filter { all, upcoming, past }

/// My trips: Read (live list), Create, Update, Delete and manual sync.
class SavedTripsScreen extends StatefulWidget {
  const SavedTripsScreen({Key? key}) : super(key: key);

  @override
  State<SavedTripsScreen> createState() => _SavedTripsScreenState();
}

class _SavedTripsScreenState extends State<SavedTripsScreen> {
  _Filter _filter = _Filter.all;
  String _search = '';
  bool _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await AppScope.of(context).syncAll();
    if (!mounted) return;
    setState(() => _syncing = false);
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<void> _confirmDelete(Trip t) async {
    final repo = AppScope.of(context).trips;
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text('Remove "${t.destination}" from this device and the cloud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              key: const Key('confirm_delete'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await repo.delete(t.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Trip deleted' : 'Deleted on device - cloud delete will retry when online'),
    ));
  }

  List<Trip> _visible(List<Trip> all) {
    final q = _search.trim().toLowerCase();
    return all.where((t) {
      if (_filter == _Filter.upcoming && !t.isUpcoming()) return false;
      if (_filter == _Filter.past && t.isUpcoming()) return false;
      if (q.isNotEmpty &&
          !t.destination.toLowerCase().contains(q) &&
          !t.travelType.toLowerCase().contains(q) &&
          !t.notes.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).trips;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My trips'),
        actions: [
          SyncStatusChip(repo: repo),
          _syncing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  key: const Key('trips_sync'),
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync with Firebase',
                  onPressed: _sync,
                ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: AnimatedBuilder(
              animation: repo,
              builder: (context, _) {
                if (repo.loading) return const Center(child: CircularProgressIndicator());
                final trips = _visible(repo.trips);
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      key: const Key('trips_search'),
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search my trips',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SegmentedButton<_Filter>(
                      segments: const [
                        ButtonSegment(value: _Filter.all, label: Text('All')),
                        ButtonSegment(value: _Filter.upcoming, label: Text('Upcoming')),
                        ButtonSegment(value: _Filter.past, label: Text('Past')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) => setState(() => _filter = s.first),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _sync,
                      child: trips.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 100),
                              const Icon(Icons.luggage_outlined, size: 56, color: Colors.grey),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  repo.trips.isEmpty
                                      ? 'No trips yet.\nUse the planner or tap "New trip".'
                                      : 'No trips match your filter.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                              itemCount: trips.length,
                              itemBuilder: (context, i) {
                                final t = trips[i];
                                return TripTile(
                                  key: ValueKey(t.id),
                                  trip: t,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => TripDetailsScreen(tripId: t.id)),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Trip actions',
                                    onSelected: (v) {
                                      if (v == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  TripFormScreen(initial: t, isNew: false)),
                                        );
                                      } else {
                                        _confirmDelete(t);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('trips_new'),
        heroTag: 'new_trip',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TripFormScreen(isNew: true)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
    );
  }
}
