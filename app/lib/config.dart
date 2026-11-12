import 'package:flutter/foundation.dart';

/// Public, build-time configuration (`--dart-define` / `--dart-define-from-file`).
/// Only PUBLIC values belong here - never the Supabase service-role key or other secrets.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const resetRedirectUrl = String.fromEnvironment('RESET_REDIRECT_URL');

  /// Simulation/demo area (scenarios, step, reset). Must be false for production builds.
  static const enableDemoTools = bool.fromEnvironment('ENABLE_DEMO_TOOLS');

  static const _devHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// Refuses to start with missing or non-HTTPS backend URLs (plain http only for local
  /// development hosts in debug builds).
  static void validate() {
    _requireSecureUrl('SUPABASE_URL', supabaseUrl);
    _requireSecureUrl('API_BASE_URL', apiBaseUrl);
    if (resetRedirectUrl.isNotEmpty) _requireSecureUrl('RESET_REDIRECT_URL', resetRedirectUrl);
    if (supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not configured');
    }
    if (kReleaseMode && enableDemoTools) {
      throw StateError('ENABLE_DEMO_TOOLS must be false in release builds');
    }
  }

  static void _requireSecureUrl(String name, String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('$name is not configured');
    }
    final devHttp = kDebugMode && uri.scheme == 'http' && _devHosts.contains(uri.host);
    if (uri.scheme != 'https' && !devHttp) {
      throw StateError('$name must use https');
    }
  }
}
