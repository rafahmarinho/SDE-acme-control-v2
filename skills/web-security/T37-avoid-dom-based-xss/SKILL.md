---
name: t37-avoid-dom-based-xss
description: In the Flutter web build, never pass URL fragments, query parameters or deep-link values into DOM sinks or JS interop; validate go_router parameters.
---

# T37: Avoid DOM-based Cross-Site Scripting (XSS)

**Category:** CODE_FIX
**SD Elements:** [T37](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T37/)
**Priority:** 8

**Spec Context:**
> "Flutter e Dart para web ... com Material 3, Riverpod e go_router" / "recuperação de senha"
> Source: docs/specs/PRD.md, paragraphs 2 and 3

**What the spec implies (naive approach):**
Reading `Uri.base` / reset-link fragments or `?next=` parameters and writing them into `document`/`window.location` via `dart:js_interop`, or redirecting to unvalidated `next` URLs after login.

**Secure Implementation Pattern:**
```dart
// go_router: validate path params, allow-list redirects
final id = state.pathParameters['plantId'];
if (id == null || !uuidRegex.hasMatch(id)) return const NotFoundScreen();

String safeNext(String? next) =>
    (next != null && next.startsWith('/') && !next.startsWith('//')) ? next : '/plants';
```

**Implementation Guidance:**
- Avoid `dart:html`/`js_interop` DOM writes; if unavoidable, use `textContent`, never `innerHTML`.
- Only allow relative in-app redirect targets after login/reset.
- Keep `web/index.html` free of inline scripts so a strict CSP can be applied (T66).

**Success Criteria:**
- [ ] `?next=https://evil.example` after login lands on `/plants`.
- [ ] No DOM sink receives URL-derived data (code review).

**Status:** Applied
