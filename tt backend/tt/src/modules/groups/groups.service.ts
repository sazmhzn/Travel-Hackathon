import crypto from 'crypto';
import { query } from '../../config/database.js';
import { AuthService } from '../auth/auth.service.js';

export interface Group {
  id: string;
  name: string;
  description?: string;
  invite_code: string;
  created_by: string;
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

// In-memory fallback stores for offline dev/test environments
export const inMemoryGroups = new Map<string, Group>();
export const inMemoryGroupMembers = new Map<string, GroupMember[]>();

export class GroupsService {
  static async createGroup(data: {
    name: string;
    description?: string;
    createdBy: string;
  }): Promise<Group> {
    const inviteCode = crypto.randomBytes(4).toString('hex').toUpperCase();

    try {
      const res = await query(
        `INSERT INTO groups (name, description, invite_code, created_by)
         VALUES ($1, $2, $3, $4)
         RETURNING id, name, description, invite_code, created_by, created_at`,
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
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        const id = `group-${Date.now()}`;
        const group: Group = {
          id,
          name: data.name,
          description: data.description,
          invite_code: inviteCode,
          created_by: data.createdBy,
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

  static async joinGroupByInviteCode(userId: string, inviteCode: string): Promise<Group> {
    try {
      const groupRes = await query('SELECT * FROM groups WHERE invite_code = $1', [inviteCode.toUpperCase()]);
      if (groupRes.rowCount === 0) {
        throw new Error('Invalid invite code');
      }
      const group = groupRes.rows[0];

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
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        let matched: Group | undefined;
        for (const g of inMemoryGroups.values()) {
          if (g.invite_code === inviteCode.toUpperCase()) {
            matched = g;
            break;
          }
        }
        if (!matched) throw new Error('Invalid invite code');
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
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
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
      throw err;
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

  static async getUserGroups(userId: string): Promise<Group[]> {
    try {
      const res = await query(
        `SELECT g.* FROM groups g
         JOIN group_members gm ON g.id = gm.group_id
         WHERE gm.user_id = $1`,
        [userId]
      );
      return res.rows;
    } catch (err: any) {
      const userGroupIds: string[] = [];
      for (const [gid, members] of inMemoryGroupMembers.entries()) {
        if (members.some((m) => m.user_id === userId)) {
          userGroupIds.push(gid);
        }
      }
      return userGroupIds.map((id) => inMemoryGroups.get(id)!).filter(Boolean);
    }
  }
}
