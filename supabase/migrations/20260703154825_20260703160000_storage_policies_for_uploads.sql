-- Storage policies for Fleet Guardian photo/logbook uploads
-- storage.objects has RLS enabled by default; without policies all uploads are denied

-- ============================================================
-- Public buckets (vehicle-blueprints, vehicle-base-photos)
-- Read: anyone (anon + authenticated)
-- Write: authenticated only
-- ============================================================

-- vehicle-blueprints: public read, authenticated write
create policy "blueprints_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'vehicle-blueprints');

create policy "blueprints_auth_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'vehicle-blueprints');

create policy "blueprints_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'vehicle-blueprints')
  with check (bucket_id = 'vehicle-blueprints');

create policy "blueprints_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'vehicle-blueprints');

-- vehicle-base-photos: public read, authenticated write
create policy "base_photos_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'vehicle-base-photos');

create policy "base_photos_auth_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'vehicle-base-photos');

create policy "base_photos_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'vehicle-base-photos')
  with check (bucket_id = 'vehicle-base-photos');

create policy "base_photos_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'vehicle-base-photos');

-- ============================================================
-- Private buckets (damage-photos, inspection-photos, vehicle-logbooks)
-- Read: authenticated only (anon reads via edge function with signed URLs)
-- Write: anon + authenticated (drivers upload photos without auth)
-- ============================================================

-- damage-photos: authenticated read, anon + authenticated write
create policy "damage_photos_auth_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'damage-photos');

create policy "damage_photos_anon_write"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'damage-photos');

create policy "damage_photos_auth_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'damage-photos');

create policy "damage_photos_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'damage-photos')
  with check (bucket_id = 'damage-photos');

create policy "damage_photos_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'damage-photos');

-- inspection-photos: authenticated read, anon + authenticated write
create policy "inspection_photos_auth_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'inspection-photos');

create policy "inspection_photos_anon_write"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'inspection-photos');

create policy "inspection_photos_auth_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'inspection-photos');

create policy "inspection_photos_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'inspection-photos')
  with check (bucket_id = 'inspection-photos');

create policy "inspection_photos_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'inspection-photos');

-- vehicle-logbooks: authenticated read + write
create policy "logbooks_auth_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'vehicle-logbooks');

create policy "logbooks_auth_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'vehicle-logbooks');

create policy "logbooks_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'vehicle-logbooks')
  with check (bucket_id = 'vehicle-logbooks');

create policy "logbooks_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'vehicle-logbooks');
