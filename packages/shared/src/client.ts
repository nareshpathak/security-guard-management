import type { ApiMeta } from "./types";

export type TokenStore = {
  getAccessToken: () => string | null;
  setAccessToken: (token: string | null) => void;
  clear: () => void;
};

export class ApiError extends Error {
  status: number;
  code?: string;
  detail?: string;
  traceId?: string;
  errors?: Record<string, string[]>;

  constructor(init: {
    message: string;
    status: number;
    code?: string;
    detail?: string;
    traceId?: string;
    errors?: Record<string, string[]>;
  }) {
    super(init.message);
    this.name = "ApiError";
    this.status = init.status;
    this.code = init.code;
    this.detail = init.detail;
    this.traceId = init.traceId;
    this.errors = init.errors;
  }
}

export type ApiClientOptions = {
  baseUrl: string;
  tokenStore: TokenStore;
  /**
   * Obtains a fresh access token, returning null when the session is dead.
   *
   * How the refresh token is stored is deliberately not this client's business.
   * The web app keeps it in an httpOnly cookie and calls its own route handler;
   * the mobile app keeps it in the device keychain and calls the API directly.
   * Both hand this client the same one-line contract.
   */
  refreshAccessToken: () => Promise<string | null>;
  onUnauthorized?: () => void;
  getDeviceId?: () => string | null;
};

function toQuery(params?: Record<string, string | number | boolean | undefined | null>) {
  if (!params) return "";
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null || v === "") continue;
    q.set(k, String(v));
  }
  const s = q.toString();
  return s ? `?${s}` : "";
}

export function createApiClient(options: ApiClientOptions) {
  const { baseUrl, tokenStore, refreshAccessToken, onUnauthorized } = options;
  let refreshPromise: Promise<boolean> | null = null;

  async function refresh(): Promise<boolean> {
    try {
      const token = await refreshAccessToken();
      if (!token) {
        tokenStore.clear();
        return false;
      }
      tokenStore.setAccessToken(token);
      return true;
    } catch {
      tokenStore.clear();
      return false;
    }
  }

  async function request<T>(
    path: string,
    init: RequestInit = {},
    retried = false,
  ): Promise<{ data: T; meta?: ApiMeta | null }> {
    const headers = new Headers(init.headers);
    if (!headers.has("Content-Type") && init.body) {
      headers.set("Content-Type", "application/json");
    }
    const token = tokenStore.getAccessToken();
    if (token) headers.set("Authorization", `Bearer ${token}`);

    const res = await fetch(`${baseUrl}${path}`, { ...init, headers });

    if (res.status === 401 && !retried && !path.includes("/auth/login") && !path.includes("/auth/refresh")) {
      refreshPromise ??= refresh().finally(() => {
        refreshPromise = null;
      });
      const ok = await refreshPromise;
      if (ok) return request<T>(path, init, true);
      onUnauthorized?.();
      throw new ApiError({ message: "Session expired", status: 401, code: "AUTH_REFRESH_INVALID" });
    }

    if (res.status === 204) return { data: undefined as T };

    const contentType = res.headers.get("content-type") ?? "";
    const isJson =
      contentType.includes("application/json") || contentType.includes("problem+json");
    const body = isJson ? await res.json() : null;

    if (!res.ok) {
      throw new ApiError({
        message:
          body?.detail ?? body?.title ?? body?.message ?? `Request failed (${res.status})`,
        status: res.status,
        code: body?.code ?? body?.extensions?.code,
        detail: body?.detail,
        traceId: body?.traceId ?? body?.extensions?.traceId,
        errors: body?.errors ?? body?.extensions?.errors,
      });
    }

    if (body && typeof body === "object" && "data" in body) {
      return { data: body.data as T, meta: (body.meta as ApiMeta | null) ?? null };
    }
    return { data: body as T };
  }

  return {
    get: <T>(path: string, query?: Record<string, string | number | boolean | undefined | null>) =>
      request<T>(`${path}${toQuery(query)}`),
    post: <T>(path: string, body?: unknown) =>
      request<T>(path, {
        method: "POST",
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
    put: <T>(path: string, body?: unknown) =>
      request<T>(path, { method: "PUT", body: JSON.stringify(body) }),
    patch: <T>(path: string, body?: unknown) =>
      request<T>(path, { method: "PATCH", body: JSON.stringify(body) }),
    delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
    toQuery,
  };
}

export type ApiClient = ReturnType<typeof createApiClient>;
