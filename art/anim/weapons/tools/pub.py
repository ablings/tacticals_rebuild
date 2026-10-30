"""pub.py <Clip> [...] : publish KeyframeSequences from MY Studio (anim_weapons.rbxl) to the group gunsy funsy.
Per clip: select it (MCP) -> right-click its Explorer row -> Save / Export -> Save to Roblox -> Creator = gunsy funsy
(checked against a verified crop before Save) -> Save -> copy the id from the success screen (clipboard) -> Close ->
verify on economy.roblox.com (name + group 102028987) -> art/anim/weapons/published.json.
Screen coordinates are for the staged window (my Studio filling the agents' monitor at x=1920). --ref saves the creator
crop and stops before Save (to make the reference). Needs MY_STUDIO_PID."""
import sys, os, json, time, subprocess, urllib.request
from PIL import Image, ImageChops, ImageStat

H = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(H, "..", "..", "..", "..", "out", "anim_weapons")
SCR = os.path.join(OUT, "_pub.png")
REF = os.path.join(H, "pub_creator_ref.png")
PUB = os.path.join(H, "..", "published.json")
X0 = 1920
GROUP = 102028987


def desk(*a):
    return subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(H, "desk.ps1")] + [str(x) for x in a],
                          capture_output=True, text=True).stdout.strip()


def shot():
    desk("shotr", SCR)
    return Image.open(SCR).convert("RGB")


def run_lua(code):
    p = os.path.join(OUT, "_pub.lua")
    open(p, "w").write(code)
    return subprocess.run(["sh", os.path.join(H, "run.sh"), p, "Edit"], capture_output=True, text=True, env=dict(os.environ, MCP_WARMUP="1")).stdout


def find_row(im):
    ys = [y for y in range(195, 525) if (lambda p: p[2] > 200 and p[0] < 90 and 90 < p[1] < 150)(im.getpixel((1700, y)))]
    return (min(ys) + max(ys)) // 2 if ys else None


def creator_crop(im):
    return im.crop((860, 440, 1060, 456))


def same(a, b):
    d = ImageStat.Stat(ImageChops.difference(a, b)).mean
    return sum(d) / 3 < 6


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
    desk("front", "anim_weapons")
    time.sleep(0.8)
    im = shot()
    y = find_row(im)
    if y is None:
        return None, "row not found"
    desk("click", X0 + 1726, y, "right"); time.sleep(0.8)
    # the context menu opens downward from the row: Save / Export is 280 px below; its submenu opens to the left
    im = shot()
    if im.getpixel((1790, y + 280))[0] < 200:
        desk("click", X0 + 800, 600); return None, "menu not where expected"
    desk("click", X0 + 1790, y + 280); time.sleep(0.8)
    desk("click", X0 + 1645, y + 280); time.sleep(3.5)
    im = shot()
    sv = im.getpixel((1410, 922))
    if not (sv[2] > 200 and sv[0] < 100):  # the blue Save button of the configuration page
        return None, "no configuration dialog"
    desk("frontdlg", "Asset Configuration", "pin"); time.sleep(0.4)
    desk("click", X0 + 1054, 449); time.sleep(1.0)
    desk("wheel", X0 + 1040, 600, 4); time.sleep(0.8)
    desk("click", X0 + 940, 570); time.sleep(1.6)
    im = shot()
    cc = creator_crop(im)
    if ref_mode:
        cc.save(REF)
        return None, "reference saved: check it, then cancel the dialog"
    ref = Image.open(REF).convert("RGB")
    best = min(sum(ImageStat.Stat(ImageChops.difference(im.crop((860 + dx, 440 + dy, 1060 + dx, 456 + dy)), ref)).mean) / 3
               for dy in range(-14, 15) for dx in range(-6, 7, 2))
    if best > 6:
        cc.save(os.path.join(OUT, "_pub_creator_bad.png"))
        desk("click", X0 + 1470, 922); time.sleep(1.2)  # Cancel
        desk("click", X0 + 1040, 546); time.sleep(1)    # confirm "Discard"
        return None, "creator is not gunsy funsy: cancelled"
    desk("click", X0 + 1410, 922); time.sleep(4)
    aid = ""
    for _ in range(15):
        desk("frontdlg", "Asset Configuration", "pin")
        im = shot()
        sv = im.getpixel((1410, 922))
        if not (sv[2] > 200 and sv[0] < 100):  # the Save button is gone: the success page
            subprocess.run(["pwsh", "-NoProfile", "-Command", "Set-Clipboard -Value 'none'"])
            desk("click", X0 + 1030, 348); time.sleep(0.7)  # copy-id icon
            aid = "".join(ch for ch in clipboard() if ch.isdigit())
            if len(aid) > 6:
                break
        time.sleep(1)
    if len(aid) <= 6:
        return None, "uploaded? no id copied: dialog left open"
    desk("click", X0 + 960, 888); time.sleep(1)  # Close
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
