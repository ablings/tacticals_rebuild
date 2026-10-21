"""Run a Luau file in a given studio (Edit). Usage: python tools/run_luau_at.py <lobby|match|studio_id> fix/x.lua [UNDO]"""
import json, os, re, subprocess, sys, tempfile
SIDS = {"lobby": "835403f5-1c18-4451-b6da-d25ee5c2f672", "match": "221cdf09-8c72-40c3-83ef-afb3ad146aac"}
CLI = os.path.expanduser(r"~\Documents\rivals_practice\mcpcli.py")
sid = SIDS.get(sys.argv[1], sys.argv[1])
code = open(sys.argv[2], encoding="utf-8").read()
if "UNDO" in sys.argv[3:]:
    code = re.sub(r"^local UNDO = false --@UNDO", "local UNDO = true --@UNDO", code, flags=re.M)
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p); print(r.stdout.strip() or r.stderr[-800:])
