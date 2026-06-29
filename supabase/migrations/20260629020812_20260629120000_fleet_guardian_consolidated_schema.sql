-- ============================================================
-- Fleet Guardian — Complete Consolidated Schema
-- Creates all tables, types, functions, views, triggers,
-- storage buckets, and seed data required by the application.
-- RLS is ENABLED on every table but NO policies are defined here
-- (policy definitions are intentionally left untouched).
-- ============================================================

-- pgcrypto provides crypt() / gen_salt() for PIN hashing
create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- Custom enum types
-- ------------------------------------------------------------
-- blueprint_view: vehicle blueprint angles. Matches the frontend
-- BlueprintView union ("front" | "rear" | "left" | "right" | "roof" | "interior").
-- NOTE: the original base schema used 'top'; the frontend uses 'roof' and 'interior',
-- so this enum must include those labels or inserts from the UI will fail.
do $$ begin
  drop type if exists public.blueprint_view cascade;
  create type public.blueprint_view as enum ('front', 'rear', 'left', 'right', 'roof', 'interior');
exception when others then
  -- If drop cascade fails (e.g. type missing), try create directly
  create type public.blueprint_view as enum ('front', 'rear', 'left', 'right', 'roof', 'interior');
end $$;

-- damage_source: who reported the damage
do $$ begin
  drop type if exists public.damage_source cascade;
  create type public.damage_source as enum ('baseline', 'driver');
exception when others then
  create type public.damage_source as enum ('baseline', 'driver');
end $$;

-- ------------------------------------------------------------
-- user_roles: maps Supabase Auth users to application roles
-- ------------------------------------------------------------
create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin')),
  created_at timestamptz not null default now(),
  unique (user_id, role)
);
alter table public.user_roles enable row level security;

-- ------------------------------------------------------------
-- drivers: PIN-authenticated driver accounts
-- ------------------------------------------------------------
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  surname text not null,
  employee_number text not null unique,
  pin_hash text,  -- bcrypt hash via pgcrypto; null until PIN set
  active boolean not null default true,
  mobile text,
  licence_number text,
  licence_type text check (licence_type in ('local', 'international')),
  licence_category text,
  cpc_valid boolean not null default false,
  cpc_expiry_date date,
  created_at timestamptz not null default now()
);
alter table public.drivers enable row level security;

-- ------------------------------------------------------------
-- vehicles: fleet vehicles
-- ------------------------------------------------------------
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  make text not null,
  model text not null,
  year integer,
  vin text,
  status text not null default 'available' check (status in ('available', 'assigned', 'maintenance', 'archived')),
  archived boolean not null default false,
  road_licence_date date,
  road_licence_due date,
  last_service_date date,
  service_due_date date,
  created_at timestamptz not null default now()
);
alter table public.vehicles enable row level security;

-- ------------------------------------------------------------
-- vehicle_sessions: driver<->vehicle assignments with odometer
-- ------------------------------------------------------------
create table if not exists public.vehicle_sessions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active' check (status in ('active', 'completed')),
  odometer_start numeric,  -- km reading at session start (optional)
  odometer_end numeric,    -- km reading at session end (optional)
  created_at timestamptz not null default now()
);
alter table public.vehicle_sessions enable row level security;

-- ------------------------------------------------------------
-- inspections: pre-trip / return checklist headers
-- ------------------------------------------------------------
create table if not exists public.inspections (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid references public.drivers(id) on delete set null,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  session_id uuid references public.vehicle_sessions(id) on delete set null,
  inspection_type text not null check (inspection_type in ('pre_trip', 'return')),
  items_pass_count integer not null default 0,  -- maintained by trigger
  items_issue_count integer not null default 0, -- maintained by trigger
  created_at timestamptz not null default now()
);
alter table public.inspections enable row level security;

