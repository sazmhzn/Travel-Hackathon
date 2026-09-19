-- Group lifecycle status for guide-managed expeditions
ALTER TABLE groups
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_groups_created_by_active
    ON groups(created_by, is_active);
