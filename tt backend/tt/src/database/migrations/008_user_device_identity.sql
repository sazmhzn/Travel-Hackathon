-- Store each user's device identity so peers can locate a missing member over
-- Bluetooth/mesh by their specific identifier instead of searching for all.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS device_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS bluetooth_name VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);