-- ------------------------------------------------------------
-- inspection_items: individual checklist line items
-- ------------------------------------------------------------
create table if not exists public.inspection_items (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.inspections(id) on delete cascade,
  item_name text not null,
  result text not null check (result in ('pass', 'issue')),
  notes text,
  created_at timestamptz not null default now()
);
alter table public.inspection_items enable row level security;

-- ------------------------------------------------------------
-- inspection_item_photos: photos attached to checklist items
-- ------------------------------------------------------------
create table if not exists public.inspection_item_photos (
  id uuid primary key default gen_random_uuid(),
  inspection_item_id uuid not null references public.inspection_items(id) on delete cascade,
  photo_url text not null,  -- storage path in inspection-photos bucket
  created_at timestamptz not null default now()
);
alter table public.inspection_item_photos enable row level security;

-- ------------------------------------------------------------
-- damage_markers: damage locations on vehicle blueprints
-- source: 'baseline' (admin-known) or 'driver' (newly reported)
-- approved: for driver-reported damage, true after admin review
-- ------------------------------------------------------------
create table if not exists public.damage_markers (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  driver_id uuid references public.drivers(id) on delete set null,
  damage_type text not null,
  description text,
  status text not null default 'open' check (status in ('open', 'in_review', 'repaired', 'closed')),
  view public.blueprint_view not null,
  x_coordinate numeric not null,  -- percentage 0-100
  y_coordinate numeric not null,  -- percentage 0-100
  source public.damage_source not null default 'driver',
  approved boolean not null default false,
  approved_at timestamptz,
  approved_by uuid references auth.users(id),
  rejection_reason text,
  session_id uuid references public.vehicle_sessions(id) on delete set null,
  reported_during text check (reported_during in ('pre_trip', 'return')),
  reported_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.damage_markers enable row level security;

-- ------------------------------------------------------------
-- damage_marker_photos: photos of damage
-- approved: for driver-reported damage photos, true after admin review
-- ------------------------------------------------------------
create table if not exists public.damage_marker_photos (
  id uuid primary key default gen_random_uuid(),
  damage_marker_id uuid not null references public.damage_markers(id) on delete cascade,
  photo_url text not null,  -- storage path in damage-photos bucket
  approved boolean not null default false,
  approved_at timestamptz,
  approved_by uuid references auth.users(id),
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.damage_marker_photos enable row level security;

-- ------------------------------------------------------------
-- vehicle_blueprints: one annotated image per view per vehicle
-- ------------------------------------------------------------
create table if not exists public.vehicle_blueprints (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  blueprint_image text not null,  -- storage path in vehicle-blueprints bucket
  view public.blueprint_view not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id, view)
);
alter table public.vehicle_blueprints enable row level security;

-- ------------------------------------------------------------
-- vehicle_base_photos: reference photos for damage comparison
-- ------------------------------------------------------------
create table if not exists public.vehicle_base_photos (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  photo_url text not null,  -- storage path in vehicle-base-photos bucket
  view public.blueprint_view,
  label text,
  created_at timestamptz not null default now()
);
alter table public.vehicle_base_photos enable row level security;

-- ------------------------------------------------------------
-- damage_marker_base_photos: junction table linking damage markers
-- to the base photos that document them (many-to-many)
-- ------------------------------------------------------------
create table if not exists public.damage_marker_base_photos (
  id uuid primary key default gen_random_uuid(),
  damage_marker_id uuid not null references public.damage_markers(id) on delete cascade,
  base_photo_id uuid not null references public.vehicle_base_photos(id) on delete cascade,
  unique (damage_marker_id, base_photo_id)
);
alter table public.damage_marker_base_photos enable row level security;

-- ------------------------------------------------------------
-- checklist_items: global checklist configuration (master list)
-- item_key: optional stable key for special items (e.g. 'new_damage',
--           'fuel_level', 'warning_lights') used by the return flow
-- ------------------------------------------------------------
create table if not exists public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  item_text text not null,
  item_order int not null default 0,
  is_active boolean not null default true,
  checklist_type text not null default 'pre_trip' check (checklist_type in ('pre_trip', 'return')),
  item_key text unique,
  created_at timestamptz not null default now()
);
alter table public.checklist_items enable row level security;

