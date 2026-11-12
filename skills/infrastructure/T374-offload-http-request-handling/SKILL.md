---
name: t374-offload-http-request-handling
description: Rely on Vercel's edge network and firewall (WAF, DDoS mitigation, attack challenge mode) to absorb slow/abusive HTTP traffic before it reaches the API functions.
---

### Task T374: Offload HTTP request handling to dedicated modules (NON-CODE)

**Category:** INFRA
**SD Elements:** [T374](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T374/)
**Priority:** 7

**Guidance:** Offload request handling to the OS/edge and configure firewall/QoS/security modules to resist resource-exhaustion (DoS) attacks.

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md - "API TypeScript na Vercel", "publicar a versão web e a API na Vercel".
- Found: the API runs as Vercel serverless functions; there is no self-managed HTTP server or OS socket layer.
- Missing: application code cannot configure the listening socket or edge modules.
- Conclusion: handled by the hosting platform configuration (Vercel Firewall/WAF), so INFRA. App-level limits are covered by T35, T536 and T1362.

**Recommended Action:** Platform owner enables Vercel Firewall rules (rate limiting on `/api/*`, bot protection, attack challenge mode on incidents) and documents them in the deployment README.

**DOCUMENTATION ONLY** - repository inventory checked (api/vercel.json, app/web/vercel.json, supabase/config.toml): vercel.json cannot express Vercel Firewall/WAF rules. Listed under "Platform-owned controls" in README.md.

**Status:** Documented
