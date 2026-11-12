/**
 * CORS with an exact-origin allow-list from ALLOWED_ORIGINS. No wildcard, no reflection of
 * arbitrary origins, no credentials (the app authenticates with Authorization: Bearer).
 * CORS is not access control: every route still authenticates the caller.
 */

function allowedOrigins(): Set<string> {
  const raw = process.env.ALLOWED_ORIGINS ?? '';
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && s !== '*'),
  );
}

export function isAllowedOrigin(origin: string | null): boolean {
  return origin !== null && allowedOrigins().has(origin);
}

export function corsHeaders(origin: string | null, methods: string[]): Record<string, string> {
  if (!isAllowedOrigin(origin)) return { Vary: 'Origin' };
  return {
    'Access-Control-Allow-Origin': origin as string,
    'Access-Control-Allow-Methods': [...methods, 'OPTIONS'].join(', '),
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}
