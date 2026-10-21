"""[PSEUDOLOBBY] Build the after-match lobby into a match place copy (post-match phase 2, notes/postmatch.md).
Usage: python tools/pseudolobby_build.py server [match|studio_id] [UNDO]   lobby server systems + PseudoLobby + remotes
       python tools/pseudolobby_build.py map    [match|studio_id] [lobby_id]  copy the hub's LobbyMap + Lighting (Edit only)
       python tools/pseudolobby_build.py hooks  [match|studio_id] [UNDO]   fix/pseudolobby_install.lua (RoundManager, SettingsBridge)
       python tools/pseudolobby_build.py assets [match|studio_id] [lobby_id]  hub instances the lobby client scripts need + PseudoLobbyMap=false
Everything it creates carries attribute PseudoLobbyNew (scripts: RepoSource too); UNDO removes exactly those.
The map travels as SerializationService bytes, base64 in 90 KB slices (the Studio bridge caps a result at 100 KB):
lobby shared.__PseudoLobbyB64 -> here (out/pseudolobby_map.b64, a local check copy) -> match shared.__PseudoLobbyIn ->
DeserializeInstancesAsync. (HttpService is off in the match place, so no local HTTP fetch.)"""
import base64, json, os, subprocess, sys, tempfile
SIDS = {"lobby": "835403f5-1c18-4451-b6da-d25ee5c2f672", "match": "221cdf09-8c72-40c3-83ef-afb3ad146aac"}
CLI = r"C:\Users\aroki\Documents\rivals_practice\mcpcli.py"
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SERVE_DIR = os.path.join(ROOT, "out")   # local check copy of the map bytes (base64)
OFFSET = (0, 0, 2600)  # hub copy sits here: clear of the match map (Warehouse is inside the hub's footprint) and the baseplate

def call(sid, code, mode="Edit"):
    fd, p = tempfile.mkstemp(suffix=".json"); os.close(fd)
    json.dump({"studio_id": sid, "datamodel_type": mode, "code": code}, open(p, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, CLI, "call", "execute_luau", p], capture_output=True, text=True, encoding="utf-8",
                       env=dict(os.environ, PYTHONIOENCODING="utf-8", MCP_TIMEOUT="600"))
    os.remove(p)
    return (r.stdout.strip() or r.stderr[-800:])

def lit(src):
    n = 1
    while ("]" + "=" * n + "]") in src: n += 1
    return "[" + "=" * n + "[" + src + "]" + "=" * n + "]"

MGR = "ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers"
SCRIPTS = [  # (class, parent path, name, repo file)
    ("ModuleScript", "ServerScriptService.Data", "PlayerStore", "scripts/pseudolobby/server/PlayerStore.lua"),
    ("ModuleScript", "ServerScriptService.Lobby", "LobbyRemotes", "scripts/pseudolobby/server/LobbyRemotes.lua"),
    ("ModuleScript", "ServerScriptService.Lobby", "LobbyCodes", "scripts/pseudolobby/server/LobbyCodes.lua"),
    ("ModuleScript", "ServerScriptService.Shared", "PartyService", "scripts/pseudolobby/server/PartyService.lua"),
    ("ModuleScript", "ServerScriptService.Shared", "PseudoLobby", "scripts/pseudolobby/PseudoLobby.lua"),
    ("ModuleScript", "ReplicatedStorage.Modules.Shared.Config", "LobbyFeaturesConfig", "scripts/pseudolobby/server/LobbyFeaturesConfig.lua"),
    ("Script", "ServerScriptService", "VipPerks", "scripts/pseudolobby/server/VipPerks.lua"),
    ("Script", "ServerScriptService", "PublicStats", "scripts/pseudolobby/server/PublicStats.lua"),
    ("Script", "ServerScriptService", "LobbyLeaderboard", "scripts/pseudolobby/server/LobbyLeaderboard.lua"),
    ("Script", "ServerScriptService", "LobbyNPCs", "scripts/pseudolobby/server/LobbyNPCs.lua"),
    ("Script", "ServerScriptService", "LobbyParty", "scripts/pseudolobby/server/LobbyParty.lua"),
    ("Script", "ServerScriptService", "LobbySocial", "scripts/pseudolobby/server/LobbySocialStub.lua"),
    # last: the ModuleLoader starts every module under [Server] Init, and this one needs the ones above
    ("ModuleScript", MGR, "LobbyManager", "scripts/pseudolobby/server/LobbyManager.lua"),
]

