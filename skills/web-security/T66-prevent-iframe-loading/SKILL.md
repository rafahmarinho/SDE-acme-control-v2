---
name: t66-prevent-iframe-loading
description: Deny framing of the Flutter web control UI and the API with X-Frame-Options DENY and CSP frame-ancestors 'none' in vercel.json, preventing clickjacking of pump/valve controls.
---

# T66: Prevent web pages from being loaded inside iFrame

**Category:** CODE_FIX
**SD Elements:** [T66](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T66/)
**Priority:** 7

**Spec Context:**
> "Permita ligar e desligar bombas, abrir e fechar válvulas" / "publicar a versão web ... na Vercel"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
Default Vercel static hosting with no security headers; a malicious page can frame the control screen and trick an operator into clicking "Start pump".

**Secure Implementation Pattern:**
```json
{
  "headers": [{
    "source": "/(.*)",
    "headers": [
      { "key": "X-Frame-Options", "value": "DENY" },
      { "key": "Content-Security-Policy", "value": "frame-ancestors 'none'; default-src 'self'; connect-src 'self' https://*.supabase.co wss://*.supabase.co https://<api>.vercel.app; img-src 'self' data: blob:; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'" },
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "Referrer-Policy", "value": "no-referrer" },
      { "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains" }
    ]
  }]
}
```

**Implementation Guidance:**
- Apply in the web app's `vercel.json` and the API's `vercel.json`.
- Tune CSP to the Flutter renderer in use (CanvasKit/WASM needs `wasm-unsafe-eval`); replace `*.supabase.co` with your exact project host.
- Add a confirmation step for critical commands as defense in depth.

**Success Criteria:**
- [ ] Production responses carry `X-Frame-Options: DENY` and `frame-ancestors 'none'`.
- [ ] Embedding the app in an iframe on another origin fails.

**Status:** Applied
