WITH profile_bands (profile, departure_time, frequency_minutes) AS (
  VALUES
    ('frequent_trunk', '00:00'::time, 8),
    ('frequent_trunk', '08:00'::time, 4),
    ('frequent_trunk', '10:00'::time, 8),
    ('frequent_trunk', '18:00'::time, 4),
    ('frequent_trunk', '20:00'::time, 8),

    ('bus_corridor', '00:00'::time, 20),
    ('bus_corridor', '08:00'::time, 10),
    ('bus_corridor', '10:00'::time, 20),
    ('bus_corridor', '18:00'::time, 10),
    ('bus_corridor', '20:00'::time, 20),

    ('sparse_harbour', '00:00'::time, 150)
),
edge_profiles (from_name, to_name, profile) AS (
  VALUES
    ('Andheri', 'Bandra', 'frequent_trunk'),
    ('Bandra', 'Andheri', 'frequent_trunk'),
    ('Andheri', 'Dadar (Western)', 'frequent_trunk'),
    ('Dadar (Western)', 'Andheri', 'frequent_trunk'),
    ('Dadar (Central)', 'Kurla', 'frequent_trunk'),
    ('Kurla', 'Dadar (Central)', 'frequent_trunk'),

    ('Andheri', 'Kurla', 'sparse_harbour'),
    ('Kurla', 'Andheri', 'sparse_harbour'),

    ('Bandra Station Bus Stop', 'BKC Bus Stop (RBI, SW)', 'bus_corridor'),
    ('BKC Bus Stop (RBI, SW)', 'Bandra Station Bus Stop', 'bus_corridor'),
    ('Kurla Station Bus Stop', 'BKC Bus Stop (Diamond Bourse, NE)', 'bus_corridor'),
    ('BKC Bus Stop (Diamond Bourse, NE)', 'Kurla Station Bus Stop', 'bus_corridor')
)
INSERT INTO schedules (edge_id, departure_time, frequency_minutes)
SELECT e.id, pb.departure_time, pb.frequency_minutes
FROM edge_profiles ep
JOIN profile_bands pb ON pb.profile = ep.profile
JOIN stations s1 ON s1.name = ep.from_name
JOIN stations s2 ON s2.name = ep.to_name
JOIN edges e ON e.from_station_id = s1.id AND e.to_station_id = s2.id;