-- ------------------------------------------------------------
-- vehicle_checklist_items: per-vehicle checklist overrides
-- (enabled flag toggles a master item for a specific vehicle)
-- ------------------------------------------------------------
create table if not exists public.vehicle_checklist_items (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checklist_item_id uuid not null references public.checklist_items(id) on delete cascade,
  enabled boolean not null default true,
  unique (vehicle_id, checklist_item_id)
);
alter table public.vehicle_checklist_items enable row level security;

-- ------------------------------------------------------------
-- vehicle_logbooks: uploaded logbook files (private bucket)
-- ------------------------------------------------------------
create table if not exists public.vehicle_logbooks (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  file_path text not null,  -- storage path in vehicle-logbooks bucket
  file_name text not null,
  uploaded_at timestamptz not null default now()
);
alter table public.vehicle_logbooks enable row level security;

-- ------------------------------------------------------------
-- vehicle_repairs: repair / maintenance history per vehicle
-- ------------------------------------------------------------
create table if not exists public.vehicle_repairs (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  repair_date date not null,
  description text not null,
  cost numeric(10, 2),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.vehicle_repairs enable row level security;

-- ------------------------------------------------------------
-- Indexes for query performance
-- ------------------------------------------------------------
create index if not exists idx_sessions_driver on public.vehicle_sessions(driver_id);
create index if not exists idx_sessions_vehicle on public.vehicle_sessions(vehicle_id);
create index if not exists idx_dmbp_marker on public.damage_marker_base_photos(damage_marker_id);
create index if not exists idx_dmbp_base on public.damage_marker_base_photos(base_photo_id);
create index if not exists idx_damages_pending_approval on public.damage_markers(source, approved, status) where source = 'driver' and approved = false;
create index if not exists idx_damages_admin_list on public.damage_markers(reported_at desc);
create index if not exists idx_damage_photos_marker on public.damage_marker_photos(damage_marker_id);
create index if not exists idx_checklist_items_order on public.checklist_items(item_order);
create index if not exists idx_checklist_items_type on public.checklist_items(checklist_type);
create index if not exists idx_vehicle_checklist_vehicle on public.vehicle_checklist_items(vehicle_id);
create index if not exists idx_vehicle_checklist_item on public.vehicle_checklist_items(checklist_item_id);
create index if not exists idx_damage_markers_vehicle on public.damage_markers(vehicle_id);
create index if not exists idx_damage_markers_driver on public.damage_markers(driver_id);
create index if not exists idx_damage_markers_session on public.damage_markers(session_id);
create index if not exists idx_damage_markers_reported_during on public.damage_markers(reported_during);
create index if not exists idx_inspection_items_inspection on public.inspection_items(inspection_id);
create index if not exists idx_inspection_item_photos_item on public.inspection_item_photos(inspection_item_id);
create index if not exists idx_base_photos_vehicle on public.vehicle_base_photos(vehicle_id);
create index if not exists idx_inspections_session on public.inspections(session_id);
create index if not exists idx_inspections_vehicle on public.inspections(vehicle_id);
create index if not exists idx_inspections_driver on public.inspections(driver_id);
create index if not exists idx_logbooks_vehicle on public.vehicle_logbooks(vehicle_id);
create index if not exists idx_repairs_vehicle on public.vehicle_repairs(vehicle_id);

-- ------------------------------------------------------------
-- Grants
-- Admin (authenticated) gets full CRUD on all tables
-- Anon (driver using anon key) gets limited read/insert
-- ------------------------------------------------------------
grant select, insert, update, delete on public.user_roles to authenticated;
grant select, insert, update, delete on public.drivers to authenticated;
grant select, insert, update, delete on public.vehicles to authenticated;
grant select, insert, update, delete on public.vehicle_sessions to authenticated;
grant select, insert, update, delete on public.inspections to authenticated;
grant select, insert, update, delete on public.inspection_items to authenticated;
grant select, insert, update, delete on public.inspection_item_photos to authenticated;
grant select, insert, update, delete on public.damage_markers to authenticated;
grant select, insert, update, delete on public.damage_marker_photos to authenticated;
grant select, insert, update, delete on public.vehicle_blueprints to authenticated;
grant select, insert, update, delete on public.vehicle_base_photos to authenticated;
grant select, insert, update, delete on public.damage_marker_base_photos to authenticated;
grant select, insert, update, delete on public.checklist_items to authenticated;
grant select, insert, update, delete on public.vehicle_checklist_items to authenticated;
grant select, insert, update, delete on public.vehicle_logbooks to authenticated;
grant select, insert, update, delete on public.vehicle_repairs to authenticated;

-- Anon (driver) grants
grant select on public.vehicles to anon;
grant select on public.vehicle_blueprints to anon;
grant select on public.vehicle_base_photos to anon;
grant select on public.damage_marker_base_photos to anon;
grant select, insert on public.vehicle_sessions to anon;
grant select, insert on public.inspections to anon;
grant select, insert on public.inspection_items to anon;
grant select, insert on public.inspection_item_photos to anon;
grant select, insert on public.damage_markers to anon;
grant select, insert on public.damage_marker_photos to anon;
grant select on public.checklist_items to anon;
grant select on public.vehicle_checklist_items to anon;

-- ------------------------------------------------------------
-- RPC functions (security definer; schema-qualified pgcrypto calls)
-- ------------------------------------------------------------

-- has_role: check if a Supabase Auth user has a given app role
create or replace function public.has_role(_user_id uuid, _role text)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role);
$$;
grant execute on function public.has_role(uuid, text) to authenticated;

