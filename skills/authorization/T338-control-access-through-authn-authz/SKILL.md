---
name: t338-control-access-through-authn-authz
description: Put every page, API route, table and storage bucket behind authentication plus role-based authorization, with re-authentication for critical control and approval actions.
---

# T338: Control access to resources through user authentication and authorization

**Category:** CODE_FIX
**SD Elements:** [T338](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T338/)
**Priority:** 7

**Spec Context:**
> "Permita ligar e desligar bombas, abrir e fechar válvulas e alternar modos manual e automático" / "perfis de operador, engenheiro, supervisor e manutenção"
> Source: docs/specs/PRD.md, paragraphs 4 and 4

**What the spec implies (naive approach):**
Login gates the UI, but tables are readable with the anon key and critical commands need nothing beyond an old session.

**Secure Implementation Pattern:**
```sql
-- supabase/migrations: default deny
revoke all on all tables in schema public from anon;
alter table public.pumps enable row level security;
create policy pumps_read on public.pumps for select to authenticated
  using (exists (select 1 from plant_members m where m.plant_id = pumps.plant_id and m.user_id = auth.uid()));
-- no insert/update policy: writes only via the API (service role) after authorization
```

**Implementation Guidance:**
- Default deny: revoke `anon`, enable RLS everywhere, add explicit policies.
- Process-state writes only through the API, which authorizes (T17) and audits (T2602).
- Critical actions (mode switch, setpoint approval, lockout) require a recent authentication (e.g. `reauthenticate` within 15 min) - MFA is a recommended follow-up.

**Success Criteria:**
- [ ] The anon key cannot read any table.
- [ ] Every table has RLS enabled (Supabase security advisor clean).
- [ ] Setpoint approval requires recent re-authentication.

**Status:** Applied
