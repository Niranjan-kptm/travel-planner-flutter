import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({Key? key, this.initialEmail = ''}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) {
        // Do not reveal whether an account exists for this email.
        setState(() => e.code == 'EMAIL_NOT_FOUND' ? _sent = true : _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Reset password',
      subtitle: "Enter your email and we'll send you a reset link.",
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  'If an account exists for ${_email.text.trim()}, a password reset '
                  'email is on its way. Check your inbox (and spam folder).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to login'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(_error!),
                  TextFormField(
                    key: const Key('reset_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 20),
                  BusyButton(
                    key: const Key('reset_submit'),
                    busy: _busy,
                    onPressed: _submit,
                    label: 'Send reset link',
                    icon: Icons.send,
                  ),
                ],
              ),
            ),
    );
  }
}
