---
name: t70-account-lockout-authentication-throttling
description: Throttle repeated failed logins for the email/password accounts (Supabase Auth and API token checks) to resist brute force without permanently locking out plant operators.
---

# T70: Implement account lockout or authentication throttling for system accounts

**Category:** CODE_FIX
**SD Elements:** [T70](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T70/)
**Priority:** 8

**Spec Context:**
> "Supabase para PostgreSQL, login por e-mail e senha" / "Inclua login, recuperação de senha"
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
A login form that calls `signInWithPassword` with unlimited retries and distinguishes "wrong password" from "unknown email".

**Secure Implementation Pattern:**
```toml
# supabase/config.toml
[auth.rate_limit]
sign_in_sign_ups = 10       # per 5 minutes per IP
token_verifications = 30
email_sent = 4
```
```dart
// app/lib/services/auth_service.dart - client backoff + generic error
if (failures >= 3) {
  await Future.delayed(Duration(seconds: 1 << failures.clamp(0, 6)));
}
throw const AuthFailure('Invalid email or password.');
```

**Implementation Guidance:**
- Configure Supabase Auth rate limits (config.toml / dashboard) and document the chosen values.
- API: per-IP and per-user failed-token counters in a `rate_limits` table; respond 429 with `Retry-After`.
- Show one generic error for every login failure; record failures in `events` (see T2602).
- Prefer throttling over hard lockout so an attacker cannot lock operators out during a shift.

**Success Criteria:**
- [ ] The 11th sign-in attempt from one IP within 5 minutes is rejected.
- [ ] Login error text is identical for unknown email and wrong password.
- [ ] Failed attempts are written to the audit log.

**Status:** Applied
