# Diti365 — Security Agency Management System (SAMS)
## Product Requirements Document (PRD) v1.0

> **Purpose of this document:** This is a build-ready specification written to be consumed by Cursor (or any AI coding agent) to generate the Diti365 platform end-to-end: **Database → Backend API → Web App → Android/iOS App**, in that order.
>
> **Source of truth:** This PRD was reverse-engineered from the production Android app `Diti365.apk` (package `com.diti.securityguarding`, versionName `4.8`) plus the live API surface it calls. Every module, screen, endpoint and data field listed here exists in, or is a deliberate improvement over, the current live product.

---

## 0. Document Map

| File | Contents |
|---|---|
| `PRD.md` (this file) | Product overview, personas, roles, module map, scope, architecture, phased delivery |
| `docs/01-database.md` | **Phase 1** — Complete SQL Server schema: tables, columns, keys, indexes, views, functions, stored procedures, triggers, seed data |
| `docs/02-api.md` | **Phase 1.5** — .NET 10 Web API: full endpoint inventory, contracts, auth, envelopes, jobs |
| `docs/03-web.md` | **Phase 2** — Next.js SaaS web app: design system, IA, screen-by-screen specs |
| `docs/04-mobile.md` | **Phase 3** — React Native (Expo) app: screens, offline sync, GPS/QR/biometric attendance |
| `docs/05-rbac-and-nfr.md` | Role permission matrix, security, performance, compliance, acceptance criteria, roadmap |
| `docs/06-apk-inventory.md` | Raw evidence appendix — extracted activities, fragments, models, endpoints from the APK |

**Build order is mandatory.** Do not start the web app until the database is created and seeded. Do not start mobile until the web app's API contracts are frozen.

---

## 1. Product Overview

### 1.1 What Diti365 is

Diti365 is a **multi-tenant SaaS platform for private security agencies** (security guarding companies). A security agency deploys guards/gunmen at client sites ("units"), and must manage the full lifecycle:

**Recruit → Verify → Train → Deploy → Track (attendance + patrol) → Pay → Bill the client → Handle incidents & complaints → Retain or offboard.**

Diti365 digitises that entire lifecycle across three surfaces:

1. **Web (SaaS console)** — head office, branch admins, HR, operations, accounts, sales.
2. **Mobile app (Android/iOS)** — field staff: guards, supervisors, gatekeepers, night patrol officers, sales executives.
3. **Client portal** — the agency's customers see their own guards, attendance, patrol logs, complaints and invoices.

### 1.2 Current state (as-is, from APK analysis)

| Attribute | Current |
|---|---|
| Android package | `com.diti.securityguarding` v4.8 |
| Architecture | Native Kotlin/Java, XML + DataBinding, Retrofit + OkHttp, Picasso |
| Backend | ASP.NET Web API at `http://web521.66.232.new.ocpwebserver.com/api/` |
| API controllers | `Users`, `Operation`, `Tasks`, `Sales`, `Report` |
| Legacy web | `http://web.securityguardingsoftwares.com/` and `http://jpsonline.in/` (WebForms `.aspx` report/print pages opened in WebView) |
| Realtime | Firebase Realtime Database (chat), Firebase Cloud Messaging (push), Firebase Auth (phone OTP) |
| Database | Microsoft SQL Server |
| Endpoints | 120 documented endpoints |
| Screens | 27 activities + 90 fragments |
| Role dashboards | 8 |

**Known problems with the as-is system (these are the reasons for the rebuild):**

- `usesCleartextTraffic="true"` — API traffic is plain HTTP. **Critical security defect.**
- No JWT/OAuth — session handled via a raw user id + device id.
- Business logic scattered between the app, WebForms pages and SPs; reports rendered as `.aspx` pages inside a WebView.
- No design system; each screen has its own layout binding (300+ binding classes).
- Legacy monolith DB with inconsistent naming (`EmpID`, `Empid`, `empid` all appear).
- No proper multi-tenant isolation guarantee; `CompanyID` is passed by the client.
- No offline support — guards in low-signal sites cannot punch attendance.
- No audit trail, no soft deletes in most tables.

