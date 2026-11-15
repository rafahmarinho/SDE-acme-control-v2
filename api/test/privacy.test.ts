import { beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * T604 / T754: simulated SMS goes only to supervisors with a current granted consent who have not
 * restricted processing. The Supabase admin client is replaced by an in-memory fake.
 */
const tables: Record<string, Record<string, unknown>[]> = {};
const inserted: Record<string, unknown>[] = [];

function query(table: string) {
  let rows = [...(tables[table] ?? [])];
  const builder = {
    select: () => builder,
    eq: (col: string, val: unknown) => ((rows = rows.filter((r) => r[col] === val)), builder),
    in: (col: string, vals: unknown[]) => ((rows = rows.filter((r) => vals.includes(r[col]))), builder),
    insert: async (row: Record<string, unknown>) => (inserted.push({ table, ...row }), { error: null }),
    then: (resolve: (v: { data: unknown; error: null }) => unknown) => resolve({ data: rows, error: null }),
  };
  return builder;
}

vi.mock('../src/lib/supabase-admin.js', () => ({ adminClient: () => ({ from: query }) }));

const { notifySupervisors } = await import('../src/lib/outbound.js');
const PLANT = '11111111-1111-4111-8111-111111111111';

describe('consent and restriction of processing', () => {
  beforeEach(() => {
    inserted.length = 0;
    tables.plant_members = [
      { plant_id: PLANT, user_id: 'consented', role: 'supervisor' },
      { plant_id: PLANT, user_id: 'withdrawn', role: 'supervisor' },
      { plant_id: PLANT, user_id: 'restricted', role: 'supervisor' },
      { plant_id: PLANT, user_id: 'operator', role: 'operator' },
    ];
    tables.current_consents = [
      { user_id: 'consented', purpose: 'sms_alarm_notifications', granted: true },
      { user_id: 'withdrawn', purpose: 'sms_alarm_notifications', granted: false },
      { user_id: 'restricted', purpose: 'sms_alarm_notifications', granted: true },
      { user_id: 'operator', purpose: 'sms_alarm_notifications', granted: true },
    ];
    tables.profiles = [{ id: 'restricted', processing_restricted: true }];
  });

  it('sends only to consenting, unrestricted supervisors', async () => {
    expect(await notifySupervisors(PLANT, 'Setpoint changed.')).toBe(1);
    expect(inserted.filter((r) => r.table === 'events')).toHaveLength(1);
  });

  it('sends nothing once consent is withdrawn', async () => {
    tables.current_consents = tables.current_consents!.map((c) => ({ ...c, granted: false }));
    expect(await notifySupervisors(PLANT, 'Setpoint changed.')).toBe(0);
    expect(inserted).toHaveLength(0);
  });
});
