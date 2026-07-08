-- Add damage_marker_id and status columns to vehicle_repairs for the
-- Repairs & Maintenance workflow integration.

-- damage_marker_id: nullable FK linking a repair to the damage that triggered it.
alter table public.vehicle_repairs
  add column if not exists damage_marker_id uuid references public.damage_markers(id) on delete set null;

-- status: repair lifecycle — being_repaired (default) or repaired.
-- The existing 'resolved' boolean is kept for backwards compatibility; the
-- trigger below keeps it in sync with the new status column.
alter table public.vehicle_repairs
  add column if not exists status text not null default 'being_repaired'
  check (status in ('being_repaired', 'repaired'));

-- Sync the legacy 'resolved' boolean whenever status changes.
create or replace function public.sync_vehicle_repair_resolved()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.resolved := (new.status = 'repaired');
  return new;
end;
$$;

drop trigger if exists trg_sync_vehicle_repair_resolved on public.vehicle_repairs;
create trigger trg_sync_vehicle_repair_resolved
  before insert or update of status on public.vehicle_repairs
  for each row
  execute function public.sync_vehicle_repair_resolved();

-- Migrate any existing rows: resolved=true → status='repaired'.
update public.vehicle_repairs
  set status = 'repaired'
  where resolved = true and status = 'being_repaired';

-- Index for looking up a repair by its linked damage marker.
create index if not exists idx_vehicle_repairs_damage_marker
  on public.vehicle_repairs(damage_marker_id);