### 1.3 Vision (to-be)

> A premium, fast, mobile-first SaaS that any security agency in India can sign up for, configure in a day, and run their entire field operation on — with bank-grade audit trails, real-time guard visibility on a map, and one-click statutory payroll & client invoicing.

### 1.4 Product principles

1. **The guard's phone is the primary sensor.** GPS, camera, QR scan and clock are the truth; the office reconciles.
2. **Every number is drillable.** Any figure on a dashboard clicks through to the row-level records that produced it.
3. **Never lose a punch.** Offline-first attendance and patrol with a durable outbox queue.
4. **Tenant isolation is enforced server-side, always.** The client never chooses its own `CompanyId`.
5. **Statutory-correct by default.** PF, ESIC, LWF, PT, bonus, minimum wages per state.
6. **Fast.** p95 API < 400 ms; every list virtualised and server-paginated.

---

## 2. Personas & Roles

### 2.1 Role catalogue

Eight role dashboards exist in the current app (`HomeSuperAdmin_frag`, `HomeAdmin_frag`, `HomeSupervisor_frag`, `HomeGatekeeper_frag`, `HomeNightPatrol_frag`, `HomeSales_frag`, `ClientMainActivity`, `EmployeeMainActivity`). The to-be system keeps these and adds three back-office roles that today share the Admin login.

| # | Role code | Persona | Primary surface | Core jobs |
|---|---|---|---|---|
| 1 | `SUPER_ADMIN` | Diti365 platform operator | Web | Onboard/suspend agency tenants, licence & user-count limits, expiry, global masters, platform analytics |
| 2 | `COMPANY_ADMIN` | Agency owner / GM | Web + Mobile | Full access within own tenant, all branches, approvals, config |
| 3 | `BRANCH_ADMIN` | Branch manager | Web + Mobile | Everything within assigned branch(es) |
| 4 | `OPERATIONS` | Ops executive | Web + Mobile | Deployment, turnout, movement, relievers, incident handling |
| 5 | `HR` | HR executive | Web | Recruitment, documents, verification, training, resign/rejoin |
| 6 | `ACCOUNTS` | Accountant | Web | Payroll run, advances, uniform recovery, client invoicing, ledgers |
| 7 | `SUPERVISOR` | Field supervisor | Mobile-first | Unit attendance approval, field reports, incidents, guard movement, patrol audit |
| 8 | `GATEKEEPER` | Gate guard | Mobile only | Gate pass entry (visitor in/out with photo + vehicle) |
| 9 | `NIGHT_PATROL` | Night patrolling officer | Mobile only | QR checkpoint scanning with photo + GPS, night visit reports |
| 10 | `SALES` | Sales executive | Mobile + Web | Visit entry, follow-ups, new contracts, client relations |
| 11 | `EMPLOYEE` (Guard/Gunman) | Deployed guard | Mobile only | Self-attendance punch, salary slip, profile, documents, complaints, suggestions, leave/advance requests |
| 12 | `CLIENT` | Agency's customer | Web + Mobile | Own units, guards on duty, attendance, patrol logs, complaints, bills |

> Roles 4–6 (`OPERATIONS`, `HR`, `ACCOUNTS`) are new in v1.0 and must be delivered as fully configurable permission sets, not hard-coded.

### 2.2 Persona detail

**Ravi — Agency Owner (COMPANY_ADMIN), 44, runs 900 guards across 60 client sites in 3 cities.**
Pain: he doesn't know by 9 AM how many posts are vacant today. Needs: a live turnout board (required vs present vs absent vs reliever), and a phone alert when a site falls below contracted strength.

**Sunita — HR Executive, 29.**
Pain: recruits' police verification and medical certificates expire silently; ESIC/PF numbers get keyed twice. Needs: a recruit pipeline with document expiry alerts and a single 200-field biodata form that validates Aadhaar/PAN/IFSC inline.

**Imran — Field Supervisor, 35, covers 8 units on a bike.**
Pain: he approves attendance from a paper muster at 11 PM. Needs: a mobile approval queue per unit, with the guard's punch selfie and GPS distance from the site shown next to each row.

