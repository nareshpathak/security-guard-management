# Diti365 — RBAC Matrix, Security, NFRs, Acceptance & Roadmap

---

## 1. Permission Model

Permission code format: `M{module}.{Entity}.{Action}`
Actions: `View` · `Create` · `Edit` · `Delete` · `Approve` · `Export` · `ViewAll` (cross-branch) · `ViewSensitive` (unmasked Aadhaar/PAN/bank/salary)

Permissions are stored in `sec.Permission`, granted per role in `sec.RolePermission`, returned by `GET /me/permissions`, cached client-side, and **re-checked server-side on every request**. Client-side checks are UX only and are never trusted.

### 1.1 Role × Module matrix
Legend: **F** full · **E** edit own scope · **A** approve · **V** view · **O** own records only · **–** no access

| Module | SUPER_ADMIN | COMPANY_ADMIN | BRANCH_ADMIN | OPERATIONS | HR | ACCOUNTS | SUPERVISOR | GATEKEEPER | NIGHT_PATROL | SALES | EMPLOYEE | CLIENT |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M1 Auth/Profile | F | F | F | E | E | E | E | E | E | E | O | O |
| M2 Tenant admin | F | – | – | – | – | – | – | – | – | – | – | – |
| M3 Masters | F | F | V | V | E | V | V | – | – | V | – | – |
| M4 Clients & Units | V | F | E | E | V | V | V (own units) | – | – | E | – | O |
| M5 Recruitment | – | F | E | V | F | – | V | – | – | – | – | – |
| M6 Employee 360 | – | F | E | V | F | V (pay only) | V (own units) | – | – | – | O | V (name/photo/desig only) |
| M7 Deployment | – | F | E+A | F+A | V | – | E (own units) | – | – | – | O | V |
| M8 Attendance | – | F+A | E+A | E+A | V | V | A (own units) | – | – | – | O (punch) | V (own units) |
| M9 QR Patrol | – | F | E | F | – | – | E (own units) | – | Scan+View own | – | – | V (own units) |
| M10 Tracking | – | F | V | F | – | – | V (own team) | – | ping only | ping only | ping only | – |
| M11 Tasks | – | F | E | E | E | E | E | O | O | E | O | – |
| M12 Incidents/Complaints | – | F | E+A | F+A | V | – | E (own units) | – | E | – | O (raise) | O (raise+track) |
| M13 Sales/CRM | – | F | E | V | – | V | – | – | – | F (own) | – | – |
| M14 Uniform/Inventory | – | F | E | E | V | E | V | – | – | – | O (ledger) | – |
| M15 Payroll & Billing | – | F | V | – | – | F | – | – | – | – | O (own slip) | V (own invoices) |
| M16 HR lifecycle/Gate pass/Training | – | F | E+A | E | F+A | V | E | F (gate pass) | – | – | O (requests) | V (gate pass of own units) |
| Reports | Platform only | F | Branch scope | Ops set | HR set | Finance set | Own units | Own gate pass | Own scans | Own sales | Own | Own units |
| Settings/Audit | F | F | V | – | – | – | – | – | – | – | – | – |

### 1.2 Data-scope rules (enforced in SQL, not in C#)
Every report and list SP joins `dbo.fnUserAccessibleUnits(@CompanyID, @UserID)` and `dbo.fnUserAccessibleBranches(...)`:
- `COMPANY_ADMIN` → all branches, all units of the tenant.
- `BRANCH_ADMIN` → units of their `sec.UserBranch` rows.
- `SUPERVISOR` → units where they are the assigned supervisor (`crm.Unit.SupervisorEmpID` or `ops.Deployment`).
- `CLIENT` → units of their `ClientID` only.
- `EMPLOYEE` → their own `EmpID` rows only.
- `SUPER_ADMIN` → no tenant data unless impersonating, and impersonation is logged.

### 1.3 Field-level sensitivity
Masked by default unless `ViewSensitive`: Aadhaar (`XXXX XXXX 1234`), PAN (`ABCXX1234X`), bank account (`XXXXXX7890`), salary amounts, mobile numbers on the client portal. Unmasking is logged to `aud.AuditLog` with the field name.

---

## 2. Security Requirements

