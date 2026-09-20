import bcrypt from 'bcryptjs';
import { query } from '../../config/database.js';

export interface UserPayload {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: 'GUIDE' | 'MEMBER' | 'ADMIN';
  fcm_token?: string;
  device_id?: string | null;
  bluetooth_name?: string | null;
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
    deviceId?: string;
    bluetoothName?: string;
  }): Promise<UserPayload> {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(data.password, salt);
    const role = data.role || 'MEMBER';
    const emailKey = data.email.toLowerCase();

    try {
      const res = await query(
        `INSERT INTO users (email, password_hash, name, phone, role, device_id, bluetooth_name)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, email, name, phone, role, fcm_token, device_id, bluetooth_name`,
        [
          emailKey,
          passwordHash,
          data.name,
          data.phone || null,
          role,
          data.deviceId || null,
          data.bluetoothName || null,
        ]
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
          device_id: data.deviceId,
          bluetooth_name: data.bluetoothName,
          password_hash: passwordHash,
        };
        inMemoryUsers.set(emailKey, user);
        return {
          id: user.id,
          email: user.email,
          name: user.name,
          phone: user.phone,
          role: user.role,
          device_id: user.device_id,
          bluetooth_name: user.bluetooth_name,
        };
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
    deviceId?: string;
    bluetoothName?: string;
  }): Promise<UserPayload> {
    const emailKey = data.email.toLowerCase();
    const hasIdentity =
      (data.deviceId && data.deviceId.length > 0) ||
      (data.bluetoothName && data.bluetoothName.length > 0);

    try {
      const res = await query(
        `SELECT id, email, password_hash, name, phone, role, fcm_token, device_id, bluetooth_name
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

      // Bind this device's Bluetooth identity to the profile on login.
      if (hasIdentity) {
        const updated = await query(
          `UPDATE users
           SET device_id = COALESCE($2, device_id),
               bluetooth_name = COALESCE($3, bluetooth_name),
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $1
           RETURNING id, email, name, phone, role, fcm_token, device_id, bluetooth_name`,
          [user.id, data.deviceId || null, data.bluetoothName || null]
        );
        return updated.rows[0];
      }

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        phone: user.phone,
        role: user.role,
        fcm_token: user.fcm_token,
        device_id: user.device_id,
        bluetooth_name: user.bluetooth_name,
      };
    } catch (err: any) {
      // In-memory fallback
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        const user = inMemoryUsers.get(emailKey);
        if (!user) throw new Error('Invalid email or password');
        const valid = await bcrypt.compare(data.password, user.password_hash);
        if (!valid) throw new Error('Invalid email or password');
        if (hasIdentity) {
          if (data.deviceId) user.device_id = data.deviceId;
          if (data.bluetoothName) user.bluetooth_name = data.bluetoothName;
        }
        return {
          id: user.id,
          email: user.email,
          name: user.name,
          phone: user.phone,
          role: user.role,
          fcm_token: user.fcm_token,
          device_id: user.device_id,
          bluetooth_name: user.bluetooth_name,
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
        'SELECT id, email, name, phone, role, fcm_token, device_id, bluetooth_name FROM users WHERE id = $1',
        [userId]
      );
      return res.rows[0] || null;
    } catch (err: any) {
      for (const u of inMemoryUsers.values()) {
        if (u.id === userId) {
          return {
            id: u.id,
            email: u.email,
            name: u.name,
            phone: u.phone,
            role: u.role,
            fcm_token: u.fcm_token,
            device_id: u.device_id,
            bluetooth_name: u.bluetooth_name,
          };
        }
      }
      return null;
    }
  }
}
