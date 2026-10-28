param([int]$x, [int]$y, [int]$ticks)
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Sc { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, int d, IntPtr e); }
'@
[Sc]::SetCursorPos($x, $y) | Out-Null; Start-Sleep -Milliseconds 100
[Sc]::mouse_event(0x800, 0, 0, -120 * $ticks, [IntPtr]::Zero)
"scrolled"
