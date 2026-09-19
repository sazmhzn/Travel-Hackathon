-- Associate recorded routes with the expedition they were created in
ALTER TABLE routes
    ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_routes_group_id ON routes(group_id);
