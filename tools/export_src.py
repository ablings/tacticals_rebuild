"""Export every live script's Source (read-only) to out/src_<place>/<full.name>.lua for offline auditing.
Usage: python tools/export_src.py lobby|match   (skips ServerStorage backups _RebuildRemoved/_Pre*/_MainGame*)"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "63f7832a-a0f3-42a5-97a5-34139db0ba2b", "match": "2f647323-e1f0-47f0-b336-38337f383a2e"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
place = sys.argv[1]
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "src_" + place)
os.makedirs(ROOT, exist_ok=True)
LIST = '''local out = {}
for _, r in ipairs({"Workspace","ReplicatedFirst","ReplicatedStorage","ServerScriptService","ServerStorage","StarterGui","StarterPack","StarterPlayer"}) do
	for _, d in ipairs(game:GetService(r):GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			local f = d:GetFullName()
			if not (f:find("_RebuildRemoved",1,true) or f:find("ServerStorage._Pre",1,true) or f:find("_MainGame",1,true) or f:find("_Old",1,true) or f:find("_Before",1,true)) then table.insert(out, f) end
		end
	end
end
return game:GetService("HttpService"):JSONEncode(out)'''
def run(code):
    fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": SIDS[place], "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    os.remove(p)
    return r.stdout.strip()
names = json.loads(run(LIST))
print(len(names), "scripts")
BATCH = 15
def fetch(chunk):
    code = '''local HS = game:GetService("HttpService")
local names = HS:JSONDecode(%s)
local out = {}
local function find(path)
	local parts = string.split(path, ".")
	local cur = game:GetService(parts[1])
	local i = 2
	while cur and i <= #parts do
		local found = nil
		for j = #parts, i, -1 do
			local nm = table.concat(parts, ".", i, j)
			local c = cur:FindFirstChild(nm)
			if c then found = c; i = j + 1; break end
		end
		cur = found
	end
	return cur
end
for _, n in ipairs(names) do local s = find(n); out[n] = s and s.Source or "--NOTFOUND" end
return HS:JSONEncode(out)''' % json.dumps(json.dumps(chunk))
    res = run(code)
    try:
        d = json.loads(res)
    except Exception:
        if len(chunk) > 1:
            for n in chunk: fetch([n])
        else:
            print("fail", chunk[0], len(res))
        return
    for n, s in d.items():
        fn = "".join(c if c.isalnum() or c in "._-[] " else "_" for c in n)[:180] + ".lua"
        open(os.path.join(ROOT, fn), "w", encoding="utf-8", newline="\n").write(s)
for i in range(0, len(names), BATCH):
    fetch(names[i:i + BATCH])
print("done ->", ROOT)
