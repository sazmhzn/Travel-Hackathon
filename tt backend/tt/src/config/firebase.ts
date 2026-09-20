import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { env } from './env.js';
import { logger } from '../utils/logger.js';

let messaging: Messaging | null = null;
let initialized = false;

/**
 * Initializes Firebase Admin from FIREBASE_SERVICE_ACCOUNT_KEY (a JSON string).
 * Safe to call at startup; if the key is missing the app runs without FCM.
 */
export function initializeFirebase(): void {
  if (initialized) return;
  initialized = true;

  if (!env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    logger.info('FCM disabled: FIREBASE_SERVICE_ACCOUNT_KEY not set.');
    return;
  }

  try {
    const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_KEY);
    if (getApps().length === 0) {
      initializeApp({ credential: cert(serviceAccount) });
    }
    messaging = getMessaging();
    logger.info('Firebase Admin initialized for FCM push notifications.');
  } catch (err) {
    logger.warn({ err }, 'Failed to initialize Firebase Admin; FCM disabled.');
    messaging = null;
  }
}

/** Returns the messaging client, or null when FCM is not configured. */
export function getFirebaseMessaging(): Messaging | null {
  if (!initialized) initializeFirebase();
  return messaging;
}
