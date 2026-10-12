# =====================================================================
#   NGUYEN'S AI - GEMINI WINDOWS COPILOT (COMMAND PROMPT MODE)
#   Real desktop automation with physical mouse and native keyboard (10 FPS)
# =====================================================================

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $Root) { $Root = (Get-Location).Path }

# Automatically unblock all script files to prevent Windows SmartScreen blocks
try {
    Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
} catch {}

$DataDir = Join-Path $Root "data"
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
$SecretPath = Join-Path $DataDir "secret.txt"
$SettingsPath = Join-Path $DataDir "settings.json"
$WorkerPath = Join-Path $Root "worker.ps1"

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

function Get-StoredApiKey {
    if (Test-Path $SecretPath) {
        try {
            $sec = Get-Content -Raw $SecretPath | ConvertTo-SecureString
            return (New-Object Net.NetworkCredential("", $sec)).Password
        } catch {}
    }
    if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY }
    return $null
}

function Save-StoredApiKey([string]$Key) {
    $sec = ConvertTo-SecureString $Key -AsPlainText -Force
    $enc = ConvertFrom-SecureString $sec
    [IO.File]::WriteAllText($SecretPath, $enc, [Text.Encoding]::UTF8)
}

function Verify-Key([string]$Key) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $cleanKey = if ($Key) { $Key.Trim().Trim('"').Trim("'") } else { "" }
    if ([string]::IsNullOrWhiteSpace($cleanKey) -or $cleanKey.Length -lt 20) {
        throw "API key is too short or invalid. Please check your key from Google AI Studio."
    }

    # Verify access to Google Generative Language API
    $testUrl = "https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey"
    try {
        $resp = Invoke-RestMethod -Uri $testUrl -Method Get -TimeoutSec 15
        if ($null -ne $resp) { return $true }
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match '400' -or $errMsg -match '403' -or $errMsg -match 'API_KEY_INVALID') {
            throw "Invalid API key or unauthorized access to Gemini API (HTTP 400/403)."
        } elseif ($errMsg -match '429') {
            throw "Gemini API account hit rate limit / quota (HTTP 429)."
        }
        throw "Error connecting to Google Gemini API: $errMsg"
    }
    return $true
}

Clear-Host
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  NGUYEN'S AI - DIRECT COMMAND PROMPT MODE (10 FPS CONTINUOUS)    " -ForegroundColor Yellow
Write-Host "  Physical mouse glide and native keyboard automation on Windows  " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

# Check and update API Key
$apiKey = Get-StoredApiKey
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[!] No Gemini API Key found in system." -ForegroundColor Yellow
    Write-Host "    Get a free key at: https://aistudio.google.com/app/apikey" -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        $inputKey = Read-Host ">> Please paste your Gemini API Key and press Enter"
        $inputKey = $inputKey.Trim()
        if ([string]::IsNullOrWhiteSpace($inputKey)) { continue }

        Write-Host "Verifying connection with Google Gemini API..." -ForegroundColor Cyan
        try {
            Verify-Key $inputKey | Out-Null
            Save-StoredApiKey $inputKey
            Write-Host "[OK] Verification successful! Key securely saved with Windows DPAPI." -ForegroundColor Green
            $apiKey = $inputKey
            break
        } catch {
            Write-Host "[ERROR] Invalid key or network issue: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please re-check your Gemini API key." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

# Ensure standard settings file
@{
    model = "gemini-3.5-flash-lite"
    max_steps = 30
    typing_delay_ms = 18
    fps = 10
    step_delay_ms = 100
} | ConvertTo-Json | Set-Content -Path $SettingsPath -Encoding UTF8

$MemoryPath = Join-Path $DataDir "memory.json"
function Get-CliMemories {
    if (Test-Path $MemoryPath) {
        try {
            $raw = Get-Content -Raw $MemoryPath -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) { return @($raw | ConvertFrom-Json) }
        } catch {}
    }
    return @()
}

$memList = Get-CliMemories
Write-Host "System Status:" -ForegroundColor White
Write-Host "  * Model: Google Gemini 3.5 Flash Vision (High stability, rate-limit resilient)" -ForegroundColor Gray
Write-Host "  * Performance: 10 FPS continuous (Physical cursor glide, automatic DPI scaling)" -ForegroundColor Gray
Write-Host "  * Keyboard Output: Types in Vietnamese with full Unicode diacritics (tiếng Việt có dấu)" -ForegroundColor Gray
Write-Host "  * Persistent Memory (memory.json): $($memList.Count) rule(s) stored" -ForegroundColor Magenta
Write-Host "    - Commands with 'remember' / 'nhớ': Automatically stored in memory.json" -ForegroundColor DarkGray
Write-Host "    - Commands with 'do' / 'làm': Automatically reinforced with stored rules" -ForegroundColor DarkGray
Write-Host "  * Usage: Type your task and press ENTER (type 'memory' to view stored memories)" -ForegroundColor Green
Write-Host "  * EMERGENCY STOP: Press Ctrl + Fn + E (or move mouse cursor to (0, 0) corner)" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor DarkGray

# Command loop
while ($true) {
    Write-Host ""
    Write-Host "[Nguyen's AI] Enter task to perform (or type 'exit' to quit):" -ForegroundColor Green
    $task = Read-Host -Prompt "Command >"
    if ([string]::IsNullOrWhiteSpace($task)) { continue }
    
    $trimmed = $task.Trim()
    if ($trimmed.ToLower() -in @("exit", "quit", "q", "thoat", "thoát", "dong", "đóng")) {
        Write-Host "Nguyen's AI exited. See you next time!" -ForegroundColor Yellow
        break
    }

    if ($trimmed.ToLower() -in @("memory", "memories", "bonho", "bộ nhớ", "bo nho", "xem nho", "xem nhớ")) {
        $curMems = Get-CliMemories
        Write-Host ""
        Write-Host "=== STORED MEMORY RULES IN MEMORY.JSON ===" -ForegroundColor Magenta
        if ($curMems.Count -eq 0) {
            Write-Host "No rules stored yet. Try typing: 'Remember: always use Verdana font' or 'Nhớ rằng luôn mở trình duyệt toàn màn hình'" -ForegroundColor Gray
        } else {
            for ($i = 0; $i -lt $curMems.Count; $i++) {
                Write-Host " [$($i+1)] $($curMems[$i].text)  ($($curMems[$i].created_at))" -ForegroundColor Cyan
            }
        }
        Write-Host "==========================================" -ForegroundColor Magenta
        continue
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ">>> LAUNCHING PHYSICAL MOUSE AND KEYBOARD AUTOMATION (10 FPS) <<<" -ForegroundColor Cyan
    Write-Host "Task: $trimmed" -ForegroundColor White
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan

    # Clear stop flag
    $stopPath = Join-Path $DataDir "stop.flag"
    if (Test-Path $stopPath) { Remove-Item $stopPath -Force }

    # Save task to task.json in UTF-8
    $taskJsonPath = Join-Path $DataDir "task.json"
    [pscustomobject]@{
        task = $trimmed
        created_at = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $taskJsonPath -Encoding UTF8

    # Run worker securely
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$WorkerPath" -TaskPath "$taskJsonPath" -ConsoleMode

    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "[Done] Windows automation session completed." -ForegroundColor Green
}