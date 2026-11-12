---
name: t558-authenticate-components-before-network-communication
description: Ensure the Flutter clients, the Vercel TypeScript API and Supabase authenticate each other before exchanging any data, so no component implicitly trusts another.
---

# T558: Authenticate all other components before any network communication with them

**Category:** CODE_FIX
**SD Elements:** [T558](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T558/)
**Priority:** 9

**Spec Context:**
> "Use uma API TypeScript na Vercel para os comandos e a simulação." / "As versões web e mobile devem compartilhar o mesmo projeto Supabase."
> Source: docs/specs/PRD.md, paragraphs 3 and 6

**What the spec implies (naive approach):**
The Flutter app calls the Vercel API with a user id in the body and the API trusts it; the API talks to whatever Supabase URL is configured, over any scheme.

**Secure Implementation Pattern:**
```ts
// api/src/auth/verify.ts
import { createClient } from '@supabase/supabase-js';
const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
  auth: { persistSession: false },
});
export async function requireUser(req: Request) {
  const token = req.headers.get('authorization')?.replace(/^Bearer /, '');
  if (!token) throw new HttpError(401, 'unauthenticated');
  const { data, error } = await admin.auth.getUser(token); // verified server-side
  if (error || !data.user) throw new HttpError(401, 'unauthenticated');
  return data.user; // identity comes from the token, never from the body
}
```

**Implementation Guidance:**
- Every API route calls `requireUser()` before parsing the body; respond with a generic 401.
- The API reaches Supabase only through an `https://` `SUPABASE_URL` from env; fail at boot otherwise.
- The Flutter client uses only `https://` values for `API_BASE_URL` / `SUPABASE_URL` from `--dart-define`; refuse to start otherwise.
- Never add trust-all HTTP clients or custom `badCertificateCallback` (see T156).

**Success Criteria:**
- [ ] Unauthenticated requests to every `/api/*` route return 401 (automated test).
- [ ] No route derives user identity or role from request body/query.
- [ ] Boot-time check rejects non-HTTPS backend URLs in both API and app.

**Status:** Pending