| # | Requirement |
|---|---|
| S1 | HTTPS/TLS 1.2+ only. `usesCleartextTraffic=false`. HSTS with preload. Certificate pinning in the mobile app. |
| S2 | Passwords: PBKDF2-SHA256, 210 000 iterations, 128-bit salt. Minimum 8 chars with complexity. Legacy hashes migrated on first successful login. |
| S3 | JWT 15 min + rotating refresh 30 days, refresh reuse detection revokes the whole family. |
| S4 | Account lockout after 5 failures for 15 min; alert on 3 lockouts in 24 h. |
| S5 | Tenant isolation enforced server-side; automated test proves cross-tenant reads are impossible on every endpoint. |
| S6 | All input validated with FluentValidation/Zod; **stored procedures with `SqlParameter` only** — zero string-concatenated SQL, zero inline SQL text in C#. |
| S7 | Files: private containers, short-lived SAS, MIME allow-list, size caps, async malware scan, no executable types. |
| S8 | Audit trail on all people, attendance and financial mutations with old/new JSON, actor, IP and timestamp. Audit rows are append-only. |
| S9 | PII: Aadhaar/PAN/bank encrypted at rest with SQL Server Always Encrypted or column-level AES; keys in Key Vault. |
| S10 | DPDP Act 2023 alignment: consent capture at recruitment, purpose limitation, data-subject export and erasure workflows, breach-notification runbook. |
| S11 | Rate limiting and bot protection on auth endpoints; OTP throttling. |
| S12 | No secrets in source; `.env` templates only; secret scanning in CI. |
| S13 | Dependency scanning (Dependabot + `dotnet list package --vulnerable`) gates the build. |
| S14 | Annual VAPT; OWASP ASVS L2 as the target. |
| S15 | Backups: full nightly + 15-min log shipping, 35-day PITR, quarterly restore drill. |
| S16 | Screenshot blocking on salary and statutory screens; clipboard restricted for masked fields. |

---

## 3. Non-Functional Requirements

| Area | Requirement |
|---|---|
| Availability | 99.5 % monthly; planned maintenance windows announced in-app |
| API latency | p95 < 400 ms, p99 < 900 ms (list endpoints, 50 rows) |
| Web performance | FCP < 1.5 s on 4G; Lighthouse ≥ 90 |
| Mobile | Cold start < 2.5 s on 2 GB RAM; APK ≤ 40 MB; crash-free > 99.5 % |
| Scale targets (year 1) | 200 tenants · 100 000 employees · 300 000 attendance rows/day · 500 000 location pings/day · 100 000 QR scans/day |
| Concurrency | 500 simultaneous punches at shift change (06:00, 08:00, 20:00 peaks) |
| Data volume | `ops.LocationLog` partitioned monthly; `ops.Attendance` archived after 8 years |
| Localisation | English + Hindi; IST default, tenant-configurable timezone; ₹ INR formatting |
| Browser support | Last 2 versions of Chrome, Edge, Safari, Firefox |
| Android support | Android 8.0 (API 26)+ |
| Accessibility | WCAG 2.1 AA (web), TalkBack-usable (mobile) |
| Observability | Structured logs, distributed traces, RED metrics, uptime checks, alerting to Slack/email |
| DR | RPO 15 min, RTO 4 h |

---

## 4. Acceptance Criteria (sample, Given/When/Then)

**AC-1 Offline punch**
*Given* a guard is deployed at Unit A and the device has no connectivity,
*when* he punches in inside the geofence with a selfie,
*then* the punch is stored locally with a Queued badge, and on reconnect it syncs exactly once and appears in the supervisor's approval queue with the original punch timestamp (not the sync time).

**AC-2 Geofence rejection**
*Given* the tenant geofence radius for Unit A is 150 m,
*when* a guard attempts to punch from 412 m away,
*then* the punch is rejected with `GEOFENCE_VIOLATION`, the distance is shown, and an "request exception" path is offered which creates a supervisor approval item.

**AC-3 Tenant isolation**
*Given* a valid Company-2 access token,
*when* any endpoint is called with any Company-1 record id,
*then* the response is 404 or 403 and no Company-1 data is returned, for **every** endpoint.

**AC-4 Payroll correctness**
*Given* the seeded demo tenant with 40 employees and a full month of approved attendance,
*when* `usp_Payroll_Generate` runs,
*then* every slip's `NetPayble` equals `TotalEarnings − DeductionAmt` to the paisa, PF/ESIC respect their ceilings, and re-running produces byte-identical results.

**AC-5 Vacant post alert**
*Given* Unit A's day shift requires 6 guards and only 4 are deployed,
*when* the clock reaches 60 minutes before shift start,
*then* the Operations user receives a push notification and the turnout board shows Unit A in red with a "Fill" action.

