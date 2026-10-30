"""pub.py <Clip> [...] : publish KeyframeSequences from MY Studio (anim_body.rbxl) to the group gunsy funsy.
Per clip: select it (MCP) -> right-click its Explorer row -> Save / Export -> Save to Roblox -> Creator = gunsy funsy
(checked against a verified crop before Save) -> Save -> copy the id from the success screen (clipboard) -> Close ->
verify on economy.roblox.com (name + group 102028987) -> art/anim/weapons/published.json.
Screen coordinates are for the staged window (my Studio filling the agents' monitor at x=1920). --ref saves the creator
crop and stops before Save (to make the reference). Needs MY_STUDIO_PID."""
import sys, os, json, time, subprocess, urllib.request
from PIL import Image, ImageChops, ImageStat

H = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(H, "..", "..", "..", "..", "..", "out", "anim_body")
SCR = os.path.join(OUT, "_pub.png")
REF = os.path.join(H, "pub_creator_ref.png")
PUB = os.path.join(H, "..", "..", "published.json")
X0 = 1920
GROUP = 102028987


def _desk(*a):
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(H, "desk.ps1")] + [str(x) for x in a],
                       capture_output=True, text=True)
    return r.stdout.strip(), r.stderr


def desk(*a):
    out, err = _desk(*a)
    if a[0] in ("click", "wheel") and "refused" in err:  # another agent's window came over mine: bring mine back, retry
        _desk("front", "anim_body")
        if _desk("rect", "Asset Configuration")[0] != "none":
            _desk("frontdlg", "Asset Configuration", "pin")
        time.sleep(0.5)
        out, err = _desk(*a)
    return out


def shot():
    desk("shotr", SCR)
    return Image.open(SCR).convert("RGB")


def run_lua(code):
    p = os.path.join(OUT, "_pub.lua")
    open(p, "w").write(code)
    return subprocess.run(["sh", os.path.join(H, "..", "run.sh"), p, "Edit"], capture_output=True, text=True, env=dict(os.environ, MCP_WARMUP="1")).stdout


def find_row(im):
    ys = [y for y in range(195, 525) if (lambda p: p[2] > 200 and p[0] < 90 and 90 < p[1] < 150)(im.getpixel((1700, y)))]
    if not ys or max(ys) - min(ys) < 14:   # missing or cut off at the Explorer's edge
        return None
    return (min(ys) + max(ys)) // 2


def creator_crop(im):
    return im.crop((860, 440, 1060, 456))


def same(a, b):
    d = ImageStat.Stat(ImageChops.difference(a, b)).mean
    return sum(d) / 3 < 6


def save_button(im, x, y):
    """the blue Save button somewhere in a 40x24 box around (x, y)"""
    n = 0
    for yy in range(y - 12, y + 12, 3):
        for xx in range(x - 20, x + 20, 3):
            p = im.getpixel((xx, yy))
            if p[2] > 200 and p[0] < 100:
                n += 1
    return n >= 8


def clipboard():
    return subprocess.run(["pwsh", "-NoProfile", "-Command", "Get-Clipboard"], capture_output=True, text=True).stdout.strip()


def verify(aid, name):
    try:
        d = json.load(urllib.request.urlopen("https://economy.roblox.com/v2/assets/%s/details" % aid, timeout=20))
        c = d.get("Creator") or {}
        return d.get("Name") == name and d.get("AssetTypeId") == 24 and c.get("CreatorTargetId") == GROUP
    except Exception as e:
        print("verify error", e)
        return False


