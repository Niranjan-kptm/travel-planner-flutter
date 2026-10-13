import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/setup_required_screen.dart';
import 'services/trip_repository.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppServices? services;
  String? initError;
  try {
    final store = await TripRepository.createLocalStore();
    services = AppServices.create(store);
    await services.auth.restoreSession();
  } catch (e) {
    initError = e.toString();
  }
  runApp(TravelApp(services: services, initError: initError));
}

class TravelApp extends StatelessWidget {
  final AppServices? services;
  final String? initError;

  const TravelApp({Key? key, required this.services, this.initError})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = services;
    final app = MaterialApp(
      title: 'AI Travel Planner',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: s == null
          ? StartupErrorScreen(message: initError ?? 'unknown error')
          : const AuthGate(),
    );
    return s == null ? app : AppScope(services: s, child: app);
  }
}

/// Shows setup instructions, login or the app depending on the auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isConfigured) return const SetupRequiredScreen();
        if (auth.isRestoring) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return auth.isSignedIn ? const HomeShell() : const LoginScreen();
      },
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final String message;
  const StartupErrorScreen({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Startup error')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not open local storage:\n$message'),
      ),
    );
  }
}
