-- Continue consolidated schema - tables, indexes, views, functions, triggers, storage

-- Enable pgcrypto
create extension if not exists pgcrypto;

-- Add any missing columns to existing tables
do $$ begin alter table public.drivers add column mobile text; exception when duplicate_column then null; end $$;
do $$ begin alter table public.drivers add column licence_number text; exception when duplicate_column then null; end $$;
do $$ begin alter table public.drivers add column licence_type text check (licence_type in ('local', 'international')); exception when duplicate_column then null; end $$;
do $$ begin alter table public.drivers add column licence_category text; exception when duplicate_column then null; end $$;
do $$ begin alter table public.drivers add column cpc_valid boolean not null default false; exception when duplicate_column then null; end $$;
do $$ begin alter table public.drivers add column cpc_expiry_date date; exception when duplicate_column then null; end $$;

do $$ begin alter table public.vehicles add column road_licence_date date; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicles add column road_licence_due date; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicles add column last_service_date date; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicles add column service_due_date date; exception when duplicate_column then null; end $$;

do $$ begin alter table public.vehicle_sessions add column odometer_start numeric; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicle_sessions add column odometer_end numeric; exception when duplicate_column then null; end $$;

do $$ begin alter table public.inspections add column items_pass_count integer not null default 0; exception when duplicate_column then null; end $$;
do $$ begin alter table public.inspections add column items_issue_count integer not null default 0; exception when duplicate_column then null; end $$;

do $$ begin alter table public.damage_markers add column source damage_source not null default 'driver'; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column approved boolean not null default false; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column approved_at timestamptz; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column approved_by uuid references auth.users(id); exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column rejection_reason text; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column session_id uuid references public.vehicle_sessions(id) on delete set null; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_markers add column reported_during text check (reported_during in ('pre_trip', 'return')); exception when duplicate_column then null; end $$;

do $$ begin alter table public.damage_marker_photos add column approved boolean not null default false; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_marker_photos add column approved_at timestamptz; exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_marker_photos add column approved_by uuid references auth.users(id); exception when duplicate_column then null; end $$;
do $$ begin alter table public.damage_marker_photos add column uploaded_at timestamptz not null default now(); exception when duplicate_column then null; end $$;

do $$ begin alter table public.vehicle_blueprints add column view blueprint_view; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicle_blueprints add column updated_at timestamptz not null default now(); exception when duplicate_column then null; end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vehicle_blueprints_vehicle_view_unique') then
    alter table public.vehicle_blueprints add constraint vehicle_blueprints_vehicle_view_unique unique (vehicle_id, view);
  end if;
end $$;

do $$ begin alter table public.vehicle_base_photos add column view blueprint_view; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicle_base_photos add column label text; exception when duplicate_column then null; end $$;
do $$ begin alter table public.vehicle_base_photos add column created_at timestamptz not null default now(); exception when duplicate_column then null; end $$;

-- Create missing tables
create table if not exists public.damage_marker_base_photos (
  id uuid primary key default gen_random_uuid(),
  damage_marker_id uuid not null references public.damage_markers(id) on delete cascade,
  base_photo_id uuid not null references public.vehicle_base_photos(id) on delete cascade,
  unique (damage_marker_id, base_photo_id)
);

-- Checklist items (drop old template tables, create global)
drop table if exists public.vehicle_checklist_assignments cascade;
drop table if exists public.checklist_templates cascade;

create table if not exists public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  item_text text not null,
  item_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

do $$ begin alter table public.checklist_items add column checklist_type text not null default 'pre_trip' check (checklist_type in ('pre_trip', 'return')); exception when duplicate_column then null; end $$;
do $$ begin alter table public.checklist_items add column item_key text unique; exception when duplicate_column then null; end $$;

create table if not exists public.vehicle_checklist_items (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checklist_item_id uuid not null references public.checklist_items(id) on delete cascade,
  enabled boolean not null default true,
  unique (vehicle_id, checklist_item_id)
);

create table if not exists public.vehicle_logbooks (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  file_path text not null,
  file_name text not null,
  uploaded_at timestamptz not null default now()
);

