# Diti365 — Phase 1.5: Backend API Specification
**.NET 10 Web API · C# 14 · raw ADO.NET + stored procedures (no ORM) · JWT · Hangfire · SignalR**

---

## 1. Solution Layout

```
api/
  Diti365.sln
  src/
    Diti365.Api/                 # controllers, filters, middleware, DI, Swagger
      Controllers/V1/            # legacy-compatible: Users, Operation, Tasks, Sales, Report
      Controllers/V2/            # clean REST
      Filters/                   # TenantGuardFilter, PermissionFilter, ValidationFilter
      Middleware/                # ExceptionHandling, RequestLogging, TraceId
      Hubs/                      # LiveMapHub, ApprovalHub, ChatHub
    Diti365.Application/         # MediatR commands/queries, validators, DTOs, mappers
    Diti365.Domain/              # entities, enums, domain services (payroll rules, geofence)
    Diti365.Infrastructure/      # ADO.NET repositories, Blob, Fcm, Sms, Pdf, Jobs
    Diti365.Contracts/           # shared request/response records -> also emitted as TS types
  tests/
    Diti365.UnitTests/
    Diti365.IntegrationTests/    # Testcontainers SQL Server + seeded DB
```

**Rules for Cursor**
- Controllers are thin: validate → `_mediator.Send(...)` → map to envelope. No business logic.
- **All** data access goes through **raw ADO.NET calling stored procedures** (`CommandType.StoredProcedure`). No EF Core, no Dapper, no ORM of any kind, anywhere in the solution.
- No ad-hoc SQL text in C#. If a query is needed, a stored procedure is written for it in `db/scripts/`.
- No `SqlConnection`, `SqlCommand` or repository in a controller. Ever. See §3 for the required pattern.
- Every endpoint has an XML doc comment + `[ProducesResponseType]` for 200/400/401/403/404/409/422/500.

---

## 2. Authentication & Authorisation

### 2.1 Token flow
```
POST /api/v2/auth/login       { loginId, password, deviceId, deviceModel, appVersion, platform, fcmToken }
  -> 200 { accessToken (JWT, 15 min), refreshToken (opaque, 30 d), user {...}, permissions [...] }
POST /api/v2/auth/refresh     { refreshToken }        -> rotates, revokes old
POST /api/v2/auth/logout      { refreshToken }
POST /api/v2/auth/otp/request { mobileNo, purpose }   -> sends SMS/Firebase OTP
POST /api/v2/auth/otp/verify  { mobileNo, otp }       -> short-lived reset token
POST /api/v2/auth/password/forgot   { mobileNo }
POST /api/v2/auth/password/reset    { resetToken, newPassword }
POST /api/v2/auth/password/change   { currentPassword, newPassword }
POST /api/v2/auth/device/verify     { deviceId }      -> legacy checkdeviceid
```

### 2.2 JWT claims (non-negotiable)
`sub` = UserID · `company_id` · `branch_ids` (CSV) · `emp_id` · `client_id` · `role` · `login_type` · `device_id` · `perms` (compressed bitset or a cache key) · `exp` · `jti`

### 2.3 Tenant guard
`TenantGuardFilter` runs on every authenticated request:
1. Reads `company_id` from the token and stores it in a scoped `ICurrentUser`.
2. **Rejects (400 `TENANT_PARAM_FORBIDDEN`) any request that contains `companyId`/`CompanyID` in route, query or body**, unless the caller is `SUPER_ADMIN`.
3. Every SP call takes `@CompanyID` from `ICurrentUser`, never from the model binder.

### 2.4 Permission attribute
```csharp
[HasPermission("M8.Attendance.Approve")]
public async Task<IActionResult> Approve(...)
```
Backed by `sec.RolePermission`, cached per role for 5 minutes, invalidated on write.

### 2.5 Password migration
On login, if `PasswordHash` is null and `LegacyPasswordHash` matches the legacy algorithm, verify against legacy, then immediately re-hash with PBKDF2, store, and null out `LegacyPasswordHash`.

### 2.6 Rate limits
`login` and `otp/request`: 5 per mobile per 15 min. Punch endpoints: 30/min per device. Global: 300/min per user. Use `Microsoft.AspNetCore.RateLimiting` with a fixed-window per-user partition.


---

## 3. Data Access — ADO.NET + Stored Procedures (mandatory pattern)

