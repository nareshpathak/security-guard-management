# Diti365 — Phase 2: Web Application Specification
**Next.js 15 (App Router) · TypeScript strict · Tailwind v4 · shadcn/ui · TanStack Query/Table · Recharts · Google Maps**

Target quality bar: **premium B2B SaaS** — think Linear's density and speed with Stripe-grade forms and Vercel-grade polish. Not a CRUD admin template.

---

## 1. Design System

### 1.1 Tokens
```
Brand primary   #0B5FFF  (Diti Blue)     hover #0A54E0   subtle bg #EFF5FF
Brand accent    #00C2A8  (Guard Teal)
Neutrals        zinc scale (50 → 950)
Success #16A34A · Warning #F59E0B · Danger #DC2626 · Info #0EA5E9
Status colours: Present #16A34A · Absent #DC2626 · Half-day #F59E0B · Leave #8B5CF6 · Week-off #64748B · Holiday #0EA5E9 · Pending #F59E0B
Radius  sm 6 · md 8 · lg 12 · xl 16 · full 9999
Shadow  xs/sm/md/lg — soft, low-opacity, never harsh
Spacing 4-point scale
Font    Inter (UI) · JetBrains Mono (codes, IDs, amounts in tables)
Type    display 30/36 semibold · h1 24/32 · h2 20/28 · h3 16/24 · body 14/20 · small 13/18 · caption 12/16
```
Dark mode is a first-class requirement (`class` strategy, all tokens defined for both themes).

### 1.2 Core components (build once in `packages/ui`)
`AppShell` (collapsible sidebar + topbar + breadcrumb + command palette), `DataTable` (server pagination, multi-sort, column visibility, sticky header, row selection, bulk actions, saved views, CSV/XLSX export, empty/loading/error states), `StatCard` (value, delta, sparkline, click-through), `FilterBar` (date-range preset + branch + unit + designation + status, persisted to URL query), `FormLayout` (sectioned, sticky save bar, dirty-state guard), `EntityDrawer` (side-sheet detail without losing list context), `Timeline`, `StatusPill`, `AvatarWithStatus`, `MapPanel`, `PhotoLightbox`, `SignaturePad`, `DateRangePicker` (with FY/月 presets), `ApprovalQueue`, `AuditTrailPanel`, `PdfPreview`, `ConfirmDialog`, `Toast`, `CommandPalette` (⌘K — jump to employee, unit, task, invoice).

### 1.3 Interaction rules
- Every list is **URL-driven** (filters/page/sort in the query string) so views are shareable and back-button-safe.
- Optimistic updates for approvals, task status and read flags; rollback with a toast on failure.
- Skeletons, never spinners, for first paint. Inline row shimmer on refetch.
- Keyboard: `⌘K` palette, `/` focus search, `j/k` row nav, `Enter` open, `a` approve in queues.
- Every destructive action needs typed confirmation for financial/people records.
- Empty states always offer the primary action ("No units yet — Add your first unit").
- Toasts announce, drawers explain, dialogs interrupt. Never nest dialogs.

### 1.4 Responsiveness & a11y
Breakpoints 640/768/1024/1280/1536. Tables collapse to card lists below `md`. Sidebar becomes a sheet below `lg`.
WCAG 2.1 AA: 4.5:1 contrast, visible focus rings, full keyboard operability, `aria-live` on async regions, labels on every input, no colour-only status encoding (pill + icon + text).

---

## 2. Information Architecture

```
/login  /forgot-password  /reset-password  /verify-otp
/(app)
  /dashboard                          role-aware
  /operations
     /turnout                         live board
     /deployment                      assignments, incdec, movement, relievers
     /attendance                      register, approvals, summary
     /patrol                          checkpoints, logs, rounds, missed
     /tracking                        live map, trails, summary
     /gate-pass
     /incidents
     /field-reports
  /people
     /recruits                        pipeline
     /employees                       list + 360 profile
     /documents                       vault + expiry
     /training
     /lifecycle                       resign / exit / rejoin
     /requests                        leave, advance, transfer
  /clients
     /clients  /units  /contracts  /complaints  /client-relations
  /sales
     /visits  /follow-ups  /pipeline
  /inventory
     /items  /stock  /issues  /ledger
  /finance
     /payroll  /salary-slips  /advances  /invoices  /receipts  /ageing
  /tasks
     /assigned-to-me  /assigned-by-me  /all  /[id]
  /reports                            20 report keys, one shell
  /chat
  /settings
     /company  /branches  /users  /roles  /masters  /rules  /integrations  /audit
/(platform)                           SUPER_ADMIN only
  /tenants  /tenants/[id]  /plans  /platform-analytics  /impersonate
```

