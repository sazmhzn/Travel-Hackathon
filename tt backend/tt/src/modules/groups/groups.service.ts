import crypto from 'crypto';
import { query } from '../../config/database.js';
import { AuthService } from '../auth/auth.service.js';
import { TelemetryService } from '../telemetry/telemetry.service.js';

export interface Group {
  id: string;
  name: string;
  description?: string;
  invite_code: string;
  created_by: string;
  is_active?: boolean;
  created_at?: string;
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
}

// A member is considered "missing" when no telemetry ping has been received
// within this window.
const MISSING_THRESHOLD_MS = 10 * 60 * 1000;

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
         RETURNING id, name, description, invite_code, created_by, is_active, created_at`,
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
          is_active: true,
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

      if (group.is_active === false) {
        throw new Error('This expedition is currently deactivated');
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
        if (matched.is_active === false) {
          throw new Error('This expedition is currently deactivated');
        }
        const members = inMemoryGroupMembers.get(matched.id) || [];
        if (!members.some((m) => m.user_id === userId)) {
          members.push({ id: `gm-${Date.now()}`, group_id: matched.id, user_id: userId, role: 'MEMBER' });
          inMemoryGroupMembers.set(matched.id, members);
        }
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
   * Activates or deactivates an expedition. Only the owning guide may toggle it.
   */
  static async setGroupStatus(
    userId: string,
    groupId: string,
    isActive: boolean
  ): Promise<Group> {
    const isGuide = await this.isUserGuideInGroup(userId, groupId);
    if (!isGuide) {
      throw new Error('Only the expedition guide can change its status');
    }

    try {
      const res = await query(
        `UPDATE groups SET is_active = $2, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1
         RETURNING id, name, description, invite_code, created_by, is_active, created_at`,
        [groupId, isActive]
      );
      if (res.rowCount === 0) {
        throw new Error('Group not found');
      }
      return res.rows[0];
    } catch (err: any) {
      if (!isDatabaseOffline(err)) throw err;
      const group = inMemoryGroups.get(groupId);
      if (!group) throw new Error('Group not found');
      group.is_active = isActive;
      return group;
    }
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
      const isMissing = !lastSeen || now - lastSeen.getTime() > MISSING_THRESHOLD_MS;
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
        `SELECT gm.id, gm.group_id, gm.user_id, gm.role, gm.joined_at, u.name, u.email, u.phone, u.fcm_token
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
