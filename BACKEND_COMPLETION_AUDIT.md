# Backend Completion Audit

**Generated:** 2026-07-28  
**Scope:** Database → Backend → API (frontend intentionally out of scope)  
**Sources:** all `*.md` docs, `db/scripts/*`, `api/src/**`, live `Diti365_Dev`

---

## Executive verdict

| Layer | Status | Notes |
|---|---|---|
| Database scripts | **COMPLETE** (DoD sign-off pending) | 107 tables, 150 procs, views/functions/triggers/seeds present |
| Live `Diti365_Dev` | **APPLIED** | Matches script inventory |
| API host / DI | **COMPLETE** (this pass) | `Program.cs`, JWT, rate limit, Swagger, Serilog |
| V2 REST surface | **MOSTLY COMPLETE** | Core modules wired to existing repositories |
| V1 legacy surface | **PARTIAL → SUBSTANTIAL** | All 5 controllers exist; request-shape parity with APK not fully proven |
| Hangfire / SignalR / Blob SAS | **MISSING** | Spec §6–§8; no jobs/hubs/upload-url yet |
| Integration tests | **MISSING** | No test projects under `api/tests` |

**BACKEND COMPLETION: ~72%**

---

## Module matrix

| Module | Requirement | DB tables / SPs | Backend (repo) | API | Status | Issues / fixes this pass |
|---|---|---|---|---|---|---|
| M1 Auth / tenancy | JWT, OTP, device, refresh | `sec.*`, `usp_User_*` | `AuthRepository`, `AuthService` | V2 `auth`, V1 `Users` | **COMPLETE** (OTP SMS seam TODO) | Host + DI added; login verified (`diti.admin` / `Admin@123`); PBKDF2 upgrade works |
| M2 Tenant admin | companies CRUD, suspend, impersonate | `org.Company`, company log SPs | `MasterRepository` (list/log) | V2 `companies` list/log | **PARTIAL** | Create/suspend/extend/impersonate SPs/API still missing |
| M3 Masters | bootstrap + lookups | `mst.*`, `usp_Master_*` | `MasterRepository` | V2 `masters`, V1 Users master GETs | **COMPLETE** for reads | Tenant-editable POST/PATCH/DELETE not exposed |
| M4 Client / Unit | CRUD, posts, geofence, locations | `crm.*`, people SPs | `PeopleRepository` | V2 clients/units/posts/locations; V1 Operation | **COMPLETE** for SP-backed ops | Client list-by-id nested routes incomplete |
| M5 Recruitment | pipeline, approve/convert | recruit SPs | `PeopleRepository` | V2 `recruits/*`; V1 Operation | **COMPLETE** | — |
| M6 Employee 360 | core + sub-resources | employee SPs | `PeopleRepository` | V2 employees + sub-resources; V1 | **COMPLETE** for existing SPs | Qualifications/physical/photo endpoints not separate if SP gaps |
| M7 Deployment / Turnout | deploy, movement, inc/dec, turnout | ops deployment SPs | `OpsRepository` | V2 Operations; V1 Operation | **COMPLETE** | — |
| M8 Attendance | punch, sync, approve, summary | attendance SPs | `AttendanceRepository` | V2 `attendance`; V1 Operation | **COMPLETE** | Fixed `QuerySingleAsync<AttendanceCounts>` compile bug |
| M9 Patrol | checkpoints, scan, rounds | patrol SPs | `OpsRepository` | V2 patrol; V1 Operation | **COMPLETE** | QR PNG generation not implemented |
| M10 Tracking | ping, live, trail | location SPs | `OpsRepository` | V2 tracking; V1 Operation | **COMPLETE** | Batch ping missing |
| M11 Tasks | CRUD + status/history | task SPs | `WorkflowRepository` | V2 tasks; V1 Tasks | **COMPLETE** | — |
| M12 Incidents / Complaints / Field | create/close/list | incident/complaint SPs | `WorkflowRepository` | V2 + V1 Operation | **COMPLETE** | Incident list report via Reports |
| M13 Sales | visits, follow-ups, relations | sales SPs | `SalesRepository` | V2 sales; V1 Sales | **COMPLETE** | — |
| M14 Uniform / Inventory | stock, issue, return, ledger | inventory SPs | `WorkflowRepository` | V2 uniform; V1 Operation | **COMPLETE** | Item master CRUD via masters lookup only |
| M15 Payroll / Billing / Advances | runs, slips, invoices | finance SPs | `FinanceRepository` + advances in Workflow | V2 finance; V1 salary/bill/advance | **COMPLETE** for SP set | Recalculate endpoint not separate from generate |
| M16 HR / Gate / Requests / Docs | lifecycle, training, gate, docs | HR/doc SPs | `WorkflowRepository` | V2 hr/gate/documents; V1 | **COMPLETE** for SP set | Chat not implemented |
| Reports / Dashboard | allow-listed reports | report SPs | `ReportRepository` | V2 reports/dashboard; V1 Report | **COMPLETE** | Export xlsx/csv/pdf missing |
| Realtime | SignalR hubs | — | — | — | **MISSING** | Spec §7 |
| Background jobs | Hangfire | job SPs exist | — | — | **MISSING** | Spec §8 |
| File upload SAS | Blob upload-url | doc SP exists | save metadata only | — | **PARTIAL** | Spec §6 — metadata POST only |
| V1 APK parity | 120 endpoints, legacy envelope | — | repos | V1 controllers | **PARTIAL** | Controllers present; APK replay harness not run |
| Tests | unit + Testcontainers | — | — | — | **MISSING** | `api/tests` empty |

---

## Fixes performed this session

1. Added `Program.cs` (JWT, rate limiting, Swagger, CORS, Serilog, TenantGuardFilter).
2. Added `DependencyInjection.cs` registering all repositories and auth services.
3. Added `appsettings.json` + gitignored `appsettings.Development.json` (local SQL + JWT).
4. Added V2 controllers: People, Finance, Sales, Workflow, Reports (wiring existing repos).
5. Added V1 controllers: Users, Operation, Tasks, Sales, Report with legacy envelope.
6. Fixed Infrastructure `FrameworkReference` / package prune conflicts for .NET 10.
7. Suppressed analyzer rules that conflict with deliberate ADO.NET conventions (`P.Int`, etc.).
8. Fixed `AttendanceRepository.GetCountsAsync` type inference and `OtpService` usings.
9. Verified: `dotnet build` succeeds; `/health` 200; login upgrades PLAINTEXT → PBKDF2.

---

## Remaining blockers / next work

1. **Hangfire jobs** from `02-api.md` §8 (absent marking, turnout snapshot, missed patrol, etc.).
2. **SignalR hubs** (live-map, approvals, chat, alerts).
3. **Blob SAS** upload-url + virus-scan job.
4. **SUPER_ADMIN company lifecycle** (create/suspend/extend/impersonate) — needs SPs if not present.
5. **Integration + tenant-isolation + RBAC test suites**.
6. **APK traffic replay** to prove V1 request/response byte-level compatibility.
7. **DbUp runner** still pending (`db/run-all.ps1` works meanwhile).
8. OTP SMS gateway still a TODO seam (fails closed outside Development).

---

## Build / runtime verification

| Check | Result |
|---|---|
| `dotnet build api/Diti365.sln` | **Succeeded** |
| `GET /health` | **200** `{ status: ok }` |
| `POST /api/v2/auth/login` (`diti.admin` / `Admin@123`) | **200**; password rehashed |
| Device rebinding with new `deviceId` | **403 AUTH_DEVICE_NOT_REGISTERED** (expected) |
| Live DB | 107 tables, 150 procedures |
