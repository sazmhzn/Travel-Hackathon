-- Enable PostGIS Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'MEMBER' CHECK (role IN ('GUIDE', 'MEMBER', 'ADMIN')),
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 2. Groups Table
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    invite_code VARCHAR(16) UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON groups(invite_code);

-- 3. Group Members Table
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'MEMBER' CHECK (role IN ('GUIDE', 'MEMBER')),
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_group_member UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);

-- 4. Travel Plans Table (LineString 4326)
CREATE TABLE IF NOT EXISTS travel_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    route GEOMETRY(LineString, 4326) NOT NULL,
    bounding_box GEOMETRY(Polygon, 4326),
    total_distance_meters DOUBLE PRECISION DEFAULT 0.0,
    elevation_gain DOUBLE PRECISION DEFAULT 0.0,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial Indices for Travel Plans
CREATE INDEX IF NOT EXISTS idx_travel_plans_route ON travel_plans USING GIST (route);
CREATE INDEX IF NOT EXISTS idx_travel_plans_bbox ON travel_plans USING GIST (bounding_box);
CREATE INDEX IF NOT EXISTS idx_travel_plans_group ON travel_plans(group_id);

-- 5. Activities & Media Markers Table (Point 4326)
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    visibility VARCHAR(50) DEFAULT 'PUBLIC' CHECK (visibility IN ('PUBLIC', 'GROUP_ONLY')),
    location GEOMETRY(Point, 4326) NOT NULL,
    media_urls TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial Index for Activities
CREATE INDEX IF NOT EXISTS idx_activities_location ON activities USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_activities_visibility ON activities(visibility);

-- 6. Location History Table (Telemetry Batches & Mesh Relays)
CREATE TABLE IF NOT EXISTS location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    location GEOMETRY(Point, 4326) NOT NULL,
    altitude DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    battery_level INTEGER,
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial & Composite Indices for Telemetry
CREATE INDEX IF NOT EXISTS idx_location_history_location ON location_history USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_location_history_user_time ON location_history(user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_history_group_time ON location_history(group_id, recorded_at DESC);

-- 7. Emergency Distress Triggers Table
CREATE TABLE IF NOT EXISTS emergency_triggers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    location GEOMETRY(Point, 4326) NOT NULL,
    battery_level INTEGER,
    reason TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RESOLVED', 'CANCELLED')),
    telegram_message_id TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_emergency_triggers_status ON emergency_triggers(status);
CREATE INDEX IF NOT EXISTS idx_emergency_triggers_group ON emergency_triggers(group_id);
CREATE INDEX IF NOT EXISTS idx_emergency_triggers_location ON emergency_triggers USING GIST (location);
