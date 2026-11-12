---
name: t69-strong-credentials-for-system-accounts
description: Server-to-server credentials (Supabase service-role key, database password, Vercel tokens) are provisioned with strong random values in platform dashboards and rotated on a schedule.
---

### Task T69: Strong password requirements for server-to-server system accounts (NON-CODE)

**Category:** INFRA
**SD Elements:** [T69](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T69/)
**Priority:** 8

**Guidance:** System accounts used for server-to-server authentication must meet at least the end-user password policy.

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md - "API TypeScript na Vercel", "Supabase", "exemplos de variáveis de ambiente".
- Found: the API authenticates to Supabase with platform-issued keys stored as Vercel env vars.
- Missing: credential generation/rotation happens in the Supabase and Vercel consoles, not in code.
- Conclusion: INFRA. Keeping the secrets out of code is covered by T248/T76.

**Recommended Action:** Platform owner sets a strong random database password, uses the new Supabase secret API keys where available, stores them as "Sensitive" Vercel env vars, and rotates them at least yearly or on staff changes.

**Status:** Documented
