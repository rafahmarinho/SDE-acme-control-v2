---
name: t38-bind-variables-in-sql
description: Use supabase-js/postgrest builders, parameterised RPC functions and bound parameters for all PostgreSQL access; never concatenate search/filter input into SQL or filter strings.
---

# T38: Bind variables in SQL statements

**Category:** CODE_FIX
**SD Elements:** [T38](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T38/)
**Priority:** 10

**Spec Context:**
> "Supabase para PostgreSQL" / "Inclua login, recuperação de senha, perfil, configurações, busca, filtros"
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
Search and filters implemented by interpolating text into SQL (`execute 'select ... where name ilike ''%' || q || '%'''`) or into PostgREST `.or()` filter strings.

**Secure Implementation Pattern:**
```sql
-- supabase/migrations: parameterised search function
create function public.search_equipment(p_plant uuid, p_q text)
returns setof equipment language sql stable security invoker as $$
  select * from equipment
  where plant_id = p_plant and name ilike '%' || p_q || '%'   -- p_q is a bound parameter
  limit 50;
$$;
```
```dart
await supabase.rpc('search_equipment', params: {'p_plant': plantId, 'p_q': query});
```

**Implementation Guidance:**
- Use builder methods (`.eq`, `.ilike`) with values, or RPC with typed parameters.
- Never build `.or('name.ilike.%$q%')` strings from user input; never use `EXECUTE` with concatenated input in PL/pgSQL (use `format('%L')` / `USING`).
- Escape `%`/`_` in LIKE input if literal matching is required.

**Success Criteria:**
- [ ] No string concatenation of user input into SQL or PostgREST filter strings (code review grep).
- [ ] Search with `' or 1=1 --` returns no extra rows (test).

**Status:** Applied
