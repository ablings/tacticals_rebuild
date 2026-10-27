"""Grader, read-only: straight-down frames at h 11 over floor points; median luminance of the centre patch.
Camera moves only (restored by the caller at the end)."""
import os, sys, time, json
sys.path.insert(0, r"C:\Users\Shadow\Documents\tacticals_rebuild\tools")
from wh2_fastcap import Mcp, world, match
from PIL import Image
OUT = r"C:\Users\Shadow\Documents\tacticals_rebuild\captures\warehouse2\grade_r6\pools"
os.makedirs(OUT, exist_ok=True)
pts = json.loads(sys.argv[1])
H = float(sys.argv[2]) if len(sys.argv) > 2 else 11
m = Mcp()
tmp = os.path.join(OUT, "_f.png")
for e, n in pts:
    p, t = world(e, H, n), world(e, 0, n)
    r = m.lua(f"""local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Scriptable cam.FieldOfView=70
cam.CFrame=CFrame.lookAt(Vector3.new({p[0]},{p[1]},{p[2]}),Vector3.new({t[0]},{t[1]},{t[2]}+0.3)) cam.Focus=CFrame.new({t[0]},{t[1]},{t[2]})
game.Selection:Set({{}})
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Include rp.FilterDescendantsInstances={{workspace.Warehouse2.CollisionProxies, workspace.Warehouse2.Props, workspace.Warehouse2.Shootables}}
local h=workspace:Raycast(Vector3.new({p[0]},{p[1]},{p[2]}), Vector3.new(0,-20,0), rp)
return h and (h.Instance.Name..' '..string.format('%.2f',h.Position.Y)) or 'none'""")
    time.sleep(2.5)
    prev = None
    for k in range(6):
        m.call("screen_capture", {"capture_id": "g6pool"}, img=tmp)
        cur = open(tmp, "rb").read()
        if prev and match(prev, tmp):
            break
        prev = tmp + ".p"; open(prev, "wb").write(cur)
    im = Image.open(tmp).convert("L")
    w, h = im.size
    patch = sorted(im.crop((w//2-40, h//2-40, w//2+40, h//2+40)).tobytes())
    wide = sorted(im.crop((w//2-200, h//2-120, w//2+200, h//2+120)).tobytes())
    dst = os.path.join(OUT, f"pool_e{e}_n{n}.png")
    os.replace(tmp, dst)
    print(f"e {e:6} n {n:6}  under: {r.strip()[-40:]:30s} centre p50 {patch[len(patch)//2]:3d}  wide p50 {wide[len(wide)//2]:3d} p10 {wide[len(wide)//10]:3d} p90 {wide[9*len(wide)//10]:3d}", flush=True)
m.p.kill()
