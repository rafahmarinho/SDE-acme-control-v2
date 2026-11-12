-- ACME Control - initial schema with default-deny security model.
-- Clients (anon/authenticated keys) only READ through Row Level Security and write a few
-- user-owned tables. All process-state changes go through the Vercel API (service role),
-- which authorizes, applies interlocks and writes the append-only audit log.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Schemas
-- ---------------------------------------------------------------------------
-- "internal" is NOT exposed through PostgREST (see config.toml [api].schemas).
create schema if not exists internal;
revoke all on schema internal from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Identity, membership and roles
-- ---------------------------------------------------------------------------
create table public.plants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  location_label text check (char_length(location_label) <= 120),
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  phone text check (phone is null or phone ~ '^\+[0-9]{8,15}$'),
  processing_restricted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.plant_members (
  user_id uuid not null references auth.users (id) on delete cascade,
  plant_id uuid not null references public.plants (id) on delete cascade,
  role text not null check (role in ('operator', 'engineer', 'supervisor', 'maintenance')),
  primary key (user_id, plant_id)
);

-- Role of the calling user in a plant (null when not a member).
create function public.my_role(p_plant uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role from public.plant_members m
  where m.user_id = auth.uid() and m.plant_id = p_plant
$$;

-- True when the calling user and p_user are members of at least one common plant.
create function public.shares_plant(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.plant_members a join public.plant_members b on a.plant_id = b.plant_id
    where a.user_id = auth.uid() and b.user_id = p_user)
$$;

-- ---------------------------------------------------------------------------
-- Process model
-- ---------------------------------------------------------------------------
create table public.tanks (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 32),
  name text not null check (char_length(name) between 1 and 80),
  capacity_m3 numeric not null check (capacity_m3 > 0),
  level_pct numeric not null default 50 check (level_pct between 0 and 100),
  low_limit_pct numeric not null default 5 check (low_limit_pct between 0 and 100),
  high_limit_pct numeric not null default 95 check (high_limit_pct between 0 and 100),
  pressure_bar numeric not null default 1.0,
  unique (plant_id, tag)
);

create table public.pumps (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 32),
  name text not null check (char_length(name) between 1 and 80),
  source_tank_id uuid not null references public.tanks (id),
  dest_tank_id uuid not null references public.tanks (id),
  rated_flow_m3h numeric not null check (rated_flow_m3h > 0),
  requested_state text not null default 'off' check (requested_state in ('on', 'off')),
  actual_state text not null default 'off' check (actual_state in ('on', 'off', 'fault')),
  mode text not null default 'manual' check (mode in ('manual', 'auto')),
  in_maintenance boolean not null default false,
  flow_m3h numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique (plant_id, tag)
);

create table public.valves (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 32),
  name text not null check (char_length(name) between 1 and 80),
  tank_id uuid not null references public.tanks (id),
  direction text not null check (direction in ('inlet', 'outlet')),
  rated_flow_m3h numeric not null check (rated_flow_m3h > 0),
  requested_state text not null default 'closed' check (requested_state in ('open', 'closed')),
  actual_state text not null default 'closed' check (actual_state in ('open', 'closed', 'fault')),
  mode text not null default 'manual' check (mode in ('manual', 'auto')),
  in_maintenance boolean not null default false,
  flow_m3h numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique (plant_id, tag)
);

create table public.setpoints (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 32),
  description text not null check (char_length(description) <= 160),
  value numeric not null,
  unit text not null check (char_length(unit) <= 16),
  min_value numeric not null,
  max_value numeric not null,
  check (min_value < max_value and value between min_value and max_value),
  unique (plant_id, tag)
);

create table public.setpoint_proposals (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  setpoint_id uuid not null references public.setpoints (id) on delete cascade,
  proposed_value numeric not null,
  reason text not null check (char_length(reason) between 1 and 500),
  proposed_by uuid not null references auth.users (id),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  review_comment text check (char_length(review_comment) <= 500),
  created_at timestamptz not null default now(),
  check (reviewed_by is null or reviewed_by <> proposed_by)   -- separation of duties
);

create table public.process_values (
  id bigserial primary key,
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null,
  ts timestamptz not null default now(),
  value numeric not null,
  unit text not null
);
create index process_values_plant_tag_ts on public.process_values (plant_id, tag, ts desc);

create table public.alarms (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  tag text not null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  message text not null check (char_length(message) <= 300),
  active boolean not null default true,
  raised_at timestamptz not null default now(),
  cleared_at timestamptz
);
create index alarms_plant_active on public.alarms (plant_id, active, raised_at desc);

-- Operational events shown on the "events" page (not the security audit log).
create table public.events (
  id bigserial primary key,
  plant_id uuid not null references public.plants (id) on delete cascade,
  ts timestamptz not null default now(),
  type text not null check (char_length(type) <= 64),
  message text not null check (char_length(message) <= 300),
  actor uuid references auth.users (id)
);
create index events_plant_ts on public.events (plant_id, ts desc);

