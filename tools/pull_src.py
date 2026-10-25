"""Pull named scripts' Source (read-only) from a Studio into out/pull_<tag>/<full.name>.lua.
Usage: python tools/pull_src.py <studio_id> <tag> <name> [<name> ...]   (matches Instance.Name exactly; every match is saved)"""
import json, os, subprocess, sys, tempfile
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
sid, tag, names = sys.argv[1], sys.argv[2], sys.argv[3:]
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "pull_" + tag)
os.makedirs(ROOT, exist_ok=True)
code = '''local want = game:GetService("HttpService"):JSONDecode([=[%s]=])
local set = {}
for _, n in want do set[n] = true end
local out = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") and set[d.Name] then
		local ok, f = pcall(function() return d:GetFullName() end)
		if ok then out[f] = d.Source end
	end
end
return game:GetService("HttpService"):JSONEncode(out)''' % json.dumps(names)
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p)
txt = r.stdout.strip()
if "{" not in txt: sys.exit("raw: " + txt[:600] + r.stderr[-600:])
try:
    data = json.loads(txt)
except Exception:
    if len(names) > 1:
        for n in names: subprocess.run([sys.executable, __file__, sid, tag, n])
        sys.exit(0)
    sys.exit("fail " + names[0] + " " + str(len(txt)) + " " + txt[:200])
for full, src in data.items():
    fn = os.path.join(ROOT, full.replace("/", "_").replace(":", "_") + ".lua")
    with open(fn, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print(len(src), full)
