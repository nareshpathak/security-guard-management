import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { AuthUser, LoginResponse } from "@diti365/shared";
import { getApi, setSessionLostHandler, API_BASE_URL } from "./api";
import { clearSession, getDeviceId, getRefreshToken, setRefreshToken, tokenStore } from "./session";
import { putCache, getCache } from "./db";

type AuthState = {
  user: AuthUser | null;
  permissions: string[];
  ready: boolean;
  login: (loginId: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  has: (code: string) => boolean;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setSessionLostHandler(() => {
      void clearSession();
      setUser(null);
      setPermissions([]);
    });

    (async () => {
      /*  Show the cached profile immediately so a guard opening the app in a
          basement sees his own name and unit rather than a login screen. The
          refresh below corrects it when there is signal; if the refresh fails
          he is signed out, but not before he has seen something useful.  */
      const cached = await getCache<{ user: AuthUser; permissions: string[] }>("session");
      if (cached) {
        setUser(cached.value.user);
        setPermissions(cached.value.permissions);
      }

      const refresh = await getRefreshToken();
      if (!refresh) {
        setUser(null);
        setPermissions([]);
        setReady(true);
        return;
      }

      try {
        const res = await fetch(`${API_BASE_URL}/api/v2/auth/refresh`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken: refresh, deviceId: await getDeviceId() }),
        });

        if (res.ok) {
          const json = await res.json();
          const data = json.data as LoginResponse;
          tokenStore.setAccessToken(data.accessToken);
          await setRefreshToken(data.refreshToken);
          setUser(data.user);
          setPermissions(data.permissions ?? []);
          await putCache("session", { user: data.user, permissions: data.permissions ?? [] });
        } else if (res.status === 401) {
          // Genuinely rejected, not merely unreachable: end the session.
          await clearSession();
          setUser(null);
          setPermissions([]);
        }
        // Any other failure is treated as "no signal" and the cached profile
        // stands. The first authenticated call will retry the refresh.
      } catch {
        // Offline. Keep whatever the cache gave us.
      }

      setReady(true);
    })();
  }, []);

  const login = useCallback(async (loginId: string, password: string) => {
    const { data } = await getApi().post<LoginResponse>("/api/v2/auth/login", {
      loginId,
      password,
      deviceId: await getDeviceId(),
      platform: "android",
      appVersion: "1.0.0",
    });

    tokenStore.setAccessToken(data.accessToken);
    await setRefreshToken(data.refreshToken);
    setUser(data.user);
    setPermissions(data.permissions ?? []);
    await putCache("session", { user: data.user, permissions: data.permissions ?? [] });
  }, []);

  const logout = useCallback(async () => {
    try {
      const refresh = await getRefreshToken();
      if (refresh) await getApi().post("/api/v2/auth/logout", { refreshToken: refresh });
    } catch {
      // Signing out must work with no signal. The refresh token is destroyed
      // locally either way; the server copy expires on its own.
    } finally {
      await clearSession();
      await putCache("session", null);
      setUser(null);
      setPermissions([]);
    }
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      permissions,
      ready,
      login,
      logout,
      has: (code) => permissions.includes(code),
    }),
    [user, permissions, ready, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}

/**
 * Which home screen this user gets.
 *
 * Mirrors the legacy fragments - HomeAdmin_frag, HomeSupervisor_frag,
 * HomeGatekeeper_frag, HomeNightPatrol_frag, HomeSales_frag - but keyed off the
 * role code rather than an integer loginType nobody could read.
 */
export type Persona = "guard" | "supervisor" | "patrol" | "gatekeeper" | "sales" | "admin" | "client";

export function personaFor(user: AuthUser | null): Persona {
  switch (user?.roleCode) {
    case "SUPER_ADMIN":
    case "COMPANY_ADMIN":
    case "BRANCH_ADMIN":
    case "OPERATIONS":
      return "admin";
    case "SUPERVISOR":
      return "supervisor";
    case "NIGHT_PATROL":
      return "patrol";
    case "GATEKEEPER":
      return "gatekeeper";
    case "SALES":
      return "sales";
    case "CLIENT":
      return "client";
    default:
      return "guard";
  }
}
