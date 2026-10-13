import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_planner/models/trip.dart';
import 'package:travel_planner/services/sqlite_store.dart';

Trip _t(String id, {int updatedAt = 1}) => Trip(
      id: id, destination: 'Jaipur', startDate: '2030-02-01', endDate: '2030-02-03',
      budget: 30000, travellers: 2, travelType: 'Cultural', preferences: const ['History'],
      itinerary: const [], notes: '', estimatedCost: 0, createdAt: 1, updatedAt: updatedAt,
    );

void main() {
  sqfliteFfiInit();

  test('real SqliteStore CRUD is user-scoped and keeps tombstones', () async {
    final store = SqliteStore(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await store.init();
    await store.upsert('alice', _t('a'));
    await store.upsert('bob', _t('b'));
    expect((await store.getAll('alice')).map((t) => t.id), ['a']);

    await store.upsert('alice', _t('a', updatedAt: 9).copyWith(destination: 'Udaipur'));
    final updated = await store.getAll('alice');
    expect(updated.single.destination, 'Udaipur');

    await store.upsert('alice', updated.single.copyWith(deleted: true));
    expect(await store.getAll('alice'), isEmpty);
    expect((await store.getAll('alice', includeDeleted: true)).single.deleted, isTrue);

    await store.remove('alice', 'a');
    expect(await store.getAll('alice', includeDeleted: true), isEmpty);
    expect((await store.getAll('bob')).length, 1);
    await store.close();
  });
}
