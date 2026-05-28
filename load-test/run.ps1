#!/usr/bin/env pwsh
# Load-test runner for AnMates API
# Usage: .\run.ps1 [options]
#   -VUs       Peak virtual users (default: 500)
#   -UserPool  Pre-created user pool size (default: 100)
#   -Clean     Remove result files before running

param(
    [int]$VUs      = 500,
    [int]$UserPool = 100,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

# ── helpers ──────────────────────────────────────────────────────────────────
function Banner($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)     { Write-Host "    $msg" -ForegroundColor Green }
function Warn($msg)   { Write-Host "    [warn] $msg" -ForegroundColor Yellow }
function Die($msg)    { Write-Host "`n[ERROR] $msg" -ForegroundColor Red; exit 1 }

# ── preflight ────────────────────────────────────────────────────────────────
Banner "Preflight checks"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Die "docker not found in PATH" }
$composeOk = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) { Die "docker compose plugin not available" }
Ok "docker compose: OK"

if (-not (Test-Path "$ScriptDir\k6-script.js")) { Die "k6-script.js not found in $ScriptDir" }
Ok "k6-script.js: found"

# ── clean previous results ────────────────────────────────────────────────────
if ($Clean -and (Test-Path "$ScriptDir\results\raw.json")) {
    Banner "Cleaning previous results"
    Remove-Item "$ScriptDir\results\raw.json" -Force
    Ok "results/raw.json removed"
}

New-Item -ItemType Directory -Force "$ScriptDir\results" | Out-Null

# ── update k6 stage config for requested VU count ─────────────────────────────
# We patch the compose env on the fly; the script reads USER_POOL from env.
$env:USER_POOL = "$UserPool"

# ── tear down any leftover containers ─────────────────────────────────────────
Banner "Tearing down previous stack (if any)"
docker compose down --remove-orphans 2>&1 | Out-Null
Ok "done"

# ── run ───────────────────────────────────────────────────────────────────────
Banner "Starting stack  (db + api build + k6 load test)"
Write-Host "    Peak VUs  : $VUs" -ForegroundColor White
Write-Host "    User pool : $UserPool" -ForegroundColor White
Write-Host "    This takes ~4 minutes. Press Ctrl+C to abort.`n" -ForegroundColor White

$startTime = Get-Date
docker compose up --build --abort-on-container-exit
$exitCode = $LASTEXITCODE

Banner "Tearing down stack"
docker compose down --remove-orphans 2>&1 | Out-Null
Ok "containers removed"

# ── parse results ─────────────────────────────────────────────────────────────
$rawFile = "$ScriptDir\results\raw.json"
if (-not (Test-Path $rawFile)) {
    Die "raw.json not found — test may have failed before k6 wrote output"
}

Banner "Parsing results"

$durations   = [System.Collections.Generic.List[double]]::new()
$statusCodes = @{}
$dataSent    = 0.0
$dataRecv    = 0.0
$mainReqs    = 0
$setupReqs   = 0
$firstTime   = $null
$lastTime    = $null
$vuSamples   = [System.Collections.Generic.List[int]]::new()

Get-Content $rawFile | ForEach-Object {
    try { $obj = $_ | ConvertFrom-Json } catch { return }
    if ($obj.type -ne "Point") { return }

    $t = $obj.data.time
    if ($t) {
        if (-not $firstTime) { $firstTime = [datetime]$t }
        $lastTime = [datetime]$t
    }

    switch ($obj.metric) {
        "http_req_duration" { $durations.Add($obj.data.value) }
        "http_reqs" {
            $grp = $obj.data.tags.group
            if ($grp -match "setup") { $setupReqs++ } else { $mainReqs++ }
            $s = $obj.data.tags.status
            if ($s) {
                if (-not $statusCodes[$s]) { $statusCodes[$s] = 0 }
                $statusCodes[$s]++
            }
        }
        "vus"           { $vuSamples.Add([int]$obj.data.value) }
        "data_sent"     { $dataSent += $obj.data.value }
        "data_received" { $dataRecv += $obj.data.value }
    }
}

