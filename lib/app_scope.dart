import 'dart:async';

import 'package:flutter/widgets.dart';

import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/local_store.dart';
import 'services/profile_repository.dart';
import 'services/trip_repository.dart';

/// All app services, created once in main().
class AppServices {
  final AuthService auth;
  final FirebaseService cloud;
  final TripRepository trips;
  final ProfileRepository profile;

  AppServices._(this.auth, this.cloud, this.trips, this.profile) {
    auth.addListener(_onAuthChanged);
  }

  factory AppServices.create(LocalStore store, {AuthService? auth}) {
    final a = auth ?? AuthService();
    final cloud = FirebaseService(
      tokenProvider: ({bool forceRefresh = false}) =>
          a.getIdToken(forceRefresh: forceRefresh),
    );
    return AppServices._(a, cloud, TripRepository(store, cloud), ProfileRepository(cloud));
  }

  String? _attachedUid;

  /// Connects the per-user repositories to the signed-in account.
  void _onAuthChanged() {
    final user = auth.currentUser;
    if (user?.uid == _attachedUid) return;
    _attachedUid = user?.uid;
    if (user == null) {
      unawaited(trips.detach());
      profile.detach();
    } else {
      unawaited(trips.attachUser(user.uid));
      unawaited(profile.attach(user));
    }
  }

  /// Retries anything that failed while offline (trips and profile).
  Future<SyncResult> syncAll() async {
    final user = auth.currentUser;
    if (user != null) await profile.refresh(user);
    return trips.syncNow();
  }
}

class AppScope extends InheritedWidget {
  final AppServices services;

  const AppScope({Key? key, required this.services, required Widget child})
      : super(key: key, child: child);

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
