---
name: t2157-secure-email-and-messaging
description: Configure the SMTP provider and DNS (SPF, DKIM, DMARC, TLS) used by Supabase Auth for password-recovery emails; keep email content free of sensitive data.
---

### Task T2157: Secure email and messaging in web applications (NON-CODE)

**Category:** INFRA
**SD Elements:** [T2157](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T2157/)
**Priority:** 7

**Guidance:** Use TLS for mail transport, authenticate senders with SPF/DKIM, publish DMARC, and avoid sending sensitive data by email.

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md - "login por e-mail e senha", "recuperação de senha", "integrações externas simuladas".
- Found: emails are sent by Supabase Auth (password recovery); other notifications are simulated.
- Missing: SPF/DKIM/DMARC and SMTP TLS are DNS and provider settings, not application code.
- Conclusion: INFRA.

**Recommended Action:** Platform owner configures a custom SMTP provider in Supabase with the sending domain's SPF, DKIM and DMARC (`p=quarantine` or stricter) records, and reviews the Auth email templates so they contain only the reset link and no account details.

**Status:** Documented
