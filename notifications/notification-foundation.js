// IPCDJ Worship notification client foundation.
// DORMANT: this module is not imported by the live site yet and has no side effects.

export const IPCDJ_NOTIFICATION_FOUNDATION_VERSION = 1;

export const IPCDJ_NOTIFICATION_CATEGORIES = Object.freeze({
  SONG_PHASES: "song_phases",
  ESTRENO: "estreno",
  LIVE_SET: "live_set",
  ANNOUNCEMENTS: "announcements"
});

export const IPCDJ_DEFAULT_NOTIFICATION_PREFERENCES = Object.freeze({
  song_phases: false,
  estreno: false,
  live_set: false,
  announcements: false
});

export function getNotificationCapabilities() {
  const secure = window.isSecureContext === true;
  const serviceWorker = "serviceWorker" in navigator;
  const notifications = "Notification" in window;
  const pushManager = "PushManager" in window;
  const standalone =
    (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches) ||
    window.navigator.standalone === true;

  return Object.freeze({
    secure,
    serviceWorker,
    notifications,
    pushManager,
    standalone,
    permission: notifications ? Notification.permission : "unsupported",
    supported: secure && serviceWorker && notifications && pushManager
  });
}

export function normalizeNotificationPreferences(input = {}) {
  const result = { ...IPCDJ_DEFAULT_NOTIFICATION_PREFERENCES };
  for (const key of Object.keys(result)) {
    result[key] = input[key] === true;
  }
  return Object.freeze(result);
}

export async function getExistingPushSubscription(registration) {
  if (!registration || !registration.pushManager) return null;
  return registration.pushManager.getSubscription();
}

export function urlBase64ToUint8Array(value) {
  const padding = "=".repeat((4 - (value.length % 4)) % 4);
  const normalized = (value + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(normalized);
  return Uint8Array.from(raw, character => character.charCodeAt(0));
}

export async function createPushSubscription({ registration, vapidPublicKey }) {
  if (!registration || !registration.pushManager) {
    throw new Error("PushManager unavailable");
  }
  if (!vapidPublicKey) {
    throw new Error("VAPID public key required");
  }

  // IMPORTANT: callers must invoke this function only inside a deliberate
  // user-activation flow. This helper intentionally does not request permission.
  return registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
  });
}

export function serializePushSubscription(subscription) {
  if (!subscription) return null;
  const json = subscription.toJSON ? subscription.toJSON() : {};
  return {
    endpoint: subscription.endpoint || json.endpoint || "",
    expirationTime: subscription.expirationTime ?? json.expirationTime ?? null,
    keys: {
      p256dh: json.keys?.p256dh || "",
      auth: json.keys?.auth || ""
    }
  };
}

export function createAnonymousInstallationId(storage = localStorage) {
  const key = "ipcdj-push-installation-id-v1";
  try {
    const existing = storage.getItem(key);
    if (existing) return existing;

    const value =
      globalThis.crypto?.randomUUID?.() ||
      "ipcdj-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2);

    storage.setItem(key, value);
    return value;
  } catch (_) {
    return globalThis.crypto?.randomUUID?.() || "ipcdj-" + Date.now().toString(36);
  }
}

export function buildSubscriptionRecord({
  subscription,
  preferences,
  installationId,
  appBuild = "",
  locale = navigator.language || "es"
}) {
  const serialized = serializePushSubscription(subscription);
  if (!serialized) throw new Error("Push subscription required");

  return Object.freeze({
    contractVersion: 1,
    installationId,
    subscription: serialized,
    preferences: normalizeNotificationPreferences(preferences),
    appBuild,
    locale,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null
  });
}
