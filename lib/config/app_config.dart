/// App-wide Firebase settings.
///
/// Edit the two placeholders below with values from YOUR Firebase project
/// (see README.md, section "Firebase setup"), or pass them at build time:
///   flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_DB_URL=...
///
/// Nothing here is a real credential. Until both values are set the app shows
/// a "Firebase setup required" screen instead of a fake login.
class AppConfig {
  /// Project settings > General > "Web API Key" in the Firebase console.
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDq2FVgodBNvMzcPpYHMGaU8zka8Z5nyUI',
  );

  /// Realtime Database > Data tab, the URL at the top, for example
  ///   https://your-project-id-default-rtdb.firebaseio.com
  ///   https://your-project-id-default-rtdb.asia-southeast1.firebasedatabase.app
  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DB_URL',
    defaultValue: 'https://travel-planner-709c5-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  /// Optional: host of the local Firebase Emulator Suite (e.g. "localhost").
  /// When set, the app talks to the Auth emulator (port 9099) and the
  /// Realtime Database emulator (port 9000) instead of production Firebase.
  static const String emulatorHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');

  /// Realtime Database namespace used with the emulator.
  static const String emulatorNamespace = String.fromEnvironment(
    'FIREBASE_EMULATOR_NS',
    defaultValue: 'demo-travel-planner-default-rtdb',
  );

  static bool get useEmulator => emulatorHost.isNotEmpty;

  static bool get apiKeyConfigured =>
      firebaseApiKey.isNotEmpty && !firebaseApiKey.startsWith('PASTE_YOUR');

  static bool get databaseConfigured =>
      firebaseDatabaseUrl.startsWith('https://') &&
      !firebaseDatabaseUrl.contains('PASTE_YOUR');

  /// True when both Firebase Authentication and the Realtime Database can be used.
  static bool get firebaseConfigured =>
      useEmulator || (apiKeyConfigured && databaseConfigured);

  /// Auth REST API key. The emulator accepts any non-empty key.
  static String get effectiveApiKey =>
      apiKeyConfigured ? firebaseApiKey : (useEmulator ? 'emulator-key' : '');

  static String get authBaseUrl => useEmulator
      ? 'http://$emulatorHost:9099/identitytoolkit.googleapis.com/v1'
      : 'https://identitytoolkit.googleapis.com/v1';

  static String get tokenUrl => useEmulator
      ? 'http://$emulatorHost:9099/securetoken.googleapis.com/v1/token'
      : 'https://securetoken.googleapis.com/v1/token';

  static String get databaseBaseUrl {
    if (useEmulator) return 'http://$emulatorHost:9000';
    var u = firebaseDatabaseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Extra query parameters required by the database emulator.
  static Map<String, String> get databaseQueryExtras =>
      useEmulator ? {'ns': emulatorNamespace} : const {};
}
