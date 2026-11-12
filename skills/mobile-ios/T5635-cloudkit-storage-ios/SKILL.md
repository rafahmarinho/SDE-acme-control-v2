---
name: t5635-cloudkit-storage-ios
description: Do not use CloudKit for ACME Control data - Supabase is the single shared backend; if CloudKit is ever enabled, use the private database with ACLs and no sensitive data.
---

# T5635: Follow best practices for handling CloudKit Storage (iOS)

**Category:** CODE_FIX
**SD Elements:** [T5635](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5635/)
**Priority:** 9

**Spec Context:**
> "As versões web e mobile devem compartilhar o mesmo projeto Supabase."
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Enable the CloudKit capability to sync settings or the offline cache across an operator's devices.

**Secure Implementation Pattern:**
```text
ios/Runner/Runner.entitlements: no com.apple.developer.icloud-services / CloudKit containers
Settings and data sync -> Supabase (authenticated, RLS-protected)
```

**Implementation Guidance:**
- Keep the CloudKit capability disabled in Xcode.
- If ever required: private database only, CKRecord ACLs, encrypt before upload, never store tokens or plant data.

**Success Criteria:**
- [ ] Entitlements contain no CloudKit/iCloud service keys.

**Status:** Applied