create table public.maintenance_orders (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  equipment_tag text not null check (char_length(equipment_tag) <= 32),
  description text not null check (char_length(description) between 1 and 2000),
  status text not null default 'open' check (status in ('open', 'in_progress', 'done')),
  created_by uuid not null default auth.uid() references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.shift_handovers (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  notes text not null check (char_length(notes) between 1 and 2000),
  author uuid not null default auth.uid() references auth.users (id),
  created_at timestamptz not null default now()
);

-- File metadata; objects live in the private "attachments" bucket at <plant_id>/<id>.
create table public.attachments (
  id uuid primary key,
  plant_id uuid not null references public.plants (id) on delete cascade,
  path text not null unique,
  original_name text not null check (char_length(original_name) between 1 and 120),
  mime text not null check (mime in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes integer not null check (size_bytes between 1 and 10485760),
  uploaded_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  check (path = plant_id::text || '/' || id::text)
);

-- ---------------------------------------------------------------------------
-- Privacy: consent records (append-only history)
-- ---------------------------------------------------------------------------
create table public.consents (
  id bigserial primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  purpose text not null check (purpose in ('profile_optional_fields', 'sms_alarm_notifications')),
  granted boolean not null,
  notice_version text not null check (char_length(notice_version) <= 16),
  at timestamptz not null default now()
);

create view public.current_consents
with (security_invoker = true) as
select distinct on (user_id, purpose) user_id, purpose, granted, notice_version, at
from public.consents
order by user_id, purpose, at desc;

-- ---------------------------------------------------------------------------
-- Internal: append-only audit log, rate limits
-- ---------------------------------------------------------------------------
create table internal.audit_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor uuid,
  plant_id uuid,
  action text not null,
  target text,
  requested jsonb,
  result jsonb,
  request_id text,
  ip text,
  user_agent text,
  prev_hash text,
  hash text not null
);
create index audit_log_plant_at on internal.audit_log (plant_id, at desc);

create function internal.audit_hash_chain() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_prev text;
begin
  select a.hash into v_prev from internal.audit_log a order by a.id desc limit 1;
  new.prev_hash := v_prev;
  new.hash := encode(extensions.digest(
    coalesce(v_prev, '') || new.at::text || coalesce(new.actor::text, '') || new.action ||
    coalesce(new.target, '') || coalesce(new.requested::text, '') || coalesce(new.result::text, ''),
    'sha256'), 'hex');
  return new;
end $$;
create trigger audit_hash before insert on internal.audit_log
  for each row execute function internal.audit_hash_chain();

create function internal.deny_change() returns trigger
language plpgsql
as $$
begin
  raise exception 'audit log is append-only';
end $$;
create trigger audit_no_update_delete before update or delete on internal.audit_log
  for each row execute function internal.deny_change();
create trigger audit_no_truncate before truncate on internal.audit_log
  for each statement execute function internal.deny_change();
revoke update, delete, truncate on internal.audit_log from public, anon, authenticated, service_role;

create table internal.rate_limits (
  key text not null,
  window_start timestamptz not null,
  hits integer not null,
  primary key (key, window_start)
);

-- ---------------------------------------------------------------------------
-- Functions callable by the API (service role only)
-- ---------------------------------------------------------------------------
create function public.rl_hit(p_key text, p_limit integer, p_window_seconds integer)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  insert into internal.rate_limits as r (key, window_start, hits)
  values (p_key, date_bin(make_interval(secs => p_window_seconds), now(), to_timestamp(0)), 1)
  on conflict (key, window_start) do update set hits = r.hits + 1
  returning hits <= p_limit
$$;

create function public.audit_write(
  p_actor uuid, p_plant uuid, p_action text, p_target text,
  p_requested jsonb, p_result jsonb, p_request_id text, p_ip text, p_user_agent text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into internal.audit_log (actor, plant_id, action, target, requested, result, request_id, ip, user_agent, hash)
  values (p_actor, p_plant, left(p_action, 64), left(p_target, 128), p_requested, p_result,
          left(p_request_id, 64), left(p_ip, 64), left(p_user_agent, 256), '')
$$;

-- Demo reset: restores process data for one plant; never touches the audit log.
create function public.demo_reset(p_plant uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tanks set level_pct = 50, pressure_bar = 1.0 where plant_id = p_plant;
  update public.pumps set requested_state = 'off', actual_state = 'off', mode = 'manual',
    in_maintenance = false, flow_m3h = 0, updated_at = now() where plant_id = p_plant;
  update public.valves set requested_state = 'closed', actual_state = 'closed', mode = 'manual',
    in_maintenance = false, flow_m3h = 0, updated_at = now() where plant_id = p_plant;
  update public.alarms set active = false, cleared_at = now() where plant_id = p_plant and active;
  delete from public.process_values where plant_id = p_plant;
  insert into public.events (plant_id, type, message) values (p_plant, 'simulation.reset', 'Demo data reset.');
end $$;

-- ---------------------------------------------------------------------------
-- Functions callable by authenticated users
-- ---------------------------------------------------------------------------
-- Equipment search with bound parameters (no string-built SQL), capped at 50 rows.
create function public.search_equipment(p_plant uuid, p_q text)
returns table (kind text, id uuid, tag text, name text)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from (
    select 'tank'::text, t.id, t.tag, t.name from public.tanks t where t.plant_id = p_plant
    union all
    select 'pump'::text, p.id, p.tag, p.name from public.pumps p where p.plant_id = p_plant
    union all
    select 'valve'::text, v.id, v.tag, v.name from public.valves v where v.plant_id = p_plant
  ) e (kind, id, tag, name)
  where e.name ilike '%' || replace(replace(replace(left(p_q, 64), '\', '\\'), '%', '\%'), '_', '\_') || '%'
     or e.tag ilike '%' || replace(replace(replace(left(p_q, 64), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  order by e.tag
  limit 50
$$;

-- Supervisor-only, plant-scoped, paginated audit view.
create function public.audit_entries(p_plant uuid, p_before timestamptz default now(), p_limit integer default 50)
returns table (at timestamptz, actor uuid, action text, target text, result jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.my_role(p_plant) is distinct from 'supervisor' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select a.at, a.actor, a.action, a.target, a.result from internal.audit_log a
    where a.plant_id = p_plant and a.at < p_before
    order by a.at desc
    limit least(greatest(p_limit, 1), 200);
end $$;

-- ---------------------------------------------------------------------------
-- Privileges: default deny, then explicit grants
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

grant select on all tables in schema public to authenticated;
grant insert (plant_id, equipment_tag, description) on public.maintenance_orders to authenticated;
grant insert (plant_id, notes) on public.shift_handovers to authenticated;
grant insert (purpose, granted, notice_version) on public.consents to authenticated;
grant update (display_name, phone, updated_at) on public.profiles to authenticated;
grant usage on sequence public.consents_id_seq to authenticated;

grant execute on function public.my_role(uuid) to authenticated;
grant execute on function public.shares_plant(uuid) to authenticated;
grant execute on function public.search_equipment(uuid, text) to authenticated;
grant execute on function public.audit_entries(uuid, timestamptz, integer) to authenticated;
grant execute on function public.rl_hit(text, integer, integer) to service_role;
grant execute on function public.audit_write(uuid, uuid, text, text, jsonb, jsonb, text, text, text) to service_role;
grant execute on function public.demo_reset(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Row Level Security on every table
-- ---------------------------------------------------------------------------
alter table public.plants enable row level security;
alter table public.profiles enable row level security;
alter table public.plant_members enable row level security;
alter table public.tanks enable row level security;
alter table public.pumps enable row level security;
alter table public.valves enable row level security;
alter table public.setpoints enable row level security;
alter table public.setpoint_proposals enable row level security;
alter table public.process_values enable row level security;
alter table public.alarms enable row level security;
alter table public.events enable row level security;
alter table public.maintenance_orders enable row level security;
alter table public.shift_handovers enable row level security;
alter table public.attachments enable row level security;
alter table public.consents enable row level security;

create policy plants_read on public.plants for select to authenticated
  using (public.my_role(id) is not null);

create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_plant(id));
create policy profiles_self_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy members_read_own on public.plant_members for select to authenticated
  using (user_id = auth.uid());

create policy tanks_read on public.tanks for select to authenticated using (public.my_role(plant_id) is not null);
create policy pumps_read on public.pumps for select to authenticated using (public.my_role(plant_id) is not null);
create policy valves_read on public.valves for select to authenticated using (public.my_role(plant_id) is not null);
create policy setpoints_read on public.setpoints for select to authenticated using (public.my_role(plant_id) is not null);
create policy proposals_read on public.setpoint_proposals for select to authenticated using (public.my_role(plant_id) is not null);
create policy pv_read on public.process_values for select to authenticated using (public.my_role(plant_id) is not null);
create policy alarms_read on public.alarms for select to authenticated using (public.my_role(plant_id) is not null);
create policy events_read on public.events for select to authenticated using (public.my_role(plant_id) is not null);
create policy attachments_read on public.attachments for select to authenticated using (public.my_role(plant_id) is not null);

create policy mo_read on public.maintenance_orders for select to authenticated
  using (public.my_role(plant_id) is not null);
create policy mo_insert on public.maintenance_orders for insert to authenticated
  with check (public.my_role(plant_id) = 'maintenance' and created_by = auth.uid());

create policy handover_read on public.shift_handovers for select to authenticated
  using (public.my_role(plant_id) is not null);
create policy handover_insert on public.shift_handovers for insert to authenticated
  with check (public.my_role(plant_id) is not null and author = auth.uid());

create policy consents_own_read on public.consents for select to authenticated using (user_id = auth.uid());
create policy consents_own_insert on public.consents for insert to authenticated with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: private bucket, path-scoped policies (<plant_id>/<uuid>)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attachments', 'attachments', false, 10485760, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy attachments_object_read on storage.objects for select to authenticated
  using (bucket_id = 'attachments'
         and public.my_role(((storage.foldername(name))[1])::uuid) is not null);

-- Realtime: publish only process tables (RLS still applies to subscribers).
alter publication supabase_realtime add table public.tanks, public.pumps, public.valves, public.alarms;