**Deepak — Guard, 26, posted at a factory gate with poor signal.**
Pain: the app fails to punch, so he is marked absent and loses a day's wage. Needs: offline punch that queues and syncs, with a visible "queued / synced" state.

**Mrs. Nair — Client Facility Manager.**
Pain: she has no proof the night patrol actually walked the rounds. Needs: a portal showing every QR checkpoint scan with time, photo and guard name.

---

## 3. Module Map

The system is organised into 16 functional modules. Each module below lists its **as-is evidence** (screens/endpoints found in the APK) so nothing is lost in the rebuild.

### M1 — Authentication, Tenancy & Device Trust
Login (mobile/username + password), phone OTP verification, forgot password, change password, device-ID binding (one account = one registered device unless overridden), licence expiry check, FCM token registration, login log, company log.
*As-is:* `Login_act`, `Enterotp_act`, `Forgotpass_act`, `Changepass_act`, `Splash_act`; endpoints `login`, `checknum`, `changepass`, `checkdeviceid`, `checkexpire`, `updatetoken`, `getLoginLog`, `getCompanylog`, `getCompanylogdetail`, `getrights`.

### M2 — Tenant / Company Administration (SUPER_ADMIN)
Create agency tenant, plan & user-count limit, licence expiry, branch creation, module toggles, impersonation with audit, platform-wide login analytics.
*As-is:* `HomeSuperAdmin_frag`, `Companymodel` (CompanyID, CompanyName, UserCount, LoginCount, IsExpired), `Newmembermodel`, `Companylogrpt_frag`, `Companyloginrpt_frag`.

### M3 — Master Data
Country/State/City/District, Region, Area, Branch, Designation, Grade, Category, Qualification, Shift, Bank + IFSC, Complaint type, Incident type, Uniform item + rate, Task repetition type, Service type, Holiday calendar, Minimum-wage table per state/category.
*As-is:* `getstates`, `getcity`, `getdesignation`, `getqualification`, `getcomplaintype`, `gettype`, `getsubdropdown`, `getlist`.

### M4 — Client & Unit (Site) Management
Client company master, contact persons, multiple units/sites per client, site GPS geofence, agreement no. & expiry, work order no. & expiry, contracted strength by designation/shift, billing rates, client user logins, client locations.
*As-is:* `Addclient_frag`, `Addclientlocation_act`, `Myclients_frag`, `Myunits_frag`, `Cclist_act`, `addclient`, `addsite`, `updatesite`, `getunit`, `getuserunit`, `getMyClient`; `Unitmodel` (AgreementNo, AgreementExpDate, OrderNo, OrderDate, OrderExpiryDate, WorkStartDate).

### M5 — Recruitment
Recruit intake (200+ field biodata), pending recruit queue, approve/reject/blacklist, waitlist, duplicate detection by Aadhaar/mobile/old emp code, recruitment reports, new-joins register.
*As-is:* `Addrecrut_act`, `Waitlist_frag`, `Newjoin_frag`, `RecruitAdapter`, `RecruitmentrptAdapter`, `addrecruits`, `updaterecruits`, `getrecruits`, `getpendingrecruit`, `getrecruitdata`, `getNewRecruits`, `getRecruitedEmployee`.

### M6 — Employee (Guard) 360
Full employee master: personal, permanent/present address, family (father/mother/wife/dependents), qualifications, ex-service details (rank, regiment, discharge), physicals (height, weight, chest, waist, shoe/trouser/t-shirt size, blood group, eyes), bank + joint account, statutory IDs (Aadhaar, PAN, UAN/PF, ESIC, Voter, DL), police verification (PV no., send/return date, validity, thana remark), medical certificate + doctor details, gun licence (gun no., model, type of arm, licence expiry, area validity), ID card issue/expiry, belt no., swipe no., documents & photos, blacklist flag.
*As-is:* `Employeedetails_act`, `Familydetail_act`, `Documentupload_act`, `Documentdetails_act`, `Stafflist_frag`, `Profile_frag`; `Addrecruitmodel$Datum` (196 fields — see `docs/06-apk-inventory.md`); endpoints `getemp`, `getemployee`, `getstafflist`, `getprofile`, `addfamily`, `bankdetails`, `uploaddoc`, `docdetail`, `addgunman`, `addrelievers`.

