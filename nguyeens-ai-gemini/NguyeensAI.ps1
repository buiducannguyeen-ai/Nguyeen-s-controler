param([int]$Port = 8765)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $script:Root) { $script:Root = $PSScriptRoot }
if (-not $script:Root) { $script:Root = (Get-Location).Path }
$script:DataDir = Join-Path $script:Root 'data'
$script:WebDir = Join-Path $script:Root 'web'
$script:WorkerProcess = $null
$script:Listener = $null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null

$nativeMouseCode = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class NguyeensServerMouse {
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

    public struct POINT { public int X; public int Y; }
    const uint MOUSEEVENTF_MOVE = 0x0001;

    public static void SmoothMove(int startX, int startY, int endX, int endY, int steps, int delayMs) {
        for (int i = 1; i <= steps; i++) {
            int nx = (int)(startX + ((endX - startX) * (double)i / steps));
            int ny = (int)(startY + ((endY - startY) * (double)i / steps));
            SetCursorPos(nx, ny);
            mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(delayMs);
        }
    }

    public static void TestDemo() {
        POINT p;
        GetCursorPos(out p);
        int cx = p.X;
        int cy = p.Y;
        SmoothMove(cx, cy, cx + 160, cy, 18, 14);
        SmoothMove(cx + 160, cy, cx + 160, cy + 160, 18, 14);
        SmoothMove(cx + 160, cy + 160, cx, cy + 160, 18, 14);
        SmoothMove(cx, cy + 160, cx, cy, 18, 14);
    }
}
'@
if (-not ([System.Management.Automation.PSTypeName]'NguyeensServerMouse').Type) {
    Add-Type -TypeDefinition $nativeMouseCode -Language CSharp
}

