---
name: t1539-clear-browser-data-on-logout
description: For the Flutter web build, clear browser storage on logout and expose a logout endpoint that returns Clear-Site-Data.
---

# T1539: Clear browser data on user logout

**Category:** CODE_FIX
**SD Elements:** [T1539](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T1539/)
**Priority:** 8

**Spec Context:**
> "Flutter e Dart para web" / "Os resultados devem aparecer nas telas e continuar salvos após recarregar a aplicação"
> Source: docs/specs/PRD.md, paragraphs 3 and 5

**What the spec implies (naive approach):**
supabase_flutter persists the session in `localStorage`; persisting UI data for reload is done with more `localStorage` entries that survive logout.

**Secure Implementation Pattern:**
```ts
// api/api/logout.ts - called by the web client during logout
export default function handler(_req: Request) {
  return new Response(null, {
    status: 204,
    headers: { 'Clear-Site-Data': '"cache", "storage"', 'Cache-Control': 'no-store' },
  });
}
```
```dart
if (kIsWeb) { html.window.localStorage.clear(); html.window.sessionStorage.clear(); }
```

**Implementation Guidance:**
- "Persisted after reload" means persisted in Supabase, not in the browser; keep browser storage minimal.
- On logout call `signOut()`, clear local/session storage, then call the logout endpoint (same site as the web app) for `Clear-Site-Data`.
- Send `Cache-Control: no-store` on authenticated API responses.

**Success Criteria:**
- [ ] After logout on web, DevTools shows empty localStorage/sessionStorage for the origin.
- [ ] Authenticated API responses include `Cache-Control: no-store`.

**Status:** Applied
