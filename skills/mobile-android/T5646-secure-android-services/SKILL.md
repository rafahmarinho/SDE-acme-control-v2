---
name: t5646-secure-android-services
description: Keep any Android services (e.g. background realtime or notification services) non-exported and permission-protected; the PRD requires pausing updates in background, not long-running services.
---

# T5646: Implement secure services (Android)

**Category:** CODE_FIX
**SD Elements:** [T5646](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5646/)
**Priority:** 10

**Spec Context:**
> "No celular ... pause as atualizações em segundo plano ... Retome as atualizações quando a conexão voltar"
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Add a foreground/background service (or a plugin that declares one) to keep realtime alarms flowing, exported with an intent filter.

**Secure Implementation Pattern:**
```dart
// Pause instead of running a service
class LifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) realtime.pause();
    if (s == AppLifecycleState.resumed) realtime.resume();
  }
}
```
```xml
<!-- If a service is ever required -->
<service android:name=".SyncService" android:exported="false" />
```

**Implementation Guidance:**
- Implement the PRD behaviour with lifecycle pausing, not services.
- Review the merged manifest (`build/.../AndroidManifest.xml`) for plugin-declared services; ensure `exported="false"` or signature permissions.
- No `<intent-filter>` on services.

**Success Criteria:**
- [ ] Merged manifest has no exported services (or each has a signature-level permission).
- [ ] Realtime subscriptions stop when the app is backgrounded.

**Status:** Applied
