import { HttpError } from '../lib/http.js';
import { adminClient } from '../lib/supabase-admin.js';

export const ROLES = ['operator', 'engineer', 'supervisor', 'maintenance'] as const;
export type Role = (typeof ROLES)[number];

/**
 * Single server-side permission matrix (docs/security/access-matrix.md). The Flutter router
 * only mirrors this for navigation; it is never the enforcement point.
 */
export const PERMISSIONS = {
  'pump.toggle': ['operator', 'supervisor'],
  'valve.toggle': ['operator', 'supervisor'],
  'mode.set': ['operator', 'supervisor'],
  'equipment.lockout': ['maintenance'],
  'setpoint.propose': ['engineer'],
  'setpoint.review': ['supervisor'],
  'attachment.upload': ['operator', 'engineer', 'supervisor', 'maintenance'],
  'attachment.read': ['operator', 'engineer', 'supervisor', 'maintenance'],
  'alarm.acknowledge': ['operator', 'supervisor'],
  'simulation.manage': ['supervisor'],
} as const satisfies Record<string, readonly Role[]>;

export type Action = keyof typeof PERMISSIONS;

export function isPermitted(role: Role, action: Action): boolean {
  return (PERMISSIONS[action] as readonly Role[]).includes(role);
}

/** Loads the caller's role in a plant from the database (never from client claims). */
export async function roleInPlant(userId: string, plantId: string): Promise<Role | null> {
  const { data, error } = await adminClient()
    .from('plant_members')
    .select('role')
    .eq('user_id', userId)
    .eq('plant_id', plantId)
    .maybeSingle();
  if (error) throw new Error('membership_lookup_failed');
  return (data?.role as Role | undefined) ?? null;
}

/**
 * Object-level + role authorization. Non-members get 404 (no enumeration of other plants);
 * members without the permission get 403.
 */
export async function authorize(userId: string, plantId: string, action: Action): Promise<Role> {
  const role = await roleInPlant(userId, plantId);
  if (!role) throw new HttpError(404, 'not_found');
  if (!isPermitted(role, action)) throw new HttpError(403, 'forbidden');
  return role;
}
