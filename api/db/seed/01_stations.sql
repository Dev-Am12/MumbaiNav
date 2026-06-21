-- ============================================================
-- TRAIN STATIONS (real — OpenCity)
-- ============================================================
INSERT INTO stations (name, type, geom, line) VALUES
  ('Andheri', 'train', ST_SetSRID(ST_MakePoint(72.8465039707666, 19.1171747947178), 4326)::geography, 'Western Line'),
  ('Bandra',  'train', ST_SetSRID(ST_MakePoint(72.8403282370921, 19.0555892333471), 4326)::geography, 'Western Line'),
  ('Kurla',   'train', ST_SetSRID(ST_MakePoint(72.8793543303778, 19.0654774786936), 4326)::geography, 'Central Line');

-- ============================================================
-- BUS STOPS (real — OpenCity / BEST)
-- ============================================================
INSERT INTO stations (name, type, geom, line) VALUES
  ('Bandra Station Bus Stop',        'bus_stop', ST_SetSRID(ST_MakePoint(72.842047, 19.054996), 4326)::geography, NULL),
  ('Kurla Station Bus Stop',         'bus_stop', ST_SetSRID(ST_MakePoint(72.878998, 19.067222), 4326)::geography, NULL),
  ('BKC Bus Stop (RBI, SW)',         'bus_stop', ST_SetSRID(ST_MakePoint(72.853113, 19.057894), 4326)::geography, NULL),
  ('BKC Bus Stop (Diamond Bourse, NE)', 'bus_stop', ST_SetSRID(ST_MakePoint(72.865906, 19.066511), 4326)::geography, NULL);

-- ============================================================
-- BIKE DOCKS (synthetic placement)
-- ============================================================
INSERT INTO stations (name, type, geom, line) VALUES
  ('Bandra Station Bike Dock', 'bike_dock', ST_SetSRID(ST_MakePoint(72.842300, 19.055200), 4326)::geography, NULL),
  ('Kurla Station Bike Dock',  'bike_dock', ST_SetSRID(ST_MakePoint(72.879300, 19.067400), 4326)::geography, NULL),
  ('BKC Bike Dock (Central)',  'bike_dock', ST_SetSRID(ST_MakePoint(72.859500, 19.062200), 4326)::geography, NULL);
