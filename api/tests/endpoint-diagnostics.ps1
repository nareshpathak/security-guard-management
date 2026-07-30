param()

# Endpoint diagnostics: safe GET-only pass across all discovered routes.
# - Starts API, logs in, enumerates routes (respects controller-level Route attributes)
# - Performs GET requests only (safe) to discover endpoints returning 5xx/4xx
# - Writes JSON report with detailed responses for errors

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiProject = "src\Diti365.Api"
$baseUrl = 'http://localhost:5000'
$reportPath = Join-Path $PSScriptRoot 'endpoint-diagnostics-report.json'

function Start-Api {
    Write-Host "Starting API project $apiProject..."
    $startInfo = @{
        FilePath = 'dotnet'
        ArgumentList = @('run','--project',$apiProject,'--urls',$baseUrl)
        WorkingDirectory = $repoRoot
    }
    $proc = Start-Process @startInfo -PassThru
    Write-Host "Waiting for API to become ready..."
    $ready = $false
    for ($i=0; $i -lt 60; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "$baseUrl/health/live" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($r.StatusCode -eq 200) { $ready = $true; break }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $ready) {
        Write-Error "API did not become ready within timeout. Killing process $($proc.Id)"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "API start failed"
    }
    return $proc
}

function Stop-Api($proc) {
    Write-Host "Stopping API (PID $($proc.Id))"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}

function Login-Admin {
    Write-Host "Logging in with seeded admin..."
    $loginUrl = "$baseUrl/api/v2/auth/login"
    $body = @{ LoginId = 'diti.admin'; Password = 'Admin@123' } | ConvertTo-Json
    $r = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
    if ($r.data -and $r.data.accessToken) { return $r.data.accessToken }
    if ($r.accessToken) { return $r.accessToken }
    if ($r.Data -and $r.Data.accessToken) { return $r.Data.accessToken }
    throw "Login token not found"
}

function Enumerate-Routes {
    Write-Host "Enumerating controller routes from source (controller-level routes respected)..."
    $controllersDir = Join-Path $repoRoot 'src\Diti365.Api\Controllers'
    $routes = @()
    Get-ChildItem -Path $controllersDir -Recurse -Filter *Controller.cs | ForEach-Object {
        $path = $_.FullName
        $text = Get-Content -Raw -Path $path
        $classPattern = '\[Route\("([^\"]+)"\)\]'
        $classMatch = [regex]::Match($text, $classPattern)
        $baseRoute = ''
        if ($classMatch.Success) { $baseRoute = $classMatch.Groups[1].Value }
        $pattern = '\[Http(Get|Post|Put|Delete|Patch)(?:\("([^\"]*)"\))?'
        $matches = [regex]::Matches($text,$pattern)
        foreach ($m in $matches) {
            $verb = $m.Groups[1].Value.ToUpper()
            $methodRoute = $m.Groups[2].Value
            if (-not $methodRoute) { $methodRoute = '' }
            $full = ''
            if ($methodRoute -ne '' -and $methodRoute.StartsWith('/')) {
                $full = $methodRoute
            } elseif ($baseRoute -ne '') {
                $b = $baseRoute.TrimEnd('/')
                $mr = $methodRoute.TrimStart('/')
                if ($mr -ne '') { $full = "$b/$mr" } else { $full = $b }
            } else {
                if ($methodRoute -ne '') { $full = "/api/v2/$methodRoute" } else { $full = '' }
            }
            if ($full -ne '' -and -not $full.StartsWith('/')) { $full = '/' + $full }
            if ($full -ne '') { $full = [regex]::Replace($full, '\{[^}]+\}', '1') }
            $routes += [PSCustomObject]@{ Controller = (Split-Path $path -Leaf); Verb = $verb; Route = $full; File = $path }
        }
    }
    return $routes
}

# Start diagnostics
$proc = Start-Api
try {
    $token = Login-Admin
    $authHeader = @{ Authorization = "Bearer $token" }
    $routes = Enumerate-Routes
    $rows = @()
    foreach ($r in $routes) {
        if ($r.Route -eq '') { continue }
        $full = "$baseUrl$($r.Route)"
        # Only GETs in this pass
        if ($r.Verb -ne 'GET') { continue }
        Start-Sleep -Milliseconds 200
        try {
            $resp = Invoke-WebRequest -Uri $full -Headers $authHeader -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            $rows += [PSCustomObject]@{ Url = $full; Verb = $r.Verb; Status = $resp.StatusCode; TimeMs = 0; Sample = ($resp.Content | Select-Object -First 1) }
        } catch {
            $ex = $_.Exception
            $status = ''
            if ($ex.Response -ne $null) {
                try { $status = $ex.Response.StatusCode.Value__ } catch {}
            }
            $content = ''
            try { $content = ($ex.Response.GetResponseStream() | ForEach-Object { '' }) } catch {}
            $rows += [PSCustomObject]@{ Url = $full; Verb = $r.Verb; Status = $status; Error = $_.ToString(); Sample = $content }
        }
    }
    $rows | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Host "Diagnostics JSON saved to $reportPath"
    $errRows = $rows | Where-Object { $_.Status -ge 500 -or $_.Status -eq '' -and $_.Error -ne '' }
    Write-Host "Errors found: $($errRows.Count)"
    $errRows | Select-Object -First 20 | Format-List
} finally {
    Stop-Api $proc
}

exit 0