---

## 3. Role Dashboards

Each dashboard is a single API call (`GET /api/v2/dashboard/{role}`) rendering a widget grid. Every number is clickable and deep-links to a pre-filtered list.

### 3.1 COMPANY_ADMIN / BRANCH_ADMIN
Row 1 StatCards: **Guards on duty now** (present/required with % ring) · **Vacant posts today** · **Pending attendance approvals** · **Open complaints (SLA-breached in red)** · **Documents expiring ≤30 d** · **Invoice outstanding ₹**
Row 2: *Turnout by unit* horizontal bar (required vs present, red where short) · *Attendance trend* 30-day line
Row 3: *Live map* of field staff (clustered) · *Patrol compliance* donut (scanned/missed today)
Row 4: *Recent incidents* table · *Approval queue* (attendance, recruits, advances, requests — unified) · *Tasks overdue*
Row 5: *Recruitment funnel* · *Sales pipeline* · *Payroll status* for the current month

### 3.2 SUPER_ADMIN (platform)
Tenants total/active/expiring-in-30d · MRR · logins today · API error rate · top tenants by users · signup trend · tenants over user limit · impersonation log.

### 3.3 OPERATIONS
Vacant posts (T-60 alert list) · today's turnout by unit · reliever requests · movement register · missed patrol rounds · open incidents · unit-wise strength vs contract.

### 3.4 HR
Recruit pipeline by stage · pending police verifications · expiring medicals/PV/gun licences · new joins & exits this month · training due · birthdays/anniversaries · headcount by designation.

### 3.5 ACCOUNTS
Payroll run status · net payable ₹ · advances outstanding · uniform recovery pending · invoices draft/sent/overdue · ageing buckets · collection trend · statutory dues (PF/ESIC/PT/LWF) for the month.

### 3.6 SUPERVISOR (web view; primary is mobile)
My units · today's attendance approval queue · my open tasks · incidents I raised · patrol status of my units · guards absent today with contact numbers.

### 3.7 SALES
Visits this week · follow-ups due today (red if overdue) · conversion funnel · new contracts value · my clients · next-follow-up calendar.

### 3.8 CLIENT
Guards deployed today (photo grid with on-duty status) · attendance % this month · patrol rounds completed vs expected · my complaints (open/closed) · invoices & outstanding · download attendance register / invoice PDF.

---

## 4. Screen Specifications

> Format per screen: **route · purpose · layout · columns/fields · actions · validation · permissions · empty state**

### 4.1 Auth

**`/login`** — Split screen: left brand panel with product screenshot, right form. Fields: Mobile/Username, Password, Remember me. Actions: Sign in, Forgot password, "Login with OTP". On `LICENCE_EXPIRED` show a full-page renewal notice with the agency's contact. On `AUTH_DEVICE_NOT_REGISTERED` show a "request device change" flow that raises an admin approval.

**`/verify-otp`** — 6-box OTP input, 60-second resend timer, auto-submit on paste.

### 4.2 Operations

#### `/operations/turnout` — **Live Turnout Board** (the flagship screen)
Layout: sticky FilterBar (date, branch, client, unit, shift) → 4 StatCards (Required, Present, Absent, Vacant) → a **unit grid**: one card per unit showing required/present as a progress ring, colour red when short, with a "Fill" button opening the reliever picker. Toggle to table view.
Table columns: Unit · Client · Shift · Required · Deployed · Present · Absent · Reliever · Vacant · Last punch · Actions.
Actions: Assign reliever, Mark bulk attendance, Notify supervisor, Export.
Auto-refresh every 60 s via SignalR; new vacancies flash amber.

