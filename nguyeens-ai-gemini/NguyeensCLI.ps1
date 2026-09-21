# =====================================================================
#   NGUYEN S AI - GEMINI WINDOWS COPILOT (COMMAND PROMPT MODE)
#   Dieu khien may tinh bang chuot vat ly va ban phim that - 10 FPS Lien tuc
# =====================================================================

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
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
    foreach ($testModel in @('gemini-3.5-flash', 'gemini-3.5-flash-lite', 'gemini-flash-lite-latest', 'gemini-3.8-flash')) {
        try {
            $url = "https://generativelanguage.googleapis.com/v1beta/models/${testModel}:generateContent?key=$Key"
            $body = @{
                contents = @(
                    @{ parts = @( @{ text = "Ping" } ) }
                )
            } | ConvertTo-Json -Depth 5
            $resp = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
            if ($null -ne $resp) { return $true }
        } catch {
            if ($testModel -ne 'gemini-3.8-flash') { continue }
            throw $_
        }
    }
    return $false
}

Clear-Host
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  NGUYEN S AI - CHE DO COMMAND PROMPT TRUC TIEP (10 FPS LIEN TUC)  " -ForegroundColor Yellow
Write-Host "  Dieu khien chuot vat ly va ban phim that tren man hinh Windows  " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

# Kiem tra va cap nhat API Key
$apiKey = Get-StoredApiKey
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[!] Chua tim thay Gemini API Key trong he thong." -ForegroundColor Yellow
    Write-Host "    Lay khoa mien phi tai: https://aistudio.google.com/app/apikey" -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        $inputKey = Read-Host ">> Vui long dan Gemini API Key cua ban va bam Enter"
        $inputKey = $inputKey.Trim()
        if ([string]::IsNullOrWhiteSpace($inputKey)) { continue }

        Write-Host "Dang kiem tra ket noi voi Google Gemini API..." -ForegroundColor Cyan
        try {
            Verify-Key $inputKey | Out-Null
            Save-StoredApiKey $inputKey
            Write-Host "[OK] Xac thuc thanh cong! Khoa da duoc ma hoa Windows DPAPI an toan." -ForegroundColor Green
            $apiKey = $inputKey
            break
        } catch {
            Write-Host "[LOI] Khoa khong hop le hoac loi mang: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Vui long kiem tra lai khoa Gemini API cua ban." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

# Dam bao file settings chuan
@{
    model = "gemini-3.5-flash-lite"
    max_steps = 30
    typing_delay_ms = 18
    fps = 10
    step_delay_ms = 100
} | ConvertTo-Json | Set-Content -Path $SettingsPath -Encoding UTF8

Write-Host "Trang thai hoat dong:" -ForegroundColor White
Write-Host "  * Mo hinh: Google Gemini 3.5 Flash Vision (Sieu on dinh, khong bi nghen 503)" -ForegroundColor Gray
Write-Host "  * Toc do: 10 FPS lien tuc (Chuot vat ly luot co chu dich)" -ForegroundColor Gray
Write-Host "  * Cach dung: Nhap yeu cau can lam va bam nut ENTER" -ForegroundColor Green
Write-Host "  * DUNG KHAN CAP: Nhan to hop phim Ctrl + Fn + E (hoac di chuot vao goc tren 0, 0)" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor DarkGray

# Vong lap nhan lenh va thuc thi
while ($true) {
    Write-Host ""
    Write-Host "[Nguyeen S AI] Nhap nhiem vu can thuc hien (hoac exit de thoat):" -ForegroundColor Green
    $task = Read-Host -Prompt "Lenh >"
    if ([string]::IsNullOrWhiteSpace($task)) { continue }
    
    $trimmed = $task.Trim()
    if ($trimmed.ToLower() -in @("exit", "quit", "q", "thoat", "dong")) {
        Write-Host "Da thoat Nguyeen S AI. Hen gap lai ban!" -ForegroundColor Yellow
        break
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ">>> KHOI DONG DIEU KHIEN CHUOT VA BAN PHIM THAT (10 FPS) <<<" -ForegroundColor Cyan
    Write-Host "Nhiem vu: $trimmed" -ForegroundColor White
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan

    # Xoa co dung
    $stopPath = Join-Path $DataDir "stop.flag"
    if (Test-Path $stopPath) { Remove-Item $stopPath -Force }

    # Khoi chay worker truc tiep
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $WorkerPath -TaskText $trimmed -ConsoleMode

    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "[Xong] Hoan tat phien thao tac tren Windows." -ForegroundColor Green
}