--[[ fix/check_training.lua : read-only checks after fix/place_training.lua (writes nothing; temporary probe parts are destroyed).
1 hooks + folders   2 height logic (y 585 / 540)   3 floor coverage + walk flood fill from the plaza (floor cells, 2 studs)
4 roof deck: surfaces at +24, ceiling clearance, flood fill per deck, access by ramps (sampled slope) and trusses (flush tops)
5 EnemySpots: 3 studs above a surface, dummy body volume unobstructed, reachable cell, Gallery count
6 gallery lanes clear (firing line and plaza -> every gallery spot)   7 arrivals clear   8 NotCover / sign rules   9 lights
Runner: python tools/run_luau.py fix/check_training.lua ]]
local LM = workspace.LobbyMap
local T = LM.Training
local CS = game:GetService("CollectionService")
local R = T:FindFirstChild("Range2")
if not R then return "Range2 MISSING" end
local out = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(out, table.concat(t, " ")) end
local function f2(x) return x and string.format("%.2f", x) or "nil" end
local function f3(v) return string.format("(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
local bad = 0
local function flag(cond, ...) if not cond then bad += 1; say("  FAIL", ...) end; return cond end
local FLOOR, ROOF, CEIL = 600, 624, 648

-- collision world as characters see it (Range2 only: the old geometry is hidden and non-colliding; NPCs/dummies excluded)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.RespectCanCollide = true
local excl = {T.EnemySpots, T.Arrivals}
for _, c in T:GetChildren() do if c:IsA("Model") then table.insert(excl, c) end end   -- dummies parented to Training in Play
rp.FilterDescendantsInstances = excl
local function down(x, z, top) local r = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top - 590), 0), rp); return r and r.Position.Y, r and r.Instance end
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.RespectCanCollide = true; op.FilterDescendantsInstances = excl
-- precise "is the body free": temporary part + GetPartsInPart (follows wedge / truss collision, not AABBs)
local probe = Instance.new("Part"); probe.Anchored = true; probe.CanCollide = false; probe.CanQuery = false; probe.CanTouch = false; probe.Transparency = 1
probe.Parent = workspace
local op2 = OverlapParams.new(); op2.FilterType = Enum.RaycastFilterType.Exclude; op2.RespectCanCollide = true
local ex2 = table.clone(excl); table.insert(ex2, probe); op2.FilterDescendantsInstances = ex2
local function bodyHits(cf, size)
	probe.Size = size; probe.CFrame = cf
	local h = workspace:GetPartsInPart(probe, op2); local n = {}
	for _, x in h do table.insert(n, x.Name) end
	return n
end

