-- Refactor damage_markers approval workflow to use status as the single source of truth.
-- New status values: pending_approval, approved, rejected
-- approved boolean + rejection_reason text are kept as derived fields, synced via trigger.

-- 1. Drop the old status check constraint so data can be migrated.
alter table public.damage_markers
  drop constraint if exists damage_markers_status_check;

-- 2. Migrate existing data into the new status values.
update public.damage_markers
  set status = 'approved'
  where approved = true;

update public.damage_markers
  set status = 'rejected'
  where approved = false and rejection_reason is not null;

update public.damage_markers
  set status = 'pending_approval'
  where approved = false and rejection_reason is null;

-- 3. Add the new status check constraint (after data is migrated).
alter table public.damage_markers
  add constraint damage_markers_status_check
  check (status in ('pending_approval', 'approved', 'rejected'));

-- 4. Keep approved / rejection_reason in sync whenever status changes.
create or replace function public.sync_damage_marker_approved()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' then
    new.approved := true;
    new.rejection_reason := null;
  elsif new.status = 'rejected' then
    new.approved := false;
  elsif new.status = 'pending_approval' then
    new.approved := false;
    new.rejection_reason := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_damage_marker_approved on public.damage_markers;
create trigger trg_sync_damage_marker_approved
  before insert or update of status on public.damage_markers
  for each row
  execute function public.sync_damage_marker_approved();

-- 5. Replace the pending-approval index to use status instead of approved.
drop index if exists public.idx_damages_pending_approval;
create index if not exists idx_damages_pending_approval
  on public.damage_markers(source, status)
  where source = 'driver' and status = 'pending_approval';

-- 6. Update the vehicle_summary view so open_damage_count uses the new status.
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
    count(*) filter (where status = 'approved' and (source = 'baseline' or source = 'driver')) as open_damage_count,
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

-- 7. Update comments to reflect the new model.
comment on column public.damage_markers.status is 'Approval workflow: pending_approval, approved, rejected';
comment on column public.damage_markers.approved is 'Derived from status: true when status = approved';
comment on column public.damage_markers.rejection_reason is 'Reason when status = rejected';
