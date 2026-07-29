# Database ↔ Backend Matrix

Status values: **COMPLETE** | **PARTIAL** | **MISSING** | **N/A** (no public API by design)

Verification basis: repository methods call named stored procedures; controllers call those repositories. Marked COMPLETE only when Entity/access + Service/repo + API path exist and compile.

| Database Area | Schema / Tables (examples) | Entity / DTO | Repository | API | Business Logic | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Auth / Users / Roles / Permissions | `sec.Users`, `Role`, `RolePermission`, `RefreshToken`, `Otp`, `LoginLog` | Auth contracts | `AuthRepository`, `AuthService`, `RefreshTokenStore` | V2 `/auth/*`, V1 `/Users/*` | PBKDF2, device bind, refresh rotate | COMPLETE |
| Company / Branch | `org.Company`, `Branch` | Dynamic Row | `MasterRepository` | V2 `/companies` (list/log) | Licence checks on login | PARTIAL |
| Masters | `mst.*` (28) | `LookupItem`, Row | `MasterRepository` | V2 `/masters/*` | Bootstrap cold-start | COMPLETE (read) |
| Employees / Recruit | `hr.Employee`, recruit tables | Row + typed inputs | `PeopleRepository` | V2 `/employees`, `/recruits` | Dedupe, convert, blacklist | COMPLETE |
| Client / Unit / Post / Location | `crm.Client`, `Unit`, posts, locations | `ClientInput`, `UnitInput` | `PeopleRepository` | V2 `/clients`, `/units` | Geofence fields on unit | COMPLETE |
| Deployment / Movement / IncDec / Contract | `ops.Deployment`, related | Typed write DTOs | `OpsRepository` | V2 `/deployments`, `/contracts` | Over-strength flags | COMPLETE |
| Turnout | `ops.Turnout` | Typed | `OpsRepository` | V2 `/turnout/*` | Live + vacant posts | COMPLETE |
| Attendance | `ops.Attendance`, summary, TVP | Attendance contracts | `AttendanceRepository` | V2 `/attendance/*` | Geofence/server compute in SP | COMPLETE |
| Patrol / QR | `ops.Qr*`, rounds, scan log | Typed | `OpsRepository` | V2 `/patrol/*` | Distance check in SP | COMPLETE |
| Tracking | location log tables | Typed | `OpsRepository` | V2 `/tracking/*` | Live + trail | COMPLETE |
| Tasks | `ops.Task*` | Typed | `WorkflowRepository` | V2 `/tasks/*` | Status, checklist, read | COMPLETE |
| Incidents / Field reports | incident / field tables | Typed | `WorkflowRepository` | V2 `/incidents`, `/field-reports` | Close + counts | COMPLETE |
| Complaints | complaint tables | Typed | `WorkflowRepository` | V2 `/complaints` | Status + SLA filter | COMPLETE |
| Gate pass | gate pass tables | Typed | `WorkflowRepository` | V2 `/gate-passes` | Exit | COMPLETE |
| HR lifecycle / Training / Requests / Suggestions | HR tables | Typed | `WorkflowRepository` | V2 `/hr/*` | Resign/left/rejoin/training | COMPLETE |
| Uniform / Stock | `inv.*` | Typed | `WorkflowRepository` | V2 `/uniform/*` | Issue/return/ledger | COMPLETE |
| Documents | `doc.*` | Typed | `WorkflowRepository` | V2 `/documents` | Expiring list; no SAS yet | PARTIAL |
| Payroll | `fin.Payroll*` | Row | `FinanceRepository` | V2 `/payroll/*` | Generate/lock/slips/statutory | COMPLETE |
| Invoices / Receipts | `fin.Invoice*` | Row | `FinanceRepository` | V2 `/invoices/*` | Generate + receipt | COMPLETE |
| Advances | advance tables | Typed | `WorkflowRepository` | V2 `/advances` | Approve | COMPLETE |
| Sales CRM | `crm.SalesVisit`, FollowUp, ClientRelation | Typed | `SalesRepository` | V2 `/sales/*` | Pipeline | COMPLETE |
| Reports / Dashboard | report procs + views | Dynamic Row | `ReportRepository` | V2 `/reports/*`, `/dashboard/{role}` | Allow-listed keys only | COMPLETE |
| Audit tables | `aud.*` | — | — | — | Written by triggers/SPs | N/A (no public CRUD) |
| Code counters | `mst.CodeCounter` | — | via code SPs | — | Gapless emp/invoice codes | N/A (internal) |
| Chat | comms tables (if any) | — | — | — | Spec requires SignalR | MISSING |
| Hangfire job procs | absentee, purge, etc. | — | — | — | Spec §8 | MISSING |

## API surface counts (approximate)

| Surface | Controllers | Notes |
|---|---|---|
| V2 | Auth, Me, Masters, Attendance, Operations, People, Finance, Sales, Workflow, Reports | Primary web/new-mobile API |
| V1 | Users, Operation, Tasks, Sales, Report | Legacy APK envelope |

## Intentionally no public API

| Area | Why |
|---|---|
| `aud.*` audit tables | Append-only via triggers/SPs; read via audit permission later |
| `mst.CodeCounter` | Internal numbering only |
| Seed / demo scripts | Dev data only |
| Trigger objects | Server-side backstops, not HTTP |
