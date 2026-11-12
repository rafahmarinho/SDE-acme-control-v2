---
name: t1144-prevent-server-side-template-injection
description: When the API renders reports or simulated notification messages, use a logic-less auto-escaping template engine with fixed templates; user data is passed only as variables.
---

# T1144: Prevent Server-Side Template Injection (SSTI)

**Category:** CODE_FIX
**SD Elements:** [T1144](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T1144/)
**Priority:** 8

**Spec Context:**
> "Use inglês como idioma padrão em todas as telas, mensagens, relatórios" / "com integrações externas simuladas"
> Source: docs/specs/PRD.md, paragraphs 1 and 2

**What the spec implies (naive approach):**
Reports and simulated SMS/email messages built by compiling templates that include user text (e.g. a shift note becomes part of the template source) or by `eval`/`new Function` string building.

**Secure Implementation Pattern:**
```ts
import Mustache from 'mustache';                     // logic-less, escapes {{var}}
const TEMPLATES = { alarm: 'Alarm {{tag}} at {{plant}}: {{message}}' } as const; // fixed, versioned
export const render = (k: keyof typeof TEMPLATES, vars: Record<string, string>) =>
  Mustache.render(TEMPLATES[k], vars);               // user data only as variables
```

**Implementation Guidance:**
- Templates live in source control; never accept template text from users or the database.
- No `eval`, `new Function`, or dynamic `import()` of user-influenced strings.
- Validate variables with zod before rendering (types, max length).

**Success Criteria:**
- [ ] A note containing `{{` or `${7*7}` is rendered literally.
- [ ] No code compiles templates from request/database content.

**Status:** Applied
