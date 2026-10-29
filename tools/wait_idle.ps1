# Wait until Edward has not touched mouse/keyboard for $sec seconds (computer-use steps only run while he is away).
param([int]$sec = 120, [int]$maxMin = 110)
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Idle { [StructLayout(LayoutKind.Sequential)] public struct LII { public uint cbSize; public uint dwTime; }
[DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII p);
public static uint Ms() { var l = new LII(); l.cbSize = 8; GetLastInputInfo(ref l); return (uint)Environment.TickCount - l.dwTime; } }
'@
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt $maxMin) {
  $i = [Idle]::Ms() / 1000
  if ($i -ge $sec) { "idle $([math]::Round($i)) s at $(Get-Date -Format HH:mm:ss)"; exit 0 }
  Start-Sleep -Seconds 15
}
"still active after $maxMin min"; exit 2
