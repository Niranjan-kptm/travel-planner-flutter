import '../data/destinations.dart';
import '../models/trip.dart';
import 'recommendation_service.dart';

/// Rule-based day-by-day itinerary generator (deterministic, no AI model).
/// Uses the destination's highlights, the travel type and the selected
/// interests. Users can edit every day afterwards.
class ItineraryService {
  static const Map<String, List<String>> _typeActivities = {
    'Beach': [
      'Morning swim and beach time',
      'Sunset by the sea',
      'Seafood lunch at a beach shack',
      'Beach-side cafe hopping',
    ],
    'Adventure': [
      'Guided adventure activity (book a licensed operator)',
      'Short hike to a viewpoint',
      'Try a local outdoor sport',
    ],
    'Culture': [
      'Heritage walk with a local guide',
      'Visit a museum or historic site',
      'Explore the old market streets',
    ],
    'Nature': [
      'Nature trail or park visit',
      'Sunrise at a scenic viewpoint',
      'Picnic at a quiet spot',
    ],
    'Relaxation': [
      'Slow morning and a spa session',
      'Leisurely cafe afternoon',
      'Evening stroll and early night',
    ],
  };

  static const Map<String, String> _preferenceActivities = {
    'Food & cuisine': 'Food tour of local specialities',
    'History & heritage': 'Visit a heritage monument',
    'Shopping': 'Shopping at local markets',
    'Nightlife': 'Evening at a popular night spot',
    'Photography': 'Golden-hour photo walk',
    'Wildlife': 'Wildlife sanctuary or safari visit',
    'Trekking': 'Half-day trek',
    'Water sports': 'Water sports session',
    'Spiritual': 'Visit a temple or spiritual site',
    'Wellness & spa': 'Ayurveda or spa treatment',
    'Family friendly': 'Family-friendly activity or park',
  };

  static List<ItineraryDay> generate({
    required String destination,
    required int days,
    required String travelType,
    List<String> preferences = const [],
  }) {
    final n = days < 1 ? 1 : days;
    final Destination? d = RecommendationService.findByName(destination);
    final place = destination.trim().isEmpty ? 'your destination' : destination.trim();
    final highlights = d?.highlights ?? <String>['Main sights of $place'];
    final typePool = <String>[
      ...?_typeActivities[travelType],
      ...?(d == null
          ? null
          : d.types
              .where((t) => t != travelType)
              .expand((t) => _typeActivities[t] ?? const <String>[])),
    ];
    if (typePool.isEmpty) typePool.addAll(_typeActivities['Culture']!);
    final prefPool = preferences
        .map((p) => _preferenceActivities[p])
        .whereType<String>()
        .toList();

    var h = 0, t = 0, p = 0;
    String nextHighlight() => highlights[h++ % highlights.length];
    String nextType() => typePool[t++ % typePool.length];
    String? nextPref() => prefPool.isEmpty ? null : prefPool[p++ % prefPool.length];

    final out = <ItineraryDay>[];
    for (var i = 1; i <= n; i++) {
      if (i == 1) {
        out.add(ItineraryDay(day: 1, title: 'Arrive in $place', activities: [
          'Arrive and check in',
          n == 1 ? nextHighlight() : 'Explore the neighbourhood',
          if (n == 1) 'Head back home',
          if (n > 1) 'Dinner at a well-rated local restaurant',
        ]));
      } else if (i == n) {
        out.add(ItineraryDay(day: i, title: 'Departure day', activities: [
          prefPool.contains(_preferenceActivities['Shopping'])
              ? 'Last-minute souvenir shopping'
              : 'Relaxed breakfast and souvenirs',
          'Check out and travel home',
        ]));
      } else {
        final hi = nextHighlight();
        final pref = nextPref();
        out.add(ItineraryDay(day: i, title: hi, activities: [
          hi,
          nextType(),
          if (pref != null) pref,
        ]));
      }
    }
    return out;
  }
}
