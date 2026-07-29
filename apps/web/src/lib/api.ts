"use client";

import { createApiClient, type ApiClient, type ClientSession } from "@diti365/shared";
import { getOrCreateDeviceId, tokenStore } from "./session";

/**
 * HTTPS by default. The API refuses plain HTTP - that is the whole point of
 * replacing the legacy app, which shipped with usesCleartextTraffic="true".
 */
const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://localhost:7175";

let client: ApiClient | null = null;

/**
 * Asks our own route handler to mint a new access token from the httpOnly
 * refresh cookie. Returns the full profile too, which is how a page reload
 * restores the session.
 */
export async function refreshSession(): Promise<ClientSession | null> {
  const res = await fetch("/api/auth/refresh", { method: "POST" });
  if (!res.ok) return null;
  const json = await res.json();
  return json?.data ?? null;
}

export function getApi(): ApiClient {
  if (!client) {
    client = createApiClient({
      baseUrl,
      tokenStore,
      getDeviceId: getOrCreateDeviceId,
      refreshAccessToken: async () => (await refreshSession())?.accessToken ?? null,
      onUnauthorized: () => {
        tokenStore.clear();
        if (typeof window !== "undefined" && !window.location.pathname.startsWith("/login")) {
          window.location.href = `/login?next=${encodeURIComponent(window.location.pathname)}`;
        }
      },
    });
  }
  return client;
}

export { baseUrl as apiBaseUrl };
