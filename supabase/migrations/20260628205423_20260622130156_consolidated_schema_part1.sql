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