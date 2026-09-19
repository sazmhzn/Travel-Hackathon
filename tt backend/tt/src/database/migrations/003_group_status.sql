-- Expedition lifecycle status (PENDING / ONGOING / COMPLETED) replaces is_active
ALTER TABLE groups
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'ONGOING', 'COMPLETED'));

ALTER TABLE groups
    DROP COLUMN IF EXISTS is_active;

-- Only one ONGOING expedition per guide.
CREATE UNIQUE INDEX IF NOT EXISTS uq_groups_one_ongoing_per_guide
    ON groups(created_by) WHERE status = 'ONGOING';

CREATE INDEX IF NOT EXISTS idx_groups_status
    ON groups(status);
