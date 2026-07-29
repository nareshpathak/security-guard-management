"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ApiError } from "@diti365/shared";
import { Button, Input, Label } from "@diti365/ui";
import { getApi } from "@/lib/api";

/**
 * Step 2: exchange the code for a reset token.
 *
 * The token is held in component state and passed on in the router state, not
 * in the URL - a reset token in an address bar ends up in browser history,
 * server logs and anything the user pastes.
 */
export default function VerifyOtpPage() {
  const router = useRouter();
  const search = useSearchParams();
  const mobileNo = search.get("mobileNo") ?? "";
  const [otp, setOtp] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const { data } = await getApi().post<{ resetToken: string }>("/api/v2/auth/otp/verify", {
        mobileNo,
        otp,
        purpose: "Reset",
      });
      sessionStorage.setItem("diti365.resetToken", data.resetToken);
      router.replace("/reset-password");
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : "That code was not accepted. Check it and try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-6 py-12">
      <form onSubmit={onSubmit} className="w-full max-w-sm space-y-4">
        <div>
          <h1 className="text-2xl font-semibold text-text">Enter your code</h1>
          <p className="mt-1 text-sm text-muted">
            Six digits, sent to {mobileNo || "your registered number"}. It expires in a few minutes.
          </p>
        </div>

        <div>
          <Label htmlFor="otp" required>
            Code
          </Label>
          <Input
            id="otp"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            className="tabular text-lg tracking-[0.4em]"
            value={otp}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
            required
            autoFocus
          />
        </div>

        {error ? (
          <div
            role="alert"
            className="rounded-md border border-danger/30 bg-danger-subtle px-3 py-2 text-sm text-danger"
          >
            {error}
          </div>
        ) : null}

        <Button type="submit" className="w-full" loading={loading} disabled={otp.length !== 6}>
          Verify
        </Button>

        <p className="text-center text-sm text-muted">
          <Link href="/forgot-password" className="text-primary underline">
            Send a new code
          </Link>
        </p>
      </form>
    </div>
  );
}