**Hard rules**
1. `Microsoft.Data.SqlClient` only. No EF Core, no Dapper, no ORM, anywhere.
2. Every database call is `CommandType.StoredProcedure`. **Inline SQL text in C# is a build failure.** If you need a query, add a stored procedure to `db/scripts/`.
3. Every parameter is a typed `SqlParameter` with explicit `SqlDbType` and `Size`. Never string concatenation, never `AddWithValue` (it infers the wrong type and wrecks execution plans).
4. `@CompanyID` and `@UserID` are appended by the executor from `ICurrentUser`. A repository must not accept them as method arguments — that removes the possibility of passing a tenant id from the client.
5. All calls are `async` and take a `CancellationToken`.
6. Connections are opened as late as possible, disposed via `await using`, and never held across an `await` that does other work. Rely on the built-in connection pool; do not cache `SqlConnection`.

### 3.1 The executor

`Diti365.Infrastructure/Data/IDbExecutor.cs` — the only type allowed to create a `SqlConnection`.

```csharp
public interface IDbExecutor
{
    // Multiple rows
    Task<IReadOnlyList<T>> QueryAsync<T>(
        string procedure, Action<SqlParameterCollection>? p, Func<SqlDataReader, T> map, CancellationToken ct);

    // Single row or null
    Task<T?> QuerySingleAsync<T>(
        string procedure, Action<SqlParameterCollection>? p, Func<SqlDataReader, T> map, CancellationToken ct);

    // Legacy envelope: result set 1 = (Success, Status, Id, Message), result set 2 = data
    Task<SpResult<T>> QueryEnvelopeAsync<T>(
        string procedure, Action<SqlParameterCollection>? p, Func<SqlDataReader, T> map, CancellationToken ct);

    // Paged list: result set 1 = rows, result set 2 = (TotalRows)
    Task<PagedResult<T>> QueryPagedAsync<T>(
        string procedure, Action<SqlParameterCollection>? p, Func<SqlDataReader, T> map, CancellationToken ct);

    // Writes; returns the SP's OUTPUT @Id
    Task<int> ExecuteAsync(
        string procedure, Action<SqlParameterCollection>? p, CancellationToken ct);

    Task<T?> ExecuteScalarAsync<T>(
        string procedure, Action<SqlParameterCollection>? p, CancellationToken ct);

    // Bulk insert via a table-valued parameter (offline sync batches, seed import)
    Task<int> ExecuteTvpAsync(
        string procedure, string tvpName, string tvpTypeName, DataTable rows,
        Action<SqlParameterCollection>? p, CancellationToken ct);
}
```

The implementation must:
- read the connection string from `IOptions<DbOptions>`;
- inject `@CompanyID`, `@UserID` and `@TraceId` from `ICurrentUser` unless the procedure is in the small allow-list of tenant-less procedures (login, OTP, master bootstrap);
- set `CommandTimeout` from config (default 30 s, 300 s for the payroll and report procedures);
- wrap `SqlException` numbers 1205 (deadlock), -2 (timeout), 4060/40197/40501/49918 (transient) in a **retry policy: 3 attempts, 200 ms exponential backoff with jitter**;
- translate SP `THROW` codes 51000–51999 into domain exceptions that the middleware maps to the error codes in §9;
- log procedure name, duration and row count to Serilog at Debug, and anything over 500 ms at Warning.

### 3.2 Parameter helpers

```csharp
public static class P
{
    public static SqlParameter Int(string n, int? v)        => new(n, SqlDbType.Int)          { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter BigInt(string n, long? v)    => new(n, SqlDbType.BigInt)       { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter NVar(string n, string? v, int size)
                                                            => new(n, SqlDbType.NVarChar, size) { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter Bit(string n, bool? v)       => new(n, SqlDbType.Bit)          { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter Date(string n, DateOnly? v)  => new(n, SqlDbType.Date)         { Value = (object?)v?.ToDateTime(TimeOnly.MinValue) ?? DBNull.Value };
    public static SqlParameter DateTime2(string n, DateTime? v) => new(n, SqlDbType.DateTime2) { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter Decimal(string n, decimal? v, byte precision, byte scale)
        => new(n, SqlDbType.Decimal) { Precision = precision, Scale = scale, Value = (object?)v ?? DBNull.Value };
    public static SqlParameter Guid(string n, Guid? v)      => new(n, SqlDbType.UniqueIdentifier) { Value = (object?)v ?? DBNull.Value };
    public static SqlParameter OutInt(string n)             => new(n, SqlDbType.Int)          { Direction = ParameterDirection.Output };
}
```

