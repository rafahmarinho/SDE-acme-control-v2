---
name: t35-fine-tune-http-server-settings
description: Tune the Vercel function limits (duration, memory, allowed methods, headers) and add security headers and violation logging for the API.
---

# T35: Fine-tune HTTP server settings

**Category:** CODE_FIX
**SD Elements:** [T35](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T35/)
**Priority:** 9

**Spec Context:**
> "Use uma API TypeScript na Vercel para os comandos e a simulação." / "README com os passos para ... publicar ... a API na Vercel"
> Source: docs/specs/PRD.md, paragraphs 3 and 6

**What the spec implies (naive approach):**
Default Vercel settings: long function durations, every HTTP verb accepted, no response hardening, no alerting on oversized/abusive requests.

**Secure Implementation Pattern:**
```json
// api/vercel.json
{
  "functions": { "api/**/*.ts": { "maxDuration": 10, "memory": 512 } },
  "headers": [{ "source": "/api/(.*)", "headers": [
    { "key": "Cache-Control", "value": "no-store" },
    { "key": "X-Content-Type-Options", "value": "nosniff" },
    { "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains" }
  ]}]
}
```
```ts
if (!route.methods.includes(req.method)) return json(405, { error: 'method_not_allowed' });
```

**Implementation Guidance:**
- Per-route method allow-list; reject unexpected methods with 405.
- Limit header count/size where the runtime allows; reject oversized bodies (T536).
- Log 405/413/429 events to `security_events` and alert the supervisor role (T2602).

**Success Criteria:**
- [ ] `maxDuration` ≤ 10 s for API functions.
- [ ] Unsupported methods return 405 and are logged.

**Status:** Applied
