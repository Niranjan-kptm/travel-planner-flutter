// Integration test against the Firebase Emulator Suite (Auth + Realtime
// Database with database.rules.json). Skipped unless built with
//   flutter test test/firebase_emulator_test.dart --dart-define=FIREBASE_EMULATOR_HOST=localhost
// while `firebase emulators:start --only auth,database --project demo-travel-planner` runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_planner/config/app_config.dart';
import 'package:travel_planner/models/trip.dart';
import 'package:travel_planner/models/user_profile.dart';
import 'package:travel_planner/services/auth_service.dart';
import 'package:travel_planner/services/firebase_service.dart';
import 'package:travel_planner/services/rtdb_event.dart';
import 'package:travel_planner/services/sqlite_store.dart';
import 'package:travel_planner/services/trip_repository.dart';

FirebaseService _cloudFor(AuthService a) => FirebaseService(
      tokenProvider: ({bool forceRefresh = false}) => a.getIdToken(forceRefresh: forceRefresh),
    );

Trip _trip(String id) => Trip(
      id: id, destination: 'Goa', startDate: '2030-01-10', endDate: '2030-01-12',
      budget: 40000, travellers: 2, travelType: 'Beach', preferences: const ['Food'],
      itinerary: const [ItineraryDay(day: 1, title: 'Arrive', activities: ['Beach walk'])],
      notes: '', estimatedCost: 20000, createdAt: 0, updatedAt: 0,
    );

void main() {
  final skip = AppConfig.useEmulator ? false : 'FIREBASE_EMULATOR_HOST not set';
  sqfliteFfiInit();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'alice$stamp@example.com';
  final emailB = 'bob$stamp@example.com';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('auth: register, wrong password, login, reset, logout', () async {
    final auth = AuthService();
    final u = await auth.register(name: 'Alice Test', email: emailA, password: 'secret123');
    expect(u.uid, isNotEmpty);
    expect(auth.currentUser?.email, emailA);
    await expectLater(auth.register(name: 'X', email: emailA, password: 'secret123'),
        throwsA(isA<AuthException>()));
    await auth.signOut();
    expect(auth.currentUser, isNull);
    await expectLater(auth.signIn(email: emailA, password: 'wrongpass'),
        throwsA(isA<AuthException>()));
    final again = await auth.signIn(email: emailA, password: 'secret123');
    expect(again.uid, u.uid);
    expect(await auth.getIdToken(forceRefresh: true), isNotEmpty);
    await auth.sendPasswordReset(emailA);

    final restored = AuthService();
    await restored.restoreSession();
    expect(restored.currentUser?.uid, u.uid, reason: 'session persisted');
    await auth.signOut();
  }, skip: skip);

  test('profile + trip CRUD sync, live stream, per-user rules', () async {
    final auth = AuthService();
    final a = await auth.signIn(email: emailA, password: 'secret123');
    final cloud = _cloudFor(auth);

    final profile = UserProfile(
      uid: a.uid, name: 'Alice Test', email: emailA, phone: '', homeCity: 'Pune',
      preferredTravelType: 'Beach', interests: const ['Food'], defaultBudget: 30000,
      createdAt: 1, updatedAt: 2,
    );
    expect(await cloud.putProfile(profile), isTrue);
    expect((await cloud.fetchProfile(a.uid)).value?.homeCity, 'Pune');

    final store = SqliteStore(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await store.init();
    final repo = TripRepository(store, cloud, enableLiveUpdates: false);
    await repo.attachUser(a.uid);

    final events = <RtdbEvent>[];
    final stream = await cloud.listenTrips(a.uid);
    expect(stream, isNotNull);
    final sub = stream!.listen(events.add);

    // Create
    final created = await repo.save(_trip(repo.newId()));
    expect(created.synced, isTrue);
    expect((await cloud.fetchTrips(a.uid))![created.id]!.destination, 'Goa');
    // Update
    final updated = await repo.save(created.copyWith(destination: 'Udaipur', travellers: 3));
    expect(updated.synced, isTrue);
    final fromCloud = (await cloud.fetchTrips(a.uid))![created.id]!;
    expect(fromCloud.destination, 'Udaipur');
    expect(fromCloud.travellers, 3);
    expect(fromCloud.itinerary.single.activities, ['Beach walk']);
    // Live update arrived over the stream
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(events.where((e) => e.event == 'put' || e.event == 'patch').map((e) => e.data).join(),
        contains('Udaipur'));
    // Invalid data rejected by rules
    expect(await cloud.putTrip(a.uid, updated.copyWith(travellers: 99)), isFalse);
    // Delete
    expect(await repo.delete(created.id), isTrue);
    expect((await cloud.fetchTrips(a.uid))!.containsKey(created.id), isFalse);
    expect(repo.trips, isEmpty);

    // Another user cannot read or write Alice's data.
    await repo.save(_trip(repo.newId()));
    final authB = AuthService();
    await authB.register(name: 'Bob Test', email: emailB, password: 'secret123');
    final cloudB = _cloudFor(authB);
    expect(await cloudB.fetchTrips(a.uid), isNull);
    expect(await cloudB.putTrip(a.uid, _trip('intruder')), isFalse);
    expect(await cloudB.fetchTrips(authB.currentUser!.uid), isEmpty);

    await sub.cancel();
    await repo.detach();
    await store.close();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
