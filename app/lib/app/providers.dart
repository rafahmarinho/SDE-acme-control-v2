import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/command_service.dart';
import '../services/offline_cache_service.dart';
import '../services/secure_store.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
final offlineCacheProvider = Provider<OfflineCacheService>((ref) => OfflineCacheService(ref.watch(secureStoreProvider)));
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(supabaseProvider), ref.watch(offlineCacheProvider)));

final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

/// Providers holding user data depend on the session so they reset automatically on logout.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentSession;
});

final commandServiceProvider = Provider<CommandService>((ref) {
  ref.watch(sessionProvider);
  final service = CommandService(ref.watch(supabaseProvider));
  service.onSessionExpired = () => ref.read(authServiceProvider).signOut();
  return service;
});
