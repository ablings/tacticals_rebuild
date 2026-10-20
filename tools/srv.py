"""Run Luau in a Studio's Play SERVER (or Client) datamodel; the bridge rejects multi-line code there, so lines are joined.
Usage: python tools/srv.py <lobby|match|id> <file.lua | -e code> [Client]"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "5e5685e4-6afe-4dde-b307-dd6c67c0a85d", "match": "7a8bab8a-3a9c-479b-b323-38d82789723b"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
sid = SIDS.get(sys.argv[1], sys.argv[1])
code = sys.argv[3] if sys.argv[2] == "-e" else open(sys.argv[2], encoding="utf-8").read()
mode = "Client" if "Client" in sys.argv[3:] else "Server"
lines = [l.split(" --", 1)[0] if l.lstrip().startswith("--") is False and " -- " in l else ("" if l.lstrip().startswith("--") else l) for l in code.splitlines()]
code = " ".join(lines)
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": mode, "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p); print(r.stdout.strip() or r.stderr[-800:])