create table if not exists public.vehicle_repairs (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  repair_date date not null,
  description text not null,
  cost numeric(10, 2),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

-- Enable RLS on new tables
alter table public.damage_marker_base_photos enable row level security;
alter table public.checklist_items enable row level security;
alter table public.vehicle_checklist_items enable row level security;
alter table public.vehicle_logbooks enable row level security;
alter table public.vehicle_repairs enable row level security;

-- Create indexes
create index if not exists idx_sessions_driver on public.vehicle_sessions(driver_id);
create index if not exists idx_sessions_vehicle on public.vehicle_sessions(vehicle_id);
create index if not exists idx_dmbp_marker on public.damage_marker_base_photos(damage_marker_id);
create index if not exists idx_damages_pending_approval on public.damage_markers(source, approved, status) where source = 'driver' and approved = false;
create index if not exists idx_damages_admin_list on public.damage_markers(reported_at desc);
create index if not exists idx_damage_photos_marker on public.damage_marker_photos(damage_marker_id);
create index if not exists idx_checklist_items_order on public.checklist_items(item_order);
create index if not exists idx_vehicle_checklist_vehicle on public.vehicle_checklist_items(vehicle_id);
create index if not exists idx_vehicle_checklist_item on public.vehicle_checklist_items(checklist_item_id);
create index if not exists idx_damage_markers_vehicle on public.damage_markers(vehicle_id);
create index if not exists idx_damage_markers_driver on public.damage_markers(driver_id);
create index if not exists idx_damage_markers_session on public.damage_markers(session_id);
create index if not exists idx_damage_markers_reported_during on public.damage_markers(reported_during);
create index if not exists idx_inspection_items_inspection on public.inspection_items(inspection_id);
create index if not exists idx_inspection_item_photos_item on public.inspection_item_photos(inspection_item_id);
create index if not exists idx_base_photos_vehicle on public.vehicle_base_photos(vehicle_id);

-- Grant privileges
grant select, insert, update, delete on public.damage_marker_base_photos, public.checklist_items, public.vehicle_checklist_items, public.vehicle_logbooks, public.vehicle_repairs to authenticated;
grant select on public.vehicle_base_photos, public.damage_marker_base_photos to anon;
grant select on public.checklist_items, public.vehicle_checklist_items to anon;

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

-- Update triggers
create or replace function public.sync_inspection_counts()
returns trigger language plpgsql as $$
declare
  v_inspection_id uuid;
begin
  v_inspection_id := coalesce(new.inspection_id, old.inspection_id);
  update public.inspections set
    items_pass_count = (select count(*) from public.inspection_items where inspection_id = v_inspection_id and result = 'pass'),
    items_issue_count = (select count(*) from public.inspection_items where inspection_id = v_inspection_id and result = 'issue')
  where id = v_inspection_id;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_inspection_counts on public.inspection_items;
create trigger trg_sync_inspection_counts
  after insert or update or delete on public.inspection_items
  for each row execute function public.sync_inspection_counts();

create or replace function public.trg_session_manage_vehicle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'insert' then
    if new.status = 'active' then
      update public.vehicle_sessions
        set status = 'completed', ended_at = now()
        where driver_id = new.driver_id
          and status = 'active'
          and id <> new.id;
      update public.vehicles set status = 'assigned' where id = new.vehicle_id;
    end if;
  elsif tg_op = 'update' then
    if old.status = 'active' and new.status = 'completed' then
      update public.vehicles set status = 'available' where id = new.vehicle_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_session_manage_vehicle on public.vehicle_sessions;
create trigger trg_session_manage_vehicle
  after insert or update on public.vehicle_sessions
  for each row execute function public.trg_session_manage_vehicle();

-- Storage buckets
insert into storage.buckets (id, name, public, created_at)
values ('vehicle-blueprints', 'vehicle-blueprints', true, now())
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, created_at)
values ('vehicle-base-photos', 'vehicle-base-photos', true, now())
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, created_at)
values ('inspection-photos', 'inspection-photos', false, now())
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, created_at)
values ('damage-photos', 'damage-photos', false, now())
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, created_at)
values ('vehicle-logbooks', 'vehicle-logbooks', false, now())
on conflict (id) do nothing;

-- Storage policies (drop and recreate)
do $$ begin
  drop policy if exists bp_public_read on storage.objects;
  drop policy if exists bp_auth_insert on storage.objects;
  drop policy if exists bp_auth_update on storage.objects;
  drop policy if exists bp_auth_delete on storage.objects;
  drop policy if exists base_public_read on storage.objects;
  drop policy if exists base_auth_insert on storage.objects;
  drop policy if exists base_auth_update on storage.objects;
  drop policy if exists base_auth_delete on storage.objects;
  drop policy if exists damage_anon_read on storage.objects;
  drop policy if exists damage_auth_read on storage.objects;
  drop policy if exists damage_anon_insert on storage.objects;
  drop policy if exists damage_auth_insert on storage.objects;
  drop policy if exists damage_auth_update on storage.objects;
  drop policy if exists damage_auth_delete on storage.objects;
  drop policy if exists inspect_anon_read on storage.objects;
  drop policy if exists inspect_auth_read on storage.objects;
  drop policy if exists inspect_anon_insert on storage.objects;
  drop policy if exists inspect_auth_insert on storage.objects;
  drop policy if exists inspect_auth_update on storage.objects;
  drop policy if exists inspect_auth_delete on storage.objects;
  drop policy if exists logbooks_auth_read on storage.objects;
  drop policy if exists logbooks_auth_insert on storage.objects;
  drop policy if exists logbooks_auth_update on storage.objects;
  drop policy if exists logbooks_auth_delete on storage.objects;