**AC-6 Patrol proof**
*Given* a night round with 8 checkpoints and a 30-minute window,
*when* only 6 are scanned within the window,
*then* the round is marked missed, the supervisor is notified, and the client portal shows 6/8 with the scanned photos and times.

**AC-7 Document expiry**
*Given* a guard's police verification expires in 30 days,
*when* the nightly job runs,
*then* HR sees the document in the "expiring ≤30 d" dashboard card and receives a notification; the guard's profile shows an amber chip.

**AC-8 Legacy app compatibility**
*Given* `Diti365.apk` v4.8 pointed at the new API over HTTPS,
*when* a user logs in, punches attendance, scans a QR checkpoint and views a salary slip,
*then* all four flows succeed with the legacy `{Success, Status, Id, Message, Data}` envelope unchanged.

**AC-9 Client portal privacy**
*Given* a CLIENT user,
*when* they open a deployed guard's record,
*then* they see only name, photo, designation, shift and today's status — never Aadhaar, PAN, bank, salary, address or family data.

**AC-10 Audit**
*Given* an accountant edits a draft salary row,
*when* the change is saved,
*then* `aud.AuditLog` contains the old and new JSON, the user id, IP and timestamp, and the row is visible in `/settings/audit` with a diff view.

---

## 5. Migration Plan (Phase 4)

1. **Schema diff** — run a comparison of `docs/01-database.md` against the live production DB; produce a reconciliation sheet; production wins every conflict.
2. **Extract** — full BCP export of the legacy DB to a staging instance.
3. **Map & transform** — mapping scripts per table into the new schema; normalise the employee mega-table into its satellites; de-duplicate employees by Aadhaar/mobile/EmpCode; normalise phone numbers and dates.
4. **Load** — staged loads with FK validation off, then on; row counts and checksums compared per table.
5. **Reconcile** — automated report: source vs target counts, sum of `NetPayble` for the last 12 payrolls, attendance day counts per employee for the last 3 months, outstanding invoice totals. Zero variance required.
6. **File migration** — copy documents/photos from the legacy file store to blob storage, rewrite URLs.
7. **Password migration** — legacy hashes carried into `LegacyPasswordHash`; users transparently upgraded on first login.
8. **Parallel run** — 2 weeks with both systems live; daily reconciliation of attendance and turnout.
9. **Cutover** — freeze legacy writes, final delta load, DNS/API switch, legacy app pointed at the new API, monitoring heightened for 72 h.
10. **Rollback plan** — documented, tested, with a 4-hour RTO.

---

## 6. Roadmap & Milestones

| Week | Milestone | Owner | Exit gate |
|---|---|---|---|
| 1 | P0 scaffold, CI/CD, environments, design tokens | Full team | builds green, staging up |
| 2–3 | **P1 Database**: DDL, functions, views, SPs, triggers, seed | Backend/DBA | DbUp clean twice, seed browsable, tSQLt smoke tests pass |
| 4–7 | **P1.5 API**: v1 compat + v2, auth, files, jobs, SignalR | Backend | 120 v1 endpoints replayed OK, Swagger published, isolation suite green |
| 5–12 | **P2 Web**: shell + design system → dashboards → ops → people → clients → finance → reports → settings | Frontend | every route done, RBAC E2E green, Lighthouse ≥ 90 |
| 11–16 | **P3 Mobile**: shell + auth → punch/patrol (offline) → supervisor → sales/gate/client → polish | Mobile | airplane-mode suite green, EAS internal build |
| 17–19 | **P4 Migration, UAT, training, cutover** | All | zero-variance reconciliation, 2 pilot agencies live |
| 20 | Hypercare | All | < 5 P2 defects open, 0 P1 |

**Suggested team:** 1 tech lead, 2 backend (.NET), 2 frontend (Next.js), 1 mobile (RN), 1 DBA (part-time), 1 QA, 1 designer (first 8 weeks), 1 BA/PM.

---

## 7. Post-v1 Backlog
Face-recognition attendance · biometric device integration (eSSL/ZKTeco) · GST e-invoicing IRN · WhatsApp Business notifications · guard training LMS with quizzes · client self-service contract renewal · panic/SOS button with escalation tree · shift auto-rostering optimiser · payroll direct-to-bank API · Tally/Zoho Books sync · iOS release · offline-first client portal PWA · anomaly detection on punch patterns · multilingual (Marathi, Tamil, Bengali).
