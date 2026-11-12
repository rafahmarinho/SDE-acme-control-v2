---
name: t742-ensure-accuracy-of-personal-information
description: Let users view and correct their own profile data with validation, keeping a single source of truth in Supabase shared by web and mobile.
---

# T742: Implement technical measures to ensure the accuracy of personal information

**Category:** CODE_FIX
**SD Elements:** [T742](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T742/)
**Priority:** 7

**Spec Context:**
> "Inclua login ... perfil" / "As versões web e mobile devem compartilhar o mesmo projeto Supabase."
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Profile data duplicated in the offline cache and in event records; edits on mobile don't propagate and no validation is done.

**Secure Implementation Pattern:**
```sql
alter table public.profiles add constraint name_len check (char_length(display_name) between 1 and 80);
create policy profile_self_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update (role, email) on public.profiles from authenticated;   -- role changes via supervisor flow
```

**Implementation Guidance:**
- Self-service edit of name/optional fields in the Profile screen; email change via Supabase Auth flow.
- Events reference `user_id` (join for display) instead of copying names.
- Validate inputs client- and server-side.

**Success Criteria:**
- [ ] A user can correct their display name and the change appears on web and mobile.
- [ ] Users cannot change their own role.

**Status:** Applied
