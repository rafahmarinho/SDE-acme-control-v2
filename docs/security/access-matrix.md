# Access matrix

Enforced in `api/src/auth/permissions.ts` (API actions) and `supabase/migrations/0001_init.sql`
(RLS policies + column grants). The Flutter router only mirrors this for navigation.
Non-members of a plant get **404** for every object of that plant.

## API actions (per plant membership role)

| Action | operator | engineer | supervisor | maintenance | Extra |
|--------|:-:|:-:|:-:|:-:|-------|
| pump.toggle / valve.toggle | ✓ | | ✓ | | interlocks; manual mode only |
| mode.set | ✓ | | ✓ | | recent login (15 min) |
| equipment.lockout | | | | ✓ | recent login; forces safe state |
| setpoint.propose | | ✓ | | | value within tag min/max |
| setpoint.review | | | ✓ | | recent login; never own proposal |
| attachment.upload / read | ✓ | ✓ | ✓ | ✓ | server-chosen paths, 60 s signed URLs |
| simulation.manage | | | ✓ | | ENABLE_DEMO_TOOLS only; reset needs recent login |

## Direct database access (authenticated key, RLS)

| Table | Read | Write |
|-------|------|-------|
| plants, tanks, pumps, valves, setpoints, setpoint_proposals, process_values, alarms, events, attachments | plant members | API only (service role) |
| maintenance_orders | plant members | insert: maintenance role, `created_by = auth.uid()` |
| shift_handovers | plant members | insert: plant members, `author = auth.uid()` |
| profiles | self + users sharing a plant | update own `display_name`, `phone` only |
| plant_members | own rows | administrator only |
| consents | own | insert own (append-only history) |
| internal.audit_log | supervisors via `audit_entries()` | append-only via `audit_write()` (service role) |
| anon key | nothing | nothing |