function Pct($arr, $p) {
    if ($arr.Count -eq 0) { return 0 }
    $sorted = ($arr | Sort-Object)
    $idx = [int][Math]::Ceiling($p / 100.0 * $sorted.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    return [Math]::Round($sorted[$idx], 2)
}

$sorted     = ($durations | Sort-Object)
$totalSec   = if ($firstTime -and $lastTime) { [Math]::Round(($lastTime - $firstTime).TotalSeconds) } else { 0 }
$rps        = if ($totalSec -gt 0) { [Math]::Round($mainReqs / $totalSec, 1) } else { 0 }
$peakVU     = if ($vuSamples.Count -gt 0) { ($vuSamples | Measure-Object -Maximum).Maximum } else { 0 }
$total4xx   = ($statusCodes.Keys | Where-Object { $_ -like "4*" } | ForEach-Object { $statusCodes[$_] } | Measure-Object -Sum).Sum
$total5xx   = ($statusCodes.Keys | Where-Object { $_ -like "5*" } | ForEach-Object { $statusCodes[$_] } | Measure-Object -Sum).Sum
$total2xx   = ($statusCodes.Keys | Where-Object { $_ -like "2*" } | ForEach-Object { $statusCodes[$_] } | Measure-Object -Sum).Sum
$errorRate  = if ($mainReqs -gt 0) { [Math]::Round(($total4xx + $total5xx) / $mainReqs * 100, 2) } else { 0 }

$p95 = Pct $sorted 95
$p99 = Pct $sorted 99

$slo_p95   = $p95 -lt 500
$slo_p99   = $p99 -lt 1000
$slo_errRate = $errorRate -lt 1.0

function SloIcon($pass) { if ($pass) { "PASS" } else { "FAIL" } }

# ── print report ──────────────────────────────────────────────────────────────
$endTime = Get-Date
$wallTime = [Math]::Round(($endTime - $startTime).TotalSeconds)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  ANMATES API LOAD TEST REPORT  —  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

Write-Host "`n  SETUP" -ForegroundColor Cyan
Write-Host "  User pool  : $UserPool tokens"
Write-Host "  Peak VUs   : $peakVU"
Write-Host "  Test time  : ${totalSec}s  (wall: ${wallTime}s)"

Write-Host "`n  THROUGHPUT" -ForegroundColor Cyan
Write-Host "  Total reqs : $mainReqs"
Write-Host "  Avg req/s  : $rps"
Write-Host "  Data sent  : $([Math]::Round($dataSent/1MB,2)) MB"
Write-Host "  Data recv  : $([Math]::Round($dataRecv/1MB,2)) MB"

Write-Host "`n  LATENCY (ms)" -ForegroundColor Cyan
Write-Host "  p50  :  $(Pct $sorted 50)"
Write-Host "  p75  :  $(Pct $sorted 75)"
Write-Host "  p90  :  $(Pct $sorted 90)"
Write-Host "  p95  :  $p95  (SLO: p95<500ms)   [$(SloIcon $slo_p95)]" -ForegroundColor $(if ($slo_p95) { "Green" } else { "Red" })
Write-Host "  p99  :  $p99  (SLO: p99<1000ms) [$(SloIcon $slo_p99)]" -ForegroundColor $(if ($slo_p99) { "Green" } else { "Red" })
Write-Host "  max  :  $(Pct $sorted 100)"

Write-Host "`n  ERRORS" -ForegroundColor Cyan
Write-Host "  2xx  :  $total2xx"
Write-Host "  4xx  :  $total4xx"
Write-Host "  5xx  :  $total5xx"
Write-Host "  Rate :  $errorRate%  (SLO: rate<1%) [$(SloIcon $slo_errRate)]" -ForegroundColor $(if ($slo_errRate) { "Green" } else { "Red" })

Write-Host "`n  STATUS BREAKDOWN" -ForegroundColor Cyan
$statusCodes.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Key)  :  $($_.Value)"
}

Write-Host ""
$allPass = $slo_p95 -and $slo_p99 -and $slo_errRate
if ($allPass) {
    Write-Host "  RESULT: ALL SLOs PASSED" -ForegroundColor Green
} else {
    Write-Host "  RESULT: ONE OR MORE SLOs FAILED" -ForegroundColor Red
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  Raw data: load-test\results\raw.json`n" -ForegroundColor Gray

if ($exitCode -ne 0 -and -not $allPass) { exit 1 }
