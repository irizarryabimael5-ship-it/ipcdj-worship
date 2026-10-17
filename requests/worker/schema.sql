-- IPCDJ Requests v1: isolated staging database (never reuse Web Push D1).
-- Cloudflare D1 already enforces foreign keys and forbids changing this PRAGMA in SQL migrations.
CREATE TABLE IF NOT EXISTS song_requests(
  id TEXT PRIMARY KEY,
  canonical_key TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  link_url TEXT NOT NULL DEFAULT '',
  comment TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','held','approved','rejected','published')),
  request_count INTEGER NOT NULL DEFAULT 1 CHECK(request_count>=1),
  created_at TEXT NOT NULL,
  last_requested_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  published_at TEXT,
  artwork_url TEXT NOT NULL DEFAULT '',
  preview_url TEXT NOT NULL DEFAULT '',
  metadata_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_request_review ON song_requests(status,last_requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_request_published ON song_requests(status,published_at DESC,id);
CREATE TABLE IF NOT EXISTS request_submissions(
  idempotency_hash TEXT PRIMARY KEY,
  payload_hash TEXT NOT NULL,
  request_id TEXT NOT NULL REFERENCES song_requests(id),
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_request_submissions_created ON request_submissions(created_at);
CREATE TABLE IF NOT EXISTS request_rate_events(
  id TEXT PRIMARY KEY,
  ip_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_request_rate_window ON request_rate_events(ip_hash,created_at);
-- A pre-read rate check alone can race. This trigger is the final, transactional
-- per-IP rolling-hour cap, preventing two concurrent writes from bypassing it.
CREATE TRIGGER IF NOT EXISTS request_rate_cap BEFORE INSERT ON request_rate_events
BEGIN
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM request_rate_events
    WHERE ip_hash=NEW.ip_hash
      AND created_at>=strftime('%Y-%m-%dT%H:%M:%fZ',NEW.created_at,'-1 hour')
  )>=5 THEN RAISE(ABORT,'rate-limited') END;
END;
CREATE TABLE IF NOT EXISTS request_outbox(
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES song_requests(id),
  event_type TEXT NOT NULL CHECK(event_type IN('new_submission','review_action')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','sending','sent','retry','failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0),
  created_at TEXT NOT NULL,
  next_attempt_at TEXT NOT NULL,
  sent_at TEXT,
  last_error TEXT
);
CREATE INDEX IF NOT EXISTS idx_request_outbox_due ON request_outbox(status,next_attempt_at);
CREATE TABLE IF NOT EXISTS request_audit(
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES song_requests(id),
  previous_status TEXT NOT NULL,
  next_status TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_request_audit_request ON request_audit(request_id,created_at);

-- Server-owned admin audit, transactional with the status update.
-- The Worker never trusts an uncommitted old status when logging a transition.
CREATE TRIGGER IF NOT EXISTS song_request_status_audit
AFTER UPDATE OF status ON song_requests
WHEN NEW.status<>OLD.status
BEGIN
  INSERT INTO request_audit(id,request_id,previous_status,next_status,created_at)
  VALUES(lower(hex(randomblob(16))),NEW.id,OLD.status,NEW.status,NEW.updated_at);
END;

-- One-shot Staging Gmail delivery probe. DB primary key prevents repeated sends.
CREATE TABLE IF NOT EXISTS email_probe_results(
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL CHECK(status IN('attempting','accepted','failed')),
  started_at TEXT NOT NULL,
  completed_at TEXT,
  message_id TEXT,
  error_code TEXT
);
