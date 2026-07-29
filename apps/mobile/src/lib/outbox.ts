import * as Crypto from "expo-crypto";
import * as FileSystem from "expo-file-system";
import * as Network from "expo-network";
import { getDb, type OutboxRow } from "./db";
import { getApi, API_BASE_URL } from "./api";
import { tokenStore } from "./session";
import { ApiError } from "@diti365/shared";

/**
 * The outbox.
 *
 * Every field write - punch, QR scan, gate pass, incident, field report, visit,
 * approval, turnout - is written HERE FIRST and only then flushed to the API.
 * Never the other way round. A guard who punches in at 06:00 in a basement car
 * park and surfaces at 14:00 must have a 06:00 punch, not a lost one.
 *
 * The row id IS the ClientRequestId. The server procedures de-duplicate on it,
 * so a retry after a dropped response can never double-count a day. That single
 * decision is what makes the aggressive retry schedule below safe.
 */

/** 5 s, 30 s, 2 min, 10 min, 1 h, then hourly. */
const BACKOFF_MS = [5_000, 30_000, 120_000, 600_000, 3_600_000];

/** After a day of failures the item stops retrying and asks a human. */
const GIVE_UP_AFTER_MS = 24 * 60 * 60 * 1000;

export type QueueInput = {
  endpoint: string;
  method?: "POST" | "PUT" | "PATCH";
  payload: Record<string, unknown>;
  /** Local file URIs to upload before the payload is posted. */
  files?: string[];
  /** Shown in the Sync Centre, e.g. "Punch in - Tower A". */
  label: string;
};

/** Writes the item and returns its ClientRequestId. */
export async function enqueue(input: QueueInput): Promise<string> {
  const db = await getDb();
  const id = Crypto.randomUUID();

  await db.runAsync(
    `INSERT INTO outbox (id, endpoint, method, payloadJson, filesJson, label, createdAt, nextAttemptAt)
     VALUES (?, ?, ?, ?, ?, ?, ?, 0)`,
    id,
    input.endpoint,
    input.method ?? "POST",
    JSON.stringify({ ...input.payload, clientRequestId: id }),
    input.files?.length ? JSON.stringify(input.files) : null,
    input.label,
    Date.now(),
  );

  // Try immediately. If there is no signal this returns straight away and the
  // scheduled flush picks it up later.
  void flush();
  return id;
}

export async function pendingCount(): Promise<number> {
  const db = await getDb();
  const row = await db.getFirstAsync<{ n: number }>(
    "SELECT COUNT(*) AS n FROM outbox WHERE status IN ('queued','syncing','failed')",
  );
  return row?.n ?? 0;
}

export async function listOutbox(): Promise<OutboxRow[]> {
  const db = await getDb();
  return db.getAllAsync<OutboxRow>(
    "SELECT * FROM outbox WHERE status != 'synced' ORDER BY createdAt DESC",
  );
}

export async function discard(id: string): Promise<void> {
  const db = await getDb();
  await db.runAsync("DELETE FROM outbox WHERE id = ?", id);
}

/** Clears the backoff so the next flush picks the item up at once. */
export async function retryNow(id: string): Promise<void> {
  const db = await getDb();
  await db.runAsync(
    "UPDATE outbox SET status = 'queued', nextAttemptAt = 0, lastError = NULL WHERE id = ?",
    id,
  );
  void flush();
}

let flushing = false;

/**
 * Sends everything that is due.
 *
 * Serial, not parallel: a punch-out that overtakes its punch-in produces a
 * shift the server cannot make sense of. Ten items at a time keeps a long
 * offline stretch from blocking the UI thread on reconnect.
 */
