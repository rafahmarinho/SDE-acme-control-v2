---
name: t2-secure-password-reset
description: Implement the PRD password-recovery flow with anti-enumeration, allow-listed redirect URLs, short-lived single-use links, rate limiting and session revocation.
---

# T2: Secure the password reset mechanism

**Category:** CODE_FIX
**SD Elements:** [T2](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T2/)
**Priority:** 9

**Spec Context:**
> "Inclua login, recuperação de senha, perfil, configurações"
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
A "forgot password" screen that answers "email not found" for unknown addresses and builds the redirect URL from the current page, enabling user enumeration and reset-link hijacking.

**Secure Implementation Pattern:**
```dart
// app/lib/screens/password_recovery_screen.dart
await supabase.auth.resetPasswordForEmail(
  email,
  redirectTo: const String.fromEnvironment('RESET_REDIRECT_URL'), // allow-listed in Supabase
);
// Always show the same message, whatever happened:
showMessage('If an account exists for this email, a reset link has been sent.');
```

**Implementation Guidance:**
- Register the exact reset redirect URLs (web URL + mobile deep link) in Supabase "Redirect URLs"; no wildcards.
- Keep link/OTP expiry short (≤ 1 h) and single-use; rate-limit `email_sent` (T70).
- On the new-password screen enforce the T143 policy, then `signOut(scope: SignOutScope.global)` to revoke other sessions.
- Notify the user by email after a password change and log the event (T2602).

**Success Criteria:**
- [ ] Identical UI response for existing and non-existing emails.
- [ ] Reset link cannot be reused and expires.
- [ ] All other sessions are revoked after a successful reset.

**Status:** Applied
