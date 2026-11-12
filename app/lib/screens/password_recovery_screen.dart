import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../components/password_field.dart';
import '../services/auth_service.dart';

/// Password recovery request. Always shows the same confirmation (no account enumeration).
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});
  @override
  ConsumerState<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends ConsumerState<PasswordRecoveryScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    await ref.read(authServiceProvider).requestPasswordReset(_email.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _sent = true;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password recovery')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_sent)
            const Text(passwordResetConfirmation)
          else ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Send reset link')),
          ],
          TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
        ],
      ),
    );
  }
}

/// New password after following the recovery link. Enforces the policy and revokes other sessions.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    try {
      await ref.read(authServiceProvider).updatePassword(_password.text);
      if (mounted) context.go('/plants');
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Use at least 12 characters with upper- and lower-case letters and a digit.'),
            const SizedBox(height: 16),
            PasswordField(controller: _password, label: 'New password', newPassword: true, validator: (v) => validatePassword(v ?? '')),
            const SizedBox(height: 12),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              newPassword: true,
              validator: (v) => v == _password.text ? null : 'Passwords do not match.',
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Save password')),
          ],
        ),
      ),
    );
  }
}
