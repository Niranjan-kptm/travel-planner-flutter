import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/destinations.dart';
import '../models/trip.dart';
import '../services/itinerary_service.dart';
import '../services/recommendation_service.dart';
import '../utils/format.dart';
import '../widgets/preference_chips.dart';
import '../widgets/travel_type_selector.dart';
import 'results_screen.dart';
import 'trip_form_screen.dart';

/// Trip planner: destination, dates, budget (INR), travellers, travel type
/// and interests. Either shows ranked recommendations or builds a trip with
/// a generated itinerary for the typed destination.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({Key? key}) : super(key: key);

  @override
  State<PlannerScreen> createState() => PlannerScreenState();
}

class PlannerScreenState extends State<PlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _destCtrl;
  final _budgetCtrl = TextEditingController(text: '30000');
  late DateTimeRange _dates;
  int _travellers = 1;
  String _type = kTravelTypes.first;
  List<String> _prefs = <String>[];
  String _pendingDestination = '';
  bool _profileApplied = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).add(const Duration(days: 14));
    _dates = DateTimeRange(start: start, end: start.add(const Duration(days: 4)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileApplied) return;
    final p = AppScope.of(context).profile.profile;
    if (p != null) {
      _profileApplied = true;
      if (kTravelTypes.contains(p.preferredTravelType)) _type = p.preferredTravelType;
      if (p.interests.isNotEmpty) _prefs = List.of(p.interests);
      if (p.defaultBudget > 0) _budgetCtrl.text = '${p.defaultBudget}';
    }
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  int get _days => _dates.end.difference(_dates.start).inDays + 1;

  void prefill({String destination = '', String? travelType}) {
    setState(() {
      _pendingDestination = destination;
      _destCtrl?.text = destination;
      if (travelType != null && kTravelTypes.contains(travelType)) _type = travelType;
    });
  }

  Future<void> _pickDates() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
      initialDateRange: _dates.start.isBefore(first)
          ? DateTimeRange(start: first, end: first.add(const Duration(days: 4)))
          : _dates,
      helpText: 'Select travel dates',
    );
    if (picked != null) setState(() => _dates = picked);
  }

  String? _validateDates() {
    if (_days > 60) return 'Trips can be at most 60 days';
    return null;
  }

  TripQuery? _query() {
    final datesError = _validateDates();
    if (!_formKey.currentState!.validate() || datesError != null) {
      if (datesError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(datesError)));
      }
      return null;
    }
    return TripQuery(
      destination: _destCtrl?.text.trim() ?? '',
      budget: int.parse(_budgetCtrl.text.trim()),
      days: _days,
      travelType: _type,
      travellers: _travellers,
      preferences: _prefs,
    );
  }

  void _recommend() {
    final q = _query();
    if (q == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          query: q,
          startDate: _dates.start,
          endDate: _dates.end,
        ),
      ),
    );
  }

  void _createTrip() {
    final q = _query();
    if (q == null) return;
    if (q.destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a destination, or use "Get recommendations".')));
      return;
    }
    final repo = AppScope.of(context).trips;
    final draft = Trip(
      id: repo.newId(),
      destination: q.destination,
      startDate: isoDate(_dates.start),
      endDate: isoDate(_dates.end),
      budget: q.budget,
      travellers: q.travellers,
      travelType: q.travelType,
      preferences: q.preferences,
      itinerary: ItineraryService.generate(
        destination: q.destination,
        days: q.days,
        travelType: q.travelType,
        preferences: q.preferences,
      ),
      notes: '',
      estimatedCost: RecommendationService.estimateCost(q.destination, q.days, q.travellers),
      createdAt: 0,
      updatedAt: 0,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripFormScreen(initial: draft, isNew: true)),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan a trip')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tell us about your trip',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Leave the destination empty to get ranked suggestions.'),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _pendingDestination),
                      optionsBuilder: (v) {
                        final q = v.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return kDestinations
                            .map((d) => d.name)
                            .where((n) => n.toLowerCase().contains(q));
                      },
                      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                        _destCtrl = ctrl;
                        return TextFormField(
                          key: const Key('planner_destination'),
                          controller: ctrl,
                          focusNode: focus,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Destination (optional)',
                            hintText: 'e.g. Goa, Manali or any city',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (v) => (v ?? '').trim().length > 80
                              ? 'Destination is too long'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      key: const Key('planner_dates'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickDates,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Travel dates',
                          prefixIcon: Icon(Icons.date_range),
                        ),
                        child: Text(
                            '${formatDateRange(_dates.start, _dates.end)}  ·  $_days day(s)'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('planner_budget'),
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Total budget for the trip (₹ INR)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter your total budget';
                        if (n < 1000) return 'Budget must be at least ₹1,000';
                        if (n > 10000000) return 'Budget looks too large (max ₹1,00,00,000)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _label('Travellers'),
                    Row(children: [
                      IconButton.filledTonal(
                        tooltip: 'Fewer travellers',
                        onPressed: _travellers > 1
                            ? () => setState(() => _travellers--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_travellers',
                            key: const Key('planner_travellers'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'More travellers',
                        onPressed: _travellers < 20
                            ? () => setState(() => _travellers++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      Text(_travellers == 1 ? 'person' : 'people'),
                    ]),
                    const SizedBox(height: 14),
                    _label('Travel type'),
                    TravelTypeSelector(
                      selected: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: 14),
                    _label('Interests (optional)'),
                    PreferenceChips(
                      selected: _prefs,
                      onChanged: (p) => setState(() => _prefs = p),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('planner_recommend'),
                      onPressed: _recommend,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Get recommendations'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('planner_create'),
                      onPressed: _createTrip,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Create trip with itinerary'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Suggestions and itineraries come from a transparent rule-based '
                      'engine (not a trained AI model). Costs are illustrative estimates.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
