---
name: t59-use-standard-cryptography-libraries
description: Use only vetted crypto - Web Crypto/Node crypto in the API, platform Keystore/Keychain via flutter_secure_storage and a maintained AES-GCM package in Dart - never custom algorithms.
---

# T59: Use standard libraries for cryptography

**Category:** CODE_FIX
**SD Elements:** [T59](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T59/)
**Priority:** 8

**Spec Context:**
> "mostre os últimos dados como leitura offline" / "login por e-mail e senha"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
"Encrypting" the offline cache with XOR/base64 or a hand-written cipher to avoid dependencies.

**Secure Implementation Pattern:**
```dart
import 'package:cryptography/cryptography.dart';
final algo = AesGcm.with256bits();
final key = await loadOrCreateKey();                 // stored in Keystore/Keychain (flutter_secure_storage)
final box = await algo.encrypt(utf8.encode(json), secretKey: key);   // random nonce per message
```
```ts
import { randomUUID, createHash, timingSafeEqual } from 'node:crypto';
```

**Implementation Guidance:**
- Password hashing is delegated to Supabase Auth; never hash passwords yourself.
- Use authenticated encryption (AES-GCM / ChaCha20-Poly1305) from maintained packages.
- Track crypto dependencies in the SBOM and update them (T186).

**Success Criteria:**
- [ ] No custom cipher/hash implementations in the codebase.
- [ ] Offline cache encryption uses an AEAD algorithm with per-message nonces.

**Status:** Applied
