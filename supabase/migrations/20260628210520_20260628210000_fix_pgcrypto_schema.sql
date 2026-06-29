-- Fix pgcrypto function calls to use schema-qualified names
-- pgcrypto is installed in the 'extensions' schema, but search_path = public excludes it

-- Update verify_driver_pin to use extensions.crypt
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

-- Update set_driver_pin to use extensions.crypt and extensions.gen_salt
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

-- Update create_driver to use extensions.crypt and extensions.gen_salt
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