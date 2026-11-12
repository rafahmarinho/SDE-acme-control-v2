---
name: t17-do-not-rely-on-client-side-authorization
description: Role-adapted navigation in Flutter is UX only; enforce operator/engineer/supervisor/maintenance permissions in the Vercel API and Supabase RLS.
---

# T17: Do not only rely on client-side authorization

**Category:** CODE_FIX
**SD Elements:** [T17](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T17/)
**Priority:** 8

**Spec Context:**
> "Adapte a navegação aos perfis de usuário." / "Tenha perfis de operador, engenheiro, supervisor e manutenção"
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
Hide the "Commands" or "Approve setpoint" menu items with go_router redirects and assume users who cannot see them cannot call them.

**Secure Implementation Pattern:**
```ts
// api/src/auth/permissions.ts
const can = {
  'pump.toggle':       ['operator', 'supervisor'],
  'valve.toggle':      ['operator', 'supervisor'],
  'mode.set':          ['operator', 'supervisor'],
  'setpoint.propose':  ['engineer'],
  'setpoint.review':   ['supervisor'],
  'equipment.lockout': ['maintenance'],
} as const;
export function authorize(role: Role, action: keyof typeof can) {
  if (!can[action].includes(role)) throw new HttpError(403, 'forbidden');
}
```

**Implementation Guidance:**
- Keep one server-side permission matrix; the Flutter router only mirrors it for navigation.
- Load the role from `profiles` using the verified user id (never from the request).
- Mirror read/write rules in Supabase RLS for direct client queries (T2598).
- Log denied attempts (T2602).

**Success Criteria:**
- [ ] Calling each `/api/*` action with a non-permitted role returns 403 (tests per role).
- [ ] Direct Supabase writes from the client to protected tables are blocked by RLS.

**Status:** Applied
