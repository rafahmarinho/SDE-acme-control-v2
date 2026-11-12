# Cryptography profile

| Use | Algorithm / mechanism | Where |
|-----|----------------------|-------|
| Offline cache encryption (mobile) | AES-256-GCM, random 96-bit nonce per write (`cryptography` package) | `app/lib/services/secure_store.dart` |
| Cache key storage | Android Keystore (EncryptedSharedPreferences) / iOS Keychain `first_unlock_this_device`, non-synchronizable | `flutter_secure_storage` |
| Session storage (mobile) | Keychain / Keystore | `secure_session_storage.dart` |
| Audit log integrity | SHA-256 hash chain (pgcrypto `digest`) | `internal.audit_hash_chain()` |
| Identifiers, demo passwords | `node:crypto` `randomUUID` / `randomBytes`; Dart `Uuid().v4()` / `Random.secure()` | API, app |
| Password hashing | Delegated to Supabase Auth (bcrypt) - never implemented locally | - |
| Transport | TLS 1.2+ terminated by Vercel and Supabase; HSTS; HTTPS/WSS-only client config | platform |

Forbidden: MD5, SHA-1, DES/3DES, RC4, ECB mode, base64/gzip as "encryption", custom ciphers,
`Math.random` outside `api/src/simulation/`, disabling TLS verification
(`badCertificateCallback`, `HttpOverrides`, `NODE_TLS_REJECT_UNAUTHORIZED=0`).
CI (`.github/workflows/security.yml`) fails on these patterns.
