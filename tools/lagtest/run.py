"""Run a Luau file in a Studio over the kit's mcpcli. Usage: python tools/lagtest/run.py <studio_id> <Edit|Server|Client> <file.lua> [KEY=VAL ...]
KEY=VAL pairs replace {{KEY}} in the source."""
import json, os, subprocess, sys, tempfile
sid, dm, path = sys.argv[1:4]
src = open(path, encoding="utf-8").read()
for kv in sys.argv[4:]:
    k, v = kv.split("=", 1); src = src.replace("{{%s}}" % k, v)
f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
json.dump({"studio_id": sid, "datamodel_type": dm, "code": src}, f); f.close()
kit = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "roblox_kits", "tools", "mcpcli.py")
r = subprocess.run([sys.executable, kit, "call", "execute_luau", f.name], capture_output=True, text=True, encoding="utf-8", errors="replace",
                   timeout=float(os.environ.get("RUN_TIMEOUT", "400")))
sys.stdout.write(r.stdout); sys.stderr.write(r.stderr[-2000:]); os.unlink(f.name)
