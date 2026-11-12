---
name: t270-secure-android-data-storage
description: Store tokens and the offline plant-data cache only in app-private, encrypted storage on Android; no external storage, no world-readable files, backups disabled for sensitive data.
---

# T270: Follow best practices for storing application data on Android devices

**Category:** CODE_FIX
**SD Elements:** [T270](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T270/)
**Priority:** 7

**Spec Context:**
> "No celular ... mostre os últimos dados como leitura offline."
> Source: docs/specs/PRD.md, paragraph 6

**What the spec implies (naive approach):**
Dump the last API responses to a JSON file in external storage or `SharedPreferences`, and leave `allowBackup="true"`.

**Secure Implementation Pattern:**
```dart
const secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
final dir = await getApplicationSupportDirectory();       // app-private
await File('${dir.path}/cache.bin').writeAsBytes(encrypted);  // AES-GCM (T59), key in Keystore
```
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:allowBackup="false" android:fullBackupContent="false"
             android:dataExtractionRules="@xml/data_extraction_rules" ...>
```

**Implementation Guidance:**
- Never use external storage for app data; no `FileProvider` exposing cache paths.
- Tokens: flutter_secure_storage (Keystore-backed). Cache: encrypted file in app-private dir.
- Exclude cache and secure prefs from cloud backup/device transfer.

**Success Criteria:**
- [ ] `allowBackup` is false (or rules exclude sensitive files).
- [ ] No plaintext plant data or tokens under `/data/data/<pkg>` (verified on emulator).

**Status:** Applied
