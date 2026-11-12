---
name: t76-do-not-hardcode-passwords
description: No passwords, API keys or tokens in Dart, TypeScript, SQL seed or native config; demo credentials are injected or generated, never committed.
---

# T76: Do not hardcode passwords

**Category:** CODE_FIX
**SD Elements:** [T76](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T76/)
**Priority:** 10

**Spec Context:**
> "Prepare dados de demonstração com duas plantas industriais." / "Tenha perfis de operador, engenheiro, supervisor e manutenção"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
`seed.sql` creates `operator@acme.test / Password123!` for every role and the login screen pre-fills those credentials.

**Secure Implementation Pattern:**
```ts
// supabase/seed-users.ts (run locally/CI with service role, not committed secrets)
for (const role of ['operator', 'engineer', 'supervisor', 'maintenance']) {
  const password = crypto.randomBytes(18).toString('base64url');
  await admin.auth.admin.createUser({ email: `${role}@demo.acme.test`, password, email_confirm: true });
  console.log(`${role}: ${password}`); // printed once to the operator running the seed
}
```

**Implementation Guidance:**
- No credentials in source, seed SQL, README or UI defaults.
- Demo quick-login buttons (if any) only in debug builds behind `ENABLE_DEMO_TOOLS` (T49).
- Add a lint/secret-scan rule failing on literal `password =`/key patterns.

**Success Criteria:**
- [ ] Secret scan passes on the repository.
- [ ] Release builds contain no demo credentials.

**Status:** Applied
