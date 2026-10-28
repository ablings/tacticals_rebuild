# Minimal desktop control for Studio-only computer use (when the session has no computer-use tool).
#   desk.ps1 shot <out.png>                 full-screen screenshot
#   desk.ps1 click <x> <y> [double|right]   click, only if the window under the point belongs to RobloxStudioBeta
#   desk.ps1 keys <sendkeys>                SendKeys into the foreground window, only if it belongs to RobloxStudioBeta
#   desk.ps1 front <titlePart>              bring the Studio window whose title holds <titlePart> to the front
# Refuses Delete / Backspace / Ctrl+A (CLAUDE.md hard rule) and any window of another process.
param([Parameter(Mandatory = $true)][string]$cmd, [string]$a1, [string]$a2, [string]$a3)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class Dk {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
  public static uint Pid(IntPtr h) { uint p; GetWindowThreadProcessId(h, out p); return p; }
}
'@
function IsStudio([IntPtr]$h) {
  $p = Get-Process -Id ([Dk]::Pid($h)) -ErrorAction SilentlyContinue
  return ($p -and $p.ProcessName -eq 'RobloxStudioBeta')
}
switch ($cmd) {
  'shot' {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($a1, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    "fg: " + [Dk]::Title([Dk]::GetForegroundWindow())
  }
  'shotr' {
    # the right monitor (Studio's), any screen that is not the primary
    $b = ([System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1).Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($a1, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    "fg: " + [Dk]::Title([Dk]::GetForegroundWindow()) + " | origin " + $b.X + "," + $b.Y
  }
  'front' {
    $p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$a1*" } | Select-Object -First 1
    if (-not $p) { Write-Error "no Studio window with '$a1'"; exit 1 }
    [Dk]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    (New-Object -ComObject WScript.Shell).AppActivate($p.Id) | Out-Null
    Start-Sleep -Milliseconds 300
    [Dk]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    "fg: " + [Dk]::Title([Dk]::GetForegroundWindow())
  }
  'click' {
    $pt = New-Object Dk+POINT; $pt.X = [int]$a1; $pt.Y = [int]$a2
    $h = [Dk]::WindowFromPoint($pt)
    if (-not (IsStudio $h)) { Write-Error ("refused: window at point is '" + [Dk]::Title([Dk]::GetAncestor($h, 2)) + "', not Studio"); exit 1 }
    [Dk]::SetCursorPos($pt.X, $pt.Y) | Out-Null; Start-Sleep -Milliseconds 120
    if ($a3 -eq 'right' -or $a2 -eq 'right') { $dn = 0x8; $up = 0x10 } else { $dn = 0x2; $up = 0x4 }
    $n = if ($a3 -eq 'double') { 2 } else { 1 }
    for ($i = 0; $i -lt $n; $i++) { [Dk]::mouse_event($dn, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 40; [Dk]::mouse_event($up, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 90 }
    "clicked in: " + [Dk]::Title([Dk]::GetAncestor($h, 2))
  }
  'keys' {
    if ($a1 -match '\{DEL|\{DELETE|\{BS|\{BACKSPACE|\{BKSP|\^a|\^A') { Write-Error "refused: Delete / Backspace / Ctrl+A"; exit 1 }
    $h = [Dk]::GetForegroundWindow()
    if (-not (IsStudio $h)) { Write-Error ("refused: foreground is '" + [Dk]::Title($h) + "', not Studio"); exit 1 }
    [System.Windows.Forms.SendKeys]::SendWait($a1)
    "sent to: " + [Dk]::Title($h)
  }
  default { Write-Error "unknown command $cmd"; exit 1 }
}
