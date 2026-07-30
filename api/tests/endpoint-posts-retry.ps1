param()

# Retry POST endpoints with a richer sample payload to reduce 4xx/422 responses.
# WARNING: This may create test data in the dev database. Use with caution.

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiProject = "src\Diti365.Api"
$baseUrl = 'http://localhost:5000'
$reportPath = Join-Path $PSScriptRoot 'endpoint-posts-retry-report.csv'
$skipPatterns = @('delete','terminate','approve','lock','return','bank-advice','resign','uploaddoc','uploaddoc','approve','delet')

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
    $attempts = 0
    while ($attempts -lt 6) {
        try {
            $r = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
            if ($r.data -and $r.data.accessToken) { return $r.data.accessToken }
            if ($r.accessToken) { return $r.accessToken }
            if ($r.Data -and $r.Data.accessToken) { return $r.Data.accessToken }
            throw "Login token not found"
        } catch {
            $attempts++
            $err = $_.Exception.Response.StatusCode.Value__ 2>$null
            Write-Host "Login attempt $attempts failed: $($_)"
            if ($_.Exception -and $_.Exception.Response -and $_.Exception.Response.StatusCode -and $_.Exception.Response.StatusCode.Value__ -eq 429) {
                $wait = 5 * $attempts
                Write-Host "Rate-limited. Waiting $wait seconds before retrying..."
                Start-Sleep -Seconds $wait
                continue
            }
            throw $_
        }
    }
    throw "Login failed after retries"
}

function Enumerate-PostRoutes {
    Write-Host "Enumerating POST controller routes..."
    $controllersDir = Join-Path $repoRoot 'src\Diti365.Api\Controllers'
    $routes = @()
    Get-ChildItem -Path $controllersDir -Recurse -Filter *Controller.cs | ForEach-Object {
        $path = $_.FullName
        $text = Get-Content -Raw -Path $path
        $classPattern = '\[Route\("([^\"]+)"\)\]'
        $classMatch = [regex]::Match($text, $classPattern)
        $baseRoute = ''
        if ($classMatch.Success) { $baseRoute = $classMatch.Groups[1].Value }
        $pattern = '\[Http(Post)(?:\("([^\"]*)"\))?'
        $matches = [regex]::Matches($text,$pattern)
        foreach ($m in $matches) {
            $verb = 'POST'
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
            $routes += [PSCustomObject]@{ Url = $full; File = $path }
        }
    }
    return $routes | Sort-Object Url -Unique
}

# sample payload to try to satisfy common required fields
$samplePayload = @{
    Id = 1
    EmpId = 1
    ClientId = 1
    Name = 'sample'
    FromDate = '2026-07-01'
    ToDate = '2026-07-30'
    MonthYear = '202607'
    Amount = 1
    Reason = 'sample'
    Notes = 'automated-test'
}

$proc = Start-Api
try {
    $token = Login-Admin
    $authHeader = @{ Authorization = "Bearer $token" }

    $postRoutes = Enumerate-PostRoutes
    Write-Host "Found $($postRoutes.Count) POST actions. Filtering skip patterns..."
    $rows = @()
    foreach ($p in $postRoutes) {
        $low = $p.Url.ToLower()
        $skip = $false
        foreach ($sp in $skipPatterns) { if ($low.Contains($sp)) { $skip = $true; break } }
        if ($skip) { $rows += [PSCustomObject]@{ Url = "$baseUrl$($p.Url)"; Tried = $false; Skipped = $true; Reason='heuristic-skip' }; continue }
        $full = "$baseUrl$($p.Url)"
        try {
            Write-Host "POST $full"
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $resp = Invoke-WebRequest -Uri $full -Method Post -Headers $authHeader -Body ($samplePayload | ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
            $sw.Stop()
            $status = $resp.StatusCode
            $rows += [PSCustomObject]@{ Url = $full; Tried = $true; Skipped = $false; Status = $status; TimeMs = $sw.ElapsedMilliseconds; Sample = ($resp.Content | Select-Object -First 1) }
        } catch {
            $err = $_.ToString()
            $rows += [PSCustomObject]@{ Url = $full; Tried = $true; Skipped = $false; Status = 'ERR'; Error = $err }
        }
    }
    $rows | Export-Csv -Path $reportPath -NoTypeInformation -Force
    Write-Host "POST retry report saved to $reportPath"
    $suc = ($rows | Where-Object { $_.Status -ne 'ERR' -and $_.Status -ge 200 -and $_.Status -lt 300 }).Count
    $errc = ($rows | Where-Object { $_.Status -eq 'ERR' }).Count
    Write-Host "POSTs tried: $($rows.Count), succeeded 2xx: $suc, errors: $errc"
} finally {
    Stop-Api $proc
}

exit 0
