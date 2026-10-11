# =====================================================================
#   NGUYEN S AI - GEMINI WINDOWS COPILOT (COMMAND PROMPT MODE)
#   Dieu khien may tinh bang chuot vat ly va ban phim that - 10 FPS Lien tuc
# =====================================================================

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $Root) { $Root = (Get-Location).Path }

# Tự động mở khóa (Unblock-File) tất cả các tệp script tránh Windows SmartScreen chặn
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
        throw "API key quá ngắn hoặc không hợp lệ. Vui lòng kiểm tra lại khóa từ Google AI Studio."
    }

    # Kiểm tra quyền truy cập Google Generative Language API
    $testUrl = "https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey"
    try {
        $resp = Invoke-RestMethod -Uri $testUrl -Method Get -TimeoutSec 15
        if ($null -ne $resp) { return $true }
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match '400' -or $errMsg -match '403' -or $errMsg -match 'API_KEY_INVALID') {
            throw "Khóa API không hợp lệ hoặc chưa được kích hoạt quyền truy cập Gemini API (HTTP 400/403)."
        } elseif ($errMsg -match '429') {
            throw "Tài khoản Gemini API đang chạm giới hạn hạn mức (Rate limit/Quota 429)."
        }
        throw "Lỗi kết nối tới Google Gemini API: $errMsg"
    }
    return $true
}

Clear-Host
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  NGUYỄN'S AI - CHẾ ĐỘ COMMAND PROMPT TRỰC TIẾP (10 FPS LIÊN TỤC) " -ForegroundColor Yellow
Write-Host "  Điều khiển chuột vật lý và bàn phím thật trên màn hình Windows  " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

# Kiểm tra và cập nhật API Key
$apiKey = Get-StoredApiKey
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[!] Chưa tìm thấy Gemini API Key trong hệ thống." -ForegroundColor Yellow
    Write-Host "    Lấy khóa miễn phí tại: https://aistudio.google.com/app/apikey" -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        $inputKey = Read-Host ">> Vui lòng dán Gemini API Key của bạn và bấm Enter"
        $inputKey = $inputKey.Trim()
        if ([string]::IsNullOrWhiteSpace($inputKey)) { continue }

        Write-Host "Đang kiểm tra kết nối với Google Gemini API..." -ForegroundColor Cyan
        try {
            Verify-Key $inputKey | Out-Null
            Save-StoredApiKey $inputKey
            Write-Host "[OK] Xác thực thành công! Khóa đã được mã hóa Windows DPAPI an toàn." -ForegroundColor Green
            $apiKey = $inputKey
            break
        } catch {
            Write-Host "[LỖI] Khóa không hợp lệ hoặc lỗi mạng: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Vui lòng kiểm tra lại khóa Gemini API của bạn." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

# Đảm bảo file settings chuẩn
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
Write-Host "Trạng thái hoạt động:" -ForegroundColor White
Write-Host "  * Mô hình: Google Gemini 3.5 Flash Vision (Siêu ổn định, không bị nghẽn 503)" -ForegroundColor Gray
Write-Host "  * Tốc độ: 10 FPS liên tục (Chuột vật lý lướt có chủ đích, bù trừ DPI tự động)" -ForegroundColor Gray
Write-Host "  * Ngôn ngữ: Chỉ hỗ trợ Tiếng Anh và Tiếng Việt (có dấu đầy đủ)" -ForegroundColor Gray
Write-Host "  * Bộ nhớ dài hạn (memory.json): $($memList.Count) quy tắc đang được ghi nhớ" -ForegroundColor Magenta
Write-Host "    - Lệnh có từ 'nhớ'/'remember': Tự động lưu vào bộ nhớ memory.json" -ForegroundColor DarkGray
Write-Host "    - Lệnh có từ 'làm'/'do': Tự động củng cố đầu ra từ bộ nhớ đã lưu" -ForegroundColor DarkGray
Write-Host "  * Cách dùng: Nhập yêu cầu cần làm và bấm phím ENTER (gõ 'memory' để xem bộ nhớ)" -ForegroundColor Green
Write-Host "  * DỪNG KHẨN CẤP: Nhấn tổ hợp phím Ctrl + Fn + E (hoặc di chuột vào góc trên 0, 0)" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor DarkGray

# Vòng lặp nhận lệnh và thực thi
while ($true) {
    Write-Host ""
    Write-Host "[Nguyễn's AI] Nhập nhiệm vụ cần thực hiện (hoặc exit để thoát):" -ForegroundColor Green
    $task = Read-Host -Prompt "Lệnh >"
    if ([string]::IsNullOrWhiteSpace($task)) { continue }
    
    $trimmed = $task.Trim()
    if ($trimmed.ToLower() -in @("exit", "quit", "q", "thoat", "thoát", "dong", "đóng")) {
        Write-Host "Đã thoát Nguyễn's AI. Hẹn gặp lại bạn!" -ForegroundColor Yellow
        break
    }

    if ($trimmed.ToLower() -in @("memory", "bonho", "bộ nhớ", "bo nho", "xem nho", "xem nhớ", "memories")) {
        $curMems = Get-CliMemories
        Write-Host ""
        Write-Host "=== DANH SÁCH BỘ NHỚ ĐANG ĐƯỢC LƯU TRONG MEMORY.JSON ===" -ForegroundColor Magenta
        if ($curMems.Count -eq 0) {
            Write-Host "Chưa có quy tắc nào được lưu. Hãy thử gõ: 'Nhớ rằng tôi thích phông chữ Verdana' hoặc 'Remember: always maximize window'" -ForegroundColor Gray
        } else {
            for ($i = 0; $i -lt $curMems.Count; $i++) {
                Write-Host " [$($i+1)] $($curMems[$i].text)  ($($curMems[$i].created_at))" -ForegroundColor Cyan
            }
        }
        Write-Host "==========================================================" -ForegroundColor Magenta
        continue
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ">>> KHỞI ĐỘNG ĐIỀU KHIỂN CHUỘT VÀ BÀN PHÍM THẬT (10 FPS) <<<" -ForegroundColor Cyan
    Write-Host "Nhiệm vụ: $trimmed" -ForegroundColor White
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan

    # Xóa cờ dừng
    $stopPath = Join-Path $DataDir "stop.flag"
    if (Test-Path $stopPath) { Remove-Item $stopPath -Force }

    # Lưu nhiệm vụ vào task.json với UTF-8 để đảm bảo an toàn tuyệt đối khi truyền câu lệnh có dấu cách / dấu tiếng Việt
    $taskJsonPath = Join-Path $DataDir "task.json"
    [pscustomobject]@{
        task = $trimmed
        created_at = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $taskJsonPath -Encoding UTF8

    # Khởi chạy worker an toàn
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$WorkerPath" -TaskPath "$taskJsonPath" -ConsoleMode

    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "[Xong] Hoàn tất phiên thao tác trên Windows." -ForegroundColor Green
}