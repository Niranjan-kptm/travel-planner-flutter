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

/// Create / edit a trip including its day-by-day itinerary.
/// Pops with the stored [Trip] after a successful save.
class TripFormScreen extends StatefulWidget {
  final Trip? initial;
  final bool isNew;

  const TripFormScreen({Key? key, this.initial, this.isNew = true}) : super(key: key);

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dest;
  late final TextEditingController _budget;
  late final TextEditingController _notes;
  late DateTimeRange _dates;
  late int _travellers;
  late String _type;
  late List<String> _prefs;
  late List<ItineraryDay> _itinerary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    final today = DateTime.now();
    final start = e?.start ?? DateTime(today.year, today.month, today.day).add(const Duration(days: 7));
    _dates = DateTimeRange(start: start, end: e?.end ?? start.add(const Duration(days: 2)));
    _dest = TextEditingController(text: e?.destination ?? '');
    _budget = TextEditingController(text: e == null || e.budget == 0 ? '' : '${e.budget}');
    _notes = TextEditingController(text: e?.notes ?? '');
    _travellers = e?.travellers ?? 1;
    _type = e != null && kTravelTypes.contains(e.travelType) ? e.travelType : kTravelTypes.first;
    _prefs = List.of(e?.preferences ?? const <String>[]);
    _itinerary = List.of(e?.itinerary ?? const <ItineraryDay>[]);
  }

  @override
  void dispose() {
    _dest.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _days => _dates.end.difference(_dates.start).inDays + 1;

  Future<void> _pickDates() async {
    final first = DateTime(2000);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 1095)),
      initialDateRange: _dates,
    );
    if (picked == null) return;
    setState(() {
      _dates = picked;
      _fitItinerary();
    });
  }

  /// Keeps one itinerary entry per day when the dates change.
  void _fitItinerary() {
    if (_itinerary.isEmpty) return;
    if (_itinerary.length > _days) {
      _itinerary = _itinerary.sublist(0, _days);
    } else {
      for (var i = _itinerary.length + 1; i <= _days; i++) {
        _itinerary.add(ItineraryDay(day: i, title: 'Free day', activities: const []));
      }
    }
    _itinerary = [
      for (var i = 0; i < _itinerary.length; i++) _itinerary[i].copyWith(day: i + 1)
    ];
  }

  void _regenerate() {
    final dest = _dest.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a destination first')));
      return;
    }
    setState(() {
      _itinerary = ItineraryService.generate(
        destination: dest,
        days: _days,
        travelType: _type,
        preferences: _prefs,
      );
    });
  }

  Future<void> _editDay(int index) async {
    final day = _itinerary[index];
    final title = TextEditingController(text: day.title);
    final acts = TextEditingController(text: day.activities.join('\n'));
    final result = await showDialog<ItineraryDay>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Day ${day.day}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: acts,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Activities (one per line)',
                alignLabelWithHint: true,
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              day.copyWith(
                title: title.text.trim().isEmpty ? 'Day ${day.day}' : title.text.trim(),
                activities: acts.text
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    title.dispose();
    acts.dispose();
    if (result != null) setState(() => _itinerary[index] = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_days > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trips can be at most 60 days')));
      return;
    }
    final s = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dest = _dest.text.trim();
    final base = widget.initial;
    final trip = Trip(
      id: base?.id ?? s.trips.newId(),
      destination: dest,
      startDate: isoDate(_dates.start),
      endDate: isoDate(_dates.end),
      budget: int.parse(_budget.text.trim()),
      travellers: _travellers,
      travelType: _type,
      preferences: _prefs,
      itinerary: _itinerary,
      notes: _notes.text.trim(),
      estimatedCost: RecommendationService.estimateCost(dest, _days, _travellers),
      createdAt: base?.createdAt ?? 0,
      updatedAt: 0,
    );
    setState(() => _saving = true);
    try {
      final stored = await s.trips.save(trip);
      messenger.showSnackBar(SnackBar(
        content: Text(stored.synced
            ? 'Trip saved and synced to Firebase'
            : 'Trip saved on this device - it will sync when you are online'),
      ));
      navigator.pop(stored);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text('Could not save trip: $e')));
      }
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final est = RecommendationService.estimateCost(_dest.text, _days, _travellers);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New trip' : 'Edit trip'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              key: const Key('trip_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('trip_destination'),
                    controller: _dest,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Destination is required';
                      if (s.length > 80) return 'Destination is too long';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDates,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Travel dates',
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text('${formatDateRange(_dates.start, _dates.end)} · $_days day(s)'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('trip_budget'),
                    controller: _budget,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Total budget (₹ INR)',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      helperText: est > 0 ? 'Estimated cost: ${formatInr(est)}' : null,
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'Enter a budget';
                      if (n > 10000000) return 'Budget looks too large';
                      return null;
                    },
                  ),
                  _label('Travellers'),
                  Row(children: [
                    IconButton.filledTonal(
                      tooltip: 'Fewer travellers',
                      onPressed: _travellers > 1 ? () => setState(() => _travellers--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_travellers',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'More travellers',
                      onPressed: _travellers < 20 ? () => setState(() => _travellers++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                  _label('Travel type'),
                  TravelTypeSelector(selected: _type, onChanged: (t) => setState(() => _type = t)),
                  _label('Interests'),
                  PreferenceChips(selected: _prefs, onChanged: (p) => setState(() => _prefs = p)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  Row(children: [
                    const Expanded(
                      child: Text('Itinerary',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      key: const Key('trip_generate'),
                      onPressed: _regenerate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_itinerary.isEmpty ? 'Generate' : 'Regenerate'),
                    ),
                  ]),
                  if (_itinerary.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No itinerary yet. Tap Generate for a day-by-day plan.'),
                    ),
                  for (var i = 0; i < _itinerary.length; i++)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${_itinerary[i].day}')),
                        title: Text(_itinerary[i].title),
                        subtitle: Text(_itinerary[i].activities.isEmpty
                            ? 'No activities'
                            : _itinerary[i].activities.map((a) => '• $a').join('\n')),
                        trailing: IconButton(
                          tooltip: 'Edit day',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editDay(i),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(widget.isNew ? 'Save trip' : 'Update trip'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
