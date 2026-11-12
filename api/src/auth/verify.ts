import { HttpError, type RequestContext } from '../lib/http.js';
import { hit, LIMITS } from '../lib/rate-limit.js';
import { adminClient } from '../lib/supabase-admin.js';

export interface AuthUser {
  id: string;
  token: string;
  /** Unix seconds of the most recent interactive authentication (from the JWT "amr" claim). */
  lastAuthAt: number | null;
}

const BEARER = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/;

function lastAuthenticationTime(token: string): number | null {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1] ?? '', 'base64url').toString('utf8')) as {
      amr?: { method?: string; timestamp?: number }[];
    };
    const times = (payload.amr ?? []).map((a) => a.timestamp ?? 0).filter((t) => t > 0);
    return times.length ? Math.max(...times) : null;
  } catch {
    return null;
  }
}

/**
 * Authenticates the caller by verifying the Supabase access token server-side.
 * Identity always comes from the verified token - never from the request body or query.
 * Repeated failures from one IP are throttled.
 */
export async function requireUser(req: Request, ctx: RequestContext): Promise<AuthUser> {
  const match = BEARER.exec(req.headers.get('authorization') ?? '');
  const token = match?.[1];
  if (token && token.length <= 8192) {
    const { data, error } = await adminClient().auth.getUser(token);
    if (!error && data.user) {
      return { id: data.user.id, token, lastAuthAt: lastAuthenticationTime(token) };
    }
  }
  const allowed = await hit(`authfail:${ctx.ip ?? 'unknown'}`, LIMITS.authFailurePerIp.limit, LIMITS.authFailurePerIp.window);
  if (!allowed) {
    throw new HttpError(429, 'rate_limited', { 'Retry-After': String(LIMITS.authFailurePerIp.window) });
  }
  throw new HttpError(401, 'unauthenticated');
}

/** Critical actions (mode change, lockout, setpoint approval, demo reset) need a recent login. */
export const REAUTH_MAX_AGE_SECONDS = 15 * 60;

export function requireRecentAuth(user: AuthUser, nowSeconds = Math.floor(Date.now() / 1000)): void {
  if (user.lastAuthAt === null || nowSeconds - user.lastAuthAt > REAUTH_MAX_AGE_SECONDS) {
    throw new HttpError(401, 'reauthentication_required');
  }
}
