"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@diti365/shared";
import { Button, Input, Label } from "@diti365/ui";
import { getApi } from "@/lib/api";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [resetToken, setResetToken] = useState<string | null>(null);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // sessionStorage, read on mount rather than during render: the value does not
  // exist on the server and reading it while rendering breaks hydration.
  useEffect(() => {
    setResetToken(sessionStorage.getItem("diti365.resetToken"));
  }, []);

  const tooShort = password.length > 0 && password.length < 8;
  const mismatch = confirm.length > 0 && confirm !== password;
  const canSave = password.length >= 8 && confirm === password && !loading;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!resetToken) return;
    setLoading(true);
    setError(null);
    try {
      await getApi().post("/api/v2/auth/password/reset", { resetToken, newPassword: password });
      sessionStorage.removeItem("diti365.resetToken");
      router.replace("/login?reset=1");
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : "Could not set the new password. Request a fresh code.",
      );
    } finally {
      setLoading(false);
    }
  }

  if (resetToken === null) {
    return (
      <div className="flex min-h-screen items-center justify-center px-6">
        <div className="w-full max-w-sm space-y-4 text-center">
          <h1 className="text-xl font-semibold text-text">Start again</h1>
          <p className="text-sm text-muted">
            This page needs a verified code. Codes expire after a few minutes.
          </p>
          <Link href="/forgot-password" className="inline-block text-primary underline">
            Request a new code
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-6 py-12">
      <form onSubmit={onSubmit} className="w-full max-w-sm space-y-4">
        <div>
          <h1 className="text-2xl font-semibold text-text">Choose a new password</h1>
          <p className="mt-1 text-sm text-muted">
            At least 8 characters. Signing in elsewhere will be ended.
          </p>
        </div>

        <div>
          <Label htmlFor="password" required>
            New password
          </Label>
          <Input
            id="password"
            type="password"
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            aria-invalid={tooShort}
            required
            autoFocus
          />
          {tooShort ? (
            <p className="mt-1 text-xs text-danger">
              {8 - password.length} more character{8 - password.length === 1 ? "" : "s"} needed.
            </p>
          ) : null}
        </div>

        <div>
          <Label htmlFor="confirm" required>
            Confirm
          </Label>
          <Input
            id="confirm"
            type="password"
            autoComplete="new-password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            aria-invalid={mismatch}
            required
          />
          {mismatch ? <p className="mt-1 text-xs text-danger">These do not match.</p> : null}
        </div>

        {error ? (
          <div
            role="alert"
            className="rounded-md border border-danger/30 bg-danger-subtle px-3 py-2 text-sm text-danger"
          >
            {error}
          </div>
        ) : null}

        <Button type="submit" className="w-full" loading={loading} disabled={!canSave}>
          Set password
        </Button>
      </form>
    </div>
  );
}
