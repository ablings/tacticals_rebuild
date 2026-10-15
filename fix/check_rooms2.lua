--[[ fix/check_rooms2.lua : read-only checks after fix/place_rooms2.lua (restores anything it touches).
Openings (rays on collision geometry), floor profiles hub -> corridor -> room, block-cast walk routes, prompt reach from walkable
floor, gate alignment with the hub frames, and every room hook (NPCs, prompts, Spin, RoomLights, RoomFX centres, signs, emblem).
Runner: python tools/run_luau.py fix/check_rooms2.lua ]]
local LM = workspace.LobbyMap
local CS = game:GetService("CollectionService")
local out = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(out, table.concat(t, " ")) end
local function f2(x) return x and string.format("%.2f", x) or "nil" end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
local R2 = LM:FindFirstChild("Rooms2")
if not R2 then return "Rooms2 MISSING" end

-- collision world: what characters collide with
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.RespectCanCollide = true
local excl = {}
for _, n in {"NPCs", "Interact"} do table.insert(excl, LM[n]) end
rp.FilterDescendantsInstances = excl
local function ray(o, d) return workspace:Raycast(o, d, rp) end
local function span(o, axis, maxd)
	local a = ray(o, axis * maxd); local b = ray(o, -axis * maxd)
	local da = a and (a.Position - o).Magnitude or maxd; local db = b and (b.Position - o).Magnitude or maxd
	return da + db, a and a.Instance.Name or "-", b and b.Instance.Name or "-", o:Dot(axis) + (da - db) / 2
end
local function floorAt(x, z, top) local r = ray(Vector3.new(x, top or 9, z), Vector3.new(0, -20, 0)); return r and r.Position.Y, r and r.Instance.Name end
local bad = 0
local function flag(cond, ...) if not cond then bad += 1; say("  FAIL", ...) end end

---------------------------------------------------------------- 1. openings
say("== openings (need corridor ~9.8 at frames / ~10.3 between, 12.2 high; doors 11.0 x 12.2; hub gates 10.8 x 12.15)")
local gateCentre = {}
for _, side in {{"N", 1}, {"S", -1}} do
	local sg = side[2]
	-- hub gate mouth
	local w, a, b, c = span(Vector3.new(0, 6, sg * 44.5), Vector3.xAxis, 30)
	gateCentre[side[1]] = c
	say(side[1], "hub gate z" .. sg * 44.5, "width@6", f2(w), "centre x", f2(c), a, b)
	for _, y in {1, 3, 6, 10.5} do
		local mins, minsAt, maxs = math.huge, nil, 0
		for z = 49.5, 63.5, 0.5 do
			local ww, aa, bb, cc = span(Vector3.new(0, y, sg * z), Vector3.xAxis, 20)
			if ww < mins then mins, minsAt = ww, ("z%.1f %s|%s"):format(sg * z, aa, bb) end
			maxs = math.max(maxs, ww)
		end
		say(side[1], "corridor width @y" .. y, "min (frames)", f2(mins), minsAt, "max (between)", f2(maxs))
		flag(mins >= 9.5, "corridor too narrow", side[1], y) -- design 9.8; PCD hulls + frame plinths take ~0.1 a side
	end
	local cw, _, _, cc = span(Vector3.new(0, 6, sg * 56.5), Vector3.xAxis, 20)
	say(side[1], "corridor centre x", f2(cc), "vs hub gate centre", f2(gateCentre[side[1]]), "offset", f2(cc - gateCentre[side[1]]))
	flag(math.abs(cc - gateCentre[side[1]]) < 0.3, "gate/corridor misaligned", side[1])
	local minh = math.huge
	for z = 45, 69, 1 do for _, x in {-2, 0, 2} do
		local fl = floorAt(x, sg * z, 3) or 0
		local up = ray(Vector3.new(x, fl + 0.3, sg * z), Vector3.new(0, 30, 0))
		local hh = up and (up.Position.Y - fl) or 30
		if hh < minh then minh = hh end
	end end
	say(side[1], "min clear height x -2..2, z 45..69", f2(minh)); flag(minh >= 12.0, "low headroom", side[1])
	local hx = math.huge
	for z = 45, 69, 1 do local up = ray(Vector3.new(4, 0.5, sg * z), Vector3.new(0, 30, 0)); if up then hx = math.min(hx, up.Position.Y) end end
	say(side[1], "clear height at x 4 (under the frame haunches)", f2(hx))
	local dz = sg > 0 and 66.5 or -65.5
	for _, y in {1, 6, 11} do local ww, aa, bb = span(Vector3.new(0, y, dz), Vector3.xAxis, 20); say(side[1], "doorway z" .. dz, "width@" .. y, f2(ww), aa, bb) end
	local dw = span(Vector3.new(0, 6, dz), Vector3.xAxis, 20); flag(dw >= 10.9, "doorway narrow", side[1])
	local fl = floorAt(0, dz, 3); local up = ray(Vector3.new(0, (fl or 0) + 0.3, dz), Vector3.new(0, 30, 0))
	say(side[1], "doorway clear height", f2(up and up.Position.Y - (fl or 0)), up and up.Instance.Name)
