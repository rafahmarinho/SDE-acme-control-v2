---
name: t151-cryptographically-secure-random-numbers
description: Use CSPRNGs (Random.secure, crypto.randomUUID/randomBytes) for ids, keys, nonces and demo passwords; Math.random only for non-security simulation noise.
---

# T151: Use cryptographically secure random numbers

**Category:** CODE_FIX
**SD Elements:** [T151](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T151/)
**Priority:** 7

**Spec Context:**
> "O processo deve responder aos comandos: os tanques enchem ou esvaziam conforme o fluxo" / "arquivos"
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
The simulation already uses `Math.random()`; the same helper ends up generating attachment ids, request ids and demo passwords.

**Secure Implementation Pattern:**
```ts
import { randomUUID, randomBytes } from 'node:crypto';
const attachmentId = randomUUID();                  // security-relevant identifiers
const demoPassword = randomBytes(18).toString('base64url');
// simulation noise: seeded PRNG kept in src/simulation only
```
```dart
final rng = Random.secure();
final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
```

**Implementation Guidance:**
- Separate modules: `src/simulation/prng.ts` (deterministic, non-security) vs `node:crypto` for everything else.
- Lint rule banning `Math.random` outside `src/simulation/`.
- Never derive security tokens from time or user ids.

**Success Criteria:**
- [ ] `Math.random` appears only under `api/src/simulation/`.
- [ ] Dart code uses `Random.secure()` for any key/nonce/token.

**Status:** Applied
