import bcrypt from 'bcryptjs';
import { query } from '../../config/database.js';

export interface UserPayload {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: 'GUIDE' | 'MEMBER' | 'ADMIN';
  fcm_token?: string;
}

// In-memory fallback mock user store for offline dev/tests when PostgreSQL is not running
export const inMemoryUsers = new Map<string, UserPayload & { password_hash: string }>();

export class AuthService {
  static async register(data: {
    email: string;
    password: string;
    name: string;
    phone?: string;
    role?: 'GUIDE' | 'MEMBER';
  }): Promise<UserPayload> {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(data.password, salt);
    const role = data.role || 'MEMBER';
    const emailKey = data.email.toLowerCase();

    try {
      const res = await query(
        `INSERT INTO users (email, password_hash, name, phone, role)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, email, name, phone, role, fcm_token`,
        [emailKey, passwordHash, data.name, data.phone || null, role]
      );
      return res.rows[0];
    } catch (err: any) {
      // If DB is offline, store in in-memory map for dev/test resilience
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        if (inMemoryUsers.has(emailKey)) {
          throw new Error('Email is already registered');
        }

        const id = `user-${Date.now()}-${Math.random().toString(36).substring(7)}`;
        const user: UserPayload & { password_hash: string } = {
          id,
          email: emailKey,
          name: data.name,
          phone: data.phone,
          role,
          password_hash: passwordHash,
        };
        inMemoryUsers.set(emailKey, user);
        return { id: user.id, email: user.email, name: user.name, phone: user.phone, role: user.role };
      }
      if (err.code === '23505') {
        throw new Error('Email is already registered');
      }
      throw err;
    }
  }

  static async login(data: {
    email: string;
    password: string;
  }): Promise<UserPayload> {
    const emailKey = data.email.toLowerCase();

    try {
      const res = await query(
        `SELECT id, email, password_hash, name, phone, role, fcm_token
         FROM users
         WHERE email = $1`,
        [emailKey]
      );

      if (res.rowCount === 0) {
        throw new Error('Invalid email or password');
      }

      const user = res.rows[0];
      const valid = await bcrypt.compare(data.password, user.password_hash);
      if (!valid) {
        throw new Error('Invalid email or password');
      }

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        phone: user.phone,
        role: user.role,
        fcm_token: user.fcm_token,
      };
    } catch (err: any) {
      // In-memory fallback
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        const user = inMemoryUsers.get(emailKey);
        if (!user) throw new Error('Invalid email or password');
        const valid = await bcrypt.compare(data.password, user.password_hash);
        if (!valid) throw new Error('Invalid email or password');
        return {
          id: user.id,
          email: user.email,
          name: user.name,
          phone: user.phone,
          role: user.role,
          fcm_token: user.fcm_token,
        };
      }
      throw err;
    }
  }

  static async updateFcmToken(userId: string, token: string): Promise<void> {
    try {
      await query('UPDATE users SET fcm_token = $1 WHERE id = $2', [token, userId]);
    } catch (err: any) {
      // Fallback
      for (const u of inMemoryUsers.values()) {
        if (u.id === userId) u.fcm_token = token;
      }
    }
  }

  static async getUserById(userId: string): Promise<UserPayload | null> {
    try {
      const res = await query(
        'SELECT id, email, name, phone, role, fcm_token FROM users WHERE id = $1',
        [userId]
      );
      return res.rows[0] || null;
    } catch (err: any) {
      for (const u of inMemoryUsers.values()) {
        if (u.id === userId) {
          return { id: u.id, email: u.email, name: u.name, phone: u.phone, role: u.role, fcm_token: u.fcm_token };
        }
      }
      return null;
    }
  }
}
