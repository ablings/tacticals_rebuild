--[[ fix/check_hub1.lua : read-only checks after fix/place_hub1.lua (restores everything it touches).
Openings by rays against collision geometry, walk routes, hooks present, crane/drone path clearance, fidelity status. ]]
local LM = workspace.LobbyMap
local out = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(out, table.concat(t, " ")) end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end

-- solid world for players: everything that collides (characters collide only with CanCollide parts; rays use CanQuery,
-- and in this place every colliding kit part is queryable)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {}
rp.RespectCanCollide = true
local function ray(o, d) local r = workspace:Raycast(o, d, rp); return r end
local function span(o, axis, maxd)   -- free distance both ways along axis
	local a = ray(o, axis * maxd); local b = ray(o, -axis * maxd)
	local da = a and (a.Position - o).Magnitude or maxd; local db = b and (b.Position - o).Magnitude or maxd
	return da + db, a and a.Instance.Name or "-", b and b.Instance.Name or "-"
end
local function floorAt(x, z, top)
	local r = ray(Vector3.new(x, top or 30, z), Vector3.new(0, -60, 0)); return r and r.Position.Y, r and r.Instance:GetFullName()
end

-- 1. openings
say("== openings (need: gates 10.8 x 12.2, tunnel 22 x 18, duels door 11 x 8)")
for _, g in {{"N gate", 44.5}, {"S gate", -44.5}} do
	local z = g[2]
	for _, y in {1, 6, 11.5} do local w, a, b = span(Vector3.new(0, y, z), Vector3.xAxis, 30); say(g[1], "width @y" .. y, string.format("%.2f", w), a, b) end
	local up = ray(Vector3.new(0, 0.5, z), Vector3.new(0, 40, 0)); local fl = floorAt(0, z, 5)
	say(g[1], "floor", fl, "clear height", up and string.format("%.2f", up.Position.Y - (fl or 0)) or ">40", up and up.Instance.Name)
end
for _, x in {89, 96, 103} do
	for _, y in {1, 9, 17} do local w, a, b = span(Vector3.new(x, y, 0), Vector3.zAxis, 40); say("tunnel x" .. x, "width @y" .. y, string.format("%.2f", w), a, b) end
	local up = ray(Vector3.new(x, 0.5, 0), Vector3.new(0, 40, 0)); local fl = floorAt(x, 0, 5)
	say("tunnel x" .. x, "floor", fl, "clear", up and string.format("%.2f", up.Position.Y - (fl or 0)) or ">40", up and up.Instance.Name)
end
for _, x in {-89, -92} do
	for _, y in {16.5, 20, 23.5} do local w, a, b = span(Vector3.new(x, y, 0), Vector3.zAxis, 30); say("duels door x" .. x, "width @y" .. y, string.format("%.2f", w), a, b) end
	local fl = floorAt(x, 0, 20); local up = ray(Vector3.new(x, (fl or 16) + 0.3, 0), Vector3.new(0, 40, 0))
	say("duels door x" .. x, "floor", fl, "clear", up and string.format("%.2f", up.Position.Y - (fl or 16)) or ">40", up and up.Instance.Name)
end

-- 2. floors / routes
say("== floors")
for _, p in {{"spawn (0,4,0)", 0, 0}, {"disc r8", 8, 0}, {"hub mid", 40, 20}, {"hangar (112,3.5,0) from y8", 112, 0, 8}, {"riser foot", -73, 0},
	{"riser top", -77.5, 0}, {"landing", -84, -20}, {"stair top landing", -87, 0}, {"NPC_DuelsOfficer", -86.4, 8.5}, {"duels floor", -100, 0}} do
	local y, who = floorAt(p[2], p[3], p[4] or 30); say(p[1], y and string.format("%.2f", y), who)
end
say("stairs profile (x -88, z 40 -> 10):")
local prof = {}
for z = 42, 8, -1 do local y = floorAt(-88, z, 30); table.insert(prof, string.format("%d:%.1f", z, y or -99)) end
say(table.concat(prof, " "))
prof = {}
for x = -66, -92, -1 do local y = floorAt(x, 0, 30); table.insert(prof, string.format("%d:%.1f", x, y or -99)) end
say("west route (z 0):", table.concat(prof, " "))
-- headroom on stairs (box cast 2x5x2 a stud above the treads)
local bad = 0
for z = 40, 10, -2 do
	local y = floorAt(-88, z, 30) or 0
	local hits = workspace:GetPartBoundsInBox(CFrame.new(-88, y + 3.2, z), Vector3.new(1.8, 5, 1.8), (function() local o = OverlapParams.new(); o.RespectCanCollide = true; return o end)())
	for _, h in hits do if h.CanCollide then bad += 1; if bad < 6 then say("  stair box hit", z, h:GetFullName()) end end end
