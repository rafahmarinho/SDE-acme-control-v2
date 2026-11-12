---
name: t349-protect-audit-information-and-logs
description: Make the events/security audit tables append-only, readable only by supervisors (and scoped per plant), and protected from tampering - including by the demo "reset data" feature.
---

# T349: Protect audit information and logs against unauthorized access

**Category:** CODE_FIX
**SD Elements:** [T349](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T349/)
**Priority:** 7

**Spec Context:**
> "consultar eventos e reiniciar os dados" / "Mostre o estado solicitado e o estado real."
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
"Reset data" truncates every table including events, and any authenticated user can update or delete event rows.

**Secure Implementation Pattern:**
```sql
create table internal.audit_log (id bigserial primary key, at timestamptz default now(),
  actor uuid, plant_id uuid, action text, target text, requested jsonb, result jsonb,
  prev_hash text, hash text);                                   -- optional SHA-256 chain (T60)
revoke update, delete, truncate on internal.audit_log from public, authenticated, service_role;
create function internal.deny_change() returns trigger language plpgsql as $$
begin raise exception 'audit log is append-only'; end $$;
create trigger no_change before update or delete on internal.audit_log for each row execute function internal.deny_change();
```

**Implementation Guidance:**
- Demo "reset" clears process data only and writes a "reset" audit entry; it never touches the audit log.
- Read access via a supervisor-only view/RPC, scoped to their plants.
- Retention policy documented; export/backup handled outside app permissions.

**Success Criteria:**
- [ ] UPDATE/DELETE on the audit log fail for every app role.
- [ ] Demo reset leaves the audit log intact and logs itself.
- [ ] Non-supervisors cannot read audit entries.

**Status:** Pending
