import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as Battery from "expo-battery";
import { getApi } from "./api";
import { getDb } from "./db";
import { getDeviceId, tokenStore } from "./session";

/**
 * Background duty tracking.
 *
 * Starts at punch-in and stops at punch-out. Never runs otherwise: a guard's
 * location off-shift is not the agency's business, and a tracker that runs all
 * day is a tracker people uninstall.
 *
 * Pings are buffered locally and posted in batches, because a guard walking a
 * basement will produce twenty fixes with no signal and then surface. The batch
 * endpoint accepts spoofed pings and flags them rather than rejecting the lot.
 */

export const TASK_NAME = "diti365-duty-location";

const PING_TABLE = `
  CREATE TABLE IF NOT EXISTS pings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    accuracy REAL,
    speed REAL,
    battery INTEGER,
    loggedAt TEXT NOT NULL,
    source TEXT NOT NULL,
    isMock INTEGER NOT NULL DEFAULT 0
  );
`;

async function pingDb() {
  const db = await getDb();
  await db.execAsync(PING_TABLE);
  return db;
}

/**
 * Registered at module load so the OS can revive it after the app is killed.
 * A task defined only inside a component would be gone the moment Android
 * reclaims the process, which is exactly when it matters most.
 */
TaskManager.defineTask(TASK_NAME, async ({ data, error }) => {
  if (error || !data) return;

  const { locations } = data as { locations: Location.LocationObject[] };
  if (!locations?.length) return;

  const db = await pingDb();
  let battery = -1;
  try {
    battery = Math.round((await Battery.getBatteryLevelAsync()) * 100);
  } catch {
    // Battery level is nice to have, not worth losing a ping over.
  }

  for (const l of locations) {
    await db.runAsync(
      `INSERT INTO pings (latitude, longitude, accuracy, speed, battery, loggedAt, source, isMock)
       VALUES (?, ?, ?, ?, ?, ?, 'BG', ?)`,
      l.coords.latitude,
      l.coords.longitude,
      l.coords.accuracy ?? null,
      l.coords.speed ?? null,
      battery >= 0 ? battery : null,
      new Date(l.timestamp).toISOString(),
      l.mocked ? 1 : 0,
    );
  }

  await flushPings();
});

/** Sends buffered pings. Safe to call at any time; does nothing when empty. */
export async function flushPings(): Promise<void> {
  if (!tokenStore.getAccessToken()) return;

  const db = await pingDb();
  const rows = await db.getAllAsync<{
    id: number;
    latitude: number;
    longitude: number;
    accuracy: number | null;
    speed: number | null;
    battery: number | null;
    loggedAt: string;
    source: string;
    isMock: number;
  }>("SELECT * FROM pings ORDER BY id ASC LIMIT 200");

  if (rows.length === 0) return;

  try {
    await getApi().post("/api/v2/tracking/ping/batch", {
      deviceId: await getDeviceId(),
      pings: rows.map((r) => ({
        latitude: r.latitude,
        longitude: r.longitude,
        accuracy: r.accuracy ?? undefined,
        speed: r.speed ?? undefined,
        batteryLevel: r.battery ?? undefined,
        loggedAt: r.loggedAt,
        source: r.source,
        isMockLocation: r.isMock === 1,
      })),
    });

    await db.runAsync(
      `DELETE FROM pings WHERE id <= ?`,
      rows[rows.length - 1].id,
    );
  } catch {
    // No signal. They stay in the table and go with the next batch.
  }
}

/** A single immediate fix, used when a supervisor asks "where are you now". */
export async function pingNow(): Promise<void> {
  const { status } = await Location.getForegroundPermissionsAsync();
  if (status !== "granted") return;

  const p = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
  let battery: number | undefined;
  try {
    battery = Math.round((await Battery.getBatteryLevelAsync()) * 100);
  } catch {
    battery = undefined;
  }

  await getApi().post("/api/v2/tracking/ping", {
    latitude: p.coords.latitude,
    longitude: p.coords.longitude,
    accuracy: p.coords.accuracy ?? undefined,
    batteryLevel: battery,
    loggedAt: new Date(p.timestamp).toISOString(),
    source: "FG",
    isMockLocation: Boolean(p.mocked),
    deviceId: await getDeviceId(),
  });
}

export async function isTracking(): Promise<boolean> {
  return Location.hasStartedLocationUpdatesAsync(TASK_NAME);
}

/**
 * Called at punch-in.
 *
 * Background permission is requested separately and AFTER foreground, which is
 * what Android requires and what gives the user a fighting chance of
 * understanding what they are agreeing to.
 */
export async function startDutyTracking(): Promise<{ started: boolean; reason?: string }> {
  const fg = await Location.requestForegroundPermissionsAsync();
  if (fg.status !== "granted") return { started: false, reason: "Location permission was refused." };

  const bg = await Location.requestBackgroundPermissionsAsync();
  if (bg.status !== "granted")
    return {
      started: false,
      reason:
        "Background location was refused. Your duty location will only be recorded while the app is open.",
    };

  if (await isTracking()) return { started: true };

  await Location.startLocationUpdatesAsync(TASK_NAME, {
    accuracy: Location.Accuracy.Balanced,
    timeInterval: 2 * 60 * 1000,
    distanceInterval: 50,
    pausesUpdatesAutomatically: false,
    // The notification is not optional on Android and should not be: someone
    // being tracked is entitled to see that they are being tracked.
    foregroundService: {
      notificationTitle: "Diti365 is recording your duty location",
      notificationBody: "This stops automatically when you punch out.",
      notificationColor: "#0B5FFF",
    },
  });

  return { started: true };
}

/** Called at punch-out. Sends whatever is left before stopping. */
export async function stopDutyTracking(): Promise<void> {
  await flushPings();
  if (await isTracking()) await Location.stopLocationUpdatesAsync(TASK_NAME);
}
