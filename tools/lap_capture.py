"""Play-mode lap capture (eye height) via the stdio MCP bridge. Needs Play running and the client helper _G.lap
(installed by tools/lap_client.lua). Usage: python tools/lap_capture.py <stops.json> [names...]
stops.json: {"name": [[cam x,y,z],[look x,y,z], fov?], ...}  -> out/lap/<name>.png"""
import json, os, subprocess, sys, shutil, time
SID = "d93b3ec2-422d-40e2-87ce-6dd7b5c4e24c"
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ENV = dict(os.environ, PYTHONIOENCODING="utf-8")
def call(tool, args):
    return subprocess.run([sys.executable, CLI, "call", tool, json.dumps(args)], capture_output=True, text=True, env=ENV, encoding="utf-8")
stops = json.load(open(sys.argv[1])); names = sys.argv[2:] or list(stops)
os.makedirs("out/lap", exist_ok=True)
for n in names:
    s = stops[n]; c, l = s[0], s[1]; fov = s[2] if len(s) > 2 else 70
    code = f"_G.lap(Vector3.new({c[0]},{c[1]},{c[2]}),Vector3.new({l[0]},{l[1]},{l[2]}),{fov}) task.wait(1.2) return 'ok'"
    r = call("execute_luau", {"studio_id": SID, "datamodel_type": "Client", "code": code})
    cid = f"lap_{n}"
    call("screen_capture", {"studio_id": SID, "capture_id": cid})
    src = os.path.join("out", f"{cid}_1.png")
    if os.path.exists(src): shutil.move(src, os.path.join("out", "lap", f"{n}.png")); print("ok", n)
    else: print("FAIL", n, r.stdout[-200:])
