param([int]$Port = 8765)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
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
Add-Type -TypeDefinition $nativeMouseCode -Language CSharp

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
        throw 'API key Google Gemini khong hop le. Khoa API Google AI Studio thuong bat dau bang AIza... va dai tren 30 ky tu.'
    }
    $secure = ConvertTo-SecureString $cleanKey -AsPlainText -Force
    $encrypted = $secure | ConvertFrom-SecureString
    [IO.File]::WriteAllText((Join-Path $script:DataDir 'secret.txt'), $encrypted, [Text.Encoding]::UTF8)
}

function Test-GeminiKey {
    param([string]$Key, [string]$Model = 'gemini-3.5-flash')
    $cleanKey = if ($Key) { $Key.Trim().Trim('"').Trim("'") } else { Get-ApiKey }
    if ([string]::IsNullOrWhiteSpace($cleanKey)) {
        throw 'Chua cung cap API key de kiem tra.'
    }
    $testUri = "https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey"
    try {
        $resp = Invoke-RestMethod -Method Get -Uri $testUri -TimeoutSec 15
        if ($resp.models) {
            return @{ ok = $true; message = 'Xac thuc Google Gemini API key thanh cong!' }
        }
        return @{ ok = $true; message = 'Ket noi Gemini API thanh cong.' }
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match '400' -or $errMsg -match '403' -or $errMsg -match 'API_KEY_INVALID') {
            throw 'Khoa Gemini API khong hop le hoac khong co quyen truy cap Generative Language API (HTTP 400/403).'
        } elseif ($errMsg -match '429') {
            throw 'Tai khoan Google Gemini cua ban dang cham gioi han han muc (Rate limit/Quota 429).'
        }
        throw "Loi khi kiem tra Gemini API: $errMsg"
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
            state = 'idle'; message = 'San sang nhan nhiem vu voi Gemini API.'; step = 0
            logs = @('Chuong trinh dieu khien cuc bo (Gemini Edition) da san sang.')
            updated_at = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    }
}

function Get-Status {
    $path = Join-Path $script:DataDir 'status.json'
    try { return Get-Content -Raw $path | ConvertFrom-Json }
    catch { return [pscustomobject]@{ state='idle'; message='San sang.'; step=0; logs=@() } }
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
        state='stopped'; message='Da dung theo yeu cau cua ban.'; step=0
        logs=@('Da kich hoat dung khan cap.'); updated_at=(Get-Date).ToString('o')
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
    Write-Host " Nguyeen's AI -- Phien ban tich hop Google Gemini API" -ForegroundColor Green
    Write-Host " May chu dang lang nghe tai: http://127.0.0.1:$Port/" -ForegroundColor Cyan
    Write-Host " Giu cua so nay mo trong khi su dung." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Start-Process "http://127.0.0.1:$Port/"

    while ($script:Listener.IsListening) {
        $context = $script:Listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $response.Headers['Cache-Control'] = 'no-store'
        $path = $request.Url.AbsolutePath
        try {
            if ($request.HttpMethod -eq 'GET' -and $path -eq '/') {
                Write-FileResponse $response (Join-Path $script:WebDir 'index.html') 'text/html; charset=utf-8'
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
                Write-JsonResponse $response @{ ok=$true; message='Da ma hoa va luu Gemini API key an toan tren may nay.' }
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
                $newLogs = @($status.logs) + @('Da thu nghiem di chuyen con chuot that tren man hinh Windows thanh cong.')
                $status.logs = $newLogs
                $status.updated_at = (Get-Date).ToString('o')
                $status | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $script:DataDir 'status.json') -Encoding UTF8
                Write-JsonResponse $response @{ ok=$true; message='Con tro chuot that cua ban vua di chuyen thanh cong tren man hinh Windows!' }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/stop') {
                Stop-Worker
                Write-JsonResponse $response @{ ok=$true; message='Da dung.' }
            } else {
                Write-JsonResponse $response @{ error='Khong tim thay.' } 404
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