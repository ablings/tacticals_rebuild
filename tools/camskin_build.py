"""Embed fix/data/warehouse_camskin.json into fix/warehouse_camskin.lua and run it in a Studio.
Usage (from tacticals_rebuild): python tools/camskin_build.py <studio_id> [UNDO]
  match place 331cb3a0... -> Workspace.Warehouse.CamSkin
  lobby 8ef4e21a...       -> ServerStorage._DuelSource.Warehouse.Warehouse.CamSkin (then run fix/duel_split_map.lua there)"""
import json, os, re, subprocess, sys, tempfile

CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FIX = os.path.join(ROOT, "fix", "warehouse_camskin.lua")
data = json.dumps(json.load(open(os.path.join(ROOT, "fix", "data", "warehouse_camskin.json"))))
src = open(FIX, encoding="utf-8").read()
src = re.sub(r"local DATA = \[==\[.*?\]==\] --@DATA", lambda _: "local DATA = [==[" + data + "]==] --@DATA", src, flags=re.S)
open(FIX, "w", encoding="utf-8", newline="\n").write(src)
if len(sys.argv) > 1:
    code = src
    if "UNDO" in sys.argv[2:]:
        code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": sys.argv[1], "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    print(r.stdout); print(r.stderr[-2000:], file=sys.stderr); os.remove(path); sys.exit(r.returncode)
