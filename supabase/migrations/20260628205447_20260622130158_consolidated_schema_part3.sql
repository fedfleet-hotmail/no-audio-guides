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