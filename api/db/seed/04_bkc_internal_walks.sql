WITH edge_data (from_name, to_name, mode, duration_s, distance_m) AS (
  VALUES
    ('BKC Bike Dock (Central)', 'BKC Bus Stop (RBI, SW)', 'walk', 620, 820),
    ('BKC Bus Stop (RBI, SW)', 'BKC Bike Dock (Central)', 'walk', 620, 820),
    ('BKC Bike Dock (Central)', 'BKC Bus Stop (Diamond Bourse, NE)', 'walk', 620, 820),
    ('BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)', 'walk', 620, 820)
)
INSERT INTO edges (from_station_id, to_station_id, mode, base_duration_seconds, distance_meters, geom)
SELECT s1.id, s2.id, e.mode, e.duration_s, e.distance_m,
       ST_MakeLine(s1.geom::geometry, s2.geom::geometry)::geography
FROM edge_data e
JOIN stations s1 ON s1.name = e.from_name
JOIN stations s2 ON s2.name = e.to_name;
