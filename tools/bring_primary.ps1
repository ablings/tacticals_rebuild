# Bring one Studio window (title contains $titlePart) and every other visible window of that process (Publish dialog,
# "Some assets need permission" prompt) onto the PRIMARY monitor, maximise the main one, focus it. (2026-10-18: with two
# monitors the Claude app covers the right one; computer-use captures showed Studio under it while clicks went to Claude.)
# -list only prints the windows. Usage: pwsh tools/bring_primary.ps1 <titlePart> [-list]
# -secondary: use the OTHER monitor instead (Edward 2026-10-18: "use the second monitor so i can watch youtube on my main one")
param([Parameter(Mandatory = $true)][string]$titlePart, [switch]$list, [switch]$secondary)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class BP {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public struct RECT { public int L, T, R, B; }
  public static List<IntPtr> Of(int pid) {
    var o = new List<IntPtr>();
    EnumWindows((h, l) => { int p; GetWindowThreadProcessId(h, out p); if (p == pid && IsWindowVisible(h)) o.Add(h); return true; }, IntPtr.Zero);
    return o;
  }
  public static string Title(IntPtr h) { var sb = new StringBuilder(256); GetWindowText(h, sb, 256); return sb.ToString(); }
}
"@
Add-Type -AssemblyName System.Windows.Forms
$prim = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($secondary) {
  $other = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
  if ($other) { $prim = $other.WorkingArea }
}
$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$titlePart*" } | Select-Object -First 1
if (-not $p) { Write-Error "no Studio window with '$titlePart'"; exit 1 }
foreach ($h in [BP]::Of($p.Id)) {
  $r = New-Object BP+RECT; [BP]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.R - $r.L; $ht = $r.B - $r.T
  "{0} '{1}' at {2},{3} {4}x{5}" -f $h, [BP]::Title($h), $r.L, $r.T, $w, $ht
  if ($list) { continue }
  if ($h -eq $p.MainWindowHandle) {
    [BP]::ShowWindow($h, 9) | Out-Null
    [BP]::MoveWindow($h, $prim.X + 50, $prim.Y + 50, 1200, 700, $true) | Out-Null
    [BP]::ShowWindow($h, 3) | Out-Null
  } elseif ($r.L -lt $prim.X -or $r.L -ge $prim.X + $prim.Width) {
    # a popup off the primary monitor: same size, near the top-left of the primary one
    [BP]::MoveWindow($h, $prim.X + 150, $prim.Y, $w, $ht, $true) | Out-Null
    "  -> moved to primary"
  }
}
if (-not $list) {
  (New-Object -ComObject WScript.Shell).AppActivate($p.Id) | Out-Null
  [BP]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
}
