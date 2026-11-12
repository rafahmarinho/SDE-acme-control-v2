---
name: t186-third-party-library-patches-and-secure-settings
description: Pin current stable versions of Flutter, Riverpod, go_router, supabase_flutter and pnpm packages, commit lockfiles, audit dependencies and apply secure configuration defaults.
---

# T186: Use recommended settings and the latest patches for third party libraries and software

**Category:** CODE_FIX
**SD Elements:** [T186](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T186/)
**Priority:** 10

**Spec Context:**
> "Use versões atuais e estáveis das tecnologias" / "Material 3, Riverpod e go_router" / "Use pnpm na API TypeScript."
> Source: docs/specs/PRD.md, paragraphs 2 and 3

**What the spec implies (naive approach):**
Copy version numbers from old tutorials, no lockfiles, never re-check for advisories.

**Secure Implementation Pattern:**
```bash
# app/
flutter upgrade && flutter pub upgrade --major-versions && flutter pub outdated
# api/
pnpm up --latest && pnpm audit --prod
git add app/pubspec.lock api/pnpm-lock.yaml
```

**Implementation Guidance:**
- Commit `pubspec.lock` and `pnpm-lock.yaml`; use `pnpm install --frozen-lockfile` in CI.
- Enable Dependabot/Renovate for pub and npm; fail CI on high/critical advisories.
- Review each library's security settings (e.g. supabase_flutter auth flow = PKCE, session storage = secure).

**Success Criteria:**
- [ ] Lockfiles committed; `pnpm audit --prod` has no high/critical findings.
- [ ] `flutter pub outdated` shows no packages behind on security releases.

**Status:** Applied
