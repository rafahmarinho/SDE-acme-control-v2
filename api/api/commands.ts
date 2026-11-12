/**
 * POST /api/commands - pump on/off, valve open/close, manual/auto mode and maintenance lockout.
 * Flow: authenticate -> validate (strict schema) -> authorize (role + plant) -> rate limit ->
 * load equipment state from the DB -> interlocks -> write requested state -> audit + event.
 * The actual state is resolved by the process simulation, so the UI shows requested vs. actual.
 */
import { authorize, type Action } from '../src/auth/permissions.js';
import { requireRecentAuth, requireUser } from '../src/auth/verify.js';
import { checkPumpCommand, checkValveCommand } from '../src/commands/interlocks.js';
import { CommandSchema, type Command } from '../src/commands/schemas.js';
import { audit, event, securityEvent } from '../src/lib/audit.js';
import { HttpError, json, readJson, route, type RequestContext } from '../src/lib/http.js';
import { enforce, LIMITS } from '../src/lib/rate-limit.js';
import { adminClient } from '../src/lib/supabase-admin.js';
import { renderText } from '../src/lib/templates.js';

function actionFor(cmd: Command): Action {
  switch (cmd.type) {
    case 'pump':
      return 'pump.toggle';
    case 'valve':
      return 'valve.toggle';
    case 'mode':
      return 'mode.set';
    case 'lockout':
      return 'equipment.lockout';
  }
}

async function handle(req: Request, ctx: RequestContext): Promise<Response> {
  const user = await requireUser(req, ctx);
  await enforce(`ip:${ctx.ip ?? 'unknown'}`, LIMITS.perIp.limit, LIMITS.perIp.window);
  const cmd = CommandSchema.parse(await readJson(req));
  const action = actionFor(cmd);
  const role = await authorize(user.id, cmd.plantId, action);
  if (cmd.type === 'mode' || cmd.type === 'lockout') requireRecentAuth(user);
  await enforce(`cmd:${user.id}`, LIMITS.command.limit, LIMITS.command.window);

  const db = adminClient();
  const table = cmd.type === 'pump' ? 'pumps' : cmd.type === 'valve' ? 'valves' : cmd.equipmentKind === 'pump' ? 'pumps' : 'valves';
  const { data: eq, error } = await db
    .from(table)
    .select('id, tag, mode, in_maintenance, requested_state, actual_state, source_tank_id:' + (table === 'pumps' ? 'source_tank_id' : 'tank_id'))
    .eq('id', cmd.equipmentId)
    .eq('plant_id', cmd.plantId)
    .maybeSingle<{ id: string; tag: string; mode: 'manual' | 'auto'; in_maintenance: boolean; requested_state: string; actual_state: string; source_tank_id: string }>();
  if (error) throw new Error('equipment_lookup_failed');
  if (!eq) throw new HttpError(404, 'not_found');

  let blocked: string | null = null;
  let update: Record<string, unknown> = {};
  if (cmd.type === 'pump') {
    const { data: tank } = await db.from('tanks').select('level_pct, low_limit_pct').eq('id', eq.source_tank_id).single();
    blocked = checkPumpCommand(
      { mode: eq.mode, inMaintenance: eq.in_maintenance, sourceLevelPct: Number(tank?.level_pct ?? 0), sourceLowLimitPct: Number(tank?.low_limit_pct ?? 100) },
      cmd.state,
    );
    update = { requested_state: cmd.state };
  } else if (cmd.type === 'valve') {
    blocked = checkValveCommand({ mode: eq.mode, inMaintenance: eq.in_maintenance });
    update = { requested_state: cmd.state };
  } else if (cmd.type === 'mode') {
    blocked = eq.in_maintenance ? 'equipment_in_maintenance' : null;
    update = { mode: cmd.mode };
  } else {
    // Lockout forces the equipment to a safe state.
    update = cmd.inMaintenance
      ? { in_maintenance: true, mode: 'manual', requested_state: table === 'pumps' ? 'off' : 'closed' }
      : { in_maintenance: false };
  }

  const requested = { ...cmd };
  if (blocked) {
    await audit({ actor: user.id, plantId: cmd.plantId, action: `${action}.blocked`, target: eq.tag, requested, result: { accepted: false, reason: blocked, role } }, ctx);
    await event(cmd.plantId, 'command.blocked', renderText('interlockBlocked', { tag: eq.tag, reason: blocked.replace(/_/g, ' ') }), user.id);
    return json(409, { error: blocked, requestId: ctx.requestId });
  }

  const { data: updated, error: updError } = await db
    .from(table)
    .update({ ...update, updated_at: new Date().toISOString() })
    .eq('id', eq.id)
    .eq('plant_id', cmd.plantId)
    .select('id, tag, requested_state, actual_state, mode, in_maintenance')
    .single();
  if (updError || !updated) throw new Error('equipment_update_failed');

  await audit({ actor: user.id, plantId: cmd.plantId, action, target: eq.tag, requested, result: { accepted: true, role, state: updated } }, ctx);
  await event(cmd.plantId, `command.${cmd.type}`, `${eq.tag}: ${JSON.stringify(update)}`, user.id);

  return json(202, {
    equipmentId: updated.id,
    tag: updated.tag,
    requestedState: updated.requested_state,
    actualState: updated.actual_state,
    mode: updated.mode,
    inMaintenance: updated.in_maintenance,
  });
}

const handler = route({ POST: handle }, securityEvent);
export const POST = handler;
export const GET = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
