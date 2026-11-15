-- ACME Control - support for the full set of PRD screens (alarms, trends, maintenance,
-- simulation events). Keeps the 0001 default-deny model: clients read through RLS, process
-- changes go through the audited Vercel API, and every new grant is column-scoped.

-- ---------------------------------------------------------------------------
-- Alarms: acknowledgement (written only by the API, role-checked and audited)
-- ---------------------------------------------------------------------------
alter table public.alarms
  add column acknowledged_at timestamptz,
  add column acknowledged_by uuid references auth.users (id);

-- ---------------------------------------------------------------------------
-- Maintenance orders: status workflow for the maintenance role (RLS, column grant)
-- ---------------------------------------------------------------------------
alter table public.maintenance_orders
  add column updated_at timestamptz not null default now();

grant update (status, updated_at) on public.maintenance_orders to authenticated;

create policy mo_update on public.maintenance_orders for update to authenticated
  using (public.my_role(plant_id) = 'maintenance')
  with check (public.my_role(plant_id) = 'maintenance');

-- Every status change is recorded as an operational event and in the audit log, so direct
-- RLS writes stay traceable (T2602). Runs as definer to reach the internal schema.
create function internal.maintenance_order_changed() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.events (plant_id, type, message, actor)
    values (new.plant_id, 'maintenance.created', left('Work order created for ' || new.equipment_tag || '.', 300), auth.uid());
    perform public.audit_write(auth.uid(), new.plant_id, 'maintenance.create', new.equipment_tag,
      jsonb_build_object('orderId', new.id), jsonb_build_object('status', new.status), null, null, null);
  elsif new.status is distinct from old.status then
    insert into public.events (plant_id, type, message, actor)
    values (new.plant_id, 'maintenance.status', left('Work order for ' || new.equipment_tag || ' is now ' || replace(new.status, '_', ' ') || '.', 300), auth.uid());
    perform public.audit_write(auth.uid(), new.plant_id, 'maintenance.status', new.equipment_tag,
      jsonb_build_object('orderId', new.id, 'from', old.status), jsonb_build_object('status', new.status), null, null, null);
  end if;
  return new;
end $$;
revoke execute on function internal.maintenance_order_changed() from public, anon, authenticated;

create trigger maintenance_order_changed after insert or update on public.maintenance_orders
  for each row execute function internal.maintenance_order_changed();

-- Only the status columns may change; identity / plant / description are immutable.
create function internal.maintenance_order_guard() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.plant_id <> old.plant_id or new.created_by <> old.created_by
     or new.equipment_tag <> old.equipment_tag or new.description <> old.description then
    raise exception 'immutable column' using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger maintenance_order_guard before update on public.maintenance_orders
  for each row execute function internal.maintenance_order_guard();

-- ---------------------------------------------------------------------------
-- Trends: bounded, plant-scoped time-series read (T2600)
-- ---------------------------------------------------------------------------
-- Security invoker: RLS on process_values still decides what the caller may read.
-- Rejects time ranges over 7 days and caps the result at 2000 points.
create function public.trend_values(p_plant uuid, p_tag text, p_from timestamptz, p_to timestamptz, p_limit integer default 1000)
returns table (ts timestamptz, value numeric, unit text)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if p_tag is null or char_length(p_tag) > 64 then
    raise exception 'invalid tag' using errcode = '22023';
  end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '7 days' then
    raise exception 'invalid time range' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 2000 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  return query
    select v.ts, v.value, v.unit from public.process_values v
    where v.plant_id = p_plant and v.tag = p_tag and v.ts >= p_from and v.ts < p_to
    order by v.ts desc
    limit p_limit;
end $$;

-- Distinct trend tags available for a plant (small, bounded list for the tag picker).
create function public.trend_tags(p_plant uuid)
returns table (tag text, unit text)
language sql
stable
security invoker
set search_path = ''
as $$
  select distinct on (v.tag) v.tag, v.unit from public.process_values v
  where v.plant_id = p_plant
  order by v.tag, v.ts desc
  limit 100
$$;

revoke execute on function public.trend_values(uuid, text, timestamptz, timestamptz, integer) from public, anon;
revoke execute on function public.trend_tags(uuid) from public, anon;
grant execute on function public.trend_values(uuid, text, timestamptz, timestamptz, integer) to authenticated;
grant execute on function public.trend_tags(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Demo reset also clears acknowledgement state and reopens the baseline
-- ---------------------------------------------------------------------------
create or replace function public.demo_reset(p_plant uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tanks set level_pct = case when tag like '%1' then 60 else 40 end, pressure_bar = 1.0 where plant_id = p_plant;
  update public.pumps set requested_state = 'off', actual_state = 'off', mode = 'manual',
    in_maintenance = false, flow_m3h = 0, updated_at = now() where plant_id = p_plant;
  update public.valves set requested_state = 'closed', actual_state = 'closed', mode = 'manual',
    in_maintenance = false, flow_m3h = 0, updated_at = now() where plant_id = p_plant;
  update public.alarms set active = false, cleared_at = now() where plant_id = p_plant and active;
  delete from public.process_values where plant_id = p_plant;
  insert into public.events (plant_id, type, message) values (p_plant, 'simulation.reset', 'Demo data reset.');
end $$;
revoke execute on function public.demo_reset(uuid) from public, anon, authenticated;
grant execute on function public.demo_reset(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Privacy: restriction-of-processing changes are audited (T754)
-- ---------------------------------------------------------------------------
create function internal.profile_restriction_changed() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.processing_restricted is distinct from old.processing_restricted then
    perform public.audit_write(auth.uid(), null, 'privacy.restriction', new.id::text,
      jsonb_build_object('from', old.processing_restricted), jsonb_build_object('processing_restricted', new.processing_restricted),
      null, null, null);
  end if;
  return new;
end $$;
revoke execute on function internal.profile_restriction_changed() from public, anon, authenticated;
create trigger profile_restriction_changed after update of processing_restricted on public.profiles
  for each row execute function internal.profile_restriction_changed();

-- ---------------------------------------------------------------------------
-- Realtime: events, proposals and work orders (RLS still applies to subscribers)
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.events, public.setpoint_proposals, public.maintenance_orders;
