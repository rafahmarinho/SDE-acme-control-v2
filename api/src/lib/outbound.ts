import { event } from './audit.js';
import { adminClient } from './supabase-admin.js';

/**
 * External integrations (SMS, e-mail, CMMS, historian) are SIMULATED per the PRD: they make no
 * network calls. Messages are recorded as events. There is no code path that fetches a URL from
 * request or user-stored data. If a real integration is added, use a fixed https allow-list from
 * env, `redirect: 'error'` and a timeout.
 */
export type Integration = 'sms' | 'email' | 'cmms' | 'historian';

export async function simulateIntegration(plantId: string, integration: Integration, message: string): Promise<void> {
  await event(plantId, `integration.${integration}.simulated`, message, null);
}

/**
 * Notifies supervisors of a plant via (simulated) SMS, honouring consent withdrawal and
 * restriction of processing: only users with a current granted consent and no restriction.
 */
export async function notifySupervisors(plantId: string, message: string): Promise<number> {
  const db = adminClient();
  const { data: members, error } = await db.from('plant_members').select('user_id').eq('plant_id', plantId).eq('role', 'supervisor');
  if (error || !members?.length) return 0;
  const ids = members.map((m) => m.user_id as string);
  const [{ data: consents }, { data: restricted }] = await Promise.all([
    db.from('current_consents').select('user_id').in('user_id', ids).eq('purpose', 'sms_alarm_notifications').eq('granted', true),
    db.from('profiles').select('id').in('id', ids).eq('processing_restricted', true),
  ]);
  const blocked = new Set((restricted ?? []).map((r) => r.id as string));
  const recipients = (consents ?? []).map((c) => c.user_id as string).filter((u) => !blocked.has(u));
  for (const _ of recipients) {
    await simulateIntegration(plantId, 'sms', message);
  }
  return recipients.length;
}
