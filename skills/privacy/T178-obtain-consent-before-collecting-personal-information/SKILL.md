---
name: t178-obtain-consent-before-collecting-personal-information
description: Show a privacy notice and record consent for optional personal data (profile details, notifications) at first login, separate from terms of use; minimise what is collected.
---

# T178: Obtain consent from users prior to collecting personal information

**Category:** CODE_FIX
**SD Elements:** [T178](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T178/)
**Priority:** 10

**Spec Context:**
> "Inclua login, recuperação de senha, perfil, configurações" / "login por e-mail e senha"
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
The profile page collects phone number, photo and personal details without explanation; event logs keep user identity indefinitely.

**Secure Implementation Pattern:**
```sql
create table public.consents (
  user_id uuid references auth.users not null,
  purpose text check (purpose in ('profile_optional_fields', 'sms_alarm_notifications')),
  granted boolean not null, version text not null, at timestamptz default now(),
  primary key (user_id, purpose, at));
alter table public.consents enable row level security;
create policy own on public.consents for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
```

**Implementation Guidance:**
- First-login screen with a short privacy notice (English) and separate opt-ins for optional purposes.
- Data minimisation: profile = name, email, role; everything else optional and consent-gated.
- Work-required processing (audit logs of control actions) is documented in the notice rather than consent-based - confirm with the privacy officer.

**Success Criteria:**
- [ ] Optional fields/notifications are unavailable until consent is recorded.
- [ ] Consent records include notice version and timestamp.

**Status:** Pending
