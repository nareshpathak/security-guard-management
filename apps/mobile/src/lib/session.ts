import * as SecureStore from "expo-secure-store";
import * as Crypto from "expo-crypto";

/**
 * Token storage for the phone.
 *
 * Unlike the web app - which keeps the refresh token in an httpOnly cookie the
 * page cannot read - a native app has no cookie jar to hide behind, so the
 * refresh token goes into SecureStore: the Android Keystore, not AsyncStorage.
 * AsyncStorage is a plain SQLite file that any rooted device or backup dumps in
 * cleartext, and this token is worth 30 days of access to a tenant's payroll.
 *
 * The access token stays in memory. It expires in 15 minutes, so persisting it
 * would buy nothing and widen the blast radius.
 */

const REFRESH_KEY = "diti365.refresh";
const DEVICE_KEY = "diti365.device";
const BIOMETRIC_KEY = "diti365.appLock";

let accessToken: string | null = null;

export const tokenStore = {
  getAccessToken: () => accessToken,
  setAccessToken: (token: string | null) => {
    accessToken = token;
  },
  clear: () => {
    accessToken = null;
  },
};

export async function getRefreshToken(): Promise<string | null> {
  return SecureStore.getItemAsync(REFRESH_KEY);
}

export async function setRefreshToken(token: string | null): Promise<void> {
  if (token === null) {
    await SecureStore.deleteItemAsync(REFRESH_KEY);
    return;
  }
  await SecureStore.setItemAsync(REFRESH_KEY, token, {
    keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  });
}

/**
 * A stable per-installation id, used for device binding.
 *
 * The legacy app called this "checkdeviceid" and used it to stop one guard
 * sharing his login with another. Reinstalling generates a new one, which is
 * why a mismatch asks an admin to reset rather than locking the user out.
 */
export async function getDeviceId(): Promise<string> {
  const existing = await SecureStore.getItemAsync(DEVICE_KEY);
  if (existing) return existing;

  const id = Crypto.randomUUID();
  await SecureStore.setItemAsync(DEVICE_KEY, id, {
    keychainAccessible: SecureStore.ALWAYS_THIS_DEVICE_ONLY,
  });
  return id;
}

export async function isAppLockEnabled(): Promise<boolean> {
  return (await SecureStore.getItemAsync(BIOMETRIC_KEY)) === "1";
}

export async function setAppLockEnabled(on: boolean): Promise<void> {
  await SecureStore.setItemAsync(BIOMETRIC_KEY, on ? "1" : "0");
}

export async function clearSession(): Promise<void> {
  tokenStore.clear();
  await setRefreshToken(null);
  // The device id deliberately survives sign-out: it identifies the handset,
  // not the person, and losing it would trigger a device-binding reset on every
  // ordinary logout.
}
