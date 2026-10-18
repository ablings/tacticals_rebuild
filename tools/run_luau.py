"""Run a Luau file in Tacticals_rebuild.rbxl through the stdio MCP bridge.
Usage (from tacticals_rebuild): python tools/run_luau.py fix/place_hub1.lua [UNDO]
UNDO replaces the line tagged --@UNDO with 'local UNDO = true'."""
import json, os, subprocess, sys, re, tempfile
SID = "7f9e7426-2e49-4e8e-916c-304843df58de"   # Tacticals_rebuild.rbxl; ids change on reload (list_roblox_studios)
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
code = open(sys.argv[1], encoding="utf-8").read()
if "UNDO" in sys.argv[2:]:
    code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": SID, "datamodel_type": "Edit", "code": code}, open(path, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", path], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
print(r.stdout); print(r.stderr[-2000:], file=sys.stderr); os.remove(path); sys.exit(r.returncode)
