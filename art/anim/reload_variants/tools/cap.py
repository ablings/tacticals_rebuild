"""cap.py: Studio frame strips of a clip in MY Studio (out/anim_reload_variants/studio_id.txt), via the weapons animator's
strip.lua + cap_lib.lua (read-only reuse). One puppet per time in a row (side / game), or one capture per time (fp).
  python cap.py <Clip> <side|game|fp> <Gun> <t1,t2,...> <out.png> [--label "..."]
Times are clip seconds. Prints the png path."""
import json, os, subprocess, sys, glob, time
from PIL import Image, ImageDraw
R = "C:/Users/aroki/Documents/tacticals_rebuild"
D = R + "/out/anim_reload_variants"
W = R + "/art/anim/weapons/studio"
T = R + "/art/anim/reload_variants/tools"
SID = open(D + "/studio_id.txt").read().strip()
KIT = "C:/Users/aroki/Documents/roblox_kits/tools/mcpcli.py"


def mcp(tool, args):
    args["studio_id"] = SID
    p = D + "/_cap_args.json"
    json.dump(args, open(p, "w"))
    env = dict(os.environ, MCP_TIMEOUT="600", MCP_WARMUP="1")
    return subprocess.run([sys.executable, KIT, "call", tool, p], capture_output=True, text=True, cwd=D, env=env).stdout


def run_lua(code):
    lib = open(W + "/cap_lib.lua", encoding="utf-8").read()
    src = "local C = (function()\n" + lib + "\nend)()\n" + code
    return mcp("execute_luau", {"code": src, "datamodel_type": "Edit"})


def strip(clip, view, gun, times, cid):
    job = 'local JOB = {clip="%s", times={%s}, gun=%s, view="%s", left=false}\n' % (clip, ",".join("%.4f" % t for t in times),
                                                                                  '"%s"' % gun if gun != "-" else "nil", view)
    out = run_lua(job + open(W + "/strip.lua", encoding="utf-8").read())
    import re
    m = re.search(r"CAM ([-0-9. ]+)", out)
    if not m:
        raise SystemExit("strip failed: " + out[-400:])
    v = [float(x) for x in m.group(1).split()]
    before = set(glob.glob(D + "/**/*.png", recursive=True))
    mcp("screen_capture", {"capture_id": cid, "camera_position": v[0:3], "look_at_position": v[3:6]})
    new = [p for p in glob.glob(D + "/**/*.png", recursive=True) if p not in before]
    if not new:
        new = sorted(glob.glob(D + "/**/%s*.png" % cid, recursive=True), key=os.path.getmtime)[-1:]
    return new[-1]


def main():
    a = sys.argv[1:]
    label = None
    if "--label" in a:
        i = a.index("--label"); label = a[i + 1]; a = a[:i] + a[i + 2:]
    clip, view, gun, times, out = a[0], a[1], a[2], [float(x) for x in a[3].split(",")], a[4]
    if view == "fp":
        ims = []
        for k, t in enumerate(times):
            p = strip(clip, "fp", gun, [t], "fp_%s_%d" % (clip, k))
            im = Image.open(p).convert("RGB")
            im = im.resize((im.width * 300 // im.height, 300))
            ImageDraw.Draw(im).text((6, 6), "%.2fs" % t, fill=(255, 255, 0))
            ims.append(im)
        o = Image.new("RGB", (sum(i.width for i in ims), 300)); x = 0
        for i in ims: o.paste(i, (x, 0)); x += i.width
    else:
        o = Image.open(strip(clip, view, gun, times, "%s_%s" % (clip, view))).convert("RGB")
    if label:
        d = ImageDraw.Draw(o); d.rectangle((0, 0, 9 * len(label) + 10, 18), fill=(0, 0, 0)); d.text((5, 3), label, fill=(255, 255, 255))
    o.save(out); print(out)


if __name__ == "__main__":
    main()
