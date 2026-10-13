import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/trip.dart';
import 'firebase_service.dart';
import 'local_store.dart';
import 'local_store_factory.dart';
import 'rtdb_event.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  final int removed;
  final String? error;
  const SyncResult(this.pushed, this.pulled, this.removed, this.error);

  String get summary => error != null
      ? 'Sync failed: $error'
      : 'Sync complete - uploaded $pushed, downloaded $pulled'
          '${removed > 0 ? ', removed $removed' : ''}';
}

enum CloudState { notConfigured, connecting, live, synced, offline }

/// Local-first trip repository for the signed-in user.
///
/// * Every write goes to local storage first (works offline), then to Firebase.
/// * Deletes made offline are kept as tombstones until the cloud delete
///   succeeds, so they never come back on the next sync.
/// * Live updates from other devices arrive through the Realtime Database
///   streaming API and are merged into local storage.
/// * Conflicts: newest `updatedAt` wins.
class TripRepository extends ChangeNotifier {
  final LocalStore local;
  final FirebaseService cloud;
  final Duration retryInterval;
  final bool enableLiveUpdates;

  TripRepository(
    this.local,
    this.cloud, {
    this.retryInterval = const Duration(seconds: 30),
    this.enableLiveUpdates = true,
  });

  static Future<LocalStore> createLocalStore() async {
    final store = createPlatformLocalStore();
    await store.init();
    return store;
  }

  final Random _rand = Random();
  String? _uid;
  List<Trip> _trips = <Trip>[];
  int _pending = 0;
  bool _loading = false;
  CloudState _state = CloudState.connecting;
  String _lastError = '';
  DateTime? _lastSyncAt;
  StreamSubscription<RtdbEvent>? _sub;
  Timer? _retryTimer;
  Timer? _reconnectTimer;
  int _streamFailures = 0;
  Future<void> _tail = Future<void>.value();

  String? get userId => _uid;
  List<Trip> get trips => List.unmodifiable(_trips);
  int get pendingCount => _pending;
  bool get loading => _loading;
  CloudState get cloudState => cloud.isConfigured ? _state : CloudState.notConfigured;
  String get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isLive => _sub != null && _state == CloudState.live;

  List<Trip> get upcomingTrips => _trips.where((t) => t.isUpcoming()).toList();

