import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';
import 'local_store.dart';

/// Used when the app runs in a web browser (e.g. FlutLab web preview),
/// because sqflite does not run on the web. Trips are kept as JSON in the
/// browser's localStorage (via shared_preferences), one key per user.
/// This is NOT SQLite.
class WebFallbackStore implements LocalStore {
  static const String _legacyKey = 'travel_planner_trips_v1';
  static String _key(String userId) => 'travel_planner_trips_v2_$userId';

  SharedPreferences? _prefs;

  @override
  String get label => 'Browser storage (localStorage) - web fallback, not SQLite';

  @override
  bool get supportsRawSql => false;

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) throw StateError('WebFallbackStore.init() was not called');
    return p;
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Trip> _read(String key) {
    final raw = _p.getString(key);
    if (raw == null || raw.isEmpty) return <Trip>[];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Trip.fromMap(Map<String, Object?>.from(e as Map)))
          .toList();
    } catch (_) {
      return <Trip>[];
    }
  }

  Future<void> _write(String userId, List<Trip> trips) async {
    await _p.setString(
        _key(userId), jsonEncode(trips.map((t) => t.toMap()).toList()));
  }

  @override
  Future<List<Trip>> getAll(String userId, {bool includeDeleted = false}) async {
    final list = _read(_key(userId));
    if (!includeDeleted) list.removeWhere((t) => t.deleted);
    list.sort((a, b) {
      final c = a.startDate.compareTo(b.startDate);
      return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  @override
  Future<void> upsert(String userId, Trip trip) async {
    final list = _read(_key(userId));
    final i = list.indexWhere((t) => t.id == trip.id);
    if (i >= 0) {
      list[i] = trip;
    } else {
      list.add(trip);
    }
    await _write(userId, list);
  }

  @override
  Future<void> remove(String userId, String id) async {
    final list = _read(_key(userId));
    list.removeWhere((t) => t.id == id);
    await _write(userId, list);
  }

  @override
  Future<int> claimUnowned(String userId) async {
    final legacy = _read(_legacyKey);
    if (legacy.isEmpty) return 0;
    final list = _read(_key(userId));
    for (final t in legacy) {
      if (!list.any((x) => x.id == t.id)) list.add(t.copyWith(synced: false));
    }
    await _write(userId, list);
    await _p.remove(_legacyKey);
    return legacy.length;
  }

  @override
  Future<List<Map<String, Object?>>> rawSelect(String sql) {
    throw UnsupportedError('Raw SQL is only available with real SQLite (Android/iOS).');
  }
}
