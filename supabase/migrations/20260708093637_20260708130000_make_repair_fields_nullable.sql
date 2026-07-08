-- Auto-created repair records (on damage approval) only set
-- damage_marker_id, vehicle_id, and status.  Make the remaining
-- editable fields nullable so the insert succeeds.
ALTER TABLE vehicle_repairs ALTER COLUMN repair_date DROP NOT NULL;
ALTER TABLE vehicle_repairs ALTER COLUMN description DROP NOT NULL;
