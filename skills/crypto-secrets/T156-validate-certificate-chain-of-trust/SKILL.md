---
name: t156-validate-certificate-chain-of-trust
description: Keep platform TLS certificate validation intact in Flutter (web, Android, iOS) and the Node API; never override bad-certificate handlers or disable verification.
---

# T156: Validate certificate and its chain of trust properly

**Category:** CODE_FIX
**SD Elements:** [T156](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T156/)
**Priority:** 7

**Spec Context:**
> "Use uma API TypeScript na Vercel" / "Supabase para ... atualizações em tempo real"
> Source: docs/specs/PRD.md, paragraphs 2 and 3

**What the spec implies (naive approach):**
During local development someone adds `badCertificateCallback = (_, __, ___) => true` or `NODE_TLS_REJECT_UNAUTHORIZED=0` and it ships.

**Secure Implementation Pattern:**
```dart
// Do NOT do this anywhere:
// HttpOverrides.global = MyOverrides(); client.badCertificateCallback = (c, h, p) => true;
// Use default clients; supabase_flutter and http use platform trust stores.
```
```ts
if (process.env.NODE_TLS_REJECT_UNAUTHORIZED === '0') throw new Error('TLS verification must not be disabled');
```

**Implementation Guidance:**
- Rely on OS/browser chain, hostname and expiry validation; use HTTPS/WSS URLs only (T558).
- Add a CI grep failing on `badCertificateCallback`, `HttpOverrides`, `rejectUnauthorized: false`.
- Certificate pinning is optional for a later hardening phase (not selected in the survey).

**Success Criteria:**
- [ ] CI check for TLS-disabling patterns passes.
- [ ] API refuses to start with TLS verification disabled.

**Status:** Applied
