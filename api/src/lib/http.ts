import { randomUUID } from 'node:crypto';
import { ZodError } from 'zod';
import { corsHeaders, isAllowedOrigin } from './cors.js';

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    public readonly headers: Record<string, string> = {},
  ) {
    super(code);
  }
}

export interface RequestContext {
  requestId: string;
  ip: string | null;
  userAgent: string | null;
  url: URL;
}

/** Hardened headers sent on every API response. */
export const SECURITY_HEADERS: Readonly<Record<string, string>> = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
  'Referrer-Policy': 'no-referrer',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
};

export function json(status: number, body: unknown, extraHeaders: Record<string, string> = {}): Response {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...SECURITY_HEADERS, ...extraHeaders },
  });
}

/** Maximum accepted request body (commands, setpoints and simulation requests are tiny). */
export const MAX_BODY_BYTES = 16 * 1024;

/** Reads a JSON body, enforcing content type and size limits before parsing. */
export async function readJson(req: Request): Promise<unknown> {
  const type = req.headers.get('content-type') ?? '';
  if (!type.toLowerCase().startsWith('application/json')) {
    throw new HttpError(415, 'unsupported_media_type');
  }
  const declared = Number(req.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) {
    throw new HttpError(413, 'payload_too_large');
  }
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) {
    throw new HttpError(413, 'payload_too_large');
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new HttpError(400, 'invalid_json');
  }
}

export type Handler = (req: Request, ctx: RequestContext) => Promise<Response>;
export type SecurityEventSink = (event: string, status: number, ctx: RequestContext) => Promise<void>;

const SECURITY_STATUSES = new Set([401, 403, 405, 413, 415, 429]);
const KNOWN_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'] as const;

function clientIp(req: Request): string | null {
  const forwarded = req.headers.get('x-forwarded-for');
  return forwarded ? (forwarded.split(',')[0]?.trim() ?? null) : null;
}

/**
 * Wraps route handlers with: method allow-list, CORS, uniform security headers, generic errors
 * (no stack traces or database messages) and security-event logging.
 */
export function route(handlers: Partial<Record<(typeof KNOWN_METHODS)[number], Handler>>, onSecurityEvent?: SecurityEventSink) {
  const allowed = Object.keys(handlers);
  return async (req: Request): Promise<Response> => {
    const ctx: RequestContext = {
      requestId: randomUUID(),
      ip: clientIp(req),
      userAgent: req.headers.get('user-agent')?.slice(0, 256) ?? null,
      url: new URL(req.url),
    };
    const cors = corsHeaders(req.headers.get('origin'), allowed);

    if (req.method === 'OPTIONS') {
      const origin = req.headers.get('origin');
      return new Response(null, { status: isAllowedOrigin(origin) ? 204 : 403, headers: { ...SECURITY_HEADERS, ...cors } });
    }

    const handler = handlers[req.method as (typeof KNOWN_METHODS)[number]];
    try {
      if (!handler) throw new HttpError(405, 'method_not_allowed', { Allow: allowed.join(', ') });
      const res = await handler(req, ctx);
      for (const [k, v] of Object.entries(cors)) res.headers.set(k, v);
      return res;
    } catch (err) {
      let status = 500;
      let code = 'internal_error';
      let headers: Record<string, string> = {};
      if (err instanceof HttpError) {
        ({ status, code, headers } = err);
      } else if (err instanceof ZodError) {
        status = 400;
        code = 'invalid_request';
      } else {
        console.error(JSON.stringify({ level: 'error', requestId: ctx.requestId, message: (err as Error)?.name ?? 'Error' }));
      }
      if (SECURITY_STATUSES.has(status) && onSecurityEvent) {
        await onSecurityEvent(code, status, ctx).catch(() => undefined);
      }
      return json(status, { error: code, requestId: ctx.requestId }, { ...headers, ...cors });
    }
  };
}
