import { HttpError } from './http.js';
import { adminClient } from './supabase-admin.js';

/**
 * Database-backed fixed-window rate limiter (Vercel functions are stateless).
 * Fails closed: if the limiter cannot be consulted, the request errors instead of passing.
 */
export async function hit(key: string, limit: number, windowSeconds: number): Promise<boolean> {
  const { data, error } = await adminClient().rpc('rl_hit', {
    p_key: key.slice(0, 200),
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw new Error('rate_limiter_unavailable');
  return data === true;
}

export async function enforce(key: string, limit: number, windowSeconds: number): Promise<void> {
  if (!(await hit(key, limit, windowSeconds))) {
    throw new HttpError(429, 'rate_limited', { 'Retry-After': String(windowSeconds) });
  }
}

/** Limits per action class (per user unless noted). */
export const LIMITS = {
  command: { limit: 30, window: 60 },
  proposal: { limit: 10, window: 60 },
  review: { limit: 20, window: 60 },
  simulation: { limit: 5, window: 60 },
  attachment: { limit: 20, window: 60 },
  perIp: { limit: 300, window: 60 },
  authFailurePerIp: { limit: 20, window: 300 },
} as const;
