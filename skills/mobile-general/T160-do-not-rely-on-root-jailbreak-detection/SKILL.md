---
name: t160-do-not-rely-on-root-jailbreak-detection
description: Design mobile security assuming rooted/jailbroken devices - all critical control decisions are server-side; root detection, if added, is only an extra signal.
---

# T160: Avoid relying on jailbreak or root detection as a strong security measure

**Category:** CODE_FIX
**SD Elements:** [T160](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T160/)
**Priority:** 7

**Spec Context:**
> "Permita ligar e desligar bombas, abrir e fechar válvulas" / "Inclua as versões Android e iOS"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
Add a root-detection package and assume that, if it passes, the client-side role checks and interlock UI can be trusted.

**Secure Implementation Pattern:**
```text
Trust boundary: Flutter app = untrusted.
Server enforces: authentication (T558), role (T17/T145), interlocks, rate limits (T1362), audit (T2602).
Optional: on rooted devices, warn the user and report a signal to the API (logged), never as the only control.
```

**Implementation Guidance:**
- Do not branch security logic solely on root/jailbreak results.
- If detection is added, treat it as telemetry or a policy block for critical actions in addition to server checks.

**Success Criteria:**
- [ ] Every control action is still rejected server-side when sent from a modified client (test with curl).

**Status:** Applied
