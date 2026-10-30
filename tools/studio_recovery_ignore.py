"""Answer Studio's 'Auto Recovery File Found' dialog with Ignore, ONLY for the Studio process whose window title contains the
given place file (never another agent's dialog). Usage: python tools/studio_recovery_ignore.py <place file name>"""
import ctypes, ctypes.wintypes as wt, sys, time
ctypes.windll.shcore.SetProcessDpiAwareness(2)
u = ctypes.windll.user32
name = sys.argv[1].lower()
wins = []
def cb(h, _):
    if u.IsWindowVisible(h):
        n = u.GetWindowTextLengthW(h); b = ctypes.create_unicode_buffer(n + 1); u.GetWindowTextW(h, b, n + 1)
        pid = wt.DWORD(); u.GetWindowThreadProcessId(h, ctypes.byref(pid)); r = wt.RECT(); u.GetWindowRect(h, ctypes.byref(r))
        wins.append((h, b.value, pid.value, r))
    return True
u.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)
mine = {p for h, t, p, r in wins if name in t.lower() and t.endswith("Roblox Studio")}
for h, t, p, r in wins:
    w, ht = r.right - r.left, r.bottom - r.top
    if t == "RobloxStudio" and p in mine and 300 < w < 450 and 150 < ht < 260:
        u.SetForegroundWindow(h); time.sleep(0.3)
        x, y = r.left + 315, r.top + 158
        u.SetCursorPos(x, y); time.sleep(0.15); u.mouse_event(2, 0, 0, 0, 0); time.sleep(0.05); u.mouse_event(4, 0, 0, 0, 0)
        print("recovery dialog of", sys.argv[1], ": Ignore"); time.sleep(1)
