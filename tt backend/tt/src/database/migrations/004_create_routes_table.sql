-- Enable PostGIS & UUID Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Routes Table for Guide Spatial Path Ingestion
CREATE TABLE IF NOT EXISTS routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guide_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    visibility VARCHAR(50) DEFAULT 'public' CHECK (visibility IN ('public', 'private', 'group')),
    path GEOMETRY(LineString, 4326) NOT NULL,
    bounding_box GEOMETRY(Polygon, 4326),
    total_distance_meters DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial & Filter Indices
CREATE INDEX IF NOT EXISTS idx_routes_path ON routes USING GIST (path);
CREATE INDEX IF NOT EXISTS idx_routes_bounding_box ON routes USING GIST (bounding_box);
CREATE INDEX IF NOT EXISTS idx_routes_guide_id ON routes(guide_id);
CREATE INDEX IF NOT EXISTS idx_routes_visibility ON routes(visibility);
