"""Create or update a LocalScript in StarterPlayer.StarterPlayerScripts from a repo file (attribute RepoSource = the file).
Usage: python tools/install_localscript.py <lobby|match|studio_id> <Name> <repo file> [UNDO] [--server: a Script in ServerScriptService]"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "d93b3ec2-422d-40e2-87ce-6dd7b5c4e24c", "match": "f297bc30-46c5-414e-a250-d1593301e5a0"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sid = SIDS.get(sys.argv[1], sys.argv[1]); name, f = sys.argv[2], sys.argv[3]
src = open(os.path.join(ROOT, f), encoding="utf-8").read().replace("\r\n", "\n")
n = 1
while ("]" + "=" * n + "]") in src: n += 1
lit = "[" + "=" * n + "[" + src + "]" + "=" * n + "]"
undo = "UNDO" in sys.argv
server = "--server" in sys.argv
parent = 'game:GetService("ServerScriptService")' if server else 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")'
cls = "Script" if server else "LocalScript"
code = f'''local sps = {parent}
local s = sps:FindFirstChild({json.dumps(name)})
if {str(undo).lower()} then
	if s and s:GetAttribute("RepoSource") then s:Destroy() return "removed" end
	return "not ours / not there"
end
if s and not s:GetAttribute("RepoSource") then return "EXISTS and is not ours" end
local src = {lit}
local fn, err = loadstring(src)
if not fn then return "SYNTAX " .. tostring(err) end
if not s then s = Instance.new("{cls}"); s.Name = {json.dumps(name)}; s.Parent = sps end
s:SetAttribute("RepoSource", {json.dumps(f)})
s.Source = src
return "installed " .. s:GetFullName()'''
fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                   env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
os.remove(p); print(r.stdout.strip() or r.stderr[-800:])
