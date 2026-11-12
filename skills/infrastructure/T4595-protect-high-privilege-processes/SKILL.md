---
name: t4595-protect-high-privilege-processes
description: OS-level protection of privileged processes is provided by the managed Vercel and Supabase platforms; document the shared-responsibility boundary and apply it to any self-hosted component.
---

### Task T4595: Protect processes with high privileges (NON-CODE)

**Category:** INFRA
**SD Elements:** [T4595](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T4595/)
**Priority:** 8

**Guidance:** Protect OS, credential-management, database and configuration processes with trusted-execution mechanisms (PPL, kernel protections, least privilege).

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md deployment and stack sections - "API TypeScript na Vercel", "Supabase para PostgreSQL".
- Found: all server processes run on managed platforms (Vercel functions, Supabase-managed Postgres/Auth/Storage).
- Missing: no self-managed hosts or OS in the architecture.
- Conclusion: the platform providers own process protection, so INFRA.

**Recommended Action:** Security owner records the shared-responsibility model (Vercel/Supabase SOC 2 reports) and applies this countermeasure if any self-hosted component (e.g. on-prem gateway to real PLCs) is introduced.

**DOCUMENTATION ONLY** - repository inventory checked: no Dockerfile, host configuration or self-managed OS exists; all server processes run on managed Vercel/Supabase. Listed under "Platform-owned controls" in README.md.

**Status:** Documented
