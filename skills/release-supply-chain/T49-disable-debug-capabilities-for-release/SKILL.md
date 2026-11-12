---
name: t49-disable-debug-capabilities-for-release
description: Gate the demo/simulation tooling (scenarios, step, reset) and any debug features behind role checks and a build/runtime flag, and remove debug code and data from release builds.
---

# T49: Disable and remove debug capabilities and code/data, and prepare application for release

**Category:** CODE_FIX
**SD Elements:** [T49](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T49/)
**Priority:** 7

**Spec Context:**
> "Inclua uma área para escolher cenários, avançar a simulação, consultar eventos e reiniciar os dados." / "instruções para gerar os pacotes nativos"
> Source: docs/specs/PRD.md, paragraphs 5 and 6

**What the spec implies (naive approach):**
"Reset data" and "advance simulation" available to every user in production, plus debug logging and debug banners in release APK/IPA.

**Secure Implementation Pattern:**
```ts
// api/api/simulation.ts
if (process.env.ENABLE_DEMO_TOOLS !== 'true') return json(404, { error: 'not_found' });
authorize(role, 'simulation.manage');            // supervisor only
```
```dart
const demoTools = bool.fromEnvironment('ENABLE_DEMO_TOOLS');
if (demoTools && role == Role.supervisor) GoRoute(path: '/simulation', ...);
```

**Implementation Guidance:**
- Release builds: `flutter build --release --obfuscate --split-debug-info=...`, `debugShowCheckedModeBanner: false`, no `print` of sensitive data.
- Android `debuggable=false` (release default); remove test accounts and seed shortcuts.
- Document the release checklist in README.

**Success Criteria:**
- [ ] With `ENABLE_DEMO_TOOLS=false`, simulation endpoints return 404 and the screen is absent.
- [ ] Release builds contain no debug-only routes or credentials.

**Status:** Applied
