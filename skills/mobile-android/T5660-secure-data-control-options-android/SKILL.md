---
name: t5660-secure-data-control-options-android
description: Give users in Settings a way to clear the offline cache and sign out of the device, deleting tokens and cached plant data immediately.
---

# T5660: Implement secure data control options for users (Android)

**Category:** CODE_FIX
**SD Elements:** [T5660](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5660/)
**Priority:** 7

**Spec Context:**
> "Inclua login, recuperação de senha, perfil, configurações" / "mostre os últimos dados como leitura offline"
> Source: docs/specs/PRD.md, paragraphs 2 and 6

**What the spec implies (naive approach):**
Settings only contains theme options; cached plant data stays on the device indefinitely.

**Secure Implementation Pattern:**
```dart
ListTile(
  title: const Text('Clear offline data'),
  subtitle: const Text('Removes cached plant data from this device'),
  onTap: () async { await offlineCache.wipe(); showMessage('Offline data cleared.'); },
),
ListTile(title: const Text('Sign out of this device'), onTap: () => logout(ref)), // T164
```

**Implementation Guidance:**
- Settings provides "Clear offline data" and "Sign out"; both delete files and keys immediately.
- Cached data has an expiry (e.g. 24 h) after which it is wiped automatically (T148).
- Show the timestamp of cached data in offline mode.

**Success Criteria:**
- [ ] "Clear offline data" removes the cache file and its key.
- [ ] Cache older than the configured TTL is not displayed and is deleted.

**Status:** Pending
