-- Rally Routes and Tracks Schema

-- Route types
CREATE TYPE route_type AS ENUM ('rally', 'liaison', 'simple');

-- Point types for route points
CREATE TYPE point_type AS ENUM (
    'ss',           -- Stage Start
    'sf',           -- Stage Finish
    'checkpoint',   -- Must be within distance
    'waypoint',     -- Informational (good place, speed zone, gas station, etc.)
    'routing'       -- Simple point for Google Maps routing
);

-- Track sources
CREATE TYPE track_source AS ENUM ('rally', 'wikiloc', 'other');

-- ============================================
-- ROUTES (planned)
-- ============================================

CREATE TABLE routes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    route_type route_type NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE route_points (
    id SERIAL PRIMARY KEY,
    route_id INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL,
    point_type point_type NOT NULL,
    name VARCHAR(255),
    description TEXT,
    geom GEOMETRY(Point, 4326) NOT NULL,
    distance_tolerance_m INTEGER,  -- For checkpoints: must be within this distance (meters)
    speed_limit_kmh INTEGER,       -- For speed zones
    metadata JSONB,                -- Extra data (gas station name, etc.)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(route_id, sequence)
);

CREATE INDEX idx_route_points_geom ON route_points USING GIST(geom);
CREATE INDEX idx_route_points_route_id ON route_points(route_id);

-- ============================================
-- TRACKS (recorded GPS breadcrumbs)
-- ============================================

CREATE TABLE tracks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    source track_source NOT NULL DEFAULT 'other',
    source_url TEXT,               -- Wikiloc URL etc.
    vehicle_type VARCHAR(100),     -- car, motorcycle, bike, etc.
    vehicle_make VARCHAR(100),     -- Toyota, KTM, etc.
    start_number VARCHAR(20),      -- Race number
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER
    ) STORED,
    geom GEOMETRY(LineString, 4326),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tracks_geom ON tracks USING GIST(geom);

-- Track points (individual breadcrumbs with timestamps)
CREATE TABLE track_points (
    id SERIAL PRIMARY KEY,
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE,
    elevation_m DOUBLE PRECISION,
    speed_kmh DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    metadata JSONB
);

CREATE INDEX idx_track_points_geom ON track_points USING GIST(geom);
CREATE INDEX idx_track_points_track_id ON track_points(track_id);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Calculate track start/end times from points
CREATE OR REPLACE FUNCTION update_track_times()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE tracks t SET
        start_time = (SELECT MIN(recorded_at) FROM track_points WHERE track_id = t.id),
        end_time = (SELECT MAX(recorded_at) FROM track_points WHERE track_id = t.id),
        geom = (SELECT ST_MakeLine(geom ORDER BY sequence) FROM track_points WHERE track_id = t.id)
    WHERE t.id = NEW.track_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_track_times
AFTER INSERT ON track_points
FOR EACH ROW EXECUTE FUNCTION update_track_times();

-- ============================================
-- VIEWS
-- ============================================

-- Route as linestring for display
CREATE VIEW routes_linestring AS
SELECT
    r.id,
    r.name,
    r.route_type,
    ST_MakeLine(rp.geom ORDER BY rp.sequence) as geom
FROM routes r
JOIN route_points rp ON rp.route_id = r.id
GROUP BY r.id;
