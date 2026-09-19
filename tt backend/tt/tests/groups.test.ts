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

  it('should default a new expedition to PENDING and let a guide start/complete it', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@status.com`,
      password: 'Password123!',
      name: 'Status Guide',
      role: 'GUIDE',
    });

    const group = await GroupsService.createGroup({
      name: 'Status Test Expedition',
      createdBy: guide.id,
    });
    expect(group.status).toBe('PENDING');

    const started = await GroupsService.setGroupStatus(guide.id, group.id, 'ONGOING');
    expect(started.status).toBe('ONGOING');

    const completed = await GroupsService.setGroupStatus(guide.id, group.id, 'COMPLETED');
    expect(completed.status).toBe('COMPLETED');
  });

  it('should clear members when a completed expedition is reactivated', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@reactivate.com`,
      password: 'Password123!',
      name: 'Reactivate Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@reactivate.com`,
      password: 'Password123!',
      name: 'Leaving Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Reactivate Expedition',
      createdBy: guide.id,
    });
    await GroupsService.joinGroupByInviteCode(member.id, group.invite_code);
    await GroupsService.setGroupStatus(guide.id, group.id, 'COMPLETED');

    const reactivated = await GroupsService.setGroupStatus(guide.id, group.id, 'PENDING');
    expect(reactivated.status).toBe('PENDING');

    const members = await GroupsService.getGroupMembers(group.id);
    expect(members.some((m) => m.user_id === member.id)).toBe(false);
    expect(members.some((m) => m.user_id === guide.id && m.role === 'GUIDE')).toBe(true);
  });

  it('should not let a guide run two expeditions at once', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@ongoing.com`,
      password: 'Password123!',
      name: 'Ongoing Guide',
      role: 'GUIDE',
    });

    const first = await GroupsService.createGroup({
      name: 'First Ongoing Expedition',
      createdBy: guide.id,
    });
    const second = await GroupsService.createGroup({
      name: 'Second Ongoing Expedition',
      createdBy: guide.id,
    });

    await GroupsService.setGroupStatus(guide.id, first.id, 'ONGOING');

    await expect(
      GroupsService.setGroupStatus(guide.id, second.id, 'ONGOING')
    ).rejects.toThrow(/complete the ongoing/i);

    const firstGroup = await GroupsService.getGroupById(first.id);
    const secondGroup = await GroupsService.getGroupById(second.id);
    expect(firstGroup?.status).toBe('ONGOING');
    expect(secondGroup?.status).toBe('PENDING');
  });

  it('should let different guides run expeditions at the same time', async () => {
    const guideA = await AuthService.register({
      email: `guide-a-${Date.now()}@ongoing.com`,
      password: 'Password123!',
      name: 'Guide A',
      role: 'GUIDE',
    });
    const guideB = await AuthService.register({
      email: `guide-b-${Date.now()}@ongoing.com`,
      password: 'Password123!',
      name: 'Guide B',
      role: 'GUIDE',
    });

    const groupA = await GroupsService.createGroup({ name: 'Guide A Trek', createdBy: guideA.id });
    const groupB = await GroupsService.createGroup({ name: 'Guide B Trek', createdBy: guideB.id });

    await GroupsService.setGroupStatus(guideA.id, groupA.id, 'ONGOING');
    const started = await GroupsService.setGroupStatus(guideB.id, groupB.id, 'ONGOING');
    expect(started.status).toBe('ONGOING');
  });

  it('should not let members join a completed expedition', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@completed.com`,
      password: 'Password123!',
      name: 'Completed Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@completed.com`,
      password: 'Password123!',
      name: 'Late Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Finished Expedition',
      createdBy: guide.id,
    });
    await GroupsService.setGroupStatus(guide.id, group.id, 'COMPLETED');

    await expect(
      GroupsService.joinGroupByInviteCode(member.id, group.invite_code)
    ).rejects.toThrow(/completed/i);
  });

  it('should only let the guide change expedition status', async () => {
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
      GroupsService.setGroupStatus(member.id, group.id, 'ONGOING')
    ).rejects.toThrow(/guide/i);
  });

  it('should let a guide edit the expedition title and description', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@edit.com`,
      password: 'Password123!',
      name: 'Edit Guide',
      role: 'GUIDE',
    });

    const group = await GroupsService.createGroup({
      name: 'Original Title',
      description: 'Original description',
      createdBy: guide.id,
    });

    const updated = await GroupsService.updateGroup(guide.id, group.id, {
      name: 'Updated Title',
      description: 'Updated description',
    });
    expect(updated.name).toBe('Updated Title');
    expect(updated.description).toBe('Updated description');
  });

  it('should not let a member edit an expedition', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@editperm.com`,
      password: 'Password123!',
      name: 'Edit Perm Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@editperm.com`,
      password: 'Password123!',
      name: 'Edit Perm Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Locked Expedition',
      createdBy: guide.id,
    });

    await expect(
      GroupsService.updateGroup(member.id, group.id, { name: 'Hacked' })
    ).rejects.toThrow(/guide/i);
  });

  it('should let a guide remove a member but not themselves or other guides', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@remove.com`,
      password: 'Password123!',
      name: 'Remove Guide',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@remove.com`,
      password: 'Password123!',
      name: 'Removable Member',
      role: 'MEMBER',
    });

    const group = await GroupsService.createGroup({
      name: 'Roster Expedition',
      createdBy: guide.id,
    });
    await GroupsService.joinGroupByInviteCode(member.id, group.invite_code);

    await GroupsService.removeMember(guide.id, group.id, member.id);
    const members = await GroupsService.getGroupMembers(group.id);
    expect(members.some((m) => m.user_id === member.id)).toBe(false);

    await expect(
      GroupsService.removeMember(guide.id, group.id, guide.id)
    ).rejects.toThrow(/guide/i);
  });

  it('should browse only pending and completed expeditions', async () => {
    const guide = await AuthService.register({
      email: `guide-${Date.now()}@browse.com`,
      password: 'Password123!',
      name: 'Browse Guide',
      role: 'GUIDE',
    });

    const pending = await GroupsService.createGroup({ name: 'Browse Pending', createdBy: guide.id });
    const ongoing = await GroupsService.createGroup({ name: 'Browse Ongoing', createdBy: guide.id });
    const completed = await GroupsService.createGroup({ name: 'Browse Completed', createdBy: guide.id });
    await GroupsService.setGroupStatus(guide.id, ongoing.id, 'ONGOING');
    await GroupsService.setGroupStatus(guide.id, completed.id, 'COMPLETED');

    const browsed = await GroupsService.getBrowseGroups(guide.id, 'GUIDE');
    const ids = browsed.map((g) => g.id);
    expect(ids).toContain(pending.id);
    expect(ids).toContain(completed.id);
    expect(ids).not.toContain(ongoing.id);
  });

  it('should let members browse every guide\'s pending and completed expeditions', async () => {
    const guideA = await AuthService.register({
      email: `guide-a-${Date.now()}@browseall.com`,
      password: 'Password123!',
      name: 'Browse Guide A',
      role: 'GUIDE',
    });
    const guideB = await AuthService.register({
      email: `guide-b-${Date.now()}@browseall.com`,
      password: 'Password123!',
      name: 'Browse Guide B',
      role: 'GUIDE',
    });
    const member = await AuthService.register({
      email: `member-${Date.now()}@browseall.com`,
      password: 'Password123!',
      name: 'Browse Member',
      role: 'MEMBER',
    });

    const groupA = await GroupsService.createGroup({ name: 'Guide A Browse', createdBy: guideA.id });
    const groupB = await GroupsService.createGroup({ name: 'Guide B Browse', createdBy: guideB.id });

    const browsed = await GroupsService.getBrowseGroups(member.id, 'MEMBER');
    const ids = browsed.map((g) => g.id);
    expect(ids).toContain(groupA.id);
    expect(ids).toContain(groupB.id);

    // Non-members must not receive the invite code.
    const card = browsed.find((g) => g.id === groupA.id);
    expect(card?.invite_code).toBe('');
    expect(card?.is_member).toBe(false);
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
