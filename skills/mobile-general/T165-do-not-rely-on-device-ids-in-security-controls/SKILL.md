---
name: t165-do-not-rely-on-device-ids-in-security-controls
description: Device or install identifiers are never used for authentication or authorization of plant control actions; only verified user sessions and roles are.
---

# T165: Do not rely on Unique Device ID values in security controls

**Category:** CODE_FIX
**SD Elements:** [T165](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T165/)
**Priority:** 9

**Spec Context:**
> "Tenha perfis de operador, engenheiro, supervisor e manutenção" / "ações de controle exigem conexão"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
"Trusted control-room tablets": allow commands without login if the request carries a known device id.

**Secure Implementation Pattern:**
```ts
// API: identity and permissions only from the verified JWT + database role
const user = await requireUser(req);          // T558
authorize(await loadRole(user.id), action);    // T17
// installId (if sent) is metadata for the audit log only
```

**Implementation Guidance:**
- No device allow-lists replacing user authentication.
- Device id may be used as a hint (e.g. "new device sign-in" notification), never as a factor.

**Success Criteria:**
- [ ] No code path grants access based on device/install id.

**Status:** Applied
