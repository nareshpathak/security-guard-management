"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import { AppShell, defaultNav } from "@diti365/ui";
import { useAuth } from "@/lib/auth";
import { CommandPalette } from "@/components/command-palette";

export function AppFrame({ children }: { children: React.ReactNode }) {
  const { user, ready, logout, has } = useAuth();
  const { resolvedTheme, setTheme } = useTheme();
  const router = useRouter();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
  }, [ready, user, router]);

  // `ready` stays false until the silent refresh settles, so this also covers
  // the reload case where the in-memory access token is briefly absent.
  if (!ready || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center gap-3 text-sm text-muted">
        <span className="size-4 animate-spin rounded-full border-2 border-border border-t-primary" />
        Restoring your session…
      </div>
    );
  }

  /*  Hide what this user cannot do. This is a courtesy, not a control: every
      one of these screens calls an endpoint that checks the same permission
      server-side, so a user who types the URL gets a 403, not data.  */
  const nav = defaultNav
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => !item.permission || has(item.permission)),
    }))
    .filter((group) => group.items.length > 0);

  return (
    <AppShell
      nav={nav}
      userName={user.name || user.userName}
      roleCode={user.roleCode}
      dark={resolvedTheme === "dark"}
      onToggleDark={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
      // logout() already redirects to /login after clearing the query cache.
      onLogout={logout}
    >
      {children}
      <CommandPalette />
    </AppShell>
  );
}
