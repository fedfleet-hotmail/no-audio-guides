-- ============================================================
-- Fleet Guardian — Consolidated Schema Migration
-- First: drop all existing policies, then recreate clean state
-- ============================================================

-- Drop ALL existing policies first (to avoid duplicates)
do $$ begin
  -- Admin policies
  drop policy if exists admin_all on public.user_roles;
  drop policy if exists admin_all on public.drivers;
  drop policy if exists admin_all on public.vehicles;
  drop policy if exists admin_all on public.vehicle_sessions;
  drop policy if exists admin_all on public.inspections;
  drop policy if exists admin_all on public.inspection_items;
  drop policy if exists admin_all on public.inspection_item_photos;
  drop policy if exists admin_all on public.damage_markers;
  drop policy if exists admin_all on public.damage_marker_photos;
  drop policy if exists admin_all on public.vehicle_blueprints;
  drop policy if exists admin_all on public.vehicle_base_photos;
  drop policy if exists admin_all on public.damage_marker_base_photos;
  drop policy if exists admin_all on public.checklist_items;
  drop policy if exists admin_all on public.vehicle_checklist_items;
  drop policy if exists admin_all on public.vehicle_logbooks;
  drop policy if exists admin_all on public.vehicle_repairs;
  drop policy if exists admin_all_user_roles on public.user_roles;
  drop policy if exists admin_all_drivers on public.drivers;
  drop policy if exists admin_all_vehicles on public.vehicles;
  drop policy if exists admin_all_sessions on public.vehicle_sessions;
  drop policy if exists admin_all_inspections on public.inspections;
  drop policy if exists admin_all_inspection_items on public.inspection_items;
  drop policy if exists admin_all_inspection_photos on public.inspection_item_photos;
  drop policy if exists admin_all_damage_markers on public.damage_markers;
  drop policy if exists admin_all_damage_photos on public.damage_marker_photos;
  drop policy if exists admin_all_blueprints on public.vehicle_blueprints;
  drop policy if exists admin_all_base_photos on public.vehicle_base_photos;
  drop policy if exists admin_all_dmbp on public.damage_marker_base_photos;
  drop policy if exists admin_all_checklist_items on public.checklist_items;
  drop policy if exists admin_all_vehicle_checklist on public.vehicle_checklist_items;
  drop policy if exists admin_all_logbooks on public.vehicle_logbooks;
  drop policy if exists admin_all_repairs on public.vehicle_repairs;
  drop policy if exists admin_all_checklist_templates on public.checklist_items;
  
  -- Anon policies
  drop policy if exists anon_vehicles_read on public.vehicles;
  drop policy if exists anon_vehicles_status_update on public.vehicles;
  drop policy if exists anon_blueprints_read on public.vehicle_blueprints;
  drop policy if exists anon_base_photos_read on public.vehicle_base_photos;
  drop policy if exists anon_dmbp_read on public.damage_marker_base_photos;
  drop policy if exists anon_session_rw on public.vehicle_sessions;
  drop policy if exists anon_sessions_select on public.vehicle_sessions;
  drop policy if exists anon_sessions_insert on public.vehicle_sessions;
  drop policy if exists anon_inspections_rw on public.inspections;
  drop policy if exists anon_inspections_select on public.inspections;
  drop policy if exists anon_inspections_insert on public.inspections;
  drop policy if exists anon_inspection_items_rw on public.inspection_items;
  drop policy if exists anon_inspection_items_select on public.inspection_items;
  drop policy if exists anon_inspection_items_insert on public.inspection_items;
  drop policy if exists anon_inspection_photos_rw on public.inspection_item_photos;
  drop policy if exists anon_inspection_photos_select on public.inspection_item_photos;
  drop policy if exists anon_inspection_photos_insert on public.inspection_item_photos;
  drop policy if exists anon_damage_read on public.damage_markers;
  drop policy if exists anon_damage_insert on public.damage_markers;
  drop policy if exists anon_damage_update on public.damage_markers;
  drop policy if exists anon_damage_photo_read_approved on public.damage_marker_photos;
  drop policy if exists anon_damage_photo_insert on public.damage_marker_photos;
  drop policy if exists anon_read_checklist_items on public.checklist_items;
  drop policy if exists anon_read_checklist_templates on public.checklist_items;
  drop policy if exists anon_read_vehicle_checklist on public.vehicle_checklist_items;
  
  -- Old auth policies
  drop policy if exists select_logbooks_auth on public.vehicle_logbooks;
  drop policy if exists insert_logbooks_auth on public.vehicle_logbooks;
  drop policy if exists update_logbooks_auth on public.vehicle_logbooks;
  drop policy if exists delete_logbooks_auth on public.vehicle_logbooks;
  drop policy if exists select_repairs_auth on public.vehicle_repairs;
  drop policy if exists insert_repairs_auth on public.vehicle_repairs;
  drop policy if exists update_repairs_auth on public.vehicle_repairs;
  drop policy if exists delete_repairs_auth on public.vehicle_repairs;
  drop policy if exists select_logbooks_admin on public.vehicle_logbooks;
  drop policy if exists insert_logbooks_admin on public.vehicle_logbooks;
  drop policy if exists update_logbooks_admin on public.vehicle_logbooks;
  drop policy if exists delete_logbooks_admin on public.vehicle_logbooks;
  drop policy if exists select_repairs_admin on public.vehicle_repairs;
  drop policy if exists insert_repairs_admin on public.vehicle_repairs;
  drop policy if exists update_repairs_admin on public.vehicle_repairs;
  drop policy if exists delete_repairs_admin on public.vehicle_repairs;
