"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { ApiError } from "@diti365/shared";
import { Button, Input, Label } from "@diti365/ui";
import { useAuth } from "@/lib/auth";

/**
 * The demo credentials are prefilled in development only.
 *
 * A production build must never ship a sign-in form that arrives with a
 * working username and password already typed into it.
 */
const isDev = process.env.NODE_ENV === "development";

export default function LoginPage() {
  const { login, user, ready } = useAuth();
  const router = useRouter();
  const search = useSearchParams();
  const [loginId, setLoginId] = useState(isDev ? "diti.admin" : "");
  const [password, setPassword] = useState(isDev ? "Admin@123" : "");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const next = search.get("next") || "/dashboard";

  // Redirecting during render is a side effect in the render phase: React warns
  // about it, and under StrictMode it can fire twice.
  useEffect(() => {
    if (ready && user) router.replace(next);
  }, [ready, user, next, router]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await login(loginId, password);
      router.replace(next);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : err instanceof Error
            ? err.message
            : "Sign-in failed. Check your details and try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <div className="relative hidden overflow-hidden bg-primary lg:block">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.18),transparent_55%)]" />
        <div className="relative flex h-full flex-col justify-between p-12 text-white">
          <div className="text-sm font-semibold tracking-wide">Diti365</div>
          <div>
            <h1 className="max-w-md text-4xl font-semibold leading-tight">
              Security operations, turnout and payroll in one console
            </h1>
            <p className="mt-4 max-w-md text-sm text-white/80">
              Deploy guards, track attendance, close vacancies and run payroll against live agency
              data.
            </p>
          </div>
          {isDev ? (
            <div className="text-xs text-white/70">Demo: diti.admin / Admin@123</div>
          ) : (
            <div className="text-xs text-white/60">© Diti365</div>
          )}
        </div>
      </div>

      <div className="flex items-center justify-center px-6 py-12">
        <form onSubmit={onSubmit} className="w-full max-w-sm space-y-4">
          <div>
            <h2 className="text-2xl font-semibold text-text">Sign in</h2>
            <p className="mt-1 text-sm text-muted">Use your agency login id or mobile number.</p>
          </div>

          <div>
            <Label htmlFor="loginId" required>
              Login id
            </Label>
            <Input
              id="loginId"
              autoComplete="username"
              value={loginId}
              onChange={(e) => setLoginId(e.target.value)}
              required
            />
          </div>

          <div>
            <Label htmlFor="password" required>
              Password
            </Label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          {error ? (
            // aria-live so a screen reader announces the failure. A sighted user
            // sees the box appear; without this nobody else would.
            <div
              role="alert"
              aria-live="assertive"
              className="rounded-md border border-danger/30 bg-danger-subtle px-3 py-2 text-sm text-danger"
            >
              {error}
            </div>
          ) : null}

          <Button type="submit" className="w-full" loading={loading}>
            Sign in
          </Button>

          <p className="text-center text-sm text-muted">
            <Link href="/forgot-password" className="text-primary underline">
              Forgotten your password?
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
}
