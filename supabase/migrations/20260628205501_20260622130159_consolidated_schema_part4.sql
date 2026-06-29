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