PATH_FN = '''local function at(path, create)
	local o = game
	for part in string.gmatch(path, "[^%.]+") do
		local c = (o == game) and game:GetService(part) or o:FindFirstChild(part)
		if not c and create then c = Instance.new("Folder"); c.Name = part; c:SetAttribute("PseudoLobbyNew", true); c.Parent = o end
		o = c
		if not o then return nil end
	end
	return o
end
'''

def server(sid, undo):
    assert "LobbyMap = nil" in call(sid, 'return "LobbyMap = " .. tostring(workspace:FindFirstChild("LobbyMap"))'), "not a match place"
    if undo:
        template_undo(sid)
        code = PATH_FN + '''local out = {}
for _, root in { game.ServerScriptService, game.ReplicatedStorage, game.ServerStorage, game:GetService("SoundService") } do
	for _, d in root:GetDescendants() do
		if d.Parent and d:GetAttribute("PseudoLobbyNew") then table.insert(out, d:GetFullName()); d:Destroy() end
	end
end
return "removed " .. #out .. ": " .. table.concat(out, ", ")'''
        print(call(sid, code)); return
    # remotes + values the lobby code waits for
    print(call(sid, PATH_FN + '''local out = {}
local folder = at("ReplicatedStorage.Events.Lobby", true)
for name, cls in { Request = "RemoteFunction", QueueState = "RemoteEvent", Notify = "RemoteEvent" } do
	if not folder:FindFirstChild(name) then local r = Instance.new(cls); r.Name = name; r:SetAttribute("PseudoLobbyNew", true); r.Parent = folder; table.insert(out, name) end
end
if not game.ReplicatedStorage:FindFirstChild("LobbyTopWins") then
	local v = Instance.new("StringValue"); v.Name = "LobbyTopWins"; v.Value = "[]"; v:SetAttribute("PseudoLobbyNew", true); v.Parent = game.ReplicatedStorage; table.insert(out, "LobbyTopWins")
end
return "remotes: " .. (#out > 0 and table.concat(out, ", ") or "already there")'''))
    for cls, parent, name, f in SCRIPTS:
        src = open(os.path.join(ROOT, f), encoding="utf-8").read().replace("\r\n", "\n")
        code = PATH_FN + f'''local parent = at({json.dumps(parent)}, true)
local m = parent:FindFirstChild({json.dumps(name)})
if m and not m:GetAttribute("RepoSource") then return "SKIP {name}: exists and is not ours" end
local src = {lit(src)}
local fn, err = loadstring(src)
if not fn then return "SYNTAX {name}: " .. tostring(err) end
if not m then m = Instance.new({json.dumps(cls)}); m.Name = {json.dumps(name)}; m:SetAttribute("PseudoLobbyNew", true); m.Parent = parent end
m:SetAttribute("RepoSource", {json.dumps(f)})
m.Source = src
return "installed " .. m:GetFullName()'''
        print(call(sid, code))
    # modules the match place already has, swapped for the hub's version (the original Source kept for UNDO):
    #   the profile template (the match's had only ProfileVersion: a profile first made there lacked Quests etc.),
    #   LobbyConfig (the match's was older: no GamePasses / QueueById, TutorialPlaceId of the old combined place)
    for path, f in REPLACE:
        src = open(os.path.join(ROOT, f), encoding="utf-8").read().replace("\r\n", "\n")
        print(call(sid, PATH_FN + f'''local t = at({json.dumps(path)})
if t:GetAttribute("PseudoLobbyOriginal") == nil then t:SetAttribute("PseudoLobbyOriginal", t.Source) end
local src = {lit(src)}
assert(loadstring(src), "syntax")
t.Source = src
t:SetAttribute("RepoSource", {json.dumps(f)})
return "replaced " .. t:GetFullName()'''))

REPLACE = [
    ("ServerScriptService.Data.DataManager.Template", "scripts/pseudolobby/server/Template.lua"),
    ("ReplicatedStorage.Modules.Shared.Config.LobbyConfig", "scripts/pseudolobby/server/LobbyConfig.lua"),
]

def template_undo(sid):
    for path, f in REPLACE:
        print(call(sid, PATH_FN + f'''local t = at({json.dumps(path)})
local o = t and t:GetAttribute("PseudoLobbyOriginal")
if o == nil then return "not ours: {path}" end
t.Source = o; t:SetAttribute("PseudoLobbyOriginal", nil); t:SetAttribute("RepoSource", nil)
return "restored " .. t:GetFullName()'''))