#### `/operations/deployment`
Tabs: **Current** · **Increase/Decrease** · **Movement** · **Relievers** · **Temporary events**.
Current tab: DataTable — Employee (avatar, code) · Designation · Unit · Post · Shift · From date · Reliever? · Status. Bulk select → Move / End / Change shift.
Add deployment drawer: Employee (async search by code/name/mobile) → Unit → Post (filtered by unit, shows required vs filled) → Shift → From date → Reliever-for (optional).
Validation: employee cannot be deployed to two units on the same date/shift; post cannot exceed `RequiredStrength` without an override reason.
IncDec form: Unit, Change type, Date, Timing, No. of persons, Remark → creates an approval item.
Movement form: Employee, From unit, To unit, Post name, Date, Time, Instruction by, Remark.

#### `/operations/attendance`
Tabs: **Register** · **Approvals** · **Summary** · **Exceptions**.

*Register* — month × employee matrix. Rows = employees of the selected unit; columns = days 1..31 with colour-coded status cells; click a cell → drawer with punch times, both selfies, GPS distance, map pin, device, edit history. Footer totals per employee (P/A/HD/LV/WO/HO, OT hours). Export → XLSX and the PDF register (replaces `PrintDailAttendance.aspx`).

*Approvals* — the queue: Date · Employee · Unit · Shift · In (time + distance chip) · Out · Hours · Selfie thumbnails · Flags (out-of-geofence, mock GPS, late, missing out-punch). Row actions Approve/Reject (reason required). Bulk approve with a confirmation showing how many are flagged. Keyboard `a`/`r`/`j`/`k`.

*Summary* — per employee monthly totals, drill to register.

*Exceptions* — only flagged rows: out-of-geofence, mock location, duplicate device, missing punch-out, >16 h shift.

#### `/operations/patrol`
Tabs **Checkpoints** · **Scan logs** · **Rounds** · **Missed**.
Checkpoints: table (Name, Unit, Location, Lat/Long, Max distance, Scans today, Active) + "Generate QR" → printable A5 PDF sheet with QR, unit name, checkpoint name, instructions; bulk print all checkpoints of a unit.
Scan logs: Time · Guard · Unit · Checkpoint · Distance · In-range pill · Photo thumbnail · Map link. Filter by unit/date/guard/in-range.
Rounds: define expected checkpoint sequence + window; compliance % per unit/day.
Missed: rounds where scans < expected, with notify action.

#### `/operations/tracking`
Full-bleed Google Map, left rail of online field staff (avatar, role, last-seen, battery). Click a user → their trail for the selected date as a polyline with time-stamped markers, plus a playback scrubber. Unit geofences drawn as circles. Right panel: distance travelled, units visited, idle time. Table view for `trackRpt` export.

#### `/operations/gate-pass`
Entry form: Visitor name, Mobile, Purpose, Whom to meet, Vehicle no., Material details, Photo capture (webcam), Unit. List: Date · Visitor · Mobile · Purpose · Vehicle · In · Out · Photo · Print pass (PDF with QR).

#### `/operations/incidents` and `/operations/field-reports`
Incidents list (Date/Time · Unit · Type · Severity pill · Guard · Reported by · Status) → detail drawer with photos, action taken, timeline, close action.
Field reports: supervisor visit reports with unit, contact person, remark, GPS, photos and a per-guard detail sub-table (name, designation, join date, photo, remark).

### 4.3 People

#### `/people/recruits`
**Kanban pipeline**: New → Screened → Verified → Approved → Waitlist → Rejected → Converted. Drag to move (permission-gated). Card: name, mobile, designation, source, age of card. Right drawer shows the full biodata form progress %, documents checklist, and duplicate warnings (Aadhaar/mobile/old emp code match).
Actions: Approve → converts to employee and allocates `EmpCode`; Reject with reason; Waitlist; Bulk SMS.

