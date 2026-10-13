import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

/// User profile at /users/<uid>/profile with an offline cache.
class ProfileRepository extends ChangeNotifier {
  final FirebaseService cloud;
  ProfileRepository(this.cloud);

  UserProfile? _profile;
  bool _pending = false;
  bool _loading = false;
  String? _uid;

  UserProfile? get profile => _profile;
  bool get hasPendingChanges => _pending;
  bool get loading => _loading;

  static String _cacheKey(String uid) => 'profile_v1_$uid';
  static String _pendingKey(String uid) => 'profile_pending_v1_$uid';

  Future<void> attach(AuthUser user) async {
    if (_uid == user.uid) return;
    _uid = user.uid;
    _loading = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(user.uid));
    _pending = prefs.getBool(_pendingKey(user.uid)) ?? false;
    if (raw != null) {
      try {
        _profile = UserProfile.fromJson(user.uid, jsonDecode(raw) as Map);
      } catch (_) {
        _profile = null;
      }
    }
    _profile ??= UserProfile(
      uid: user.uid,
      name: user.displayName,
      email: user.email,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    await refresh(user);
    _loading = false;
    notifyListeners();
  }

  /// Pulls the cloud copy, or creates it on first login.
  Future<void> refresh(AuthUser user) async {
    if (_pending) {
      await _push();
      if (_pending) return;
    }
    final res = await cloud.fetchProfile(user.uid);
    if (_uid != user.uid || !res.ok) return;
    final remote = res.value;
    if (remote == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final base = _profile!;
      _profile = base.copyWith(
        name: base.name.isEmpty ? user.displayName : base.name,
        email: user.email,
        createdAt: base.createdAt > 0 ? base.createdAt : now,
        updatedAt: now,
      );
      await _cache();
      await _push();
    } else {
      _profile = remote.email.isEmpty ? remote.copyWith(email: user.email) : remote;
      await _cache();
    }
    notifyListeners();
  }

  /// Saves locally and to the cloud. Returns true if the cloud write worked.
  Future<bool> save(UserProfile p) async {
    _profile = p.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    await _cache();
    await _setPending(true);
    notifyListeners();
    await _push();
    notifyListeners();
    return !_pending;
  }

  Future<void> retryPending() async {
    if (_pending) {
      await _push();
      notifyListeners();
    }
  }

  Future<void> _push() async {
    final p = _profile;
    if (p == null) return;
    final ok = await cloud.putProfile(p);
    await _setPending(!ok);
  }

  Future<void> _cache() async {
    final p = _profile;
    if (p == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(p.uid), jsonEncode(p.toJson()));
  }

  Future<void> _setPending(bool v) async {
    _pending = v;
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey(uid), v);
  }

  void detach() {
    _uid = null;
    _profile = null;
    _pending = false;
    notifyListeners();
  }
}
