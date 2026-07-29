# Database — Local Development

## Environment

| Item | Value |
|---|---|
| Engine | Microsoft SQL Server 2022 (RTM) 16.0.1000.6, Developer Edition |
| Host | `localhost` (default instance) |
| Auth | Windows Authentication (`-E` / `Integrated Security=true`) |
| Dev database | `Diti365_Dev` |
| CLI | `sqlcmd` |

## Connection strings

**sqlcmd**
```
sqlcmd -S localhost -E -I -d Diti365_Dev
```

> The `-I` flag sets QUOTED_IDENTIFIER ON. Without it, filtered indexes fail with Msg 1934.

**.NET (appsettings.Development.json)**
```
Server=localhost;Database=Diti365_Dev;Integrated Security=true;TrustServerCertificate=true;MultipleActiveResultSets=true
```

## Running the scripts

Until the DbUp runner exists, run scripts manually in numeric order:

```
sqlcmd -S localhost -E -I -d Diti365_Dev -i db\scripts\001_schemas.sql
sqlcmd -S localhost -E -I -d Diti365_Dev -i db\scripts\010_master_tables.sql
...
```

Or run everything in order (PowerShell):

```powershell
Get-ChildItem db\scripts\*.sql | Sort-Object Name | ForEach-Object {
    Write-Host "--> $($_.Name)" -ForegroundColor Cyan
    sqlcmd -S localhost -E -I -d Diti365_Dev -i $_.FullName -b
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $($_.Name)" -ForegroundColor Red; break }
}
```

Every script is idempotent, so re-running the whole set is safe and is the standard way to
verify a change.

## Resetting the database

```
sqlcmd -S localhost -E -I -Q "ALTER DATABASE Diti365_Dev SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE Diti365_Dev; CREATE DATABASE Diti365_Dev;"
```

## Spec

The authoritative schema specification is `docs/prd/01-database.md`.
No table, column, index, view, function, procedure or trigger may be created that is not
described there. See `DECISIONS.md` #7 for why this spec — not a production dump — is the
source of truth.
