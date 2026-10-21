"""Create or update a ModuleScript from a repo file (attribute RepoSource = the file). Refuses a module it didn't create.
Usage: python tools/install_module.py <lobby|match|studio_id> <Parent.Path> <Name> <repo file> [UNDO]"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "ddbec6a6-8f28-4bef-9054-7be5bea3e83a", "match": "7a8bab8a-3a9c-479b-b323-38d82789723b"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sid = SIDS.get(sys.argv[1], sys.argv[1]); parent, name, f = sys.argv[2], sys.argv[3], sys.argv[4]
src = open(os.path.join(ROOT, f), encoding="utf-8").read().replace("\r\n", "\n")
n = 1
while ("]" + "=" * n + "]") in src: n += 1
lit = "[" + "=" * n + "[" + src + "]" + "=" * n + "]"
undo = "UNDO" in sys.argv
code = f'''local parent = game
for part in string.gmatch({json.dumps(parent)}, "[^%.]+") do parent = parent and parent:FindFirstChild(part) end
if not parent then return "parent not found: " .. {json.dumps(parent)} end
local m = parent:FindFirstChild({json.dumps(name)})
if {str(undo).lower()} then
	if m and m:GetAttribute("RepoSource") then m:Destroy() return "removed" end
	return "not ours / not there"
end
if m and not m:GetAttribute("RepoSource") then return "EXISTS and is not ours" end
local src = {lit}
local fn, err = loadstring(src)
if not fn then return "SYNTAX " .. tostring(err) end
if not m then m = Instance.new("ModuleScript"); m.Name = {json.dumps(name)}; m.Parent = parent end
m:SetAttribute("RepoSource", {json.dumps(f)})
m.Source = src
return "installed " .. m:GetFullName()'''
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p); print(r.stdout.strip() or r.stderr[-800:])