### M7 — Deployment & Turnout
Assign guards to unit/post/shift, increase/decrease deployment (IncDec), new contract deployment, contract termination, temporary event deployment, guard movement between posts/units, reliever assignment, daily turnout register (required vs present vs vacant), duty list.
*As-is:* `IncDecDeployment_frag`, `Newcontract_frag`, `Contracttermination_frag`, `Temporaryevent_frag`, `Movement_frag`, `Turnout_frag`, `Dutylist_frag`, `Addreliever_act`; endpoints `incDecDeployment`, `newcontractDeployment`, `contractTermination`, `temporaryEvent`, `movement`, `insertturnout`, `getturnoutrpt`, `getreliever`, `getunitemployee`.

### M8 — Attendance
Guard self-punch (IN/OUT) with GPS + selfie + geofence distance check; supervisor bulk marking; attendance-for-approval queue; approve/reject with reason; monthly attendance summary; daily attendance register print; attendance count on dashboard; double-shift/OT handling.
*As-is:* `SelfAttendancepunch_frag`, `Attendancepunch_frag`, `Attendanceop_frag`, `Approveattend_frag`, `Attendancesummary_frag`, `Showattendance_frag`, `Showselfattend_frag`, `Dailyattendanceprint_frag`; endpoints `insertattendance`, `insertattendancein`, `insertattendanceout`, `getattendance`, `getselfattendance`, `attendforapproval`, `approve`, `getattendsummary`, `getAttendanceCount`.

### M9 — QR Patrol & Checkpoints
Generate QR checkpoints per unit/location, print QR, scan QR (with optional photo capture), enforce max distance between guard GPS and checkpoint GPS, patrol logs by admin/client/supervisor/location, patrol summary, missed-round alerts.
*As-is:* `Createqr_act`, `Qrscanner_frag`, `Qrloglist_frag`, `QrlistAdapter`, `Shownightpatrol_frag`; endpoints `addclientqr`, `getqrlist`, `getqrlistadmin`, `getqrlistsummary`, `getqrdistance`, `readqr`, `readqrwithimage`, `GetQRlog*`.

### M10 — Live Location Tracking
Background location ping from supervisor/patrol devices, per-user location log, today's log, location summary, map view of all field staff, unit-wise location log, track report.
*As-is:* `Locationfetch_act`, `Locationlog_frag`, `Locationuserlog_frag`, `Todaylog_frag`, `Logsummary_frag`, `LogReportAdmin_frag`, `HomeMapsActivity`, `GoogleService` (foreground service); endpoints `trackLocation`, `trackRpt`, `getlocationlog`, `getuserlocationlog`.

### M11 — Task Management
Assign task with heading/description/priority/attachment/start-end date/repetition, tasks assigned-by-me and assigned-to-me, status transitions, close with remark, task history, read receipts, due-days ageing, delete.
*As-is:* `Taskassign_frag`, `Tasklist_frag`, `Recievedtasklist_frag`, `Taskhistory_frag`, `Taskshome_frag`, `Taskdetails_act`, `Closedtaskdetail_act`, `Statushistory_act`; endpoints `addtask`, `gettasklistby`, `gettasklistto`, `gettaskstatus`, `updatetaskstatus`, `closetask`, `closetaskhistorylist`, `deletetask`, `readtask`.

### M12 — Incidents, Field Reports & Complaints
Incident entry (type, date, time, guard, remark, photo), incident report, field visit report by supervisor, report detail & counts, complaint raise (by client or employee), complaint assignment, status update & closure, unit complaints.
*As-is:* `Incident_frag`, `Incidentrpt_frag`, `Fieldreport_frag`, `Reportdetail_frag`, `Complaint_frag`, `Mycomplaints_frag`, `Assignedunitcomplaints_frag`, `Suggestion_frag`; endpoints `insertincident`, `incidentRpt`, `insertfield`, `getrptdetail`, `getcount`, `insertcomplaint`, `getcomplaint`, `getunitcomplaint`, `updatecomplaintstatus`, `insertsuggestion`.

