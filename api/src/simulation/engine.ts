import { pumpCanRun } from '../commands/interlocks.js';
import { createSimulationRng } from './prng.js';

/** Allow-listed scenarios; requests select by name, mapped here (never to files). */
export const SCENARIO_NAMES = ['normal', 'tank_low', 'pump_maintenance', 'high_demand'] as const;
export type ScenarioName = (typeof SCENARIO_NAMES)[number];

export interface TankState {
  id: string;
  tag: string;
  capacityM3: number;
  levelPct: number;
  lowLimitPct: number;
  highLimitPct: number;
}
export interface PumpState {
  id: string;
  tag: string;
  sourceTankId: string;
  destTankId: string;
  ratedFlowM3h: number;
  requestedState: 'on' | 'off';
  actualState: 'on' | 'off' | 'fault';
  mode: 'manual' | 'auto';
  inMaintenance: boolean;
  flowM3h: number;
}
export interface ValveState {
  id: string;
  tag: string;
  tankId: string;
  direction: 'inlet' | 'outlet';
  ratedFlowM3h: number;
  requestedState: 'open' | 'closed';
  actualState: 'open' | 'closed' | 'fault';
  mode: 'manual' | 'auto';
  inMaintenance: boolean;
  flowM3h: number;
}
export interface PlantState {
  tanks: TankState[];
  pumps: PumpState[];
  valves: ValveState[];
  /** Auto-mode thresholds for the destination (treated) tank, in %. */
  autoStartPct: number;
  autoStopPct: number;
}

export const STEP_SECONDS = 10;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/** Applies a named scenario's initial conditions (returns a new state). */
export function applyScenario(state: PlantState, scenario: ScenarioName): PlantState {
  const s = structuredClone(state);
  switch (scenario) {
    case 'normal':
      s.tanks.forEach((t, i) => (t.levelPct = i === 0 ? 60 : 40));
      break;
    case 'tank_low':
      if (s.tanks[0]) s.tanks[0].levelPct = s.tanks[0].lowLimitPct + 2;
      break;
    case 'pump_maintenance':
      if (s.pumps[0]) s.pumps[0].inMaintenance = true;
      break;
    case 'high_demand':
      s.valves.filter((v) => v.direction === 'outlet').forEach((v) => (v.ratedFlowM3h *= 1.8));
      break;
  }
  return s;
}

/** Advances the process by `steps` x STEP_SECONDS. Pure function: input state is not mutated. */
export function simulate(state: PlantState, steps: number, seed = 1): PlantState {
  const s = structuredClone(state);
  const rng = createSimulationRng(seed);
  const tankById = new Map(s.tanks.map((t) => [t.id, t]));
  const hours = STEP_SECONDS / 3600;

  for (let i = 0; i < steps; i++) {
    for (const p of s.pumps) {
      const src = tankById.get(p.sourceTankId);
      const dst = tankById.get(p.destTankId);
      if (!src || !dst) continue;
      if (p.mode === 'auto') {
        if (dst.levelPct <= s.autoStartPct) p.requestedState = 'on';
        if (dst.levelPct >= s.autoStopPct) p.requestedState = 'off';
      }
      const canRun = pumpCanRun({ inMaintenance: p.inMaintenance, sourceLevelPct: src.levelPct, sourceLowLimitPct: src.lowLimitPct });
      p.actualState = p.requestedState === 'on' && canRun ? 'on' : 'off';
      p.flowM3h = p.actualState === 'on' ? p.ratedFlowM3h * (0.97 + rng() * 0.06) : 0;
      const volume = p.flowM3h * hours;
      src.levelPct = clamp(src.levelPct - (volume / src.capacityM3) * 100, 0, 100);
      dst.levelPct = clamp(dst.levelPct + (volume / dst.capacityM3) * 100, 0, 100);
    }
    for (const v of s.valves) {
      const tank = tankById.get(v.tankId);
      if (!tank) continue;
      v.actualState = v.inMaintenance ? v.actualState : v.requestedState;
      v.flowM3h = v.actualState === 'open' ? v.ratedFlowM3h * (0.95 + rng() * 0.1) : 0;
      const delta = ((v.flowM3h * hours) / tank.capacityM3) * 100;
      tank.levelPct = clamp(tank.levelPct + (v.direction === 'inlet' ? delta : -delta), 0, 100);
    }
  }
  return s;
}

/** Pressure approximation from level (bar), for display and trends. */
export function pressureBar(t: TankState): number {
  return Math.round((1 + t.levelPct * 0.012) * 100) / 100;
}
