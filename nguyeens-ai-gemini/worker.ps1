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
    [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    public static double CursorCoordScale = 1.0;
    public static int PhysicalWidth = 1920;
    public static int PhysicalHeight = 1080;
    public static double DpiScaleFactor = 1.0;

    public static void EnableDpiAwareness() {
        try {
            // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
            SetProcessDpiAwarenessContext((IntPtr)(-4));
        } catch {
            try { SetProcessDPIAware(); } catch {}
        }
    }

    public static void DetectScreenDpiAndCalibrate() {
        IntPtr hdc = GetDC(IntPtr.Zero);
        try {
            int physW = GetDeviceCaps(hdc, 118); // DESKTOPHORZRES
            int physH = GetDeviceCaps(hdc, 117); // DESKTOPVERTRES
            int logW = GetDeviceCaps(hdc, 8);    // HORZRES
            int logH = GetDeviceCaps(hdc, 10);   // VERTRES

            if (physW <= 0 || physH <= 0) {
                physW = GetSystemMetrics(0); // SM_CXSCREEN
                physH = GetSystemMetrics(1); // SM_CYSCREEN
                logW = physW;
                logH = physH;
            }

            PhysicalWidth = physW;
            PhysicalHeight = physH;
            DpiScaleFactor = (logW > 0 && physW > 0) ? ((double)physW / logW) : 1.0;

            // Calibrate cursor coordinate mapping
            POINT orig;
            if (GetCursorPos(out orig)) {
                int testX = Math.Min(physW - 30, 600);
                int testY = Math.Min(physH - 30, 400);
                SetCursorPos(testX, testY);
                POINT readBack;
                GetCursorPos(out readBack);
                SetCursorPos(orig.X, orig.Y);

                if (testX > 0 && readBack.X > 0) {
                    double ratio = (double)readBack.X / (double)testX;
                    if (Math.Abs(ratio - 1.0) > 0.05) {
                        CursorCoordScale = ratio;
                    } else {
                        CursorCoordScale = 1.0;
                    }
                }
            }
        } catch {
            CursorCoordScale = 1.0;
        } finally {
            if (hdc != IntPtr.Zero) ReleaseDC(IntPtr.Zero, hdc);
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
        int tx = (int)Math.Round(x * CursorCoordScale);
        int ty = (int)Math.Round(y * CursorCoordScale);
        SetCursorPos(tx, ty);
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

if (-not ([System.Management.Automation.PSTypeName]'NguyeensNativeInput').Type) {
    Add-Type -TypeDefinition $nativeCode -Language CSharp
}
[NguyeensNativeInput]::EnableDpiAwareness() | Out-Null
[NguyeensNativeInput]::DetectScreenDpiAndCalibrate() | Out-Null

$script:MemoryPath = Join-Path $DataDir 'memory.json'

# Từ khóa kích hoạt ghi nhớ "nhớ" (chỉ Tiếng Việt và Tiếng Anh)
$script:RememberPatterns = @(
    '\bnhớ\b', '\bnho\b', '\bghi nhớ\b', '\bghi nho\b', '\bhãy nhớ\b', '\bhay nho\b',
    '\bnhớ rằng\b', '\bnho rang\b', '\bnhớ là\b', '\bnho la\b', '\blưu ý\b', '\bluu y\b',
    '\bremember\b', '\bmemorize\b', '\bkeep in mind\b', '\bnote that\b', '\brecall\b', '\bsave rule\b'
)

# Từ khóa kích hoạt hành động "làm" (chỉ Tiếng Việt và Tiếng Anh)
$script:ActionPatterns = @(
    '\blàm\b', '\blam\b', '\bthực hiện\b', '\bthuc hien\b', '\bhãy làm\b', '\bhay lam\b',
    '\btiến hành\b', '\btien hanh\b', '\bxử lý\b', '\bxu ly\b', '\bthao tác\b', '\bthao tac\b', '\bchạy\b', '\bchay\b',
    '\bdo\b', '\bexecute\b', '\bperform\b', '\bmake\b', '\brun\b', '\bact\b', '\bcarry out\b'
)

function Test-HasRememberIntent([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $lower = $Text.ToLower()
    foreach ($pat in $script:RememberPatterns) {
        if ($lower -match $pat) { return $true }
    }
    return $false
}

function Test-HasActionIntent([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $lower = $Text.ToLower()
    foreach ($pat in $script:ActionPatterns) {
        if ($lower -match $pat) { return $true }
    }
    return $false
}

function Get-StoredMemories {
    if (Test-Path $script:MemoryPath) {
        try {
            $content = Get-Content -Raw $script:MemoryPath -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $arr = $content | ConvertFrom-Json
                return @($arr)
            }
        } catch {}
    }
    return @()
}

function Save-MemoryRule([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $existing = [System.Collections.Generic.List[object]]@(Get-StoredMemories)
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
        [IO.File]::WriteAllText($script:MemoryPath, $json, [Text.Encoding]::UTF8)
        Add-Log "MEMORY: Saved new rule into memory.json -> `"$clean`""
        return $newItem
    }
    return $null
}

function Add-Log {
    param([string]$Text)
    $entry = ('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text)
    $script:Logs.Add($entry)
    while ($script:Logs.Count -gt 80) { $script:Logs.RemoveAt(0) }

    if ($ConsoleMode) {
        if ($Text -match 'Physical mouse' -or $Text -match 'Physical keyboard') {
            Write-Host "  [10 FPS] $Text" -ForegroundColor Cyan
        } elseif ($Text -match 'Gemini:' -or $Text -match 'Thought') {
            Write-Host "  [AI Thought] $Text" -ForegroundColor Yellow
        } elseif ($Text -match 'MEMORY:') {
            Write-Host "  [MEMORY] $Text" -ForegroundColor Magenta
        } elseif ($Text -match 'Completed' -or $Text -match 'Success' -or $Text -match 'Done') {
            Write-Host "  [COMPLETED] $Text" -ForegroundColor Green
        } elseif ($Text -match 'Error' -or $Text -match 'Failed') {
            Write-Host "  [ERROR] $Text" -ForegroundColor Red
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
    if (Test-Path $StopPath) { throw [OperationCanceledException]::new('Đã dừng theo yêu cầu của bạn.') }
    if ([NguyeensNativeInput]::IsEmergencyStopPressed()) {
        throw [OperationCanceledException]::new('DỪNG KHẨN CẤP: Đã nhấn tổ hợp phím Ctrl + Fn + E!')
    }
    $point = New-Object NguyeensNativeInput+POINT
    if ([NguyeensNativeInput]::GetCursorPos([ref]$point)) {
        if ($point.X -le 1 -and $point.Y -le 1) {
            throw [OperationCanceledException]::new('Đã dừng vì chuột được đưa vào góc trên bên trái (0, 0).')
        }
    }
}

function Capture-Screen {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $w = if ([NguyeensNativeInput]::PhysicalWidth -gt 0) { [NguyeensNativeInput]::PhysicalWidth } else { $bounds.Width }
    $h = if ([NguyeensNativeInput]::PhysicalHeight -gt 0) { [NguyeensNativeInput]::PhysicalHeight } else { $bounds.Height }
    $script:VirtualLeft = $bounds.Left
    $script:VirtualTop = $bounds.Top
    $script:VirtualWidth = $w
    $script:VirtualHeight = $h
    $bitmap = New-Object Drawing.Bitmap($w, $h, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $ms = New-Object IO.MemoryStream
    try {
        $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, (New-Object Drawing.Size($w, $h)), [Drawing.CopyPixelOperation]::SourceCopy)
        
        # High-speed in-memory JPEG compression - safe standard .NET without ambiguous EncoderParameter overloads
        try {
            $bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
            $script:ImageMimeType = 'image/jpeg'
        } catch {
            $bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
            $script:ImageMimeType = 'image/png'
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
    if (Test-Path $path) {
        try {
            $raw = Get-Content -Raw $path -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $secure = $raw.Trim() | ConvertTo-SecureString
                $pass = (New-Object Net.NetworkCredential('', $secure)).Password
                if (-not [string]::IsNullOrWhiteSpace($pass)) { return $pass }
            }
        } catch {}
    }
    if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY }
    return $null
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
            $res = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $json -TimeoutSec 65
            if ($candidate -ne $Model) {
                Add-Log "Connected successfully to model: $candidate"
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
                $next = if ($idx -ge 0 -and ($idx + 1) -lt $candArr.Count) { $candArr[$idx + 1] } else { 'fallback' }
                if ($isTimeout) {
                    Add-Log "Model $candidate responded slowly (timed out). Automatically failing over to fast model $next..."
                } else {
                    Add-Log "Model $candidate encountered notice ($errStr). Switching to $next..."
                }
                continue
            }
            throw $_
        }
    }
}

function ConvertTo-ScreenPixels {
    param($CoordX, $CoordY, $Point = $null)
    
    $rawX = $null
    $rawY = $null

    if ($null -ne $CoordX -and [string]$CoordX -ne '' -and $null -ne $CoordY -and [string]$CoordY -ne '') {
        $rawX = [double]$CoordX
        $rawY = [double]$CoordY
    } elseif ($null -ne $Point) {
        $pArr = @($Point)
        if ($pArr.Count -ge 2) {
            # In standard Google Gemini Vision [y, x] normalized coordinates:
            $rawY = [double]$pArr[0]
            $rawX = [double]$pArr[1]
        }
    }

    if ($null -eq $rawX -or $null -eq $rawY) {
        $rawX = 500.0
        $rawY = 500.0
        Add-Log "Notice: Specific coordinates not found, centering mouse at (500, 500)."
    }

    # Normalized 0..1000 coordinate system (Google Vision standard) vs raw physical pixels
    $px = 0
    $py = 0
    if ($rawX -gt 1000 -or $rawY -gt 1000) {
        # Raw pixel fallback if model ever outputs direct pixel values > 1000
        $px = [int]$rawX
        $py = [int]$rawY
    } else {
        # Google standard 0..1000 normalized grid: mapped to real physical monitor pixels
        $px = [int][Math]::Round(($rawX / 1000.0) * $script:VirtualWidth)
        $py = [int][Math]::Round(($rawY / 1000.0) * $script:VirtualHeight)
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

    # Convert current cursor pos from logical space to physical monitor pixels
    $scale = [NguyeensNativeInput]::CursorCoordScale
    $startX = if ($scale -gt 0) { [int][Math]::Round($point.X / $scale) } else { $point.X }
    $startY = if ($scale -gt 0) { [int][Math]::Round($point.Y / $scale) } else { $point.Y }
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

    $actX = if ($null -ne $Action.x) { $Action.x } elseif ($null -ne $Action.X) { $Action.X } else { $null }
    $actY = if ($null -ne $Action.y) { $Action.y } elseif ($null -ne $Action.Y) { $Action.Y } else { $null }
    $actPoint = if ($null -ne $Action.point) { $Action.point } elseif ($null -ne $Action.coordinate) { $Action.coordinate } elseif ($null -ne $Action.coords) { $Action.coords } else { $null }

    switch ($type) {
        'click' {
            $pos = ConvertTo-ScreenPixels $actX $actY $actPoint
            Move-CursorSmooth $pos.X $pos.Y
            Start-Sleep -Milliseconds 45
            [NguyeensNativeInput]::Click([string]$Action.button)
            Add-Log "Physical mouse: Moved to ($($pos.X), $($pos.Y)) [norm: $($pos.NormX), $($pos.NormY)] and clicked $($Action.button)."
        }
        'double_click' {
            $pos = ConvertTo-ScreenPixels $actX $actY $actPoint
            Move-CursorSmooth $pos.X $pos.Y
            Start-Sleep -Milliseconds 45
            [NguyeensNativeInput]::DoubleClick([string]$Action.button)
            Add-Log "Physical mouse: Moved to ($($pos.X), $($pos.Y)) [norm: $($pos.NormX), $($pos.NormY)] and double-clicked."
        }
        'move' {
            $pos = ConvertTo-ScreenPixels $actX $actY $actPoint
            Move-CursorSmooth $pos.X $pos.Y
            Add-Log "Physical mouse: Moved to ($($pos.X), $($pos.Y)) [norm: $($pos.NormX), $($pos.NormY)]."
        }
        'drag' {
            $path = @($Action.path)
            if ($path.Count -gt 0) {
                $p0 = $path[0]
                $first = ConvertTo-ScreenPixels $p0.x $p0.y $p0.point
                Move-CursorSmooth $first.X $first.Y
                [NguyeensNativeInput]::MouseDown('left')
                try {
                    foreach ($p in $path) {
                        $pt = ConvertTo-ScreenPixels $p.x $p.y $p.point
                        Move-CursorSmooth $pt.X $pt.Y
                    }
                }
                finally { [NguyeensNativeInput]::MouseUp('left') }
                Add-Log 'Physical mouse: Drag and drop completed.'
            }
        }
        'scroll' {
            if ($null -ne $actX -or $null -ne $actPoint) {
                $pos = ConvertTo-ScreenPixels $actX $actY $actPoint
                Move-CursorSmooth $pos.X $pos.Y
            }
            $sx = if ($null -ne $Action.scroll_x) {[int]$Action.scroll_x} elseif ($null -ne $Action.delta_x) {[int]$Action.delta_x} else {0}
            $sy = if ($null -ne $Action.scroll_y) {[int]$Action.scroll_y} elseif ($null -ne $Action.delta_y) {[int]$Action.delta_y} else {0}
            [NguyeensNativeInput]::Scroll($sx,$sy)
            Add-Log "Screen scroll: $sy."
        }
        'keypress' {
            $keys = @($Action.keys | ForEach-Object {[string]$_})
            [NguyeensNativeInput]::KeyPress([string[]]$keys)
            Add-Log ('Physical keyboard: Pressed key(s): ' + ($keys -join ' + ') + '.')
        }
        'type' {
            if ($null -ne $actX -or $null -ne $actPoint) {
                $pos = ConvertTo-ScreenPixels $actX $actY $actPoint
                Move-CursorSmooth $pos.X $pos.Y
                Start-Sleep -Milliseconds 40
                [NguyeensNativeInput]::Click('left')
                Start-Sleep -Milliseconds 60
            }
            $text = [string]$Action.text
            [NguyeensNativeInput]::TypeText($text, $TypingDelay)
            Add-Log "Physical keyboard: Typed $($text.Length) character(s) in Vietnamese Unicode."
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
            Add-Log "Wait $ms ms."
        }
        'screenshot' { Add-Log 'Gemini requested screen re-capture.' }
        default { throw "Unsupported action: $type" }
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
        throw 'No task content found to execute.'
    }

    $settings = Get-Settings
    $apiKey = Get-Secret
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'No Gemini API key found. Please open run.bat and paste your API key to store it securely.'
    }
    $model = [string]$settings.model
    if ([string]::IsNullOrWhiteSpace($model) -or $model -match 'gemini-2\.' -or $model -match 'gemini-1\.' -or $model -eq 'gemini-3.6-flash' -or $model -eq 'gemini-3.8-flash') { $model = 'gemini-3.5-flash-lite' }
    $maxSteps = if ($settings.max_steps) {[Math]::Min([int]$settings.max_steps,50)} else {30}
    $typingDelay = if ($settings.typing_delay_ms) {[Math]::Max([int]$settings.typing_delay_ms,10)} else {18}
    $stepDelay = if ($settings.step_delay_ms) {[Math]::Max([int]$settings.step_delay_ms,50)} else {100}

    # Display resolution and Windows DPI scaling
    $screenW = if ([NguyeensNativeInput]::PhysicalWidth -gt 0) { [NguyeensNativeInput]::PhysicalWidth } else { $script:VirtualWidth }
    $screenH = if ([NguyeensNativeInput]::PhysicalHeight -gt 0) { [NguyeensNativeInput]::PhysicalHeight } else { $script:VirtualHeight }
    $dpiScale = [NguyeensNativeInput]::DpiScaleFactor
    $cursorScale = [NguyeensNativeInput]::CursorCoordScale
    Add-Log ("Desktop display: {0}x{1}px (DPI: {2:P0}, Cursor scale: {3:F2})" -f $screenW, $screenH, $dpiScale, $cursorScale)

    # PERSISTENT MEMORY PROCESSING (data/memory.json)
    $hasRememberIntent = Test-HasRememberIntent $task
    $hasActionIntent = Test-HasActionIntent $task

    if ($hasRememberIntent) {
        $savedMem = Save-MemoryRule $task
        if ($savedMem) {
            Add-Log "MEMORY: Detected 'remember' intent -> Saved new rule into data/memory.json."
        }
    }

    $allMemories = @(Get-StoredMemories)
    $memoryReinforcementText = ""

    if ($allMemories.Count -gt 0) {
        $memListText = ($allMemories | ForEach-Object { "- " + $_.text }) -join "`n"
        $memoryReinforcementText = @"

[PERSISTENT MEMORY FROM MEMORY.JSON]:
The user has previously established these persistent memory rules and preferences. You MUST enforce and reinforce these rules in your thought, actions, and output:
$memListText
"@
        if ($hasActionIntent) {
            Add-Log "MEMORY: Detected action intent -> Loaded $($allMemories.Count) rule(s) from memory.json to reinforce output."
        } else {
            Add-Log "MEMORY: Loaded $($allMemories.Count) rule(s) from memory.json into context."
        }
    }

    Add-Log "Starting Gemini 3.5 Flash Vision at 10 FPS continuous loop."
    Add-Log "Activated physical mouse and native keyboard on Windows (Press Ctrl+Fn+E for emergency stop)."

    # Test physical mouse responsiveness
    try {
        $pt = New-Object NguyeensNativeInput+POINT
        if ([NguyeensNativeInput]::GetCursorPos([ref]$pt)) {
            [NguyeensNativeInput]::MoveTo($pt.X + 12, $pt.Y)
            Start-Sleep -Milliseconds 40
            [NguyeensNativeInput]::MoveTo($pt.X, $pt.Y)
            Add-Log "Physical mouse connected successfully and ready for control."
        }
    } catch {}

    $initialBase64 = Capture-Screen
    Write-Status 'running' 'Gemini is observing desktop display (10 FPS).' 0

    $systemInstruction = @"
You are an autonomous AI operating on the user's real Windows desktop computer.
Your job is to carry out the user's request by observing screenshots and issuing precise mouse and keyboard actions.

LANGUAGE & KEYBOARD OUTPUT RULES:
- All reasoning thoughts ('thought') and status/result summaries must be written in English.
- KEYBOARD OUTPUT ('type' action): When typing text into applications via the physical keyboard (e.g., in Notepad, search boxes, forms, documents, chat), ALWAYS type in natural, grammatically correct Vietnamese with full accents/diacritics ('Tiếng Việt có dấu đầy đủ') whenever Vietnamese text, greetings, summaries, or content is requested or appropriate, using native UTF-16 Unicode keystrokes. Never produce unaccented Vietnamese ('tieng Viet khong dau'). If the user explicitly asks for English text, URLs, or code, type in English.
- All JSON schema keys ('thought', 'actions', 'type', 'x', 'y', 'button', 'keys', 'text', 'scroll_y', 'ms', 'status', 'result') MUST ALWAYS remain in English.

COORDINATE SYSTEM & LASER-PRECISION TARGETING (0-1000 NORMALIZED SCALE):
All mouse coordinates ('x' and 'y') MUST be specified on the normalized 0 to 1000 scale:
- x: 0 is the extreme LEFT edge of the screen, 1000 is the extreme RIGHT edge. (Horizontal center is 500).
- y: 0 is the extreme TOP edge of the screen, 1000 is the extreme BOTTOM edge. (Vertical center is 500).
- Physical display resolution: $($script:VirtualWidth)x$($script:VirtualHeight) pixels.
The host system automatically converts these [0..1000] values into the exact physical pixel location.

CRITICAL COORDINATE GROUNDING CONSTRAINT (PREVENTS MOUSE MISMATCH):
To ensure the mouse lands exactly where you intended (preventing any coordinate drift between thinking and clicking):
1. In the 'thought' field, you MUST first state the spatial grounding target before explaining the action:
   Format: [Target: <element name>, Est: (x=..., y=...), Action: <click/type/etc.>]
   Example: "[Target: Notepad editor, Est: (x=500, y=380), Action: type] I will click into the text editor and type the greeting in Vietnamese."
2. The coordinates 'x' and 'y' in the 'actions' array MUST EXACTLY match the estimated coordinates stated in your 'thought'!
3. TARGET THE DEAD CENTER of the visual element (button, link, input box, icon), never the extreme border.
4. COORDINATE AXIS CLARITY:
   - 'x' is HORIZONTAL (left-to-right). NEVER put vertical coordinates in 'x'.
   - 'y' is VERTICAL (top-to-bottom). NEVER put horizontal coordinates in 'y'.
$memoryReinforcementText
RULES FOR ACTIONS:
- To click: {"type":"click", "x":X, "y":Y, "button":"left"} (where X and Y are in 0..1000).
- To double click: {"type":"double_click", "x":X, "y":Y, "button":"left"}.
- To type text: issue {"type":"type", "text":"Your text here", "x":X, "y":Y} (clicks input field first, then types text).
- To press keyboard keys: {"type":"keypress", "keys":["enter"]} or {"type":"keypress", "keys":["ctrl", "a"]}.
- To wait for UI to update: {"type":"wait", "ms": 500}.

MANDATORY ACTION EXECUTION:
- You MUST generate at least one active action on every step. NEVER return empty actions [] if task is running!
- If the user's prompt was purely a memory instruction (e.g. remember a fact or rule) and requires no screen interaction, confirm what you remembered in 'thought' and 'result' in accented Vietnamese or English and set status="done".
- If the requested app or chatbot (like EduNext) is open on the screen, locate the message/task, click into the answer field, and type the required response, then press Enter or click Send.
- Set status="running" while working, and status="done" when finished.

SAFETY & ETHICAL BOUNDARIES (MANDATORY):
- Never read, inspect, store, or type passwords, PIN codes, OTPs, or credit card details.
- Never confirm financial transactions or delete important files.
- If an action requires entering sensitive credentials or confirming destructive changes, immediately set status="needs_user" with a helpful explanation in accented Vietnamese or English.
- When the requested task is completely accomplished, set status="done" with a clear result summary in accented Vietnamese or English.

OUTPUT FORMAT:
You MUST respond with a JSON object matching this schema:
{
  "thought": "[Target: <element>, Est: (x=..., y=...)] Observation and plan in the user's language",
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
  "result": "Final message if done or reason if needs_user in the user's language"
}

CRITICAL JSON SYNTAX:
- Only output strictly valid RFC 8259 JSON.
- In 'thought', write equations with plain text (e.g. 'x^3 - 3*x^2*2' or 'a = x, b = 2'). NEVER use LaTeX backslashes (\cdot, \frac, \times, \alpha) as backslashes break JSON parsers.
- Do NOT use unescaped backslashes (\) anywhere in strings.
"@

    function Parse-GeminiJson {
        param([string]$RawText)

        if ([string]::IsNullOrWhiteSpace($RawText)) {
            return $null
        }

        # 1. Strip markdown code fences (```json ... ``` or ``` ...)
        $text = $RawText.Trim()
        if ($text -match '(?s)```(?:json)?\s*(.*?)\s*```') {
            $text = $matches[1].Trim()
        } elseif ($text.StartsWith('```')) {
            $text = $text -replace '^```[a-zA-Z]*\r?\n', ''
            $text = $text -replace '\r?\n```$', ''
            $text = $text.Trim()
        }

        # Find boundaries if there is text before { or after }
        $firstBrace = $text.IndexOf('{')
        $lastBrace = $text.LastIndexOf('}')
        if ($firstBrace -ge 0 -and $lastBrace -gt $firstBrace) {
            $text = $text.Substring($firstBrace, $lastBrace - $firstBrace + 1)
        }

        # Attempt 1: Direct JSON parse
        try {
            return ($text | ConvertFrom-Json)
        } catch {}

        # Attempt 2: Auto-repair backslashes (e.g. \cdot, \times, \frac, \sqrt, C:\Users...)
        try {
            $repaired = [regex]::Replace($text, '\\(?!["\\/bfnrt]|u[0-9a-fA-F]{4})', '\\\\')
            return ($repaired | ConvertFrom-Json)
        } catch {}

        # Attempt 3: Aggressive string repair in thought
        try {
            $thoughtFixed = [regex]::Replace($text, '(?<="thought"\s*:\s*")(?s)(.*?)(?=",\s*"(?:actions|status|action))', {
                param($m)
                return ($m.Groups[1].Value -replace '\\', '\\')
            })
            return ($thoughtFixed | ConvertFrom-Json)
        } catch {}

        # Attempt 4: Direct fallback extraction of actions array and status
        try {
            $actions = @()
            if ($text -match '(?s)"actions"\s*:\s*(\[\s*\{.*?\}\s*\])') {
                $actionsRaw = $matches[1]
                try {
                    $actions = @($actionsRaw | ConvertFrom-Json)
                } catch {
                    $repairedActions = [regex]::Replace($actionsRaw, '\\(?!["\\/bfnrt]|u[0-9a-fA-F]{4})', '\\\\')
                    $actions = @($repairedActions | ConvertFrom-Json)
                }
            } elseif ($text -match '(?s)"action"\s*:\s*(\{\s*.*?\s*\})') {
                $actions = @($matches[1] | ConvertFrom-Json)
            }

            $status = if ($text -match '"status"\s*:\s*"([a-zA-Z_]+)"') { $matches[1] } else { 'running' }
            $result = if ($text -match '"result"\s*:\s*"([^"]*)"') { $matches[1] } else { '' }
            $thought = if ($text -match '"thought"\s*:\s*"((?:[^"\\]|\\.)*)"') { $matches[1] } else { 'Gemini dang thao tac tren man hinh.' }

            return [pscustomobject]@{
                thought = $thought
                actions = $actions
                status = $status
                result = $result
            }
        } catch {}

        return $null
    }

    $history = New-Object Collections.Generic.List[object]

    for ($step=1; $step -le $maxSteps; $step++) {
        Test-Stop

        $screenBase64 = Capture-Screen
        Write-Status 'running' "Gemini is observing desktop display (10 FPS - Step $step/$maxSteps)." $step

        $userPrompt = @"
[USER TASK]: $task
[STEP]: $step / $maxSteps.

[LANGUAGE & KEYBOARD DIRECTIVE]:
- Write your reasoning 'thought' and 'result' fields in English.
- KEYBOARD OUTPUT: For any 'type' action typing text, type in proper accented Vietnamese (Tiếng Việt có dấu đầy đủ) when generating Vietnamese greetings, documents, notes, answers, or requested text.

[LASER COORDINATE DIRECTIVE]:
- Observe the screenshot carefully.
- Identify the target element and its exact center (x, y) on the 0..1000 grid (x: 0=left, 1000=right; y: 0=top, 1000=bottom).
- In 'thought', begin with: [Target: <element name>, Est: (x=..., y=...)], then explain your observation and action.
- Ensure 'x' and 'y' in 'actions' match this center target exactly.
"@

        # Prepare multimodal request for Gemini (fast JPEG in-memory for 10 FPS continuous streaming)
        $mime = if ($script:ImageMimeType) { $script:ImageMimeType } else { 'image/jpeg' }
        $parts = @(
            @{ text = $userPrompt },
            @{
                inlineData = @{
                    mimeType = $mime
                    data = $screenBase64
                }
            }
        )

        if ($promptImageBase64) {
            $parts += @{ text = "Attached user reference image:" }
            $parts += @{
                inlineData = @{
                    mimeType = $promptImageMime
                    data = $promptImageBase64
                }
            }
        }

        $contents = @(
            @{
                role = 'user'
                parts = $parts
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
        $plan = Parse-GeminiJson $rawText

        if (-not $plan) {
            Add-Log "Warning: Unable to parse JSON from Gemini at step $step, retrying in next cycle..."
            Start-Sleep -Milliseconds 600
            continue
        }

        if ($plan.thought) {
            Add-Log ("Gemini: " + [string]$plan.thought)
        }

        # 1. ALWAYS execute actions first if provided by Gemini
        $rawActions = if ($plan.actions) { $plan.actions } elseif ($plan.action) { $plan.action } else { $null }
        $actions = @($rawActions)

        if ($actions.Count -gt 0) {
            Write-Status 'running' "Executing $($actions.Count) action(s) at step $step..." $step
            foreach ($action in $actions) {
                Execute-Action $action $typingDelay
            }
        }

        # 2. Handle needs_user
        if ($plan.status -eq 'needs_user') {
            Add-Log 'AI halted for manual user confirmation due to sensitive operation.'
            Write-Status 'needs_user' ([string]$plan.result) $step
            exit 0
        }

        # 3. Handle completion
        if ($plan.status -eq 'done') {
            if ($actions.Count -gt 0) {
                Start-Sleep -Milliseconds 350
            }
            $answer = if ($plan.result) { [string]$plan.result } else { 'Task completed successfully.' }
            Add-Log ("Completed: " + $answer)
            Capture-Screen | Out-Null
            Write-Status 'done' 'Task completed successfully.' $step $answer
            exit 0
        }

        # 4. If no actions were given and not done, continue observing
        if ($actions.Count -eq 0) {
            Add-Log "No actions proposed in this step, continuing observation..."
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

    Add-Log "Stopped upon reaching safety limit of $maxSteps steps."
    Write-Status 'stopped' "Reached safety limit of $maxSteps steps." $maxSteps
} catch [OperationCanceledException] {
    $cancelMsg = $_.Exception.Message
    Add-Log $cancelMsg
    if ($ConsoleMode) {
        Write-Host ""
        Write-Host "  ==========================================================" -ForegroundColor Red
        Write-Host "  [EMERGENCY STOP] $cancelMsg" -ForegroundColor Yellow
        Write-Host "  All physical mouse and keyboard actions safely aborted." -ForegroundColor Green
        Write-Host "  ==========================================================" -ForegroundColor Red
        Write-Host ""
    }
    Write-Status 'stopped' $cancelMsg 0
} catch {
    $message = $_.Exception.Message
    if ($message -match '400' -or $message -match '403' -or $message -match 'API_KEY_INVALID') {
        $message = 'Invalid Gemini API key or unauthorized access to Generative Language API (HTTP 400/403).'
    } elseif ($message -match '429') {
        $message = 'Google Gemini account reached rate limit or quota (HTTP 429).'
    } elseif ($message -match '503' -or $message -match 'Unavailable') {
        $message = 'Google Gemini servers are temporarily overloaded (HTTP 503). Retrying automatically.'
    } elseif ($message -match 'model') {
        $message = 'Specified Gemini model unavailable for your API key: ' + $message
    }
    Add-Log ('Error: ' + $message)
    Write-Status 'error' $message 0
} finally {
    Remove-Item (Join-Path $DataDir 'worker.pid') -Force -ErrorAction SilentlyContinue
}