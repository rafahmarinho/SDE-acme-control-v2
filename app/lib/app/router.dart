import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../screens/alarms_screen.dart';
import '../screens/commands_screen.dart';
import '../screens/equipment_screen.dart';
import '../screens/login_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/password_recovery_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/plants_screen.dart';
import '../screens/process_view_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/setpoints_screen.dart';
import '../screens/shift_handover_screen.dart';
import '../screens/simulation_screen.dart';
import '../screens/trends_screen.dart';
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
    // Unknown hosts/paths from URLs or deep links are ignored: land on the plant list (T5657).
    onException: (_, __, router) => router.go('/plants'),
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
      GoRoute(path: '/plants', builder: (_, __) => const PlantsScreen()),
      GoRoute(
        path: '/plants/:plantId',
        pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => ProcessViewScreen(plantId: id))),
        routes: [
          GoRoute(path: 'process', redirect: (_, s) => '/plants/${s.pathParameters['plantId']}'),
          GoRoute(path: 'equipment', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => EquipmentScreen(plantId: id)))),
          GoRoute(path: 'alarms', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => AlarmsScreen(plantId: id)))),
          GoRoute(
            path: 'trends',
            pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => TrendsScreen(plantId: id, initialTag: s.uri.queryParameters['tag']))),
          ),
          // Control screens never execute anything on open: every action needs an explicit tap,
          // so a crafted link can at most display the screen (T170).
          GoRoute(path: 'commands', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => CommandsScreen(plantId: id)))),
          GoRoute(path: 'setpoints', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => SetpointsScreen(plantId: id)))),
          GoRoute(path: 'maintenance', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => MaintenanceScreen(plantId: id)))),
          GoRoute(path: 'handover', pageBuilder: (_, s) => _page(s, plantScoped(s, (id) => ShiftHandoverScreen(plantId: id)))),
        ],
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      // Demo tooling is not even registered in builds without ENABLE_DEMO_TOOLS (T49).
      if (AppConfig.enableDemoTools) GoRoute(path: '/simulation', builder: (_, __) => const SimulationScreen()),
    ],
  );
});

/// Plant sections switch instantly (tab-like), without a push animation.
Page<void> _page(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);

/// Re-evaluates redirects when the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
