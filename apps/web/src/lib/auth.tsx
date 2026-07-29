"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { AuthUser } from "@diti365/shared";
import { loginSchema } from "@diti365/shared";
import { getApi, refreshSession } from "./api";
import { getOrCreateDeviceId, purgeLegacyTokenStorage, tokenStore } from "./session";

type AuthState = {
  user: AuthUser | null;
  permissions: string[];
  /** False until the silent refresh on mount has settled. Guards route redirects. */
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

  // The access token lives in memory, so a reload starts with nothing. One
  // silent refresh against the httpOnly cookie rebuilds the whole session.
  useEffect(() => {
    let cancelled = false;
    purgeLegacyTokenStorage();

    (async () => {
      const session = await refreshSession().catch(() => null);
      if (cancelled) return;
      if (session) {
        tokenStore.setAccessToken(session.accessToken);
        setUser(session.user as AuthUser);
        setPermissions(session.permissions ?? []);
      }
      setReady(true);
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (loginId: string, password: string) => {
    loginSchema.parse({ loginId, password });

    // Goes to our own route handler, not the .NET API: it needs to set the
    // httpOnly refresh cookie, which only the server can do.
    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ loginId, password, deviceId: getOrCreateDeviceId() }),
    });

    const json = await res.json().catch(() => null);
    if (!res.ok) {
      throw new Error(json?.detail ?? json?.title ?? "Sign-in failed. Check your details.");
    }

    tokenStore.setAccessToken(json.data.accessToken);
    setUser(json.data.user);
    setPermissions(json.data.permissions ?? []);
  }, []);

  const logout = useCallback(async () => {
    try {
      await fetch("/api/auth/logout", { method: "POST" });
    } finally {
      tokenStore.clear();
      setUser(null);
      setPermissions([]);
      // Drop every cached tenant response so the next user cannot see it.
      getApi();
      if (typeof window !== "undefined") window.location.href = "/login";
    }
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      permissions,
      ready,
      login,
      logout,
      // Permission codes come from the server, which is the only authority.
      // Do not shortcut this by role: an admin whose role has had a permission
      // revoked would still be shown buttons that the API will reject.
      has: (code: string) => permissions.includes(code),
    }),
    [user, permissions, ready, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
