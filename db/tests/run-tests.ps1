param(
    [string] $Server = "localhost",
    [string] $Database = "Diti365_Dev"
)

$ErrorActionPreference = 'Stop'

function Run-Check($sql, $expected, $comparison, $msg) {
    $out = sqlcmd -S $Server -E -I -d $Database -h -1 -W -Q $sql
    if ($LASTEXITCODE -ne 0) { Write-Host "SQL failed: $msg" -ForegroundColor Red; exit 1 }
    $val = $out.Trim()
    if ($val -eq '') { Write-Host "No result for: $msg" -ForegroundColor Red; exit 1 }
    [int]$num = 0
    if (-not [int]::TryParse($val, [ref]$num)) { Write-Host "Non-numeric result for: $msg -> '$val'" -ForegroundColor Red; exit 1 }

    $ok = switch ($comparison) {
        'ge' { $num -ge $expected }
        'gt' { $num -gt $expected }
        'eq' { $num -eq $expected }
        default { throw "Unknown comparison: $comparison" }
    }
    if (-not $ok) { Write-Host "Check failed: $msg -> got $num expected $comparison $expected" -ForegroundColor Red; exit 1 }
    Write-Host "OK: $msg -> $num" -ForegroundColor Green
}

Write-Host "Running DB smoke checks against $Server / $Database" -ForegroundColor Cyan

Run-Check "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.tables;" 100 ge "Table count >= 100"
Run-Check "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.procedures;" 120 ge "Stored procedures >= 120"
Run-Check "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF');" 10 ge "Functions >= 10"
Run-Check "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.schemas WHERE name IN ('mst','org','sec','hr','ops');" 5 ge "Required schemas present"

# Check demo tenant seeded (company)
Run-Check "SET NOCOUNT ON; SELECT COUNT(*) FROM org.Company;" 1 ge "At least one company exists (seeded)"

# Check sample user exists
$out = sqlcmd -S $Server -E -I -d $Database -h -1 -W -Q "SET NOCOUNT ON; SELECT TOP(1) UserName FROM sec.Users;"
if ($LASTEXITCODE -ne 0) { Write-Host "SQL failed: user check" -ForegroundColor Red; exit 1 }
if ($out.Trim() -eq '') { Write-Host "No users found in sec.Users" -ForegroundColor Red; exit 1 }
Write-Host "OK: sec.Users has at least one user -> $($out.Trim())" -ForegroundColor Green

Write-Host "All smoke checks passed." -ForegroundColor Green
exit 0