end

---------------------------------------------------------------- 2. floor profiles (hub -> corridor -> room), steps
say("== walkway floor profiles hub -> lane end (z: y), max step (plinth / case beyond are obstacles, routed round below)")
for _, sg in {1, -1} do
	for _, x in {-3, 0, 3} do
		local prev, maxstep, prof = nil, 0, {}
		for z = 30, (sg > 0 and 80 or 90), 1 do
			local y = floorAt(x, sg * z, 6) or -99
			if prev then maxstep = math.max(maxstep, math.abs(y - prev)) end
			prev = y
			if z % 10 == 0 then table.insert(prof, ("%d:%.2f"):format(sg * z, y)) end
		end
		say(sg > 0 and "N" or "S", "x" .. x, table.concat(prof, " "), "max step", f2(maxstep)); flag(maxstep < 0.6, "step", sg, x)
	end
end
for _, p in {{"shop floor", 0, 80}, {"shop corner", -25, 105}, {"armory floor", 0, -80}, {"armory corner", 25, -75}, {"staff deck (QM)", 10, 106.7},
	{"supply deck", 7, -110.6}, {"gun-wall mat", -6, -108.5}} do
	local y, who = floorAt(p[2], p[3], 9); say(p[1], f2(y), who)
end
local _, sc = floorAt(0, 80, 9); local up = ray(Vector3.new(-5, 2, 85), Vector3.new(0, 30, 0)); say("shop ceiling over (-5,85)", up and f2(up.Position.Y), up and up.Instance.Name, "(non-colliding ceiling: expect none)")
-- ceilings are visual (no collide): measure on query geometry of all kit
local rq = RaycastParams.new(); rq.FilterType = Enum.RaycastFilterType.Include; rq.FilterDescendantsInstances = {R2}
local saved = {}
for _, d in R2:GetDescendants() do if d:IsA("BasePart") then saved[d] = d.CanQuery; d.CanQuery = true end end
for _, p in {{"shop ceiling", -5, 85}, {"shop beam line", -10, 85}, {"armory ceiling", -5, -84}, {"armory beam line", -10.33, -84}, {"corridor N lining", 0, 56.5}, {"corridor S lining", 0, -56.5}} do
	local r = workspace:Raycast(Vector3.new(p[2], 1, p[3]), Vector3.new(0, 40, 0), rq); say(p[1], r and f2(r.Position.Y), r and r.Instance.Name)
end
for d, q in saved do d.CanQuery = q end

