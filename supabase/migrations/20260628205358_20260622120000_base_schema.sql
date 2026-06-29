-- Fleet Guardian Base Schema
-- Core tables, types, and functions for the fleet management system

-- Enable pgcrypto for PIN hashing
create extension if not exists pgcrypto;

-- Custom types
create type damage_source as enum ('baseline', 'driver');
create type blueprint_view as enum ('front', 'rear', 'left', 'right', 'top');

-- User roles table for admin access
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin')),
  created_at timestamptz not null default now(),
  unique (user_id, role)
);
alter table public.user_roles enable row level security;

-- Drivers table
create table public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  surname text not null,
  employee_number text not null unique,
  pin_hash text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.drivers enable row level security;

-- Vehicles table
create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  make text not null,
  model text not null,
  year integer,
  vin text,
  status text not null default 'available' check (status in ('available', 'assigned', 'maintenance', 'archived')),
  archived boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.vehicles enable row level security;

-- Vehicle sessions (driver assignments)
create table public.vehicle_sessions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active' check (status in ('active', 'completed')),
  created_at timestamptz not null default now()
);
alter table public.vehicle_sessions enable row level security;

-- Inspections table
create table public.inspections (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid references public.drivers(id) on delete set null,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  session_id uuid references public.vehicle_sessions(id) on delete set null,
  inspection_type text not null check (inspection_type in ('pre_trip', 'return')),
  created_at timestamptz not null default now()
);
alter table public.inspections enable row level security;

-- Inspection items
create table public.inspection_items (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.inspections(id) on delete cascade,
  item_name text not null,
  result text not null check (result in ('pass', 'issue')),
  notes text,
  created_at timestamptz not null default now()
);
alter table public.inspection_items enable row level security;

-- Inspection item photos
create table public.inspection_item_photos (
  id uuid primary key default gen_random_uuid(),
  inspection_item_id uuid not null references public.inspection_items(id) on delete cascade,
  photo_url text not null,
  created_at timestamptz not null default now()
);
alter table public.inspection_item_photos enable row level security;

-- Damage markers
create table public.damage_markers (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  driver_id uuid references public.drivers(id) on delete set null,
  damage_type text not null,
  description text,
  status text not null default 'open' check (status in ('open', 'in_review', 'repaired', 'closed')),
  view blueprint_view not null,
  x_coordinate numeric not null,
  y_coordinate numeric not null,
  reported_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.damage_markers enable row level security;

-- Damage marker photos
create table public.damage_marker_photos (
  id uuid primary key default gen_random_uuid(),
  damage_marker_id uuid not null references public.damage_markers(id) on delete cascade,
  photo_url text not null,
  created_at timestamptz not null default now()
);
alter table public.damage_marker_photos enable row level security;

-- Vehicle blueprints (annotated vehicle images)
create table public.vehicle_blueprints (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  blueprint_image text not null,
  view blueprint_view not null,
  created_at timestamptz not null default now(),
  unique (vehicle_id, view)
);
alter table public.vehicle_blueprints enable row level security;

-- Vehicle base photos (reference photos for damage comparison)
create table public.vehicle_base_photos (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  photo_url text not null,
  created_at timestamptz not null default now()
);
alter table public.vehicle_base_photos enable row level security;

-- Indexes for performance
create index idx_sessions_driver on public.vehicle_sessions(driver_id);
create index idx_sessions_vehicle on public.vehicle_sessions(vehicle_id);
create index idx_damage_markers_vehicle on public.damage_markers(vehicle_id);
create index idx_damage_markers_driver on public.damage_markers(driver_id);
create index idx_damage_photos_marker on public.damage_marker_photos(damage_marker_id);
create index idx_inspection_items_inspection on public.inspection_items(inspection_id);
create index idx_inspection_item_photos_item on public.inspection_item_photos(inspection_item_id);
create index idx_base_photos_vehicle on public.vehicle_base_photos(vehicle_id);

-- Grant privileges
grant select on public.vehicle_blueprints to anon, authenticated;
grant select on public.vehicle_base_photos to anon, authenticated;
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

-- Anonymous (driver) grants
grant select on public.vehicles to anon;
grant select, insert on public.vehicle_sessions to anon;
grant select, insert on public.inspections to anon;
grant select, insert on public.inspection_items to anon;
grant select, insert on public.inspection_item_photos to anon;
grant select, insert on public.damage_markers to anon;
grant select, insert on public.damage_marker_photos to anon;

-- Helper function: has_role (for admin checks)
create or replace function public.has_role(_user_id uuid, _role text)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role);
$$;
grant execute on function public.has_role(uuid, text) to authenticated;

-- Helper function: verify_driver_pin (for driver auth)
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
    and d.pin_hash = crypt(p_pin, d.pin_hash);
end;
$$;
grant execute on function public.verify_driver_pin(text, text) to anon;

-- Helper function: set_driver_pin (for admin to reset driver PINs)
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
  set pin_hash = crypt(p_pin, gen_salt('bf'))
  where id = p_driver_id;
end;
$$;
grant execute on function public.set_driver_pin(uuid, text) to authenticated;

-- Helper function: create_driver (for admin to create new drivers with PIN)
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
  values (p_name, p_surname, p_employee_number, crypt(p_pin, gen_salt('bf')))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.create_driver(text, text, text, text) to authenticated;