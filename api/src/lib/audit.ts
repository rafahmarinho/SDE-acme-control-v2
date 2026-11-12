import type { RequestContext } from './http.js';
import { adminClient } from './supabase-admin.js';

export interface AuditEntry {
  actor: string | null;
  plantId: string | null;
  action: string;
  target?: string | null;
  requested?: unknown;
  result?: unknown;
}

const SENSITIVE_KEY = /pass|token|secret|authorization|cookie|key/i;

/** Removes secret-looking fields so tokens and passwords never reach the audit log. */
export function redact(value: unknown, depth = 0): unknown {
  if (depth > 4 || value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.slice(0, 20).map((v) => redact(v, depth + 1));
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    out[k] = SENSITIVE_KEY.test(k) ? '[redacted]' : redact(v, depth + 1);
  }
  return out;
}

/** Writes one entry to the append-only internal.audit_log (who / what / when / where / result). */
export async function audit(entry: AuditEntry, ctx: RequestContext): Promise<void> {
  const { error } = await adminClient().rpc('audit_write', {
    p_actor: entry.actor,
    p_plant: entry.plantId,
    p_action: entry.action,
    p_target: entry.target ?? null,
    p_requested: redact(entry.requested ?? null),
    p_result: redact(entry.result ?? null),
    p_request_id: ctx.requestId,
    p_ip: ctx.ip,
    p_user_agent: ctx.userAgent,
  });
  if (error) {
    console.error(JSON.stringify({ level: 'error', requestId: ctx.requestId, message: 'audit_write_failed' }));
  }
}

/** Security-event sink for the route wrapper (401/403/405/413/415/429). */
export async function securityEvent(code: string, status: number, ctx: RequestContext): Promise<void> {
  await audit({ actor: null, plantId: null, action: `security.${code}`, target: ctx.url.pathname, result: { status } }, ctx);
}

/** Operational event shown on the events page. */
export async function event(plantId: string, type: string, message: string, actor: string | null): Promise<void> {
  await adminClient().from('events').insert({ plant_id: plantId, type, message: message.slice(0, 300), actor });
}
