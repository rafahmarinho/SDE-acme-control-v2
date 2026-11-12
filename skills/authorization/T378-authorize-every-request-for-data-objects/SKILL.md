---
name: t378-authorize-every-request-for-data-objects
description: Check object-level permissions (plant, equipment, setpoint proposal, maintenance order, file) on every request, using the session identity, to prevent IDOR.
---

# T378: Authorize every request for data objects

**Category:** CODE_FIX
**SD Elements:** [T378](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T378/)
**Priority:** 8

**Spec Context:**
> "Prepare dados de demonstração com duas plantas industriais." / "propostas de alteração de setpoints analisadas pelo supervisor"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
`POST /api/setpoints/:id/approve` approves any proposal id passed in the URL, including the supervisor's own proposals or proposals for a plant they are not assigned to.

**Secure Implementation Pattern:**
```ts
const proposal = await db.from('setpoint_proposals').select('*').eq('id', id).single();
if (!proposal.data) return json(404, { error: 'not_found' });
if (!(await userHasPlant(user.id, proposal.data.plant_id))) return json(404, { error: 'not_found' });
if (proposal.data.proposed_by === user.id) return json(403, { error: 'separation_of_duties' });
```

**Implementation Guidance:**
- Model plant membership (`plant_members(user_id, plant_id, role)`) and check it for every object.
- Return 404 (not 403) for objects outside the user's scope to avoid enumeration.
- Enforce separation of duties: a proposer cannot approve their own proposal.
- Back the same rules with RLS (T2598).

**Success Criteria:**
- [ ] Accessing another plant's equipment/proposal by id returns 404.
- [ ] Self-approval of a setpoint proposal is rejected.

**Status:** Pending