Money is always `Decimal(..., 18, 2)`. Latitude/longitude always `Decimal(..., 10, 7)`. Strings always carry the same `Size` as the SP parameter — a mismatch silently truncates.

### 3.3 Reader mapping

One private static `Map` method per DTO, in the repository that owns it. **Cache ordinals outside the row loop** — `reader["Column"]` inside a loop is the single biggest performance mistake in ADO.NET code.

```csharp
private static Func<SqlDataReader, EmployeeListDto> EmployeeListMapper(SqlDataReader r)
{
    int oEmpId   = r.GetOrdinal("EmpID");
    int oEmpCode = r.GetOrdinal("EmpCode");
    int oName    = r.GetOrdinal("EmpFullName");
    int oDesig   = r.GetOrdinal("DesignationName");
    int oUnit    = r.GetOrdinal("UnitName");
    int oMobile  = r.GetOrdinal("Mobile1");
    int oStatus  = r.GetOrdinal("EmpStatus");

    return row => new EmployeeListDto(
        EmpID           : row.GetInt32(oEmpId),
        EmpCode         : row.GetString(oEmpCode),
        EmpFullName     : row.GetString(oName),
        DesignationName : row.IsDBNull(oDesig)  ? null : row.GetString(oDesig),
        UnitName        : row.IsDBNull(oUnit)   ? null : row.GetString(oUnit),
        Mobile1         : row.IsDBNull(oMobile) ? null : row.GetString(oMobile),
        EmpStatus       : row.GetString(oStatus));
}
```

Rules: never `GetXxx` without an `IsDBNull` check on a nullable column; never index by column name inside the loop; DTOs are `record` types with non-nullable properties only where the SP guarantees `NOT NULL`.

### 3.4 A complete repository method (the reference implementation)

```csharp
public sealed class EmployeeRepository(IDbExecutor db) : IEmployeeRepository
{
    public Task<PagedResult<EmployeeListDto>> GetListAsync(EmployeeListQuery q, CancellationToken ct) =>
        db.QueryPagedAsync(
            "usp_Employee_GetList",
            p =>
            {
                p.Add(P.Int  ("@BranchID",      q.BranchId));
                p.Add(P.Int  ("@UnitID",        q.UnitId));
                p.Add(P.Int  ("@DesignationID", q.DesignationId));
                p.Add(P.NVar ("@Search",        q.Search, 200));
                p.Add(P.NVar ("@EmpStatus",     q.Status, 20));
                p.Add(P.Int  ("@PageNo",        q.Page));
                p.Add(P.Int  ("@PageSize",      q.PageSize));
                p.Add(P.NVar ("@SortBy",        q.SortBy, 50));
                p.Add(P.NVar ("@SortDir",       q.SortDir, 4));
            },
            EmployeeListMapper,   // ordinal-cached factory from §3.3
            ct);
}
```

Note what is absent: no connection, no command, no `CompanyID`, no try/catch, no transaction. Those belong to the executor and the stored procedure respectively.

### 3.5 Transactions

Transactions live **inside the stored procedure** (`BEGIN TRY / BEGIN TRAN … COMMIT / CATCH → ROLLBACK; THROW;` per `01-database.md` §1). C# does not open `SqlTransaction` and does not use `TransactionScope`. If an operation spans several procedures, write a single wrapper procedure that calls them.

### 3.6 Table-valued parameters

Used for the mobile offline sync batch (`POST /api/v2/attendance/sync`), bulk deployment and seed import. Define the type in SQL, e.g.

```sql
CREATE TYPE ops.AttendancePunchList AS TABLE (
    ClientRequestId UNIQUEIDENTIFIER NOT NULL,
    EmpID INT NOT NULL, UnitID INT NOT NULL, ShiftID INT NULL,
    PunchAt DATETIME2(0) NOT NULL, Latitude DECIMAL(10,7) NULL,
    Longitude DECIMAL(10,7) NULL, Direction CHAR(3) NOT NULL, SelfieUrl NVARCHAR(500) NULL
);
```

