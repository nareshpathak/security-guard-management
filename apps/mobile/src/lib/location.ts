import * as Location from "expo-location";

/**
 * Location, with the honesty the legacy app lacked.
 *
 * Two rules the server also enforces, checked here so the guard finds out
 * before he takes a selfie rather than after:
 *   - a fix worse than 50 m is not good enough to prove he is on site
 *   - a mocked fix is refused outright for attendance
 */

export const REQUIRED_ACCURACY_METERS = 50;

export type Fix = {
  latitude: number;
  longitude: number;
  accuracy: number;
  isMocked: boolean;
  capturedAt: string;
};

export class LocationError extends Error {
  constructor(
    message: string,
    readonly reason: "permission" | "services" | "accuracy" | "mocked" | "timeout",
  ) {
    super(message);
  }
}

export async function requestForegroundPermission(): Promise<boolean> {
  const { status } = await Location.requestForegroundPermissionsAsync();
  return status === "granted";
}

export async function getFix(): Promise<Fix> {
  if (!(await Location.hasServicesEnabledAsync()))
    throw new LocationError("Turn on location to record your duty.", "services");

  const { status } = await Location.getForegroundPermissionsAsync();
  if (status !== "granted")
    throw new LocationError("Diti365 needs location permission to record your duty.", "permission");

  const position = await Location.getCurrentPositionAsync({
    accuracy: Location.Accuracy.High,
    mayShowUserSettingsDialog: true,
  });

  const accuracy = position.coords.accuracy ?? 9999;

  /*  `mocked` is reported by Android. It is not proof of honesty - a determined
      spoofer can hide it - but refusing the obvious cases costs nothing and
      stops the casual "punch in from home" app.  */
  if (position.mocked)
    throw new LocationError(
      "This device is reporting a fake location. Turn off any mock-location app.",
      "mocked",
    );

  if (accuracy > REQUIRED_ACCURACY_METERS)
    throw new LocationError(
      `Your location is only accurate to ${Math.round(accuracy)} m. Step outside and try again.`,
      "accuracy",
    );

  return {
    latitude: position.coords.latitude,
    longitude: position.coords.longitude,
    accuracy,
    isMocked: Boolean(position.mocked),
    capturedAt: new Date(position.timestamp).toISOString(),
  };
}

/** Great-circle distance in metres. Same formula as dbo.fnDistanceMeters. */
export function distanceMeters(
  lat1: number, lon1: number, lat2: number, lon2: number,
): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}
