CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- STATIONS — train stations, bus stops, bike docks
-- ============================================================
CREATE TABLE stations (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('train', 'bus_stop', 'bike_dock')),
  geom GEOGRAPHY(POINT, 4326) NOT NULL,
  line VARCHAR(50)                  -- e.g. 'Western Line'; NULL for bus/bike
);

CREATE INDEX idx_stations_geom ON stations USING GIST (geom);
CREATE INDEX idx_stations_type ON stations (type);

-- ============================================================
-- EDGES — connections between stations (train/bus/bike/walk legs)
-- ============================================================
CREATE TABLE edges (
  id SERIAL PRIMARY KEY,
  from_station_id INT NOT NULL REFERENCES stations(id),
  to_station_id INT NOT NULL REFERENCES stations(id),
  mode VARCHAR(20) NOT NULL CHECK (mode IN ('train', 'bus', 'bike', 'walk')),
  base_duration_seconds INT NOT NULL CHECK (base_duration_seconds > 0),
  distance_meters FLOAT,
  geom GEOGRAPHY(LINESTRING, 4326)  -- optional, for map rendering in Flutter
);

CREATE INDEX idx_edges_geom ON edges USING GIST (geom);
CREATE INDEX idx_edges_from ON edges (from_station_id);
CREATE INDEX idx_edges_to ON edges (to_station_id);
CREATE INDEX idx_edges_mode ON edges (mode);

-- ============================================================
-- SCHEDULES — frequency data per edge
-- ============================================================
CREATE TABLE schedules (
  id SERIAL PRIMARY KEY,
  edge_id INT NOT NULL REFERENCES edges(id),
  departure_time TIME NOT NULL,
  frequency_minutes INT NOT NULL CHECK (frequency_minutes > 0)
);

CREATE INDEX idx_schedules_edge ON schedules (edge_id);

-- ============================================================
-- CROWD DENSITY — synthetic, time-of-day-aware
-- ============================================================
CREATE TABLE crowd_density (
  id SERIAL PRIMARY KEY,
  station_id INT REFERENCES stations(id),
  edge_id INT REFERENCES edges(id),         -- nullable; density can be per-edge or per-station
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  density_score FLOAT NOT NULL CHECK (density_score >= 0.0 AND density_score <= 1.0),
  source VARCHAR(20) NOT NULL DEFAULT 'simulated',
  CONSTRAINT crowd_density_has_target CHECK (station_id IS NOT NULL OR edge_id IS NOT NULL)
);

CREATE INDEX idx_crowd_density_station ON crowd_density (station_id);
CREATE INDEX idx_crowd_density_edge ON crowd_density (edge_id);
CREATE INDEX idx_crowd_density_timestamp ON crowd_density (timestamp);

-- ============================================================
-- BIKE AVAILABILITY — simulated Yulu-style dock data
-- ============================================================
CREATE TABLE bike_availability (
  id SERIAL PRIMARY KEY,
  dock_station_id INT NOT NULL REFERENCES stations(id),
  bikes_available INT NOT NULL CHECK (bikes_available >= 0),
  docks_total INT NOT NULL CHECK (docks_total >= 0 AND bikes_available <= docks_total),
  timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bike_availability_station ON bike_availability (dock_station_id);
CREATE INDEX idx_bike_availability_timestamp ON bike_availability (timestamp);
