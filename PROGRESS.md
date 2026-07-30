# Diti365 — Build Progress

> Har Cursor chat ke shuru me ye file attach karein (`@PROGRESS.md`) taaki naye chat ko
> pata ho kahan tak kaam ho chuka hai. Har kaam ke baad update karein.

**Current phase:** P1.5 — API (host + core V1/V2 surfaces buildable; jobs/SignalR/tests remain)
**Last updated:** 2026-07-28
**Blocked on:** nothing for core CRUD/API wiring; Hangfire/SignalR/Blob/tests still open

### Pending installs
- [x] **.NET 10 SDK** installed

---

## P0 — Scaffold
- [ ] Monorepo (pnpm + Turborepo): `apps/web`, `apps/mobile`, `packages/shared`, `packages/ui`
- [x] `.NET` solution under `api/`
- [x] `.cursor/rules/` installed
- [ ] CI (GitHub Actions): build + lint + test
- [ ] dev / staging environments reachable

## P1 — Database
- [x] ~~Production schema dump~~ — no DB access; reconstructed schema is authoritative (DECISIONS #7)
- [x] SQL Server 2022 Developer Edition running locally (`localhost`, Windows auth) — see `db/README.md`
- [x] `Diti365_Dev` database created
- [ ] `db/DbUp` runner (unblocked now that .NET 10 is installed; `db/run-all.ps1` works meanwhile)
- [x] 001 schemas · 010 masters (27) · 020 tenant+auth (13) · 030 people (17) · 040 client/unit (9)  = **66 tables**
- [x] 150_foreign_keys.sql (deferred cross-schema FKs)
- [x] 050 deployment (6) · 060 attendance (2 + TVP) · 070 patrol/location (5 + TVP) · 080 tasks (3) · 090 incident/complaint (6)  = **22 tables**, running total **88**
- [x] 100 sales (empty, see DECISIONS #13) · 110 inventory (3) · 120 payroll/billing (7) · 130 comms/docs (5) · 140 audit (3)  = **18 tables**, grand total **106**
- [x] 200 indexes (52 covering indexes)
- [x] 145 counter table (gapless emp-code / invoice-no numbering)
- [x] 300 functions — 15 functions + 2 code-generator procedures (see DECISIONS #14)
- [x] 400 views (12)
- [ ] 500-560 stored procedures
  - [x] 510 users/auth/masters (26 procs)
  - [x] 520 attendance (13 procs + 1 fn)
  - [x] 521 deployment (14 procs)
  - [x] 522 patrol/location (14 procs)
  - [x] 523 people/client/unit (20 procs)
  - [x] 524 incident/complaint (13) · 525 inventory/HR (15)
  - [x] 530 tasks (7) · 540 sales (7) · 550 report (8) · 560 payroll (11)
- [x] 600 triggers (12)
- [x] 700 seed reference · 711 demo tenant (supersedes 710, see DECISIONS #27) · 720 demo transactions
- [x] tSQLt-style smoke tests + tenant-isolation checks (db/tests/run-tests.ps1) — lightweight sqlcmd smoke checks added
- [ ] **DoD checklist in `01-database.md` §10 signed off**

## P1.5 — API
- [x] Solution scaffold + DI + Serilog + Swagger (`Program.cs`, `DependencyInjection.cs`)
- [x] Auth: JWT, refresh rotation, TenantGuardFilter, HasPermission, legacy hash migration (OTP SMS seam TODO)
- [x] V1 UsersController · OperationController · TasksController · SalesController · ReportController (legacy envelope; APK replay harness still TODO)
- [x] V2 resources for auth, me, masters, attendance, ops/patrol/tracking, people/recruits/clients/units, sales, finance/payroll/invoices, workflow (tasks/incidents/complaints/gate/hr/uniform/docs), reports
- [ ] Blob upload (SAS) · SignalR hubs · Hangfire jobs
- [ ] Integration tests (Testcontainers) · tenant-isolation suite · RBAC suite
- [ ] **DoD in `02-api.md` §10**
- [x] Audit docs: `BACKEND_COMPLETION_AUDIT.md`, `DATABASE_BACKEND_MATRIX.md`

## P2 — Web
- [ ] `packages/ui` design system + Storybook
- [ ] AppShell, auth screens, role router
- [ ] Dashboards (8) · Operations · People · Clients · Sales · Inventory · Finance · Tasks · Reports · Settings
- [ ] Client portal
- [ ] PDFs (QuestPDF)
- [ ] Playwright RBAC E2E
- [ ] **DoD in `03-web.md` §7**

## P3 — Mobile
- [ ] Expo scaffold + auth + role router
- [ ] Offline outbox + Sync Centre
- [ ] Punch flow · QR patrol · gate pass · supervisor approvals · sales · client
- [ ] Background GPS + OEM guide
- [ ] Airplane-mode test suite
- [ ] **DoD in `04-mobile.md` §8**

## P4 — Migration & cutover
- [ ] Schema diff · extract · transform · load · reconcile (zero variance)
- [ ] File + password migration
- [ ] Parallel run 2 weeks
- [ ] Cutover + hypercare
