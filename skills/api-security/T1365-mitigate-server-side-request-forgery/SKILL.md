---
name: t1365-mitigate-server-side-request-forgery
description: Keep the simulated external integrations (SMS, CMMS, historian, email) on fixed allow-listed HTTPS endpoints; never fetch URLs supplied by users or stored by users.
---

# T1365: Mitigate Server Side Request Forgery

**Category:** CODE_FIX
**SD Elements:** [T1365](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T1365/)
**Priority:** 8

**Spec Context:**
> "Quero as telas funcionando e os dados persistidos, com integrações externas simuladas."
> Source: docs/specs/PRD.md, paragraph 2

**What the spec implies (naive approach):**
A settings field "integration webhook URL" that the API calls with `fetch(userUrl)`, reaching internal metadata endpoints or the Supabase admin API.

**Secure Implementation Pattern:**
```ts
// api/src/lib/outbound.ts
const ALLOWED = new Map([['historian', 'https://historian.example.com/ingest']]); // config, not user data
export async function callIntegration(name: string, body: unknown) {
  const url = ALLOWED.get(name);
  if (!url) throw new Error('unknown integration');
  return fetch(url, { method: 'POST', body: JSON.stringify(body), redirect: 'error',
                      signal: AbortSignal.timeout(3000) });
}
```

**Implementation Guidance:**
- While integrations are simulated, implement them as in-process stubs - no outbound HTTP at all.
- If real endpoints are added: fixed allow-list in env, `https:` only, `redirect: 'error'`, timeouts, response validation.
- Never accept URLs in request bodies or user settings.

**Success Criteria:**
- [ ] No `fetch()` in the API takes a URL derived from request or database user content.
- [ ] Simulated integrations make no network calls.

**Status:** Pending