---------------------------------------------------------------- 3. walk routes (block cast 2 x 4.5 x 2 at floor + 3)
say("== routes (block cast 2x4.5x2, bottom 0.75 above the floor)")
local function route(name, pts)
	local hits = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ya = (floorAt(a.X, a.Y, 6) or 0) + 3; local yb = (floorAt(b.X, b.Y, 6) or 0) + 3
		local A, B = Vector3.new(a.X, ya, a.Y), Vector3.new(b.X, yb, b.Y)
		local r = workspace:Blockcast(CFrame.lookAt(A, B), Vector3.new(2, 4.5, 2), B - A, rp)
		if r then table.insert(hits, ("seg%d %s at %s"):format(i, r.Instance:GetFullName(), f3(r.Position))) end
	end
	say(name, #hits == 0 and "clear" or table.concat(hits, "; ")); flag(#hits == 0, "route blocked", name)
end
local V = Vector2.new
route("spawn -> N gate -> shop counter front", {V(0, 14), V(0, 40), V(0, 66), V(0, 78), V(-8, 84), V(-7, 97), V(3, 98.8)})
route("shop counter -> back to hub", {V(3, 98.8), V(10, 95), V(9, 80), V(2, 70), V(0, 50), V(0, 20)})
route("spawn -> S gate -> gun wall", {V(0, -14), V(0, -40), V(0, -66), V(0, -80), V(-1, -100), V(0, -108)})
route("armory -> dais front", {V(0, -80), V(-4, -88), V(-10, -88.5)})
route("armory -> supply counter front", {V(0, -80), V(0, -100), V(8, -103.3)})
route("supply -> back to hub", {V(8, -103.3), V(0, -100), V(0, -80), V(0, -50), V(0, -20)})

---------------------------------------------------------------- 4. prompt reach from walkable floor
say("== prompt reach (any walkable standing spot, root at floor+3, within MaxActivationDistance)")
local function walkable(x, z)
	local y = floorAt(x, z, 6); if not y or y > 1.5 then return nil end
	local r = workspace:Blockcast(CFrame.new(x, y + 6, z), Vector3.new(2, 0.5, 1), Vector3.new(0, -5.2, 0), rp) -- body volume (HRP footprint 2 x 1, facing the counter) y+0.8..y+6
	if r then return nil end
	return y
end
local prompts = {}
for _, p in LM.Interact:GetDescendants() do if p:IsA("ProximityPrompt") then table.insert(prompts, p) end end
for _, n in {"NPC_Quartermaster", "NPC_Supply"} do local npc = LM.NPCs:FindFirstChild(n); local pr = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true); if pr then table.insert(prompts, pr) end end
for _, pr in prompts do
	local part = pr.Parent; local pos = part:IsA("Attachment") and part.WorldPosition or part.Position
	local best
	-- customer side only for the counters (staff decks behind them do not count)
	local okSide = function(z) return true end
	if part.Name == "Shop_Counter" or part.Parent.Name == "NPC_Quartermaster" then okSide = function(z) return z < 100.0 end end
	if part.Parent.Name == "NPC_Supply" then okSide = function(z) return z > -104.4 end end
	for x = pos.X - 14, pos.X + 14, 1 do for z = pos.Z - 14, pos.Z + 14, 1 do
		local y = okSide(z) and walkable(x, z)
		if y then local d = (Vector3.new(x, y + 3, z) - pos).Magnitude; if not best or d < best then best = d end end
	end end
	say(part:GetFullName(), "OpenPanel", pr:GetAttribute("OpenPanel"), "d", pr.MaxActivationDistance, "nearest stand", f2(best))
	flag(best and best <= pr.MaxActivationDistance - 1, "prompt out of reach", part.Name)
end

---------------------------------------------------------------- 5. hooks
say("== hooks")
for _, n in {"Rooms", "Interact", "NPCs", "Signs", "Rooms2"} do say(n, LM:FindFirstChild(n) and "ok" or "MISSING") end
for _, n in {"Shop", "Armory"} do say("Rooms." .. n, LM.Rooms:FindFirstChild(n) and "ok" or "MISSING") end
local fs = LM.Rooms.Armory:FindFirstChild("FeaturedScissors")
say("FeaturedScissors", fs and f3(fs:GetPivot().Position), "Spin", fs and fs:GetAttribute("Spin"))
flag(fs and fs:GetAttribute("Spin"), "FeaturedScissors Spin")
if fs then -- clears the dais cap at every spin angle?
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = {R2.A_Dais}
	local orig = fs:GetPivot(); local hit = 0
	local sq = {}; for _, d in R2.A_Dais:GetDescendants() do if d:IsA("BasePart") then sq[d] = d.CanQuery; d.CanQuery = true end end
	for i = 0, 11 do fs:PivotTo(orig * CFrame.Angles(0, math.rad(i * 30), 0)); for _, p in fs:GetDescendants() do if p:IsA("BasePart") then hit += #workspace:GetPartsInPart(p, op) end end end
	fs:PivotTo(orig); for d, q in sq do d.CanQuery = q end
	say("FeaturedScissors vs dais, 12 spin poses: hits", hit)
