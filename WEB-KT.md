# Web App — Quick KT for New Developer

This is a short knowledge-transfer note to get a new developer productive on the web application portion of the Diti365 project.

Summary
-------
- Project root: C:\dev\diti365.worktrees\agents-fullstack-implementation-phase
- Web app sources: apps/web/src
- Framework: Next.js (app router), TypeScript, pnpm workspace
- API surface: backend routes live under api/src/Diti365.Api/Controllers/V2 and the frontend calls `/api/v2/...` endpoints using `getApi()` client helper
- Route validator: tools/check-routes.mjs (use `pnpm check:routes`)

What is already in place
------------------------
- Pages, lists and most CRUD UI are implemented under `apps/web/src/app` (folders: approvals, dashboard, clients, finance, inventory, operations, people, reports, sales, settings, tasks, etc.).
- Build and CI-friendly scripts are set up: `pnpm --filter web build`, `pnpm --filter web lint`, `pnpm --filter web run typecheck`.
- Route consistency verified (run `pnpm check:routes`) — current web/mobile API calls resolve to real backend routes.
- Recent fix: recruits page action endpoints aligned with backend (`/api/v2/recruits/{id}/status` and `/api/v2/recruits/{id}/convert`).

Remaining web features (missing pages/components)
------------------------------------------------
From the feature checklist, the following items are NOT present as dedicated pages/components in the web app and must be completed:
- Employee Family Details
- Map (map view for location visualization)
- Contract Termination (UI to terminate contracts)
- QR Code Creation / QR Management
- Picture/File Upload (generalized multi-file upload UI or specific flows)
- Events (events UI/events list)
- Firebase Integration (if required by mobile features or realtime chat)

Priority & Recommended order
----------------------------
1. Picture/File Upload — many flows rely on file uploads (documents, complaints, incidents). Implement an upload component and reuse it.
2. Employee Family Details — extend employee detail pages (people/employees/[id]) to show and edit family records.
3. Contract Termination — add termination UI in clients/contracts area.
4. QR Management — add QR creation page and endpoints, if backend supports QR; otherwise collaborate with backend to expose QR endpoints.
5. Map — add a map/list view and a reusable Map component; choose provider (Leaflet/OpenStreetMap recommended if no Google/Firebase constraint).
6. Events — add simple events list and create page (use existing ResourceList pattern).
7. Firebase Integration — only if required (chat realtime, push notifications). Discuss scope with backend/PO before starting.

Where to implement (code pointers)
----------------------------------
- Main pages folder: `apps/web/src/app/(app)` — add routes as peer folders (example: `people/employees/[id]/family` or `people/employees/family`)
- Reuse `ResourceList` component: `apps/web/src/components/resource-list.tsx` for list views
- API client: `apps/web/src/lib/api.ts` (use getApi().get/post/put/delete with typed generics)
- Common UI building blocks: `apps/web/src/components/*` (Status, buttons, forms)
- Utilities: `apps/web/src/lib/*` (list-query, format helpers)

Development & verification steps
--------------------------------
1. Branching: create a focused feature branch (e.g., `feature/web/employee-family`)
2. Implement UI and wire to API using same `/api/v2/...` contract. If backend API is missing, open a ticket or add a TODO and coordinate with backend team.
3. Run these locally to validate:
   - pnpm --filter web dev (for local dev)
   - pnpm --filter web build (to validate production build)
   - pnpm --filter web lint
   - pnpm --filter web run typecheck
   - pnpm check:routes (ensure no route mismatches)
4. Manual test flows: verify list, create, update, delete, file uploads, and navigation for each page you add.

Acceptance criteria
-------------------
- Page compiles and passes TypeScript and ESLint checks
- All API calls from newly added pages resolve against backend routes (no failures from tools/check-routes.mjs)
- File upload uses existing backend endpoints and successfully uploads files in local integration testing
- UX reuses existing components and matches app styling

Coding & commit guidance
------------------------
- Follow existing commit convention (e.g., `fix(web): ...`, `feat(web): ...`)
- Make small, focused commits per feature
- Run lint and typecheck before committing
- Do not commit generated files or diagnostic artifacts (e.g., `api/tests/endpoint-diagnostics-report.json`)

How to get help / next steps
---------------------------
- If an API endpoint is missing, open an issue and tag the backend owner; include the expected route and payload.
- If realtime or Firebase is required, discuss scope before implementing — it can be a substantial addition.

Useful commands
---------------
- Install workspace deps: `pnpm install`
- Dev server (web): `pnpm --filter web dev`
- Build web: `pnpm --filter web build`
- Lint web: `pnpm --filter web lint`
- Typecheck web: `pnpm --filter web run typecheck`
- Route check: `pnpm check:routes`

Done — start by implementing the Picture/File Upload component (high reuse), then Employee Family Details. Ask for API contract confirmation when needed.

(Generated by the dev team — keep this file updated as features are completed.)
