import crypto from 'crypto';
import { query } from '../../config/database.js';
import { env } from '../../config/env.js';
import { broadcastToGroup, broadcastToUser } from '../../sockets/gateway.js';
import { AuthService } from '../auth/auth.service.js';
import { TelemetryService } from '../telemetry/telemetry.service.js';

export type GroupStatus = 'PENDING' | 'ONGOING' | 'COMPLETED';

export interface Group {
  id: string;
  name: string;
  description?: string;
  invite_code: string;
  created_by: string;
  status?: GroupStatus;
  created_at?: string;
  guide_name?: string;
  is_member?: boolean;
  hotspot_ssid?: string | null;
  hotspot_password?: string | null;
}

export interface GroupMember {
  id: string;
  group_id: string;
  user_id: string;
  role: 'GUIDE' | 'MEMBER';
  joined_at?: string;
  name?: string;
  email?: string;
  phone?: string;
  fcm_token?: string;
  device_id?: string | null;
  bluetooth_name?: string | null;
}

export interface GroupMemberStatus extends GroupMember {
  isMissing: boolean;
  lat?: number | null;
  lng?: number | null;
  battery?: number | null;
  altitude?: number | null;
  speed?: number | null;
  lastSeen?: string | null;
}

export interface GroupDetails {
  group: Group;
  memberCount: number;
  guideCount: number;
  onlineCount: number;
  missingCount: number;
  members: GroupMemberStatus[];
  missingThresholdSeconds: number;
}

// A member is considered "missing" when no telemetry ping has been received
// within this window. Configurable via MISSING_THRESHOLD_SECONDS.
const missingThresholdMs = (): number => env.MISSING_THRESHOLD_SECONDS * 1000;

// In-memory fallback stores for offline dev/test environments
export const inMemoryGroups = new Map<string, Group>();
export const inMemoryGroupMembers = new Map<string, GroupMember[]>();

function isDatabaseOffline(err: any): boolean {
  return (
    err?.code === 'ECONNREFUSED' ||
    err?.code === 'ENOTFOUND' ||
    err?.code === 'ETIMEDOUT' ||
    /connect/i.test(err?.message ?? '')
  );
}

function generateInviteCode(): string {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
}

