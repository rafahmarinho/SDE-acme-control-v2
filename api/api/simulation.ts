/**
 * POST /api/simulation - demo tooling: choose scenario, step the simulation, reset demo data.
 * Disabled (404) unless ENABLE_DEMO_TOOLS=true; supervisor-only; reset requires a recent login.
 * Results are persisted in Supabase so they survive reloads (PRD).
 */
import { authorize } from '../src/auth/permissions.js';
import { requireRecentAuth, requireUser } from '../src/auth/verify.js';
import { SimulationRequestSchema } from '../src/commands/schemas.js';
import { audit, event, securityEvent } from '../src/lib/audit.js';
import { demoToolsEnabled } from '../src/lib/env.js';
import { HttpError, json, readJson, route, type RequestContext } from '../src/lib/http.js';
import { enforce, LIMITS } from '../src/lib/rate-limit.js';
import { adminClient } from '../src/lib/supabase-admin.js';
import { applyScenario, pressureBar, simulate, type PlantState } from '../src/simulation/engine.js';

async function loadState(plantId: string): Promise<PlantState> {
  const db = adminClient();
  const [tanks, pumps, valves, sps] = await Promise.all([
    db.from('tanks').select('id, tag, capacity_m3, level_pct, low_limit_pct, high_limit_pct').eq('plant_id', plantId).order('tag'),
    db.from('pumps').select('id, tag, source_tank_id, dest_tank_id, rated_flow_m3h, requested_state, actual_state, mode, in_maintenance, flow_m3h').eq('plant_id', plantId).order('tag'),
    db.from('valves').select('id, tag, tank_id, direction, rated_flow_m3h, requested_state, actual_state, mode, in_maintenance, flow_m3h').eq('plant_id', plantId).order('tag'),
    db.from('setpoints').select('tag, value').eq('plant_id', plantId),
  ]);
  if (tanks.error || pumps.error || valves.error || sps.error) throw new Error('state_load_failed');
  const sp = (suffix: string, fallback: number) => Number(sps.data.find((s) => String(s.tag).endsWith(suffix))?.value ?? fallback);
  return {
    tanks: tanks.data.map((t) => ({ id: t.id, tag: t.tag, capacityM3: Number(t.capacity_m3), levelPct: Number(t.level_pct), lowLimitPct: Number(t.low_limit_pct), highLimitPct: Number(t.high_limit_pct) })),
    pumps: pumps.data.map((p) => ({ id: p.id, tag: p.tag, sourceTankId: p.source_tank_id, destTankId: p.dest_tank_id, ratedFlowM3h: Number(p.rated_flow_m3h), requestedState: p.requested_state, actualState: p.actual_state, mode: p.mode, inMaintenance: p.in_maintenance, flowM3h: Number(p.flow_m3h) })),
    valves: valves.data.map((v) => ({ id: v.id, tag: v.tag, tankId: v.tank_id, direction: v.direction, ratedFlowM3h: Number(v.rated_flow_m3h), requestedState: v.requested_state, actualState: v.actual_state, mode: v.mode, inMaintenance: v.in_maintenance, flowM3h: Number(v.flow_m3h) })),
    autoStartPct: sp('-LO', 30),
    autoStopPct: sp('-HI', 90),
  };
}

async function saveState(plantId: string, s: PlantState): Promise<void> {
  const db = adminClient();
  const now = new Date().toISOString();
  for (const t of s.tanks) {
    await db.from('tanks').update({ level_pct: Math.round(t.levelPct * 100) / 100, pressure_bar: pressureBar(t) }).eq('id', t.id).eq('plant_id', plantId);
  }
  for (const p of s.pumps) {
    await db.from('pumps').update({ requested_state: p.requestedState, actual_state: p.actualState, in_maintenance: p.inMaintenance, flow_m3h: Math.round(p.flowM3h * 10) / 10, updated_at: now }).eq('id', p.id).eq('plant_id', plantId);
  }
  for (const v of s.valves) {
    await db.from('valves').update({ actual_state: v.actualState, flow_m3h: Math.round(v.flowM3h * 10) / 10, updated_at: now }).eq('id', v.id).eq('plant_id', plantId);
  }
  await db.from('process_values').insert(
    s.tanks.flatMap((t) => [
      { plant_id: plantId, tag: `${t.tag}.level`, value: Math.round(t.levelPct * 100) / 100, unit: '%' },
      { plant_id: plantId, tag: `${t.tag}.pressure`, value: pressureBar(t), unit: 'bar' },
    ]).concat(s.pumps.map((p) => ({ plant_id: plantId, tag: `${p.tag}.flow`, value: Math.round(p.flowM3h * 10) / 10, unit: 'm3/h' }))),
  );
  await syncAlarms(plantId, s);
}

