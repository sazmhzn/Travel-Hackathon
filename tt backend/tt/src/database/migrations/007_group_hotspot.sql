-- Store the guide's offline hotspot credentials so members can join the
-- expedition's local network when there is no internet connectivity.
ALTER TABLE groups
    ADD COLUMN IF NOT EXISTS hotspot_ssid VARCHAR(64),
    ADD COLUMN IF NOT EXISTS hotspot_password VARCHAR(64);
