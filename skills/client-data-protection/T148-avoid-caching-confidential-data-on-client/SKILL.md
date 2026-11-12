---
name: t148-avoid-caching-confidential-data-on-client
description: The offline read-only cache stores only the minimum plant data needed, encrypted, with expiry and wipe on logout; no tokens, personal data or command payloads in it.
---

# T148: Avoid caching confidential data on client

**Category:** CODE_FIX
**SD Elements:** [T148](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T148/)
**Priority:** 7

**Spec Context:**
> "mostre os últimos dados como leitura offline. Retome as atualizações quando a conexão voltar; ações de controle exigem conexão."
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Persist the complete Riverpod state (including user list, shift notes, maintenance photos and pending commands) to disk forever.

**Secure Implementation Pattern:**
```dart
class OfflineSnapshot {               // whitelist of cached fields
  final DateTime takenAt;
  final List<TankLevel> tanks;        // level, pressure, flow, states
  final List<AlarmSummary> activeAlarms;
}
const cacheTtl = Duration(hours: 24);
Future<OfflineSnapshot?> read() async {
  final s = await _decryptAndParse();
  if (s == null || DateTime.now().difference(s.takenAt) > cacheTtl) { await wipe(); return null; }
  return s;
}
```

**Implementation Guidance:**
- Cache an explicit snapshot model; never serialise whole provider state.
- Encrypt (T59) with a key in secure storage; wipe on logout (T164) and via Settings (T5660).
- Never queue control actions offline (PRD); show cached data as read-only with its timestamp.

**Success Criteria:**
- [ ] Cache contains only whitelisted fields (unit test on serializer).
- [ ] Expired cache is deleted and not displayed.

**Status:** Applied
