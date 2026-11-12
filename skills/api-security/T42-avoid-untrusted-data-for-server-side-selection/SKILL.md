---
name: t42-avoid-untrusted-data-for-server-side-selection
description: Map scenario, command type, equipment and report selectors to server-side allow-lists; never use client strings to pick files, modules, handlers or templates, and range-check numeric inputs like simulation steps and setpoints.
---

# T42: Avoid relying on untrusted data for server-side selection

**Category:** CODE_FIX
**SD Elements:** [T42](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T42/)
**Priority:** 10

**Spec Context:**
> "Inclua uma área para escolher cenários, avançar a simulação, consultar eventos e reiniciar os dados." / "setpoints"
> Source: docs/specs/PRD.md, paragraphs 4 and 5

**What the spec implies (naive approach):**
`POST /api/simulation { scenario: "tank-overflow" }` loads `scenarios/${scenario}.json` (path traversal), and `{ steps: 1e9 }` runs the engine a billion times.

**Secure Implementation Pattern:**
```ts
const SCENARIOS = { normal: normalScenario, tank_low: tankLowScenario, pump_trip: pumpTripScenario } as const;
const Body = z.object({
  scenario: z.enum(Object.keys(SCENARIOS) as [keyof typeof SCENARIOS, ...[]]).optional(),
  steps: z.number().int().min(1).max(600),
});
const b = Body.parse(await req.json());
const scenario = b.scenario ? SCENARIOS[b.scenario] : undefined;   // lookup, not path
```

**Implementation Guidance:**
- Commands use `z.discriminatedUnion('type', [...])` with fixed action names.
- Setpoint values validated against engineering limits stored server-side per tag (min/max/unit).
- Never `import()`/`readFile` paths built from input.

**Success Criteria:**
- [ ] Unknown scenario names and `steps` > 600 return 400.
- [ ] Setpoints outside the tag's engineering range are rejected server-side.

**Status:** Applied
