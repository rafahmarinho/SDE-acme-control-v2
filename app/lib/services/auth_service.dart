import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'offline_cache_service.dart';
import 'secure_store.dart';
import 'web_storage.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client mirror of the server password policy (supabase/config.toml). The server is
/// authoritative; this only gives early feedback on touch forms.
const minPasswordLength = 12;
String? validatePassword(String value) {
  if (value.length < minPasswordLength) return 'Use at least $minPasswordLength characters.';
  if (!RegExp('[a-z]').hasMatch(value) || !RegExp('[A-Z]').hasMatch(value) || !RegExp('[0-9]').hasMatch(value)) {
    return 'Use upper- and lower-case letters and at least one digit.';
  }
  return null;
}

/// Shown for every password-recovery request, whether or not the account exists.
const passwordResetConfirmation = 'If an account exists for this email, a reset link has been sent.';

class AuthService {
  AuthService(this._client, this._offlineCache);

  final SupabaseClient _client;
  final OfflineCacheService _offlineCache;
  int _consecutiveFailures = 0;

  /// Email/password sign-in with a single generic error and growing client-side backoff.
  /// Server-side throttling is configured in Supabase Auth rate limits.
  Future<void> signIn(String email, String password) async {
    if (_consecutiveFailures >= 3) {
      await Future<void>.delayed(Duration(seconds: 1 << min(_consecutiveFailures, 6)));
    }
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
      _consecutiveFailures = 0;
    } on AuthException {
      _consecutiveFailures++;
      throw const AuthFailure('Invalid email or password.');
    }
  }

  /// Re-authenticates the current user before critical actions (mode change, lockout,
  /// setpoint approval, demo reset), which the API requires within 15 minutes.
  Future<void> reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthFailure('Your session has expired. Please sign in again.');
    await signIn(email, password);
  }

  /// Requests a recovery email. Errors are swallowed so the response never reveals whether an
  /// account exists; the redirect target is a fixed, allow-listed URL.
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.resetRedirectUrl.isEmpty ? null : AppConfig.resetRedirectUrl,
      );
    } catch (_) {
      // Intentionally identical outcome for all cases (anti-enumeration).
    }
  }

  /// Sets a new password (after recovery or from Settings) and revokes all other sessions.
  Future<void> updatePassword(String newPassword) async {
    final problem = validatePassword(newPassword);
    if (problem != null) throw AuthFailure(problem);
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException {
      throw const AuthFailure('The password could not be changed. Please try again.');
    }
    await _client.auth.signOut(scope: SignOutScope.others);
  }

  /// Full client cleanup on logout, session error or expiry: stops realtime, revokes the
  /// refresh token, wipes the offline cache + its key and (on web) browser storage.
  Future<void> signOut({bool global = false}) async {
    try {
      await _client.removeAllChannels();
      await _client.auth.signOut(scope: global ? SignOutScope.global : SignOutScope.local);
    } catch (_) {
      // Continue local cleanup even if the network call fails.
    }
    await _offlineCache.wipe();
    if (!kIsWeb) {
      await secureStorage.deleteAll();
    } else {
      clearBrowserStorageAndReload();
    }
  }
}
