"""Push one repo source file into one ModuleScript / Script, safely: only when the live Source still equals the file's committed
version (git HEAD), so nobody's live edits are overwritten. --check only compares.
Usage: python tools/push_module.py <lobby|match|studio_id> <Instance.Path> <repo file> [--check] [--force: skip the HEAD check, only for a module you just pushed yourself]"""
import json, os, subprocess, sys, tempfile
SIDS = {"lobby": "63f7832a-a0f3-42a5-97a5-34139db0ba2b", "match": "2f647323-e1f0-47f0-b336-38337f383a2e"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

LUA = r'''local HS = game:GetService("HttpService")
local a = HS:JSONDecode(__DATA__)
local inst = game
for part in string.gmatch(a.path, "[^%.]+") do inst = inst and inst:FindFirstChild(part) end
if not inst then return "NOT FOUND " .. a.path end
local CR = string.char(13)
local function norm(s) return ((s:gsub(CR, "")):gsub("%s+$", "")) end
local live = norm(inst.Source)
if live == norm(a.new) then return "already up to date" end
if live ~= norm(a.old) and not a.force then return "LIVE DIFFERS from HEAD: not pushed (len live " .. #live .. ", head " .. #a.old .. ")" end
if a.check then return "live == HEAD: ok to push" end
local f, err = loadstring(a.new)
if not f then return "SYNTAX " .. tostring(err) end
inst.Source = a.new
return "pushed " .. a.path'''


def long_string(s):
    n = 1
    while ("]" + "=" * n + "]") in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


def main():
    sid = SIDS.get(sys.argv[1], sys.argv[1])
    path, f = sys.argv[2], sys.argv[3].replace("\\", "/")
    new = open(os.path.join(ROOT, f), encoding="utf-8").read().replace("\r\n", "\n")
    old = subprocess.run(["git", "-C", ROOT, "show", "HEAD:" + f], capture_output=True, text=True, encoding="utf-8").stdout.replace("\r\n", "\n")
    data = json.dumps({"path": path, "new": new, "old": old, "check": "--check" in sys.argv, "force": "--force" in sys.argv})
    code = LUA.replace("__DATA__", long_string(data))
    fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(p, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="300"))
    os.remove(p)
    print(r.stdout.strip() or r.stderr[-800:])


main()