and pass a `DataTable` via `ExecuteTvpAsync`. Never loop and call a single-row SP N times.

### 3.7 What replaces EF Core's conveniences

| EF Core gave you | ADO.NET replacement |
|---|---|
| Migrations | DbUp / `db/run-all.ps1` running ordered `.sql` scripts |
| Change tracking | Not needed — writes go through explicit SPs |
| LINQ queries | Stored procedures with `@PageNo/@PageSize/@SortBy/@SortDir` parameters |
| Lazy loading | Multiple result sets from one SP, mapped in one pass |
| `DbContext` per request | `IDbExecutor` registered `Scoped`, connection pooled |
| Identity password hashing | `Microsoft.AspNetCore.Cryptography.KeyDerivation` (PBKDF2) used directly |
| Hangfire storage | `Hangfire.SqlServer` manages its own schema; leave it alone |

### 3.8 Testing

- Repository integration tests run against a real SQL Server (Testcontainers or the local dev instance) seeded by `db/scripts/`. No mocking of `IDbExecutor` in repository tests.
- Application-layer tests mock `IEmployeeRepository` etc., never `IDbExecutor`.
- A CI guard scans `**/*.cs` for the strings `SELECT `, `INSERT INTO`, `UPDATE `, `DELETE FROM`, `new SqlConnection`, `Dapper`, `DbContext` outside `Diti365.Infrastructure/Data/` and fails the build on a hit.

---

## 4. V1 Compatibility Surface (keeps `Diti365.apk` v4.8 alive)

Base: `https://api.diti365.com/api/`
Envelope (unchanged): `{ "Success": bool, "Status": int, "Id": int, "Message": string, "Data": [ ... ] }`
Auth during transition: accept **both** the legacy header/body user identifier **and** a bearer token; log every legacy-auth call so adoption can be tracked.

### 3.1 `UsersController` (`api/Users/*`)
| Action | Method | Backing SP |
|---|---|---|
| `login` | POST | `usp_User_Login` |
| `checknum` | POST | `usp_User_CheckMobile` |
| `changepass` | POST | `usp_User_ChangePassword` |
| `checkdeviceid` | POST | `usp_User_CheckDeviceId` |
| `checkexpire` | POST | `usp_Company_CheckExpiry` |
| `updatetoken` | POST | `usp_User_UpdateFcmToken` |
| `getrights` | GET | `usp_User_GetRights` |
| `getprofile` | GET | `usp_User_GetProfile` |
| `getuserlists` | GET | `usp_User_GetUserList` |
| `getLoginLog` | GET | `usp_User_GetLoginLog` |
| `getCompanylog` | GET | `usp_Company_GetLog` |
| `getCompanylogdetail` | GET | `usp_Company_GetLogDetail` |
| `getstates` `getcity` `getdesignation` `getqualification` `getcomplaintype` `gettype` `getsubdropdown` `getlist` | GET | `usp_Master_*` |

### 3.2 `OperationController` (`api/Operation/*`)
Recruitment: `addrecruits`, `updaterecruits`, `getrecruits`, `getpendingrecruit`, `getrecruitdata`
Employee: `getemp`, `getemployee`, `getstafflist`, `getunitemployee`, `addfamily`, `bankdetails`, `addgunman`, `addreliever`, `getreliever`
Client/Unit: `addclient`, `addsite`, `updatesite`, `getunit`, `getuserunit`, `active`
Attendance: `insertattendance`, `insertattendancein`, `insertattendanceout`, `getattendance`, `getselfattendance`, `getattendsummary`, `getAttendanceCount`, `attendforapproval`, `approve`
Deployment: `incDecDeployment`, `newcontractDeployment`, `contractTermination`, `temporaryEvent`, `movement`, `insertturnout`
QR/Patrol: `addclientqr`, `getqrlist`, `getqrlistadmin`, `getqrlistsummary`, `getqrdistance`, `readqr`, `readqrwithimage`
Location: `trackLocation`, `getlocationlog`, `getuserlocationlog`
Incidents/Complaints: `insertincident`, `insertfield`, `getrptdetail`, `getcount`, `insertcomplaint`, `getcomplaint`, `getunitcomplaint`, `updatecomplaintstatus`, `insertsuggestion`, `insertrequest`
HR: `resign`, `insertleft`, `insertrejoin`, `training`
Gate pass: `insertgatepass`
Uniform: `issueitem`, `issueemployee`, `returnitem`, `returnemployee`, `getstock`, `getbranchstock`, `GetUniformLedger`
Finance: `insertadvance`, `getsalary`, `getbill`
Docs: `uploaddoc`, `docdetail`
Misc: `updateFlag`, `getuserchecklists`, `getuserlists`

