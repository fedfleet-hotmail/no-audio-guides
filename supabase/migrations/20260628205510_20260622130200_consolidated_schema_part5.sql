-- Seed default checklist items
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

insert into public.checklist_items (item_text, item_order, checklist_type, is_active, item_key) values
  ('New Damage?', 1, 'return', true, 'new_damage'),
  ('Fuel Level', 2, 'return', true, 'fuel_level'),
  ('Warning Lights?', 3, 'return', true, 'warning_lights')
on conflict (item_key) do nothing;

-- Column comments
comment on column public.damage_markers.source is 'baseline = known/pre-existing damage, driver = newly reported by driver';
comment on column public.damage_markers.approved is 'For driver-reported damages: true after admin review';
comment on column public.damage_markers.rejection_reason is 'Reason if damage report was rejected';
comment on column public.vehicle_sessions.odometer_start is 'Optional odometer reading at session start (km)';
comment on column public.vehicle_sessions.odometer_end is 'Optional odometer reading at session end (km)';