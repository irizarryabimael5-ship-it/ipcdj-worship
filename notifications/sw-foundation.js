// IPCDJ Worship service-worker notification helpers.
// Active helper layer imported by the root IPCDJ service worker.
// Keep payload normalization and same-origin click routing generic and song-agnostic.
(function(globalScope){
  "use strict";

  const CONTRACT_VERSION = 1;
  const DEFAULT_URL = "./";

  function asString(value, fallback = "") {
    return typeof value === "string" ? value : fallback;
  }

  function safeSameOriginPath(value) {
    const candidate = asString(value, DEFAULT_URL);
    try {
      const url = new URL(candidate, globalScope.location.origin);
      if (url.origin !== globalScope.location.origin) return DEFAULT_URL;
      return url.pathname + url.search + url.hash;
    } catch (_) {
      return DEFAULT_URL;
    }
  }

  function normalizePayload(input) {
    const payload = input && typeof input === "object" ? input : {};

    return {
      version: Number(payload.version) || CONTRACT_VERSION,
      id: asString(payload.id),
      type: asString(payload.type, "system.announcement"),
      title: asString(payload.title, "IPCDJ Worship"),
      body: asString(payload.body),
      tag: asString(payload.tag, asString(payload.id)),
      url: safeSameOriginPath(payload.url),
      icon: safeSameOriginPath(payload.icon || "./icon-512.png"),
      badge: safeSameOriginPath(payload.badge || "./icon-192.png"),
      timestamp: Number(payload.timestamp) || Date.now(),
      expiresAt: Number(payload.expiresAt) || null,
      renotify: payload.renotify === true,
      silent: payload.silent === true,
      data: payload.data && typeof payload.data === "object" ? payload.data : {}
    };
  }

  function payloadIsExpired(payload, now = Date.now()) {
    return !!(payload.expiresAt && now > payload.expiresAt);
  }

  function toNotificationOptions(payload) {
    const normalized = normalizePayload(payload);
    return {
      body: normalized.body,
      icon: normalized.icon,
      badge: normalized.badge,
      tag: normalized.tag || undefined,
      timestamp: normalized.timestamp,
      renotify: normalized.renotify,
      silent: normalized.silent,
      data: {
        id: normalized.id,
        type: normalized.type,
        url: normalized.url,
        ...normalized.data
      }
    };
  }

  function notificationTarget(notification) {
    const data = notification?.data || {};
    return safeSameOriginPath(data.url || DEFAULT_URL);
  }

  globalScope.IPCDJPushFoundation = Object.freeze({
    CONTRACT_VERSION,
    normalizePayload,
    payloadIsExpired,
    toNotificationOptions,
    notificationTarget,
    safeSameOriginPath
  });
})(self);
