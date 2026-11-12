---
name: t2133-protect-data-security-ios
description: On iOS store tokens and cache keys in the Keychain, enable Data Protection (complete until first unlock or stronger) for cached files, and enforce ATS.
---

# T2133: Protect the security of data in iOS

**Category:** CODE_FIX
**SD Elements:** [T2133](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T2133/)
**Priority:** 8

**Spec Context:**
> "Inclua as versões Android e iOS" / "mostre os últimos dados como leitura offline"
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Session stored by `shared_preferences` (NSUserDefaults, plaintext) and cache files with default protection; ATS exceptions added for local testing.

**Secure Implementation Pattern:**
```xml
<!-- Runner.entitlements -->
<key>com.apple.developer.default-data-protection</key>
<string>NSFileProtectionComplete</string>
<!-- Info.plist: no NSAppTransportSecurity / NSAllowsArbitraryLoads -->
```
```dart
const secure = FlutterSecureStorage(iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));
```

**Implementation Guidance:**
- Configure supabase_flutter to persist the session via a secure-storage `LocalStorage` implementation, not shared_preferences.
- Encrypt cache with a Keychain-held key (T59) in addition to file protection.
- No ATS exceptions in release builds.

**Success Criteria:**
- [ ] No tokens in NSUserDefaults.
- [ ] Data Protection entitlement set; no `NSAllowsArbitraryLoads`.

**Status:** Pending
