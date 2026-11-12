---
name: t2139-prevent-information-exposure-through-apis
description: Return only explicitly selected fields with schema-validated responses and generic errors from the API and Supabase queries; no stack traces or entire rows.
---

# T2139: Prevent information exposure through APIs

**Category:** CODE_FIX
**SD Elements:** [T2139](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T2139/)
**Priority:** 7

**Spec Context:**
> "Inclua ... estados de carregamento e mensagens de erro." / "Mostre o estado solicitado e o estado real."
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
Error messages show raw Postgres/Supabase errors; endpoints return `select('*')` rows including internal columns (e.g. other users' emails on events).

**Secure Implementation Pattern:**
```ts
const EquipmentState = z.object({ id: z.string().uuid(), requested: z.enum(['on','off','open','closed']),
  actual: z.enum(['on','off','open','closed','fault']), mode: z.enum(['manual','auto']) });
const rows = await db.from('pumps').select('id,requested,actual,mode').eq('plant_id', plantId);
return json(200, z.array(EquipmentState).parse(rows.data));

// error handler
catch (e) { log.error(e); return json(500, { error: 'internal_error', requestId }); }
```

**Implementation Guidance:**
- Explicit column lists everywhere (API and Flutter repository); no `select('*')` in production code.
- Response schemas validated before sending; error bodies are `{ error: code, requestId }`.
- User-facing error messages in English, friendly and generic (PRD), with details only in server logs.

**Success Criteria:**
- [ ] No response contains stack traces or SQL error text.
- [ ] No `select('*')` in app or API code.

**Status:** Pending