### 3.3 `TasksController` (`api/Tasks/*`)
`addtask`, `gettasklistby`, `gettasklistto`, `gettaskstatus`, `updatetaskstatus`, `closetask`, `closetaskhistorylist`, `deletetask`, `readtask`

### 3.4 `SalesController` (`api/Sales/*`)
`visitEntry`, `visitReport`, `getVisitLog`, `followupEntry`, `followReport`, `nextfollowReport`, `clientRelation`, `clientrelationRpt`

### 3.5 `ReportController` (`api/Report/*`)
`eventRpt`, `incdecRpt`, `movementRpt`, `newcontractRpt`, `contractterminationRpt`, `resignRpt`, `trainingRpt`, `incidentRpt`, `getturnoutrpt`

> **Total v1 endpoints: 120.** The full extracted list is in `docs/06-apk-inventory.md` — every one must exist.

---

## 5. V2 REST Surface (web + new mobile)

Base: `https://api.diti365.com/api/v2/`
Envelope: `{ "data": ..., "meta": { page, pageSize, total, sortBy, sortDir }, "error": null }`
Standard list query: `?page=1&pageSize=50&search=&sortBy=&sortDir=asc&from=&to=&branchId=&unitId=&status=`

| Resource | Endpoints |
|---|---|
| `auth` | §2.1 |
| `me` | `GET /me`, `PATCH /me`, `GET /me/permissions`, `GET /me/dashboard`, `GET /me/notifications`, `POST /me/notifications/{id}/read`, `POST /me/device` |
| `companies` (SUPER_ADMIN) | `GET/POST/PATCH /companies`, `POST /companies/{id}/suspend`, `POST /companies/{id}/extend`, `GET /companies/{id}/usage`, `POST /companies/{id}/impersonate` |
| `branches` | full CRUD |
| `masters` | `GET /masters/{type}` for every `mst.*`, `POST/PATCH/DELETE` where tenant-editable; `GET /masters/bootstrap` returns all lookups in one call for app cold-start |
| `clients` | CRUD + `GET /clients/{id}/units`, `/contacts`, `/invoices`, `/complaints` |
| `units` | CRUD + `GET /units/{id}/posts`, `/locations`, `/employees`, `/qr`, `/turnout`, `PATCH /units/{id}/geofence` |
| `recruits` | CRUD + `POST /recruits/{id}/approve|reject|waitlist|convert`, `GET /recruits/pipeline` |
| `employees` | CRUD + `/{id}/addresses`, `/family`, `/bank`, `/statutory`, `/qualifications`, `/physical`, `/verification`, `/medical`, `/gun-licence`, `/documents`, `/deployments`, `/attendance`, `/salary-slips`, `/uniform-ledger`, `/status-history`, `POST /{id}/blacklist`, `POST /{id}/photo` |
| `deployments` | `GET/POST/PATCH`, `POST /deployments/bulk`, `POST /deployments/movement`, `POST /deployments/incdec`, `POST /deployments/reliever` |
| `contracts` | CRUD + `POST /contracts/{id}/terminate`, `POST /contracts/temporary-event` |
| `attendance` | `POST /attendance/punch-in`, `/punch-out`, `POST /attendance/bulk`, `POST /attendance/sync` (offline batch), `GET /attendance`, `GET /attendance/summary`, `GET /attendance/pending-approval`, `POST /attendance/approve`, `POST /attendance/reject`, `GET /attendance/register` |
| `turnout` | `GET /turnout`, `POST /turnout`, `GET /turnout/live` (today, all units, vacancy flags) |
| `patrol` | `GET/POST /patrol/checkpoints`, `GET /patrol/checkpoints/{id}/qr.png`, `POST /patrol/scan`, `GET /patrol/logs`, `GET /patrol/summary`, `GET/POST /patrol/rounds`, `GET /patrol/missed` |
| `tracking` | `POST /tracking/ping`, `POST /tracking/ping/batch`, `GET /tracking/live`, `GET /tracking/users/{id}/trail?date=`, `GET /tracking/summary` |
| `tasks` | CRUD + `/{id}/status`, `/{id}/close`, `/{id}/history`, `/{id}/checklist`, `/{id}/read`, `GET /tasks/assigned-to-me`, `GET /tasks/assigned-by-me` |
| `incidents` | CRUD + `/{id}/close`, `GET /incidents/report` |
| `field-reports` | CRUD + `/{id}/details` |
| `complaints` | CRUD + `/{id}/assign`, `/{id}/status`, `/{id}/close`, `GET /complaints/sla-breached` |
| `gate-passes` | CRUD + `POST /{id}/exit`, `GET /gate-passes/report` |
| `sales` | `/visits`, `/follow-ups`, `/follow-ups/due`, `/client-relations`, `GET /sales/pipeline` |
| `uniform` | `/items`, `/stock`, `/stock/transactions`, `POST /uniform/issue`, `POST /uniform/return`, `GET /uniform/ledger/{empId}` |
| `payroll` | `POST /payroll/runs`, `GET /payroll/runs`, `POST /payroll/runs/{id}/recalculate`, `POST /payroll/runs/{id}/lock`, `GET /payroll/runs/{id}/slips`, `GET /payroll/slips/{empId}/{monthYear}`, `GET /payroll/runs/{id}/bank-advice`, `GET /payroll/runs/{id}/pf-ecr`, `GET /payroll/runs/{id}/esic` |
| `advances` | CRUD + `/{id}/approve` |
| `invoices` | `POST /invoices/generate`, CRUD, `POST /{id}/send`, `POST /{id}/receipt`, `GET /invoices/ageing` |
| `documents` | `POST /documents/upload-url`, `POST /documents`, `GET /documents`, `GET /documents/expiring`, `POST /documents/{id}/verify` |
| `hr` | `/resignations`, `/exits`, `/rejoins`, `/trainings`, `/requests`, `/suggestions` |
| `reports` | `GET /reports/{key}` for all 20 report keys, plus `GET /reports/{key}/export?format=xlsx|csv|pdf` |
| `dashboard` | `GET /dashboard/{role}` returns role-shaped widget payload in one call |
| `chat` | `GET /chat/threads`, `GET /chat/threads/{id}/messages`, `POST /chat/messages` (SignalR for live) |

