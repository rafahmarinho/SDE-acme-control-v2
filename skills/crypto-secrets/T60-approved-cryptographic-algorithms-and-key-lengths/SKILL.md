---
name: t60-approved-cryptographic-algorithms-and-key-lengths
description: Restrict crypto to approved algorithms and sizes (AES-256-GCM, SHA-256+, HMAC-SHA-256, TLS 1.2+) and forbid encoding/compression as "encryption".
---

# T60: Use correct and approved cryptographic algorithms, parameters, and key lengths

**Category:** CODE_FIX
**SD Elements:** [T60](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T60/)
**Priority:** 8

**Spec Context:**
> "Use versões atuais e estáveis das tecnologias" / "mostre os últimos dados como leitura offline"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
MD5/SHA-1 for event integrity hashes, AES-ECB or 128-bit keys derived from a constant for the offline cache, base64 treated as protection.

**Secure Implementation Pattern:**
```text
Symmetric encryption : AES-256-GCM, 96-bit random nonce, never reused
Hashing / integrity  : SHA-256 (or SHA-512); HMAC-SHA-256 for keyed integrity
Key derivation       : HKDF-SHA-256 from Keystore/Keychain-held random keys
Transport            : TLS 1.2+ (platform defaults; no custom cipher downgrades)
Forbidden            : MD5, SHA-1, DES/3DES, RC4, ECB mode, base64/gzip as encryption
```

**Implementation Guidance:**
- Document the crypto profile in `docs/security/crypto.md` and reference it in code review.
- Keys are random (T151), 256-bit, never derived from user ids or constants.
- If audit log hash-chaining is added (T349), use SHA-256.

**Success Criteria:**
- [ ] grep finds no md5/sha1/ECB usage.
- [ ] All encryption keys are 256-bit random values held in secure storage.

**Status:** Pending