  Trip? byId(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Ids start with a letter so Firebase treats the parent as an object, not a list.
  String newId() =>
      't${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(1 << 20).toRadixString(36)}';

  /// Serialises local+cloud operations so events and user edits never interleave.
  Future<T> _locked<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  void _setState(CloudState s, [String error = '']) {
    _state = s;
    _lastError = error;
    notifyListeners();
  }

  // ------------------------------------------------------------ lifecycle

  Future<void> attachUser(String uid) async {
    if (_uid == uid) return;
    await detach();
    _uid = uid;
    _loading = true;
    _state = CloudState.connecting;
    notifyListeners();
    try {
      await local.claimUnowned(uid);
      await _reload();
    } catch (e) {
      _lastError = 'Could not read local storage: $e';
    }
    _loading = false;
    notifyListeners();
    if (!cloud.isConfigured) return;
    unawaited(syncNow().then((_) => _startLive()));
    _retryTimer = Timer.periodic(retryInterval, (_) => _periodic());
  }

  Future<void> detach() async {
    _retryTimer?.cancel();
    _reconnectTimer?.cancel();
    _retryTimer = null;
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _trips = <Trip>[];
    _pending = 0;
    _lastSyncAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _periodic() {
    if (_uid == null) return;
    if (_pending > 0 || _state == CloudState.offline) unawaited(syncNow());
    if (_sub == null && (_reconnectTimer == null || !_reconnectTimer!.isActive)) {
      unawaited(_startLive());
    }
  }

  Future<void> _reload() async {
    final uid = _uid;
    if (uid == null) return;
    final all = await local.getAll(uid, includeDeleted: true);
    _pending = all.where((t) => !t.synced).length;
    _trips = all.where((t) => !t.deleted).toList()
      ..sort((a, b) {
        final c = a.startDate.compareTo(b.startDate);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      });
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw StateError('No signed-in user');
    return uid;
  }

  // ----------------------------------------------------------------- CRUD

  /// Create or update. Returns the stored trip (synced == true if the cloud write worked).
  Future<Trip> save(Trip trip) => _locked(() async {
        final uid = _requireUid();
        final now = DateTime.now().millisecondsSinceEpoch;
        final stamped = trip.copyWith(
          createdAt: trip.createdAt > 0 ? trip.createdAt : now,
          updatedAt: now,
          synced: false,
          deleted: false,
        );
        await local.upsert(uid, stamped);
        await _reload();
        notifyListeners();
        if (!cloud.isConfigured) return stamped;
        final ok = await cloud.putTrip(uid, stamped);
        if (_uid != uid) return stamped;
        if (ok) {
          final done = stamped.copyWith(synced: true);
          await local.upsert(uid, done);
          await _reload();
          _lastSyncAt = DateTime.now();
          _setState(_sub != null ? CloudState.live : CloudState.synced);
          return done;
        }
        _setState(CloudState.offline, cloud.lastError);
        return stamped;
      });

  /// Deletes locally at once; the cloud delete is retried until it succeeds.
  /// Returns true when the cloud copy is gone too.
  Future<bool> delete(String id) => _locked(() async {
        final uid = _requireUid();
        final all = await local.getAll(uid, includeDeleted: true);
        final existing = all.where((t) => t.id == id).toList();
        if (existing.isEmpty) return true;
        final tomb = existing.first.copyWith(
          deleted: true,
          synced: false,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await local.upsert(uid, tomb);
        await _reload();
        notifyListeners();
        if (!cloud.isConfigured) {
          await local.remove(uid, id);
          await _reload();
          notifyListeners();
          return true;
        }
        final ok = await cloud.deleteTrip(uid, id);
        if (_uid != uid) return ok;
        if (ok) {
          await local.remove(uid, id);
          await _reload();
          _setState(_sub != null ? CloudState.live : CloudState.synced);
        } else {
          _setState(CloudState.offline, cloud.lastError);
        }
        return ok;
      });

  // ----------------------------------------------------------------- sync

  /// Pushes pending local changes, then merges the cloud copy.
  Future<SyncResult> syncNow() => _locked(() async {
        final uid = _uid;
        if (uid == null) return const SyncResult(0, 0, 0, 'Not signed in');
        if (!cloud.isConfigured) {
          return const SyncResult(0, 0, 0, 'Firebase is not configured');
        }
        if (_state != CloudState.live) _setState(CloudState.connecting);
        var pushed = 0;
        final all = await local.getAll(uid, includeDeleted: true);
        for (final t in all.where((t) => !t.synced)) {
          final ok = t.deleted
              ? await cloud.deleteTrip(uid, t.id)
              : await cloud.putTrip(uid, t);
          if (_uid != uid) return const SyncResult(0, 0, 0, 'User changed');
          if (!ok) {
            await _reload();
            _setState(CloudState.offline, cloud.lastError);
            return SyncResult(pushed, 0, 0, cloud.lastError);
          }
          if (t.deleted) {
            await local.remove(uid, t.id);
          } else {
            await local.upsert(uid, t.copyWith(synced: true));
          }
          pushed++;
        }
        final remote = await cloud.fetchTrips(uid);
        if (_uid != uid) return const SyncResult(0, 0, 0, 'User changed');
        if (remote == null) {
          await _reload();
          _setState(CloudState.offline, cloud.lastError);
          return SyncResult(pushed, 0, 0, cloud.lastError);
        }
        final merged = await _mergeSnapshot(uid, remote);
        await _reload();
        _lastSyncAt = DateTime.now();
        _setState(_sub != null ? CloudState.live : CloudState.synced);
        return SyncResult(pushed, merged[0], merged[1], null);
      });

  /// Merges a full cloud snapshot. Returns [pulled, removed].
  Future<List<int>> _mergeSnapshot(String uid, Map<String, Trip> remote) async {
    var pulled = 0;
    var removed = 0;
    final localAll = await local.getAll(uid, includeDeleted: true);
    final byId = {for (final t in localAll) t.id: t};
    for (final r in remote.values) {
      final l = byId[r.id];
      if (l == null) {
        await local.upsert(uid, r);
        pulled++;
      } else if (l.deleted && !l.synced) {
        continue; // local delete still pending
      } else if (l.synced) {
        if (!_sameTrip(l, r)) {
          await local.upsert(uid, r);
          pulled++;
        }
      } else if (r.updatedAt > l.updatedAt) {
        await local.upsert(uid, r); // remote edit is newer than the pending local one
        pulled++;
      }
    }
    for (final l in localAll) {
      if (l.synced && !remote.containsKey(l.id)) {
        await local.remove(uid, l.id); // deleted on another device
        removed++;
      }
    }
    return [pulled, removed];
  }

  bool _sameTrip(Trip a, Trip b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  Future<void> _applyRemoteTrip(String uid, String id, dynamic data) async {
    final all = await local.getAll(uid, includeDeleted: true);
    final matches = all.where((t) => t.id == id).toList();
    final l = matches.isEmpty ? null : matches.first;
    if (data == null) {
      if (l != null && (l.synced || l.deleted)) await local.remove(uid, id);
      return;
    }
    if (data is! Map) return;
    final r = Trip.fromJson(id, data);
    if (l == null || l.synced || r.updatedAt > l.updatedAt) {
      if (l != null && l.deleted && !l.synced) return;
      await local.upsert(uid, r);
    }
  }

  // --------------------------------------------------------- live updates

  Future<void> _startLive() async {
    final uid = _uid;
    if (!enableLiveUpdates || uid == null || _sub != null) return;
    final stream = await cloud.listenTrips(uid);
    if (_uid != uid) return;
    if (stream == null) {
      _scheduleReconnect();
      return;
    }
    _sub = stream.listen(
      (e) => _onEvent(uid, e),
      onError: (Object e) => _onStreamDown(uid, e.toString()),
      onDone: () => _onStreamDown(uid, 'closed'),
      cancelOnError: true,
    );
  }

  void _onStreamDown(String uid, String reason) {
    if (_uid != uid) return;
    _sub?.cancel();
    _sub = null;
    debugPrint('Live updates down: $reason');
    if (_state == CloudState.live) _setState(CloudState.synced);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _streamFailures++;
    final secs = min(60, 2 << min(_streamFailures, 5));
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (_uid != null) unawaited(_startLive());
    });
  }

  void _onEvent(String uid, RtdbEvent e) {
    switch (e.event) {
      case 'put':
      case 'patch':
        unawaited(_handleData(uid, e.event, e.data));
        break;
      case 'cancel':
        _onStreamDown(uid, 'cancelled by server (permission denied?)');
        break;
      case 'auth_revoked':
        _onStreamDown(uid, 'auth token expired');
        break;
      default:
        break; // keep-alive
    }
  }

  Future<void> _handleData(String uid, String event, String raw) async {
    dynamic msg;
    try {
      msg = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (msg is! Map) return;
    final path = '${msg['path'] ?? '/'}';
    final data = msg['data'];
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    var needsFullSync = false;
    await _locked(() async {
      if (_uid != uid) return;
      if (parts.isEmpty) {
        if (event == 'put') {
          await _mergeSnapshot(uid, FirebaseService.parseTrips(data));
        } else if (data is Map) {
          for (final entry in data.entries) {
            await _applyRemoteTrip(uid, '${entry.key}', entry.value);
          }
        }
      } else if (parts.length == 1 && event == 'put') {
        await _applyRemoteTrip(uid, parts.first, data);
      } else {
        needsFullSync = true; // partial field update: refetch everything
      }
      await _reload();
      _streamFailures = 0;
      _lastSyncAt = DateTime.now();
      _setState(CloudState.live);
    });
    if (needsFullSync) await syncNow();
  }
}
