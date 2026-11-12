---
name: t20-unique-session-ids-reset-after-auth
description: Rely on Supabase-issued random sessions, rotate refresh tokens, and re-issue the session after login and after any role change, preventing session fixation.
---

# T20: Generate unique session IDs and reset old IDs after authentication

**Category:** CODE_FIX
**SD Elements:** [T20](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T20/)
**Priority:** 9

**Spec Context:**
> "login por e-mail e senha" / "Tenha perfis de operador, engenheiro, supervisor e manutenção"
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
Create a custom "session id" in the API (e.g. user id + timestamp) or keep the same token after a supervisor changes a user's role.

**Secure Implementation Pattern:**
```toml
# supabase/config.toml
[auth]
jwt_expiry = 900                         # 15 min access tokens
enable_refresh_token_rotation = true
refresh_token_reuse_interval = 10
```
```ts
// After a role change, revoke the user's sessions so a new token with the new role is issued
await admin.auth.admin.signOut(userId, 'global');
```

**Implementation Guidance:**
- Never build session identifiers yourself; accept only Supabase-issued JWTs verified server-side (T558).
- Short access-token lifetime + refresh-token rotation; configure inactivity/absolute session timeouts.
- On role change (profile `role` update) force global sign-out of that user.
- The API reads the role from the database per request, not from stale JWT claims.

**Success Criteria:**
- [ ] Refresh-token reuse after rotation is rejected.
- [ ] Changing a user's role invalidates that user's existing sessions.
- [ ] No custom session-id generation code exists.

**Status:** Pending