/**
 * Raises one alarm per abnormal condition (no duplicates while it stays active) and clears it
 * when the condition returns to normal. Conditions: tank level limits, and a pump that was
 * requested ON but is not running (empty source tank or maintenance interlock).
 */
async function syncAlarms(plantId: string, s: PlantState): Promise<void> {
  const db = adminClient();
  const tankById = new Map(s.tanks.map((t) => [t.id, t]));
  const wanted = new Map<string, { severity: 'medium' | 'high' | 'critical'; message: string }>();
  for (const t of s.tanks) {
    if (t.levelPct <= t.lowLimitPct) wanted.set(t.tag, { severity: t.levelPct <= 0.5 ? 'critical' : 'high', message: `${t.tag} level low (${t.levelPct.toFixed(1)}%)` });
    else if (t.levelPct >= t.highLimitPct) wanted.set(t.tag, { severity: 'high', message: `${t.tag} level high (${t.levelPct.toFixed(1)}%)` });
  }
  for (const p of s.pumps) {
    if (p.requestedState === 'on' && p.actualState !== 'on') {
      const reason = p.inMaintenance ? 'equipment in maintenance' : (tankById.get(p.sourceTankId)?.levelPct ?? 0) <= (tankById.get(p.sourceTankId)?.lowLimitPct ?? 0) ? 'source tank empty' : 'interlock';
      wanted.set(p.tag, { severity: 'medium', message: `${p.tag} requested ON but not running (${reason})` });
    }
  }
  const tags = [...s.tanks.map((t) => t.tag), ...s.pumps.map((p) => p.tag)];
  const { data: active } = await db.from('alarms').select('id, tag').eq('plant_id', plantId).eq('active', true).in('tag', tags).limit(200);
  const activeTags = new Set((active ?? []).map((a) => a.tag as string));
  const toClear = (active ?? []).filter((a) => !wanted.has(a.tag as string)).map((a) => a.id as string);
  if (toClear.length) {
    await db.from('alarms').update({ active: false, cleared_at: new Date().toISOString() }).eq('plant_id', plantId).in('id', toClear);
  }
  const toRaise = [...wanted.entries()].filter(([tag]) => !activeTags.has(tag));
  if (toRaise.length) {
    await db.from('alarms').insert(toRaise.map(([tag, a]) => ({ plant_id: plantId, tag, severity: a.severity, message: a.message })));
    for (const [tag, a] of toRaise) await event(plantId, 'alarm.raised', `${tag}: ${a.message}`, null);
  }
}

async function handle(req: Request, ctx: RequestContext): Promise<Response> {
  if (!demoToolsEnabled()) throw new HttpError(404, 'not_found');
  const user = await requireUser(req, ctx);
  const body = SimulationRequestSchema.parse(await readJson(req));
  await authorize(user.id, body.plantId, 'simulation.manage');
  await enforce(`sim:${user.id}`, LIMITS.simulation.limit, LIMITS.simulation.window);

  if (body.action === 'reset') {
    requireRecentAuth(user);
    const { error } = await adminClient().rpc('demo_reset', { p_plant: body.plantId });
    if (error) throw new Error('reset_failed');
    await audit({ actor: user.id, plantId: body.plantId, action: 'simulation.reset', requested: body, result: { ok: true } }, ctx);
    return json(200, { ok: true });
  }

  const state = await loadState(body.plantId);
  const next = body.action === 'scenario' ? applyScenario(state, body.scenario) : simulate(state, body.steps, Date.now() & 0xffff);
  await saveState(body.plantId, next);
  await audit({ actor: user.id, plantId: body.plantId, action: `simulation.${body.action}`, requested: body, result: { ok: true } }, ctx);
  await event(body.plantId, `simulation.${body.action}`, body.action === 'scenario' ? `Scenario ${body.scenario} applied.` : `Simulation advanced ${body.steps} step(s).`, user.id);
  return json(200, {
    tanks: next.tanks.map((t) => ({ id: t.id, tag: t.tag, levelPct: t.levelPct })),
    pumps: next.pumps.map((p) => ({ id: p.id, tag: p.tag, requestedState: p.requestedState, actualState: p.actualState, flowM3h: p.flowM3h })),
  });
}

const handler = route({ POST: handle }, securityEvent);
export const POST = handler;
export const GET = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
