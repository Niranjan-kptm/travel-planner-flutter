import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';
import 'rtdb_event.dart';
import 'rtdb_stream.dart';

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Result of a cloud read: [ok] is false when the request failed
/// (offline, permission denied ...), [value] may be null when the node is empty.
class CloudRead<T> {
  final bool ok;
  final T? value;
  const CloudRead.success(this.value) : ok = true;
  const CloudRead.failure()
      : ok = false,
        value = null;
}

/// Firebase Realtime Database through its REST API, authenticated with the
/// signed-in user's Firebase ID token (`?auth=<idToken>`), so the database
/// security rules (auth.uid === $uid) are enforced server-side.
///
/// Data layout:
///   /users/<uid>/profile          UserProfile
///   /users/<uid>/trips/<tripId>   Trip
///
/// Why REST instead of the firebase_* SDK packages? The SDK needs generated
/// native config files and Gradle changes that are hard to set up in FlutLab.
/// REST works identically on Android, iOS and Web, and live updates use the
/// REST streaming (Server-Sent Events) endpoint.
class FirebaseService {
  static const Duration _timeout = Duration(seconds: 12);

  final TokenProvider tokenProvider;
  final http.Client _client;

  /// Last failure reason, shown in the UI to help troubleshooting.
  String lastError = '';

  FirebaseService({required this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  bool get isConfigured => AppConfig.firebaseConfigured;

  Uri _uri(String path, String token, [Map<String, String> extra = const {}]) {
    final params = <String, String>{
      ...AppConfig.databaseQueryExtras,
      'auth': token,
      ...extra,
    };
    return Uri.parse('${AppConfig.databaseBaseUrl}/$path.json')
        .replace(queryParameters: params);
  }

  /// Runs a request with a fresh token; retries once with a forced refresh
  /// when the database answers 401 (expired token).
  Future<http.Response?> _send(
      String path, Future<http.Response> Function(Uri uri) request) async {
    if (!isConfigured) {
      lastError = 'Firebase is not configured';
      return null;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await tokenProvider(forceRefresh: attempt > 0);
      if (token == null) {
        lastError = 'Not signed in or offline';
        return null;
      }
      try {
        final res = await request(_uri(path, token)).timeout(_timeout);
        if (res.statusCode == 401 && attempt == 0) continue;
        if (res.statusCode >= 200 && res.statusCode < 300) {
          lastError = '';
          return res;
        }
        lastError = res.statusCode == 401
            ? 'Permission denied (HTTP 401) - check the Realtime Database rules'
            : 'HTTP ${res.statusCode}';
        return null;
      } catch (e) {
        lastError = 'Network error - you appear to be offline';
        return null;
      }
    }
    return null;
  }

  static const _json = {'Content-Type': 'application/json'};

  // ------------------------------------------------------------------ trips

  Future<bool> putTrip(String uid, Trip trip) async {
    final res = await _send('users/$uid/trips/${trip.id}',
        (u) => _client.put(u, headers: _json, body: jsonEncode(trip.toJson())));
    return res != null;
  }

  Future<bool> deleteTrip(String uid, String id) async {
    final res = await _send('users/$uid/trips/$id', (u) => _client.delete(u));
    return res != null;
  }

  /// All cloud trips by id (empty map if none), or null if the request failed.
  Future<Map<String, Trip>?> fetchTrips(String uid) async {
    final res = await _send('users/$uid/trips', (u) => _client.get(u));
    if (res == null) return null;
    return parseTrips(jsonDecode(res.body));
  }

  static Map<String, Trip> parseTrips(dynamic decoded) {
    final out = <String, Trip>{};
    if (decoded is Map) {
      decoded.forEach((key, value) {
        if (value is Map) out['$key'] = Trip.fromJson('$key', value);
      });
    }
    return out;
  }

  // ---------------------------------------------------------------- profile

  Future<CloudRead<UserProfile>> fetchProfile(String uid) async {
    final res = await _send('users/$uid/profile', (u) => _client.get(u));
    if (res == null) return const CloudRead.failure();
    final decoded = jsonDecode(res.body);
    return CloudRead.success(
        decoded is Map ? UserProfile.fromJson(uid, decoded) : null);
  }

  Future<bool> putProfile(UserProfile p) async {
    final res = await _send('users/${p.uid}/profile',
        (u) => _client.put(u, headers: _json, body: jsonEncode(p.toJson())));
    return res != null;
  }

  // ----------------------------------------------------------- live updates

  /// Live stream of changes under /users/<uid>/trips.
  Future<Stream<RtdbEvent>?> listenTrips(String uid) async {
    if (!isConfigured) return null;
    final token = await tokenProvider(forceRefresh: false);
    if (token == null) return null;
    return openRtdbEventStream(_uri('users/$uid/trips', token));
  }
}
