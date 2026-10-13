import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/models/trip.dart';
import 'package:travel_planner/models/user_profile.dart';
import 'package:travel_planner/services/auth_service.dart';
import 'package:travel_planner/services/itinerary_service.dart';
import 'package:travel_planner/services/recommendation_service.dart';
import 'package:travel_planner/utils/format.dart';

Trip _trip() => Trip(
      id: 't1',
      destination: 'Goa',
      startDate: '2030-01-10',
      endDate: '2030-01-14',
      budget: 50000,
      travellers: 2,
      travelType: 'Beach',
      preferences: const ['Food'],
      itinerary: const [ItineraryDay(day: 1, title: 'Arrive', activities: ['Check in'])],
      notes: 'n',
      estimatedCost: 30000,
      createdAt: 1,
      updatedAt: 2,
    );

void main() {
  test('Trip days, upcoming and JSON round trip', () {
    final t = _trip();
    expect(t.days, 5);
    expect(t.isUpcoming(DateTime(2030, 1, 14)), isTrue);
    expect(t.isUpcoming(DateTime(2030, 1, 15)), isFalse);
    final back = Trip.fromJson('t1', t.toJson());
    expect(back.toJson(), t.toJson());
  });

  test('Trip local map round trip keeps sync flags', () {
    final t = _trip().copyWith(synced: true, deleted: true);
    final back = Trip.fromMap(t.toMap());
    expect(back.synced, isTrue);
    expect(back.deleted, isTrue);
    expect(back.itinerary.single.activities, ['Check in']);
    expect(back.preferences, ['Food']);
  });

  test('legacy v1 record (days only) is upgraded', () {
    final t = Trip.fromMap({
      'id': 'old',
      'destination': 'Manali',
      'budget': 20000,
      'travelType': 'Adventure',
      'days': 3,
      'notes': '',
      'estimatedCost': 0,
      'updatedAt': 5,
      'synced': 0,
    });
    expect(t.days, 3);
    expect(t.travellers, 1);
  });

  test('UserProfile JSON round trip', () {
    final p = UserProfile(
      uid: 'u', name: 'Asha Rao', email: 'a@b.co', phone: '', homeCity: 'Pune',
      preferredTravelType: 'Beach', interests: const ['Food'], defaultBudget: 1000,
      createdAt: 1, updatedAt: 2,
    );
    final back = UserProfile.fromJson('u', p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.firstName, 'Asha');
    expect(back.initials, 'AR');
  });

  test('itinerary has one entry per day with arrival and departure', () {
    final it = ItineraryService.generate(
        destination: 'Goa', days: 4, travelType: 'Beach', preferences: const ['Food']);
    expect(it.length, 4);
    expect(it.map((d) => d.day), [1, 2, 3, 4]);
    expect(it.first.title, contains('Arrive'));
    expect(it.last.title, contains('Departure'));
    final custom = ItineraryService.generate(destination: 'Atlantis', days: 1, travelType: 'Cultural');
    expect(custom.length, 1);
  });

  test('personalised recommendations and search', () {
    expect(RecommendationService.search('beach'), isNotEmpty);
    expect(RecommendationService.popular(), isNotEmpty);
    final recs = RecommendationService.forUser(profile: null, trips: const []);
    expect(recs, isNotEmpty);
    expect(RecommendationService.estimateCost('Goa', 2, 2),
        RecommendationService.estimateCost('Goa', 2, 1) * 2);
  });

  test('Firebase auth error mapping and validators', () {
    expect(friendlyAuthError('EMAIL_EXISTS'), contains('already'));
    expect(friendlyAuthError('WEAK_PASSWORD : Password should be at least 6 characters'),
        isNot('WEAK_PASSWORD'));
    expect(validateEmail('bad'), isNotNull);
    expect(validateEmail('a@b.co'), isNull);
    expect(validatePassword('123'), isNotNull);
    expect(validatePassword('secret12'), isNull);
  });
}
