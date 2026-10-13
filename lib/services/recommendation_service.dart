import '../data/destinations.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';
import '../utils/format.dart';

/// What the user entered on the planner screen.
class TripQuery {
  final String destination; // optional free text, may be empty
  final int budget; // total trip budget for all travellers, INR
  final int days;
  final String travelType;
  final int travellers;
  final List<String> preferences;

  const TripQuery({
    required this.destination,
    required this.budget,
    required this.days,
    required this.travelType,
    this.travellers = 1,
    this.preferences = const [],
  });
}

class Recommendation {
  final Destination destination;
  final int score; // 0..100
  final int estimatedCost;
  final bool withinBudget;
  final bool nameMatched;
  final List<String> reasons;

  const Recommendation({
    required this.destination,
    required this.score,
    required this.estimatedCost,
    required this.withinBudget,
    required this.nameMatched,
    required this.reasons,
  });
}

/// Transparent RULE-BASED scoring. This is NOT a trained machine-learning model.
///
///   travel type match  : 35 points
///   budget fit         : 25 points (scaled down when over budget)
///   duration fit       : 15 points (minus 4 per day outside the ideal range)
///   interests match    : 15 points (share of selected interests that fit)
///   typed-name match   : 10 points
class RecommendationService {
  static List<Recommendation> recommend(TripQuery q, {int limit = 6}) {
    final wanted = q.destination.trim().toLowerCase();
    final travellers = q.travellers < 1 ? 1 : q.travellers;
    final results = <Recommendation>[];

    for (final d in kDestinations) {
      var score = 0;
      final reasons = <String>[];

      // 1) Travel type
      if (d.types.contains(q.travelType)) {
        score += 35;
        reasons.add('Matches your ${q.travelType} travel style');
      } else {
        reasons.add('Not a core ${q.travelType.toLowerCase()} destination '
            '(better for ${d.types.join(', ')})');
      }

      // 2) Budget (whole group)
      final cost = d.dailyCost * q.days * travellers;
      final within = cost <= q.budget;
      final who = travellers > 1 ? ' for $travellers travellers' : '';
      if (within) {
        score += 25;
        reasons.add('Estimated ${formatInr(cost)}$who fits your ${formatInr(q.budget)} budget');
      } else {
        final ratio = q.budget <= 0 ? 0.0 : q.budget / cost;
        score += (25 * ratio * ratio).round();
        reasons.add('Estimated ${formatInr(cost)}$who is ${formatInr(cost - q.budget)} over your budget');
      }

      // 3) Duration
      if (q.days >= d.minDays && q.days <= d.maxDays) {
        score += 15;
        reasons.add('${q.days} days suits this place (ideal ${d.minDays}-${d.maxDays})');
      } else {
        final diff = q.days < d.minDays ? d.minDays - q.days : q.days - d.maxDays;
        final pts = 15 - diff * 4;
        score += pts > 0 ? pts : 0;
        reasons.add(q.days < d.minDays
            ? 'Short for this place - ideal is ${d.minDays}-${d.maxDays} days'
            : 'Longer than the usual ${d.minDays}-${d.maxDays} days - add a nearby stop');
      }

      // 4) Interests
      if (q.preferences.isEmpty) {
        score += 15;
      } else {
        final matched = q.preferences.where((p) => matchesPreference(d, p)).toList();
        score += (15 * matched.length / q.preferences.length).round();
        if (matched.isNotEmpty) {
          reasons.add('Good for ${matched.join(', ').toLowerCase()}');
        }
      }

      // 5) Typed destination
      var nameMatched = false;
      if (wanted.isNotEmpty) {
        final name = d.name.toLowerCase();
        if (name.contains(wanted) ||
            wanted.contains(name) ||
            d.country.toLowerCase() == wanted) {
          nameMatched = true;
          score += 10;
          reasons.insert(0, 'Matches the destination you typed');
        }
      }

      if (score > 100) score = 100;
      results.add(Recommendation(
        destination: d,
        score: score,
        estimatedCost: cost,
        withinBudget: within,
        nameMatched: nameMatched,
        reasons: reasons,
      ));
    }

    results.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.estimatedCost.compareTo(b.estimatedCost);
    });
    return results.take(limit).toList();
  }

  static bool matchesPreference(Destination d, String pref) {
    final types = kPreferenceTypes[pref] ?? const <String>[];
    return d.types.any(types.contains);
  }

  /// Personalised suggestions for the dashboard, based on the profile
  /// (preferred travel type, interests, default budget) and past trips.
  /// Destinations already in an upcoming trip are skipped.
  static List<Recommendation> forUser({
    UserProfile? profile,
    List<Trip> trips = const [],
    int limit = 4,
  }) {
    var type = profile?.preferredTravelType ?? '';
    if (type.isEmpty && trips.isNotEmpty) {
      final counts = <String, int>{};
      for (final t in trips) {
        counts[t.travelType] = (counts[t.travelType] ?? 0) + 1;
      }
      type = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
    }
    if (!kTravelTypes.contains(type)) type = kTravelTypes.first;

    var budget = profile?.defaultBudget ?? 0;
    var days = 4;
    var travellers = 1;
    if (trips.isNotEmpty) {
      if (budget <= 0) {
        budget = trips.map((t) => t.budget).reduce((a, b) => a + b) ~/ trips.length;
      }
      days = (trips.map((t) => t.days).reduce((a, b) => a + b) / trips.length).round();
      travellers =
          (trips.map((t) => t.travellers).reduce((a, b) => a + b) / trips.length).round();
    }
    if (budget <= 0) budget = 30000;
    if (days < 1) days = 4;

    final planned = trips
        .where((t) => t.isUpcoming())
        .map((t) => t.destination.toLowerCase())
        .toSet();
    final all = recommend(
      TripQuery(
        destination: '',
        budget: budget,
        days: days,
        travelType: type,
        travellers: travellers < 1 ? 1 : travellers,
        preferences: profile?.interests ?? const [],
      ),
      limit: kDestinations.length,
    );
    return all
        .where((r) => !planned.contains(r.destination.name.toLowerCase()))
        .take(limit)
        .toList();
  }

  /// Free-text search over name, country, travel types and highlights.
  static List<Destination> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return kDestinations.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.country.toLowerCase().contains(q) ||
          d.types.any((t) => t.toLowerCase().contains(q)) ||
          d.highlights.any((h) => h.toLowerCase().contains(q)) ||
          d.description.toLowerCase().contains(q);
    }).toList();
  }

  static List<Destination> popular() => kPopularDestinationNames
      .map(findByName)
      .whereType<Destination>()
      .toList();

  static Destination? findByName(String name) {
    final n = name.trim().toLowerCase();
    for (final d in kDestinations) {
      if (d.name.toLowerCase() == n) return d;
    }
    return null;
  }

  /// Estimated cost for a known destination; 0 when the destination is custom.
  static int estimateCost(String name, int days, [int travellers = 1]) {
    final d = findByName(name);
    return d == null ? 0 : d.dailyCost * days * (travellers < 1 ? 1 : travellers);
  }
}
