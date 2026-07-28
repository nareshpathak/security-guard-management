# Diti365 — Build Progress

> Har Cursor chat ke shuru me ye file attach karein (`@PROGRESS.md`) taaki naye chat ko
> pata ho kahan tak kaam ho chuka hai. Har kaam ke baad update karein.

**Current phase:** P1 — Database
**Last updated:** _(date)_
**Blocked on:** production schema dump (see PRD §9.3 / CURSOR-SETUP §5)

---

## P0 — Scaffold
- [ ] Monorepo (pnpm + Turborepo): `apps/web`, `apps/mobile`, `packages/shared`, `packages/ui`
- [ ] `.NET` solution under `api/`
- [ ] `.cursor/rules/` installed
- [ ] CI (GitHub Actions): build + lint + test
- [ ] dev / staging environments reachable

## P1 — Database
- [ ] Production schema dump obtained and reconciled against `01-database.md`
- [ ] `db/DbUp` runner
- [ ] 001 schemas · 010 masters · 020 tenant · 030 people · 040 client/unit
- [ ] 050 deployment · 060 attendance · 070 patrol/location · 080 tasks · 090 incident/complaint
- [ ] 100 sales · 110 inventory · 120 payroll/billing · 130 comms/docs · 140 audit
- [ ] 200 indexes
- [ ] 300 functions (17)
- [ ] 400 views (12)
- [ ] 500–560 stored procedures
- [ ] 600 triggers (6)
- [ ] 700 seed reference · 710 demo tenant · 720 demo transactions
- [ ] tSQLt smoke tests + tenant-isolation test
- [ ] **DoD checklist in `01-database.md` §10 signed off**

## P1.5 — API
- [ ] Solution scaffold + DI + Serilog + Swagger
- [ ] Auth: JWT, refresh rotation, TenantGuardFilter, HasPermission, legacy hash migration
- [ ] V1 UsersController · OperationController · TasksController · SalesController · ReportController
- [ ] V2 resources
- [ ] Blob upload (SAS) · SignalR hubs · Hangfire jobs
- [ ] Integration tests (Testcontainers) · tenant-isolation suite · RBAC suite
- [ ] **DoD in `02-api.md` §10**

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