EXPORT = '''local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local SS = game:GetService("SerializationService")
local OFFSET = Vector3.new(%d, %d, %d)
local map = workspace.LobbyMap:Clone()
-- not on the match server: Training (and its 4.8k parts) lives behind the heli; the Animate LocalScripts never run in Workspace
local tr = map:FindFirstChild("Training"); if tr then tr:Destroy() end
-- tags the match place's code would pick up
local stripped = 0
for _, d in map:GetDescendants() do
	for _, t in { "QueuePad", "ExfilBarrier", "DuelArena", "AimAssistTarget" } do
		if CS:HasTag(d, t) then CS:RemoveTag(d, t); stripped += 1 end
	end
end
if CS:HasTag(map, "DuelArena") then CS:RemoveTag(map, "DuelArena") end
-- move everything OFFSET away (models by pivot, loose parts by CFrame; welded parts move with their model)
local function shift(inst)
	for _, c in inst:GetChildren() do
		if c:IsA("Model") then c:PivotTo(c:GetPivot() + OFFSET)
		elseif c:IsA("BasePart") then c.CFrame = c.CFrame + OFFSET
		else shift(c) end
	end
end
shift(map)
-- the duel pads and the Exfil hatch: barricaded (RIVALS keeps them visible but closed after a match)
local function barricade(cf, size, label, parent)
	local b = Instance.new("Part")
	b.Name = "PseudoLobbyBarricade"; b.Anchored = true; b.CanCollide = true; b.CanQuery = false; b.CanTouch = false
	b.CFrame = cf; b.Size = size; b.Material = Enum.Material.ForceField; b.Color = Color3.fromRGB(196, 72, 52)
	b.Transparency = 0.35; b.CastShadow = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 20
		g.LightInfluence = 0; g.Parent = b
		local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.3); l.Position = UDim2.fromScale(0, 0.35)
		l.Text = label; l.TextScaled = true; l.TextColor3 = Color3.fromRGB(236, 232, 218)
		l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); l.Parent = g
	end
	b.Parent = parent
	return b
end
local n = 0
local duels = map:FindFirstChild("Duels")
for _, pad in (duels and duels:GetChildren() or {}) do
	if pad:IsA("Model") and pad:GetAttribute("QueueName") then
		local cf, size = pad:GetBoundingBox()
		barricade(cf, Vector3.new(size.X + 1, math.max(size.Y, 10) + 2, size.Z + 1), "AVAILABLE IN THE HUB", pad)
		n += 1
	end
end
local exfil = map:FindFirstChild("Exfil")
if exfil then
	-- a Folder (no GetBoundingBox): the world box of its parts
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, d in exfil:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			mn = mn:Min(d.Position - h); mx = mx:Max(d.Position + h)
		end
	end
	local cf, size = CFrame.new((mn + mx) / 2), mx - mn
	barricade(cf, size + Vector3.new(2, 2, 2), "TRAINING: IN THE HUB", exfil)
	n += 1
end
local sp = map:FindFirstChild("LobbySpawn")
if sp and sp:IsA("SpawnLocation") then sp.Enabled = false end
-- the hub's lighting: children + properties (as attributes on the folder)
local light = Instance.new("Folder"); light.Name = "Lighting"
for _, c in game.Lighting:GetChildren() do
	if c:IsA("PostEffect") or c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("Clouds") then c:Clone().Parent = light end
end
for _, k in { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude", "ExposureCompensation",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ColorShift_Top", "ColorShift_Bottom", "FogColor", "FogEnd", "FogStart",
	"GlobalShadows", "ShadowSoftness" } do
	local ok, v = pcall(function() return game.Lighting[k] end)
	if ok then light:SetAttribute(k, v) end
end
local buf = SS:SerializeInstancesAsync({ map, light })
map:Destroy(); light:Destroy()
local raw = buffer.tostring(buf)
-- base64 (Luau has no built-in one)
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local t = {}
for i = 1, #raw, 3 do
	local a, b, c = string.byte(raw, i, i + 2)
	local v = a * 65536 + (b or 0) * 256 + (c or 0)
	local q = { bit32.extract(v, 18, 6), bit32.extract(v, 12, 6), bit32.extract(v, 6, 6), bit32.extract(v, 0, 6) }
	t[#t + 1] = A:sub(q[1] + 1, q[1] + 1) .. A:sub(q[2] + 1, q[2] + 1) .. (b and A:sub(q[3] + 1, q[3] + 1) or "=") .. (c and A:sub(q[4] + 1, q[4] + 1) or "=")
end
-- the Studio bridge caps a result at 100 KB: keep the text in shared and hand it out in slices (CHUNK)
shared.__PseudoLobbyB64 = table.concat(t)
return HS:JSONEncode({ len = #shared.__PseudoLobbyB64, bytes = #raw, barricades = n, tags = stripped })'''

