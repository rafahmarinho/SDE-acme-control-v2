---
name: t2602-log-database-and-server-activities
description: Log every control command, interlock block, setpoint proposal/review, lockout, simulation step/reset, auth failure and permission denial with who/what/when/where metadata.
---

# T2602: Log typical database and server activities and related metadata

**Category:** CODE_FIX
**SD Elements:** [T2602](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T2602/)
**Priority:** 8

**Spec Context:**
> "consultar eventos" / "Mostre o estado solicitado e o estado real." / "propostas de alteração de setpoints analisadas pelo supervisor"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
An "events" list showing only process alarms, with no record of who started a pump or approved a setpoint.

**Secure Implementation Pattern:**
```ts
await audit({
  actor: user.id, role, plantId, action: 'pump.start', target: pumpId,
  requested: { state: 'on' }, result: { accepted: false, reason: 'tank_empty' },
  requestId, ip: req.headers.get('x-forwarded-for')?.split(',')[0], userAgent: req.headers.get('user-agent'),
});
```

**Implementation Guidance:**
- One `audit()` helper writing to `internal.audit_log` (T349) from the API; DB triggers for direct table changes.
- Log successes and failures, including 401/403/409/429.
- Never log secrets, tokens or passwords; keep messages in English.
- Enable Supabase/Postgres logging (pgaudit where available) for DDL and config changes.

**Success Criteria:**
- [ ] Every command and setpoint decision produces exactly one audit entry with actor, time, target, request and result.
- [ ] Logs contain no tokens or passwords (test).

**Status:** Applied
