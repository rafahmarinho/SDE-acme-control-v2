---
name: t146-encrypt-mobile-network-communications
description: Android and iOS builds talk to Supabase and the Vercel API over HTTPS/WSS only, with cleartext traffic disabled by platform configuration.
---

# T146: Use encryption for network communications in mobile environments

**Category:** CODE_FIX
**SD Elements:** [T146](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T146/)
**Priority:** 8

**Spec Context:**
> "atualizações em tempo real" / "Retome as atualizações quando a conexão voltar; ações de controle exigem conexão."
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Operators on plant Wi-Fi/cellular; dev builds use `http://10.0.2.2` and `usesCleartextTraffic="true"` leaks into release.

**Secure Implementation Pattern:**
```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
  <base-config cleartextTrafficPermitted="false" />
</network-security-config>
<!-- AndroidManifest: android:networkSecurityConfig="@xml/network_security_config" android:usesCleartextTraffic="false" -->
```
```dart
assert(Uri.parse(apiBaseUrl).scheme == 'https');   // plus runtime check in release
```

**Implementation Guidance:**
- Debug-only overrides go in `src/debug/` resources, never main.
- iOS: no ATS exceptions (T2133).
- Realtime uses `wss://` via supabase_flutter defaults.

**Success Criteria:**
- [ ] Release APK has cleartext disabled (inspect merged manifest/config).
- [ ] App refuses non-HTTPS endpoints at startup.

**Status:** Pending
