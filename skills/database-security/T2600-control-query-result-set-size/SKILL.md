---
name: t2600-control-query-result-set-size
description: Paginate and cap results for search, filters, alarms, trends and events, so neither clients nor the API can request unbounded data sets.
---

# T2600: Control the result set size returned by a query

**Category:** CODE_FIX
**SD Elements:** [T2600](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T2600/)
**Priority:** 7

**Spec Context:**
> "busca, filtros" / "Crie páginas de ... alarmes, tendências" / "consultar eventos"
> Source: docs/specs/PRD.md, paragraphs 2, 4 and 5

**What the spec implies (naive approach):**
Trends and event pages fetch the whole time series (`select('*')`) and filter in the client.

**Secure Implementation Pattern:**
```ts
const Query = z.object({
  from: z.string().datetime(), to: z.string().datetime(),
  limit: z.number().int().min(1).max(500).default(100),
  cursor: z.string().datetime().optional(),
});
const q = Query.parse(params);
const rows = await db.from('events').select('id,ts,type,message')
  .gte('ts', q.from).lte('ts', q.to).lt('ts', q.cursor ?? q.to)
  .order('ts', { ascending: false }).limit(q.limit);
```

**Implementation Guidance:**
- Set PostgREST `max_rows` (e.g. 1000) in Supabase API settings as a global cap.
- Use keyset pagination for events/alarms; downsample trends server-side for long ranges.
- Bound time ranges (e.g. ≤ 31 days per request).

**Success Criteria:**
- [ ] No list endpoint/query returns more than its documented maximum.
- [ ] Requests over the maximum `limit` or time range are rejected with 400.

**Status:** Applied