def publish(name, ref_mode=False):
    run_lua('local ks = game.ReplicatedStorage.Repository.AnimationSources:FindFirstChild("%s")\n'
            'game:GetService("Selection"):Set({ ks })\nreturn ks and "ok" or "missing"' % name)
    desk("front", "anim_body")
    desk("frontdlg", "anim_body.rbxl - Roblox Studio", "pin")  # I hold the stage: keep my window above pinned others
    time.sleep(1.8)  # let the Explorer move its highlight to the new selection
    im = shot()
    y = find_row(im)
    for direction in (2, 2, 2, -4, -2, -2):  # scroll the Explorer until the whole row shows
        if y is not None:
            break
        if direction > 0:
            desk("wheel", X0 + 1760, 400, direction)
        else:
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                            "Add-Type -AssemblyName System.Windows.Forms"], capture_output=True)
            desk("wheel", X0 + 1760, 400, 0)
        time.sleep(0.6)
        im = shot()
        y = find_row(im)
    if y is None:
        return None, "row not found"
    for _ in range(8):  # keep the row in the Explorer's upper part so the context menu opens downward
        if y <= 330:
            break
        desk("wheel", X0 + 1760, 400, 2); time.sleep(0.6)
        im = shot()
        y2 = find_row(im)
        if y2 is None or y2 == y:
            break
        y = y2
    if y > 330:
        return None, "row too low in the Explorer"
    desk("click", X0 + 1726, y, "right"); time.sleep(0.8)
    # the context menu opens downward from the row: Save / Export is 280 px below; its submenu opens to the left
    im = shot()
    if im.getpixel((1790, y + 280))[0] < 200:
        desk("click", X0 + 800, 600); return None, "menu not where expected"
    desk("click", X0 + 1790, y + 280); time.sleep(0.8)
    desk("click", X0 + 1645, y + 280); time.sleep(3.5)
    im = shot()
    r, last = "none", None
    for _ in range(14):   # the dialog opens at the screen corner, then centres itself: wait until it stops moving
        r = desk("rect", "Asset Configuration")
        if r != "none" and r == last:
            break
        last = r
        time.sleep(0.7)
    if r == "none":
        return None, "no configuration dialog"
    L, T = [int(v) for v in r.split()[:2]]
    dx, dy = L - 2323, T - 67   # the dialog's offset from where it was measured (centred on the staged window)

    def P(x, y):
        return x + dx, y + dy

    def click(x, y, *extra):
        X, Y = P(x, y)
        desk("click", X0 + X, Y, *extra)
    desk("frontdlg", "Asset Configuration", "pin"); time.sleep(0.4)
    im = shot()
    if not save_button(im, *P(1410, 922)):
        return None, "dialog without a Save button"
    click(1054, 449); time.sleep(1.0)
    X, Y = P(1040, 600); desk("wheel", X0 + X, Y, 4); time.sleep(0.8)
    click(940, 570); time.sleep(1.6)
    im = shot()
    cx, cy = P(860, 440)
    if ref_mode:
        im.crop((cx, cy, cx + 200, cy + 16)).save(REF)
        return None, "reference saved: check it, then cancel the dialog"
    ref = Image.open(REF).convert("RGB")
    best = min(sum(ImageStat.Stat(ImageChops.difference(im.crop((cx + ddx, cy + ddy, cx + 200 + ddx, cy + 16 + ddy)), ref)).mean) / 3
               for ddy in range(-14, 15) for ddx in range(-6, 7, 2))
    if best > 6:
        im.crop((cx - 10, cy - 10, cx + 400, cy + 30)).save(os.path.join(OUT, "_pub_creator_bad.png"))
        click(1470, 922); time.sleep(1.2)
        desk("frontdlg", "Discard", "pin"); time.sleep(0.5)
        desk("click", X0 + 1032, 547); time.sleep(1)  # "Discard" (that popup sits mid-screen)
        return None, "creator is not gunsy funsy: cancelled"
    click(1410, 922); time.sleep(4)
    aid = ""
    for _ in range(15):
        desk("frontdlg", "Asset Configuration", "pin")
        im = shot()
        if not save_button(im, *P(1410, 922)):
            subprocess.run(["pwsh", "-NoProfile", "-Command", "Set-Clipboard -Value 'none'"])
            click(1030, 348); time.sleep(0.7)
            aid = "".join(ch for ch in clipboard() if ch.isdigit())
            if len(aid) > 6:
                break
        time.sleep(1)
    if len(aid) <= 6:
        return None, "uploaded? no id copied: dialog left open"
    click(960, 888); time.sleep(1)
    ok = verify(aid, name)
    return aid, ("verified" if ok else "NOT VERIFIED")


if __name__ == "__main__":
    args = sys.argv[1:]
    ref = "--ref" in args
    names = [a for a in args if not a.startswith("--")]
    pub = json.load(open(PUB)) if os.path.exists(PUB) else {}
    for n in names:
        if n in pub and not ref:
            print(n, "already", pub[n]); continue
        aid, msg = publish(n, ref)
        print(n, aid, msg, flush=True)
        if aid and msg == "verified":
            pub[n] = "rbxassetid://" + aid
            json.dump(pub, open(PUB, "w"), indent=1, sort_keys=True)
        elif not ref:
            print("STOP on", n); break