exception when others then null;
end $$;

-- Revoke UPDATE privileges from anon
revoke update on public.vehicles from anon;
revoke update on public.vehicle_sessions from anon;
revoke update on public.damage_markers from anon;

-- Create admin policies
create policy admin_all_user_roles on public.user_roles for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_drivers on public.drivers for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_vehicles on public.vehicles for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_sessions on public.vehicle_sessions for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_inspections on public.inspections for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_inspection_items on public.inspection_items for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_inspection_photos on public.inspection_item_photos for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_damage_markers on public.damage_markers for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_damage_photos on public.damage_marker_photos for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_blueprints on public.vehicle_blueprints for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_base_photos on public.vehicle_base_photos for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_dmbp on public.damage_marker_base_photos for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_checklist_items on public.checklist_items for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_vehicle_checklist on public.vehicle_checklist_items for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_logbooks on public.vehicle_logbooks for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy admin_all_repairs on public.vehicle_repairs for all to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));

-- Create anon (driver) policies
create policy anon_vehicles_read on public.vehicles for select to anon using (true);
create policy anon_blueprints_read on public.vehicle_blueprints for select to anon using (true);
create policy anon_base_photos_read on public.vehicle_base_photos for select to anon using (true);
create policy anon_dmbp_read on public.damage_marker_base_photos for select to anon using (true);
create policy anon_sessions_select on public.vehicle_sessions for select to anon using (true);
create policy anon_sessions_insert on public.vehicle_sessions for insert to anon with check (true);
create policy anon_inspections_select on public.inspections for select to anon using (true);
create policy anon_inspections_insert on public.inspections for insert to anon with check (true);
create policy anon_inspection_items_select on public.inspection_items for select to anon using (true);
create policy anon_inspection_items_insert on public.inspection_items for insert to anon with check (true);
create policy anon_inspection_photos_select on public.inspection_item_photos for select to anon using (true);
create policy anon_inspection_photos_insert on public.inspection_item_photos for insert to anon with check (true);
create policy anon_damage_read on public.damage_markers for select to anon using (source = 'baseline' or approved = true);
create policy anon_damage_insert on public.damage_markers for insert to anon with check (true);
create policy anon_damage_photo_read_approved on public.damage_marker_photos for select to anon using (approved = true);
create policy anon_damage_photo_insert on public.damage_marker_photos for insert to anon with check (true);
create policy anon_read_checklist_items on public.checklist_items for select to anon using (is_active = true);
create policy anon_read_vehicle_checklist on public.vehicle_checklist_items for select to anon using (enabled = true);