export class GroupsService {
  static async createGroup(data: {
    name: string;
    description?: string;
    createdBy: string;
  }): Promise<Group> {
    const inviteCode = await this.generateUniqueInviteCode();

    try {
      const res = await query(
        `INSERT INTO groups (name, description, invite_code, created_by)
         VALUES ($1, $2, $3, $4)
         RETURNING id, name, description, invite_code, created_by, status, created_at`,
        [data.name, data.description || null, inviteCode, data.createdBy]
      );
      const group = res.rows[0];

      // Add creator as GUIDE in group_members
      await query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'GUIDE')`,
        [group.id, data.createdBy]
      );

      return group;
    } catch (err: any) {
      if (isDatabaseOffline(err)) {
        const id = `group-${Date.now()}-${Math.random().toString(36).substring(7)}`;
        const group: Group = {
          id,
          name: data.name,
          description: data.description,
          invite_code: inviteCode,
          created_by: data.createdBy,
          status: 'PENDING',
        };
        inMemoryGroups.set(group.id, group);
        inMemoryGroupMembers.set(group.id, [
          { id: `gm-${Date.now()}`, group_id: group.id, user_id: data.createdBy, role: 'GUIDE' },
        ]);
        return group;
      }
      throw err;
    }
  }

  /**
   * Creates a reusable invite code that is unique across both the database
   * and the in-memory fallback store.
   */
  static async generateUniqueInviteCode(): Promise<string> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = generateInviteCode();
      try {
        const res = await query('SELECT 1 FROM groups WHERE invite_code = $1', [code]);
        if (res.rowCount === 0) return code;
      } catch (err: any) {
        if (!isDatabaseOffline(err)) throw err;
        // Fall through to in-memory uniqueness check below.
      }
      const takenInMemory = [...inMemoryGroups.values()].some((g) => g.invite_code === code);
      if (!takenInMemory) return code;
    }
    throw new Error('Could not generate a unique invite code');
  }

  /**
   * Idempotently seeds a guide's fallback expeditions so the UI always has
   * data to render, even on a fresh install.
   */
  static async ensureFallbackGroups(createdBy: string): Promise<Group[]> {
    const existing = await this.getOwnedGroups(createdBy);
    if (existing.length >= 3) return existing;

    const seeds = [
      { name: 'Everest Base Camp Trek', description: 'Classic 12-day EBC expedition via Lukla' },
      { name: 'Annapurna Circuit', description: 'Thorong La pass circuit around the Annapurnas' },
      { name: 'Kathmandu Valley Rim', description: 'Weekend ridge hike around the valley edge' },
    ];

    const created: Group[] = [];
    for (const seed of seeds) {
      if (existing.some((g) => g.name === seed.name)) continue;
      created.push(
        await this.createGroup({
          name: seed.name,
          description: seed.description,
          createdBy,
        })
      );
    }

    for (const group of created) {
      await this.seedFallbackMembers(group);
    }

    return [...existing, ...created];
  }

  /**
   * Adds a handful of demo members/missing hikers so the group details page
   * has something meaningful to show before real devices join.
   */
  private static async seedFallbackMembers(group: Group): Promise<void> {
    const roster: Array<{
      name: string;
      phone: string;
      role: 'GUIDE' | 'MEMBER';
      missing?: boolean;
    }> = [
      { name: 'Tenzing Sherpa', phone: '+977-9800000001', role: 'MEMBER' },
      { name: 'Maya Gurung', phone: '+977-9800000002', role: 'MEMBER' },
      { name: 'Arjun Thapa', phone: '+977-9800000003', role: 'MEMBER', missing: true },
      { name: 'Lena Fischer', phone: '+977-9800000004', role: 'MEMBER' },
      { name: 'Karma Lama', phone: '+977-9800000005', role: 'GUIDE' },
    ];

    for (const person of roster) {
      const email = `${person.name.toLowerCase().replace(/[^a-z]+/g, '.')}.${group.id.slice(-6)}@fallback.local`;
      try {
        const member = await AuthService.register({
          email,
          password: 'Password123!',
          name: person.name,
          phone: person.phone,
          role: person.role,
        });
        await this.addMember(group.id, member.id, person.role);

        if (!person.missing) {
          await TelemetryService.ingestLiveLocation({
            userId: member.id,
            groupId: group.id,
            lat: 27.7172 + (Math.random() - 0.5) * 0.05,
            lng: 85.324 + (Math.random() - 0.5) * 0.05,
            altitude: 1400 + Math.random() * 400,
            speed: Math.random() * 1.5,
            battery: 40 + Math.floor(Math.random() * 55),
            recordedAt: new Date(),
          });
        }
      } catch {
        // Seeding is best-effort: a duplicate email simply means it already exists.
      }
    }
  }

  static async joinGroupByInviteCode(userId: string, inviteCode: string): Promise<Group> {
    try {
      const groupRes = await query('SELECT * FROM groups WHERE invite_code = $1', [inviteCode.toUpperCase()]);
      if (groupRes.rowCount === 0) {
        throw new Error('Invalid invite code');
      }
      const group: Group = groupRes.rows[0];

      if (group.status === 'COMPLETED') {
        throw new Error('This expedition is completed');
      }

      // Check if already a member
      const memberRes = await query(
        'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
        [group.id, userId]
      );

      if (memberRes.rowCount === 0) {
        await query(
          `INSERT INTO group_members (group_id, user_id, role)
           VALUES ($1, $2, 'MEMBER')`,
          [group.id, userId]
        );
      }

      broadcastToGroup(group.id, 'group:member_joined', { groupId: group.id, userId });
      return group;
    } catch (err: any) {
      if (isDatabaseOffline(err)) {
        let matched: Group | undefined;
        for (const g of inMemoryGroups.values()) {
          if (g.invite_code === inviteCode.toUpperCase()) {
            matched = g;
            break;
          }
        }
        if (!matched) throw new Error('Invalid invite code');
        if (matched.status === 'COMPLETED') {
          throw new Error('This expedition is completed');
        }
        const members = inMemoryGroupMembers.get(matched.id) || [];
        if (!members.some((m) => m.user_id === userId)) {
          members.push({ id: `gm-${Date.now()}`, group_id: matched.id, user_id: userId, role: 'MEMBER' });
          inMemoryGroupMembers.set(matched.id, members);
        }
        broadcastToGroup(matched.id, 'group:member_joined', { groupId: matched.id, userId });
        return matched;
      }
      throw err;
    }
  }

  static async addMember(groupId: string, userId: string, role: 'GUIDE' | 'MEMBER'): Promise<void> {
    try {
      await query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, $3)
         ON CONFLICT (group_id, user_id) DO NOTHING`,
        [groupId, userId, role]
      );
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const members = inMemoryGroupMembers.get(groupId) || [];
      if (!members.some((m) => m.user_id === userId)) {
        members.push({ id: `gm-${Date.now()}`, group_id: groupId, user_id: userId, role });
        inMemoryGroupMembers.set(groupId, members);
      }
    }
    broadcastToGroup(groupId, 'group:member_joined', { groupId, userId });
  }

  static async getOwnedGroups(userId: string): Promise<Group[]> {
    try {
      const res = await query(
        `SELECT * FROM groups WHERE created_by = $1 ORDER BY created_at ASC`,
        [userId]
      );
      return res.rows;
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      return [...inMemoryGroups.values()].filter((g) => g.created_by === userId);
    }
  }

  /**
   * Changes an expedition's lifecycle status. Only the owning guide may do so.
   * A guide can only have one ONGOING expedition: starting a new one while
   * another is still ongoing is rejected.
   */
  static async setGroupStatus(
    userId: string,
    groupId: string,
    status: GroupStatus
  ): Promise<Group> {
    const isGuide = await this.isUserGuideInGroup(userId, groupId);
    if (!isGuide) {
      throw new Error('Only the expedition guide can change its status');
    }

    if (status === 'ONGOING') {
      await this.assertNoOtherOngoing(userId, groupId);
    }

    // Reactivating a completed expedition gives it a clean slate: all members
    // (and co-guides) are removed, leaving only the owning guide.
    const current = await this.getGroupById(groupId);
    if (!current) {
      throw new Error('Group not found');
    }
    if (current.status === 'COMPLETED' && status === 'PENDING') {
      await this.clearMembersForReactivation(groupId, current.created_by);
    }

    try {
      const res = await query(
        `UPDATE groups
         SET status = $2::text,
             hotspot_ssid = CASE WHEN $2::text = 'COMPLETED' THEN NULL ELSE hotspot_ssid END,
             hotspot_password = CASE WHEN $2::text = 'COMPLETED' THEN NULL ELSE hotspot_password END,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1
         RETURNING *`,
        [groupId, status]
      );
      if (res.rowCount === 0) {
        throw new Error('Group not found');
      }
      broadcastToGroup(groupId, 'group:updated', { groupId });
      return res.rows[0];
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const group = inMemoryGroups.get(groupId);
      if (!group) throw new Error('Group not found');
      group.status = status;
      if (status === 'COMPLETED') {
        group.hotspot_ssid = null;
        group.hotspot_password = null;
      }
      broadcastToGroup(groupId, 'group:updated', { groupId });
      return group;
    }
  }

  /**
   * Stores the guide's hotspot credentials for an expedition so members can
   * join the same local network when there is no internet. Guide only.
   */
  static async setHotspot(
    userId: string,
    groupId: string,
    ssid: string,
    password: string
  ): Promise<Group> {
    if (!(await this.isUserGuideInGroup(userId, groupId))) {
      throw new Error('Only the expedition guide can set the hotspot');
    }

    try {
      const res = await query(
        `UPDATE groups
         SET hotspot_ssid = $2, hotspot_password = $3, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1
         RETURNING *`,
        [groupId, ssid, password]
      );
      if (res.rowCount === 0) throw new Error('Group not found');
      return res.rows[0];
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const group = inMemoryGroups.get(groupId);
      if (!group) throw new Error('Group not found');
      group.hotspot_ssid = ssid;
      group.hotspot_password = password;
      return group;
    }
  }

  /**
   * Throws when the guide already has a different ONGOING expedition.
   */
  private static async assertNoOtherOngoing(userId: string, groupId: string): Promise<void> {
    try {
      const res = await query(
        `SELECT 1 FROM groups
         WHERE created_by = $1 AND status = 'ONGOING' AND id <> $2`,
        [userId, groupId]
      );
      if ((res.rowCount ?? 0) > 0) {
        throw new Error('Complete the ongoing expedition first');
      }
    } catch (err: any) {
      if (err?.message === 'Complete the ongoing expedition first') throw err;
      if (!isDatabaseOffline(err)) throw err;
      const conflict = [...inMemoryGroups.values()].some(
        (g) => g.created_by === userId && g.status === 'ONGOING' && g.id !== groupId
      );
      if (conflict) {
        throw new Error('Complete the ongoing expedition first');
      }
    }
  }

  /**
   * Removes every member and co-guide from an expedition, keeping only the
   * owning guide. Used when a completed expedition is reactivated so it starts
   * fresh for a new roster.
   */
  private static async clearMembersForReactivation(
    groupId: string,
    ownerId: string
  ): Promise<void> {
    try {
      await query(
        `DELETE FROM group_members WHERE group_id = $1 AND user_id <> $2`,
        [groupId, ownerId]
      );
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const list = inMemoryGroupMembers.get(groupId) || [];
      inMemoryGroupMembers.set(
        groupId,
        list.filter((m) => m.user_id === ownerId)
      );
    }
  }

  /**
   * Expeditions members can browse: PENDING and COMPLETED only, never ONGOING.
   * Guides see their own expeditions; members see every guide's expeditions.
   * The invite code is only exposed to users who already belong to the group.
   */
  static async getBrowseGroups(
    userId: string,
    role?: 'GUIDE' | 'MEMBER' | 'ADMIN'
  ): Promise<Group[]> {
    try {
      const scopeClause =
        role === 'GUIDE' ? 'g.created_by = $1' : "TRUE";
      const res = await query(
        `SELECT g.*, u.name AS guide_name,
                EXISTS (
                  SELECT 1 FROM group_members gm
                  WHERE gm.group_id = g.id AND gm.user_id = $1
                ) AS is_member
         FROM groups g
         JOIN users u ON g.created_by = u.id
         WHERE g.status IN ('PENDING', 'COMPLETED') AND ${scopeClause}
         ORDER BY g.created_at ASC`,
        [userId]
      );
      return res.rows.map((row: any) => this.maskInviteCode(row));
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const browse = [...inMemoryGroups.values()].filter((g) => {
        if (g.status !== 'PENDING' && g.status !== 'COMPLETED') return false;
        return role === 'GUIDE' ? g.created_by === userId : true;
      });
      const results: Group[] = [];
      for (const g of browse) {
        const members = inMemoryGroupMembers.get(g.id) || [];
        const guide = await AuthService.getUserById(g.created_by);
        results.push(
          this.maskInviteCode({
            ...g,
            guide_name: guide?.name,
            is_member: members.some((m) => m.user_id === userId),
          })
        );
      }
      return results;
    }
  }

  /**
   * Hides the invite code from users who are not members of the expedition.
   */
  private static maskInviteCode(group: Group): Group {
    if (group.is_member) return group;
    return { ...group, invite_code: '' };
  }

  /**
   * Full group view for the guide: roster merged with live telemetry and a
   * computed missing/online breakdown.
   */
  static async getGroupDetails(groupId: string, userId: string): Promise<GroupDetails> {
    const group = await this.getGroupById(groupId);
    if (!group) throw new Error('Group not found');

    const members = await this.getGroupMembers(groupId);
    if (!members.some((m) => m.user_id === userId)) {
      throw new Error('You are not a member of this group');
    }

    const memberIds = members.map((m) => m.user_id);
    const liveLocations = await TelemetryService.getGroupLiveLocations(groupId, memberIds);
    const liveByUser = new Map(liveLocations.map((loc: any) => [loc.userId, loc]));
    const now = Date.now();

    const enriched: GroupMemberStatus[] = members.map((member) => {
      const live: any = liveByUser.get(member.user_id);
      const lastSeen = live?.recordedAt ? new Date(live.recordedAt) : null;
      const isMissing = !lastSeen || now - lastSeen.getTime() > missingThresholdMs();
      return {
        ...member,
        isMissing,
        lat: live?.lat ?? null,
        lng: live?.lng ?? null,
        battery: live?.battery ?? null,
        altitude: live?.altitude ?? null,
        speed: live?.speed ?? null,
        lastSeen: lastSeen ? lastSeen.toISOString() : null,
      };
    });

    enriched.sort((a, b) => {
      if (a.isMissing !== b.isMissing) return a.isMissing ? -1 : 1;
      return (a.name ?? '').localeCompare(b.name ?? '');
    });

    return {
      group,
      memberCount: enriched.length,
      guideCount: enriched.filter((m) => m.role === 'GUIDE').length,
      onlineCount: enriched.filter((m) => !m.isMissing).length,
      missingCount: enriched.filter((m) => m.isMissing).length,
      members: enriched,
      missingThresholdSeconds: env.MISSING_THRESHOLD_SECONDS,
    };
  }

  static async getGroupById(groupId: string): Promise<Group | null> {
    try {
      const res = await query('SELECT * FROM groups WHERE id = $1', [groupId]);
      return res.rows[0] || null;
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      return inMemoryGroups.get(groupId) || null;
    }
  }

  static async getGroupMembers(groupId: string): Promise<GroupMember[]> {
    try {
      const res = await query(
        `SELECT gm.id, gm.group_id, gm.user_id, gm.role, gm.joined_at,
                u.name, u.email, u.phone, u.fcm_token, u.device_id, u.bluetooth_name
         FROM group_members gm
         JOIN users u ON gm.user_id = u.id
         WHERE gm.group_id = $1
         ORDER BY gm.role ASC, gm.joined_at ASC`,
        [groupId]
      );
      return res.rows;
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const rawMembers = inMemoryGroupMembers.get(groupId) || [];
      // Enrich with user profile data including fcm_token
      const enriched: GroupMember[] = [];
      for (const m of rawMembers) {
        const u = await AuthService.getUserById(m.user_id);
        enriched.push({
          ...m,
          name: u?.name,
          email: u?.email,
          phone: u?.phone,
          fcm_token: u?.fcm_token,
          device_id: u?.device_id,
          bluetooth_name: u?.bluetooth_name,
        });
      }
      return enriched;
    }
  }

  static async isUserGuideInGroup(userId: string, groupId: string): Promise<boolean> {
    try {
      const res = await query(
        `SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2 AND role = 'GUIDE'`,
        [groupId, userId]
      );
      return (res.rowCount ?? 0) > 0;
    } catch (err: any) {
      const members = inMemoryGroupMembers.get(groupId) || [];
      return members.some((m) => m.user_id === userId && m.role === 'GUIDE');
    }
  }

  /**
   * Updates an expedition's title and description. Only the owning guide may.
   */
  static async updateGroup(
    userId: string,
    groupId: string,
    data: { name?: string; description?: string }
  ): Promise<Group> {
    if (!(await this.isUserGuideInGroup(userId, groupId))) {
      throw new Error('Only the expedition guide can edit it');
    }

    try {
      const res = await query(
        `UPDATE groups
         SET name = COALESCE($2, name),
             description = COALESCE($3, description),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1
         RETURNING id, name, description, invite_code, created_by, status, created_at`,
        [groupId, data.name ?? null, data.description ?? null]
      );
      if (res.rowCount === 0) throw new Error('Group not found');
      broadcastToGroup(groupId, 'group:updated', { groupId });
      return res.rows[0];
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const group = inMemoryGroups.get(groupId);
      if (!group) throw new Error('Group not found');
      if (data.name !== undefined) group.name = data.name;
      if (data.description !== undefined) group.description = data.description;
      broadcastToGroup(groupId, 'group:updated', { groupId });
      return group;
    }
  }

  /**
   * Removes a member from an expedition. Only the owning guide may, and guides
   * cannot remove themselves or other guides.
   */
  static async removeMember(
    userId: string,
    groupId: string,
    memberUserId: string
  ): Promise<void> {
    if (!(await this.isUserGuideInGroup(userId, groupId))) {
      throw new Error('Only the expedition guide can remove members');
    }

    const members = await this.getGroupMembers(groupId);
    const target = members.find((m) => m.user_id === memberUserId);
    if (!target) throw new Error('This person is not a member of the expedition');
    if (target.role === 'GUIDE') {
      throw new Error('Guides cannot be removed from the expedition');
    }

    try {
      await query(
        `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, memberUserId]
      );
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const list = inMemoryGroupMembers.get(groupId) || [];
      inMemoryGroupMembers.set(
        groupId,
        list.filter((m) => m.user_id !== memberUserId)
      );
    }

    broadcastToGroup(groupId, 'group:member_removed', { groupId, userId: memberUserId });
    broadcastToUser(memberUserId, 'group:removed', { groupId });
  }

  static async getUserGroups(userId: string, role?: 'GUIDE' | 'MEMBER' | 'ADMIN'): Promise<Group[]> {
    let groups: Group[];
    try {
      const res = await query(
        `SELECT g.* FROM groups g
         JOIN group_members gm ON g.id = gm.group_id
         WHERE gm.user_id = $1
         ORDER BY g.created_at ASC`,
        [userId]
      );
      groups = res.rows;
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const userGroupIds: string[] = [];
      for (const [gid, members] of inMemoryGroupMembers.entries()) {
        if (members.some((m) => m.user_id === userId)) {
          userGroupIds.push(gid);
        }
      }
      groups = userGroupIds.map((id) => inMemoryGroups.get(id)!).filter(Boolean);
    }

    // Guides always have expeditions to manage; seed a starter set on first run.
    if (groups.length === 0 && role === 'GUIDE') {
      return this.ensureFallbackGroups(userId);
    }

    return groups;
  }
}
