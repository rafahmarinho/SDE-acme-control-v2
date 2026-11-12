---
name: t21-encrypt-data-in-transit-tls
description: TLS termination (protocol versions, ciphers, certificates) is managed by Vercel and Supabase; verify their configuration and custom-domain certificates, while app code enforces HTTPS-only URLs.
---

### Task T21: Ensure all data in transit is encrypted using a secure TLS channel (NON-CODE)

**Category:** INFRA
**SD Elements:** [T21](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T21/)
**Priority:** 8

**Guidance:** Use TLS 1.2/1.3 only, refuse insecure ciphers and plaintext authentication.

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md - "publicar a versão web e a API na Vercel", "Supabase para PostgreSQL ... atualizações em tempo real".
- Found: all endpoints are served by Vercel and Supabase, which terminate TLS.
- Missing: the application cannot select TLS versions/ciphers on those platforms.
- Conclusion: INFRA. Client-side HTTPS enforcement is covered by T558, T146 and T156; HSTS by T66/T35.

**Recommended Action:** Platform owner verifies TLS settings (e.g. SSL Labs scan of the web and API domains), manages custom-domain certificates in Vercel, and enables Supabase "enforce SSL" for direct database connections.

**Applied in repository:** HSTS (`max-age=63072000; includeSubDomains`) in `api/vercel.json` and `app/web/vercel.json`; HTTPS-only backend URLs enforced in `api/src/lib/env.ts` and `app/lib/config.dart`; Android cleartext disabled; iOS ATS without exceptions. TLS versions/ciphers remain platform-managed (Vercel/Supabase) - verify with an SSL Labs scan and enable Supabase "Enforce SSL".

**Status:** Applied
