# AI Travel Planner (Flutter + Firebase) — v2

Personalized travel planning and tourism app, upgraded from `travel_planner_flutlab_v2`.

| Area | What it does |
|---|---|
| Authentication | Firebase email/password: register, login, logout, forgot password, persistent session with token refresh |
| Profile | Name, phone, home city, preferred travel type, interests, typical budget → stored at `/users/<uid>/profile` |
| Dashboard | Time-based greeting, destination search, popular destinations, personalised recommendations, upcoming trips |
| Planner | Destination (autocomplete or any city), date range, total budget in ₹ INR, travellers, travel type, interests → recommendations or a trip with a generated day-by-day itinerary |
| Trips (CRUD) | Create, list/search/filter, view details, edit (incl. itinerary days), delete with confirmation |
| Cloud | Firebase Realtime Database, per-user data at `/users/<uid>/trips/<tripId>`, live updates (REST streaming), secure rules in `database.rules.json` |
| Offline | Android/iOS: SQLite (`sqflite`, schema v2, migrates v1 data). Web: browser `localStorage` via `shared_preferences` (not SQLite). Local-first writes, pending queue, delete tombstones, newest-`updatedAt`-wins merge, auto retry every 30 s |
| "AI" | Transparent **rule-based** scoring (travel type 35, budget 25, duration 15, interests 15, name match 10) and rule-based itineraries. No trained ML model is used. |

Firebase is used via its official REST APIs (Identity Toolkit, Secure Token, Realtime Database), so no
`google-services.json` / native Firebase plugins are needed and the same code runs on Android, iOS and Web in FlutLab.
**No credentials are bundled** — the app shows a setup screen until you add yours.

## 1. Firebase setup (one time, ~5 min)

1. https://console.firebase.google.com → **Add project**.
2. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable**.
3. **Build → Realtime Database → Create database** (pick a location, start in *locked mode*).
4. Realtime Database → **Rules** tab → paste the content of `database.rules.json` → **Publish**.
   These rules deny everything by default, let a signed-in user read/write only `/users/<their uid>`,
   and validate field types/lengths (budget ≤ ₹1 crore, 1–20 travellers, `yyyy-MM-dd` dates, endDate ≥ startDate, no unknown fields).
5. **Project settings (⚙) → General → Your apps → Add app → Web (</>)** → register. Copy:
   - `apiKey` (Web API key, e.g. `AIza...`)
   - `databaseURL` (e.g. `https://<project>-default-rtdb.<region>.firebasedatabase.app`) — also shown at the top of the Realtime Database page.
6. Optional: Authentication → Templates to customise the password-reset email.

## 2. Add your configuration

Either edit the defaults in `lib/config/app_config.dart`:

```dart
defaultValue: 'PASTE_YOUR_WEB_API_KEY_HERE',   // -> your apiKey
defaultValue: 'PASTE_YOUR_DATABASE_URL_HERE',  // -> your databaseURL
```

or (preferred, keeps keys out of source) pass them at build time:

```bash
flutter run --dart-define=FIREBASE_API_KEY=AIza... --dart-define=FIREBASE_DB_URL=https://<project>-default-rtdb.<region>.firebasedatabase.app
```

The Web API key identifies the project; access is protected by Authentication + the database rules.

## 3. Run in FlutLab

1. FlutLab → **Projects → Upload project** → choose this ZIP (or create a Flutter project and replace `lib/`, `test/`, `pubspec.yaml`).
2. Open `pubspec.yaml` → **Pub get**.
3. Put your API key + DB URL in `lib/config/app_config.dart` (FlutLab has no `--dart-define` field).
4. Select **Web** (or an Android emulator) and press **Run**.
5. Register an account → you land on the dashboard. Data appears in the Firebase console under `users/<uid>`.

Flutter SDK requirement: Dart 3 (Flutter ≥ 3.10). Verified with Flutter 3.19.6 and 3.47.7.

Local machine:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome           # plus the --dart-define flags above
flutter build web --release
```

## 4. Optional: Firebase Emulator (no real project needed)

```bash
npm i -g firebase-tools@13
firebase emulators:start --only auth,database --project demo-travel-planner
flutter run -d chrome --dart-define=FIREBASE_EMULATOR_HOST=localhost
```

`test/firebase_emulator_test.dart` runs the real auth + database services against the emulator
(`FIREBASE_EMULATOR_HOST=localhost flutter test test/firebase_emulator_test.dart`); it is skipped when the variable is not set.

## Project structure

```
lib/
  main.dart                  app start, AuthGate (setup / login / home)
  app_scope.dart             service container, attaches repos on login/logout
  config/app_config.dart     Firebase config (dart-define or defaults), emulator switch
  models/                    trip.dart (Trip, ItineraryDay), user_profile.dart
  services/
    auth_service.dart        Firebase Auth REST (register/login/reset/refresh/session)
    firebase_service.dart    Realtime Database REST + live stream
    rtdb_stream_*.dart       SSE streaming (dart:io / browser EventSource)
    trip_repository.dart     local-first CRUD + sync engine
    profile_repository.dart  cached profile + sync
    sqlite_store.dart        SQLite v2 (mobile)   web_fallback_store.dart  browser storage (web)
    recommendation_service.dart, itinerary_service.dart   rule-based engines
  screens/                   auth/, dashboard, planner, results, trip form/details, my trips, profile, db viewer
  widgets/                   cards, chips, selectors, sync status
database.rules.json          Realtime Database security rules
firebase.json                emulator config
test/                        unit tests, real SQLite (ffi) test, emulator integration test
```

## Known limitations

- Recommendations/itineraries are rule-based over a built-in list of destinations; costs are illustrative estimates, not live prices or bookings.
- Web stores trips in browser `localStorage` (per user), not SQLite; clearing site data removes the offline copy (cloud copy remains).
- Conflict resolution is per trip, last-write-wins by device clock (`updatedAt`).
- Live updates use the Realtime Database REST streaming API; when it drops, the app reconnects with backoff and also polls every 30 s.
- Email verification and social sign-in are not implemented. Password reset relies on Firebase's email delivery.
- Session tokens are stored in `shared_preferences` (not an encrypted keystore).
