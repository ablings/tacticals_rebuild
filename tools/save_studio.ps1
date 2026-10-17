# Save one Studio window's place to its file (Ctrl+S), safely: brings the window whose title matches to the front, checks the
# foreground window really is that one, then sends Ctrl+S. Refuses (exit 1) if the window is in Play or the check fails.
# Usage: pwsh tools/save_studio.ps1 Tacticals_rebuild | match_place_ref | Tutorial_place | ...
# (2026-10-17: the publish routine saves each copy before copying it; never press keys into a window we didn't check.)
param([Parameter(Mandatory = $true)][string]$titlePart)
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class FG {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
'@
$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$titlePart*" } | Select-Object -First 1
if (-not $p) { Write-Error "no Studio window with '$titlePart' in its title"; exit 1 }
$h = $p.MainWindowHandle
[FG]::ShowWindow($h, 9) | Out-Null   # SW_RESTORE
$ws = New-Object -ComObject WScript.Shell
$ws.AppActivate($p.Id) | Out-Null
Start-Sleep -Milliseconds 400
[FG]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 300
$fg = [FG]::GetForegroundWindow()
$t = [FG]::Title($fg)
if ($fg -ne $h -or $t -notlike "*$titlePart*") { Write-Error "foreground is '$t', not '$titlePart': not saving"; exit 1 }
$ws.SendKeys('^s')
Start-Sleep -Seconds 3
"saved: $t"
