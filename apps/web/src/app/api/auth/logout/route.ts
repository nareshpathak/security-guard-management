import { NextRequest, NextResponse } from "next/server";
import { callApi, REFRESH_COOKIE, refreshCookieOptions } from "@/lib/server-api";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Revokes the refresh token server-side, then clears the cookie.
 *
 * The cookie is cleared even if the API call fails: a user who clicks "log out"
 * must end up logged out of this browser regardless of what the server says.
 */
export async function POST(req: NextRequest) {
  const refreshToken = req.cookies.get(REFRESH_COOKIE)?.value;

  if (refreshToken) {
    await callApi("/api/v2/auth/logout", {
      method: "POST",
      ip: req.headers.get("x-forwarded-for") ?? undefined,
      body: { refreshToken },
    }).catch(() => undefined);
  }

  const res = NextResponse.json({ data: true });
  res.cookies.set(REFRESH_COOKIE, "", { ...refreshCookieOptions, maxAge: 0 });
  return res;
}
