<#
    run-all.ps1
    Runs every db/scripts/*.sql against the local dev database, in numeric order.
    Stops at the first error (-b makes sqlcmd return a non-zero exit code).

    Usage:
        cd C:\dev\diti365
        powershell -ExecutionPolicy Bypass -File db\run-all.ps1
        powershell -ExecutionPolicy Bypass -File db\run-all.ps1 -Reset
#>
param(
    [string] $Server   = "localhost",
    [string] $Database = "Diti365_Dev",
    [switch] $Reset
)

$ErrorActionPreference = "Stop"
$scriptDir = Join-Path $PSScriptRoot "scripts"

if ($Reset) {
    Write-Host "Dropping and recreating $Database ..." -ForegroundColor Yellow
    $sql = "IF DB_ID('$Database') IS NOT NULL BEGIN ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Database]; END; CREATE DATABASE [$Database];"
    sqlcmd -S $Server -E -I -Q $sql -b
    if ($LASTEXITCODE -ne 0) { Write-Host "Reset failed." -ForegroundColor Red; exit 1 }
}

sqlcmd -S $Server -E -I -Q "IF DB_ID('$Database') IS NULL CREATE DATABASE [$Database];" -b | Out-Null

<#
    Superseded scripts.
    710_seed_demo_tenant.sql is replaced by 711_seed_demo_tenant.sql. The original
    used sys.all_objects under CROSS APPLY, which made the seed appear to hang once
    the migration had created 107 tables, 74 indexes, 150 procedures and 12 triggers.
    710 could not be edited in place because a Windows process held a lock on it;
    delete it when convenient and drop it from this list. See DECISIONS.md #27.
#>
$Exclude = @('710_seed_demo_tenant.sql')

$files = Get-ChildItem -Path $scriptDir -Filter *.sql |
         Where-Object { $Exclude -notcontains $_.Name } |
         Sort-Object Name
if ($files.Count -eq 0) { Write-Host "No .sql files in $scriptDir" -ForegroundColor Red; exit 1 }
if ($Exclude.Count -gt 0) {
    Write-Host ("Skipping superseded: {0}" -f ($Exclude -join ', ')) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Running $($files.Count) script(s) against $Server / $Database" -ForegroundColor Cyan
Write-Host ("-" * 60)

$failed = $false
foreach ($f in $files) {
    Write-Host ("  {0,-34}" -f $f.Name) -NoNewline
    $out = sqlcmd -S $Server -E -I -d $Database -i $f.FullName -b 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host ""
        $out | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        $failed = $true
        break
    }
    Write-Host " ok" -ForegroundColor Green
}

Write-Host ("-" * 60)
if ($failed) { Write-Host "Run stopped on error." -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "OBJECT COUNT" -ForegroundColor Cyan
sqlcmd -S $Server -E -I -d $Database -h -1 -W -Q @"
SET NOCOUNT ON;
SELECT 'Schemas       : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.schemas WHERE name IN ('mst','org','sec','hr','crm','ops','inv','fin','doc','aud');
SELECT 'Tables        : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.tables;
SELECT 'Foreign keys  : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.foreign_keys;
SELECT 'Check constr. : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.check_constraints;
SELECT 'Indexes       : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.indexes WHERE object_id IN (SELECT object_id FROM sys.tables) AND index_id > 0;
SELECT 'Views         : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.views;
SELECT 'Procedures    : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.procedures;
SELECT 'Functions     : ' + CAST(COUNT(*) AS VARCHAR(10)) FROM sys.objects WHERE type IN ('FN','IF','TF');
"@ -b

Write-Host ""
Write-Host "TABLES PER SCHEMA" -ForegroundColor Cyan
sqlcmd -S $Server -E -I -d $Database -W -Q @"
SET NOCOUNT ON;
SELECT s.name AS [Schema], COUNT(*) AS [Tables]
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
GROUP BY s.name ORDER BY s.name;
"@ -b

Write-Host ""
Write-Host "All scripts ran successfully." -ForegroundColor Green
Write-Host "Run again to prove idempotency - the result must be identical." -ForegroundColor DarkGray
Write-Host ""