### M13 — Sales / CRM
Client visit entry (company, contact, location, purpose, remark), visit report, follow-up entry with next-follow-up date and stop-follow flag, follow-up reports (own + admin view), new contract pipeline, client relation visit & report.
*As-is:* `Salesvisitentry_frag`, `Salesvisitrpt_frag`, `Visitentry_frag`, `Followup_frag`, `Followuprpt_frag`, `Nextfollowup_frag`, `Adminfollowrpt_frag`, `Adminnextfollowrpt_frag`, `Adminvisitrpt_frag`, `Clientrelation_frag`, `Clientrelationrpt_frag`; endpoints `visitEntry`, `visitReport`, `getVisitLog`, `followupEntry`, `followReport`, `nextfollowReport`, `clientRelation`, `clientrelationRpt`.

### M14 — Uniform & Inventory
Uniform item master with rate, branch-wise stock, issue to employee, return from employee, employee uniform ledger (issued vs received), stock report, salary recovery of uniform cost.
*As-is:* `Uniform_frag`, `Uniformissue_frag`, `Unifromreturn_frag`, `Uniformledger_frag`, `Uniformstock_frag`; endpoints `issueitem`, `issueemployee`, `returnitem`, `returnemployee`, `getstock`, `getbranchstock`, `GetUniformLedger`.

### M15 — Payroll & Billing
Monthly salary computation from approved attendance (basic, HRA, food, leave, reliever allowance, special allowance, bonus, OT), statutory deductions (PF, ESIC, PT, LWF), advances and uniform recovery, salary slip (mobile + PDF), client invoice generation from deployed strength × rate, bill list and print.
*As-is:* `Salaryslip_frag`, `Showbill_frag`, `Issueadvnce_frag`; `Salaryslipmodel$Datum` (BasicWages, HRAAmt, FoodAllow, LeaveAllow, ReliverAllow, SpAllowance, BonusAmt, PFAmt, ESICAmt, PtEmp, LwfEmp, DeductionAmt, TotalEarnings, NetPayble, MonthYear, WcsSalaryID); endpoints `getsalary`, `getbill`, `insertadvance`; legacy print `PrintSalary.aspx`, `Report_CrInvoicePrint.aspx`, `PrintDailAttendance.aspx`.

### M16 — HR Lifecycle, Gate Pass, Training, Communication
Resignation, left (exit), rejoin, training entry & report, gate pass (visitor entry with photo, vehicle, purpose), employee requests (leave/advance/transfer), in-app chat, push notifications, document expiry alerts.
*As-is:* `Resign_frag`, `Left_frag`, `Rejoin_frag`, `Training_frag`, `Trainingrpt_frag`, `Gatepassentry_frag`, `Gatepassreport_frag`, `Request_frag`, `Chat_act`, `Messagemodel`; endpoints `resign`, `resignRpt`, `insertleft`, `insertrejoin`, `training`, `trainingRpt`, `insertgatepass`, `insertrequest`, `updateFlag`.

---

## 4. Scope

### 4.1 In scope — v1.0

All 16 modules above, delivered in three phases:

- **Phase 1 — Database.** One consolidated SQL Server database: all tables, keys, indexes, views, scalar/table-valued functions, stored procedures, triggers, and a seed script with realistic demo data (1 platform tenant + 2 demo agencies, ~40 employees, 6 units, 3 months of attendance, patrol logs, tasks, complaints, one payroll run and one invoice). **Delivered and run as a single ordered migration set.**
- **Phase 2 — Web.** Next.js SaaS console covering all 16 modules for SUPER_ADMIN, COMPANY_ADMIN, BRANCH_ADMIN, OPERATIONS, HR, ACCOUNTS, SALES, CLIENT.
- **Phase 3 — Mobile.** React Native (Expo) app for SUPERVISOR, GATEKEEPER, NIGHT_PATROL, SALES, EMPLOYEE, CLIENT, plus admin-on-the-go.

### 4.2 Out of scope — v1.0 (backlog)

