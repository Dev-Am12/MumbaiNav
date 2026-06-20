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

-- ============================================================
-- DADAR — interchange stations (real, OpenCity)
-- ============================================================
INSERT INTO stations (name, type, geom, line) VALUES
  ('Dadar (Western)', 'train', ST_SetSRID(ST_MakePoint(72.8431374888969, 19.0195608762157), 4326)::geography, 'Western Line'),
  ('Dadar (Central)', 'train', ST_SetSRID(ST_MakePoint(72.843633420996, 19.0181435365389), 4326)::geography, 'Central Line');

-- ============================================================
-- EDGES — all bidirectional (inserted both directions)
-- ============================================================
WITH edge_data (from_name, to_name, mode, duration_s, distance_m) AS (
  VALUES
    -- Train: trunk lines (frequent)
    ('Andheri', 'Bandra', 'train', 780, 6900),
    ('Bandra', 'Andheri', 'train', 780, 6900),
    ('Andheri', 'Dadar (Western)', 'train', 1200, 10840),
    ('Dadar (Western)', 'Andheri', 'train', 1200, 10840),
    ('Dadar (Central)', 'Kurla', 'train', 720, 6460),
    ('Kurla', 'Dadar (Central)', 'train', 720, 6460),

    -- Train: direct Harbour Line through-service (real, infrequent)
    ('Andheri', 'Kurla', 'train', 1980, 16000),
    ('Kurla', 'Andheri', 'train', 1980, 16000),

    -- Walk: Dadar platform transfer
    ('Dadar (Western)', 'Dadar (Central)', 'walk', 360, 250),
    ('Dadar (Central)', 'Dadar (Western)', 'walk', 360, 250),

    -- Walk: last-mile at Bandra and Kurla
    ('Bandra', 'Bandra Station Bus Stop', 'walk', 180, 200),
    ('Bandra Station Bus Stop', 'Bandra', 'walk', 180, 200),
    ('Bandra', 'Bandra Station Bike Dock', 'walk', 120, 150),
    ('Bandra Station Bike Dock', 'Bandra', 'walk', 120, 150),
    ('Kurla', 'Kurla Station Bus Stop', 'walk', 180, 200),
    ('Kurla Station Bus Stop', 'Kurla', 'walk', 180, 200),
    ('Kurla', 'Kurla Station Bike Dock', 'walk', 120, 150),
    ('Kurla Station Bike Dock', 'Kurla', 'walk', 120, 150),

    -- Bus: interchange to BKC
    ('Bandra Station Bus Stop', 'BKC Bus Stop (RBI, SW)', 'bus', 450, 1200),
    ('BKC Bus Stop (RBI, SW)', 'Bandra Station Bus Stop', 'bus', 450, 1200),
    ('Kurla Station Bus Stop', 'BKC Bus Stop (Diamond Bourse, NE)', 'bus', 480, 1370),
    ('BKC Bus Stop (Diamond Bourse, NE)', 'Kurla Station Bus Stop', 'bus', 480, 1370),

    -- Bike: interchange to BKC
    ('Bandra Station Bike Dock', 'BKC Bike Dock (Central)', 'bike', 540, 1960),
    ('BKC Bike Dock (Central)', 'Bandra Station Bike Dock', 'bike', 540, 1960),
    ('Kurla Station Bike Dock', 'BKC Bike Dock (Central)', 'bike', 600, 2160),
    ('BKC Bike Dock (Central)', 'Kurla Station Bike Dock', 'bike', 600, 2160)
)
INSERT INTO edges (from_station_id, to_station_id, mode, base_duration_seconds, distance_meters, geom)
SELECT s1.id, s2.id, e.mode, e.duration_s, e.distance_m,
       ST_MakeLine(s1.geom::geometry, s2.geom::geometry)::geography
FROM edge_data e
JOIN stations s1 ON s1.name = e.from_name
JOIN stations s2 ON s2.name = e.to_name;