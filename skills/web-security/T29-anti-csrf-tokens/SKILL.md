---
name: t29-anti-csrf-tokens
description: Prevent CSRF on state-changing API calls (commands, setpoints, reset) by authenticating with Authorization bearer tokens only, never cookies, and requiring JSON content type.
---

# T29: Use anti-Cross-Site Request Forgery (CSRF) tokens

**Category:** CODE_FIX
**SD Elements:** [T29](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T29/)
**Priority:** 7

**Spec Context:**
> "Permita ligar e desligar bombas, abrir e fechar válvulas" / "avançar a simulação ... e reiniciar os dados"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
Session stored in a cookie for convenience; `GET /api/reset` or form POSTs change plant state, so any website can trigger them in a logged-in browser.

**Secure Implementation Pattern:**
```ts
export function guardStateChange(req: Request) {
  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) throw new HttpError(405, 'method');
  if (!req.headers.get('content-type')?.startsWith('application/json')) throw new HttpError(415, 'type');
  if (!req.headers.get('authorization')?.startsWith('Bearer ')) throw new HttpError(401, 'auth');
  // No cookie-based auth is accepted anywhere -> classic CSRF is not possible.
}
```

**Implementation Guidance:**
- Never authenticate API requests from cookies; if cookies are ever introduced, add a synchronizer/double-submit token and `SameSite=Strict`.
- State changes only via POST/PUT/PATCH/DELETE with JSON bodies; GET is side-effect free.
- Combine with strict CORS (T257).

**Success Criteria:**
- [ ] State-changing endpoints reject GET and non-JSON bodies.
- [ ] No API code reads auth from `Cookie`.

**Status:** Pending
