"""Push ONE [SET] client module (ui/set/<Name>.lua) into a Studio's StarterPlayerScripts.Client.Controllers.<Name>, without a full
deploy_ui run (used for a single fix while the UI session works elsewhere). Usage: python tools/push_set.py <lobby|match|id> <Name>"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "5e5685e4-6afe-4dde-b307-dd6c67c0a85d", "match": "7a8bab8a-3a9c-479b-b323-38d82789723b"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sid = SIDS.get(sys.argv[1], sys.argv[1]); name = sys.argv[2]
src = open(os.path.join(ROOT, "ui", "set", name + ".lua"), encoding="utf-8").read().replace("\r\n", "\n")
n = 1
while ("]" + "=" * n + "]") in src: n += 1
lit = "[" + "=" * n + "[" + src + "]" + "=" * n + "]"
code = ("local m = game.StarterPlayer.StarterPlayerScripts.Client.Controllers:FindFirstChild(%s, true)\n" % json.dumps(name)
        + "if not m then return 'no such controller' end\nlocal src = " + lit
        + "\nlocal f, err = loadstring(src)\nif not f then return 'SYNTAX ' .. tostring(err) end\nm.Source = src\nreturn 'pushed ' .. m:GetFullName() .. ' ' .. #src")
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8", env=dict(os.environ, PYTHONIOENCODING="utf-8"))
os.remove(p); print(r.stdout.strip() or r.stderr[-500:])
