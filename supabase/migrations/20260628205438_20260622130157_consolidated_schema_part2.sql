-- Vehicle summary view
create or replace view public.vehicle_summary as
with session_stats as (
  select
    vehicle_id,
    count(*) as total_sessions,
    max(started_at) as last_used_at,
    sum(case when extract(epoch from (ended_at - started_at)) is not null
             then extract(epoch from (ended_at - started_at)) / 60 else 0 end) as total_minutes
  from public.vehicle_sessions
  group by vehicle_id
),
damage_stats as (
  select
    vehicle_id,
    count(*) filter (where status = 'open' and (source = 'baseline' or approved = true)) as open_damage_count,
    count(*) as total_damage_count
  from public.damage_markers
  group by vehicle_id
),
latest_inspection as (
  select distinct on (vehicle_id)
    vehicle_id,
    created_at as last_inspection_at,
    inspection_type as last_inspection_type,
    items_issue_count as last_inspection_issues
  from public.inspections
  order by vehicle_id, created_at desc
)
select
  v.id,
  v.registration_number,
  v.make,
  v.model,
  v.year,
  v.vin,
  v.status,
  v.archived,
  coalesce(ss.total_sessions, 0) as total_sessions,
  ss.last_used_at,
  coalesce(ss.total_minutes, 0) as total_drive_minutes,
  coalesce(ds.open_damage_count, 0) as open_damage_count,
  coalesce(ds.total_damage_count, 0) as total_damage_count,
  li.last_inspection_at,
  li.last_inspection_type,
  coalesce(li.last_inspection_issues, 0) as last_inspection_issues
from public.vehicles v
left join session_stats ss on ss.vehicle_id = v.id
left join damage_stats ds on ds.vehicle_id = v.id
left join latest_inspection li on li.vehicle_id = v.id;

grant select on public.vehicle_summary to authenticated;

-- Update RPC functions
create or replace function public.start_vehicle_session(
  p_driver_id uuid,
  p_vehicle_id uuid,
  p_marker_ids uuid[] default '{}'
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session_id uuid;
begin
  if not exists (select 1 from public.drivers where id = p_driver_id and active = true) then
    raise exception 'Driver not found or inactive';
  end if;
  insert into public.vehicle_sessions (driver_id, vehicle_id, status)
  values (p_driver_id, p_vehicle_id, 'active')
  returning id into v_session_id;
  if array_length(p_marker_ids, 1) is not null then
    update public.damage_markers
      set session_id = v_session_id, reported_during = 'pre_trip'
      where id = any(p_marker_ids) and source = 'driver';
  end if;
  return v_session_id;
end;
$$;
grant execute on function public.start_vehicle_session(uuid, uuid, uuid[]) to anon;

create or replace function public.complete_vehicle_session(p_session_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.vehicle_sessions where id = p_session_id and status = 'active'
  ) then
    raise exception 'Session not found or already completed';
  end if;
  update public.vehicle_sessions
    set status = 'completed', ended_at = now()
    where id = p_session_id;
end;
$$;
grant execute on function public.complete_vehicle_session(uuid) to anon;

drop function if exists public.get_vehicle_checklist(uuid);
drop function if exists public.get_vehicle_checklist(uuid, text);
create or replace function public.get_vehicle_checklist(p_vehicle_id uuid, p_type text default 'pre_trip')
returns table (
  item_id uuid,
  item_text text,
  item_order int,
  item_key text,
  enabled boolean
)
language sql stable security definer set search_path = public as $$
  select
    ci.id as item_id,
    ci.item_text,
    ci.item_order,
    ci.item_key,
    coalesce(vci.enabled, true) as enabled
  from checklist_items ci
  left join vehicle_checklist_items vci
    on vci.checklist_item_id = ci.id and vci.vehicle_id = p_vehicle_id
  where ci.is_active = true
  and ci.checklist_type = p_type
  order by ci.item_order;
$$;
grant execute on function public.get_vehicle_checklist(uuid, text) to anon, authenticated;

drop function if exists public.get_vehicle_enabled_checklist(uuid);
drop function if exists public.get_vehicle_enabled_checklist(uuid, text);
create or replace function public.get_vehicle_enabled_checklist(p_vehicle_id uuid, p_type text default 'pre_trip')
returns table (
  item_id uuid,
  item_text text,
  item_order int,
  item_key text
)
language sql stable security definer set search_path = public as $$
  select ci.id, ci.item_text, ci.item_order, ci.item_key
  from checklist_items ci
  where ci.is_active = true
  and ci.checklist_type = p_type
  and (
    not exists (select 1 from vehicle_checklist_items where vehicle_id = p_vehicle_id)
    or exists (
      select 1 from vehicle_checklist_items vci
      where vci.vehicle_id = p_vehicle_id
      and vci.checklist_item_id = ci.id
      and vci.enabled = true
    )
    or not exists (
      select 1 from vehicle_checklist_items vci
      where vci.vehicle_id = p_vehicle_id
      and vci.checklist_item_id = ci.id
    )
  )
  order by ci.item_order;
$$;
grant execute on function public.get_vehicle_enabled_checklist(uuid, text) to anon, authenticated;