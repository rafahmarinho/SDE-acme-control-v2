---
name: t214-protect-confidential-files-on-server
description: Store maintenance attachments and reports in private Supabase Storage buckets with path-scoped RLS policies, size and MIME limits, and short-lived signed URLs.
---

# T214: Protect confidential files on operating system or server

**Category:** CODE_FIX
**SD Elements:** [T214](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T214/)
**Priority:** 9

**Spec Context:**
> "Supabase para PostgreSQL, login por e-mail e senha, arquivos e atualizações em tempo real" / "manutenção"
> Source: docs/specs/PRD.md, paragraphs 2 and 4

**What the spec implies (naive approach):**
A public bucket so images load easily via permanent public URLs.

**Secure Implementation Pattern:**
```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attachments', 'attachments', false, 10485760, array['image/jpeg','image/png','application/pdf']);

create policy att_read on storage.objects for select to authenticated
  using (bucket_id = 'attachments'
         and my_role(((storage.foldername(name))[1])::uuid) is not null);   -- path = <plant_id>/<uuid>
create policy att_write on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments'
         and my_role(((storage.foldername(name))[1])::uuid) = 'maintenance');
```

**Implementation Guidance:**
- Buckets private; downloads via signed URLs (≤ 60 s) after authorization (T50).
- Enforce size and MIME limits at bucket level; validate magic bytes server-side if processing files.
- No public URLs in the database.

**Success Criteria:**
- [ ] Anonymous access to any object returns 400/403.
- [ ] Users cannot read files under another plant's prefix.

**Status:** Pending
