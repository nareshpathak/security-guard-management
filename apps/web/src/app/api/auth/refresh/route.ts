import { NextRequest, NextResponse } from "next/server";
import { callApi, REFRESH_COOKIE, refreshCookieOptions } from "@/lib/server-api";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Exchanges the httpOnly refresh cookie for a fresh access token, and rotates
 * the cookie because the API issues a new refresh token every time.
 *
 * This is also how a session is restored on page load: the access token is
 * held in memory only, so a reload has nothing until this call returns. The
 * API returns the full profile on refresh, so one round trip rebuilds
 * everything the UI needs.
 */
export async function POST(req: NextRequest) {
  const refreshToken = req.cookies.get(REFRESH_COOKIE)?.value;

  if (!refreshToken) {
    return NextResponse.json({ code: "AUTH_NO_SESSION" }, { status: 401 });
  }

  const { status, body: raw } = await callApi("/api/v2/auth/refresh", {
    method: "POST",
    ip: req.headers.get("x-forwarded-for") ?? undefined,
    body: { refreshToken },
  });

  const body = raw as { data?: { refreshToken?: string } } | null;

  if (status !== 200 || !body?.data) {
    const dead = NextResponse.json(raw ?? { code: "AUTH_REFRESH_INVALID" }, { status: 401 });
    dead.cookies.set(REFRESH_COOKIE, "", { ...refreshCookieOptions, maxAge: 0 });
    return dead;
  }

  const { refreshToken: rotated = "", ...safe } = body.data;

  const res = NextResponse.json({ data: safe });
  if (rotated) res.cookies.set(REFRESH_COOKIE, rotated, refreshCookieOptions);
  return res;
}
