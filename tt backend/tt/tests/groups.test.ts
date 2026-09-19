import { describe, it, expect } from 'vitest';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { GroupsService } from '../src/modules/groups/groups.service.js';

describe('GroupsService Integration', () => {
  it('should allow a guide to create a group and automatically become GUIDE member', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@group.com`,
      password: 'Password123!',
      name: 'Group Guide Leader',
      role: 'GUIDE',
    });

    const group = await GroupsService.createGroup({
      name: 'Everest Expedition 2026',
      description: 'High-altitude trek to EBC',
      createdBy: guide.id,
    });

    expect(group).toBeDefined();
    expect(group.id).toBeDefined();
    expect(group.name).toBe('Everest Expedition 2026');
    expect(group.invite_code).toBeDefined();
    expect(group.invite_code.length).toBeGreaterThanOrEqual(6);

    const isGuide = await GroupsService.isUserGuideInGroup(guide.id, group.id);
    expect(isGuide).toBe(true);

    const members = await GroupsService.getGroupMembers(group.id);
    expect(members.length).toBe(1);
    expect(members[0].role).toBe('GUIDE');
  });

  it('should allow a member to join via invite code', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@invite.com`,
      password: 'Password123!',
      name: 'Trek Guide',
      role: 'GUIDE',
    });

    const member = await AuthService.register({
      email: `hiker-${Date.now()}@invite.com`,
      password: 'Password123!',
      name: 'Avid Hiker',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Annapurna Circuit Team',
      createdBy: guide.id,
    });

    const joinedGroup = await GroupsService.joinGroupByInviteCode(member.id, group.invite_code);
    expect(joinedGroup.id).toBe(group.id);

    const members = await GroupsService.getGroupMembers(group.id);
    expect(members.length).toBe(2);

    const hikerMember = members.find((m) => m.user_id === member.id);
    expect(hikerMember).toBeDefined();
    expect(hikerMember?.role).toBe('MEMBER');
  });
});
