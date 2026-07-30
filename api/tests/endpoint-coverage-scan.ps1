param()

# Heuristic endpoint coverage scan (safe-mode C)
# - Starts API, logs in with seeded admin, enumerates controller routes from source files
# - Calls GETs and safe POSTs, skips destructive routes by pattern
# - Produces CSV report in tests\endpoint-coverage-report.csv

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiProject = "src\Diti365.Api"
$baseUrl = 'http://localhost:5000'
$reportPath = Join-Path $PSScriptRoot 'endpoint-coverage-report.csv'
$skipPatterns = @('delete','insert','resign','terminate','approve','lock','issue','return','advance','activate','delet','remove','bank-advice','terminate','resign','uploaddoc','uploaddoc')

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
    for ($i=0; $i -lt 40; $i++) {
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
    try {
        $r = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
        # Assuming response shape { data: { accessToken: '...' } } or similar
        if ($r.data -and $r.data.accessToken) { return $r.data.accessToken }
        if ($r.accessToken) { return $r.accessToken }
        if ($r.Data -and $r.Data.accessToken) { return $r.Data.accessToken }
        Write-Warning "Login returned unexpected shape; dumping response"
        $r | ConvertTo-Json -Depth 5 | Out-File -FilePath "$PSScriptRoot\login-response.json"
        throw "Login token not found"
    } catch {
        Write-Error "Login failed: $_"
        throw $_
    }
}

function Enumerate-Routes {
    Write-Host "Enumerating controller routes from source (controller-level routes respected)..."
    $controllersDir = Join-Path $repoRoot 'src\Diti365.Api\Controllers'
    $routes = @()
    Get-ChildItem -Path $controllersDir -Recurse -Filter *Controller.cs | ForEach-Object {
        $path = $_.FullName
        $text = Get-Content -Raw -Path $path
        # find controller-level route if present: [Route("api/v2/something")] or [Route("api/v1/...")]
        $classPattern = '\[Route\("([^\"]+)"\)\]'
        $classMatch = [regex]::Match($text, $classPattern)
        $baseRoute = ''
        if ($classMatch.Success) { $baseRoute = $classMatch.Groups[1].Value }

        # method-level http attributes with optional route
        $pattern = '\[Http(Get|Post|Put|Delete|Patch)(?:\("([^\"]*)"\))?'
        $matches = [regex]::Matches($text,$pattern)
        foreach ($m in $matches) {
            $verb = $m.Groups[1].Value.ToUpper()
            $methodRoute = $m.Groups[2].Value
            if (-not $methodRoute) { $methodRoute = '' }
            # compute full route
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
            # normalize to start with /
            if ($full -ne '' -and -not $full.StartsWith('/')) { $full = '/' + $full }
            # substitute route params like {id:int} -> 1, {name} -> sample
            if ($full -ne '') {
                $full = [regex]::Replace($full, '\{[^}]+\}', '1')
            }
            $routes += [PSCustomObject]@{ Controller = (Split-Path $path -Leaf); Verb = $verb; Route = $full; File = $path }
        }
    }
    return $routes
}

function Build-Full-Url($route) {
    if (-not $route -or $route -eq '') { return $null }
    if ($route -match '^/') { return "$baseUrl$route" }
    return "$baseUrl$route"
}

# Start
$proc = Start-Api
try {
    $token = Login-Admin
    $authHeader = @{ Authorization = "Bearer $token" }

    $routes = Enumerate-Routes
    Write-Host "Found $($routes.Count) decorated actions. Filtering and deduplicating..."
    $seen = @{}
    $rows = @()
    foreach ($r in $routes) {
        $full = Build-Full-Url $($r.Route)
        if (-not $full) { continue }
        # heuristic skip based on route text
        $low = $r.Route.ToLower()
        $skip = $false
        foreach ($p in $skipPatterns) { if ($low.Contains($p)) { $skip = $true; break } }
        if ($skip) { $rows += [PSCustomObject]@{ Url = $full; Verb = $r.Verb; Skipped = $true; Reason = 'heuristic-match' }; continue }
        if ($seen.ContainsKey($full + '|' + $r.Verb)) { continue }
        $seen[$full + '|' + $r.Verb] = $true
        # make a safe request
        $result = @{ Url = $full; Verb = $r.Verb; Status = ''; Skipped = $false; Error = ''; TimeMs = 0; Sample = '' }
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            if ($r.Verb -eq 'GET') {
                $resp = Invoke-WebRequest -Uri $full -Headers $authHeader -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                $sw.Stop()
                $result.Status = $resp.StatusCode
                $result.TimeMs = $sw.ElapsedMilliseconds
                $result.Sample = ($resp.Content | Select-Object -First 1)
            } elseif ($r.Verb -eq 'POST') {
                # safe POST payload: empty object or small JSON; many POST endpoints will validate and return 4xx if missing fields
                $body = '{}' 
                $resp = Invoke-WebRequest -Uri $full -Headers $authHeader -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                $sw.Stop()
                $result.Status = $resp.StatusCode
                $result.TimeMs = $sw.ElapsedMilliseconds
                $result.Sample = ($resp.Content | Select-Object -First 1)
            } else {
                $result.Skipped = $true
                $result.Reason = 'unsupported-verb'
            }
        } catch {
            $err = $_.Exception
            $result.Error = $_.ToString()
            if ($err.Response -ne $null) {
                try { $code = $err.Response.StatusCode; $result.Status = $code } catch {}
            }
        }
        $rows += $result
    }

    # Write CSV report
    $rows | Select-Object Url,Verb,Status,Skipped,Reason,TimeMs,Error | Export-Csv -Path $reportPath -NoTypeInformation -Force
    Write-Host "Report saved to $reportPath"
    # brief summary
    $total = $rows.Count
    $skipped = ($rows | Where-Object { $_.Skipped -eq $true }).Count
    $ok = ($rows | Where-Object { $_.Status -ge 200 -and $_.Status -lt 300 }).Count
    $clientErr = ($rows | Where-Object { $_.Status -ge 400 -and $_.Status -lt 500 }).Count
    $serverErr = ($rows | Where-Object { $_.Status -ge 500 }).Count

    Write-Host "Scanned: $total, Skipped: $skipped, 2xx: $ok, 4xx: $clientErr, 5xx: $serverErr"
    # output top errors
    $rows | Where-Object { $_.Error -ne '' } | Select-Object -First 20 | Format-List

} finally {
    Stop-Api $proc
}

exit 0
