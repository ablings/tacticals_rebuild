# Mute (or unmute) Roblox Studio in the Windows volume mixer, so test runs make no sound while Edward uses the PC.
# Per-app audio session mute through Core Audio (IAudioSessionManager2 / ISimpleAudioVolume); nothing else changes.
# Usage: pwsh tools/mute_studio.ps1 [-unmute]   (re-run after Studio restarts or plays a new sound stream: sessions are per process)
param([switch]$unmute)
Add-Type -Language CSharp @"
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int NotImpl1(); [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { [PreserveSig] int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 { int N1(); int N2(); [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator e); }
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator { [PreserveSig] int GetCount(out int n); [PreserveSig] int GetSession(int i, out IAudioSessionControl2 s); }
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 { int N1(); int N2(); int N3(); int N4(); int N5(); int N6(); int N7(); int N8(); int N9(); int N10(); int N11();
  [PreserveSig] int GetProcessId(out uint pid); }
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume { int N1(); int N2(); [PreserveSig] int SetMute(bool mute, ref Guid ctx); [PreserveSig] int GetMute(out bool mute); }
public static class StudioMute {
  public static List<string> Set(HashSet<uint> pids, bool mute) {
    var log = new List<string>();
    var en = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
    IMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);
    var iid = typeof(IAudioSessionManager2).GUID; object o; dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    var mgr = (IAudioSessionManager2)o; IAudioSessionEnumerator se; mgr.GetSessionEnumerator(out se);
    int n; se.GetCount(out n);
    for (int i = 0; i < n; i++) {
      IAudioSessionControl2 s; se.GetSession(i, out s); uint pid; s.GetProcessId(out pid);
      if (!pids.Contains(pid)) continue;
      var vol = (ISimpleAudioVolume)s; var g = Guid.Empty; vol.SetMute(mute, ref g);
      log.Add("pid " + pid + (mute ? " muted" : " unmuted"));
    }
    return log;
  }
}
"@
$pids = New-Object 'System.Collections.Generic.HashSet[uint32]'
Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { [void]$pids.Add([uint32]$_.Id) }
$r = [StudioMute]::Set($pids, -not $unmute)
if ($r.Count -eq 0) { "no Studio audio session yet (it appears once Studio plays a sound): $($pids.Count) Studio process(es)" } else { $r }
