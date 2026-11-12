-- Demo data: two water-treatment plants. Contains NO users or credentials.
-- Demo users are created separately with random passwords: `pnpm --dir api seed:users`.

insert into public.plants (id, name, location_label) values
  ('11111111-1111-4111-8111-111111111111', 'North Water Treatment Plant', 'North district'),
  ('22222222-2222-4222-8222-222222222222', 'South Water Treatment Plant', 'South district');

insert into public.tanks (id, plant_id, tag, name, capacity_m3, level_pct, low_limit_pct, high_limit_pct) values
  ('a1111111-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'TK-101', 'Raw water tank', 500, 60, 5, 95),
  ('a1111111-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'TK-102', 'Treated water tank', 400, 40, 5, 95),
  ('a2222222-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'TK-201', 'Raw water tank', 650, 55, 5, 95),
  ('a2222222-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'TK-202', 'Treated water tank', 450, 35, 5, 95);

insert into public.pumps (plant_id, tag, name, source_tank_id, dest_tank_id, rated_flow_m3h) values
  ('11111111-1111-4111-8111-111111111111', 'P-101', 'Transfer pump A', 'a1111111-0000-4000-8000-000000000001', 'a1111111-0000-4000-8000-000000000002', 120),
  ('11111111-1111-4111-8111-111111111111', 'P-102', 'Transfer pump B', 'a1111111-0000-4000-8000-000000000001', 'a1111111-0000-4000-8000-000000000002', 90),
  ('22222222-2222-4222-8222-222222222222', 'P-201', 'Transfer pump A', 'a2222222-0000-4000-8000-000000000001', 'a2222222-0000-4000-8000-000000000002', 150),
  ('22222222-2222-4222-8222-222222222222', 'P-202', 'Transfer pump B', 'a2222222-0000-4000-8000-000000000001', 'a2222222-0000-4000-8000-000000000002', 110);

insert into public.valves (plant_id, tag, name, tank_id, direction, rated_flow_m3h) values
  ('11111111-1111-4111-8111-111111111111', 'XV-101', 'Raw water inlet', 'a1111111-0000-4000-8000-000000000001', 'inlet', 140),
  ('11111111-1111-4111-8111-111111111111', 'XV-102', 'Distribution outlet', 'a1111111-0000-4000-8000-000000000002', 'outlet', 100),
  ('22222222-2222-4222-8222-222222222222', 'XV-201', 'Raw water inlet', 'a2222222-0000-4000-8000-000000000001', 'inlet', 170),
  ('22222222-2222-4222-8222-222222222222', 'XV-202', 'Distribution outlet', 'a2222222-0000-4000-8000-000000000002', 'outlet', 130);

insert into public.setpoints (plant_id, tag, description, value, unit, min_value, max_value) values
  ('11111111-1111-4111-8111-111111111111', 'SP-TK102-HI', 'Treated tank auto-stop level', 90, '%', 50, 95),
  ('11111111-1111-4111-8111-111111111111', 'SP-TK102-LO', 'Treated tank auto-start level', 30, '%', 10, 60),
  ('22222222-2222-4222-8222-222222222222', 'SP-TK202-HI', 'Treated tank auto-stop level', 88, '%', 50, 95),
  ('22222222-2222-4222-8222-222222222222', 'SP-TK202-LO', 'Treated tank auto-start level', 25, '%', 10, 60);

insert into public.events (plant_id, type, message) values
  ('11111111-1111-4111-8111-111111111111', 'system.seed', 'Demo data loaded.'),
  ('22222222-2222-4222-8222-222222222222', 'system.seed', 'Demo data loaded.');