Biometric/face-recognition attendance hardware integration; e-signature on agreements; GST e-invoicing IRN generation; guard training LMS with video; ONDC/marketplace listing; WhatsApp Business API broadcast; iOS App Store release (Android first, iOS build kept green but not shipped); multi-currency; regional language UI beyond Hindi/English.

### 4.3 Explicit non-goals

Diti365 is not a general HRMS, not a payroll bureau for non-security industries, and not an access-control hardware vendor.

---

## 5. Technology Stack (mandatory — Cursor must use exactly this)

### 5.1 Database
- **Microsoft SQL Server 2019+** (Azure SQL compatible).
- Object model preserved from the existing production schema (see §5.5) — same table and column names so the live data migrates without transformation.
- Access from the API via **raw ADO.NET only** (`Microsoft.Data.SqlClient`), calling **stored procedures exclusively**. No ORM: no EF Core, no Dapper, no LINQ-to-SQL. See `docs/prd/02-api.md` §3 for the mandated data-access pattern.
- Migrations managed with **DbUp** (idempotent, ordered `.sql` scripts) — not EF migrations, because the schema is SP-heavy.

### 5.2 Backend
- **.NET 10 Web API**, C# 14, minimal-API-free (use controllers — mirrors the existing `api/{Controller}/{Action}` routing so the current mobile app keeps working during cutover).
- Layering: `Diti365.Api` → `Diti365.Application` (CQRS via MediatR) → `Diti365.Infrastructure` (ADO.NET repositories / Storage / Push) → `Diti365.Domain`.
- Auth: **JWT access token (15 min) + rotating refresh token (30 days)**, ASP.NET Core Identity-compatible password hashing (PBKDF2, 210 000 iterations) with a one-time migration path from the legacy hash.
- Validation: FluentValidation. Mapping: Mapster. Logging: Serilog → Seq/Application Insights. Health: `/health/live`, `/health/ready`.
- Background jobs: **Hangfire** (SQL Server storage) — nightly turnout snapshot, document-expiry alerts, missed-patrol alerts, payroll pre-compute, push fan-out.
- Files: **Azure Blob Storage** (or S3-compatible MinIO for on-prem) with time-limited SAS URLs. No file bytes through the API after upload.
- Realtime: **SignalR** hub for live map, attendance approvals and chat (replaces Firebase Realtime DB).
- Push: **Firebase Cloud Messaging** (retained — the current app already carries FCM).
- API docs: **Swagger/OpenAPI 3.1**, plus a generated TypeScript client consumed by web and mobile.

### 5.3 Web
- **Next.js 15 (App Router) + TypeScript (strict)**.
- UI: **Tailwind CSS v4 + shadcn/ui + Radix primitives**, `lucide-react` icons.
- Data: **TanStack Query v5** (server state) + **Zustand** (UI state). Forms: **react-hook-form + Zod**.
- Tables: **TanStack Table v8**, server-side pagination/sort/filter, column visibility, CSV/XLSX export.
- Charts: **Recharts**. Maps: **Google Maps JS API** (the app already ships a Maps API key) with marker clustering.
- PDF: server-side **QuestPDF** for salary slips, invoices, attendance registers, gate passes, ID cards. **No `.aspx` WebView pages anywhere.**
- i18n: `next-intl`, English + Hindi.
- Auth on web: httpOnly secure cookies holding the refresh token; access token in memory.

### 5.4 Mobile — **React Native (Expo SDK 51+), recommended**

**Why React Native over Flutter or native Kotlin for this product:**
- The web app is TypeScript/React — API client, Zod schemas, permission matrix, formatters and business constants are shared verbatim between web and mobile via a `packages/shared` workspace. With Flutter or Kotlin you maintain that logic twice.
- Every hardware need is first-class in Expo: `expo-camera` (selfie + gate-pass photo), `expo-barcode-scanner` (QR patrol), `expo-location` with `expo-task-manager` (background GPS, the `GoogleService` foreground-service equivalent), `expo-notifications` (FCM), `expo-file-system` + `expo-sqlite` (offline outbox), `expo-secure-store` (token + device binding).
- **EAS Update** ships JS-only fixes to guards' phones without a Play Store review — critical for a field workforce on 900 devices.
- Same codebase produces the iOS build when you want it, at near-zero extra cost.

