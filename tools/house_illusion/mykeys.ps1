# Send keys / clicks only into windows of ONE Studio process (by PID), checked right before each action.
# Usage: mykeys.ps1 <pid> keys "<sendkeys>" [windowTitlePart]   |   mykeys.ps1 <pid> click x y [windowTitlePart]   |   mykeys.ps1 <pid> list
param([int]$procId, [string]$cmd, [string]$a1, [string]$a2, [string]$a3)
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class Mk { public delegate bool CB(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(CB cb, IntPtr l);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
 [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rr,B; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
 public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
 public static uint Pid(IntPtr h) { uint p; GetWindowThreadProcessId(h, out p); return p; }
 public static List<IntPtr> Wins(uint pid) { var o = new List<IntPtr>(); EnumWindows((h,l)=>{ if (Pid(h)==pid && IsWindowVisible(h)) o.Add(h); return true;}, IntPtr.Zero); return o; } }
'@
function Find([string]$part) {
  foreach ($h in [Mk]::Wins($procId)) { if (-not $part -or [Mk]::Title($h) -like "*$part*") { return $h } }
  return [IntPtr]::Zero
}
switch ($cmd) {
  'list' { foreach ($h in [Mk]::Wins($procId)) { $r = New-Object Mk+R; [Mk]::GetWindowRect($h, [ref]$r) | Out-Null; "$h '$([Mk]::Title($h))' $($r.L),$($r.T),$($r.Rr),$($r.B)" } }
  'keys' {
    $h = Find $a2; if ($h -eq [IntPtr]::Zero) { "REFUSED: no window '$a2' in pid $procId"; exit 1 }
    if ($a1 -match '\{DEL|\{BS|\{BACKSPACE|\^a') { "REFUSED: forbidden key"; exit 1 }
    [Mk]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 300
    $fg = [Mk]::GetForegroundWindow()
    if ([Mk]::Pid($fg) -ne $procId) { "REFUSED: foreground is '$([Mk]::Title($fg))' (pid $([Mk]::Pid($fg)))"; exit 1 }
    [System.Windows.Forms.SendKeys]::SendWait($a1); "sent to: $([Mk]::Title($fg))"
  }
  'click' {
    $h = Find $a3; if ($h -ne [IntPtr]::Zero) { [Mk]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 300 }
    $p = New-Object Mk+POINT; $p.X = [int]$a1; $p.Y = [int]$a2
    $w = [Mk]::GetAncestor([Mk]::WindowFromPoint($p), 2)
    if ([Mk]::Pid($w) -ne $procId) { "REFUSED: point is over '$([Mk]::Title($w))' (pid $([Mk]::Pid($w)))"; exit 1 }
    [Mk]::SetCursorPos($p.X, $p.Y) | Out-Null; [Mk]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); [Mk]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
    "clicked in: $([Mk]::Title($w))"
  }
  'scroll' {
    $p = New-Object Mk+POINT; $p.X = [int]$a1; $p.Y = [int]$a2
    $w = [Mk]::GetAncestor([Mk]::WindowFromPoint($p), 2)
    if ([Mk]::Pid($w) -ne $procId) { "REFUSED: point is over '$([Mk]::Title($w))'"; exit 1 }
    [Mk]::SetCursorPos($p.X, $p.Y) | Out-Null; [Mk]::mouse_event(0x0800, 0, 0, [uint32]((($(if ($a3 -like "up*") { -[long]$a3.Substring(2) } else { [long]$a3 })) * -120) -band 0xFFFFFFFFL), [IntPtr]::Zero)
    "scrolled $a3 in: $([Mk]::Title($w))"
  }
}