---

## 6. File Upload

**Direct-to-blob, never through the API.**
1. `POST /api/v2/documents/upload-url` → `{ uploadUrl (SAS, 10 min), blobPath, maxBytes, allowedMimeTypes }`
2. Client PUTs the bytes to `uploadUrl`.
3. Client `POST /api/v2/documents` with `{ blobPath, ownerType, ownerId, docTypeId, issueDate, expiryDate }`.

Rules: images compressed client-side to ≤ 200 KB / max 1280 px before upload; allowed `image/jpeg`, `image/png`, `image/webp`, `application/pdf`; max 10 MB; every stored file is virus-scanned by an async job; reads always via short-lived SAS, never public containers.
Legacy `uploaddoc` multipart endpoint is retained for the old APK and internally forwards to blob storage.

---

## 7. Real-time (SignalR)

| Hub | Events |
|---|---|
| `/hubs/live-map` | `LocationUpdated(userId, lat, lng, at)` — group per `company:{id}` and `unit:{id}` |
| `/hubs/approvals` | `AttendancePendingCountChanged`, `NewApprovalRequest` |
| `/hubs/chat` | `MessageReceived`, `MessageRead`, `Typing` |
| `/hubs/alerts` | `PanicRaised`, `GeofenceBreach`, `PatrolRoundMissed`, `PostVacant` |

Auth via the access token in the query string; groups joined server-side from token claims only.

---

## 8. Background Jobs (Hangfire)

| Job | Schedule | Purpose |
|---|---|---|
| `MarkAbsentForNoPunch` | every 30 min | after shift end + grace, insert `Status='A'` rows |
| `SnapshotDailyTurnout` | 00:15 daily | freeze required vs present per unit |
| `RefreshAttendanceSummary` | 01:00 daily | rebuild `ops.AttendanceSummary` for the current month |
| `DetectMissedPatrolRounds` | every 15 min | compare `PatrolRound` expectations to `QrScanLog`, push alert |
| `RaiseDocumentExpiryAlerts` | 06:00 daily | T-90/30/7 alerts for PV, medical, gun licence, ID card, agreements |
| `VacantPostAlert` | every 15 min | T-60 min before shift start, notify ops if deployed < required |
| `SendScheduledNotifications` | every 5 min | FCM fan-out with batching and token cleanup |
| `PayrollPrecompute` | 02:00 on the 1st | draft run for the previous month |
| `InvoiceReminder` | 09:00 daily | overdue invoice reminders to client contacts |
| `PurgeLocationLogs` | 03:00 daily | retention enforcement |
| `RebuildIndexes` / `UpdateStatistics` | weekly / nightly | maintenance |

