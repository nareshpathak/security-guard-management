<#
    smoke-test.ps1

    Proves the whole stack end to end: HTTP -> controller -> repository ->
    stored procedure -> SQL Server -> seeded data, and back.

    Start the API first, in a separate terminal:
        cd C:\dev\diti365\api
        dotnet run --project src\Diti365.Api

    Then run this:
        powershell -ExecutionPolicy Bypass -File smoke-test.ps1
#>
param(
    [string] $BaseUrl = "https://localhost:7175",
    [string] $LoginId = "diti.admin",
    [string] $Password = "Admin@123"
)

# The dev certificate is self-signed, so skip validation for this script only.
if (-not ("TrustAll" -as [type])) {
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
}
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$pass = 0
$fail = 0
$token = $null

function Step {
    param([string] $Name, [scriptblock] $Body)
    Write-Host ("  {0,-46}" -f $Name) -NoNewline
    try {
        $result = & $Body
        Write-Host " PASS" -ForegroundColor Green
        if ($result) { Write-Host "        $result" -ForegroundColor DarkGray }
        $script:pass++
    }
    catch {
        Write-Host " FAIL" -ForegroundColor Red
        $msg = $_.Exception.Message
        if ($_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        Write-Host "        $msg" -ForegroundColor Red
        $script:fail++
    }
}

function Api {
    param([string] $Method, [string] $Path, $Body = $null, [switch] $Anonymous)
    $headers = @{}
    if (-not $Anonymous -and $token) { $headers["Authorization"] = "Bearer $token" }

    $args = @{ Method = $Method; Uri = "$BaseUrl$Path"; Headers = $headers; TimeoutSec = 30 }
    if ($Body) {
        $args.Body = ($Body | ConvertTo-Json -Depth 6)
        $args.ContentType = "application/json"
    }
    Invoke-RestMethod @args
}

Write-Host ""
Write-Host "============================================================"
Write-Host "  DITI365 API - SMOKE TEST"
Write-Host "  $BaseUrl"
Write-Host "============================================================"
Write-Host ""

# ---------------------------------------------------------------- liveness
Step "health check responds" {
    $r = Invoke-WebRequest -Uri "$BaseUrl/health/live" -TimeoutSec 10 -UseBasicParsing
    "status $($r.StatusCode)"
}

# ---------------------------------------------------------------- auth
Step "login with seeded admin" {
    $r = Api POST "/api/v2/auth/login" @{ loginId = $LoginId; password = $Password } -Anonymous
    $script:token = $r.data.accessToken
    if (-not $script:token) { throw "no access token in the response" }
    "user $($r.data.user.name), $($r.data.permissions.Count) permissions"
}

Step "bad password is rejected with 401" {
    try {
        Api POST "/api/v2/auth/login" @{ loginId = $LoginId; password = "wrong-password" } -Anonymous | Out-Null
        throw "a wrong password was accepted"
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw "expected 401, got $($_.Exception.Response.StatusCode.value__)" }
        "401 as expected"
    }
}

Step "unauthenticated request is rejected" {
    $saved = $script:token; $script:token = $null
    try {
        Api GET "/api/v2/me" | Out-Null
        throw "an anonymous request was allowed"
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw "expected 401, got $($_.Exception.Response.StatusCode.value__)" }
        "401 as expected"
    }
    finally { $script:token = $saved }
}

Step "tenant guard rejects a client-supplied companyId" {
    try {
        Api GET "/api/v2/employees?companyId=2" | Out-Null
        throw "companyId from the client was accepted"
    }
    catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -ne 400) { throw "expected 400 TENANT_PARAM_FORBIDDEN, got $code" }
        "400 TENANT_PARAM_FORBIDDEN"
    }
}

# ---------------------------------------------------------------- identity
Step "GET /me returns the tenant from the token" {
    $r = Api GET "/api/v2/me"
    if (-not $r.data.companyId) { throw "no companyId claim came back" }
    "company $($r.data.companyId), role $($r.data.roleCode)"
}

Step "GET /me/permissions" {
    $r = Api GET "/api/v2/me/permissions"
    "$($r.data.Count) permission codes"
}

# ---------------------------------------------------------------- masters
Step "masters bootstrap (13 result sets in one call)" {
    $r = Api GET "/api/v2/masters/bootstrap"
    "$($r.data.Count) result sets"
}

Step "states master is seeded" {
    $r = Api GET "/api/v2/masters/states"
    if ($r.data.Count -lt 30) { throw "expected 36 states, got $($r.data.Count)" }
    "$($r.data.Count) states"
}

# ---------------------------------------------------------------- core data
Step "employees list" {
    $r = Api GET "/api/v2/employees?page=1&pageSize=10"
    "$($r.meta.total) employees, showing $($r.data.Count)"
}

Step "units list" {
    $r = Api GET "/api/v2/units?page=1&pageSize=20"
    "$($r.meta.total) units"
}

Step "deployments list" {
    $r = Api GET "/api/v2/deployments?page=1&pageSize=20"
    "$($r.meta.total) active deployments"
}

# ---------------------------------------------------------------- the flagship screen
Step "live turnout board" {
    $r = Api GET "/api/v2/turnout/live"
    $short = @($r.data | Where-Object { $_.VacantNos -gt 0 })
    "$($r.data.Count) units, $($short.Count) short of strength"
}

