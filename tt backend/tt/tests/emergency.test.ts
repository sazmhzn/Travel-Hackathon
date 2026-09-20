import { describe, it, expect } from 'vitest';
import { EmergencyService } from '../src/modules/emergency/emergency.service.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { GroupsService } from '../src/modules/groups/groups.service.js';
import { TelemetryService } from '../src/modules/telemetry/telemetry.service.js';

describe('EmergencyService Integration', () => {
  it('should trigger rescue mode, notify guides, and create alert record', async () => {
    // 1. Create a guide and a member
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@emergency.com`,
      password: 'Password123!',
      name: 'Head Mountain Guide',
      role: 'GUIDE',
    });

    // Assign guide an FCM token
    await AuthService.updateFcmToken(guide.id, 'fcm_token_device_abc123');

    const member = await AuthService.register({
      email: `member-${Date.now()}@emergency.com`,
      password: 'Password123!',
      name: 'Trekker In Danger',
      phone: '+977987654321',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'K2 Alpine Expedition',
      createdBy: guide.id,
    });

    await GroupsService.joinGroupByInviteCode(member.id, group.invite_code);

    // 2. Member triggers Rescue Mode
    const alertResult = await EmergencyService.triggerRescueMode({
      userId: member.id,
      groupId: group.id,
      lat: 35.8808,
      lng: 76.5158,
      battery: 18,
      reason: 'Fell into crevasse, leg injury, hypothermia risk',
    });

    expect(alertResult).toBeDefined();
    expect(alertResult.alertId).toBeDefined();
    // In test mode without live credentials, Telegram will be false or mock, but fcmGuidesNotified will find the guide with fcm_token
    expect(alertResult.fcmGuidesNotified).toBeGreaterThanOrEqual(1);
  });

  it('should alert only nearby non-members within the SOS radius', async () => {
    // Pure logic test: no DB, the nearby query only needs telemetry entries.
    const senderId = `sender-${Date.now()}`;
    const guideId = `guide-${Date.now()}`;
    const nearbyId = `nearby-${Date.now()}`;
    const farId = `far-${Date.now()}`;

    // Remote midpoint in the ocean so no real users can contaminate the query.
    const origin = { lat: 0.0, lng: 0.0 };
    await TelemetryService.ingestLiveLocation({
      userId: senderId,
      groupId: 'nearby-group',
      lat: origin.lat,
      lng: origin.lng,
      recordedAt: new Date(),
    });
    // ~1 km away, inside the 20 km radius.
    await TelemetryService.ingestLiveLocation({
      userId: nearbyId,
      groupId: 'other-group',
      lat: origin.lat + 0.01,
      lng: origin.lng,
      recordedAt: new Date(),
    });
    // ~111 km away, outside the radius.
    await TelemetryService.ingestLiveLocation({
      userId: farId,
      groupId: 'other-group',
      lat: origin.lat + 1,
      lng: origin.lng,
      recordedAt: new Date(),
    });

    const alerted = await EmergencyService.broadcastNearbySos(
      'nearby-group',
      senderId,
      'Sender In Distress',
      origin.lat,
      origin.lng,
      'Test distress',
      new Set([guideId, senderId]),
      'alert-test'
    );

    // Only the nearby stranger qualifies: sender is excluded, guide is excluded,
    // farStranger is beyond 20 km.
    expect(alerted).toBe(1);
  });
});
