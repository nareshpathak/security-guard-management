export type ApiMeta = {
  page: number;
  pageSize: number;
  total: number;
  sortBy?: string | null;
  sortDir?: string | null;
  totalPages?: number;
};

export type ApiResponse<T> = {
  data: T | null;
  meta?: ApiMeta | null;
  error?: unknown;
};

export type SpResult = {
  success: boolean;
  status: number;
  id: number;
  message: string;
};

export type AuthUser = {
  userId: number;
  companyId?: number | null;
  branchId?: number | null;
  empId?: number | null;
  clientId?: number | null;
  userName: string;
  name: string;
  empCode?: string | null;
  mobileNo?: string | null;
  designation?: string | null;
  unit?: string | null;
  roleCode: string;
  loginType?: number | null;
  photoUrl?: string | null;
  mustChangePassword: boolean;
  expiresOn?: string | null;
  attendanceCount: number;
};

/** What the .NET API returns. Only the server ever sees the refresh token. */
export type LoginResponse = {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
  user: AuthUser;
  permissions: string[];
};

/**
 * What reaches the browser. The web BFF strips `refreshToken` before replying,
 * so the type makes it impossible to reach for it in client code by accident.
 */
export type ClientSession = Omit<LoginResponse, "refreshToken">;

export type Row = Record<string, unknown>;

export type PagedQuery = {
  page?: number;
  pageSize?: number;
  search?: string;
  sortBy?: string;
  sortDir?: "asc" | "desc";
  from?: string;
  to?: string;
  branchId?: number;
  unitId?: number;
  status?: string;
};