Step "attendance for the current month" {
    $month = (Get-Date).ToString("yyyy-MM")
    $r = Api GET "/api/v2/attendance/summary?monthYear=$month&page=1&pageSize=10"
    "$($r.meta.total) employees with attendance"
}

Step "pending attendance approvals" {
    $r = Api GET "/api/v2/attendance/pending-approval?page=1&pageSize=10"
    "$($r.meta.total) rows awaiting approval"
}

Step "role dashboard (7 widget result sets)" {
    $r = Api GET "/api/v2/me/dashboard"
    "$($r.data.Count) widget sets"
}

# ---------------------------------------------------------------- patrol and payroll
Step "patrol checkpoints" {
    $r = Api GET "/api/v2/patrol/checkpoints?page=1&pageSize=10"
    "$($r.meta.total) checkpoints"
}

Step "patrol scan log" {
    $from = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
    $r = Api GET "/api/v2/patrol/logs?from=$from&page=1&pageSize=10"
    "$($r.meta.total) scans in the last 30 days"
}

Step "invoices" {
    $r = Api GET "/api/v2/invoices?page=1&pageSize=10"
    "$($r.meta.total) invoices"
}

Step "salary slip for the previous month" {
    # Pick a DEPLOYED employee, not just the first one on the roster. Relievers
    # sit on the roster with no deployment and therefore no attendance, so they
    # legitimately have no slip - testing one would fail for the wrong reason.
    $month = (Get-Date).AddMonths(-1).ToString("yyyy-MM")
    $empId = (Api GET "/api/v2/deployments?page=1&pageSize=1").data[0].EmpID
    if (-not $empId) { throw "no deployed employee to test with" }
    $r = Api GET "/api/v2/payroll/slips/$empId/$month"
    if (-not $r.data) { throw "no slip found for deployed employee $empId in $month" }
    "net payable $($r.data.NetPayble) for $($r.data.EmpName)"
}

# ---------------------------------------------------------------- newly added lists
Step "clients list with inline totals" {
    $r = Api GET "/api/v2/clients?page=1&pageSize=20"
    if ($r.meta.total -lt 1) { throw "no clients came back; the seed creates several" }
    $withUnits = @($r.data | Where-Object { $_.UnitCount -gt 0 })
    "$($r.meta.total) clients, $($withUnits.Count) with units"
}

Step "receipts list" {
    $r = Api GET "/api/v2/receipts?page=1&pageSize=20"
    "$($r.meta.total) receipts"
}

Step "advances list" {
    $r = Api GET "/api/v2/advances?page=1&pageSize=20"
    "$($r.meta.total) advances"
}

Step "a spoofed ping is stored and flagged, not dropped" {
    # Two pings, one of them claiming a mocked location. The batch must be
    # accepted whole - refusing it would discard the genuine ping too.
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
    $body = @{
        deviceId = "smoke-test"
        pings = @(
            @{ latitude = 28.6139; longitude = 77.2090; loggedAt = $now; source = "FG"; isMockLocation = $false },
            @{ latitude = 19.0760; longitude = 72.8777; loggedAt = $now; source = "BG"; isMockLocation = $true }
        )
    }
    $r = Api POST "/api/v2/tracking/ping/batch" $body
    if ($r.data.Id -ne 2) { throw "expected both pings stored, got Id=$($r.data.Id)" }
    if ($r.data.Message -notmatch "flagged as mock") { throw "the spoofed ping was not flagged: $($r.data.Message)" }
    $r.data.Message
}

# ---------------------------------------------------------------- reports
Step "report allow-list" {
    $r = Api GET "/api/v2/reports"
    "$($r.data.Count) report keys"
}

Step "an unknown report key is a 404, not a SQL call" {
    try {
        Api GET "/api/v2/reports/definitely-not-a-report" | Out-Null
        throw "an unknown report key was accepted"
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw "expected 404, got $($_.Exception.Response.StatusCode.value__)" }
        "404 as expected"
    }
}

# ---------------------------------------------------------------- legacy surface
Step "legacy api/Users/getstates returns the old envelope" {
    # The legacy surface is authenticated, same as the real app after login.
    $r = Invoke-RestMethod -Uri "$BaseUrl/api/Users/getstates" -TimeoutSec 30 `
            -Headers @{ Authorization = "Bearer $token" }
    if ($null -eq $r.Success) { throw "the legacy envelope is missing its Success member" }
    "Success=$($r.Success), Data=$($r.Data.Count) rows"
}

# ---------------------------------------------------------------- tenant isolation
Step "second tenant cannot see the first tenant's data" {
    $saved = $script:token
    try {
        $r = Api POST "/api/v2/auth/login" @{ loginId = "shield.admin"; password = "Admin@123" } -Anonymous
        $script:token = $r.data.accessToken
        $units = Api GET "/api/v2/units?page=1&pageSize=50"
        if ($units.meta.total -gt 0) {
            throw "Shield Force sees $($units.meta.total) units; it has none of its own, so this is a leak"
        }
        "Shield Force sees 0 units, as it should"
    }
    finally { $script:token = $saved }
}

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "------------------------------------------------------------"
Write-Host ""

if ($fail -gt 0) { exit 1 }
