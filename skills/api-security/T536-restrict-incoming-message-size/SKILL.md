---
name: t536-restrict-incoming-message-size
description: Cap request body sizes and field lengths on all Vercel API routes (commands, setpoints, simulation, notes) to resist resource-exhaustion attacks.
---

# T536: Restrict the size of incoming messages in services

**Category:** CODE_FIX
**SD Elements:** [T536](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T536/)
**Priority:** 8

**Spec Context:**
> "Use uma API TypeScript na Vercel para os comandos e a simulação."
> Source: docs/specs/PRD.md, paragraph 3

**What the spec implies (naive approach):**
`await req.json()` on any body size, with unbounded strings for comments and arrays of commands.

**Secure Implementation Pattern:**
```ts
const MAX_BODY = 16 * 1024; // 16 KiB is plenty for commands/setpoints
export async function readJson(req: Request) {
  const len = Number(req.headers.get('content-length') ?? '0');
  if (len > MAX_BODY) throw new HttpError(413, 'payload_too_large');
  const text = await req.text();
  if (text.length > MAX_BODY) throw new HttpError(413, 'payload_too_large');
  return JSON.parse(text);
}
// schemas: z.string().max(2000) for notes, z.array(...).max(20) for batches
```

**Implementation Guidance:**
- One shared `readJson` helper used by every route; uploads go directly to Supabase Storage with size limits (bucket `file_size_limit`).
- Every zod string/array has a `max`.
- Keep `maxDuration` low in `vercel.json` (T35).

**Success Criteria:**
- [ ] A 1 MB body to any route returns 413.
- [ ] All schema strings/arrays are bounded.

**Status:** Pending
