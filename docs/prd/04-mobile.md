# Diti365 — Phase 3: Mobile Application Specification
**React Native · Expo SDK 51+ · Expo Router · TypeScript · NativeWind · TanStack Query · expo-sqlite offline outbox**

Package id: `com.diti365.app` (the legacy `com.diti.securityguarding` stays installed until cutover completes).

---

## 1. Why React Native / Expo (decision record)
Shares `packages/shared` (API client, Zod schemas, permission matrix, formatters, business constants) verbatim with the Next.js web app — one definition of truth for validation and permissions. All hardware needs are covered by first-party Expo modules. **EAS Update** ships JS fixes to 900 field devices without a Play Store review cycle, which matters enormously for a guard workforce. iOS comes free when needed.
*Escape hatch:* if OEM battery managers (Xiaomi/Oppo/Vivo) prove too aggressive for background GPS, add a native Kotlin foreground-service module via an Expo config plugin — do not rewrite the app.

## 2. Stack
`expo-router` (file-based nav) · `@tanstack/react-query` + `persistQueryClient` · `react-native-mmkv` (fast KV) · `expo-sqlite` (outbox + cached masters) · `expo-secure-store` (tokens, device binding) · `expo-camera` · `expo-barcode-scanner` · `expo-location` + `expo-task-manager` (background GPS) · `expo-notifications` (FCM) · `expo-image-manipulator` (compress to ≤200 KB) · `expo-file-system` · `react-native-maps` · `react-hook-form` + `zod` · `nativewind` · `react-native-reanimated` · `sentry-expo` · `expo-local-authentication` (biometric app lock).

## 3. Navigation
```
(auth)/  login · otp · forgot-password · reset-password
(app)/
  (tabs)/  index(Home) · attendance · tasks · reports · more
  scan/            QR patrol scanner (modal, full screen)
  punch/           attendance punch flow (camera + GPS)
  employee/[id]
  unit/[id]
  task/[id]
  complaint/[id]
  chat/[threadId]
  gate-pass/new
  incident/new
  field-report/new
  visit/new · follow-up/new
  profile · salary-slip · documents · settings · about
```
Tab set and Home content are **role-driven** from `login.loginType` — mirroring the legacy `HomeAdmin_frag`, `HomeSupervisor_frag`, `HomeGatekeeper_frag`, `HomeNightPatrol_frag`, `HomeSales_frag`, `HomeSuperAdmin_frag`, `ClientMainActivity`, `EmployeeMainActivity`.

---

## 4. Screens by Role

### 4.1 Common
**Splash** — token check, licence expiry check, device-binding check, force-update gate, masters sync.
**Login** — mobile/username + password, "Login with OTP", biometric unlock after first login, device-binding notice.
**OTP** — 6-digit auto-read via SMS Retriever.
**Profile** — photo, code, designation, unit, contacts, blood group, PV status, ID card view; change password; language (EN/HI); logout.
**Notifications** — grouped inbox, deep-links to the relevant record.
**Chat** — thread list + conversation, text/image/location, read receipts (SignalR, offline queue).

### 4.2 EMPLOYEE (Guard / Gunman)
**Home** — big **PUNCH IN / PUNCH OUT** button showing today's status, current unit, shift timing, and a live "you are X m from the site" chip; below: this month's P/A/HD counts, latest salary slip card, open complaints, notices.
**Punch flow** — 1) acquire GPS (accuracy must be ≤ 50 m, mock-location detected and blocked) → 2) show distance vs geofence; if outside, allow "request exception" with a mandatory reason → 3) front-camera selfie (mandatory if the tenant setting says so; auto-compressed) → 4) submit. If offline, the punch is written to the outbox with a visible **Queued** badge and syncs automatically. Confirmation screen shows time, distance and a map thumbnail.
**My attendance** — month calendar with colour-coded days; tap a day for punch detail and selfies.
**Salary slip** — month picker, full earnings/deductions breakup exactly per `Salaryslipmodel`, download PDF, share.
**Documents** — my documents with expiry chips; upload from camera/file.
**Requests** — apply for leave/advance/transfer/uniform; status tracker.
**Complaint / Suggestion** — raise with photo; track status.
**Uniform ledger** — issued vs returned, outstanding recovery.

### 4.3 SUPERVISOR
**Home** — my units carousel with required-vs-present rings; pending approvals count; today's tasks; open incidents; patrol status.
**Unit attendance** — per unit roster with quick mark P/A/HD, bulk mark, and a "who hasn't punched" list with call buttons.
**Approvals** — the queue with punch selfie, distance chip and flags; swipe right to approve, left to reject (reason sheet). Works offline (queued decisions).
**Field report** — unit, contact person, remark, GPS auto-stamp, photos, and per-guard remarks; submit.
**Incident** — type, severity, date/time, guard, remark, photos.
**Movement / Reliever** — move a guard between units/posts; assign a reliever from a nearby-guard list.
**Turnout entry** — required/present/absent/reliever per unit-shift.
**Training** — record a session with attendees and photo.
**Patrol audit** — see scans of guards under me, missed rounds.

### 4.4 NIGHT_PATROL
**Home** — tonight's rounds with progress (3/8 checkpoints), next checkpoint with distance and a "navigate" action.
**Scanner** — full-screen QR camera; on scan: validate checkpoint, compute distance, **reject if beyond `MaxDistanceMeters`** with a clear message, capture photo if the checkpoint requires it, add optional remark, submit. Offline scans queue with GPS and timestamp preserved.
**My scans** — tonight's log with in-range pills.
**Night report** — end-of-shift summary submission.

