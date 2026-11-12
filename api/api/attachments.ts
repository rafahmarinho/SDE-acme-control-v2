/**
 * POST /api/attachments
 *  - "upload_url":   server chooses the storage path <plant_id>/<uuid> (indirect reference),
 *                    records metadata and returns a signed upload URL for the private bucket.
 *  - "download_url": client sends the attachment id; after authorization the server returns a
 *                    signed URL valid for 60 seconds. Raw paths/file names are never accepted.
 */
import { randomUUID } from 'node:crypto';
import { authorize } from '../src/auth/permissions.js';
import { requireUser } from '../src/auth/verify.js';
import { AttachmentRequestSchema, sanitizeFileName } from '../src/commands/schemas.js';
import { audit, securityEvent } from '../src/lib/audit.js';
import { HttpError, json, readJson, route, type RequestContext } from '../src/lib/http.js';
import { enforce, LIMITS } from '../src/lib/rate-limit.js';
import { adminClient } from '../src/lib/supabase-admin.js';

const BUCKET = 'attachments';
const DOWNLOAD_TTL_SECONDS = 60;

async function handle(req: Request, ctx: RequestContext): Promise<Response> {
  const user = await requireUser(req, ctx);
  const body = AttachmentRequestSchema.parse(await readJson(req));
  await enforce(`att:${user.id}`, LIMITS.attachment.limit, LIMITS.attachment.window);
  const db = adminClient();

  if (body.action === 'upload_url') {
    await authorize(user.id, body.plantId, 'attachment.upload');
    const id = randomUUID();
    const path = `${body.plantId}/${id}`;
    const { error } = await db.from('attachments').insert({
      id,
      plant_id: body.plantId,
      path,
      original_name: sanitizeFileName(body.fileName),
      mime: body.mime,
      size_bytes: body.sizeBytes,
      uploaded_by: user.id,
    });
    if (error) throw new Error('attachment_insert_failed');
    const { data, error: urlError } = await db.storage.from(BUCKET).createSignedUploadUrl(path);
    if (urlError || !data) throw new Error('signed_upload_failed');
    await audit({ actor: user.id, plantId: body.plantId, action: 'attachment.upload', target: id, requested: { mime: body.mime, sizeBytes: body.sizeBytes } }, ctx);
    return json(201, { attachmentId: id, uploadUrl: data.signedUrl, token: data.token });
  }

  await authorize(user.id, body.plantId, 'attachment.read');
  const { data: row } = await db.from('attachments').select('id, path').eq('id', body.attachmentId).eq('plant_id', body.plantId).maybeSingle();
  if (!row) throw new HttpError(404, 'not_found');
  const { data, error } = await db.storage.from(BUCKET).createSignedUrl(row.path as string, DOWNLOAD_TTL_SECONDS);
  if (error || !data) throw new Error('signed_url_failed');
  return json(200, { url: data.signedUrl, expiresIn: DOWNLOAD_TTL_SECONDS });
}

const handler = route({ POST: handle }, securityEvent);
export const POST = handler;
export const GET = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
