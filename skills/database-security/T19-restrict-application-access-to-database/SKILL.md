---
name: t19-restrict-application-access-to-database
description: Limit database privileges per component - clients use the anon/authenticated roles under RLS, the API uses the service role only where needed - and remove unneeded functions/grants.
---

# T19: Restrict Application's Access to Database

**Category:** CODE_FIX
**SD Elements:** [T19](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T19/)
**Priority:** 8

**Spec Context:**
> "Use uma API TypeScript na Vercel para os comandos e a simulação" / "Supabase para PostgreSQL"
> Source: docs/specs/PRD.md, paragraphs 2 and 3

**What the spec implies (naive approach):**
Use the service-role key everywhere (including the Flutter app) because it "just works" with RLS bypassed.

**Secure Implementation Pattern:**
```sql
-- Narrow what PostgREST exposes
revoke execute on all functions in schema public from public, anon;
grant execute on function public.search_equipment(uuid, text) to authenticated;
-- Dedicated schema for internal tables the API alone touches
create schema internal; revoke all on schema internal from anon, authenticated;
```
```ts
// API: per-request client with the user's JWT for reads (RLS applies);
// service-role client only for audited writes (commands, simulation step, reset).
const userDb = createClient(URL, ANON_KEY, { global: { headers: { Authorization: `Bearer ${token}` } } });
```

**Implementation Guidance:**
- Service-role key: API runtime only (T248); never shipped in the app.
- Prefer user-scoped clients in the API so RLS also protects server code paths.
- Keep internal tables (rate_limits, simulation state) out of the exposed schema.

**Success Criteria:**
- [ ] The app bundle contains only the anon key (grep of build output).
- [ ] Functions are not executable by `anon` unless explicitly granted.

**Status:** Pending