#### `/people/employees`
List: photo · EmpCode · Name · Designation · Unit/Client · Mobile · Status pill · PV status · Docs complete % · Joined. Filters: branch, unit, designation, status, gunman, reliever, blacklisted, PV pending, docs incomplete.
Row click → **Employee 360** at `/people/employees/[id]` with left profile rail (photo, code, designation, unit, status, quick actions: Call, WhatsApp, Move, Issue uniform, Mark exit) and tabs:
1. **Overview** — key facts, contract, contact, current deployment, attendance last 30 days sparkline
2. **Personal** — the full biodata form (see §4.3.1)
3. **Address** — permanent + present
4. **Family & Nominee**
5. **Qualification & Ex-service**
6. **Bank** — primary + joint, IFSC lookup, passbook/cheque images
7. **Statutory** — Aadhaar, PAN, UAN/PF, ESIC, Voter, DL with masked display and reveal-on-permission
8. **Verification** — police verification tracker with dates and certificate, medical certificate + doctor block
9. **Gun licence** — for gunmen only
10. **Documents** — vault with expiry chips
11. **Deployment history**
12. **Attendance**
13. **Salary** — structure + slips
14. **Uniform ledger**
15. **Timeline / audit**

##### 4.3.1 The biodata form (the 196-field form, done properly)
Rendered as a **6-step wizard** with autosave-per-step and a completion meter:
Step 1 Personal · Step 2 Contact & Address · Step 3 Family & Qualification · Step 4 Employment & Deployment · Step 5 Bank & Statutory · Step 6 Verification, Medical, Physicals, Uniform sizes, Gun licence.
Inline validation: Aadhaar (12 digits + Verhoeff checksum), PAN regex, IFSC lookup auto-fills bank/branch, mobile 10-digit, DOB ⇒ age 18–60, DOJ ≥ DOB+18y, expiry dates must be future, image fields accept camera or file.
Duplicate check fires on Aadhaar/mobile blur.
"Save & continue later" persists a draft.

#### `/people/documents`
Vault grid grouped by document type with expiry chips (green > 90 d, amber ≤ 30 d, red expired). Bulk upload with type auto-detect by filename. Verify action with verifier name and date. Filter "expiring in 30 days" is the default view when reached from the dashboard card.

#### `/people/training`, `/people/lifecycle`, `/people/requests`
Training: sessions list + attendee marking + report. Lifecycle: resign/exit/rejoin forms with document upload, F&F flag, and a unified status history. Requests: approval queue for leave/advance/transfer/uniform.

### 4.4 Clients

#### `/clients/units/[id]` — **Unit 360**
Header: unit name, client, agreement no. + expiry chip, work order no. + expiry, contracted strength vs deployed.
Tabs: Overview (map + geofence editor) · Posts (required strength & rates) · Guards deployed · Attendance · Patrol checkpoints & compliance · Complaints · Gate passes · Incidents · Invoices · Documents (agreement, work order).
Geofence editor: draggable marker + radius slider on the map, live "guards currently inside" count.

#### `/clients/contracts`
New contract / renewal / termination / temporary event, each with date, NOP, timing, remark, and an approval trail. Expiry watchlist for agreements and work orders.

#### `/clients/complaints`
Board or table by status (Open / Assigned / In-progress / Closed) with SLA countdown chips. Detail drawer: description, unit, raised by, assignment, history timeline, closure remark, attachments, and client-visible flag.

### 4.5 Sales
`/sales/visits` (list + entry form with GPS-stamped location and photo), `/sales/follow-ups` (Due today / Overdue / Upcoming tabs, quick "log outcome" inline, stop-follow toggle), `/sales/pipeline` (funnel Visits → Follow-ups → Contracts with value and conversion %, per executive leaderboard).

### 4.6 Inventory
`/inventory/items` (name, rate, returnable, UOM), `/inventory/stock` (branch × item grid with reorder highlighting), `/inventory/issues` (issue to employee, multi-item, auto-recovery amount → payroll), `/inventory/ledger` (per employee issued vs returned vs outstanding value).

### 4.7 Finance

#### `/finance/payroll`
Wizard: **1 Select** (month, branch, units) → **2 Validate** (blocking list: unapproved attendance, missing bank details, missing salary structure, employees with no punches) → **3 Generate** (progress) → **4 Review** (editable draft table: employee, payable days, earnings breakup, deductions, net; inline edit with reason logged) → **5 Lock & Publish** (locks attendance for the month, pushes slips to the app, generates bank advice, PF ECR and ESIC files).
Review table columns mirror `fin.Salary` exactly. Variance column vs previous month with a red flag beyond ±20 %.

