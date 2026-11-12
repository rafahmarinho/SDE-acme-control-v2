---
name: t5657-validate-incoming-messenger-messages-android
description: Any Android Handler/Messenger/Intent or Flutter platform-channel message (including deep links for password reset) must be validated for sender and content before use.
---

# T5657: Validate Incoming Messenger Messages (Android)

**Category:** CODE_FIX
**SD Elements:** [T5657](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5657/)
**Priority:** 8

**Spec Context:**
> "Flutter e Dart para web, Android e iOS" / "recuperação de senha"
> Source: docs/specs/PRD.md, paragraphs 2 and 3

**What the spec implies (naive approach):**
The password-reset deep link Intent is passed straight into the router and any extras (e.g. `next`, `role`) are trusted.

**Secure Implementation Pattern:**
```dart
// Deep link handling (app_links / go_router)
final uri = incomingUri;
if (uri.scheme != 'acmecontrol' || uri.host != 'auth-callback') return;   // allow-listed
final code = uri.queryParameters['code'];
if (code == null || code.length > 512) return;
await supabase.auth.exchangeCodeForSession(code);                        // ignore other params
```

**Implementation Guidance:**
- Prefer verified Android App Links (https + `assetlinks.json`) over custom schemes for auth callbacks.
- No custom `Messenger`/`Handler` services unless needed; if added, check `Binder.getCallingUid()` and validate `Message.what`/data.
- Validate MethodChannel arguments on both sides (types, lengths).

**Success Criteria:**
- [ ] Unknown hosts/paths in deep links are ignored.
- [ ] Only the `code` parameter is consumed from auth callbacks.

**Status:** Pending
