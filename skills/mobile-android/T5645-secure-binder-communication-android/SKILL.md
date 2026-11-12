---
name: t5645-secure-binder-communication-android
description: Avoid AIDL/Binder IPC in the Android app; if any bound service is added, keep it private and verify caller identity and permissions.
---

# T5645: Implement secure Binder communication (Android)

**Category:** CODE_FIX
**SD Elements:** [T5645](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5645/)
**Priority:** 10

**Spec Context:**
> "Flutter e Dart para web, Android e iOS"
> Source: docs/specs/PRD.md, paragraph 3 (no cross-app IPC is described)

**What the spec implies (naive approach):**
A plugin or native module exposes a bound service so other apps (or a companion app) can read plant status.

**Secure Implementation Pattern:**
```kotlin
// Only if a bound service is ever needed
override fun onBind(intent: Intent): IBinder? {
    if (checkCallingPermission("com.acme.control.permission.BIND") != PERMISSION_GRANTED) return null
    return binder
}
// Manifest: <permission android:name="com.acme.control.permission.BIND" android:protectionLevel="signature"/>
```

**Implementation Guidance:**
- Default: no AIDL, no bound services; all data flows through the authenticated API/Supabase.
- If added: `exported="false"` unless required; signature-level permission; validate every parcel.
- Include this check in release manifest review (T170).

**Success Criteria:**
- [ ] No exported bound services in the merged manifest.
- [ ] Any Binder entry point checks caller permission.

**Status:** Applied
