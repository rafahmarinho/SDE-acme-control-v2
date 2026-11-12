/**
 * POST /api/setpoints
 *  - action "propose": engineers propose a change within the tag's engineering range.
 *  - action "review":  supervisors approve/reject; a proposer can never review their own proposal
 *    (separation of duties) and approval requires a recent login.
 */
import { authorize } from '../src/auth/permissions.js';
import { requireRecentAuth, requireUser } from '../src/auth/verify.js';
import { SetpointRequestSchema } from '../src/commands/schemas.js';
import { audit, event, securityEvent } from '../src/lib/audit.js';
import { HttpError, json, readJson, route, type RequestContext } from '../src/lib/http.js';
import { notifySupervisors } from '../src/lib/outbound.js';
import { enforce, LIMITS } from '../src/lib/rate-limit.js';
import { adminClient } from '../src/lib/supabase-admin.js';
import { renderText } from '../src/lib/templates.js';

async function handle(req: Request, ctx: RequestContext): Promise<Response> {
  const user = await requireUser(req, ctx);
  await enforce(`ip:${ctx.ip ?? 'unknown'}`, LIMITS.perIp.limit, LIMITS.perIp.window);
  const body = SetpointRequestSchema.parse(await readJson(req));
  const db = adminClient();

  if (body.action === 'propose') {
    await authorize(user.id, body.plantId, 'setpoint.propose');
    await enforce(`proposal:${user.id}`, LIMITS.proposal.limit, LIMITS.proposal.window);
    const { data: sp } = await db
      .from('setpoints')
      .select('id, tag, min_value, max_value')
      .eq('id', body.setpointId)
      .eq('plant_id', body.plantId)
      .maybeSingle();
    if (!sp) throw new HttpError(404, 'not_found');
    if (body.value < Number(sp.min_value) || body.value > Number(sp.max_value)) {
      throw new HttpError(400, 'out_of_range');
    }
    const { data: proposal, error } = await db
      .from('setpoint_proposals')
      .insert({ plant_id: body.plantId, setpoint_id: sp.id, proposed_value: body.value, reason: body.reason, proposed_by: user.id })
      .select('id, status, proposed_value, created_at')
      .single();
    if (error || !proposal) throw new Error('proposal_insert_failed');
    await audit({ actor: user.id, plantId: body.plantId, action: 'setpoint.propose', target: sp.tag as string, requested: body, result: { proposalId: proposal.id } }, ctx);
    await event(body.plantId, 'setpoint.proposed', `Change proposed for ${sp.tag as string}.`, user.id);
    return json(201, { proposalId: proposal.id, status: proposal.status });
  }

  // review
  await authorize(user.id, body.plantId, 'setpoint.review');
  requireRecentAuth(user);
  await enforce(`review:${user.id}`, LIMITS.review.limit, LIMITS.review.window);
  const { data: proposal } = await db
    .from('setpoint_proposals')
    .select('id, setpoint_id, proposed_value, proposed_by, status')
    .eq('id', body.proposalId)
    .eq('plant_id', body.plantId)
    .maybeSingle();
  if (!proposal) throw new HttpError(404, 'not_found');
  if (proposal.proposed_by === user.id) throw new HttpError(403, 'separation_of_duties');
  if (proposal.status !== 'pending') throw new HttpError(409, 'already_reviewed');

  const status = body.decision === 'approve' ? 'approved' : 'rejected';
  const { data: reviewed, error: reviewError } = await db
    .from('setpoint_proposals')
    .update({ status, reviewed_by: user.id, reviewed_at: new Date().toISOString(), review_comment: body.comment ?? null })
    .eq('id', proposal.id)
    .eq('status', 'pending') // guards against concurrent double review
    .select('id')
    .maybeSingle();
  if (reviewError) throw new Error('review_update_failed');
  if (!reviewed) throw new HttpError(409, 'already_reviewed');

  let tag = '';
  if (status === 'approved') {
    const { data: sp, error: spError } = await db
      .from('setpoints')
      .update({ value: proposal.proposed_value })
      .eq('id', proposal.setpoint_id)
      .eq('plant_id', body.plantId)
      .select('tag, value, unit')
      .single();
    if (spError || !sp) throw new Error('setpoint_update_failed'); // DB check constraint re-validates range
    tag = sp.tag as string;
    const { data: plant } = await db.from('plants').select('name').eq('id', body.plantId).single();
    await notifySupervisors(body.plantId, renderText('setpointApproved', { tag, value: Number(sp.value), unit: sp.unit as string, plant: (plant?.name as string) ?? '' }));
  }
  await audit({ actor: user.id, plantId: body.plantId, action: `setpoint.${status}`, target: tag || proposal.id, requested: body, result: { status } }, ctx);
  await event(body.plantId, `setpoint.${status}`, `Setpoint proposal ${status}.`, user.id);
  return json(200, { proposalId: proposal.id, status });
}

const handler = route({ POST: handle }, securityEvent);
export const POST = handler;
export const GET = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
