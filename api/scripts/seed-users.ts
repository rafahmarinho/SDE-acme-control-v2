/**
 * Creates demo users for both plants with RANDOM passwords (printed once to the person running
 * the script). No credentials are stored in the repository or in seed.sql.
 *
 * Usage (local or a trusted machine, never in the browser/app):
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... pnpm seed:users
 */
import { randomBytes } from 'node:crypto';
import { adminClient } from '../src/lib/supabase-admin.js';

const PLANTS = ['11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222'];
const ROLES = ['operator', 'engineer', 'supervisor', 'maintenance'] as const;

async function main(): Promise<void> {
  const db = adminClient();
  for (const role of ROLES) {
    const email = `${role}@demo.acme-control.test`;
    const password = randomBytes(18).toString('base64url'); // 24 chars, CSPRNG
    const { data, error } = await db.auth.admin.createUser({ email, password, email_confirm: true });
    if (error || !data.user) {
      console.error(`Could not create ${email}: ${error?.message ?? 'unknown error'}`);
      continue;
    }
    const userId = data.user.id;
    await db.from('profiles').insert({ id: userId, display_name: `Demo ${role}` });
    await db.from('plant_members').insert(PLANTS.map((plant_id) => ({ user_id: userId, plant_id, role })));
    console.log(`${role.padEnd(12)} ${email}  ${password}`);
  }
  console.log('\nStore these passwords securely; they are not saved anywhere else.');
}

main().catch((e: unknown) => {
  console.error((e as Error).message);
  process.exit(1);
});
