import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_store.dart';

/// Persists the Supabase session in the Keychain / Android Keystore-backed storage instead of
/// plaintext SharedPreferences / NSUserDefaults. Used on Android and iOS.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _key = 'acme.supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => secureStorage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => secureStorage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) => secureStorage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => secureStorage.delete(key: _key);
}
