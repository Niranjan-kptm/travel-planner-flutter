import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/destinations.dart';
import '../services/recommendation_service.dart';
import '../utils/format.dart';
import '../widgets/sync_status_chip.dart';
import '../widgets/trip_tile.dart';
import 'home_shell.dart';
import 'trip_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showDestination(Destination d) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(d.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(d.country),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(d.description),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in d.types) Chip(label: Text(t)),
              ]),
              const SizedBox(height: 8),
              Text('About ${formatInr(d.dailyCost)} per person per day · '
                  'ideal ${d.minDays}-${d.maxDays} days'),
              const SizedBox(height: 8),
              for (final h in d.highlights) Text('• $h'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    HomeShell.of(context)?.openPlanner(
                        destination: d.name, travelType: d.types.first);
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: Text('Plan a trip to ${d.name}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (action != null) action,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([s.trips, s.profile]),
          builder: (context, _) {
            final profile = s.profile.profile;
            final name = profile?.firstName ?? s.auth.currentUser?.email.split('@').first ?? '';
            final upcoming = s.trips.upcomingTrips;
            final recs = RecommendationService.forUser(profile: profile, trips: s.trips.trips);
            final results = RecommendationService.search(_query);
            return RefreshIndicator(
              onRefresh: () async {
                await s.syncAll();
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Header(
                        greeting: '${greetingFor(DateTime.now())}, $name',
                        tripCount: s.trips.trips.length,
                        upcomingCount: upcoming.length,
                        status: SyncStatusChip(repo: s.trips),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('dashboard_search'),
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search destinations, e.g. beach, Goa, temples',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                ),
                        ),
                      ),
                      if (_query.trim().isNotEmpty) ...[
                        _sectionTitle('Search results (${results.length})'),
                        if (results.isEmpty)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.add_location_alt_outlined),
                              title: Text('"${_query.trim()}" is not in our guide'),
                              subtitle: const Text('Plan it anyway - tap to open the planner'),
                              onTap: () => HomeShell.of(context)
                                  ?.openPlanner(destination: _query.trim()),
                            ),
                          ),
                        for (final d in results)
                          Card(
                            child: ListTile(
                              leading: Text(d.emoji, style: const TextStyle(fontSize: 28)),
                              title: Text('${d.name}, ${d.country}'),
                              subtitle: Text(d.types.join(' · ')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDestination(d),
                            ),
                          ),
                      ],
                      _sectionTitle('Quick actions'),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        FilledButton.icon(
                          onPressed: () => HomeShell.of(context)?.openPlanner(),
                          icon: const Icon(Icons.add),
                          label: const Text('Plan a new trip'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => HomeShell.of(context)?.goTo(2),
                          icon: const Icon(Icons.luggage),
                          label: const Text('My trips'),
                        ),
                      ]),
                      _sectionTitle('Popular destinations'),
                      SizedBox(
                        height: 150,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final d in RecommendationService.popular())
                              _PopularCard(d: d, onTap: () => _showDestination(d)),
                          ],
                        ),
                      ),
                      _sectionTitle('Recommended for you'),
                      Text(
                        profile == null || profile.preferredTravelType.isEmpty
                            ? 'Tip: set your preferred travel type and interests in Profile for better suggestions.'
                            : 'Based on your ${profile.preferredTravelType.toLowerCase()} preference'
                                '${profile.interests.isEmpty ? '' : ' and interests'} (rule-based).',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(builder: (context, c) {
                        final cols = c.maxWidth >= 700 ? 2 : 1;
                        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
                        return Wrap(spacing: 12, runSpacing: 12, children: [
                          for (final r in recs)
                            SizedBox(
                              width: w,
                              child: Card(
                                child: ListTile(
                                  leading: Text(r.destination.emoji,
                                      style: const TextStyle(fontSize: 28)),
                                  title: Text(r.destination.name),
                                  subtitle: Text(
                                    '${r.score}% match · est. ${formatInr(r.estimatedCost)}\n${r.reasons.first}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  onTap: () => _showDestination(r.destination),
                                ),
                              ),
                            ),
                        ]);
                      }),
                      _sectionTitle('Upcoming trips',
                          action: TextButton(
                            onPressed: () => HomeShell.of(context)?.goTo(2),
                            child: const Text('See all'),
                          )),
                      if (s.trips.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (upcoming.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No upcoming trips yet. Plan one to see it here.'),
                          ),
                        )
                      else
                        for (final t in upcoming.take(3))
                          TripTile(
                            trip: t,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TripDetailsScreen(tripId: t.id)),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final int tripCount;
  final int upcomingCount;
  final Widget status;

  const _Header({
    required this.greeting,
    required this.tripCount,
    required this.upcomingCount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(greeting,
                key: const Key('dashboard_greeting'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          status,
        ]),
        const SizedBox(height: 6),
        const Text('Where would you like to go next?',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        Row(children: [
          _Stat(label: 'Trips planned', value: '$tripCount'),
          const SizedBox(width: 24),
          _Stat(label: 'Upcoming', value: '$upcomingCount'),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}

class _PopularCard extends StatelessWidget {
  final Destination d;
  final VoidCallback onTap;
  const _PopularCard({required this.d, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.emoji, style: const TextStyle(fontSize: 34)),
                const Spacer(),
                Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(d.types.first, style: const TextStyle(fontSize: 12)),
                Text('from ${formatInr(d.dailyCost)}/day',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