export async function flush(): Promise<{ sent: number; failed: number }> {
  if (flushing) return { sent: 0, failed: 0 };

  const state = await Network.getNetworkStateAsync();
  if (!state.isInternetReachable) return { sent: 0, failed: 0 };

  flushing = true;
  let sent = 0;
  let failed = 0;

  try {
    const db = await getDb();
    const due = await db.getAllAsync<OutboxRow>(
      `SELECT * FROM outbox
       WHERE status IN ('queued','failed') AND nextAttemptAt <= ?
       ORDER BY createdAt ASC LIMIT 10`,
      Date.now(),
    );

    /*  A long offline stretch produces a pile of punches. Sending them one at a
        time is a round trip each on a bad connection; /attendance/sync takes
        them together and returns a per-row outcome, so one rejection does not
        fail the rest.  */
    const punches = due.filter((d) => d.endpoint.includes("/attendance/punch-"));
    if (punches.length >= 3) {
      try {
        const outcomes = await getApi().post<
          { clientRequestId: string; success: boolean; message: string }[]
        >(
          "/api/v2/attendance/sync",
          punches.map((p) => ({
            ...JSON.parse(p.payloadJson),
            direction: p.endpoint.endsWith("punch-in") ? "IN" : "OUT",
          })),
        );

        const answered = new Set<string>();
        for (const outcome of outcomes.data ?? []) {
          answered.add(outcome.clientRequestId);
          await db.runAsync(
            "UPDATE outbox SET status = ?, lastError = ? WHERE id = ?",
            outcome.success ? "synced" : "failed",
            outcome.success ? null : outcome.message,
            outcome.clientRequestId,
          );
          if (outcome.success) sent++;
          else failed++;
        }

        // Anything the batch did not answer for falls through to the
        // one-at-a-time path below rather than being silently lost.
        const remaining = due.filter((d) => !answered.has(d.id));
        due.length = 0;
        due.push(...remaining);
      } catch {
        // The batch failed wholesale; the individual path below handles them.
      }
    }

    for (const item of due) {
      await db.runAsync("UPDATE outbox SET status = 'syncing' WHERE id = ?", item.id);

      try {
        const payload = JSON.parse(item.payloadJson) as Record<string, unknown>;

        if (item.filesJson) {
          const files = JSON.parse(item.filesJson) as string[];
          payload.attachments = await uploadFiles(files);
        }

        await getApi().post(item.endpoint, payload);

        await db.runAsync("UPDATE outbox SET status = 'synced' WHERE id = ?", item.id);
        await cleanUpFiles(item.filesJson);
        sent++;
      } catch (error) {
        /*  A duplicate is a SUCCESS, not a failure.

            It means an earlier attempt reached the server and only the response
            was lost. Treating it as an error would leave the item retrying
            forever and show the guard a red badge for a punch that was in fact
            recorded.  */
        if (error instanceof ApiError && error.code === "DUPLICATE_PUNCH") {
          await db.runAsync("UPDATE outbox SET status = 'synced' WHERE id = ?", item.id);
          await cleanUpFiles(item.filesJson);
          sent++;
          continue;
        }

        /*  A 4xx other than 409 will fail identically on every retry - a
            rejected geofence, a malformed payload. Retrying it forever burns
            battery and hides the real problem, so it goes straight to the Sync
            Centre for a human.  */
        const permanent =
          error instanceof ApiError && error.status >= 400 && error.status < 500 && error.status !== 409;

        const attempts = item.attempts + 1;
        const age = Date.now() - item.createdAt;
        const exhausted = permanent || age > GIVE_UP_AFTER_MS;

        await db.runAsync(
          `UPDATE outbox
           SET status = ?, attempts = ?, nextAttemptAt = ?, lastError = ?
           WHERE id = ?`,
          exhausted ? "failed" : "queued",
          attempts,
          exhausted ? 0 : Date.now() + (BACKOFF_MS[Math.min(attempts - 1, BACKOFF_MS.length - 1)]),
          error instanceof Error ? error.message : "Unknown error",
          item.id,
        );
        failed++;
      }
    }
  } finally {
    flushing = false;
  }

  return { sent, failed };
}

/**
 * Uploads images and returns the URLs to reference in the payload.
 *
 * Photographs are uploaded BEFORE the JSON so a punch never lands without its
 * selfie. If the upload fails the whole item is retried, which is safe because
 * the ClientRequestId makes the eventual write idempotent.
 */
async function uploadFiles(files: string[]): Promise<string[]> {
  const urls: string[] = [];

  for (const uri of files) {
    const info = await FileSystem.getInfoAsync(uri);
    if (!info.exists) continue;

    const upload = await FileSystem.uploadAsync(`${API_BASE_URL}/api/v2/documents`, uri, {
      httpMethod: "POST",
      uploadType: FileSystem.FileSystemUploadType.MULTIPART,
      fieldName: "file",
      headers: { Authorization: `Bearer ${tokenStore.getAccessToken() ?? ""}` },
    });

    if (upload.status >= 400) throw new Error(`Photo upload failed (${upload.status})`);

    const body = JSON.parse(upload.body || "{}");
    urls.push(body?.data?.url ?? body?.url ?? uri);
  }

  return urls;
}

async function cleanUpFiles(filesJson: string | null): Promise<void> {
  if (!filesJson) return;
  try {
    for (const uri of JSON.parse(filesJson) as string[]) {
      await FileSystem.deleteAsync(uri, { idempotent: true });
    }
  } catch {
    // A leftover image wastes a little disk. It is not worth failing a
    // successful sync over.
  }
}
