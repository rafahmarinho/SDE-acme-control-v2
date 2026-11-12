---
name: t754-restrict-processing-of-personal-information
description: Support restricting processing of a user's personal data (e.g. a "restricted" flag that excludes them from optional processing such as notifications and analytics) while keeping legally required audit records.
---

# T754: Enable the restriction of processing personal information of an individual for a specific purpose

**Category:** CODE_FIX
**SD Elements:** [T754](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T754/)
**Priority:** 8

**Spec Context:**
> "perfil, configurações" / "consultar eventos" / "passagem de turno"
> Source: docs/specs/PRD.md, paragraphs 2, 4 and 5

**What the spec implies (naive approach):**
All personal data is used for every purpose (notifications, reports, demo resets) with no way to restrict it.

**Secure Implementation Pattern:**
```sql
alter table public.profiles add column processing_restricted boolean not null default false;
-- optional processing paths filter restricted users
select p.id from profiles p join current_consents c on c.user_id = p.id
where c.purpose = 'sms_alarm_notifications' and c.granted and not p.processing_restricted;
```

**Implementation Guidance:**
- List processing purposes (with the privacy officer) and mark which can be restricted.
- Supervisor/admin action to set `processing_restricted` on request, logged in the audit trail.
- Required records (control-action audit) are retained but excluded from secondary use/reports.

**Success Criteria:**
- [ ] Restricted users are excluded from all optional processing paths (tests).
- [ ] Restriction changes are audited.

**Status:** Pending
