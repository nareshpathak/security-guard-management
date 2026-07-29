"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@diti365/shared";
import { Button, Input, Label } from "@diti365/ui";
import { getApi } from "@/lib/api";

/**
 * Step 1 of the reset: ask for an OTP on a mobile number.
 *
 * The reply is deliberately the same whether or not the number is registered.
 * Telling a stranger "no such user" turns this form into a way to enumerate
 * every mobile number the agency employs.
 */
export default function ForgotPasswordPage() {
  const router = useRouter();
  const [mobileNo, setMobileNo] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await getApi().post("/api/v2/auth/otp/request", { mobileNo });
      setSent(true);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : "Could not send the code. Try again in a moment.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-6 py-12">
      <div className="w-full max-w-sm space-y-4">
        <div>
          <h1 className="text-2xl font-semibold text-text">Reset your password</h1>
          <p className="mt-1 text-sm text-muted">
            We will text a six-digit code to your registered mobile number.
          </p>
        </div>

        {sent ? (
          <>
            <div
              role="status"
              className="rounded-md border border-success/30 bg-success-subtle px-3 py-2 text-sm text-success"
            >
              If {mobileNo} is registered, a code is on its way.
            </div>
            <Button className="w-full" onClick={() => router.push(`/verify-otp?mobileNo=${encodeURIComponent(mobileNo)}`)}>
              Enter the code
            </Button>
          </>
        ) : (
          <form onSubmit={onSubmit} className="space-y-4">
            <div>
              <Label htmlFor="mobileNo" required>
                Mobile number
              </Label>
              <Input
                id="mobileNo"
                inputMode="tel"
                autoComplete="tel"
                value={mobileNo}
                onChange={(e) => setMobileNo(e.target.value)}
                required
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

            <Button type="submit" className="w-full" loading={loading} disabled={mobileNo.length < 10}>
              Send code
            </Button>
          </form>
        )}

        <p className="text-center text-sm text-muted">
          <Link href="/login" className="text-primary underline">
            Back to sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
