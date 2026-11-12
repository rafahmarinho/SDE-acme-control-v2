---
name: t161-treat-device-ids-as-personal-information
description: Do not collect hardware identifiers (IMEI, serial, ICCID); if installs or devices must be tracked for audit, use an app-generated random UUID handled as personal data.
---

# T161: Treat unique device IDs as personal information

**Category:** CODE_FIX
**SD Elements:** [T161](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T161/)
**Priority:** 8

**Spec Context:**
> "Inclua as versões Android e iOS" / "consultar eventos" / "passagem de turno"
> Source: docs/specs/PRD.md, paragraphs 4, 5 and 6

**What the spec implies (naive approach):**
Record `device_info_plus` serial/Android ID with each command event to know which tablet issued it.

**Secure Implementation Pattern:**
```dart
Future<String> installId() async {
  var id = await secure.read(key: 'install_id');
  if (id == null) { id = const Uuid().v4(); await secure.write(key: 'install_id', value: id); }
  return id;                         // random, resettable, app-scoped
}
```

**Implementation Guidance:**
- Store `install_id` in events only if needed; classify it as personal data (retention, access control T349).
- Never use hardware identifiers in URLs, usernames or keys.

**Success Criteria:**
- [ ] No IMEI/serial/ANDROID_ID collection in the code.
- [ ] Any device identifier is an app-generated UUID.

**Status:** Applied
