import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Platform key storage: Android Keystore-backed EncryptedSharedPreferences, iOS Keychain
/// (this device only, never synced to iCloud Keychain).
const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);

/// Single entry point for persisting confidential data on the device.
///
/// Data is encrypted with AES-256-GCM (random 96-bit nonce per write, authenticated) using a
/// random 256-bit key held in [secureStorage], and written to the app-private Application
/// Support directory, excluded from iOS backups. No other code may write confidential data to
/// SharedPreferences, external storage, temp files or browser storage.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage}) : _storage = storage ?? secureStorage;

  static const _keyName = 'acme.store.key.v1';
  static const _backupChannel = MethodChannel('acme/backup');
  final FlutterSecureStorage _storage;
  final _algo = AesGcm.with256bits();

  Future<SecretKey> _key() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return SecretKey(base64Decode(existing));
    final key = await _algo.newSecretKey(); // CSPRNG
    await _storage.write(key: _keyName, value: base64Encode(await key.extractBytes()));
    return key;
  }

  Future<File> _file(String name) async {
    if (!RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(name)) {
      throw ArgumentError('invalid store name');
    }
    final dir = await getApplicationSupportDirectory(); // app-private
    return File('${dir.path}/$name.bin');
  }

  Future<void> put(String name, Uint8List plaintext) async {
    if (kIsWeb) throw UnsupportedError('SecureStore is not used on web');
    final box = await _algo.encrypt(plaintext, secretKey: await _key());
    final file = await _file(name);
    await file.writeAsBytes(box.concatenation(), flush: true);
    if (Platform.isIOS) {
      await _backupChannel.invokeMethod<void>('excludeFromBackup', file.path);
    }
  }

  Future<Uint8List?> get(String name) async {
    if (kIsWeb) return null;
    final file = await _file(name);
    if (!await file.exists()) return null;
    try {
      final box = SecretBox.fromConcatenation(
        await file.readAsBytes(),
        nonceLength: _algo.nonceLength,
        macLength: _algo.macAlgorithm.macLength,
      );
      return Uint8List.fromList(await _algo.decrypt(box, secretKey: await _key()));
    } on SecretBoxAuthenticationError {
      await file.delete(); // tampered or key rotated: discard
      return null;
    }
  }

  Future<void> delete(String name) async {
    if (kIsWeb) return;
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }

  /// Deletes the encryption key, making any remaining ciphertext unreadable.
  Future<void> wipeKey() => _storage.delete(key: _keyName);
}
