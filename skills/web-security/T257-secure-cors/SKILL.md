---
name: t257-secure-cors
description: Configure the Vercel API with an exact-origin CORS allow-list for the Flutter web app, no credentials wildcard, and authentication on every non-OPTIONS request.
---

# T257: Secure cross origin resource sharing (CORS)

**Category:** CODE_FIX
**SD Elements:** [T257](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T257/)
**Priority:** 8

**Spec Context:**
> "Flutter e Dart para web" / "publicar a versão web e a API na Vercel"
> Source: docs/specs/PRD.md, paragraphs 3 and 6

**What the spec implies (naive approach):**
Web app and API are separate Vercel deployments, so the API returns `Access-Control-Allow-Origin: *` (or reflects any Origin) to make it work.

**Secure Implementation Pattern:**
```ts
// api/src/lib/cors.ts
const allowed = new Set(requireEnv('ALLOWED_ORIGINS').split(',').map(s => s.trim()));
export function cors(req: Request, res: Headers) {
  const origin = req.headers.get('origin');
  if (origin && allowed.has(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Vary', 'Origin');
    res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.set('Access-Control-Allow-Headers', 'authorization,content-type');
    res.set('Access-Control-Max-Age', '600');
  }
}
```

**Implementation Guidance:**
- Exact origins from env (production web URL + localhost for dev); no wildcard, no regex on preview domains.
- Do not enable `Allow-Credentials`; the app sends bearer tokens in `Authorization`.
- CORS is not access control: every route still calls `requireUser()` (T558).

**Success Criteria:**
- [ ] Preflight from an unlisted origin receives no `Access-Control-Allow-Origin`.
- [ ] No response contains `Access-Control-Allow-Origin: *`.

**Status:** Applied
