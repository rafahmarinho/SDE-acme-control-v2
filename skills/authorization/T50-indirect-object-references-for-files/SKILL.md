---
name: t50-indirect-object-references-for-files
description: Reference stored files (maintenance attachments, reports) by database ids mapped to server-generated storage paths, never by user-supplied file names or paths.
---

# T50: Use indirect object reference maps if accessing files

**Category:** CODE_FIX
**SD Elements:** [T50](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T50/)
**Priority:** 8

**Spec Context:**
> "Supabase para PostgreSQL, login por e-mail e senha, arquivos e atualizações em tempo real" / "manutenção"
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
Upload to `storage/attachments/<original-filename>` and download via `?file=<name>`, allowing path traversal and guessing other plants' files.

**Secure Implementation Pattern:**
```ts
// Upload: server picks the path
const fileId = crypto.randomUUID();
const path = `${plantId}/${fileId}`;                       // no user-controlled segments
await db.from('attachments').insert({ id: fileId, plant_id: plantId, path, original_name: sanitize(name) });
// Download: client sends attachment id; server authorizes, then issues a short signed URL
const { data } = await admin.storage.from('attachments').createSignedUrl(row.path, 60);
```

**Implementation Guidance:**
- Store the mapping `attachments(id, plant_id, path, original_name, mime, size)`.
- Authorize by attachment id + plant membership (T378) before creating a signed URL (≤ 60 s).
- Never concatenate user input into storage paths; keep original names only as metadata.

**Success Criteria:**
- [ ] No API accepts a raw storage path or filename for download.
- [ ] Requests for another plant's attachment id return 404.

**Status:** Pending
