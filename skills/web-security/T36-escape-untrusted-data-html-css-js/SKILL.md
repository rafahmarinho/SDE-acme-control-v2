---
name: t36-escape-untrusted-data-html-css-js
description: Render user-entered text (shift handover notes, maintenance descriptions, alarm comments) only through Flutter text widgets or context-escaped templates, never as raw HTML.
---

# T36: Escape untrusted data in HTML, HTML attributes, CSS, and JavaScript

**Category:** CODE_FIX
**SD Elements:** [T36](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T36/)
**Priority:** 8

**Spec Context:**
> "Crie páginas de ... manutenção e passagem de turno" / "relatórios"
> Source: docs/specs/PRD.md, paragraphs 1 and 4

**What the spec implies (naive approach):**
Shift-handover notes rendered as rich HTML (`flutter_html`/`HtmlElementView`) or reports/emails built by concatenating notes into HTML strings in the API.

**Secure Implementation Pattern:**
```dart
Text(handover.notes);                // Flutter Text never interprets HTML
SelectableText(order.description);
```
```ts
// API-generated HTML (reports/emails): escape by context
const esc = (s: string) => s.replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]!));
html += `<td>${esc(note)}</td>`;
```

**Implementation Guidance:**
- Do not add HTML/Markdown renderers for user content; if Markdown is ever needed, sanitize with an allow-list.
- API JSON responses use `Content-Type: application/json` and `X-Content-Type-Options: nosniff`.
- Any server-built HTML uses an auto-escaping template engine (see T1144).

**Success Criteria:**
- [ ] A note containing `<img src=x onerror=alert(1)>` displays as literal text on web.
- [ ] No `HtmlElementView`/`innerHTML` usage with user data.

**Status:** Pending
