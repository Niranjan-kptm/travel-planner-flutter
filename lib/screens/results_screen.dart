import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/trip.dart';
import '../services/itinerary_service.dart';
import '../services/recommendation_service.dart';
import '../utils/format.dart';
import '../widgets/destination_card.dart';
import 'trip_form_screen.dart';

class ResultsScreen extends StatefulWidget {
  final TripQuery query;
  final DateTime startDate;
  final DateTime endDate;

  const ResultsScreen({
    Key? key,
    required this.query,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final Set<String> _saved = <String>{};
  late final List<Recommendation> _results;

  @override
  void initState() {
    super.initState();
    _results = RecommendationService.recommend(widget.query);
  }

  /// Opens the trip form pre-filled with this destination and a generated
  /// itinerary; the trip is stored when the user taps Save there.
  Future<void> _plan(Recommendation r) async {
    final q = widget.query;
    final d = r.destination;
    final repo = AppScope.of(context).trips;
    final draft = Trip(
      id: repo.newId(),
      destination: d.name,
      startDate: isoDate(widget.startDate),
      endDate: isoDate(widget.endDate),
      budget: q.budget,
      travellers: q.travellers,
      travelType: q.travelType,
      preferences: q.preferences,
      itinerary: ItineraryService.generate(
        destination: d.name,
        days: q.days,
        travelType: q.travelType,
        preferences: q.preferences,
      ),
      notes: 'Highlights: ${d.highlights.join(', ')}',
      estimatedCost: r.estimatedCost,
      createdAt: 0,
      updatedAt: 0,
    );
    final saved = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => TripFormScreen(initial: draft, isNew: true)),
    );
    if (saved != null && mounted) setState(() => _saved.add(d.name));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final typed = q.destination.trim();
    final anyNameMatch = _results.any((r) => r.nameMatched);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final contentW = (c.maxWidth - 32).clamp(280.0, 1000.0).toDouble();
            final cols = contentW >= 800 ? 2 : 1;
            const gap = 12.0;
            final cardW = (contentW - gap * (cols - 1)) / cols;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: contentW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Your request: ${q.travelType} • '
                            '${formatDateRange(widget.startDate, widget.endDate)} (${q.days} day(s)) • '
                            '${q.travellers} traveller(s) • ${formatInr(q.budget)} total budget'
                            '${q.preferences.isEmpty ? '' : ' • ${q.preferences.join(', ')}'}'
                            '${typed.isEmpty ? '' : ' • "$typed"'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (typed.isNotEmpty && !anyNameMatch)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '"$typed" is not in the built-in guide, so these are similar '
                            'suggestions. Use "Create trip with itinerary" on the planner to plan it anyway.',
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Ranked by a rule-based score (not a trained AI model). '
                          'Costs are illustrative estimates, not live prices.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: _results
                            .map((r) => SizedBox(
                                  width: cardW,
                                  child: DestinationCard(
                                    rec: r,
                                    saved: _saved.contains(r.destination.name),
                                    onSave: () => _plan(r),
                                  ),
                                ))
                            .toList(),
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