IMPORT = '''local HS = game:GetService("HttpService")
local SS = game:GetService("SerializationService")
assert(not workspace:FindFirstChild("LobbyMap"), "this is the lobby")
local b64 = table.concat(shared.__PseudoLobbyIn or {}) -- pushed in slices by build_map (HttpService is off in the match place)
shared.__PseudoLobbyIn = nil
local D = {}
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, 64 do D[string.byte(A, i)] = i - 1 end
local out = {}
b64 = b64:gsub("[^%%w%%+/=]", "")
for i = 1, #b64, 4 do
	local c1, c2, c3, c4 = string.byte(b64, i, i + 3)
	local v = D[c1] * 262144 + D[c2] * 4096 + (D[c3] or 0) * 64 + (D[c4] or 0)
	out[#out + 1] = string.char(bit32.extract(v, 16, 8))
	if c3 ~= 61 then out[#out + 1] = string.char(bit32.extract(v, 8, 8)) end
	if c4 ~= 61 then out[#out + 1] = string.char(bit32.extract(v, 0, 8)) end
end
local raw = table.concat(out)
assert(#raw == %d, "size " .. #raw)
local list = SS:DeserializeInstancesAsync(buffer.fromstring(raw))
local store = game.ServerStorage:FindFirstChild("PseudoLobby")
if store then store:Destroy() end
store = Instance.new("Folder"); store.Name = "PseudoLobby"; store:SetAttribute("PseudoLobbyNew", true)
store:SetAttribute("Offset", Vector3.new(%d, %d, %d)); store:SetAttribute("BuiltAt", os.time())
for _, inst in list do inst.Parent = store end
store.Parent = game.ServerStorage
local n = 0
for _, _ in store:GetDescendants() do n += 1 end
local m = store:FindFirstChild("LobbyMap")
local sp = m and m:FindFirstChild("LobbySpawn")
return ("PseudoLobby: %%d instances, LobbyMap=%%s, LobbySpawn=%%s, Lighting children=%%d"):format(n, tostring(m ~= nil),
	sp and tostring(sp.Position) or "nil", store:FindFirstChild("Lighting") and #store.Lighting:GetChildren() or -1)'''

def build_map(sid, lobby):
    r = call(lobby, EXPORT % OFFSET)
    try:
        d = json.loads(r)
    except Exception:
        print("export failed:", r[:800]); sys.exit(1)
    CHUNK = 90000
    parts = []
    for i in range(0, d["len"], CHUNK):
        part = call(lobby, f"return string.sub(shared.__PseudoLobbyB64, {i + 1}, {i + CHUNK})")
        assert len(part) == min(CHUNK, d["len"] - i), f"slice {i}: got {len(part)}"
        parts.append(part)
    call(lobby, "shared.__PseudoLobbyB64 = nil return 1")
    d["b64"] = "".join(parts)
    raw = base64.b64decode(d["b64"])
    assert len(raw) == d["bytes"], "base64 mismatch"
    os.makedirs(SERVE_DIR, exist_ok=True)
    open(os.path.join(SERVE_DIR, "pseudolobby_map.b64"), "w").write(d["b64"])
    print(f"exported {d['bytes']} bytes, {d['barricades']} barricades, {d['tags']} tags stripped")
    call(sid, "shared.__PseudoLobbyIn = {} return 1")
    b64 = d["b64"]
    for i in range(0, len(b64), CHUNK):
        r = call(sid, 'table.insert(shared.__PseudoLobbyIn, "' + b64[i:i + CHUNK] + '") return #shared.__PseudoLobbyIn')
        assert r.strip().isdigit(), r[:300]
    print(call(sid, IMPORT % (d["bytes"], *OFFSET)))

# hub instances the lobby CLIENT scripts need in the match place (UI session, 2026-10-18); copied to the same parent path,
# only where that name is missing, each tagged PseudoLobbyNew
ASSETS = ["ReplicatedStorage.Repository.Scissors", "ReplicatedStorage.LobbyAssets", "SoundService.Effects",
          "ReplicatedStorage.Modules.Shared.Config.TrainingConfig"]
