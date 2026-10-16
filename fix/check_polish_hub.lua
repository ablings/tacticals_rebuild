-- check_polish_hub.lua (read-only; restores what it toggles): logic checks for Polish.Hub (fix/polish_hub.lua) and the
-- lobby-wide olive tone (fix/polish_olive.lua).
-- 1. clip (rays): from each visible new part's centre to its 6 face centres and 8 corners (shrunk 0.05) against the old
--    visible geometry; (probe) GetPartsInPart with a copy 0.1 smaller.
-- 2. support: banners have the wall within 0.5 behind the cloth and the brackets touch the wall; sign bars sit on their
--    sign plate (ray back from the bar hits the plate within 0.1); shafts end on the floor round the disc.
-- 3. hooks: one enabled LobbySpawn on the disc, fall-catch spawn (0,4,0) lands on the disc; tag counts (QueuePad, ExfilBarrier,
--    RoomLight + Room attribute, LobbySpin, LobbyScreen, LF_Beacon, CityBillboard); Signs.Screen_Leaderboard; reward stand
--    SpinRoot; FX.Hologram parts; the four hub sign texts; the OUTFITTERS floor stencil; AssetCheck names present.
-- 4. budget: no Light / ParticleEmitter inside Polish.Hub, enabled lights in Edit, new collidable / queryable parts 0, the
--    olive attribute count and no olive left on parts another room pass recoloured.
-- 5. walk routes (block cast 2 x 4.5 x 2, collidable only) from the spawn disc: N gate -> Shop, S gate -> Armory, W riser
--    foot, E tunnel -> hangar, round the reward stand, to 10 studs from the leaderboard / TV / likes / ad walls (crates stand
--    under the boards). Steps and stairs are walked in Play (a block cast can't climb).
local LM = workspace.LobbyMap
local CS = game:GetService("CollectionService")
local root = LM.Polish:FindFirstChild("Hub")
assert(root, "run fix/polish_hub.lua first")
local out = {}
local function say(s) table.insert(out, s) end

local newParts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(newParts, d) end end
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and not d:IsDescendantOf(root) then d.CanQuery = true; table.insert(q, d) end
end
local skip = {root}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip

-- 1. clips
local clips, seen = {}, {}
local function note(p, h, how)
	local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Hub.", "") .. " x " .. h:GetFullName():gsub("Workspace.LobbyMap.", "")
	if not seen[key] then seen[key] = true; table.insert(clips, key .. " (" .. how .. ")") end
end
local nVis = 0
for _, p in ipairs(newParts) do
	if p.Transparency < 1 then
		nVis += 1
		local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
		hs = Vector3.new(math.max(hs.X, 0), math.max(hs.Y, 0), math.max(hs.Z, 0))
		local targets = {}
		for _, v in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, v * hs) end
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z))
		end end end
		for _, t in ipairs(targets) do
			local a = p.Position; local b = p.CFrame * t
			if (b - a).Magnitude > 0.01 then
				local h = workspace:Raycast(a, b - a, rp)
				if h then note(p, h.Instance, "ray") end
			end
		end
	end
end
local hullOnly = {}
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = skip
for _, p in ipairs(newParts) do
	if p.Transparency < 1 then
		local c = Instance.new("Part"); c.Anchored = true; c.CanCollide = false; c.Transparency = 1
		c.Shape = p.Shape
		c.Size = Vector3.new(math.max(p.Size.X - 0.1, 0.02), math.max(p.Size.Y - 0.1, 0.02), math.max(p.Size.Z - 0.1, 0.02))
		c.CFrame = p.CFrame
		for _, h in ipairs(workspace:GetPartsInPart(c, op)) do
			if h.Transparency < 0.95 then
				-- a merged per-material kit mesh (bounding box > 60 studs) overlaps every probe through its hull
				-- (vault 7.7k): count it only when a ray also hits it, otherwise list it as hull-only
				if h.Size.Magnitude > 60 and not seen[p:GetFullName():gsub("Workspace.LobbyMap.Polish.Hub.", "") .. " x " .. h:GetFullName():gsub("Workspace.LobbyMap.", "")] then
					hullOnly[h.Name] = (hullOnly[h.Name] or 0) + 1
				else
					note(p, h, "probe")
				end
			end
		end
		c:Destroy()
	end
