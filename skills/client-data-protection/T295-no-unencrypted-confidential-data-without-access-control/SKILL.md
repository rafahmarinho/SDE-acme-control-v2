---
name: t295-no-unencrypted-confidential-data-without-access-control
description: Wrap all client persistence behind a storage service that encrypts confidential data and uses app-private locations on every platform.
---

# T295: Avoid storing unencrypted confidential data without access control mechanisms

**Category:** CODE_FIX
**SD Elements:** [T295](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T295/)
**Priority:** 7

**Spec Context:**
> "mostre os últimos dados como leitura offline" / "Supabase para ... arquivos"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Different screens write to `shared_preferences`, temp files or browser storage directly, in plaintext.

**Secure Implementation Pattern:**
```dart
abstract class SecureStore {                       // single persistence entry point
  Future<void> put(String key, Uint8List plaintext); // AES-GCM, key from Keystore/Keychain
  Future<Uint8List?> get(String key);
  Future<void> wipe();
}
// Implementations: mobile -> app-private file + flutter_secure_storage key
//                  web    -> minimal; see T1468
```

**Implementation Guidance:**
- Lint/review rule: no direct `SharedPreferences`/`File` writes outside the storage service.
- Downloaded attachments are opened from memory or app-private temp and deleted after viewing.

**Success Criteria:**
- [ ] All persistence goes through `SecureStore` (code review).
- [ ] No plaintext confidential data on device storage.

**Status:** Applied
