import 'package:flutter/material.dart';

/// Shown when no Firebase project is configured. There is deliberately no
/// demo/guest login: authentication only works against a real Firebase project.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Create a Firebase project at console.firebase.google.com.',
      'Authentication > Sign-in method: enable Email/Password.',
      'Build > Realtime Database: create a database, then paste the rules from firebase/database.rules.json into the Rules tab and Publish.',
      'Project settings > General: copy the Web API Key.',
      'Open lib/config/app_config.dart and replace PASTE_YOUR_WEB_API_KEY_HERE and PASTE_YOUR_DATABASE_URL_HERE.',
      'Run the app again.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase setup required')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'This app uses real Firebase Authentication and Realtime Database. '
                'Connect it to your own Firebase project to sign up and log in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < steps.length; i++)
                ListTile(
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                  title: Text(steps[i]),
                ),
              const SizedBox(height: 12),
              const Text(
                'See README.md for full instructions, including FlutLab-specific steps.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