-- verify_driver_pin: driver PIN authentication (anon)
create or replace function public.verify_driver_pin(p_employee_number text, p_pin text)
returns table (driver_id uuid, employee_number text, name text, surname text)
language plpgsql security definer set search_path = public as $$
begin
  return query
  select d.id, d.employee_number, d.name, d.surname
  from public.drivers d
  where d.employee_number = p_employee_number
    and d.active = true
    and d.pin_hash is not null
    and d.pin_hash = extensions.crypt(p_pin, d.pin_hash);
end;
$$;
grant execute on function public.verify_driver_pin(text, text) to anon;

-- set_driver_pin: admin resets a driver's PIN
create or replace function public.set_driver_pin(p_driver_id uuid, p_pin text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if length(p_pin) < 4 or length(p_pin) > 6 then
    raise exception 'PIN must be 4-6 digits';
  end if;
  if not p_pin ~ '^\d+$' then
    raise exception 'PIN must contain only digits';
  end if;
  update public.drivers
  set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf'))
  where id = p_driver_id;
end;
$$;
grant execute on function public.set_driver_pin(uuid, text) to authenticated;

-- create_driver: admin creates a new driver with hashed PIN
create or replace function public.create_driver(
  p_name text,
  p_surname text,
  p_employee_number text,
  p_pin text
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if length(p_pin) < 4 or length(p_pin) > 6 then
    raise exception 'PIN must be 4-6 digits';
  end if;
  if not p_pin ~ '^\d+$' then
    raise exception 'PIN must contain only digits';
  end if;
  insert into public.drivers (name, surname, employee_number, pin_hash)
  values (p_name, p_surname, p_employee_number, extensions.crypt(p_pin, extensions.gen_salt('bf')))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.create_driver(text, text, text, text) to authenticated;

-- start_vehicle_session: begin a driver<->vehicle assignment
-- closes any stale active sessions for the driver, backfills marker
-- session_ids, and triggers vehicle status -> 'assigned'
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

-- complete_vehicle_session: end a vehicle session (trigger sets vehicle available)
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

-- get_vehicle_checklist: returns all active checklist items for a
-- vehicle/type with per-vehicle enabled flag (admin view)
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
  from public.checklist_items ci
  left join public.vehicle_checklist_items vci
    on vci.checklist_item_id = ci.id and vci.vehicle_id = p_vehicle_id
  where ci.is_active = true
    and ci.checklist_type = p_type
  order by ci.item_order;
$$;
grant execute on function public.get_vehicle_checklist(uuid, text) to anon, authenticated;

-- get_vehicle_enabled_checklist: returns only enabled items for a
-- vehicle/type (driver view). If no per-vehicle overrides exist, all
-- active items are returned.
create or replace function public.get_vehicle_enabled_checklist(p_vehicle_id uuid, p_type text default 'pre_trip')
returns table (
  item_id uuid,
  item_text text,
  item_order int,
  item_key text
)
language sql stable security definer set search_path = public as $$
  select ci.id, ci.item_text, ci.item_order, ci.item_key
  from public.checklist_items ci
  where ci.is_active = true
    and ci.checklist_type = p_type
    and (
      not exists (select 1 from public.vehicle_checklist_items where vehicle_id = p_vehicle_id)
      or exists (
        select 1 from public.vehicle_checklist_items vci
        where vci.vehicle_id = p_vehicle_id
          and vci.checklist_item_id = ci.id
          and vci.enabled = true
      )
      or not exists (
        select 1 from public.vehicle_checklist_items vci
        where vci.vehicle_id = p_vehicle_id
          and vci.checklist_item_id = ci.id
      )
    )
  order by ci.item_order;
$$;
grant execute on function public.get_vehicle_enabled_checklist(uuid, text) to anon, authenticated;

-- ------------------------------------------------------------
-- Triggers
-- ------------------------------------------------------------

-- sync_inspection_counts: keep inspections.items_pass_count /
-- items_issue_count in sync with child inspection_items rows
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

-- trg_session_manage_vehicle: when a session starts, mark the vehicle
-- 'assigned' and close any stale active session for the same driver;
-- when a session completes, mark the vehicle 'available'
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

-- ------------------------------------------------------------
-- vehicle_summary view: aggregated vehicle stats for admin lists
-- Columns must match what the frontend selects (Vehicles/List,
-- Vehicles/Detail, Dashboard, Reports).
-- ------------------------------------------------------------
create or replace view public.vehicle_summary as
with session_stats as (
  select
    vehicle_id,
    count(*) as total_sessions,
    max(started_at) as last_used_at,
    sum(case when ended_at is not null
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

-- ------------------------------------------------------------
-- Storage buckets
-- (policies on storage.objects are intentionally left untouched)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- Seed: default checklist items
-- Pre-trip items (no item_key — generic pass/issue items)
-- ------------------------------------------------------------
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

-- Return items with special keys (frontend branches on these)
insert into public.checklist_items (item_text, item_order, checklist_type, is_active, item_key) values
  ('New Damage?', 1, 'return', true, 'new_damage'),
  ('Fuel Level', 2, 'return', true, 'fuel_level'),
  ('Warning Lights?', 3, 'return', true, 'warning_lights')
on conflict (item_key) do nothing;

-- ------------------------------------------------------------
-- Column comments (documentation)
-- ------------------------------------------------------------
comment on column public.damage_markers.source is 'baseline = known/pre-existing damage, driver = newly reported by driver';
comment on column public.damage_markers.approved is 'For driver-reported damages: true after admin review';
comment on column public.damage_markers.rejection_reason is 'Reason if damage report was rejected';
comment on column public.vehicle_sessions.odometer_start is 'Optional odometer reading at session start (km)';
comment on column public.vehicle_sessions.odometer_end is 'Optional odometer reading at session end (km)';
comment on column public.damage_marker_photos.approved is 'For driver-reported damage photos: true after admin review';
comment on column public.checklist_items.item_key is 'Stable key for special items (new_damage, fuel_level, warning_lights)';
comment on view public.vehicle_summary is 'Aggregated vehicle stats: sessions, damages, last inspection';
