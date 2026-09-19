-- Destinations
CREATE TABLE IF NOT EXISTS destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    normalized_name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    country VARCHAR(100),
    region VARCHAR(255),
    description TEXT,
    source JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_destinations_normalized_name UNIQUE (normalized_name)
);

-- Places
CREATE TABLE IF NOT EXISTS places (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    destination_id UUID NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    provider VARCHAR(100) NOT NULL,
    provider_place_id VARCHAR(255) NOT NULL,
    name VARCHAR(500) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('NATURE','CULTURE','FOOD','ADVENTURE','SHOPPING','LANDMARK','ACCOMMODATION','TRANSPORT')),
    location GEOMETRY(Point, 4326) NOT NULL,
    address TEXT,
    rating DOUBLE PRECISION,
    rating_count INTEGER,
    price_level INTEGER,
    opening_hours JSONB,
    website_url TEXT,
    phone VARCHAR(50),
    popularity_signal DOUBLE PRECISION,
    photos TEXT[],
    source JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_places_provider UNIQUE (provider, provider_place_id)
);

CREATE INDEX IF NOT EXISTS idx_places_location ON places USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_places_destination_id ON places(destination_id);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);

-- Destination Data Snapshots
CREATE TABLE IF NOT EXISTS destination_data_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    destination_id UUID NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    data_type VARCHAR(50) NOT NULL CHECK (data_type IN ('weather','places','routes','elevation','events','tourism','safety','transport')),
    provider VARCHAR(100) NOT NULL,
    request_params JSONB NOT NULL,
    response_data JSONB NOT NULL,
    retrieved_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_destination_data_snapshots_dest_type_retrieved ON destination_data_snapshots(destination_id, data_type, retrieved_at DESC);

-- Transport Operators
CREATE TABLE IF NOT EXISTS transport_operators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('LOCAL_BUS','TOURIST_BUS','TAXI','JEEP','SHUTTLE','BOAT','OTHER')),
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    website VARCHAR(500),
    booking_url VARCHAR(500),
    price_range VARCHAR(100),
    source JSONB,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Transport Options
CREATE TABLE IF NOT EXISTS transport_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    operator_id UUID NOT NULL REFERENCES transport_operators(id) ON DELETE CASCADE,
    origin_lat DOUBLE PRECISION,
    origin_lng DOUBLE PRECISION,
    dest_lat DOUBLE PRECISION,
    dest_lng DOUBLE PRECISION,
    origin_name VARCHAR(255),
    dest_name VARCHAR(255),
    estimated_price_npr INTEGER,
    estimated_duration_minutes INTEGER,
    estimated_distance_meters INTEGER,
    source JSONB
);

-- Destination Events
CREATE TABLE IF NOT EXISTS destination_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    destination_id UUID NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    location GEOMETRY(Point, 4326),
    url TEXT,
    category VARCHAR(100),
    source JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_destination_events_destination_id ON destination_events(destination_id);
CREATE INDEX IF NOT EXISTS idx_destination_events_location ON destination_events USING GIST (location);

-- Itinerary Generations
CREATE TABLE IF NOT EXISTS itinerary_generations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    destination_id UUID NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    request_hash VARCHAR(64) NOT NULL UNIQUE,
    request_json JSONB NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED','PROCESSING','COMPLETED','FAILED','PARTIAL')),
    model VARCHAR(100),
    prompt_version VARCHAR(50),
    source_snapshot_ids UUID[],
    result_json JSONB,
    error TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_itinerary_generations_user_id ON itinerary_generations(user_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_generations_request_hash ON itinerary_generations(request_hash);
CREATE INDEX IF NOT EXISTS idx_itinerary_generations_status ON itinerary_generations(status);

-- Itinerary Items
CREATE TABLE IF NOT EXISTS itinerary_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    generation_id UUID NOT NULL REFERENCES itinerary_generations(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    sequence INTEGER NOT NULL,
    place_id UUID REFERENCES places(id) ON DELETE SET NULL,
    title VARCHAR(500),
    description TEXT,
    start_time VARCHAR(10),
    end_time VARCHAR(10),
    duration_minutes INTEGER,
    transport_mode VARCHAR(50),
    travel_minutes INTEGER,
    reason TEXT,
    source_ids UUID[],
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_itinerary_items_generation_id ON itinerary_items(generation_id);

-- Destination Generation Jobs
CREATE TABLE IF NOT EXISTS destination_generation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    destination_id UUID REFERENCES destinations(id) ON DELETE SET NULL,
    request_hash VARCHAR(64) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED','PROCESSING','COMPLETED','FAILED')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_destination_generation_jobs_request_hash ON destination_generation_jobs(request_hash);
CREATE INDEX IF NOT EXISTS idx_destination_generation_jobs_user_id ON destination_generation_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_destination_generation_jobs_status ON destination_generation_jobs(status);
