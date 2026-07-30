<#
Integration smoke test wrapper
- Starts the API (dotnet run) on http://localhost:5000 in a background process
- Runs the existing smoke-test.ps1 against that URL
- Stops the API process and returns the smoke test exit code

Usage:
  powershell -ExecutionPolicy Bypass -File tests\integration-smoke.ps1
#>
param()

$apiProject = "src\Diti365.Api"
$apiDir = Split-Path -Path $PSScriptRoot -Parent
$startInfo = @{
    FilePath = 'dotnet'
    ArgumentList = @('run','--project',$apiProject,'--urls','http://localhost:5000')
    WorkingDirectory = $apiDir
}
Write-Host "Starting API project $apiProject..."
$proc = Start-Process @startInfo -PassThru

Write-Host "Waiting for API to become ready..."
$ready = $false
for ($i=0; $i -lt 40; $i++) {
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:5000/health/live' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $ready) {
    Write-Error "API did not become ready within timeout. Killing process $($proc.Id)"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    exit 2
}

Write-Host "API ready. Running smoke tests..."
$smokeScript = Join-Path $apiDir 'smoke-test.ps1'
$smokeArgs = @('-ExecutionPolicy','Bypass','-File',$smokeScript,'-BaseUrl','http://localhost:5000')
# Run smoke-test in a child PowerShell process to capture exit code reliably
$p = Start-Process -FilePath powershell -ArgumentList $smokeArgs -Wait -PassThru -NoNewWindow
$exit = $p.ExitCode

Write-Host "Smoke tests completed with exit code $exit. Stopping API (PID $($proc.Id))"
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

exit $exit