**Mandated mobile libraries:** Expo Router (file-based nav), TanStack Query with `persistQueryClient` + AsyncStorage, `react-native-mmkv` for fast local KV, `expo-sqlite` for the offline outbox and cached masters, `react-native-maps`, `nativewind` (Tailwind for RN, so web and app share the token scale), `react-hook-form + Zod`, `sentry-expo`.

> If the team later has a hard requirement for very aggressive OEM-resistant background tracking (Xiaomi/Oppo battery killers), add a small native Kotlin foreground-service module via Expo Config Plugin — do not switch the whole app.

### 5.5 Infrastructure
- Monorepo: **pnpm workspaces + Turborepo** (`apps/web`, `apps/mobile`, `packages/shared`, `packages/ui`) and a sibling **.NET solution** (`api/`).
- Hosting: API on Azure App Service (Linux) or Windows VM behind Nginx; DB on Azure SQL / SQL Server VM; web on Vercel or the same host via Node adapter; blobs on Azure Storage.
- **HTTPS everywhere. `usesCleartextTraffic` must be `false` in the new app.** HSTS, TLS 1.2+.
- CI/CD: GitHub Actions — build/test/lint, DbUp migration gate, EAS build for mobile.
- Environments: `dev`, `staging`, `prod`, each with its own DB and blob container.

---

## 6. Architecture

### 6.1 Logical view

```
┌─────────────┐   ┌──────────────┐   ┌────────────────┐
│  Next.js    │   │ React Native │   │ Client Portal  │
│  Console    │   │ Expo App     │   │ (same Next.js) │
└──────┬──────┘   └──────┬───────┘   └───────┬────────┘
       │  HTTPS/JSON     │  HTTPS/JSON       │
       └─────────────────┴───────────────────┘
                         │
              ┌──────────▼───────────┐
              │  .NET 10 Web API      │
              │  (controllers/CQRS)  │◄── SignalR hub (live map, chat, approvals)
              └──────────┬───────────┘
        ┌────────────────┼────────────────┬──────────────┐
        │                │                │              │
┌───────▼──────┐ ┌───────▼──────┐ ┌───────▼─────┐ ┌──────▼──────┐
│ SQL Server   │ │ Blob Storage │ │  Hangfire   │ │  FCM Push   │
│ (tables+SPs) │ │ (docs/photos)│ │  (jobs)     │ │             │
└──────────────┘ └──────────────┘ └─────────────┘ └─────────────┘
```

### 6.2 Multi-tenancy

- **Row-level, shared database, shared schema**, discriminated by `CompanyID` on every tenant-owned table.
- `CompanyID` and `BranchID` are **never accepted from the client**. They are read from JWT claims (`company_id`, `branch_ids`, `role`, `emp_id`, `user_id`) and injected server-side into every query and SP call.
- A mandatory `TenantGuard` action filter rejects any request whose route/body attempts to set a tenant identifier.
- All read SPs take `@CompanyID` as the first parameter and every query plan is covered by an index leading with `CompanyID`.
- SUPER_ADMIN may impersonate a tenant; impersonation writes an `Audit.ImpersonationLog` row and stamps the JWT with `act_as`.

### 6.3 Cutover strategy (legacy app keeps working)

1. The new API exposes **v1 compatibility routes** at `api/Users/*`, `api/Operation/*`, `api/Tasks/*`, `api/Sales/*`, `api/Report/*` returning the legacy envelope `{ Success, Status, Id, Message, Data[] }` — so `Diti365.apk` v4.8 in the field continues to function unchanged, except over HTTPS.
2. New surfaces (web + new mobile) consume **v2 routes** at `api/v2/{resource}` with a clean REST envelope.
3. Once mobile v5 adoption exceeds 95 %, v1 routes are sunset behind a feature flag.

### 6.4 Standard response envelopes

**v1 (legacy compatibility — do not change):**
```json
{ "Success": true, "Status": 200, "Id": 0, "Message": "OK", "Data": [ { } ] }
```

