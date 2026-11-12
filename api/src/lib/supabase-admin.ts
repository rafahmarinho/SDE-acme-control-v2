import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assertTlsVerificationEnabled, requireEnv, requireHttpsUrl } from './env.js';

/**
 * Supabase clients for the API. The connection target comes only from fixed environment
 * values - never from request data (plants and scenarios are rows, not connection parameters).
 *
 * - adminClient(): service role, used only for audited server-side writes and lookups.
 * - userClient(token): anon key + the caller's JWT, so Row Level Security applies to reads.
 */
let admin: SupabaseClient | undefined;

export function adminClient(): SupabaseClient {
  if (!admin) {
    assertTlsVerificationEnabled();
    admin = createClient(requireHttpsUrl('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
  }
  return admin;
}

export function userClient(accessToken: string): SupabaseClient {
  assertTlsVerificationEnabled();
  return createClient(requireHttpsUrl('SUPABASE_URL'), requireEnv('SUPABASE_ANON_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}
