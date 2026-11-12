---
name: t273-avoid-permission-re-delegation
description: Request only the Android permissions the PRD needs (network, optionally camera for maintenance photos) and never perform permission-protected actions on behalf of external callers.
---

# T273: Avoid permission re-delegation by considering caller's permissions when handling external requests

**Category:** CODE_FIX
**SD Elements:** [T273](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T273/)
**Priority:** 8

**Spec Context:**
> "Supabase para ... arquivos" / "manutenção" / "No celular, adapte os formulários ao toque"
> Source: docs/specs/PRD.md, paragraphs 2, 4 and 6

**What the spec implies (naive approach):**
Add camera/storage/location permissions "just in case" and an exported share target that uploads any received file to Supabase with the user's session.

**Secure Implementation Pattern:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<!-- Camera only if maintenance photo capture is implemented; requested at point of use -->
<!-- No READ_EXTERNAL_STORAGE: use the system photo picker -->
```
```dart
final file = await ImagePicker().pickImage(source: ImageSource.gallery); // system picker, no broad permission
```

**Implementation Guidance:**
- Minimise permissions; review the merged manifest for plugin-added permissions.
- No exported components that act with the app's permissions or the user's Supabase session for other apps.
- Uploads only from explicit user action inside the app.

**Success Criteria:**
- [ ] Merged manifest lists only justified permissions (documented).
- [ ] No exported share targets / content providers.

**Status:** Pending