function Write-JsonResponse {
    param($Response, $Object, [int]$StatusCode = 200)
    $json = $Object | ConvertTo-Json -Depth 12 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Write-FileResponse {
    param($Response, [string]$Path, [string]$ContentType)
    if (-not (Test-Path $Path)) {
        $Response.StatusCode = 404
        $Response.Close()
        return
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $Response.StatusCode = 200
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Read-RequestJson {
    param($Request)
    $reader = New-Object IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $body = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
    if ([string]::IsNullOrWhiteSpace($body)) { return [pscustomobject]@{} }
    return $body | ConvertFrom-Json
}

function Get-ApiKey {
    $secretPath = Join-Path $script:DataDir 'secret.txt'
    if (-not (Test-Path $secretPath)) { return $null }
    try {
        $secure = Get-Content -Raw -Path $secretPath | ConvertTo-SecureString
        return (New-Object Net.NetworkCredential('', $secure)).Password
    } catch { return $null }
}

function Save-ApiKey {
    param([string]$Key)
    $cleanKey = if ($Key) { $Key.Trim().Trim('"').Trim("'") } else { '' }
    if ([string]::IsNullOrWhiteSpace($cleanKey) -or $cleanKey.Length -lt 20) {
        throw 'Invalid Google Gemini API key. Google AI Studio keys typically start with AIzaSy... and are over 30 characters long.'
    }
    $secure = ConvertTo-SecureString $cleanKey -AsPlainText -Force
    $encrypted = $secure | ConvertFrom-SecureString
    [IO.File]::WriteAllText((Join-Path $script:DataDir 'secret.txt'), $encrypted, [Text.Encoding]::UTF8)
}

function Test-GeminiKey {
    param([string]$Key, [string]$Model = 'gemini-3.5-flash')
    $cleanKey = if ($Key) { $Key.Trim().Trim('"').Trim("'") } else { Get-ApiKey }
    if ([string]::IsNullOrWhiteSpace($cleanKey)) {
        throw 'No API key provided for testing.'
    }
    $testUri = "https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey"
    try {
        $resp = Invoke-RestMethod -Method Get -Uri $testUri -TimeoutSec 15
        if ($resp.models) {
            return @{ ok = $true; message = 'Google Gemini API key authenticated successfully!' }
        }
        return @{ ok = $true; message = 'Connected to Gemini API successfully.' }
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match '400' -or $errMsg -match '403' -or $errMsg -match 'API_KEY_INVALID') {
            throw 'Invalid Gemini API key or unauthorized access to Generative Language API (HTTP 400/403).'
        } elseif ($errMsg -match '429') {
            throw 'Your Google Gemini account reached rate limit / quota (HTTP 429).'
        }
        throw "Error verifying Gemini API: $errMsg"
    }
}

function Get-Settings {
    $path = Join-Path $script:DataDir 'settings.json'
    if (Test-Path $path) {
        try {
            $s = Get-Content -Raw $path | ConvertFrom-Json
            if ($s.model -match 'gemini-2\.' -or $s.model -match 'gemini-1\.' -or $s.model -eq 'gemini-3.6-flash' -or $s.model -eq 'gemini-3.8-flash') { $s.model = 'gemini-3.5-flash' }
            return $s
        } catch {}
    }
    return [pscustomobject]@{ model = 'gemini-3.5-flash'; max_steps = 30; typing_delay_ms = 18 }
}

function Save-Settings {
    param($Settings)
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:DataDir 'settings.json') -Encoding UTF8
}

function Set-InitialStatus {
    $path = Join-Path $script:DataDir 'status.json'
    if (-not (Test-Path $path)) {
        [pscustomobject]@{
            state = 'idle'; message = 'Ready for automation tasks with Gemini API.'; step = 0
            logs = @('Local automation engine (Gemini Edition) is ready.')
            updated_at = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    }
}

function Get-Status {
    $path = Join-Path $script:DataDir 'status.json'
    try { return Get-Content -Raw $path | ConvertFrom-Json }
    catch { return [pscustomobject]@{ state='idle'; message='Ready.'; step=0; logs=@() } }
}

function Stop-Worker {
    $stopPath = Join-Path $script:DataDir 'stop.flag'
    [IO.File]::WriteAllText($stopPath, (Get-Date).ToString('o'))
    if ($script:WorkerProcess -and -not $script:WorkerProcess.HasExited) {
        Start-Sleep -Milliseconds 250
        if (-not $script:WorkerProcess.HasExited) {
            Stop-Process -Id $script:WorkerProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
    $pidPath = Join-Path $script:DataDir 'worker.pid'
    if (Test-Path $pidPath) {
        try {
            $workerId = [int](Get-Content -Raw $pidPath)
            Stop-Process -Id $workerId -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    [pscustomobject]@{
        state='stopped'; message='Stopped per user request.'; step=0
        logs=@('Emergency stop activated.'); updated_at=(Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $script:DataDir 'status.json') -Encoding UTF8
}

function Start-Worker {
    param(
        [string]$Task,
        [string]$ImageBase64 = '',
        [string]$ImageMime = 'image/jpeg'
    )
    if ([string]::IsNullOrWhiteSpace($Task)) { throw 'Please enter task description.' }
    if (-not (Get-ApiKey)) { throw 'Please save your Gemini API key before starting.' }
    if ($script:WorkerProcess -and -not $script:WorkerProcess.HasExited) { throw 'Another task is currently running.' }

    $stopPath = Join-Path $script:DataDir 'stop.flag'
    if (Test-Path $stopPath) { Remove-Item $stopPath -Force }
    $taskPath = Join-Path $script:DataDir 'task.json'
    [pscustomobject]@{
        task = $Task
        image_base64 = $ImageBase64
        image_mime = $ImageMime
        created_at = (Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $taskPath -Encoding UTF8

    [pscustomobject]@{
        state='starting'; message='Capturing screen and initializing Gemini Vision 10 FPS loop.'; step=0
        logs=@('One-time permission granted. Gemini Vision initialized.'); updated_at=(Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $script:DataDir 'status.json') -Encoding UTF8

    $workerPath = Join-Path $script:Root 'worker.ps1'
    $arguments = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $workerPath + '"'),'-TaskPath',('"' + $taskPath + '"'))
    $script:WorkerProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
    [IO.File]::WriteAllText((Join-Path $script:DataDir 'worker.pid'), [string]$script:WorkerProcess.Id)
}

function Get-ServerMemories {
    $path = Join-Path $script:DataDir 'memory.json'
    if (Test-Path $path) {
        try {
            $raw = Get-Content -Raw $path -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) { return @($raw | ConvertFrom-Json) }
        } catch {}
    }
    return @()
}

function Save-ServerMemoryItem([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $path = Join-Path $script:DataDir 'memory.json'
    $existing = [System.Collections.Generic.List[object]]@(Get-ServerMemories)
    $clean = $Text.Trim()
    $found = $existing | Where-Object { $_.text -eq $clean }
    if (-not $found) {
        $newItem = [pscustomobject]@{
            id = (New-Guid).ToString('N').Substring(0, 8)
            text = $clean
            created_at = (Get-Date).ToString('o')
        }
        $existing.Add($newItem)
        $json = $existing | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText($path, $json, [Text.Encoding]::UTF8)
        return $newItem
    }
    return $null
}

function Delete-ServerMemoryItem([string]$Id) {
    $path = Join-Path $script:DataDir 'memory.json'
    $existing = [System.Collections.Generic.List[object]]@(Get-ServerMemories)
    if ([string]::IsNullOrWhiteSpace($Id) -or $Id -eq 'all') {
        [IO.File]::WriteAllText($path, '[]', [Text.Encoding]::UTF8)
        return $true
    }
    $filtered = $existing | Where-Object { $_.id -ne $Id }
    $json = @($filtered) | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($path, $json, [Text.Encoding]::UTF8)
    return $true
}

Set-InitialStatus

$mutex = New-Object Threading.Mutex($false, 'Local\NguyeensAI_Gemini_8765')
if (-not $mutex.WaitOne(0, $false)) {
    Start-Process "http://127.0.0.1:$Port/"
    Write-Host "Nguyeen's AI (Gemini Edition) dang chay trong mot cua so khac."
    exit 0
}

try {
    $script:Listener = New-Object Net.HttpListener
    $script:Listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $script:Listener.Start()
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Nguyễn's AI -- Phiên bản tích hợp Google Gemini API" -ForegroundColor Green
    Write-Host " Máy chủ đang lắng nghe tại: http://127.0.0.1:$Port/" -ForegroundColor Cyan
    Write-Host " Giữ cửa sổ này mở trong khi sử dụng." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Start-Process "http://127.0.0.1:$Port/"

    while ($script:Listener.IsListening) {
        $context = $script:Listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $response.Headers['Cache-Control'] = 'no-store'
        $path = $request.Url.AbsolutePath
        try {
            if ($request.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
                Write-FileResponse $response (Join-Path $script:WebDir 'index.html') 'text/html; charset=utf-8'
            } elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/logo.svg') {
                Write-FileResponse $response (Join-Path $script:WebDir 'logo.svg') 'image/svg+xml'
            } elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/config') {
                $settings = Get-Settings
                Write-JsonResponse $response @{ configured=[bool](Get-ApiKey); model=$settings.model }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/settings') {
                $data = Read-RequestJson $request
                if ($data.api_key) {
                    Save-ApiKey ([string]$data.api_key)
                }
                $settings = Get-Settings
                if ($data.model) { $settings.model = [string]$data.model }
                Save-Settings $settings
                Write-JsonResponse $response @{ ok=$true; message='Đã mã hóa và lưu Gemini API key an toàn trên máy này.' }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/verify-gemini') {
                $data = Read-RequestJson $request
                $result = Test-GeminiKey ([string]$data.api_key) ([string]$data.model)
                Write-JsonResponse $response $result
            } elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/status') {
                Write-JsonResponse $response (Get-Status)
            } elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/screenshot') {
                Write-FileResponse $response (Join-Path $script:DataDir 'screen.png') 'image/png'
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/start') {
                $data = Read-RequestJson $request
                Start-Worker ([string]$data.task) ([string]$data.image_base64) ([string]$data.image_mime)
                Write-JsonResponse $response @{ ok=$true; message='Task started successfully.' }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/test-mouse') {
                [NguyeensServerMouse]::TestDemo()
                $status = Get-Status
                $newLogs = @($status.logs) + @('Đã thử nghiệm di chuyển con chuột thật trên màn hình Windows thành công.')
                $status.logs = $newLogs
                $status.updated_at = (Get-Date).ToString('o')
                $status | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $script:DataDir 'status.json') -Encoding UTF8
                Write-JsonResponse $response @{ ok=$true; message='Con trỏ chuột thật của bạn vừa di chuyển thành công trên màn hình Windows!' }
            } elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/memory') {
                Write-JsonResponse $response (Get-ServerMemories)
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/memory') {
                $data = Read-RequestJson $request
                $saved = Save-ServerMemoryItem ([string]$data.text)
                Write-JsonResponse $response @{ ok=$true; memory=$saved }
            } elseif ($request.HttpMethod -eq 'DELETE' -and $path -eq '/api/memory') {
                $data = Read-RequestJson $request
                Delete-ServerMemoryItem ([string]$data.id)
                Write-JsonResponse $response @{ ok=$true; message='Đã xóa quy tắc bộ nhớ.' }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/stop') {
                Stop-Worker
                Write-JsonResponse $response @{ ok=$true; message='Đã dừng.' }
            } else {
                Write-JsonResponse $response @{ error='Không tìm thấy.' } 404
            }
        } catch {
            Write-JsonResponse $response @{ error=$_.Exception.Message } 400
        }
    }
} finally {
    try { Stop-Worker } catch {}
    try { $script:Listener.Stop(); $script:Listener.Close() } catch {}
    try { $mutex.ReleaseMutex(); $mutex.Dispose() } catch {}
}