end
for _, n in {"NPC_Quartermaster", "NPC_Supply"} do
	local npc = LM.NPCs[n]; local hrp = npc:FindFirstChild("HumanoidRootPart"); local hum = npc:FindFirstChildOfClass("Humanoid")
	local mn = math.huge; for _, p in npc:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then mn = math.min(mn, p.Position.Y - p.Size.Y / 2) end end
	local fl, who = floorAt(hrp.Position.X, hrp.Position.Z + (n == "NPC_Supply" and 0 or 0), hrp.Position.Y)
	-- NPC body vs colliding kit
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = {R2}; op.RespectCanCollide = true
	local hits = {}
	for _, p in npc:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then
		for _, h in workspace:GetPartsInPart(p, op) do if h.Name ~= who then hits[h.Name] = true end end
	end end
	local hs = {}; for k in hits do table.insert(hs, k) end
	say(n, "root", f3(hrp.Position), "feet", f2(mn), "floor under root", f2(fl), who, "Humanoid", hum ~= nil, "body overlaps (deck excluded):", #hs == 0 and "none" or table.concat(hs, ","))
	flag(fl and math.abs(mn - fl) < 0.12, "NPC feet off deck", n)
	local pr = hrp:FindFirstChildWhichIsA("ProximityPrompt"); say("  prompt", pr and pr:GetAttribute("OpenPanel"), pr and pr:GetAttribute("TalkLines") and "TalkLines ok")
end
local CENTRE = {Shop = Vector3.new(0, 6, 89), Armory = Vector3.new(0, 8, -91)}
local nRL = 0
for _, l in CS:GetTagged("RoomLight") do
	nRL += 1
	local room = l:GetAttribute("Room")
	if CENTRE[room] then
		local li = l:FindFirstChildWhichIsA("Light")
		local up = l:IsA("BasePart") and ray(l.Position, Vector3.new(0, 3, 0))
		say("RoomLight", l.Name, room, f3(l.Position), "dist to centre", f2((l.Position - CENTRE[room]).Magnitude), li and li.ClassName, li and ("b" .. li.Brightness), "T", l.Transparency)
		flag((l.Position - CENTRE[room]).Magnitude < 75, "RoomLight outside radius", l.Name)
	end
end
say("RoomLight tagged total", nRL)
local e = LM.Rooms.Shop:FindFirstChild("CounterEmblem"); say("CounterEmblem", e and f3(e.Position), e and e.Transparency, e and e:FindFirstChildWhichIsA("Decal") and "decal Front")
for _, s in R2.Overlays:GetChildren() do
	local l = s:FindFirstChild("Text") and s.Text:FindFirstChild("Label")
	say("sign", s.Name, l and l.Text, f3(s.Position), "look", f3(s.CFrame.LookVector))
end
-- hidden summary
local hid = 0; for _, d in LM:GetDescendants() do if d:GetAttribute("Rooms2Hidden") then hid += 1 end end
say("Rooms2Hidden instances", hid)
local rem = game.ServerStorage:FindFirstChild("_RebuildRemoved")
say("K_Scale2 / K_Marker2 in _RebuildRemoved", rem and rem:FindFirstChild("K_Scale2") ~= nil, rem and rem:FindFirstChild("K_Marker2") ~= nil, "workspace.rooms2", workspace:FindFirstChild("rooms2") ~= nil)
local cnt = {}
for _, d in R2:GetDescendants() do if d:IsA("MeshPart") and d.CanCollide then cnt[d.CollisionFidelity.Name] = (cnt[d.CollisionFidelity.Name] or 0) + 1 end end
for k, v in cnt do say("fidelity", k, v) end
say("== FAILS", bad)
return table.concat(out, "\n")
