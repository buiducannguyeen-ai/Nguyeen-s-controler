param(
    [string]$TaskPath,
    [string]$TaskText,
    [string]$ImagePath,
    [switch]$ConsoleMode
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $Root 'data'
$StatusPath = Join-Path $DataDir 'status.json'
$StopPath = Join-Path $DataDir 'stop.flag'
$ScreenPath = Join-Path $DataDir 'screen.png'
$script:Logs = New-Object Collections.Generic.List[string]
$script:VirtualLeft = 0
$script:VirtualTop = 0
$script:VirtualWidth = 1920
$script:VirtualHeight = 1080
$script:ImageMimeType = 'image/jpeg'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$nativeCode = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public static class NguyeensNativeInput {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] static extern uint SendInput(uint nInputs, INPUT[] inputs, int cbSize);
    [DllImport("user32.dll")] static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr extraInfo);
    [DllImport("user32.dll")] public static extern short VkKeyScan(char ch);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);

    public static void EnableDpiAwareness() {
        try {
            // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
            SetProcessDpiAwarenessContext((IntPtr)(-4));
        } catch {
            try { SetProcessDPIAware(); } catch {}
        }
    }

    public static bool IsEmergencyStopPressed() {
        // VK_CONTROL = 0x11, VK_LCONTROL = 0xA2, VK_RCONTROL = 0xA3
        bool ctrl = (GetAsyncKeyState(0x11) & 0x8000) != 0 ||
                    (GetAsyncKeyState(0xA2) & 0x8000) != 0 ||
                    (GetAsyncKeyState(0xA3) & 0x8000) != 0;

        // Key 'E' / 'e' = 0x45
        bool keyE = (GetAsyncKeyState(0x45) & 0x8000) != 0;

        // When pressing Ctrl + Fn + E on Windows keyboards, both Ctrl (0x11) and E (0x45)
        // are detected. This reliably catches Ctrl+Fn+E on any PC/laptop keyboard.
        return ctrl && keyE;
    }

    public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public InputUnion U; }
    [StructLayout(LayoutKind.Explicit)] struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT {
        public int dx; public int dy; public uint mouseData; public uint dwFlags;
        public uint time; public UIntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT {
        public ushort wVk; public ushort wScan; public uint dwFlags;
        public uint time; public UIntPtr dwExtraInfo;
    }

    const uint INPUT_MOUSE = 0;
    const uint INPUT_KEYBOARD = 1;
    const uint MOUSEEVENTF_MOVE = 0x0001;
    const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004;
    const uint MOUSEEVENTF_RIGHTDOWN = 0x0008, MOUSEEVENTF_RIGHTUP = 0x0010;
    const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020, MOUSEEVENTF_MIDDLEUP = 0x0040;
    const uint MOUSEEVENTF_WHEEL = 0x0800, MOUSEEVENTF_HWHEEL = 0x01000;
    const uint KEYEVENTF_KEYUP = 0x0002, KEYEVENTF_UNICODE = 0x0004;

    public static void MoveTo(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, UIntPtr.Zero);
    }

    static void Mouse(uint flags, int data = 0) {
        INPUT i = new INPUT(); i.type = INPUT_MOUSE;
        i.U.mi = new MOUSEINPUT { dwFlags = flags, mouseData = unchecked((uint)data) };
        SendInput(1, new INPUT[] { i }, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void Click(string button) {
        string b = (button ?? "left").ToLowerInvariant();
        uint down = MOUSEEVENTF_LEFTDOWN, up = MOUSEEVENTF_LEFTUP;
        if (b == "right") { down = MOUSEEVENTF_RIGHTDOWN; up = MOUSEEVENTF_RIGHTUP; }
        if (b == "middle") { down = MOUSEEVENTF_MIDDLEDOWN; up = MOUSEEVENTF_MIDDLEUP; }
        Mouse(down); Thread.Sleep(45); Mouse(up);
    }

    public static void DoubleClick(string button) {
        Click(button); Thread.Sleep(90); Click(button);
    }

    public static void MouseDown(string button) {
        string b = (button ?? "left").ToLowerInvariant();
        uint down = b == "right" ? MOUSEEVENTF_RIGHTDOWN : (b == "middle" ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_LEFTDOWN);
        Mouse(down);
    }

    public static void MouseUp(string button) {
        string b = (button ?? "left").ToLowerInvariant();
        uint up = b == "right" ? MOUSEEVENTF_RIGHTUP : (b == "middle" ? MOUSEEVENTF_MIDDLEUP : MOUSEEVENTF_LEFTUP);
        Mouse(up);
    }

    public static void Scroll(int horizontal, int vertical) {
        if (vertical != 0) Mouse(MOUSEEVENTF_WHEEL, -vertical);
        if (horizontal != 0) Mouse(MOUSEEVENTF_HWHEEL, horizontal);
    }

    public static void TypeText(string text, int delayMs) {
        if (text == null) return;
        foreach (char c in text) {
            INPUT down = new INPUT(); down.type = INPUT_KEYBOARD;
            down.U.ki = new KEYBDINPUT { wScan = c, dwFlags = KEYEVENTF_UNICODE };
            INPUT up = down; up.U.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
            SendInput(2, new INPUT[] { down, up }, Marshal.SizeOf(typeof(INPUT)));
            if (delayMs > 0) Thread.Sleep(delayMs);
        }
    }

    static byte KeyCode(string name) {
        if (String.IsNullOrEmpty(name)) return 0;
        string k = name.Trim().ToUpperInvariant().Replace("_", "").Replace(" ", "");
        var map = new Dictionary<string, byte> {
            {"CTRL",0x11},{"CONTROL",0x11},{"ALT",0x12},{"SHIFT",0x10},
            {"META",0x5B},{"WIN",0x5B},{"WINDOWS",0x5B},{"ENTER",0x0D},
            {"RETURN",0x0D},{"TAB",0x09},{"ESC",0x1B},{"ESCAPE",0x1B},
            {"BACKSPACE",0x08},{"DELETE",0x2E},{"DEL",0x2E},{"SPACE",0x20},
            {"HOME",0x24},{"END",0x23},{"PAGEUP",0x21},{"PAGEDOWN",0x22},
            {"ARROWLEFT",0x25},{"LEFT",0x25},{"ARROWUP",0x26},{"UP",0x26},
            {"ARROWRIGHT",0x27},{"RIGHT",0x27},{"ARROWDOWN",0x28},{"DOWN",0x28},
            {"F1",0x70},{"F2",0x71},{"F3",0x72},{"F4",0x73},{"F5",0x74},
            {"F6",0x75},{"F7",0x76},{"F8",0x77},{"F9",0x78},{"F10",0x79},
            {"F11",0x7A},{"F12",0x7B}
        };
        if (map.ContainsKey(k)) return map[k];
        if (k.Length == 1) {
            short value = VkKeyScan(k[0]);
            if (value != -1) return (byte)(value & 0xff);
        }
        return 0;
    }

    public static void KeyPress(string[] keys) {
        if (keys == null || keys.Length == 0) return;
        var codes = new List<byte>();
        foreach (string key in keys) { byte code = KeyCode(key); if (code != 0) codes.Add(code); }
        foreach (byte code in codes) { keybd_event(code, 0, 0, UIntPtr.Zero); Thread.Sleep(18); }
        codes.Reverse();
        foreach (byte code in codes) { keybd_event(code, 0, KEYEVENTF_KEYUP, UIntPtr.Zero); Thread.Sleep(18); }
    }
}
'@

Add-Type -TypeDefinition $nativeCode -Language CSharp
[NguyeensNativeInput]::EnableDpiAwareness() | Out-Null

function Add-Log {
    param([string]$Text)
    $entry = ('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text)
    $script:Logs.Add($entry)
    while ($script:Logs.Count -gt 80) { $script:Logs.RemoveAt(0) }

    if ($ConsoleMode) {
        if ($Text -match 'Chuot that' -or $Text -match 'Ban phim that') {
            Write-Host "  [10 FPS] $Text" -ForegroundColor Cyan
        } elseif ($Text -match 'Gemini:') {
            Write-Host "  [AI Suy nghi] $Text" -ForegroundColor Yellow
        } elseif ($Text -match 'Hoan thanh' -or $Text -match 'Thanh cong') {
            Write-Host "  [HOAN THANH] $Text" -ForegroundColor Green
        } elseif ($Text -match 'Loi' -or $Text -match 'Error') {
            Write-Host "  [LOI] $Text" -ForegroundColor Red
        } else {
            Write-Host "  [10 FPS] $Text" -ForegroundColor DarkGray
        }
    }
}

function Write-Status {
    param([string]$State, [string]$Message, [int]$Step = 0, [string]$Result = '')
    $value = [pscustomobject]@{
        state=$State; message=$Message; step=$Step; result=$Result
        logs=@($script:Logs); updated_at=(Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 8
    $temp = "$StatusPath.tmp"
    [IO.File]::WriteAllText($temp, $value, [Text.Encoding]::UTF8)
    Move-Item -Path $temp -Destination $StatusPath -Force
}

function Test-Stop {
    if (Test-Path $StopPath) { throw [OperationCanceledException]::new('Da dung theo yeu cau cua ban.') }
    if ([NguyeensNativeInput]::IsEmergencyStopPressed()) {
        throw [OperationCanceledException]::new('DUNG KHAN CAP: Da nhan to hop phim Ctrl + Fn + E!')
    }
    $point = New-Object NguyeensNativeInput+POINT
    if ([NguyeensNativeInput]::GetCursorPos([ref]$point)) {
        if ($point.X -le 1 -and $point.Y -le 1) {
            throw [OperationCanceledException]::new('Da dung vi chuot duoc dua vao goc tren ben trai (0, 0).')
        }
    }
}

function Capture-Screen {
    $screen = [Windows.Forms.Screen]::PrimaryScreen
    $bounds = $screen.Bounds
    $script:VirtualLeft = $bounds.Left
    $script:VirtualTop = $bounds.Top
    $script:VirtualWidth = $bounds.Width
    $script:VirtualHeight = $bounds.Height
    $bitmap = New-Object Drawing.Bitmap($bounds.Width, $bounds.Height, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $ms = New-Object IO.MemoryStream
    try {
        $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bounds.Size, [Drawing.CopyPixelOperation]::SourceCopy)
        
        # High-speed in-memory JPEG compression (quality 62) - ultra lightweight (~90-130KB) and razor sharp
        $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
        if ($codec) {
            $ep = New-Object Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]62)
            $bitmap.Save($ms, $codec, $ep)
            $script:ImageMimeType = 'image/jpeg'
        } else {
            $bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
            $script:ImageMimeType = 'image/jpeg'
        }

        # Fast preview update (zero PNG overhead)
        try {
            $bytes = $ms.ToArray()
            [IO.File]::WriteAllBytes($ScreenPath, $bytes)
            return [Convert]::ToBase64String($bytes)
        } catch {
            return [Convert]::ToBase64String($ms.ToArray())
        }
    } finally {
        $ms.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}

function Get-Secret {
    $path = Join-Path $DataDir 'secret.txt'
    $secure = Get-Content -Raw $path | ConvertTo-SecureString
    return (New-Object Net.NetworkCredential('', $secure)).Password
}

function Get-Settings {
    $path = Join-Path $DataDir 'settings.json'
    if (Test-Path $path) {
        try {
            $s = Get-Content -Raw $path | ConvertFrom-Json
            if ($s.model -match 'gemini-2\.' -or $s.model -match 'gemini-1\.' -or $s.model -eq 'gemini-3.6-flash' -or $s.model -eq 'gemini-3.8-flash') {
                $s.model = 'gemini-3.5-flash-lite'
            }
            return $s
        } catch {}
    }
    return [pscustomobject]@{ model='gemini-3.5-flash-lite'; max_steps=30; typing_delay_ms=18 }
}

function Invoke-Gemini {
    param($Model, $Contents, $SystemPrompt, [string]$ApiKey)

    $cleanModel = if ($Model -and $Model -notmatch 'gemini-2\.' -and $Model -notmatch 'gemini-1\.' -and $Model -ne 'gemini-3.6-flash' -and $Model -ne 'gemini-3.8-flash') { $Model } else { 'gemini-3.5-flash-lite' }
    # Ultra-responsive models first (gemini-3.5-flash-lite responds in ~1.5s, no timeout), with smart automatic fallback
    $candidates = @($cleanModel, 'gemini-3.5-flash-lite', 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-3-flash-preview', 'gemini-3.7-flash', 'gemini-flash-latest', 'gemini-3.8-flash') | Select-Object -Unique

    foreach ($candidate in $candidates) {
        try {
            Test-Stop
            $url = "https://generativelanguage.googleapis.com/v1beta/models/${candidate}:generateContent?key=${ApiKey}"
            $payload = [ordered]@{
                contents = $Contents
                generationConfig = @{
                    temperature = 0.2
                    responseMimeType = "application/json"
                }
            }
            if ($SystemPrompt) {
                $payload['systemInstruction'] = @{
                    parts = @( @{ text = $SystemPrompt } )
                }
            }

            $json = $payload | ConvertTo-Json -Depth 30 -Compress
            $bytes = [Text.Encoding]::UTF8.GetBytes($json)

            $headers = @{
                'Content-Type' = 'application/json; charset=utf-8'
                'User-Agent' = 'NguyeensAI-Gemini/3.0'
            }

            # 65 seconds generous timeout so slow connections don't drop, with auto-failover on timeout
            $res = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $bytes -TimeoutSec 65
            if ($candidate -ne $Model) {
                Add-Log "Ket noi thanh cong voi mo hinh: $candidate"
            }
            return @{ Response = $res; Model = $candidate }
        } catch {
            Test-Stop
            $errStr = $_.Exception.Message
            $is503 = $errStr -match '503' -or $errStr -match 'Unavailable'
            $is429 = $errStr -match '429' -or $errStr -match 'RESOURCE_EXHAUSTED'
            $is404 = $errStr -match '404' -or $errStr -match 'Not Found'
            $isTimeout = $errStr -match 'timed out' -or $errStr -match 'Timeout'

            if ($candidate -ne $candidates[-1] -and ($is503 -or $is429 -or $is404 -or $isTimeout)) {
                $candArr = @($candidates)
                $idx = $candArr.IndexOf($candidate)
                $next = if ($idx -ge 0 -and ($idx + 1) -lt $candArr.Count) { $candArr[$idx + 1] } else { 'du phong' }
                if ($isTimeout) {
                    Add-Log "Mo hinh $candidate phan hoi qua cham (timed out). Tu dong chuyen sang mo hinh sieu toc $next..."
                } else {
                    Add-Log "Mo hinh $candidate gap su co ($errStr). Chuyen ngay sang $next..."
                }
                continue
            }
            throw $_
        }
    }
}

function ConvertTo-ScreenPixels {
    param($CoordX, $CoordY)
    
    $rawX = [double]$CoordX
    $rawY = [double]$CoordY

    # Normalized 0..1000 coordinate system (Google Vision standard) vs raw physical pixels
    $px = 0
    $py = 0
    if ($rawX -gt 1000 -or $rawY -gt 1000) {
        # Raw pixel fallback if model ever outputs direct pixel values > 1000
        $px = [int]$rawX
        $py = [int]$rawY
    } else {
        # Google standard 0..1000 normalized grid: mapped to real physical monitor pixels
        $px = [int](($rawX / 1000.0) * $script:VirtualWidth)
        $py = [int](($rawY / 1000.0) * $script:VirtualHeight)
    }

    # Clamp strictly within monitor boundary and apply physical monitor offsets
    $finalX = [Math]::Max(0, [Math]::Min($script:VirtualWidth - 1, $px)) + $script:VirtualLeft
    $finalY = [Math]::Max(0, [Math]::Min($script:VirtualHeight - 1, $py)) + $script:VirtualTop
    return @{ X = $finalX; Y = $finalY; NormX = [Math]::Round($rawX, 1); NormY = [Math]::Round($rawY, 1) }
}

function Move-CursorSmooth {
    param([int]$TargetX, [int]$TargetY)
    $point = New-Object NguyeensNativeInput+POINT
    [NguyeensNativeInput]::GetCursorPos([ref]$point) | Out-Null

    $startX = $point.X
    $startY = $point.Y
    $dist = [Math]::Sqrt([Math]::Pow($TargetX - $startX, 2) + [Math]::Pow($TargetY - $startY, 2))
    
    if ($dist -lt 3) {
        [NguyeensNativeInput]::MoveTo($TargetX, $TargetY)
        return
    }

    # 10 FPS smooth, purposeful glide: dynamic steps with cubic ease-out deceleration
    $steps = [Math]::Max(6, [Math]::Min(20, [int]($dist / 30)))
    $stepDelay = [Math]::Max(4, [Math]::Min(12, [int](180 / $steps)))

    for ($i = 1; $i -le $steps; $i++) {
        Test-Stop
        # Cubic ease-out: rapid acceleration from origin, gentle precision landing at target
        $t = [double]$i / $steps
        $ease = 1.0 - [Math]::Pow(1.0 - $t, 3)
        $nx = [int]($startX + (($TargetX - $startX) * $ease))
        $ny = [int]($startY + (($TargetY - $startY) * $ease))
        [NguyeensNativeInput]::MoveTo($nx, $ny)
        Start-Sleep -Milliseconds $stepDelay
    }
    [NguyeensNativeInput]::MoveTo($TargetX, $TargetY)
}

function Execute-Action {
    param($Action, [int]$TypingDelay)
    Test-Stop
    $type = [string]$Action.type
    switch ($type) {
        'click' {
            $pos = ConvertTo-ScreenPixels $Action.x $Action.y
            Move-CursorSmooth $pos.X $pos.Y
            Start-Sleep -Milliseconds 45
            [NguyeensNativeInput]::Click([string]$Action.button)
            Add-Log "Chuot that: Di chuyen chinh xac toi pixel ($($pos.X), $($pos.Y)) [toan cuc 0-1000: $($pos.NormX), $($pos.NormY)] va nhap chuot $($Action.button)."
        }
        'double_click' {
            $pos = ConvertTo-ScreenPixels $Action.x $Action.y
            Move-CursorSmooth $pos.X $pos.Y
            Start-Sleep -Milliseconds 45
            [NguyeensNativeInput]::DoubleClick([string]$Action.button)
            Add-Log "Chuot that: Di chuyen chinh xac toi pixel ($($pos.X), $($pos.Y)) [toan cuc 0-1000: $($pos.NormX), $($pos.NormY)] va nhap dup."
        }
        'move' {
            $pos = ConvertTo-ScreenPixels $Action.x $Action.y
            Move-CursorSmooth $pos.X $pos.Y
            Add-Log "Chuot that: Di chuyen toi pixel ($($pos.X), $($pos.Y)) [toan cuc 0-1000: $($pos.NormX), $($pos.NormY)]."
        }
        'drag' {
            $path = @($Action.path)
            if ($path.Count -gt 0) {
                $first = ConvertTo-ScreenPixels $path[0].x $path[0].y
                Move-CursorSmooth $first.X $first.Y
                [NguyeensNativeInput]::MouseDown('left')
                try {
                    foreach ($p in $path) {
                        $pt = ConvertTo-ScreenPixels $p.x $p.y
                        Move-CursorSmooth $pt.X $pt.Y
                    }
                }
                finally { [NguyeensNativeInput]::MouseUp('left') }
                Add-Log 'Chuot that: Keo tha chinh xac theo toa do.'
            }
        }
        'scroll' {
            if ($null -ne $Action.x -and $null -ne $Action.y) {
                $pos = ConvertTo-ScreenPixels $Action.x $Action.y
                Move-CursorSmooth $pos.X $pos.Y
            }
            $sx = if ($null -ne $Action.scroll_x) {[int]$Action.scroll_x} elseif ($null -ne $Action.delta_x) {[int]$Action.delta_x} else {0}
            $sy = if ($null -ne $Action.scroll_y) {[int]$Action.scroll_y} elseif ($null -ne $Action.delta_y) {[int]$Action.delta_y} else {0}
            [NguyeensNativeInput]::Scroll($sx,$sy)
            Add-Log "Cuon man hinh: $sy."
        }
        'keypress' {
            $keys = @($Action.keys | ForEach-Object {[string]$_})
            [NguyeensNativeInput]::KeyPress([string[]]$keys)
            Add-Log ('Ban phim that: Bam phim: ' + ($keys -join ' + ') + '.')
        }
        'type' {
            if ($null -ne $Action.x -and $null -ne $Action.y) {
                $pos = ConvertTo-ScreenPixels $Action.x $Action.y
                Move-CursorSmooth $pos.X $pos.Y
                Start-Sleep -Milliseconds 40
                [NguyeensNativeInput]::Click('left')
                Start-Sleep -Milliseconds 60
            }
            $text = [string]$Action.text
            [NguyeensNativeInput]::TypeText($text, $TypingDelay)
            Add-Log "Ban phim that: Da go $($text.Length) ky tu."
        }
        'wait' {
            $ms = if ($Action.ms) {[Math]::Min([int]$Action.ms,5000)} else {600}
            $waited = 0
            while ($waited -lt $ms) {
                Test-Stop
                $slice = [Math]::Min(30, $ms - $waited)
                Start-Sleep -Milliseconds $slice
                $waited += $slice
            }
            Add-Log "Cho $ms mili giay."
        }
        'screenshot' { Add-Log 'Gemini yeu cau chup lai man hinh.' }
        default { throw "Thao tac chua duoc ho tro: $type" }
    }
    Start-Sleep -Milliseconds 60
    Test-Stop
}

try {
    $promptImageBase64 = $null
    $promptImageMime = 'image/jpeg'

    if (-not [string]::IsNullOrWhiteSpace($TaskText)) {
        $task = $TaskText
        if ($ImagePath -and (Test-Path $ImagePath)) {
            $rawBytes = [IO.File]::ReadAllBytes($ImagePath)
            $promptImageBase64 = [Convert]::ToBase64String($rawBytes)
            if ($ImagePath -match '\.png$') { $promptImageMime = 'image/png' }
            elseif ($ImagePath -match '\.webp$') { $promptImageMime = 'image/webp' }
        }
    } elseif ($TaskPath -and (Test-Path $TaskPath)) {
        $taskData = Get-Content -Raw $TaskPath | ConvertFrom-Json
        $task = [string]$taskData.task
        if ($taskData.image_base64) {
            $promptImageBase64 = [string]$taskData.image_base64
            if ($taskData.image_mime) { $promptImageMime = [string]$taskData.image_mime }
        }
    } else {
        throw 'Khong tim thay noi dung cong viec can thuc hien.'
    }

    $settings = Get-Settings
    $apiKey = Get-Secret
    $model = [string]$settings.model
    if ([string]::IsNullOrWhiteSpace($model) -or $model -match 'gemini-2\.' -or $model -match 'gemini-1\.' -or $model -eq 'gemini-3.6-flash' -or $model -eq 'gemini-3.8-flash') { $model = 'gemini-3.5-flash-lite' }
    $maxSteps = if ($settings.max_steps) {[Math]::Min([int]$settings.max_steps,50)} else {30}
    $typingDelay = if ($settings.typing_delay_ms) {[Math]::Max([int]$settings.typing_delay_ms,10)} else {18}
    $stepDelay = if ($settings.step_delay_ms) {[Math]::Max([int]$settings.step_delay_ms,50)} else {100}

    Add-Log "Khoi dong Gemini 3.5 Flash Vision voi toc do phan hoi 10 FPS lien tuc."
    Add-Log "Kich hoat chuot vat ly va ban phim that tren Windows (Nhan Ctrl+Fn+E de dung khan cap)."

    # Kiem tra phan hoi chuot vat ly tuc thi (nhich nhe 10px va tra ve vi tri cu)
    try {
        $pt = New-Object NguyeensNativeInput+POINT
        if ([NguyeensNativeInput]::GetCursorPos([ref]$pt)) {
            [NguyeensNativeInput]::MoveTo($pt.X + 12, $pt.Y)
            Start-Sleep -Milliseconds 40
            [NguyeensNativeInput]::MoveTo($pt.X, $pt.Y)
            Add-Log "Chuot vat ly da ket noi thanh cong va san sang dieu khien."
        }
    } catch {}

    $initialBase64 = Capture-Screen
    Write-Status 'running' 'Gemini dang quan sat man hinh (10 FPS).' 0

    $systemInstruction = @"
You are an autonomous AI operating on the user's real Windows desktop computer.
Your job is to carry out the user's request by observing screenshots and issuing precise mouse and keyboard actions.

COORDINATE SYSTEM (CRITICAL - GOOGLE VISION 0-1000 NORMALIZED SCALE):
All mouse coordinates ('x' and 'y') MUST be specified on the normalized 0 to 1000 scale:
- x: 0 is the extreme LEFT edge of the screen, 1000 is the extreme RIGHT edge. (Horizontal center is 500).
- y: 0 is the extreme TOP edge of the screen, 1000 is the extreme BOTTOM edge. (Vertical center is 500).
- Physical display resolution: $($script:VirtualWidth)x$($script:VirtualHeight) pixels.
The host system automatically converts these [0..1000] values into the exact physical pixel location.

LASER-PRECISION TARGETING RULES:
1. When you want to click a button, link, tab, input box, or icon:
   - Identify the exact visual bounding box of the target element in the screenshot.
   - Output the EXACT center point (x, y) of that bounding box in the 0..1000 grid.
   - Example 1: Windows Start button (bottom-left) is around x: 20..30, y: 975.
   - Example 2: Browser tabs at top are around y: 40..50.
   - Example 3: Browser URL bar is around y: 80..85.
   - Example 4: Taskbar at the bottom of the screen is around y: 970..990.
   - Example 5: Chat input field at bottom of a chat window is located near the bottom of that window.
2. DO NOT confuse adjacent elements:
   - Align your 'thought' description directly with your coordinates. If you say you are clicking the send button, your (x, y) must point directly at the send button icon.
3. If an element or window is in the background or minimized:
   - First click its icon on the taskbar (at y ~ 975) or press ["alt", "tab"] to bring it to the foreground.

RULES FOR ACTIONS:
- To click: {"type":"click", "x":X, "y":Y, "button":"left"} (where X and Y are in 0..1000).
- To double click: {"type":"double_click", "x":X, "y":Y, "button":"left"}.
- To type text: issue {"type":"type", "text":"Your text here"}. (You can also provide "x" and "y" to click the input field first!).
- To press keyboard keys: {"type":"keypress", "keys":["enter"]} or {"type":"keypress", "keys":["ctrl", "a"]}.
- To wait for UI to update: {"type":"wait", "ms": 500}.

MANDATORY ACTION EXECUTION:
- You MUST generate at least one active action on every step. NEVER return empty actions [] if task is running!
- If the requested app or chatbot (like EduNext) is open on the screen, locate the message/task, click into the answer field, and type the required response, then press Enter or click Send.
- Set status="running" while working, and status="done" when finished.

SAFETY & ETHICAL BOUNDARIES (MANDATORY):
- Never read, inspect, store, or type passwords, PIN codes, OTPs, or credit card details.
- Never confirm financial transactions or delete important files.
- If an action requires entering sensitive credentials or confirming destructive changes, immediately set status="needs_user" with a helpful explanation.
- When the requested task is completely accomplished, set status="done" with a clear Vietnamese result summary.

OUTPUT FORMAT:
You MUST respond with a JSON object matching this schema:
{
  "thought": "Quan sat cu the vi tri phan tu tren man hinh va ke hoach thao tac (Tieng Viet)",
  "actions": [
    {
      "type": "click" | "double_click" | "move" | "drag" | "scroll" | "keypress" | "type" | "wait",
      "x": 500,
      "y": 500,
      "button": "left" | "right" | "middle",
      "keys": ["win"] | ["enter"],
      "text": "text string",
      "scroll_y": -120,
      "ms": 500
    }
  ],
  "status": "running" | "done" | "needs_user",
  "result": "Final message if done or reason if needs_user"
}
"@

    $history = New-Object Collections.Generic.List[object]

    for ($step=1; $step -le $maxSteps; $step++) {
        Test-Stop

        $screenBase64 = Capture-Screen
        Write-Status 'running' "Gemini dang quan sat man hinh (10 FPS - Buoc $step/$maxSteps)." $step

        $userPrompt = "Nhiem vu cua nguoi dung: $task`nBuoc hien tai: $step / $maxSteps.`nLuu y toa do: Hay quan sat that ky anh man hinh, xac dinh dung vi tri phan tu (tam nut bam, o nhap lieu, cua so can thao tac) va tra ve toa do tam (x, y) tren thang do chuan hoa tu 0 den 1000 (x: 0..1000, y: 0..1000)."

        # Prepare multimodal request for Gemini (fast JPEG in-memory for 10 FPS continuous streaming)
        $mime = if ($script:ImageMimeType) { $script:ImageMimeType } else { 'image/jpeg' }
        $parts = New-Object Collections.Generic.List[object]
        $parts.Add(@{ text = $userPrompt })
        $parts.Add(@{
            inlineData = @{
                mimeType = $mime
                data = $screenBase64
            }
        })

        if ($promptImageBase64) {
            $parts.Add(@{ text = "Hinh anh dinh kem boi nguoi dung (Attached user reference image):" })
            $parts.Add(@{
                inlineData = @{
                    mimeType = $promptImageMime
                    data = $promptImageBase64
                }
            })
        }

        $contents = @(
            @{
                role = 'user'
                parts = @($parts)
            }
        )

        $geminiResult = Invoke-Gemini -Model $model -Contents $contents -SystemPrompt $systemInstruction -ApiKey $apiKey
        $response = $geminiResult.Response
        if ($geminiResult.Model -and $geminiResult.Model -ne $model) {
            $model = $geminiResult.Model
            try {
                $settings.model = $model
                $settings | ConvertTo-Json | Set-Content -Path (Join-Path $DataDir 'settings.json') -Encoding UTF8
            } catch {}
        }

        $rawText = $response.candidates[0].content.parts[0].text
        # Strip potential markdown code fences if present
        $cleanJson = $rawText.Trim()
        if ($cleanJson.StartsWith('```')) {
            $cleanJson = $cleanJson -replace '^```[a-zA-Z]*\r?\n', ''
            $cleanJson = $cleanJson -replace '\r?\n```$', ''
            $cleanJson = $cleanJson.Trim()
        }

        $plan = $cleanJson | ConvertFrom-Json

        if ($plan.thought) {
            Add-Log ("Gemini: " + [string]$plan.thought)
        }

        # 1. ALWAYS execute actions first if provided by Gemini
        $rawActions = if ($plan.actions) { $plan.actions } elseif ($plan.action) { $plan.action } else { $null }
        $actions = @($rawActions)

        if ($actions.Count -gt 0) {
            Write-Status 'running' "Dang thuc thi $($actions.Count) thao tac o buoc $step..." $step
            foreach ($action in $actions) {
                Execute-Action $action $typingDelay
            }
        }

        # 2. Handle needs_user
        if ($plan.status -eq 'needs_user') {
            Add-Log 'AI yeu cau nguoi dung tu can thiep do thao tac nhay cam.'
            Write-Status 'needs_user' ([string]$plan.result) $step
            exit 0
        }

        # 3. Handle completion
        if ($plan.status -eq 'done') {
            if ($actions.Count -gt 0) {
                Start-Sleep -Milliseconds 350
            }
            $answer = if ($plan.result) { [string]$plan.result } else { 'Nhiem vu da hoan tat thanh cong.' }
            Add-Log ("Hoan thanh: " + $answer)
            Capture-Screen | Out-Null
            Write-Status 'done' 'Da hoan thanh nhiem vu.' $step $answer
            exit 0
        }

        # 4. If no actions were given and not done, continue observing
        if ($actions.Count -eq 0) {
            Add-Log "Khong co hanh dong nao duoc dua ra o buoc nay, dang tiep tuc quan sat..."
            $waited = 0
            while ($waited -lt $stepDelay) {
                Test-Stop
                $slice = [Math]::Min(30, $stepDelay - $waited)
                Start-Sleep -Milliseconds $slice
                $waited += $slice
            }
            continue
        }

        # Continuous 10 FPS cycle between steps (sliced with Test-Stop)
        $waited = 0
        while ($waited -lt $stepDelay) {
            Test-Stop
            $slice = [Math]::Min(30, $stepDelay - $waited)
            Start-Sleep -Milliseconds $slice
            $waited += $slice
        }
    }

    Add-Log "Da dung khi dat gioi han an toan $maxSteps buoc."
    Write-Status 'stopped' "Da dat gioi han an toan $maxSteps buoc." $maxSteps
} catch [OperationCanceledException] {
    $cancelMsg = $_.Exception.Message
    Add-Log $cancelMsg
    if ($ConsoleMode) {
        Write-Host ""
        Write-Host "  ==========================================================" -ForegroundColor Red
        Write-Host "  [DUNG KHAN CAP] $cancelMsg" -ForegroundColor Yellow
        Write-Host "  Da ngat toan bo thao tac chuot va ban phim that an toan." -ForegroundColor Green
        Write-Host "  ==========================================================" -ForegroundColor Red
        Write-Host ""
    }
    Write-Status 'stopped' $cancelMsg 0
} catch {
    $message = $_.Exception.Message
    if ($message -match '400' -or $message -match '403' -or $message -match 'API_KEY_INVALID') {
        $message = 'Gemini API key khong hop le hoac tai khoan chua kich hoat Generative Language API (HTTP 400/403).'
    } elseif ($message -match '429') {
        $message = 'Tai khoan Google Gemini da cham gioi han toc do hoac han muc truy van (Rate limit 429).'
    } elseif ($message -match '503' -or $message -match 'Unavailable') {
        $message = 'May chu Google Gemini dang qua tai tam thoi (HTTP 503). Vui long thu lai hoac dung mo hinh gemini-2.5-flash.'
    } elseif ($message -match 'model') {
        $message = 'Mo hinh Gemini duoc chi dinh khong kha dung cho khoa cua ban: ' + $message
    }
    Add-Log ('Loi: ' + $message)
    Write-Status 'error' $message 0
} finally {
    Remove-Item (Join-Path $DataDir 'worker.pid') -Force -ErrorAction SilentlyContinue
}