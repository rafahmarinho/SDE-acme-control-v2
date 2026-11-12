/**
 * Environment access. Secrets come only from the Vercel project environment (never from code or
 * request data). Values are never logged.
 */

export function requireEnv(name: string): string {
  const value = process.env[name];
  if (value === undefined || value.trim() === '') {
    throw new Error(`Missing required environment variable ${name}`);
  }
  return value;
}

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1']);

/** Returns the URL from env, requiring https (plain http allowed only for localhost outside production). */
export function requireHttpsUrl(name: string): string {
  const raw = requireEnv(name);
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }
  const isProduction = process.env.VERCEL_ENV === 'production' || process.env.NODE_ENV === 'production';
  const localDev = !isProduction && url.protocol === 'http:' && LOCAL_HOSTS.has(url.hostname);
  if (url.protocol !== 'https:' && !localDev) {
    throw new Error(`${name} must use https`);
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new Error(`${name} must not contain credentials, query or fragment`);
  }
  return url.origin;
}

/** Refuses to run with TLS certificate verification disabled. */
export function assertTlsVerificationEnabled(): void {
  if (process.env.NODE_TLS_REJECT_UNAUTHORIZED === '0') {
    throw new Error('TLS certificate verification must not be disabled');
  }
}

/** Demo/simulation tooling is off unless explicitly enabled for a non-production deployment. */
export function demoToolsEnabled(): boolean {
  return process.env.ENABLE_DEMO_TOOLS === 'true';
}
