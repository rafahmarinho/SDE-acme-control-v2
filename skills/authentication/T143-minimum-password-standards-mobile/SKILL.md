---
name: t143-minimum-password-standards-mobile
description: Enforce a length-first, touch-friendly minimum password policy server-side in Supabase Auth for sign-up, change password and reset.
---

# T143: Apply minimum password standards for mobile environments

**Category:** CODE_FIX
**SD Elements:** [T143](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T143/)
**Priority:** 7

**Spec Context:**
> "login por e-mail e senha" / "No celular, adapte os formulários ao toque"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Keep Supabase's permissive default (6 characters) to keep touch forms simple.

**Secure Implementation Pattern:**
```toml
# supabase/config.toml
[auth]
minimum_password_length = 12
password_requirements = "lower_upper_letters_digits"
```
```dart
// Client mirrors the server policy for UX only; the server is authoritative.
String? validatePassword(String v) =>
    v.length < 12 ? 'Use at least 12 characters.' : null;
```

**Implementation Guidance:**
- Supabase Auth settings are the source of truth; client validation is UX only.
- Prefer length (≥ 12) over symbol rules for touch keyboards; enable leaked-password protection if the plan allows.
- Apply on user creation, change password and password reset (T2).

**Success Criteria:**
- [ ] Server rejects passwords shorter than 12 characters.
- [ ] Every password form shows the policy before submission.

**Status:** Pending
