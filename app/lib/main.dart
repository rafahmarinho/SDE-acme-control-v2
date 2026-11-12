import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'config.dart';
import 'services/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate(); // https-only backends, public config only, demo tools off in release

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // Mobile: session in Keychain/Keystore. Web: supabase default (session only).
      localStorage: kIsWeb ? null : const SecureSessionStorage(),
    ),
    debug: false,
  );

  runApp(const ProviderScope(child: AcmeControlApp()));
}

class AcmeControlApp extends ConsumerWidget {
  const AcmeControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Any sign-out (explicit, expiry, revoked refresh token) triggers full local cleanup.
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.signedOut) {
        ref.read(offlineCacheProvider).wipe();
      }
    });
    return MaterialApp.router(
      title: 'ACME Control',
      debugShowCheckedModeBanner: false,
      theme: acmeDarkTheme,
      darkTheme: acmeDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
