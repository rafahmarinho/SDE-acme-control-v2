import { z } from 'zod';
import { SCENARIO_NAMES } from '../simulation/engine.js';

/**
 * Strict request schemas: fixed action names, bounded strings/numbers, unknown keys rejected.
 * Selectors (command type, scenario) map to server-side allow-lists, never to files or modules.
 */
const id = z.string().uuid();

export const CommandSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('pump'), plantId: id, equipmentId: id, state: z.enum(['on', 'off']) }).strict(),
  z.object({ type: z.literal('valve'), plantId: id, equipmentId: id, state: z.enum(['open', 'closed']) }).strict(),
  z
    .object({ type: z.literal('mode'), plantId: id, equipmentKind: z.enum(['pump', 'valve']), equipmentId: id, mode: z.enum(['manual', 'auto']) })
    .strict(),
  z
    .object({ type: z.literal('lockout'), plantId: id, equipmentKind: z.enum(['pump', 'valve']), equipmentId: id, inMaintenance: z.boolean() })
    .strict(),
]);
export type Command = z.infer<typeof CommandSchema>;

export const SetpointRequestSchema = z.discriminatedUnion('action', [
  z
    .object({
      action: z.literal('propose'),
      plantId: id,
      setpointId: id,
      value: z.number().finite(),
      reason: z.string().trim().min(1).max(500),
    })
    .strict(),
  z
    .object({
      action: z.literal('review'),
      plantId: id,
      proposalId: id,
      decision: z.enum(['approve', 'reject']),
      comment: z.string().trim().max(500).optional(),
    })
    .strict(),
]);

export const SimulationRequestSchema = z.discriminatedUnion('action', [
  z.object({ action: z.literal('scenario'), plantId: id, scenario: z.enum(SCENARIO_NAMES) }).strict(),
  z.object({ action: z.literal('step'), plantId: id, steps: z.number().int().min(1).max(600) }).strict(),
  z.object({ action: z.literal('reset'), plantId: id }).strict(),
]);

export const ALLOWED_MIME = ['image/jpeg', 'image/png', 'application/pdf'] as const;
export const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;

export const AttachmentRequestSchema = z.discriminatedUnion('action', [
  z
    .object({
      action: z.literal('upload_url'),
      plantId: id,
      fileName: z.string().min(1).max(200),
      mime: z.enum(ALLOWED_MIME),
      sizeBytes: z.number().int().min(1).max(MAX_ATTACHMENT_BYTES),
    })
    .strict(),
  z.object({ action: z.literal('download_url'), plantId: id, attachmentId: id }).strict(),
]);

/** Keeps a display-safe original file name: no path separators or control characters. */
export function sanitizeFileName(name: string): string {
  const base = name.split(/[\\/]/).pop() ?? '';
  // eslint-disable-next-line no-control-regex
  const cleaned = base.replace(/[\u0000-\u001f\u007f<>:"|?*]/g, '').replace(/^\.+/, '').trim();
  return (cleaned || 'file').slice(0, 120);
}
