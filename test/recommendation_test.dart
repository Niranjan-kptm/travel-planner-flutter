import 'package:flutter_test/flutter_test.dart';

import '../lib/services/recommendation_service.dart';
import '../lib/utils/format.dart';

void main() {
  test('beach request ranks a beach destination first', () {
    final r = RecommendationService.recommend(const TripQuery(
        destination: '', budget: 40000, days: 4, travelType: 'Beach'));
    expect(r.first.destination.types.contains('Beach'), true);
  });

  test('over-budget destinations are flagged', () {
    final r = RecommendationService.recommend(
      const TripQuery(destination: '', budget: 5000, days: 3, travelType: 'Culture'),
      limit: 50,
    );
    final sg = r.firstWhere((x) => x.destination.name == 'Singapore');
    expect(sg.withinBudget, false);
  });

  test('typed destination gets the name-match bonus', () {
    final r = RecommendationService.recommend(const TripQuery(
        destination: 'goa', budget: 30000, days: 4, travelType: 'Beach'));
    expect(r.first.destination.name, 'Goa');
    expect(r.first.nameMatched, true);
  });

  test('estimateCost and formatInr', () {
    expect(RecommendationService.estimateCost('Goa', 3), 10500);
    expect(RecommendationService.estimateCost('Unknownville', 3), 0);
    expect(formatInr(1234567), '₹12,34,567');
    expect(formatInr(1000), '₹1,000');
  });
}
