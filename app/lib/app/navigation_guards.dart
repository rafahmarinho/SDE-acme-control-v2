/// Validation for anything that arrives through URLs or deep links (web URL, Android App Link,
/// iOS Universal Link). Deep links may only open read-only screens; they never execute
/// control actions. Only the `code` parameter of the auth callback is consumed.
final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');

bool isUuid(String? value) => value != null && _uuid.hasMatch(value);

/// Allow-listed in-app redirect target after login; anything else falls back to /plants.
String safeNext(String? next) {
  if (next == null || !next.startsWith('/') || next.startsWith('//') || next.contains('\\') || next.contains(':')) {
    return '/plants';
  }
  return next;
}

/// Paths reachable without a session.
const publicPaths = {'/login', '/password-recovery', '/reset-password', '/auth/callback'};

/// Screens a deep link may open directly (read-only). Command/setpoint/simulation screens are
/// excluded so a crafted link cannot land a user on a control action.
final _deepLinkable = RegExp(r'^/(login|password-recovery|reset-password|auth/callback|plants(/[0-9a-fA-F-]{36}(/(process|alarms|trends|equipment))?)?)$');

bool isAllowedDeepLink(Uri uri) => _deepLinkable.hasMatch(uri.path);

/// Extracts only the PKCE auth code from an auth callback, ignoring every other parameter.
String? authCallbackCode(Uri uri) {
  if (uri.path != '/auth/callback') return null;
  final code = uri.queryParameters['code'];
  if (code == null || code.isEmpty || code.length > 512 || !RegExp(r'^[A-Za-z0-9_\-.]+$').hasMatch(code)) return null;
  return code;
}
