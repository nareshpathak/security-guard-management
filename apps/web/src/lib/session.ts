"use client";

/**
 * The access token is held in a module variable, NOT in localStorage.
 *
 * That is deliberate. The refresh token lives in an httpOnly cookie the page
 * cannot read (see src/app/api/auth/*), and the access token expires in 15
 * minutes, so the worst an injected script can steal is a quarter of an hour
 * rather than a month. The cost is that a page reload starts with no token -
 * AuthProvider fixes that with one silent /api/auth/refresh call on mount.
 */

let accessToken: string | null = null;

const DEVICE = "diti365.device";

export const tokenStore = {
  getAccessToken: () => accessToken,
  setAccessToken: (token: string | null) => {
    accessToken = token;
  },
  clear: () => {
    accessToken = null;
  },
};

/**
 * A stable per-browser identifier so the API can list and revoke sessions by
 * device. This is not a secret, so localStorage is the right home for it.
 */
export function getOrCreateDeviceId(): string {
  if (typeof window === "undefined") return "server";
  let id = window.localStorage.getItem(DEVICE);
  if (!id) {
    id = crypto.randomUUID();
    window.localStorage.setItem(DEVICE, id);
  }
  return id;
}

/**
 * Removes credentials left in localStorage by earlier builds of this app,
 * which stored the refresh token there. Runs once on load.
 */
export function purgeLegacyTokenStorage() {
  if (typeof window === "undefined") return;
  for (const key of ["diti365.access", "diti365.refresh", "diti365.expires", "diti365.user", "diti365.perms"]) {
    window.localStorage.removeItem(key);
  }
}