---------------------------------------------------------------- 1. hooks
say("== 1. hooks")
local spots, arr = T:FindFirstChild("EnemySpots"), T:FindFirstChild("Arrivals")
flag(T:IsA("Folder"), "Training not a Folder")
flag(spots and #spots:GetChildren() == 44, "EnemySpots count", spots and #spots:GetChildren())
local nonPart, nGal = 0, 0
for _, s in spots:GetChildren() do
	if not s:IsA("BasePart") then nonPart += 1 end
	if s:GetAttribute("Gallery") == true then nGal += 1 end
end
flag(nonPart == 0, "EnemySpots has non-BasePart children", nonPart); flag(nGal == 16, "Gallery=true spots", nGal)
flag(arr and #arr:GetChildren() == 16, "Arrivals count", arr and #arr:GetChildren())
flag(T:FindFirstChild("TrainingArrive") ~= nil, "TrainingArrive missing")
for _, s in spots:GetChildren() do flag(not s.CanCollide and not s.CanQuery and s.Transparency == 1 and s.Anchored, "spot flags", s.Name, f3(s.Position)) end
for _, a in arr:GetChildren() do flag(not a.CanCollide and not a.CanQuery and a.Transparency == 1 and a.Anchored, "arrive flags", f3(a.Position)) end
say("EnemySpots", #spots:GetChildren(), "(Gallery=true", nGal .. ")", "Arrivals", #arr:GetChildren(), "TrainingArrive", f3(T.TrainingArrive.Position))
local rs = game:GetService("ServerStorage"):FindFirstChild("RangeAssets")
say("ServerStorage.RangeAssets.Dummy present:", rs and rs:FindFirstChild("Dummy") ~= nil)

---------------------------------------------------------------- 2. height logic
say("== 2. heights")
local lo, hi = math.huge, -math.huge
local n540 = 0
for _, d in R:GetDescendants() do if d:IsA("BasePart") then
	lo = math.min(lo, d.Position.Y - d.Size.Y / 2); hi = math.max(hi, d.Position.Y + d.Size.Y / 2)
end end
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Position.Y > 540 and not d:IsDescendantOf(T) and d.Transparency < 1 then
		n540 += 1; if not d:IsDescendantOf(LM.Signs) then say("  above 540 outside Training:", d:GetFullName()) end
	end
end
say("Range2 y range", f2(lo), "..", f2(hi), "| visible parts above y 540 outside Training:", n540, "(the TRAINING sign meshes in LobbyMap.Signs)")
flag(lo >= 597.9, "geometry below the floor slab", lo); flag(hi <= CEIL + 2.01, "geometry above the ceiling slab", hi)

---------------------------------------------------------------- 3. floor coverage + walk flood fill
say("== 3. floor + walk routes (2-stud cells; free = 1.8 x 4.6 x 1.8 body above the surface)")
local CELL = 2
local cells = {}           -- key -> {x, z, y, free}
local function key(i, j, lvl) return i .. "," .. j .. "," .. lvl end
local holes, low = 0, 0
local heights = {}
local function scanArea(x0, x1, z0, z1)
	for x = x0 + 1, x1 - 1, CELL do for z = z0 + 1, z1 - 1, CELL do
		local y, inst = down(x, z, CEIL - 0.5)
		if not y then holes += 1; continue end
		local hk = string.format("%.1f", y); heights[hk] = (heights[hk] or 0) + 1
		if y < FLOOR - 0.2 then low += 1 end
		-- floor level cell (also the cell under a roof: cast from just above the floor)
		local yf = down(x, z, FLOOR + 4.9)
		if yf and math.abs(yf - FLOOR) < 0.25 then
			local free = #bodyHits(CFrame.new(x, yf + 0.25 + 2.3, z), Vector3.new(1.8, 4.6, 1.8)) == 0
			cells[key(math.floor(x / CELL), math.floor(z / CELL), 0)] = {x = x, z = z, y = yf, free = free}
		end
		if math.abs(y - ROOF) < 0.25 then
			local free = #bodyHits(CFrame.new(x, y + 0.25 + 2.3, z), Vector3.new(1.8, 4.6, 1.8)) == 0
			cells[key(math.floor(x / CELL), math.floor(z / CELL), 1)] = {x = x, z = z, y = y, free = free}
		end
	end; if x % 20 == 1 then task.wait() end end
end
scanArea(-128, 128, -128, 128); scanArea(128, 352, -36, 36)
flag(holes == 0, "floor holes (no hit under the ceiling)", holes); flag(low == 0, "surfaces below 599.8", low)
local hs = {}; for k, v in heights do if v >= 20 then table.insert(hs, k .. ":" .. v) end end; table.sort(hs); say("top surfaces (y:count, >=20 samples):", table.concat(hs, " "))

-- flood fill on one level from a seed
local function flood(seedKey, lvl)
	local seen, q = {[seedKey] = true}, {seedKey}
	while #q > 0 do
		local k = table.remove(q); local i, j = string.match(k, "^(-?%d+),(-?%d+)")
		i, j = tonumber(i), tonumber(j)
		for _, d in {{1, 0}, {-1, 0}, {0, 1}, {0, -1}} do
			local nk = key(i + d[1], j + d[2], lvl)
			local c = cells[nk]
			if c and c.free and not seen[nk] then seen[nk] = true; table.insert(q, nk) end
		end
	end
	return seen
end
local function cellAt(x, z, lvl) return key(math.floor(x / CELL), math.floor(z / CELL), lvl) end
local function nearestFree(x, z, lvl, r)
	local best, bd
	for dx = -(r or 3), r or 3 do for dz = -(r or 3), r or 3 do
		local k = key(math.floor(x / CELL) + dx, math.floor(z / CELL) + dz, lvl); local c = cells[k]
		if c and c.free then local d = (c.x - x) ^ 2 + (c.z - z) ^ 2; if not bd or d < bd then best, bd = k, d end end
	end end
	return best
end
local floorSeen = flood(nearestFree(16, 16, 0), 0)
local nFloor, nFree, nReach = 0, 0, 0
for k, c in cells do if string.sub(k, -2) == ",0" then nFloor += 1; if c.free then nFree += 1; if floorSeen[k] then nReach += 1 end end end end
say("floor cells", nFloor, "free", nFree, "reachable from the plaza", nReach)
-- free floor pockets not reachable (cells): list a few
local stray = {}
for k, c in cells do if string.sub(k, -2) == ",0" and c.free and not floorSeen[k] then table.insert(stray, ("(%d,%d)"):format(c.x, c.z)) end end
flag(#stray == 0, "free floor cells unreachable from the plaza:", #stray, table.concat(stray, " ", 1, math.min(#stray, 15)))
-- zone targets reachable on foot
for _, t in {{"gallery end", 340, 0}, {"gallery N lane", 300, 20}, {"NW maze", -97, 62}, {"NE towers", 84, 80}, {"SW cover", -86, -70},
	{"SE field", 80, -110}, {"NW corner street", -100, 96}} do
	local k = nearestFree(t[2], t[3], 0)
	flag(k and floorSeen[k], "zone not reachable on foot:", t[1])
end

---------------------------------------------------------------- 4. roof deck: ceiling clearance, decks, access
say("== 4. roof deck (+24) and access")
local nRoof, minHead = 0, math.huge
for k, c in cells do if string.sub(k, -2) == ",1" then
	nRoof += 1
	local up = workspace:Raycast(Vector3.new(c.x, c.y + 0.1, c.z), Vector3.new(0, 40, 0), rp)
	local hd = up and (up.Position.Y - c.y) or 99
	minHead = math.min(minHead, hd)
end end
say("roof cells", nRoof, "(", nRoof * CELL * CELL, "studs2 ) min headroom to the ceiling", f2(minHead))
flag(minHead >= 23.5, "roof headroom under 23.5", minHead)
-- decks = connected components on level 1
local comp, deckOf = {}, {}
for k, c in cells do
	if string.sub(k, -2) == ",1" and c.free and not deckOf[k] then
		local s = flood(k, 1); local id = #comp + 1; local n = 0
		for kk in s do deckOf[kk] = id; n += 1 end
		comp[id] = {n = n, cx = c.x, cz = c.z, access = {}}
	end
end
-- ramps: sample the slope surface along the centre line, and the foot / top connections
for _, rmp in R.Access:GetChildren() do
	if rmp:IsA("WedgePart") then
		local d = rmp.CFrame.LookVector * -1               -- high side = local +Z = -LookVector
		local len = rmp.Size.Z
		local foot = rmp.Position - d * (len / 2 + 1.5); local top = rmp.Position + d * (len / 2 + 1.5)
		local ok, maxStep, prev = true, 0, nil
		for s = -len / 2 + 1, len / 2 - 1, 1 do
			local p = rmp.Position + d * s
			local y = down(p.X, p.Z, CEIL - 0.5)
			if not y then ok = false else if prev then maxStep = math.max(maxStep, math.abs(y - prev)) end; prev = y end
		end
		local ang = math.deg(math.atan(rmp.Size.Y / len))
		local footK, topK = nearestFree(foot.X, foot.Z, 0, 2), nearestFree(top.X, top.Z, 1, 2)
		local clearAbove = #bodyHits(CFrame.new(rmp.Position + Vector3.new(0, rmp.Size.Y / 2 + 3, 0)) * rmp.CFrame.Rotation, Vector3.new(rmp.Size.X - 0.4, 0.5, len - 2)) == 0
		say("ramp ->", rmp:GetAttribute("To"), "slope", f2(ang), "deg, max step per stud", f2(maxStep), "foot reachable", footK and floorSeen[footK] or false,
			"top on deck", topK and deckOf[topK] or "none")
		flag(ok and maxStep < 1.2 and ang < 40, "ramp surface", rmp:GetAttribute("To"))
		flag(footK and floorSeen[footK], "ramp foot not reachable", rmp:GetAttribute("To"))
		flag(topK and deckOf[topK], "ramp top not on a deck", rmp:GetAttribute("To"))
		if topK and deckOf[topK] then table.insert(comp[deckOf[topK]].access, "ramp") end
	end
end
-- trusses: base on the floor, top flush with the roof it serves, a free floor cell beside it and a roof cell beside the top
for _, tr in R.Access:GetChildren() do
	if tr:IsA("TrussPart") then
		local top = tr.Position.Y + tr.Size.Y / 2; local base = tr.Position.Y - tr.Size.Y / 2
		local fk, rk
		for _, o in {Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0), Vector3.new(0, 0, 2), Vector3.new(0, 0, -2)} do
			local p = tr.Position + o
			local k0 = cellAt(p.X, p.Z, 0); if cells[k0] and cells[k0].free and floorSeen[k0] then fk = k0 end
			local k1 = cellAt(p.X, p.Z, 1); if cells[k1] and cells[k1].free and deckOf[k1] then rk = k1 end
		end
		flag(math.abs(base - FLOOR) < 0.05 and math.abs(top - ROOF) < 0.05, "truss height", tr:GetAttribute("To"), f2(base), f2(top))
		flag(fk ~= nil, "truss without a reachable floor cell beside it", tr:GetAttribute("To"), f3(tr.Position))
		flag(rk ~= nil, "truss top not beside a deck cell", tr:GetAttribute("To"), f3(tr.Position))
		if rk then table.insert(comp[deckOf[rk]].access, "truss") end
	end
end
for id, c in comp do
	local a = {}; for _, x in c.access do a[x] = (a[x] or 0) + 1 end
	local s = {}; for k, v in a do table.insert(s, k .. "x" .. v) end
	say(("deck %d: %d cells (%d studs2) near (%d,%d) access: %s"):format(id, c.n, c.n * 4, c.cx, c.cz, #s > 0 and table.concat(s, " ") or "NONE"))
	flag(#c.access > 0 or c.n < 6, "deck without access", id)
end

---------------------------------------------------------------- 5. EnemySpots
say("== 5. EnemySpots")
local zones = {}
for _, s in spots:GetChildren() do
	local p = s.Position
	local y = down(p.X, p.Z, p.Y + 0.4)
	local okY = y and math.abs((p.Y - 3) - y) < 0.15
	-- dummy volume: R15 ~4 wide (arms), ~5.2 tall, ~1.5 deep; probe 4 x 5 x 2 in the spot's rotation, 0.2 above the surface
	local hits = y and bodyHits(CFrame.new(p.X, y + 0.2 + 2.5, p.Z) * s.CFrame.Rotation, Vector3.new(4, 5, 2)) or {"no surface"}
	local lvl = (y and math.abs(y - ROOF) < 0.3) and 1 or 0
	local k = nearestFree(p.X, p.Z, lvl, 2)
	local reach = k and (lvl == 0 and floorSeen[k] or (lvl == 1 and deckOf[k] and #comp[deckOf[k]].access > 0)) or false
	local z = s:GetAttribute("Zone") or "?"; zones[z] = (zones[z] or 0) + 1
	flag(okY, "spot not 3 above a surface", z, f3(p), "surface", f2(y))
	flag(#hits == 0, "spot obstructed", z, f3(p), table.concat(hits, ","))
	flag(reach, "spot not reachable by a player", z, f3(p))
	-- facing: gallery -> -x; others -> toward the plaza
	local lv = s.CFrame.LookVector
	if s:GetAttribute("Gallery") then flag(lv.X < -0.99, "gallery spot not facing the firing line", f3(p)) end
end
local zs = {}; for k, v in zones do table.insert(zs, k .. "=" .. v) end; table.sort(zs); say("spots by zone:", table.concat(zs, " "))

---------------------------------------------------------------- 6. gallery lanes (shots: raycast against everything CanQuery, as WeaponUtil.IsPathClear)
say("== 6. gallery lanes")
local rq = RaycastParams.new(); rq.FilterType = Enum.RaycastFilterType.Exclude; rq.FilterDescendantsInstances = excl
local blocked = 0
for _, s in spots:GetChildren() do
	if s:GetAttribute("Gallery") then
		local tgt = s.Position + Vector3.new(0, 1.5, 0)            -- dummy chest/head height (feet at spot.Y - 3)
		for _, from in {Vector3.new(137, 604.5, s.Position.Z), Vector3.new(137, 604.5, 0), Vector3.new(14, 604.5, 0), Vector3.new(14, 604.5, 0 + (s.Position.Z > 0 and 10 or -10))} do
			local r = workspace:Raycast(from, tgt - from, rq)
			if r then blocked += 1; say("  blocked", f3(from), "->", s:GetAttribute("Lane"), s:GetAttribute("Distance"), "by", r.Instance:GetFullName()) end
		end
	end
end
say("gallery sight lines tested", nGal * 4, "blocked", blocked)
local laneBlock = 0
for _, s in spots:GetChildren() do if s:GetAttribute("Gallery") then
	local from = Vector3.new(137, 604.5, s.Position.Z); local r = workspace:Raycast(from, s.Position + Vector3.new(0, 1.5, 0) - from, rq)
	if r then laneBlock += 1 end
end end
flag(laneBlock == 0, "firing line -> own-lane spot blocked", laneBlock)
-- signs never block shots
for _, d in R.Signs:GetDescendants() do if d:IsA("BasePart") then flag(not d.CanQuery and not d.CanCollide and d:GetAttribute("NotCover"), "sign blocks / is cover", d.Name, f3(d.Position)) end end

---------------------------------------------------------------- 7. arrivals clear
say("== 7. arrivals")
local function arrivalOK(a)
	local p = a.Position
	local y = down(p.X, p.Z, p.Y)
	local hits = y and bodyHits(CFrame.new(p.X, y + 0.2 + 2.5, p.Z), Vector3.new(3, 5, 3)) or {"no floor"}
	local k = nearestFree(p.X, p.Z, 0, 2)
	return y and p.Y - y > 2.9 and p.Y - y < 3.6 and #hits == 0 and k and floorSeen[k], y, hits
end
local okA = 0
for _, a in arr:GetChildren() do local ok, y, h = arrivalOK(a); if flag(ok, "arrival", f3(a.Position), "floor", f2(y), table.concat(h or {}, ",")) then okA += 1 end end
local ok, y = arrivalOK(T.TrainingArrive); flag(ok, "TrainingArrive", f2(y))
say("arrivals clear", okA, "/", #arr:GetChildren(), "TrainingArrive", ok and "ok" or "FAIL", "height above floor", f2(T.TrainingArrive.Position.Y - (y or 0)))

---------------------------------------------------------------- 8. NotCover rules
say("== 8. NotCover / cover")
local cover, notc = {}, {}
for _, d in R:GetDescendants() do if d:IsA("BasePart") and d.CanCollide then
	local t = d:GetAttribute("NotCover") and notc or cover; t[d.Name] = (t[d.Name] or 0) + 1
end end
local a, b = {}, {}
for k, v in cover do table.insert(a, k .. "=" .. v) end; for k, v in notc do table.insert(b, k .. "=" .. v) end
table.sort(a); table.sort(b)
say("cover (CanCollide, no NotCover):", table.concat(a, " ")); say("CanCollide + NotCover:", table.concat(b, " "))
for _, n in {"Bridge", "Ramp", "Truss", "Ceiling"} do flag(cover[n] == nil, n, "should be NotCover") end

---------------------------------------------------------------- 9. lights
say("== 9. lights")
local nL, far = 0, 0
for _, p in CS:GetTagged("RoomLight") do if p:GetAttribute("Room") == "Training" then
	nL += 1; if (p.Position - Vector3.new(0, 606, 0)).Magnitude >= 175 then far += 1 end
end end
say("RoomLight Training", nL, "of which outside RoomFX radius 175:", far, "(on only after the RoomFX radius change, step 2)")
probe:Destroy()
say(bad == 0 and "ALL OK" or ("FAILURES " .. bad))
return table.concat(out, "\n")
