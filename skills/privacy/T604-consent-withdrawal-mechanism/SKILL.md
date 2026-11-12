---
name: t604-consent-withdrawal-mechanism
description: Provide a consent page under Profile/Settings listing granted consents, allowing withdrawal that immediately stops the related processing and records the change.
---

# T604: Implement a consent withdrawal mechanism

**Category:** CODE_FIX
**SD Elements:** [T604](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T604/)
**Priority:** 10

**Spec Context:**
> "Inclua login, recuperação de senha, perfil, configurações"
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
Consent can be granted once but there is no UI to withdraw it; notification jobs ignore later changes.

**Secure Implementation Pattern:**
```dart
// settings_screen.dart
for (final c in consents) SwitchListTile(
  title: Text(c.label), value: c.granted,
  onChanged: (v) => consentService.set(c.purpose, granted: v),   // inserts a new consent row
);
```
```sql
-- processing checks the latest decision
create view public.current_consents as
select distinct on (user_id, purpose) user_id, purpose, granted from consents order by user_id, purpose, at desc;
```

**Implementation Guidance:**
- Withdrawal is as easy as granting (same screen, one tap).
- Simulated notification integrations check `current_consents` before sending.
- On withdrawal of optional profile fields, delete those fields.

**Success Criteria:**
- [ ] Withdrawing SMS-notification consent stops simulated SMS for that user.
- [ ] Withdrawal events are stored with timestamp.

**Status:** Applied
