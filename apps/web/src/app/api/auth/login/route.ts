import { NextRequest, NextResponse } from "next/server";
import { callApi, REFRESH_COOKIE, refreshCookieOptions } from "@/lib/server-api";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Logs in against the .NET API and keeps the refresh token server-side.
 *
 * The browser receives the 15-minute access token and the user profile; the
 * 30-day refresh token goes straight into an httpOnly cookie and is never
 * exposed to page JavaScript, so an XSS bug cannot walk off with a month of
 * access to a tenant's payroll.
 */
export async function POST(req: NextRequest) {
  try {
    const { loginId, password, deviceId } = await req.json();

    if (typeof loginId !== "string" || typeof password !== "string" || !loginId || !password) {
      return NextResponse.json(
        { code: "VALIDATION", detail: "Login ID and password are both required." },
        { status: 400 },
      );
    }

    const { status, body: raw } = await callApi("/api/v2/auth/login", {
      method: "POST",
      ip: req.headers.get("x-forwarded-for") ?? undefined,
      body: {
        loginId,
        password,
        deviceId,
        platform: "web",
        appVersion: "web-1.0",
        deviceModel: req.headers.get("user-agent")?.slice(0, 200),
      },
    });

    const body = raw as { data?: { refreshToken?: string } } | null;

    if (status !== 200 || !body?.data) {
      const detail =
        raw && typeof raw === "object" && "detail" in raw
          ? (raw as { detail: string }).detail
          : "Login failed. Check your details and try again.";
      return NextResponse.json({ code: "LOGIN_FAILED", detail }, { status });
    }

    const { refreshToken = "", ...safe } = body.data;

    const res = NextResponse.json({ data: safe });
    if (refreshToken) res.cookies.set(REFRESH_COOKIE, refreshToken, refreshCookieOptions);
    return res;
  } catch (err) {
    const detail = err instanceof Error ? err.message : "An unexpected error occurred.";
    return NextResponse.json({ code: "INTERNAL_ERROR", detail }, { status: 500 });
  }
}
