---
name: t316-prevent-keyboard-cache-leaks
description: Disable autocorrect, suggestions and keyboard learning on password and sensitive fields in the touch-adapted Flutter forms.
---

# T316: Prevent unauthorized access to information through keyboard caches and shared dictionaries

**Category:** CODE_FIX
**SD Elements:** [T316](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T316/)
**Priority:** 7

**Spec Context:**
> "No celular, adapte os formulários ao toque" / "login por e-mail e senha"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Default `TextField`s for password and new-password fields with suggestions and autocorrect enabled.

**Secure Implementation Pattern:**
```dart
TextField(
  obscureText: true,
  autocorrect: false,
  enableSuggestions: false,
  enableIMEPersonalizedLearning: false,
  keyboardType: TextInputType.visiblePassword,
  autofillHints: const [AutofillHints.password],   // password managers OK, keyboard learning off
);
```

**Implementation Guidance:**
- Create a shared `PasswordField` component in `app/lib/components/` and use it everywhere.
- Apply `enableIMEPersonalizedLearning: false` to other sensitive inputs if any are added.

**Success Criteria:**
- [ ] All password fields use the shared component with autocorrect/suggestions/learning disabled.

**Status:** Pending
