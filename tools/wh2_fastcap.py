"""Warehouse 2: fast review captures over ONE StudioMCP connection (tools/wh2_capture.py opens a new one per call, ~8 s each).
Usage:
  python tools/wh2_fastcap.py <cams.json> <outdir> [--lua pre.lua] [--only sub] [--prefix new_] [--stats]
Targets the Studio whose window is out/warehouse2/Warehouse2_build.rbxl (by name, never another one). Each camera is set by
script, then captured until two consecutive frames match (Map Proof Check 7: mean |diff| < 0.5 and < 0.2 % of pixels off by
more than 6, the measure the round-5 grader logged; max 6 frames). --stats prints the frame's
luminance p5 / p50 / p95 (0-255), the numbers the night lighting is tuned on."""
import base64, glob, hashlib, json, os, queue, subprocess, sys, threading, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wh2_layout import ORIGIN_X, ORIGIN_Z, FLOOR_Y  # noqa: E402

NAME = os.environ.get("WH2_STUDIO", "Warehouse2_build.rbxl")


class Mcp:
    def __init__(self):
        local = os.environ["LOCALAPPDATA"]
        exe = sorted(glob.glob(os.path.join(local, "Roblox", "Versions", "*", "StudioMCP.exe")))[-1]
        self.p = subprocess.Popen([exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        self.q = queue.Queue()
        threading.Thread(target=lambda: [self.q.put(l) for l in self.p.stdout], daemon=True).start()
        self.i = 0
        self.req("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "wh2fast", "version": "1"}})
        self.send("notifications/initialized", {}, True)
        time.sleep(6)
        self.req("tools/list", {})
        self.sid = None
        for _ in range(10):
            out = self.call("list_roblox_studios", {}, sid=False)
            try:
                st = json.loads(out[out.index("{"):])["studios"]
                self.sid = next((s["id"] for s in st if s["name"] == NAME), None)
            except Exception:
                pass
            if self.sid:
                break
            time.sleep(3)
        if not self.sid:
            sys.exit("no Studio named " + NAME)

    def send(self, method, params, notify=False):
        msg = {"jsonrpc": "2.0", "method": method, "params": params}
        if not notify:
            self.i += 1
            msg["id"] = self.i
        self.p.stdin.write((json.dumps(msg) + "\n").encode())
        self.p.stdin.flush()
        return self.i

    def req(self, method, params, timeout=300):
        rid = self.send(method, params)
        t0 = time.time()
        while time.time() - t0 < timeout:
            try:
                line = self.q.get(timeout=1)
            except queue.Empty:
                continue
            try:
                m = json.loads(line)
            except Exception:
                continue
            if m.get("id") == rid:
                return m
        raise TimeoutError(method)

    def call(self, tool, args, sid=True, img=None):
        args = dict(args)
        if sid:
            args["studio_id"] = self.sid
        for attempt in range(4):
            r = self.req("tools/call", {"name": tool, "arguments": args})
            res = r.get("result", {})
            texts = [c["text"] for c in res.get("content", []) if c.get("type") == "text"]
            t = "\n".join(texts)
            if "No Roblox Studio instances" in t or "Unable to reach" in t:
                time.sleep(3)
                continue
            if img:
                for c in res.get("content", []):
                    if c.get("type") == "image":
                        open(img, "wb").write(base64.b64decode(c["data"]))
                        return "IMAGE"
            return t
        return t

    def lua(self, code, dm="Edit"):
        return self.call("execute_luau", {"code": code, "datamodel_type": dm})


def world(e, h, n):
    return (ORIGIN_X - e, FLOOR_Y + h, ORIGIN_Z + n)


def match(a, b):
    from PIL import Image, ImageChops
    x, y = Image.open(a).convert("L"), Image.open(b).convert("L")
    if x.size != y.size:
        return False
    d = list(ImageChops.difference(x, y).getdata())
    return sum(d) / len(d) < 0.5 and sum(1 for v in d if v > 6) / len(d) < 0.002


def stats(path):
    from PIL import Image
    im = Image.open(path).convert("L")
    w, h = im.size
    im = im.crop((0, int(h * 0.06), w, h))  # skip the top bar
    px = sorted(im.getdata())
    n = len(px)
    return px[int(n * 0.05)], px[n // 2], px[int(n * 0.95)]


def main():
    camfile, outdir = sys.argv[1], sys.argv[2]
    a = sys.argv[3:]
    only = a[a.index("--only") + 1] if "--only" in a else None
    prefix = a[a.index("--prefix") + 1] if "--prefix" in a else "new_"
    pre = a[a.index("--lua") + 1] if "--lua" in a else None
    os.makedirs(outdir, exist_ok=True)
    m = Mcp()
    if pre:
        print(m.lua(open(pre, encoding="utf-8").read())[:300])
    cams = json.load(open(camfile))
    tmp = os.path.join(outdir, "_frame.png")
    for cam in cams:
        if only and not any(o in cam["name"] for o in only.split(",")):
            continue
        p, t = world(*cam["eye"]), world(*cam["at"])
        m.lua(f"""local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Scriptable cam.FieldOfView={cam.get('fov', 70)}
cam.CFrame=CFrame.lookAt(Vector3.new({p[0]},{p[1]},{p[2]}),Vector3.new({t[0]},{t[1]},{t[2]})) cam.Focus=CFrame.new({t[0]},{t[1]},{t[2]})
game.Selection:Set({{}}) return 'ok'""")
        # local lights load into the light grid a moment after a long camera jump (a frame of the north yard taken right after
        # the south one rendered black twice in a row and "matched"): settle first
        time.sleep(float(os.environ.get("WH2_SETTLE", "2.5")))
        hs, prev = [], None
        dst = os.path.join(outdir, f"{prefix}{cam['name']}.png")
        for k in range(6):
            if m.call("screen_capture", {"capture_id": "wh2fast"}, img=tmp) != "IMAGE":
                print("  no image")
                break
            cur = open(tmp, "rb").read()
            hs.append(match(prev, tmp) if prev else False)
            prev = tmp + ".prev"
            open(prev, "wb").write(cur)
            if hs[-1]:
                break
        if os.path.exists(tmp):
            os.replace(tmp, dst)
        ok = bool(hs) and hs[-1]
        if prev and os.path.exists(prev):
            os.remove(prev)
        line = f"{cam['name']} frames {len(hs)} {'stable' if ok else 'UNSTABLE'}"
        if "--stats" in a and os.path.exists(dst):
            line += " p5/p50/p95 %d/%d/%d" % stats(dst)
        print(line, flush=True)
    m.p.kill()


if __name__ == "__main__":
    main()
