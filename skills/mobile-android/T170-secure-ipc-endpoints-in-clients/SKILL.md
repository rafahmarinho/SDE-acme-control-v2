---
name: t170-secure-ipc-endpoints-in-clients
description: Inventory and minimise the app's IPC endpoints (activities, deep links, URL schemes, platform channels) on Android and iOS, protecting each with validation and least exposure.
---

# T170: Secure IPC endpoints used in clients

**Category:** CODE_FIX
**SD Elements:** [T170](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T170/)
**Priority:** 7

**Spec Context:**
> "Inclua as versões Android e iOS e instruções para gerar os pacotes nativos." / "recuperação de senha"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
`flutter create` defaults plus an extra exported activity/URL scheme for reset links that deep-links straight into control screens like `/commands?pump=1&action=start`.

**Secure Implementation Pattern:**
```text
Allowed IPC endpoints (document in docs/security/ipc.md):
- MainActivity (exported, LAUNCHER)                     -> no data accepted
- App Link https://<web>/auth/callback (verified)       -> only ?code=
- iOS Universal Link same path                          -> only ?code=
Not allowed: deep links that trigger commands, setpoints, resets
```

**Implementation Guidance:**
- Deep links may navigate to read-only screens only; control actions always need explicit in-app confirmation.
- Validate all deep-link parameters (T5657); no custom URL schemes if App Links/Universal Links suffice.
- Re-check the merged Android manifest and iOS `Info.plist`/entitlements in each release.

**Success Criteria:**
- [ ] IPC inventory exists and matches the built manifests.
- [ ] No deep link can execute a control action.

**Status:** Pending
