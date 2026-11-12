---
name: t5634-icloud-storage-ios
description: Keep the iOS offline cache and tokens out of iCloud Drive and iCloud backups (Keychain this-device-only, files excluded from backup).
---

# T5634: Securely integrate iCloud storage into iOS applications (iOS)

**Category:** CODE_FIX
**SD Elements:** [T5634](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5634/)
**Priority:** 9

**Spec Context:**
> "No celular ... mostre os últimos dados como leitura offline."
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Cache files written to `Documents/` (backed up to iCloud by default) and tokens in Keychain items that sync via iCloud Keychain.

**Secure Implementation Pattern:**
```dart
final dir = await getApplicationSupportDirectory();   // Library/Application Support
// Mark excluded from backup via a small platform channel calling
// URLResourceValues.isExcludedFromBackup = true on the cache file URL.
const iosOpts = IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device, synchronizable: false);
```

**Implementation Guidance:**
- No iCloud Documents / key-value store entitlements.
- Cache in Application Support, excluded from backup; Keychain items non-synchronizable, this-device-only.

**Success Criteria:**
- [ ] Cache file has `isExcludedFromBackup = true`.
- [ ] Keychain items use `*_this_device` accessibility and are not synchronizable.

**Status:** Pending