exception when others then null;
end $$;

create policy bp_public_read on storage.objects for select to public using (bucket_id = 'vehicle-blueprints');
create policy bp_auth_insert on storage.objects for insert to authenticated with check (bucket_id = 'vehicle-blueprints');
create policy bp_auth_update on storage.objects for update to authenticated using (bucket_id = 'vehicle-blueprints') with check (bucket_id = 'vehicle-blueprints');
create policy bp_auth_delete on storage.objects for delete to authenticated using (bucket_id = 'vehicle-blueprints');

create policy base_public_read on storage.objects for select to public using (bucket_id = 'vehicle-base-photos');
create policy base_auth_insert on storage.objects for insert to authenticated with check (bucket_id = 'vehicle-base-photos');
create policy base_auth_update on storage.objects for update to authenticated using (bucket_id = 'vehicle-base-photos') with check (bucket_id = 'vehicle-base-photos');
create policy base_auth_delete on storage.objects for delete to authenticated using (bucket_id = 'vehicle-base-photos');

create policy damage_anon_read on storage.objects for select to anon using (bucket_id = 'damage-photos');
create policy damage_auth_read on storage.objects for select to authenticated using (bucket_id = 'damage-photos');
create policy damage_anon_insert on storage.objects for insert to anon with check (bucket_id = 'damage-photos');
create policy damage_auth_insert on storage.objects for insert to authenticated with check (bucket_id = 'damage-photos');
create policy damage_auth_update on storage.objects for update to authenticated using (bucket_id = 'damage-photos') with check (bucket_id = 'damage-photos');
create policy damage_auth_delete on storage.objects for delete to authenticated using (bucket_id = 'damage-photos');

create policy inspect_anon_read on storage.objects for select to anon using (bucket_id = 'inspection-photos');
create policy inspect_auth_read on storage.objects for select to authenticated using (bucket_id = 'inspection-photos');
create policy inspect_anon_insert on storage.objects for insert to anon with check (bucket_id = 'inspection-photos');
create policy inspect_auth_insert on storage.objects for insert to authenticated with check (bucket_id = 'inspection-photos');
create policy inspect_auth_update on storage.objects for update to authenticated using (bucket_id = 'inspection-photos') with check (bucket_id = 'inspection-photos');
create policy inspect_auth_delete on storage.objects for delete to authenticated using (bucket_id = 'inspection-photos');

create policy logbooks_auth_read on storage.objects for select to authenticated using (bucket_id = 'vehicle-logbooks');
create policy logbooks_auth_insert on storage.objects for insert to authenticated with check (bucket_id = 'vehicle-logbooks');
create policy logbooks_auth_update on storage.objects for update to authenticated using (bucket_id = 'vehicle-logbooks') with check (bucket_id = 'vehicle-logbooks');
create policy logbooks_auth_delete on storage.objects for delete to authenticated using (bucket_id = 'vehicle-logbooks');

-- Seed default checklist items
insert into public.checklist_items (item_text, item_order, checklist_type, is_active) values
  ('Tyres (tread, pressure, damage)', 1, 'pre_trip', true),
  ('Lights (head, brake, indicators)', 2, 'pre_trip', true),
  ('Windows & mirrors', 3, 'pre_trip', true),
  ('Wipers & washer fluid', 4, 'pre_trip', true),
  ('Body damage (exterior walk-around)', 5, 'pre_trip', true),
  ('Fluid leaks underneath', 6, 'pre_trip', true),
  ('Fuel / charge level', 7, 'pre_trip', true),
  ('Dashboard warning lights', 8, 'pre_trip', true),
  ('Brakes feel', 9, 'pre_trip', true),
  ('Horn', 10, 'pre_trip', true),
  ('Seatbelts & interior cleanliness', 11, 'pre_trip', true)
on conflict do nothing;

insert into public.checklist_items (item_text, item_order, checklist_type, is_active, item_key) values
  ('New Damage?', 1, 'return', true, 'new_damage'),
  ('Fuel Level', 2, 'return', true, 'fuel_level'),
  ('Warning Lights?', 3, 'return', true, 'warning_lights')
on conflict (item_key) do nothing;

-- Column comments
comment on column public.damage_markers.source is 'baseline = known/pre-existing damage, driver = newly reported by driver';
comment on column public.damage_markers.approved is 'For driver-reported damages: true after admin review';
comment on column public.damage_markers.rejection_reason is 'Reason if damage report was rejected';
comment on column public.vehicle_sessions.odometer_start is 'Optional odometer reading at session start (km)';
comment on column public.vehicle_sessions.odometer_end is 'Optional odometer reading at session end (km)';