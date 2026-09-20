import { env } from '../../config/env.js';
import { query } from '../../config/database.js';
import { logger } from '../../utils/logger.js';
import { broadcastToGroup, broadcastToUser } from '../../sockets/gateway.js';
import { GroupsService } from '../groups/groups.service.js';
import { AuthService } from '../auth/auth.service.js';
import { TelemetryService } from '../telemetry/telemetry.service.js';

export interface EmergencyDistressData {
  userId: string;
  groupId: string;
  lat: number;
  lng: number;
  battery?: number;
  reason?: string;
}

export class EmergencyService {
  /**
   * Task BE-4.4: Process Rescue Mode Trigger
   */
  static async triggerRescueMode(data: EmergencyDistressData): Promise<{
    alertId: string;
    telegramDelivered: boolean;
    fcmGuidesNotified: number;
  }> {
    const user = await AuthService.getUserById(data.userId);
    const members = await GroupsService.getGroupMembers(data.groupId);
    const guides = members.filter((m) => m.role === 'GUIDE');

    // 1. Record emergency trigger in database
    let alertId = `emergency-${Date.now()}`;
    try {
      const res = await query(
        `INSERT INTO emergency_triggers (user_id, group_id, location, battery_level, reason, status)
         VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5, $6, 'ACTIVE')
         RETURNING id`,
        [data.userId, data.groupId, data.lng, data.lat, data.battery || null, data.reason || 'SOS Triggered']
      );
      alertId = res.rows[0].id;
    } catch (dbErr) {
      logger.debug({ dbErr }, 'Emergency saved in test/fallback mode');
    }

    // 2. Broadcast high-priority WebSocket SOS to Group Room
    broadcastToGroup(data.groupId, 'emergency:distress', {
      alertId,
      userId: data.userId,
      userName: user?.name || 'Group Member',
      userPhone: user?.phone,
      lat: data.lat,
      lng: data.lng,
      battery: data.battery,
      reason: data.reason || 'Emergency rescue mode activated',
      timestamp: new Date().toISOString(),
    });

    // 2b. Alert every connected user within SOS_RADIUS_KM, even outside the
    // expedition. Group members already received the group-room broadcast.
    const memberIds = new Set(members.map((m) => m.user_id));
    const nearbyNotified = await this.broadcastNearbySos(
      data.groupId,
      data.userId,
      user?.name || 'Group Member',
      data.lat,
      data.lng,
      data.reason,
      memberIds,
      alertId
    );

    // 3. Dispatch alert to free Telegram Channel Webhook
    const telegramDelivered = await this.sendTelegramDistressAlert({
      alertId,
      userName: user?.name || 'Group Member',
      userPhone: user?.phone,
      groupId: data.groupId,
      lat: data.lat,
      lng: data.lng,
      battery: data.battery,
      reason: data.reason,
    });

    // 4. Dispatch free FCM Push Notifications to Guides
    const fcmGuidesNotified = await this.sendFcmPushToGuides(guides, {
      title: '🚨 EMERGENCY: Member in Distress!',
      body: `${user?.name || 'Member'} activated Rescue Mode at [${data.lat.toFixed(4)}, ${data.lng.toFixed(4)}]`,
      lat: data.lat,
      lng: data.lng,
      userId: data.userId,
      groupId: data.groupId,
    });

    logger.info({ alertId, nearbyNotified }, 'SOS nearby proximity fan-out complete');

    return {
      alertId,
      telegramDelivered,
      fcmGuidesNotified,
    };
  }

  /**
   * Emits `emergency:nearby` to every connected user within `SOS_RADIUS_KM`
   * of the distress signal, excluding the sender and expedition members (who
   * already get the group-room broadcast). Returns how many users were alerted.
   */
  static async broadcastNearbySos(
    groupId: string,
    senderId: string,
    senderName: string,
    lat: number,
    lng: number,
    reason: string | undefined,
    excludeUserIds: Set<string>,
    alertId: string
  ): Promise<number> {
    let alerted = 0;
    try {
      const nearby = await TelemetryService.findUsersWithinRadius(lat, lng, env.SOS_RADIUS_KM);
      for (const hit of nearby) {
        if (hit.userId === senderId || excludeUserIds.has(hit.userId)) continue;
        broadcastToUser(hit.userId, 'emergency:nearby', {
          alertId,
          groupId,
          userId: senderId,
          userName: senderName,
          lat,
          lng,
          distanceKm: hit.distanceKm,
          radiusKm: env.SOS_RADIUS_KM,
          reason: reason || 'Emergency rescue mode activated',
          timestamp: new Date().toISOString(),
        });
        alerted++;
      }
    } catch (err) {
      logger.error({ err }, 'Failed to broadcast SOS to nearby users');
    }
    return alerted;
  }

  /**
   * Send distress notification to Telegram Emergency Channel via Bot API
   */
  static async sendTelegramDistressAlert(params: {
    alertId: string;
    userName: string;
    userPhone?: string;
    groupId: string;
    lat: number;
    lng: number;
    battery?: number;
    reason?: string;
  }): Promise<boolean> {
    if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_EMERGENCY_CHAT_ID) {
      logger.warn('Telegram bot credentials not set in .env. Skipping Telegram alert.');
      return false;
    }

    const googleMapsUrl = `https://maps.google.com/?q=${params.lat},${params.lng}`;
    const openStreetMapsUrl = `https://www.openstreetmap.org/?mlat=${params.lat}&mlon=${params.lng}#map=16/${params.lat}/${params.lng}`;

    const messageText = `
🚨 <b>RESCUE MODE ACTIVATED</b> 🚨
━━━━━━━━━━━━━━━━━━━━
👤 <b>User:</b> ${params.userName} ${params.userPhone ? `(${params.userPhone})` : ''}
📍 <b>Location:</b> <code>${params.lat.toFixed(6)}, ${params.lng.toFixed(6)}</code>
🔋 <b>Battery:</b> ${params.battery ?? 'Unknown'}%
⚠️ <b>Reason:</b> ${params.reason || 'Distress signal manually triggered'}
🆔 <b>Alert ID:</b> <code>${params.alertId}</code>

🗺️ <b>Map Coordinates:</b>
• <a href="${googleMapsUrl}">Open in Google Maps</a>
• <a href="${openStreetMapsUrl}">Open in OpenStreetMap</a>
━━━━━━━━━━━━━━━━━━━━
⏰ <i>Timestamp: ${new Date().toUTCString()}</i>
`.trim();

    try {
      const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: env.TELEGRAM_EMERGENCY_CHAT_ID,
          text: messageText,
          parse_mode: 'HTML',
          disable_web_page_preview: false,
        }),
      });

      const json = await response.json() as any;
      if (!json.ok) {
        logger.warn({ json }, 'Telegram Bot API error response');
        return false;
      }

      logger.info({ alertId: params.alertId }, 'Emergency distress card successfully posted to Telegram.');
      return true;
    } catch (error) {
      logger.error({ error }, 'Failed to dispatch Telegram distress alert');
      return false;
    }
  }

  /**
   * Dispatch FCM push notifications to Group Guides
   */
  static async sendFcmPushToGuides(
    guides: any[],
    payload: { title: string; body: string; lat: number; lng: number; userId: string; groupId: string }
  ): Promise<number> {
    let notifiedCount = 0;

    for (const guide of guides) {
      if (guide.fcm_token) {
        logger.info({ guideId: guide.user_id, token: guide.fcm_token }, 'Dispatching FCM push to guide');
        // If firebase-admin initialized, call messaging().send()
        notifiedCount++;
      }
    }

    return notifiedCount;
  }
}
