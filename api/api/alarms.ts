/**
 * POST /api/alarms - acknowledge an alarm.
 * Flow: authenticate -> validate (strict schema) -> authorize (role + plant) -> rate limit ->
 * load the alarm scoped to the plant -> conditional update (only once) -> audit + event.
 */
import { authorize } from '../src/auth/permissions.js';
import { requireUser } from '../src/auth/verify.js';
import { AlarmRequestSchema } from '../src/commands/schemas.js';
import { audit, event, securityEvent } from '../src/lib/audit.js';
import { HttpError, json, readJson, route, type RequestContext } from '../src/lib/http.js';
import { enforce, LIMITS } from '../src/lib/rate-limit.js';
import { adminClient } from '../src/lib/supabase-admin.js';

async function handle(req: Request, ctx: RequestContext): Promise<Response> {
  const user = await requireUser(req, ctx);
  await enforce(`ip:${ctx.ip ?? 'unknown'}`, LIMITS.perIp.limit, LIMITS.perIp.window);
  const body = AlarmRequestSchema.parse(await readJson(req));
  const role = await authorize(user.id, body.plantId, 'alarm.acknowledge');
  await enforce(`alarm:${user.id}`, LIMITS.command.limit, LIMITS.command.window);

  const db = adminClient();
  const { data: alarm, error } = await db
    .from('alarms')
    .select('id, tag, acknowledged_at')
    .eq('id', body.alarmId)
    .eq('plant_id', body.plantId)
    .maybeSingle();
  if (error) throw new Error('alarm_lookup_failed');
  if (!alarm) throw new HttpError(404, 'not_found');
  if (alarm.acknowledged_at) throw new HttpError(409, 'already_acknowledged');

  const at = new Date().toISOString();
  const { data: updated, error: updError } = await db
    .from('alarms')
    .update({ acknowledged_at: at, acknowledged_by: user.id })
    .eq('id', alarm.id)
    .eq('plant_id', body.plantId)
    .is('acknowledged_at', null) // guards against concurrent double acknowledgement
    .select('id')
    .maybeSingle();
  if (updError) throw new Error('alarm_update_failed');
  if (!updated) throw new HttpError(409, 'already_acknowledged');

  await audit({ actor: user.id, plantId: body.plantId, action: 'alarm.acknowledge', target: alarm.tag as string, requested: body, result: { accepted: true, role } }, ctx);
  await event(body.plantId, 'alarm.acknowledged', `Alarm on ${alarm.tag as string} acknowledged.`, user.id);
  return json(200, { alarmId: alarm.id, acknowledgedAt: at });
}

const handler = route({ POST: handle }, securityEvent);
export const POST = handler;
export const GET = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
