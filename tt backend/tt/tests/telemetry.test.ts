import { describe, it, expect } from 'vitest';
import { TelemetryService } from '../src/modules/telemetry/telemetry.service.js';

describe('TelemetryService Integration', () => {
  it('should ingest live telemetry and retrieve member location from cache', async () => {
    const groupId = `test-group-${Date.now()}`;
    const userId = `user-${Date.now()}`;

    await TelemetryService.ingestLiveLocation({
      userId,
      groupId,
      lat: 27.9881,
      lng: 86.9250,
      altitude: 5364,
      speed: 1.2,
      battery: 88,
      recordedAt: new Date(),
    });

    const locations = await TelemetryService.getGroupLiveLocations(groupId, [userId]);
    expect(locations.length).toBe(1);
    expect(locations[0].userId).toBe(userId);
    expect(locations[0].lat).toBeCloseTo(27.9881);
    expect(locations[0].lng).toBeCloseTo(86.9250);
    expect(locations[0].altitude).toBe(5364);
    expect(locations[0].battery).toBe(88);
  });

  it('should process Good Samaritan mesh relay ledger and update recovered user', async () => {
    const goodSamaritanId = `samaritan-${Date.now()}`;
    const lostUserId = `lost-hiker-${Date.now()}`;
    const groupId = `everest-team-${Date.now()}`;

    const pastTimestamp = new Date(Date.now() - 3600000).toISOString(); // 1 hour ago

    const syncResult = await TelemetryService.syncMeshRelayLedger(goodSamaritanId, [
      {
        userId: lostUserId,
        groupId,
        lat: 28.0012,
        lng: 86.9345,
        altitude: 5800,
        speed: 0.0,
        battery: 14,
        recordedAt: pastTimestamp,
      },
    ]);

    expect(syncResult.processed).toBe(1);
    expect(syncResult.recoveredUsers).toContain(lostUserId);

    // Verify location is now active in cache
    const live = await TelemetryService.getGroupLiveLocations(groupId, [lostUserId]);
    expect(live.length).toBe(1);
    expect(live[0].lat).toBeCloseTo(28.0012);
    expect(live[0].battery).toBe(14);
  });

  it('should skip mesh relay records with timestamps in the far future', async () => {
    const goodSamaritanId = `samaritan-${Date.now()}`;
    const lostUserId = `future-user-${Date.now()}`;
    const groupId = `future-group-${Date.now()}`;

    const futureTimestamp = new Date(Date.now() + 86400000).toISOString(); // 24 hours in the future

    const syncResult = await TelemetryService.syncMeshRelayLedger(goodSamaritanId, [
      {
        userId: lostUserId,
        groupId,
        lat: 28.0012,
        lng: 86.9345,
        recordedAt: futureTimestamp,
      },
    ]);

    expect(syncResult.recoveredUsers.length).toBe(0);
  });
});
