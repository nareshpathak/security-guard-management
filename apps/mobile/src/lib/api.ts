import Constants from "expo-constants";
import { createApiClient, type ApiClient } from "@diti365/shared";
import { getDeviceId, getRefreshToken, setRefreshToken, tokenStore } from "./session";

/**
 * HTTPS only. The legacy build shipped with usesCleartextTraffic="true", which
 * meant a guard on a cafe wifi handed his session to anyone listening.
 */
export const API_BASE_URL =
  process.env.EXPO_PUBLIC_API_BASE_URL ??
  (Constants.expoConfig?.extra?.apiBaseUrl as string | undefined) ??
  "https://localhost:7175";

let client: ApiClient | null = null;
let onSessionLost: (() => void) | null = null;

export function setSessionLostHandler(fn: () => void) {
  onSessionLost = fn;
}

export function getApi(): ApiClient {
  if (!client) {
    client = createApiClient({
      baseUrl: API_BASE_URL,
      tokenStore,
      /*  The phone holds the refresh token itself, so it calls the API
          directly. The web app passes a different callback that goes via its
          own route handler. Same client, two custody models.  */
      refreshAccessToken: async () => {
        const refresh = await getRefreshToken();
        if (!refresh) return null;

        const res = await fetch(`${API_BASE_URL}/api/v2/auth/refresh`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken: refresh, deviceId: await getDeviceId() }),
        });

        if (!res.ok) {
          // The API revokes the whole family when it sees a replayed refresh
          // token, so a failure here means the session is genuinely finished.
          await setRefreshToken(null);
          return null;
        }

        const json = await res.json();
        if (!json?.data?.accessToken) return null;

        await setRefreshToken(json.data.refreshToken);
        return json.data.accessToken as string;
      },
      onUnauthorized: () => onSessionLost?.(),
    });
  }
  return client;
}
