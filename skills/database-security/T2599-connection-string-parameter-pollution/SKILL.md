---
name: t2599-connection-string-parameter-pollution
description: Build Supabase/PostgreSQL connections only from fixed server-side environment values; never derive URLs, keys or database parameters from request input (e.g. a chosen plant or scenario).
---

# T2599: Protect against connection string parameter pollution

**Category:** CODE_FIX
**SD Elements:** [T2599](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T2599/)
**Priority:** 9

**Spec Context:**
> "As versões web e mobile devem compartilhar o mesmo projeto Supabase." / "Inclua uma área para escolher cenários"
> Source: docs/specs/PRD.md, paragraphs 5 and 6

**What the spec implies (naive approach):**
Selecting a plant or scenario passes a project/database name that the API appends to the connection URL.

**Secure Implementation Pattern:**
```ts
// api/src/lib/supabase-admin.ts
const url = new URL(requireEnv('SUPABASE_URL'));
if (url.protocol !== 'https:') throw new Error('SUPABASE_URL must be https');
export const admin = createClient(url.toString(), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false },
});
// Plants/scenarios are rows (plant_id, scenario_id), never connection parameters.
```

**Implementation Guidance:**
- One connection configuration per environment, loaded from env at boot.
- Plants and scenarios are data (ids validated with zod `uuid()`), not separate databases.
- If a direct Postgres connection is needed (migrations), keep it in CI secrets with `sslmode=require`.

**Success Criteria:**
- [ ] No code path builds a connection URL or key from request data.
- [ ] API fails to start if `SUPABASE_URL` is missing or not HTTPS.

**Status:** Applied
