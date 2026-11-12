---
name: t1362-message-throttling-web-apis
description: Rate-limit the command, setpoint and simulation APIs per user and per IP with a database-backed limiter, returning 429 with Retry-After.
---

# T1362: Perform message throttling in Web APIs

**Category:** CODE_FIX
**SD Elements:** [T1362](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T1362/)
**Priority:** 8

**Spec Context:**
> "Permita ligar e desligar bombas, abrir e fechar válvulas e alternar modos" / "avançar a simulação"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
Unlimited command calls; a script can toggle a pump hundreds of times per second (equipment wear in a real plant) or flood the simulation.

**Secure Implementation Pattern:**
```sql
create table internal.rate_limits (key text, window_start timestamptz, hits int, primary key (key, window_start));
create function internal.hit(p_key text, p_limit int, p_window interval) returns boolean language sql as $$
  insert into internal.rate_limits as r values (p_key, date_bin(p_window, now(), 'epoch'), 1)
  on conflict (key, window_start) do update set hits = r.hits + 1
  returning hits <= p_limit $$;
```
```ts
if (!(await hit(`cmd:${user.id}`, 30, '1 minute'))) return json(429, { error: 'rate_limited' }, { 'Retry-After': '60' });
```

**Implementation Guidance:**
- Limits per action class: commands (30/min/user), setpoint proposals (10/min), simulation step/reset (5/min), plus a per-IP global limit.
- Vercel functions are stateless: use the database (or a managed KV) for counters.
- Per-equipment debounce: reject a new command for the same equipment while the previous one is pending.

**Success Criteria:**
- [ ] 31st command in a minute returns 429 with `Retry-After`.
- [ ] Rate-limit hits are logged.

**Status:** Applied
