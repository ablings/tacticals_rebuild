"""Run a Luau file in a given studio (Edit). Usage: python tools/run_luau_at.py <lobby|match|studio_id> fix/x.lua [UNDO]"""
import json, os, re, subprocess, sys, tempfile
SIDS = {"lobby": "7f9e7426-2e49-4e8e-916c-304843df58de", "match": "262bddc7-c737-4071-9821-532ab1e26f2f"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
sid = SIDS.get(sys.argv[1], sys.argv[1])
code = open(sys.argv[2], encoding="utf-8").read()
if "UNDO" in sys.argv[3:]:
    code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p); print(r.stdout.strip() or r.stderr[-800:])
