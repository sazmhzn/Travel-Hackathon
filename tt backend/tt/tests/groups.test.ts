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

  it('should let a guide deactivate and reactivate a group by invite code', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@status.com`,
      password: 'Password123!',
      name: 'Status Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@status.com`,
      password: 'Password123!',
      name: 'Status Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Status Test Expedition',
      createdBy: guide.id,
    });
    expect(group.is_active).toBe(true);

    const deactivated = await GroupsService.setGroupStatus(guide.id, group.id, false);
    expect(deactivated.is_active).toBe(false);

    await expect(
      GroupsService.joinGroupByInviteCode(member.id, group.invite_code)
    ).rejects.toThrow(/deactivated/i);

    const reactivated = await GroupsService.setGroupStatus(guide.id, group.id, true);
    expect(reactivated.is_active).toBe(true);

    const joined = await GroupsService.joinGroupByInviteCode(member.id, group.invite_code);
    expect(joined.id).toBe(group.id);
  });

  it('should only let the guide change group status', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@perm.com`,
      password: 'Password123!',
      name: 'Perm Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@perm.com`,
      password: 'Password123!',
      name: 'Perm Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Permissions Expedition',
      createdBy: guide.id,
    });

    await expect(
      GroupsService.setGroupStatus(member.id, group.id, false)
    ).rejects.toThrow(/guide/i);
  });

  it('should return group details with member and missing breakdown', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@details.com`,
      password: 'Password123!',
      name: 'Details Guide',
      role: 'GUIDE',
    });

    const group = await GroupsService.createGroup({
      name: 'Details Expedition',
      createdBy: guide.id,
    });

    const details = await GroupsService.getGroupDetails(group.id, guide.id);
    expect(details.group.id).toBe(group.id);
    expect(details.memberCount).toBe(1);
    expect(details.guideCount).toBe(1);
    expect(details.missingCount).toBe(1); // guide has not sent telemetry yet
    expect(details.members[0].isMissing).toBe(true);
  });

  it('should seed fallback groups for a guide with no expeditions, once', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@fallback.com`,
      password: 'Password123!',
      name: 'Fallback Guide',
      role: 'GUIDE',
    });

    const seeded = await GroupsService.getUserGroups(guide.id, 'GUIDE');
    expect(seeded.length).toBeGreaterThanOrEqual(3);
    expect(seeded.every((g) => g.invite_code)).toBe(true);

    const secondCall = await GroupsService.getUserGroups(guide.id, 'GUIDE');
    expect(secondCall.length).toBe(seeded.length);
  });

  it('should not seed fallback groups for members', async () => {
    const member = await AuthService.register({
      email: `member-${Date.now()}@fallback.com`,
      password: 'Password123!',
      name: 'Fallback Member',
      role: 'MEMBER',
    });

    const groups = await GroupsService.getUserGroups(member.id, 'MEMBER');
    expect(groups.length).toBe(0);
  });
});
