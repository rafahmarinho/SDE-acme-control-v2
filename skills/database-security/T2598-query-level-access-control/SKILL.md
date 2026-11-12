---
name: t2598-query-level-access-control
description: Define per-role, per-table Row Level Security policies and column privileges in Supabase so each of the four roles can only read or change what the PRD allows.
---

# T2598: Implement query-level access control

**Category:** CODE_FIX
**SD Elements:** [T2598](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T2598/)
**Priority:** 8

**Spec Context:**
> "Tenha perfis de operador, engenheiro, supervisor e manutenção" / "Entregue ... configuração do banco"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
All authenticated users get full `select/insert/update/delete` on every table because the UI already filters by role.

**Secure Implementation Pattern:**
```sql
create function public.my_role(p_plant uuid) returns text language sql stable security definer
set search_path = public as $$
  select role from plant_members where user_id = auth.uid() and plant_id = p_plant $$;

alter table maintenance_orders enable row level security;
create policy mo_read  on maintenance_orders for select to authenticated using (my_role(plant_id) is not null);
create policy mo_write on maintenance_orders for insert to authenticated
  with check (my_role(plant_id) = 'maintenance' and created_by = auth.uid());
revoke update (status, approved_by) on setpoint_proposals from authenticated; -- column-level
```

**Implementation Guidance:**
- Produce a role × table × operation matrix in `docs/security/access-matrix.md` and implement it as policies.
- Use column privileges/triggers to stop clients changing protected columns (role, approved_by, actual_state).
- `security definer` helpers must set `search_path`.
- Add pgTAP or SQL tests per role.

**Success Criteria:**
- [ ] Each role's allowed/denied operations match the matrix in automated tests.
- [ ] Clients cannot update `profiles.role` or `setpoint_proposals.status` directly.

**Status:** Applied
