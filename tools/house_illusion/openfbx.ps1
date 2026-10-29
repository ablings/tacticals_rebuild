# Open Import 3D in my Studio (pid) and load one FBX through the file dialog by window messages (no focus race).
param([int]$procId, [string]$file)
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class Of { public delegate bool CB(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(CB cb, IntPtr l);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
 [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
 public static IntPtr Find(uint pid, string part) { IntPtr r = IntPtr.Zero; EnumWindows((h,l)=>{ uint p; GetWindowThreadProcessId(h, out p); if (p==pid && IsWindowVisible(h) && Title(h).Contains(part)) { r = h; return false; } return true;}, IntPtr.Zero); return r; } }
'@
$k = Join-Path $PSScriptRoot "mykeys.ps1"
$dlg = [Of]::Find($procId, "Open 3D File")
if ($dlg -eq [IntPtr]::Zero) {
  powershell -ExecutionPolicy Bypass -File $k $procId keys "^m" "Roblox Studio" | Out-Null
  for ($i = 0; $i -lt 20 -and $dlg -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 500; $dlg = [Of]::Find($procId, "Open 3D File") }
}
if ($dlg -eq [IntPtr]::Zero) { "no file dialog"; exit 1 }
$cbx = [Of]::GetDlgItem($dlg, 1148)
$ed = [Of]::FindWindowEx($cbx, [IntPtr]::Zero, "ComboBox", $null)
if ($ed -ne [IntPtr]::Zero) { $ed = [Of]::FindWindowEx($ed, [IntPtr]::Zero, "Edit", $null) } else { $ed = [Of]::FindWindowEx($cbx, [IntPtr]::Zero, "Edit", $null) }
[Of]::SendMessage($ed, 0x000C, [IntPtr]::Zero, $file) | Out-Null
[Of]::SendMessage($dlg, 0x0111, [IntPtr]1, [Of]::GetDlgItem($dlg, 1)) | Out-Null
$pv = [IntPtr]::Zero
for ($i = 0; $i -lt 30 -and $pv -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 500; $pv = [Of]::Find($procId, "Import Preview") }
if ($pv -eq [IntPtr]::Zero) { "no preview"; exit 1 }
[Of]::SetWindowPos($pv, [IntPtr](-1), 300, 60, 816, 960, 0x0040) | Out-Null
"preview $pv at 300,60 (topmost)"