---

## 9. Errors

RFC 7807 problem+json:
```json
{ "type": "https://docs.diti365.com/errors/GEOFENCE_VIOLATION",
  "title": "Punch rejected",
  "status": 422,
  "code": "GEOFENCE_VIOLATION",
  "detail": "You are 412 m from Unit ITC Maurya. Allowed: 150 m.",
  "traceId": "00-abc...-01",
  "errors": { "latitude": ["outside geofence"] } }
```

| Code | HTTP | Meaning |
|---|---|---|
| `AUTH_INVALID_CREDENTIALS` | 401 | |
| `AUTH_ACCOUNT_LOCKED` | 423 | 5 failed attempts |
| `AUTH_DEVICE_NOT_REGISTERED` | 403 | device binding mismatch |
| `LICENCE_EXPIRED` | 402 | tenant licence lapsed |
| `LICENCE_USER_LIMIT` | 402 | `MaxUsers` exceeded |
| `TENANT_PARAM_FORBIDDEN` | 400 | client tried to set CompanyID |
| `PERMISSION_DENIED` | 403 | |
| `GEOFENCE_VIOLATION` | 422 | punch/scan outside radius |
| `DUPLICATE_PUNCH` | 409 | same emp/date/shift |
| `MOCK_LOCATION_DETECTED` | 422 | |
| `ATTENDANCE_LOCKED` | 409 | month closed by payroll |
| `PAYROLL_RUN_LOCKED` | 409 | |
| `DUPLICATE_AADHAAR` | 409 | recruit/employee dedupe |
| `VALIDATION_FAILED` | 422 | FluentValidation output |
| `RATE_LIMITED` | 429 | |

---

## 10. Non-Functional API Requirements

- **Performance:** p95 < 400 ms, p99 < 900 ms for list endpoints at 50 rows. Dashboard endpoints < 1 s (cached 60 s in Redis/`IMemoryCache`).
- **Pagination is mandatory** on every list; default 50, max 200. Unbounded queries are a build failure.
- **Compression:** Brotli/Gzip. **ETag** on master-data endpoints so mobile can `304`.
- **Idempotency:** `Idempotency-Key` header honoured on all POSTs that create field records (punch, scan, gate pass, incident).
- **Observability:** Serilog structured logs with `traceId`, `companyId`, `userId`; OpenTelemetry traces; `/metrics` for Prometheus.
- **Security headers:** HSTS, `X-Content-Type-Options`, `Referrer-Policy`, strict CORS allow-list. TLS 1.2+ only.
- **Secrets:** Azure Key Vault / environment variables; nothing in `appsettings.json` committed.
- **Swagger** exposed on non-prod only; on prod, publish the OpenAPI file to the docs site instead.

---

## 11. Definition of Done — Phase 1.5

- [ ] Zero occurrences of EF Core, Dapper, `DbContext` or inline SQL in the solution; the CI guard in §3.8 passes.
- [ ] Every database call is a stored procedure invoked through `IDbExecutor` with typed `SqlParameter`s.
- [ ] All 120 v1 endpoints respond with the legacy envelope, verified by a replay harness recording real `Diti365.apk` traffic.
- [ ] All v2 resources implemented with pagination, filtering, sorting and export where listed.
- [ ] Integration tests run against a Testcontainers SQL Server seeded by the Phase-1 scripts; ≥ 80 % line coverage on Application layer.
- [ ] Tenant-isolation test suite: for every endpoint, a Company-2 token must never read or write Company-1 data.
- [ ] RBAC test suite: every `[HasPermission]` verified positive and negative.
- [ ] Load test: 200 concurrent punch requests/sec sustained for 5 min with p95 < 400 ms.
- [ ] Zero `usesCleartextTraffic`; API refuses plain HTTP.
