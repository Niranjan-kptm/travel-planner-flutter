import '../models/trip.dart';

/// Offline storage contract. Two implementations exist:
///  - SqliteStore       (Android / iOS)  -> real SQLite via sqflite
///  - WebFallbackStore  (browser / FlutLab web) -> browser localStorage via
///                      shared_preferences, NOT SQLite
/// Every record belongs to one Firebase user ([userId]).
abstract class LocalStore {
  String get label;
  bool get supportsRawSql;

  Future<void> init();

  /// Trips of [userId]. Tombstones (pending cloud deletes) are only returned
  /// when [includeDeleted] is true.
  Future<List<Trip>> getAll(String userId, {bool includeDeleted = false});
  Future<void> upsert(String userId, Trip trip);

  /// Physically removes the record.
  Future<void> remove(String userId, String id);

  /// Assigns trips saved by the old single-user version (no login) to
  /// [userId]. Returns how many were adopted.
  Future<int> claimUnowned(String userId);

  /// Runs a single read-only SELECT (only when [supportsRawSql] is true).
  Future<List<Map<String, Object?>>> rawSelect(String sql);
}
