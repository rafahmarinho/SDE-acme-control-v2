---
name: t1468-encrypt-sensitive-data-at-rest-in-browser
description: In the Flutter web build keep browser storage to the Supabase session only; if any offline cache is added on web, encrypt it with a non-extractable Web Crypto key.
---

# T1468: Encrypt sensitive data at rest in the browser

**Category:** CODE_FIX
**SD Elements:** [T1468](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T1468/)
**Priority:** 9

**Spec Context:**
> "Os resultados devem aparecer nas telas e continuar salvos após recarregar a aplicação." / "No celular ... leitura offline"
> Source: docs/specs/PRD.md, paragraphs 5 and 6 (offline is required on mobile, not web)

**What the spec implies (naive approach):**
To survive reloads, the web build writes plant data, events and profile to `localStorage` in plaintext.

**Secure Implementation Pattern:**
```text
Web: data survives reload because it lives in Supabase - re-fetch on load.
Browser storage: only the Supabase auth session (required by supabase_flutter).
If a web offline cache is ever added: IndexedDB + AES-GCM with a non-extractable
CryptoKey (crypto.subtle.generateKey(..., false, ...)), wiped on logout (T1539).
```

**Implementation Guidance:**
- Disable the offline cache service on web (`kIsWeb`) unless a requirement appears.
- Keep access tokens short-lived (T20) to limit exposure of the stored session.

**Success Criteria:**
- [ ] On web, localStorage contains only the Supabase session key.

**Status:** Pending
