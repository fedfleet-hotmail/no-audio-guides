-- Disable Row Level Security on all Fleet Guardian tables
-- RLS was enabled without policies, blocking all access (default deny)

alter table public.user_roles disable row level security;
alter table public.drivers disable row level security;
alter table public.vehicles disable row level security;
alter table public.vehicle_sessions disable row level security;
alter table public.inspections disable row level security;
alter table public.inspection_items disable row level security;
alter table public.inspection_item_photos disable row level security;
alter table public.damage_markers disable row level security;
alter table public.damage_marker_photos disable row level security;
alter table public.vehicle_blueprints disable row level security;
alter table public.vehicle_base_photos disable row level security;
alter table public.damage_marker_base_photos disable row level security;
alter table public.checklist_items disable row level security;
alter table public.vehicle_checklist_items disable row level security;
alter table public.vehicle_logbooks disable row level security;
alter table public.vehicle_repairs disable row level security;
