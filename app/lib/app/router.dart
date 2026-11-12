import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../screens/login_screen.dart';
import '../screens/password_recovery_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shift_handover_screen.dart';
import 'navigation_guards.dart';
import 'providers.dart';

/// Routes from the PRD. Role-based visibility here is UX only: the API and Supabase RLS are the
/// enforcement points. Path parameters are validated; redirects after login are allow-listed.
final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseProvider);

  Widget plantScoped(GoRouterState state, Widget Function(String plantId) build) {
    final plantId = state.pathParameters['plantId'];
    return isUuid(plantId) ? build(plantId!) : const PlaceholderScreen(title: 'Not found');
  }

  return GoRouter(
    initialLocation: '/plants',
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentSession != null;
      final path = state.uri.path;
      if (!loggedIn && !publicPaths.contains(path)) {
        return '/login?next=${Uri.encodeComponent(safeNext(state.uri.toString()))}';
      }
      if (loggedIn && path == '/login') return safeNext(state.uri.queryParameters['next']);
      if (path == '/simulation' && !AppConfig.enableDemoTools) return '/plants';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(next: safeNext(s.uri.queryParameters['next']))),
      GoRoute(path: '/password-recovery', builder: (_, __) => const PasswordRecoveryScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      // supabase_flutter exchanges the PKCE code itself; this route only lands the user safely.
      GoRoute(path: '/auth/callback', redirect: (_, s) => authCallbackCode(s.uri) == null ? '/login' : '/reset-password'),
      GoRoute(path: '/plants', builder: (_, __) => const PlaceholderScreen(title: 'Plants')),
      GoRoute(
        path: '/plants/:plantId',
        builder: (_, s) => plantScoped(s, (_) => const PlaceholderScreen(title: 'Process view')),
        routes: [
          for (final page in const ['equipment', 'alarms', 'trends', 'commands', 'setpoints', 'maintenance'])
            GoRoute(path: page, builder: (_, s) => plantScoped(s, (_) => PlaceholderScreen(title: page))),
          GoRoute(path: 'handover', builder: (_, s) => plantScoped(s, (id) => ShiftHandoverScreen(plantId: id))),
        ],
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      if (AppConfig.enableDemoTools) GoRoute(path: '/simulation', builder: (_, __) => const PlaceholderScreen(title: 'Simulation')),
    ],
  );
});

/// Re-evaluates redirects when the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