### 4.5 GATEKEEPER
**Home** — visitors inside now, today's count, quick "New entry".
**Gate pass entry** — visitor name, mobile, purpose, whom to meet, vehicle no., material details, photo capture; save → printable/shareable pass with QR.
**Exit** — scan the pass QR or pick from the inside-now list to stamp exit.
**Log** — today/this week with search.

### 4.6 SALES
**Home** — follow-ups due today (overdue in red), visits this week, conversion stats.
**Visit entry** — company, contact person, contact no., location (GPS auto + manual), purpose, remark, photo.
**Follow-up** — link to a visit, next-follow-up date picker, outcome, stop-follow toggle.
**My clients & pipeline** — funnel, leaderboard.
**Client relation visit** — unit, contact person, timing, remark.

### 4.7 ADMIN / OPERATIONS (on the go)
**Home** — turnout summary, vacant posts, approvals, open complaints, live map entry point.
**Live map** — all field staff, tap for last-seen and trail.
**Approvals** — unified queue (attendance, recruits, advances, requests).
**Quick reports** — turnout, attendance summary, patrol compliance, complaint ageing.
**Task assign** — create and assign with attachment.

### 4.8 CLIENT
**Home** — guards on duty now (photo grid, live), attendance % this month, patrol compliance, open complaints, outstanding amount.
**Guards** — deployed list with photo, designation, shift, today's status.
**Patrol proof** — checkpoint scans with photos and times.
**Complaints** — raise with photo, track SLA.
**Invoices** — list, PDF download, payment status.

---

## 5. Offline-First Architecture (non-negotiable)

### 5.1 Outbox
`expo-sqlite` table `outbox(id TEXT PK, endpoint TEXT, method TEXT, payloadJson TEXT, filesJson TEXT, createdAt INT, attempts INT, lastError TEXT, status TEXT)`.
- Every field-write (punch in/out, QR scan, gate pass, incident, field report, visit, follow-up, attendance approval, turnout) is written to the outbox **first**, then flushed.
- Each item carries a client-generated `ClientRequestId` (UUID) sent as the `Idempotency-Key` — the server SPs de-duplicate, so retries are always safe.
- Flush triggers: connectivity regained (`expo-network` listener), app foreground, every 5 min, manual pull-to-refresh.
- Backoff: 5 s → 30 s → 2 min → 10 min → 1 h, capped at 24 h then surfaced as a user-actionable error.
- Images are stored in `FileSystem.documentDirectory/outbox/` and uploaded first (to the SAS URL) before the JSON payload is posted.
- The UI **always shows sync state**: a persistent chip "3 pending" in the header, per-row Queued/Syncing/Synced/Failed badges, and a Sync Centre screen listing every pending item with retry/discard.

### 5.2 Cached reads
Masters (states, cities, designations, shifts, complaint types, uniform items), my units, my roster and my checkpoints are cached in SQLite with a version stamp; `GET /masters/bootstrap` returns an ETag so cold start is a single call. TanStack Query is persisted so lists render instantly from cache and revalidate in the background.

### 5.3 Conflict rules
Attendance is server-authoritative: a duplicate punch returns `DUPLICATE_PUNCH` and the outbox item resolves as "already recorded" (not an error). Approvals use last-writer-wins with an audit entry. Nothing in the outbox is ever silently dropped.

---

## 6. Device, Location & Security

- **Background location** via `expo-location` + `expo-task-manager` foreground service (Android notification "Diti365 is tracking your duty location"), interval 2 min / 50 m displacement while on duty, **stopped automatically at punch-out**. Battery level reported with each ping.
- **Mock-location detection**: reject `isFromMockProvider` pings and punches with `MOCK_LOCATION_DETECTED`; log the attempt.
- **Device binding**: `deviceId` stored in SecureStore, sent on every request; a mismatch requires admin approval to reset (mirrors legacy `checkdeviceid`).
- **Permissions onboarding**: a purpose-first screen explaining camera/location/notification usage before the OS prompt; a per-OEM battery-optimisation guide (Xiaomi, Oppo, Vivo, Realme, Samsung) with a deep link to the settings page.
- **App lock**: optional biometric/PIN on resume.
- **Certificate pinning** on the API domain; **cleartext traffic disabled**; no secrets in the bundle; Sentry scrubs PII.
- **Force update**: version gate from `/me/bootstrap`; hard-block below the minimum supported build.
- Screenshots blocked on the salary-slip and employee-statutory screens (`FLAG_SECURE`).

## 7. Mobile Non-Functionals
- Cold start < 2.5 s on a Redmi 9A (2 GB RAM). APK ≤ 40 MB. Memory < 200 MB steady.
- Punch flow completes in ≤ 8 s including GPS lock and selfie upload on 3G.
- Crash-free sessions > 99.5 %. Offline punch loss rate 0.
- Full flows usable one-handed; primary actions in the bottom third; minimum touch target 48 dp.
- Hindi + English; number/date formatting per locale.
- Accessibility: TalkBack labels on every actionable element, minimum 14 sp text, high-contrast mode.

## 8. Definition of Done — Phase 3
- [ ] Every screen in §4 implemented for its role, matching or exceeding legacy `Diti365.apk` functionality.
- [ ] Airplane-mode test: 10 punches + 10 QR scans + 5 gate passes queued offline, all sync correctly and exactly once on reconnect.
- [ ] Background GPS survives 8 hours with the screen off on a Xiaomi device with battery optimisation disabled per the in-app guide.
- [ ] Geofence and mock-location rejections verified with a GPS spoofing app.
- [ ] EAS build produced for internal testing track; Sentry receiving events; EAS Update channel configured.
- [ ] Legacy feature parity checklist signed off against `docs/06-apk-inventory.md`.