end
say("stair headroom box hits (AABB, may over-report):", bad)

-- 3. hooks
say("== hooks")
for _, n in {"FX", "Heli", "NPCs", "Duels", "Exfil", "Training", "Showroom", "Signs", "Interact", "Props", "Unique", "Instances", "HubProps", "Clutter", "Hub1"} do
	say(n, LM:FindFirstChild(n) and "ok" or "MISSING")
end
local nsp = 0; for _, c in LM:GetChildren() do if c.Name == "LobbySpawn" then nsp += 1; say("LobbySpawn", f3(c.Position), "enabled", c.Enabled) end end
say("LobbySpawn count", nsp)
for _, n in {"U_Floor__floor_metal", "U_Floor__grate", "U_Floor__dark_metal", "U_SpawnDisc__spawn_logo"} do
	local p = LM.Unique:FindFirstChild(n); say("AssetCheck", n, p and ("present T=" .. p.Transparency) or "MISSING")
end
local CS = game:GetService("CollectionService")
say("QueuePad tagged", #CS:GetTagged("QueuePad"), "ExfilBarrier", #CS:GetTagged("ExfilBarrier"), "RoomLight", #CS:GetTagged("RoomLight"))
local eb = LM.Exfil:FindFirstChild("ExfilBarrier"); say("ExfilBarrier", eb and (f3(eb.Position) .. " touch " .. tostring(eb.CanTouch)) or "missing")
for _, n in {"HatchPoint", "CabinPoint"} do say(n, LM.Exfil:FindFirstChild(n) and "ok" or "MISSING") end
for _, p in LM.Interact:GetDescendants() do if p:IsA("ProximityPrompt") then say("prompt", p.Parent:GetFullName(), p:GetAttribute("OpenPanel")) end end
for _, n in LM.NPCs:GetChildren() do local h = n:FindFirstChild("HumanoidRootPart"); say("NPC", n.Name, h and f3(h.Position)) end
local fx = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("LobbyFX")
say("LobbyFX pulse y 0.08:", fx and fx.Source:find("CFrame.new(x, 0.08, s.z)", 1, true) ~= nil)
-- Interact prompt parts not buried: check a ray from the hall/room to each
-- 4. crane / drone clearance against the new kit (temporarily queryable, restored after)
say("== crane / drone")
local hub = LM.Hub1
local saved = {}
for _, d in hub:GetDescendants() do if d:IsA("BasePart") then saved[d] = d.CanQuery; d.CanQuery = true end end
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = {hub}
local function sweep(model, poses, label)
	if not model or not model.PrimaryPart then say(label, "missing or no PrimaryPart"); return end
	local orig = model:GetPivot(); local hitset = {}
	for _, cf in poses do
		model:PivotTo(cf)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				for _, h in workspace:GetPartsInPart(part, op) do hitset[h.Name] = (hitset[h.Name] or 0) + 1 end
			end
		end
	end
	model:PivotTo(orig)
	local s = {}; for k, v in hitset do table.insert(s, k .. " x" .. v) end
	say(label, #poses, "poses; hits:", #s == 0 and "none" or table.concat(s, ", "))
end
local crane = LM.Props:FindFirstChild("Crane")
local cp = {}
for i = 0, 40 do cp[#cp + 1] = CFrame.new(crane and crane:GetAttribute("x") or 21.25, 57, -34 + i * 68 / 40) end
sweep(crane, cp, "Crane")
local drone = LM.Props:FindFirstChild("Drone"); local dp = {}
local DY = tonumber(fx and fx.Source:match("Vector3%.new%(math%.sin%(a%) %* 62, (%d+) %+")) or 22
say("drone loop centre y (from LobbyFX source)", DY)
for i = 0, 199 do
	local a = i / 200 * math.pi * 2 * 5 -- covers the 2.3x / 2x harmonics
	local pos = Vector3.new(math.sin(a) * 62, DY + math.sin(a * 2.3) * 3, math.sin(a * 2) * 26)
	local nxt = Vector3.new(math.sin(a + 0.05) * 62, DY + math.sin((a + 0.05) * 2.3) * 3, math.sin((a + 0.05) * 2) * 26)
	dp[#dp + 1] = CFrame.lookAt(pos, nxt) * CFrame.Angles(0, -math.pi / 2, 0)
end
sweep(drone, dp, "Drone")
for p, q in saved do p.CanQuery = q end

-- 5. collision fidelity status
local cnt = {}
for _, d in hub:GetDescendants() do if d:IsA("MeshPart") and d.CanCollide then cnt[d.CollisionFidelity.Name] = (cnt[d.CollisionFidelity.Name] or 0) + 1 end end
for k, v in cnt do say("fidelity", k, v) end
return table.concat(out, "\n")
