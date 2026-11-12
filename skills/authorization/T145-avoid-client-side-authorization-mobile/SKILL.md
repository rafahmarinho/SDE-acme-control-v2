---
name: t145-avoid-client-side-authorization-mobile
description: Treat the Android/iOS Flutter binaries as untrusted; interlocks, role checks and "requires connection" rules for control actions must be enforced by the server.
---

# T145: Avoid client-side authorization for mobile clients

**Category:** CODE_FIX
**SD Elements:** [T145](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T145/)
**Priority:** 8

**Spec Context:**
> "uma bomba não funciona se o tanque estiver vazio ou o equipamento estiver em manutenção" / "ações de controle exigem conexão"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
Disable the pump button in the app when the tank is empty or the user is not an operator, and trust that a disabled button means the action cannot happen.

**Secure Implementation Pattern:**
```ts
// api/api/commands.ts
const user = await requireUser(req);
const role = await loadRole(user.id);
authorize(role, `${cmd.target}.toggle`);
const state = await loadEquipmentState(cmd.equipmentId);   // from DB, not from client
const blocked = checkInterlocks(cmd, state);              // empty tank / maintenance
if (blocked) return json(409, { error: blocked.reason });
```

**Implementation Guidance:**
- Assume a decompiled/modified APK/IPA can send any request; the app never decides permissions.
- Interlocks run in `api/src/commands/interlocks.ts` on server-loaded state.
- The client may grey out controls for UX, but the API returns 403/409 for forbidden/blocked actions.

**Success Criteria:**
- [ ] A crafted request to start a pump on an empty tank returns 409.
- [ ] A crafted request from a maintenance user to change a setpoint returns 403.

**Status:** Pending
