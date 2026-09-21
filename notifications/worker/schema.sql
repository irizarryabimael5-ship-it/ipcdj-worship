PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT NOT NULL DEFAULT '',
  language TEXT NOT NULL DEFAULT 'es',
  standalone INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  failure_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_success_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_subscriptions_enabled ON subscriptions(enabled, updated_at);

CREATE TABLE IF NOT EXISTS songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL DEFAULT '',
  active_from TEXT NOT NULL,
  learning_start TEXT NOT NULL,
  learning_end TEXT NOT NULL,
  final_start TEXT NOT NULL,
  final_end TEXT NOT NULL,
  release_day_start_at TEXT NOT NULL,
  release_at TEXT NOT NULL,
  release_day_end_at TEXT NOT NULL,
  rollover_at TEXT NOT NULL,
  introduced_at TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_events (
  event_key TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  source TEXT NOT NULL CHECK(source IN ('auto','manual')),
  song_id TEXT,
  scheduled_at TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  url TEXT NOT NULL DEFAULT '/',
  tag TEXT NOT NULL,
  urgency TEXT NOT NULL DEFAULT 'normal',
  ttl_seconds INTEGER NOT NULL DEFAULT 21600,
  variant_index INTEGER,
  template_version INTEGER,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','sent','cancelled')),
  created_at TEXT NOT NULL,
  sent_at TEXT,
  FOREIGN KEY(song_id) REFERENCES songs(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_events_due ON notification_events(status, scheduled_at);

CREATE TABLE IF NOT EXISTS deliveries (
  event_key TEXT NOT NULL,
  subscription_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sent','retry','gone','failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  response_code INTEGER,
  updated_at TEXT NOT NULL,
  last_error TEXT,
  PRIMARY KEY(event_key, subscription_id),
  FOREIGN KEY(event_key) REFERENCES notification_events(event_key) ON DELETE CASCADE,
  FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_deliveries_pending ON deliveries(event_key, status, attempts);