#### `/finance/invoices`
Generate from deployment: select client + month → preview lines (unit, post, man-days, rate, amount) → GST computed by place of supply → save draft → PDF preview → Send (email + client portal). Ageing view with buckets and a "send reminder" bulk action.

#### `/finance/advances`, `/finance/receipts`, `/finance/ageing`
Standard CRUD + approval; receipts allocate against invoices.

### 4.8 Tasks
List with tabs (To me / By me / All), filters (status, priority, unit, assignee, overdue), and a Kanban toggle by status. Detail: description, attachments, checklist, status history timeline, comments, close with remark. Recurring tasks spawn the next instance on close.

### 4.9 Reports
One shell at `/reports` with a report picker. All 20 report keys: Daily Attendance Register · Monthly Attendance Summary · Turnout · Deployment · IncDec · Movement · New Contract · Contract Termination · Resignation · Training · Incident · Field Report · Recruitment · Patrol/QR Summary · Location Track · Gate Pass · Complaint · Sales Visit · Follow-up · Uniform Ledger · Salary Register · Invoice Register · Statutory (PF/ESIC/PT/LWF).
Every report: the same FilterBar, server-paginated table, column chooser, group-by where meaningful, totals row, and export to XLSX / CSV / PDF. Scheduled email delivery (daily/weekly/monthly) configurable per report.

### 4.10 Settings
`/settings/company` (profile, logo, GSTIN, PSARA licence, theme colour), `/settings/branches`, `/settings/users` (invite, role, branch scope, device reset, force logout), `/settings/roles` (permission matrix editor — module × action checkboxes, clone a system role), `/settings/masters` (tabbed editor for every `mst.*` table), `/settings/rules` (geofence radius, selfie mandatory, attendance cut-off, OT policy, patrol grace, SLA hours, auto-absent time, minimum wage mapping), `/settings/integrations` (FCM, SMS gateway, Maps key, email SMTP, WhatsApp), `/settings/audit` (searchable `aud.AuditLog` with before/after diff viewer).

### 4.11 Client Portal
Same Next.js app, `CLIENT` role, restricted nav: Dashboard · My units · Guards on duty (photo grid, live) · Attendance (view + download register) · Patrol logs (with photos as proof) · Complaints (raise + track) · Invoices (view, download, payment status) · Documents. Never sees salary, employee personal data beyond name/photo/designation, or other clients.

---

## 5. PDF Deliverables (QuestPDF, server-side)
Salary slip · Daily attendance register · Monthly attendance summary · Client invoice (GST-compliant) · Gate pass · Employee ID card (front/back with photo, code, blood group, validity) · Biodata/Form-11 print · Patrol/QR checkpoint sheet · Patrol compliance report · Incident report · Field visit report · Deployment order · Appointment letter · Experience/relieving letter · Bank advice.
All branded with the tenant's logo and address. **No `.aspx` page is referenced anywhere in the new web app.**

---

## 6. Web Non-Functionals
- Lighthouse ≥ 90 on Performance/Accessibility/Best-practices/SEO for `/login` and `/dashboard`.
- First Contentful Paint < 1.5 s on a 4G throttle; route-level code splitting; RSC for static shells, client components only where interactive.
- All list data via TanStack Query with `staleTime` 30 s and background refetch; masters cached 24 h with ETag.
- Error boundary per route segment with a "report issue" action carrying the `traceId`.
- i18n English + Hindi; all strings in message catalogues, no hard-coded copy.
- Sentry for errors, PostHog (self-hosted option) for product analytics.

## 7. Definition of Done — Phase 2
- [ ] Every route in §2 exists and is permission-gated per `docs/05-rbac-and-nfr.md`.
- [ ] Every screen in §4 implemented with loading/empty/error states.
- [ ] RBAC E2E suite (Playwright) proves each role sees exactly its allowed nav and is 403'd elsewhere.
- [ ] All 20 reports export correctly in all three formats; PDFs match the legacy `.aspx` output field-for-field.
- [ ] Dark mode audited on every screen. Keyboard-only walkthrough of the top 10 flows passes.
- [ ] No client-side call ever sends `companyId`.