end
say(("CLIPS (%d; visible new parts %d of %d):"):format(#clips, nVis, #newParts))
for _, c in ipairs(clips) do say("  " .. c) end
for n, k in pairs(hullOnly) do say(("  hull-only probe overlaps (no ray hit, merged mesh): %s x%d"):format(n, k)) end

-- 2. support
local bad = 0
for _, m in ipairs(root.Banners:GetChildren()) do
	local cl = m.Cloth
	local back = -cl.CFrame.LookVector
	local h = workspace:Raycast(cl.Position, back * 0.6, rp)
	if not h then bad += 1; say("  no wall behind " .. m.Name) end
	for _, b in ipairs(m:GetChildren()) do
		if b.Name == "Bracket" then
			local hb = workspace:Raycast(b.Position, back * (b.Size.Z / 2 + 0.06), rp)
			if not hb then bad += 1; say("  bracket off the wall in " .. m.Name) end
		end
	end
end
for _, b in ipairs(root.SignBars:GetChildren()) do
	local h = workspace:Raycast(b.Position, -b.CFrame.LookVector * 0.12, rp)
	if not (h and h.Instance.Name:find("SignText")) then bad += 1; say("  sign bar not on its plate: " .. b.Name .. " hit " .. tostring(h and h.Instance.Name)) end
end
for _, s in ipairs(root.SunShafts:GetChildren()) do
	local bm = s:FindFirstChildWhichIsA("Beam", true)
	local a1 = bm and bm.Attachment1
	local y = a1 and a1.WorldPosition.Y or 99
	if math.abs(y - 0.8) > 0.05 then bad += 1; say(("  shaft %s ends at y %.2f"):format(s.Name, y)) end
end
say(("SUPPORT bad %d (banners %d, sign bars %d, shafts %d)"):format(bad, #root.Banners:GetChildren(), #root.SignBars:GetChildren(), #root.SunShafts:GetChildren()))

-- 3. hooks
local spawns = 0
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("SpawnLocation") and d.Enabled then spawns += 1 end end
local fc = workspace:Raycast(Vector3.new(0, 4, 0), Vector3.new(0, -6, 0), rp)
say(("HOOKS: enabled SpawnLocations %d; fall-catch (0,4,0) lands on %s at %.2f"):format(spawns, fc and fc.Instance.Name or "nothing", fc and fc.Position.Y or -1))
local tags = {}
for _, t in ipairs({"QueuePad", "ExfilBarrier", "RoomLight", "LobbySpin", "LobbyScreen", "LF_Beacon", "CityBillboard", "LobbyBeacon", "LobbyRun"}) do
	table.insert(tags, t .. " " .. #CS:GetTagged(t))
end
say("  tags: " .. table.concat(tags, ", "))
local noRoom = 0
for _, p in ipairs(CS:GetTagged("RoomLight")) do if not p:GetAttribute("Room") then noRoom += 1 end end
say("  RoomLight without Room attribute: " .. noRoom)
local lb = LM.Signs:FindFirstChild("Screen_Leaderboard")
local rs = LM.Features:FindFirstChild("RewardStand")
local spinRoot = rs and rs:FindFirstChild("SpinRoot", true)
say(("  Signs.Screen_Leaderboard %s; RewardStand SpinRoot %s (LobbySpin %s)"):format(tostring(lb ~= nil), tostring(spinRoot ~= nil),
	tostring(spinRoot and CS:HasTag(spinRoot, "LobbySpin") or (rs and #CS:GetTagged("LobbySpin") > 0))))
local holo = LM.FX:FindFirstChild("Hologram")
say(("  FX.Hologram parts %d"):format(holo and #holo:GetChildren() or -1))
local function signText(n)
	local p = LM.Hub1.Overlays:FindFirstChild(n)
	local l = p and p:FindFirstChildWhichIsA("TextLabel", true)
	return l and l.Text or "?"
end
local st = LM.Features.Wayfinding:FindFirstChild("Stencil_SHOP")
local stl = st and st:FindFirstChildWhichIsA("TextLabel", true)
say(("  signs: %s / %s / %s / %s; floor stencil N '%s'"):format(signText("SignText_SHOP"), signText("SignText_ARMORY"), signText("SignText_EXFIL"),
	signText("SignText_DUELS"), stl and stl.Text or "?"))
local ac = 0
for _, n in ipairs({"U_Floor__floor_metal", "U_Floor__grate", "U_Floor__dark_metal", "U_SpawnDisc__spawn_logo"}) do
	if LM.Unique:FindFirstChild(n, true) then ac += 1 end
end
say("  AssetCheck names present " .. ac .. "/4")

-- 4. budget
local nl, np, nc, nq = 0, 0, 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Light") then nl += 1 end
	if d:IsA("ParticleEmitter") then np += 1 end
	if d:IsA("BasePart") and d.CanCollide then nc += 1 end
	if d:IsA("BasePart") and d.CanQuery and not table.find(q, d) then nq += 1 end
end
local en = 0; for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Light") and d.Enabled then en += 1 end end
local olive, mixed = 0, 0
for _, d in ipairs(LM:GetDescendants()) do
	if d:GetAttribute("PolishOlive_Orig") then
		olive += 1
		for k, _ in pairs(d:GetAttributes()) do
			if k ~= "PolishOlive_Orig" and k ~= "PolishHub_Orig" and k:match("^Polish.*_Orig") then mixed += 1 end
		end
	end
end
say(("BUDGET: new lights %d, particle emitters %d, enabled lights (Edit) %d, new collidable %d, new queryable %d; olive parts %d, olive on another room's recolour %d"):format(
	nl, np, en, nc, nq, olive, mixed))

-- 5. walk routes
for _, d in ipairs(q) do d.CanQuery = false end
local wp = RaycastParams.new(); wp.FilterType = Enum.RaycastFilterType.Exclude; wp.FilterDescendantsInstances = {}
wp.RespectCanCollide = true
local V = Vector3.new
local routes = {
	{"disc -> N gate -> Shop", {V(0, 3, 0), V(0, 3, 30), V(0, 3, 46), V(0, 3, 66), V(0, 3, 76)}},
	{"disc -> S gate -> Armory", {V(0, 3, 0), V(0, 3, -30), V(0, 3, -46), V(0, 3, -66), V(0, 3, -78)}},
	{"disc -> W riser foot (stairs: check_hub1 west route + Play walk)", {V(0, 3, 0), V(-60, 3, 0), V(-69.5, 3, 0)}},
	{"disc -> E tunnel -> hangar", {V(0, 3, 0), V(60, 3, 0), V(88, 3, 0), V(104, 3, 0), V(112, 3.5, 0)}},
	{"round the reward stand", {V(-5, 3, -16), V(-25, 3, -16), V(-25, 3, -32), V(-5, 3, -32), V(-5, 3, -16)}},
	{"to the leaderboard (N wall x -55)", {V(0, 3, 0), V(-40, 3, 20), V(-55.5, 3, 30)}},
	{"to the duels TV (S wall x -55)", {V(0, 3, 0), V(-40, 3, -20), V(-55.5, 3, -30)}},
	{"to the likes board (N wall x 55)", {V(0, 3, 0), V(40, 3, 20), V(55, 3, 30)}},
	{"to the ad board (S wall x 55)", {V(0, 3, 0), V(40, 3, -20), V(55, 3, -30)}},
}
local blocked = 0
for _, r in ipairs(routes) do
	local pts = r[2]; local txt = "clear"
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local h = workspace:Blockcast(CFrame.lookAt(a, b), Vector3.new(2, 4.5, 2), b - a, wp)
		if h then txt = ("BLOCKED by %s at %s"):format(h.Instance:GetFullName():gsub("Workspace.LobbyMap.", ""), tostring(h.Position)); blocked += 1; break end
	end
	say(("  route %s: %s"):format(r[1], txt))
end
say(("WALK: routes blocked %d"):format(blocked))
return table.concat(out, "\n")
