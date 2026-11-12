/**
 * Process interlocks, evaluated on server-loaded state (never on client-supplied state).
 * PRD: a pump does not run if its tank is empty or the equipment is in maintenance.
 */

export interface PumpSnapshot {
  mode: 'manual' | 'auto';
  inMaintenance: boolean;
  sourceLevelPct: number;
  sourceLowLimitPct: number;
}

export interface ValveSnapshot {
  mode: 'manual' | 'auto';
  inMaintenance: boolean;
}

export type BlockReason = 'equipment_in_maintenance' | 'source_tank_empty' | 'equipment_in_auto_mode';

export function checkPumpCommand(p: PumpSnapshot, requested: 'on' | 'off'): BlockReason | null {
  if (p.mode === 'auto') return 'equipment_in_auto_mode';
  if (requested === 'off') return null; // stopping is always allowed
  if (p.inMaintenance) return 'equipment_in_maintenance';
  if (p.sourceLevelPct <= p.sourceLowLimitPct) return 'source_tank_empty';
  return null;
}

export function checkValveCommand(v: ValveSnapshot): BlockReason | null {
  if (v.mode === 'auto') return 'equipment_in_auto_mode';
  if (v.inMaintenance) return 'equipment_in_maintenance';
  return null;
}

/** Whether a pump may physically run right now (used by the simulation every step). */
export function pumpCanRun(p: Omit<PumpSnapshot, 'mode'>): boolean {
  return !p.inMaintenance && p.sourceLevelPct > p.sourceLowLimitPct;
}
