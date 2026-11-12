---
name: t248-protect-secret-keys-and-passwords
description: Keep the Supabase service-role key, database password and other secrets only in Vercel/Supabase secret stores; the Flutter app holds only public config; ship only .env.example files.
---

# T248: Protect secret keys and passwords in the application

**Category:** CODE_FIX
**SD Elements:** [T248](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T248/)
**Priority:** 8

**Spec Context:**
> "Entregue o código completo, configuração do banco, dados iniciais, exemplos de variáveis de ambiente"
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Commit a working `.env` with the service-role key "as an example", or put it in `--dart-define` so the app can write directly to protected tables.

**Secure Implementation Pattern:**
```text
app/.env.example   SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL         (public only)
api/.env.example   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY=<server-only>  (placeholders)
Vercel project env  real values, "Sensitive" flag, separate per environment
```
```ts
export function requireEnv(name: string) {
  const v = process.env[name];
  if (!v) throw new Error(`missing env ${name}`);   // never log the value
  return v;
}
```

**Implementation Guidance:**
- `.gitignore` excludes `.env*` except `.env.example` (already in scaffold); add a secret scanner (gitleaks) pre-commit/CI.
- Rotate keys if they ever appear in a commit, log or build artifact.
- Demo user passwords in `seed.sql` are generated at seed time or documented as must-change.

**Success Criteria:**
- [ ] Secret scan of repo and Flutter build output finds no service-role key.
- [ ] API boot fails cleanly when a secret is missing, without printing values.

**Status:** Applied
