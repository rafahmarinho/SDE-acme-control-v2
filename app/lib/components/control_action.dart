import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/plant_providers.dart';
import '../app/providers.dart';
import '../services/auth_service.dart';
import '../services/command_service.dart';
import 'password_field.dart';

/// Runs a control action against the API with consistent UX:
/// - refuses while offline (control actions are never queued - PRD),
/// - asks for the password when the API requires a recent login, then retries once,
/// - shows friendly messages (never raw server output).
/// Returns true when the API accepted the action.
Future<bool> runControlAction(BuildContext context, WidgetRef ref, Future<Object?> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String m, {bool error = false}) => messenger.showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? Theme.of(context).colorScheme.errorContainer : null,
        showCloseIcon: true,
      ));

  if (!(ref.read(onlineProvider).valueOrNull ?? true)) {
    show(const OfflineException().message, error: true);
    return false;
  }
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      await action();
      if (success != null) show(success);
      return true;
    } on ReauthenticationRequiredException {
      if (attempt > 0 || !context.mounted) break;
      final ok = await confirmPassword(context, ref);
      if (!ok) return false;
    } on CommandException catch (e) {
      show(e.message, error: true);
      return false;
    } catch (_) {
      show('The action could not be completed.', error: true);
      return false;
    }
  }
  show(const ReauthenticationRequiredException().message, error: true);
  return false;
}

/// Re-authentication dialog for critical actions (mode change, lockout, approval, demo reset).
Future<bool> confirmPassword(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  String? error;
  var busy = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> submit() async {
          setState(() {
            busy = true;
            error = null;
          });
          try {
            await ref.read(authServiceProvider).reauthenticate(controller.text);
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } on AuthFailure catch (e) {
            setState(() => error = e.message);
          } finally {
            controller.clear();
            if (ctx.mounted) setState(() => busy = false);
          }
        }

        return AlertDialog(
          title: const Text('Confirm your password'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This is a critical action. Confirm your password to continue.'),
            const SizedBox(height: 12),
            PasswordField(controller: controller, onSubmitted: (_) => submit()),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: busy ? null : submit, child: const Text('Confirm')),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result ?? false;
}

/// Simple confirmation dialog for impactful actions.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, String confirm = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}
