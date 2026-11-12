---
name: t4593-monitor-endpoint-behaviour
description: Behavioural monitoring (baselines, anomaly detection, alerting) is run by an operations/SIEM capability consuming the application's audit log and platform logs.
---

### Task T4593: Monitor the behaviour on endpoint (NON-CODE)

**Category:** INFRA
**SD Elements:** [T4593](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T4593/)
**Priority:** 7

**Guidance:** Establish baselines of normal behaviour (access times, actions, IPs) and analyse activity in real time for anomalies.

**Why Not Code-Fixable:**
- Searched specs: docs/specs/PRD.md - "consultar eventos", operator/supervisor roles; no monitoring/SIEM requirement.
- Found: the app produces audit events (implemented by T2602/T349).
- Missing: a monitoring platform, baselines and alert routing are operational infrastructure, not app code.
- Conclusion: INFRA - the app supplies the data, operations runs the monitoring.

**Recommended Action:** Ops team configures Vercel Log Drains and Supabase log export to a SIEM, defines baselines (e.g. commands per shift, off-hours logins, new IPs) and alerts to the plant supervisor on-call.

**Status:** Documented
