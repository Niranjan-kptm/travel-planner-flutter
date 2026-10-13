import 'package:flutter/material.dart';

/// Centered card with the app branding, shared by the auth screens.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthLayout({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: showBack
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.travel_explore, size: 56, color: scheme.primary),
                    const SizedBox(height: 8),
                    Text('AI Travel Planner',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 20),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner used by forms.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: scheme.onErrorContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        ),
      ]),
    );
  }
}

/// Button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  const BusyButton({
    Key? key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy ? const SizedBox.shrink() : Icon(icon ?? Icons.arrow_forward),
      label: child,
    );
  }
}
