import * as SQLite from "expo-sqlite";

/**
 * The local database. Two jobs: the outbox, and cached reads.
 *
 * Guards work in basements, stairwells and industrial estates. The app is
 * offline more often than not, so "write locally, sync later" is the normal
 * path and the network is the exception - not the other way round.
 */

let db: SQLite.SQLiteDatabase | null = null;

export async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;

  db = await SQLite.openDatabaseAsync("diti365.db");

  await db.execAsync(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS outbox (
      id           TEXT PRIMARY KEY,   -- the ClientRequestId sent to the server
      endpoint     TEXT NOT NULL,
      method       TEXT NOT NULL,
      payloadJson  TEXT NOT NULL,
      filesJson    TEXT,               -- local image paths, uploaded before the payload
      label        TEXT NOT NULL,      -- what to call this in the Sync Centre
      createdAt    INTEGER NOT NULL,
      attempts     INTEGER NOT NULL DEFAULT 0,
      nextAttemptAt INTEGER NOT NULL DEFAULT 0,
      lastError    TEXT,
      status       TEXT NOT NULL DEFAULT 'queued'  -- queued | syncing | synced | failed
    );

    CREATE INDEX IF NOT EXISTS ix_outbox_pending
      ON outbox (status, nextAttemptAt);

    CREATE TABLE IF NOT EXISTS cache (
      key        TEXT PRIMARY KEY,
      json       TEXT NOT NULL,
      fetchedAt  INTEGER NOT NULL
    );
  `);

  return db;
}

export type OutboxRow = {
  id: string;
  endpoint: string;
  method: string;
  payloadJson: string;
  filesJson: string | null;
  label: string;
  createdAt: number;
  attempts: number;
  nextAttemptAt: number;
  lastError: string | null;
  status: "queued" | "syncing" | "synced" | "failed";
};

/** Reference data that must survive a cold start with no signal. */
export async function putCache(key: string, value: unknown): Promise<void> {
  const d = await getDb();
  await d.runAsync(
    "INSERT OR REPLACE INTO cache (key, json, fetchedAt) VALUES (?, ?, ?)",
    key,
    JSON.stringify(value),
    Date.now(),
  );
}

export async function getCache<T>(key: string): Promise<{ value: T; fetchedAt: number } | null> {
  const d = await getDb();
  const row = await d.getFirstAsync<{ json: string; fetchedAt: number }>(
    "SELECT json, fetchedAt FROM cache WHERE key = ?",
    key,
  );
  if (!row) return null;
  try {
    return { value: JSON.parse(row.json) as T, fetchedAt: row.fetchedAt };
  } catch {
    return null;
  }
}
