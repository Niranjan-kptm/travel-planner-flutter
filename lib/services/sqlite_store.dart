import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/trip.dart';
import 'local_store.dart';

/// Real SQLite storage (Android / iOS) via sqflite.
/// Schema v2 adds per-user rows, dates, travellers, preferences, itinerary
/// and a `deleted` tombstone flag used for offline deletes.
class SqliteStore implements LocalStore {
  static const int schemaVersion = 2;
  static const String _createV2 = '''
    CREATE TABLE trips (
      userId TEXT NOT NULL,
      id TEXT NOT NULL,
      destination TEXT NOT NULL,
      startDate TEXT NOT NULL,
      endDate TEXT NOT NULL,
      days INTEGER NOT NULL,
      budget INTEGER NOT NULL,
      travellers INTEGER NOT NULL DEFAULT 1,
      travelType TEXT NOT NULL,
      preferences TEXT NOT NULL DEFAULT '[]',
      itinerary TEXT NOT NULL DEFAULT '[]',
      notes TEXT,
      estimatedCost INTEGER NOT NULL DEFAULT 0,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0,
      deleted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (userId, id)
    )
  ''';

  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;

  /// [factory] and [path] are only overridden in tests (sqflite_common_ffi).
  SqliteStore({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;

  @override
  String get label => 'SQLite (sqflite) - offline database on this device';

  @override
  bool get supportsRawSql => true;

  Database get _d {
    final d = _db;
    if (d == null) throw StateError('SqliteStore.init() was not called');
    return d;
  }

  @override
  Future<void> init() async {
    final factory = _factory ?? databaseFactory;
    final path =
        _path ?? p.join(await factory.getDatabasesPath(), 'travel_planner.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await db.execute(_createV2);
          await db.execute('CREATE INDEX idx_trips_user ON trips(userId)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _migrateV1(db);
        },
      ),
    );
  }

  /// v1 had no users, no dates and no itinerary. Rows are copied with an
  /// empty owner and adopted by the first account that signs in.
  static Future<void> _migrateV1(Database db) async {
    await db.execute('ALTER TABLE trips RENAME TO trips_v1');
    await db.execute(_createV2);
    await db.execute('CREATE INDEX idx_trips_user ON trips(userId)');
    final old = await db.query('trips_v1');
    for (final row in old) {
      final t = Trip.fromMap(row).copyWith(synced: false);
      await db.insert('trips', {...t.toMap(), 'userId': ''});
    }
    await db.execute('DROP TABLE trips_v1');
  }

  @override
  Future<List<Trip>> getAll(String userId, {bool includeDeleted = false}) async {
    final rows = await _d.query(
      'trips',
      where: includeDeleted ? 'userId = ?' : 'userId = ? AND deleted = 0',
      whereArgs: [userId],
      orderBy: 'startDate ASC, updatedAt DESC',
    );
    return rows.map((r) => Trip.fromMap(r)).toList();
  }

  @override
  Future<void> upsert(String userId, Trip trip) async {
    await _d.insert('trips', {...trip.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(String userId, String id) async {
    await _d.delete('trips', where: 'userId = ? AND id = ?', whereArgs: [userId, id]);
  }

  @override
  Future<int> claimUnowned(String userId) => _d.update(
        'trips',
        {'userId': userId, 'synced': 0},
        where: "userId = ''",
      );

  @override
  Future<List<Map<String, Object?>>> rawSelect(String sql) async {
    var s = sql.trim();
    if (s.endsWith(';')) s = s.substring(0, s.length - 1).trim();
    if (!s.toLowerCase().startsWith('select') || s.contains(';')) {
      throw ArgumentError('Only a single SELECT statement is allowed here.');
    }
    return _d.rawQuery(s);
  }

  Future<void> close() async => _db?.close();
}
