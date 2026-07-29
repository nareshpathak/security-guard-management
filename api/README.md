# Diti365 API

.NET 10 Web API. Raw ADO.NET calling stored procedures — no EF Core, no Dapper, no ORM.
Spec: `docs/prd/02-api.md`.

## Prerequisites

* .NET 10 SDK
* SQL Server 2019+ with `Diti365_Dev` created and `db/run-all.ps1` run successfully

## Build and run

```powershell
cd api
dotnet restore
dotnet build
dotnet run --project src/Diti365.Api
```

Swagger opens at `https://localhost:7175/swagger` in Development.

## Configuration

`appsettings.Development.json` carries a working local connection string and a
development signing key. Nothing else is committed.

For any other environment set these as environment variables — the host refuses to
start if the signing key is missing or shorter than 32 bytes:

```
Database__ConnectionString=Server=...;Database=Diti365;...
Jwt__SigningKey=<32+ byte secret from Key Vault>
Cors__AllowedOrigins__0=https://app.diti365.com
```

## Demo logins

Seeded by `db/scripts/711_seed_demo_tenant.sql`. These work **only** in Development:
the seed stores `PLAINTEXT:<password>` in `LegacyPasswordHash`, and the API accepts
that prefix only when `ASPNETCORE_ENVIRONMENT=Development`, re-hashing with PBKDF2 on
first login. See `DECISIONS.md` #25.

| User | Password | Role |
|---|---|---|
| `superadmin` | `Admin@123` | Platform |
| `diti.admin` | `Admin@123` | Company admin |
| `diti.ops` / `diti.hr` / `diti.accounts` | `Admin@123` | Operations / HR / Accounts |
| `diti.sup1` … `diti.sup3` | `Admin@123` | Supervisors |
| `diti.gate1` / `diti.patrol1` / `diti.sales1` | `Admin@123` | Gate / Patrol / Sales |
| `dti00001` … | `Guard@123` | Guards |
| `client001` | `Client@123` | Client portal |
| `shield.admin` | `Admin@123` | Second tenant, for isolation tests |

```bash
curl -k -X POST https://localhost:7175/api/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"loginId":"diti.admin","password":"Admin@123"}'
```

## Project layout

```
src/
  Diti365.Domain/          error codes, domain exception, role and status constants
  Diti365.Contracts/       request and response records shared with the TS client
  Diti365.Application/     ICurrentUser, permission codes
  Diti365.Infrastructure/
    Data/                  IDbExecutor, P parameter helpers, SQL error translation
    Security/              PBKDF2, JWT, refresh rotation, OTP, AuthService
    Repositories/          one per domain, all calling stored procedures
  Diti365.Api/
    Controllers/V2/        the current REST API
    Controllers/V1/        legacy surface for Diti365.apk v4.8
    Filters/               TenantGuardFilter, HasPermissionAttribute
    Middleware/            RFC 7807 errors, request logging
```

## The rules this codebase enforces

1. **`CompanyID` never comes from the client.** `TenantGuardFilter` rejects any request
   carrying `companyId`, and `DbExecutor` injects it from the JWT. A repository has no
   way to accept a tenant id.
2. **Every call is a stored procedure.** There is no method on `IDbExecutor` that takes
   SQL text. If a query is needed, a procedure is added to `db/scripts/`.
3. **Typed parameters only.** `P.Int`, `P.NVar(name, value, size)`, `P.Money`. Never
   `AddWithValue` — it infers the wrong type and produces a new cached plan per string
   length.
4. **Ordinals are cached outside the row loop.** Mappers are factories that resolve
   ordinals once per result set.
5. **Transactions live in the procedure**, never in C#.
6. **Server computes what the client must not.** Geofence distance, worked hours and
   attendance status are derived in SQL; a punch payload claiming them is ignored.

## Legacy compatibility

`api/{Users|Operation|Tasks|Sales|Report}/*` reproduce the old envelope
`{Success, Status, Id, Message, Data}` exactly, so the ~900 phones running
`Diti365.apk` v4.8 keep working through cutover. The only change they see is that the
API refuses plain HTTP. Retire this surface once v5 adoption passes 95 percent.

## Not yet wired

These are seams with interfaces but no production implementation:

* **Blob storage** for documents, selfies and patrol photos — the SAS upload flow in
  `docs/prd/02-api.md` §6.
* **SMS gateway** — `OtpService.SendAsync` logs in Development and fails closed
  elsewhere rather than pretending to send.
* **FCM push** — notification rows are written to `doc.Notification`; the fan-out job
  is not built.
* **Hangfire jobs** — the procedures exist (`usp_Attendance_MarkAbsentForNoPunch`,
  `usp_Patrol_DetectMissedRounds`, `usp_Turnout_DetectVacantPosts`,
  `usp_Location_Purge`, `usp_Attendance_RefreshSummary`); the scheduler is not.
* **SignalR hubs** for the live map, approvals and chat.
* **QuestPDF** documents — salary slip, invoice, attendance register, gate pass, ID card.
