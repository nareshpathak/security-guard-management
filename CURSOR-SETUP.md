# Cursor me PRD kaise use karein

## 1. Repo structure banayein

```
diti365/
├─ .cursor/rules/diti365.mdc     <- is folder se copy karein (always-applied rule)
├─ docs/prd/
│   ├─ PRD.md
│   ├─ 01-database.md
│   ├─ 02-api.md
│   ├─ 03-web.md
│   ├─ 04-mobile.md
│   ├─ 05-rbac-and-nfr.md
│   └─ 06-apk-inventory.md
├─ db/          (Phase 1 yahan banegi)
├─ api/         (Phase 1.5)
├─ apps/web/    (Phase 2)
├─ apps/mobile/ (Phase 3)
└─ packages/shared/
```

`Diti365-PRD/PRD.md` aur `docs/*` ko `docs/prd/` me daal dein.
`.cursor/rules/diti365.mdc` ko repo root ke `.cursor/rules/` me daalein — ye har chat me
automatically load hota hai, isliye Cursor kabhi rules bhoolta nahi.

## 2. APK dena hai ya nahi?

**Nahi.** Cursor binary decompile nahi kar sakta aur 19 MB file context waste karti hai.
Jo bhi APK me tha (120 endpoints, 91 screens, 63 DTOs) wo `06-apk-inventory.md` me
text form me maujood hai. APK ko sirf QA/reference ke liye repo se bahar rakhein
(ya `reference/Diti365-v4.8.apk` me daal kar `.gitignore` me add kar dein).

## 3. Kaam kaise karwayein — ek phase ek chat

Har phase ke liye **nayi Cursor chat** kholein (context clean rahega). Ye prompts use karein:

### Phase 1 — Database
```
@docs/prd/01-database.md @docs/prd/PRD.md

Read the full database spec. Then create the complete Phase 1 deliverable:

1. db/DbUp/ — a .NET 10 console runner project (DbUp + SQL Server provider) that runs
   db/scripts/*.sql in numeric order, idempotently, with a --dry-run flag.
2. db/scripts/001_schemas.sql through 140_audit_tables.sql — every table in §2 with the
   exact columns, types, keys, FKs, defaults and audit columns listed.

Start with scripts 001 to 040 only. Show me the files, then wait — I will say "continue"
before you write 050 onwards. Follow every convention in §1. Do not invent columns that
are not in the spec.
```

Phir batches me aage badhein:
- `continue with 050–090` (deployment, attendance, patrol, tasks, incidents)
- `continue with 100–140` (sales, inventory, payroll, docs, audit)
- `now 200_indexes.sql and 300_functions.sql — implement all 17 functions from §4`
- `now 400_views.sql — all 12 views from §5`
- `now 500–560 stored procedures. Start with 510_procedures_users.sql`
  (SP files bade hain — ek-ek file alag prompt me karwayein)
- `now 600_triggers.sql — all 6 triggers from §6`
- `now 700_seed_reference.sql — the full reference seed from §8.1`
- `now 710 and 720 — demo tenant and 90 days of demo transactions, deterministic`
- `now db/tests/ — tSQLt smoke test per stored procedure, plus the tenant-isolation test from §10`

### Phase 2 — API
```
@docs/prd/02-api.md @docs/prd/01-database.md @docs/prd/05-rbac-and-nfr.md

Scaffold the .NET 10 solution exactly per §1. Then implement, in this order:
1. Auth (§2) — JWT + rotating refresh, TenantGuardFilter, HasPermission attribute, legacy hash migration
2. V1 UsersController (§3.1) — all endpoints, legacy envelope
Stop after these two and show me. I'll say continue for OperationController.
```

### Phase 3 — Web
```
@docs/prd/03-web.md @docs/prd/05-rbac-and-nfr.md

Scaffold apps/web (Next.js 15 App Router, TS strict, Tailwind v4, shadcn/ui) and build
packages/ui with the design tokens from §1.1 and these components from §1.2:
AppShell, DataTable, StatCard, FilterBar, FormLayout, EntityDrawer, StatusPill.
Dark mode from day one. Storybook stories for each. Nothing else yet.
```
Uske baad screen-by-screen: `now build /operations/turnout exactly per §4.2`, etc.

### Phase 4 — Mobile
```
@docs/prd/04-mobile.md

Scaffold apps/mobile (Expo SDK 51, expo-router, NativeWind, TanStack Query).
Build the offline outbox from §5.1 first — expo-sqlite table, flush loop with backoff,
Idempotency-Key, sync-state UI. With tests. Nothing else yet.
```

## 4. Kaam karne ke tips

- **Ek prompt = ek file ya ek feature.** Poora phase ek saath mat maangein — quality gir jayegi.
- Har bade output ke baad `@docs/prd/...` dobara attach karein taaki Cursor spec se drift na kare.
- Har phase ke ant me: `Verify this phase against the "Definition of Done" checklist in
  @docs/prd/0X-....md and list anything missing.`
- Cursor ka **Agent/Composer mode** use karein (Ctrl+I), plain chat nahi — wo multiple files
  ek saath likh sakta hai.
- Model: Claude Opus/Sonnet lambe spec-following kaam ke liye behtar hai.
- Phase 1 ke baad ek baar khud DB banake dekh lein (LocalDB ya Docker `mcr.microsoft.com/mssql/server`)
  — seed data browse karke confirm karein ki business logic sahi hai, tabhi API pe jayein.

## 5. Sabse pehla kaam (P1 se bhi pehle)

Production SQL Server ka schema nikaal kar `01-database.md` se milayein:

```sql
SELECT s.name AS SchemaName, t.name AS TableName, c.name AS ColumnName,
       ty.name AS DataType, c.max_length, c.is_nullable
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
ORDER BY s.name, t.name, c.column_id;

SELECT s.name, o.name, o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P','FN','TF','IF','V','TR') ORDER BY o.type_desc, s.name, o.name;
```

Iska output mujhe de dein — main `01-database.md` ko real schema ke hisaab se reconcile kar dunga.
Yahi Phase 1 ka sabse bada risk hai.