ENCODE_TAIL = EXPORT[EXPORT.index("local raw = buffer.tostring(buf)"):EXPORT.index("return HS:JSONEncode")]
DECODE_HEAD = IMPORT[IMPORT.index("local b64 = table.concat"):IMPORT.index("local list = SS:Deserialize")]

def transfer(src_sid, dst_sid, export_code, import_code_fmt):
    """export_code leaves its base64 in shared.__PseudoLobbyB64 and returns JSON {len, bytes, ...}; import_code_fmt gets %d bytes."""
    d = json.loads(call(src_sid, export_code))
    CHUNK = 90000
    parts = [call(src_sid, f"return string.sub(shared.__PseudoLobbyB64, {i + 1}, {i + CHUNK})") for i in range(0, d["len"], CHUNK)]
    call(src_sid, "shared.__PseudoLobbyB64 = nil return 1")
    b64 = "".join(parts)
    assert len(base64.b64decode(b64)) == d["bytes"], "base64 mismatch"
    call(dst_sid, "shared.__PseudoLobbyIn = {} return 1")
    for i in range(0, len(b64), CHUNK):
        r = call(dst_sid, 'table.insert(shared.__PseudoLobbyIn, "' + b64[i:i + CHUNK] + '") return #shared.__PseudoLobbyIn')
        assert r.strip().isdigit(), r[:300]
    return d, call(dst_sid, import_code_fmt % d["bytes"])

def assets(sid, lobby):
    export = PATH_FN + '''local HS = game:GetService("HttpService")
local SS = game:GetService("SerializationService")
local list = {}
for _, p in HS:JSONDecode(%s) do
	local o = at(p)
	if o then
		local c = o:Clone()
		c:SetAttribute("PseudoLobbyPath", p:match("^(.*)%%.[^%%.]+$"))
		c:SetAttribute("PseudoLobbyNew", true)
		table.insert(list, c)
	end
end
local buf = SS:SerializeInstancesAsync(list)
for _, c in list do c:Destroy() end
''' % lit(json.dumps(ASSETS)) + ENCODE_TAIL + '''shared.__PseudoLobbyB64 = table.concat(t)
return HS:JSONEncode({ len = #shared.__PseudoLobbyB64, bytes = #raw, count = #list })'''
    imp = PATH_FN.replace("%", "%%") + '''local SS = game:GetService("SerializationService")
''' + DECODE_HEAD.replace("%%", "%") .replace("%", "%%").replace("%%d", "%d") + '''local list = SS:DeserializeInstancesAsync(buffer.fromstring(raw))
local out = {}
for _, inst in list do
	local parent = at(inst:GetAttribute("PseudoLobbyPath"), true)
	if parent:FindFirstChild(inst.Name) then table.insert(out, inst.Name .. " (already there)"); inst:Destroy()
	else inst.Parent = parent; table.insert(out, inst:GetFullName()) end
end
return "assets: " .. table.concat(out, ", ")'''
    d, r = transfer(lobby, sid, export, imp)
    print(f"{d['count']} assets, {d['bytes']} bytes"); print(r)
    # the UI contract: a match place says PseudoLobbyMap = false until the map is out (saved in the place)
    print(call(sid, 'if game.ReplicatedStorage:GetAttribute("PseudoLobbyMap") == nil then game.ReplicatedStorage:SetAttribute("PseudoLobbyMap", false) end return "PseudoLobbyMap = " .. tostring(game.ReplicatedStorage:GetAttribute("PseudoLobbyMap"))'))

def hooks(sid, undo):
    code = open(os.path.join(ROOT, "fix", "pseudolobby_install.lua"), encoding="utf-8").read()
    if undo: code = code.replace("local UNDO = false --@UNDO", "local UNDO = true --@UNDO")
    print(call(sid, code))

if __name__ == "__main__":
    step = sys.argv[1]
    sid = SIDS.get(sys.argv[2], sys.argv[2]) if len(sys.argv) > 2 else SIDS["match"]
    undo = "UNDO" in sys.argv
    if step == "server": server(sid, undo)
    elif step == "map": build_map(sid, SIDS.get(sys.argv[3], sys.argv[3]) if len(sys.argv) > 3 else SIDS["lobby"])
    elif step == "hooks": hooks(sid, undo)
    elif step == "assets": assets(sid, SIDS.get(sys.argv[3], sys.argv[3]) if len(sys.argv) > 3 else SIDS["lobby"])
    else: print(__doc__)
