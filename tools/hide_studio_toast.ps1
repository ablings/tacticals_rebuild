# Hide Studio's small borderless 'RobloxStudio' popup (a toast ~366x40) that steals the foreground from the main window, so
# save_studio.ps1 can focus the place window. Only touches windows of RobloxStudioBeta titled exactly 'RobloxStudio' under 120 px high.
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class HT { public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  public struct RECT { public int L, T, R, B; } }
"@
$ids = (Get-Process RobloxStudioBeta).Id
[HT]::EnumWindows({ param($h, $l)
  $p = 0; [HT]::GetWindowThreadProcessId($h, [ref]$p) | Out-Null
  if ($ids -contains $p -and [HT]::IsWindowVisible($h)) {
    $sb = New-Object Text.StringBuilder 256; [HT]::GetWindowText($h, $sb, 256) | Out-Null
    $r = New-Object HT+RECT; [HT]::GetWindowRect($h, [ref]$r) | Out-Null
    if ($sb.ToString() -eq 'RobloxStudio' -and ($r.B - $r.T) -lt 120) { [HT]::ShowWindow($h, 0) | Out-Null; "hid $h at $($r.L),$($r.T)" }
  }; $true }, [IntPtr]::Zero) | Out-Null
