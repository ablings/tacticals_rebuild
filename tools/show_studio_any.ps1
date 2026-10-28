# Show one Studio window full-size on the second monitor (XF243Y P, x 1920..3840) WITHOUT taking focus,
# so Studio MCP screen_capture renders real pixels (minimised/covered windows capture blank white).
# Usage: pwsh tools/show_studio.ps1 tacticals|rivals
param([string]$which = 'tacticals')
Add-Type @'
using System; using System.Runtime.InteropServices;
public class SW { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x,int y,int cx,int cy,uint f); }
'@
$pat = "*$which*"
$h = (Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like $pat } | Select-Object -First 1).MainWindowHandle
if (-not $h) { Write-Error "window not found: $which"; exit 1 }
[SW]::ShowWindow($h, 4) | Out-Null                                  # SW_SHOWNOACTIVATE
[SW]::SetWindowPos($h, [IntPtr]::Zero, 1920, 0, 1920, 1040, 0x0010) | Out-Null  # HWND_TOP, SWP_NOACTIVATE
"shown $which"
