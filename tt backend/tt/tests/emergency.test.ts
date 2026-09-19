import { describe, it, expect } from 'vitest';
import { EmergencyService } from '../src/modules/emergency/emergency.service.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { GroupsService } from '../src/modules/groups/groups.service.js';

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
});
