import "server-only";

/**
 * Server-side calls from the Next.js route handlers to the .NET API.
 *
 * This module is the only place the browser's refresh token is ever touched.
 * It runs on the server, so the token can live in an httpOnly cookie that page
 * JavaScript cannot read.
 */

export const API_BASE_URL =
  process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://localhost:7175";

export async function callApi(
  path: string,
  init: { method: string; body?: unknown; accessToken?: string; ip?: string },
): Promise<{ status: number; body: any }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (init.accessToken) headers.Authorization = `Bearer ${init.accessToken}`;
  // Let the API log the real client address rather than the Next.js server's.
  if (init.ip) headers["X-Forwarded-For"] = init.ip;

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      method: init.method,
      headers,
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
      cache: "no-store",
    });
  } catch (cause) {
    /*  The overwhelmingly common cause in development is an untrusted ASP.NET
        certificate, which surfaces as an opaque "fetch failed". Saying so is
        worth more than the raw error.

        There is deliberately no "ignore certificate errors" switch here. One
        would have been convenient exactly once, and then would have sat in the
        codebase waiting to be turned on in production.  */
    const detail =
      cause instanceof Error && /certificate|self-signed|SSL|TLS/i.test(String(cause.cause ?? cause))
        ? `Could not verify the API's TLS certificate at ${API_BASE_URL}. Run: dotnet dev-certs https --trust`
        : `Could not reach the API at ${API_BASE_URL}. Is it running?`;

    return { status: 502, body: { code: "API_UNREACHABLE", detail } };
  }

  const contentType = res.headers.get("content-type") ?? "";
  const body = contentType.includes("json") ? await res.json().catch(() => null) : null;
  return { status: res.status, body };
}

/** Name of the httpOnly cookie holding the rotating refresh token. */
export const REFRESH_COOKIE = "diti365_rt";

export const refreshCookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "strict" as const,
  path: "/api/auth",
  // Matches the API's 30-day refresh lifetime. Rotation shortens this in practice.
  maxAge: 60 * 60 * 24 * 30,
};