**v2 (new):**
```json
{ "data": {}, "meta": { "page": 1, "pageSize": 50, "total": 1234 }, "error": null }
```
Errors: RFC 7807 `application/problem+json` with `traceId` and a machine `code` (see `docs/02-api.md` §9).

---

## 7. Phased Delivery

| Phase | Deliverable | Duration | Exit criteria |
|---|---|---|---|
| **P0** | Repo scaffold, CI, environments, design tokens | 1 week | `pnpm build` and `dotnet build` green in CI; staging reachable |
| **P1** | **Database** — full DDL, SPs, functions, views, triggers, seed | 2 weeks | `dbup` runs clean on an empty DB; seed produces a browsable demo tenant; every SP has a smoke test |
| **P1.5** | **API** — all v1 compat + v2 endpoints, auth, files, jobs | 4 weeks | 100 % endpoint parity with `docs/02-api.md`; Swagger published; legacy APK v4.8 works against new API |
| **P2** | **Web** — 16 modules, 8 role dashboards, reports & PDFs | 8 weeks | Every screen in `docs/03-web.md` implemented; Lighthouse ≥ 90; RBAC matrix tests pass |
| **P3** | **Mobile** — Expo app, offline attendance & patrol | 6 weeks | All flows in `docs/04-mobile.md`; offline punch verified in airplane mode; Play Store internal track |
| **P4** | Migration, UAT, cutover, training | 3 weeks | Legacy data migrated with reconciliation report; 2 pilot agencies live |

---

## 8. Success Metrics

| Metric | Baseline (as-is) | Target v1.0 |
|---|---|---|
| Attendance punches lost to connectivity | ~4 % | < 0.1 % (offline outbox) |
| Time to close monthly payroll | 5 days | < 4 hours |
| Time to generate client invoices | 2 days | < 30 minutes |
| Supervisor attendance approval lag | 18 h avg | < 4 h avg |
| Patrol rounds with photo evidence | not enforced | > 95 % |
| Vacant post detected before shift start | manual | 100 % auto-flagged by T-60 min |
| API p95 latency | unmeasured | < 400 ms |
| Crash-free sessions (mobile) | unmeasured | > 99.5 % |

---

## 9. Assumptions, Risks & Open Questions

### 9.1 Assumptions
- The existing SQL Server database is available for schema extraction and data migration; `docs/01-database.md` reconstructs it from the API/model evidence and **must be reconciled column-by-column against the live DB before P1 sign-off**.
- Google Maps API key, Firebase project and an SMS/OTP gateway (or Firebase Phone Auth) are provided by the client.
- Statutory rates (PF 12 %, ESIC 0.75 %/3.25 %, PT and LWF slabs, state minimum wages) are supplied as configurable master data, not hard-coded.

### 9.2 Risks
| Risk | Impact | Mitigation |
|---|---|---|
| Legacy schema drift vs. this reconstruction | High | Run a schema-diff script against production in week 1 of P1; treat `docs/01-database.md` as a proposal until reconciled |
| Business rules buried in `.aspx` pages and existing SPs | High | Extract and document every SP body during P1; port print pages to QuestPDF with side-by-side output comparison |
| OEM battery optimisation killing background GPS | Medium | Foreground service + user-facing "tracking is on" notification + per-OEM whitelisting guide in-app |
| 900 guards on low-end Android with poor data | Medium | Offline-first, aggressive payload trimming, image compression to ≤ 200 KB before upload |
| Payroll correctness (statutory) | High | Golden-file tests: reproduce 3 historical months of real payroll to the rupee before go-live |
| Tenant data leakage | Critical | Server-side tenant injection + automated RBAC/tenant test suite on every PR |

### 9.3 Open questions for the client
1. Is `jpsonline.in` a separate tenant/white-label, or the same product under another brand?
2. Which statutory returns must the system file/export (Form 11, PF ECR, ESIC MC, Form-16)? `Isform11pf` and `Isformfullfinal` fields exist in the employee model.
3. Is there an existing GST/Tally integration for invoicing?
4. Should the client portal be a subdomain per agency (`acme.diti365.com`) or a shared login?
5. Retention policy for patrol photos and punch selfies (storage cost driver)?
