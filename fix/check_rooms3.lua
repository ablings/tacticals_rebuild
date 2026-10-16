--[[ fix/check_rooms3.lua : read-only checks after fix/place_rooms3.lua (restores anything it touches).
Openings (rays on collision geometry), floors, block-cast walk routes (hub stairs -> Duels door -> every pad -> west deck and back;
hub -> east tunnel -> hangar -> pad), ExfilBarrier reach, hangar respawn, ExfilFX camera + heli lift path, 1v1 board visibility,
QueueManager step-off spots, and every Duels / Exfil hook.
Runner: python tools/run_luau.py fix/check_rooms3.lua ]]
local LM = workspace.LobbyMap
local CS = game:GetService("CollectionService")
local PS = game:GetService("PhysicsService")
local out = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(out, table.concat(t, " ")) end
local function f2(x) return x and string.format("%.2f", x) or "nil" end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
local R3 = LM:FindFirstChild("Rooms3")
if not R3 then return "Rooms3 MISSING" end
local bad = 0
local function flag(cond, ...) if not cond then bad += 1; say("  FAIL", ...) end end

-- collision world: what characters collide with (NPCs excluded; Duels pad parts included: plates collide, barriers do not)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.RespectCanCollide = true
rp.FilterDescendantsInstances = {LM.NPCs}
local function ray(o, d) return workspace:Raycast(o, d, rp) end
local function span(o, axis, maxd)
	local a = ray(o, axis * maxd); local b = ray(o, -axis * maxd)
	local da = a and (a.Position - o).Magnitude or maxd; local db = b and (b.Position - o).Magnitude or maxd
	return da + db, a and a.Instance.Name or "-", b and b.Instance.Name or "-"
end
local function floorAt(x, z, top) local r = ray(Vector3.new(x, top, z), Vector3.new(0, -40, 0)); return r and r.Position.Y, r and r.Instance.Name end
-- floors without props on them (the heli stands on the pad: a prop, routed round below)
local rpF = RaycastParams.new(); rpF.FilterType = Enum.RaycastFilterType.Exclude; rpF.RespectCanCollide = true
rpF.FilterDescendantsInstances = {LM.NPCs, LM.Heli}
local function deckAt(x, z, top) local r = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -40, 0), rpF); return r and r.Position.Y, r and r.Instance.Name end
-- precise overlap: a temporary part tested with GetPartsInPart (real collision geometry, not bounding boxes)
local function bodyHits(cf, size, extraExcl)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Size = size; p.CFrame = cf; p.Parent = workspace
	local o = OverlapParams.new(); o.RespectCanCollide = true; o.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {LM.NPCs, p}; for _, e in extraExcl or {} do table.insert(ex, e) end
	o.FilterDescendantsInstances = ex
	local h = workspace:GetPartsInPart(p, o); p:Destroy()
	local n = {}; for _, x in h do table.insert(n, x.Name) end
	return n
end

---------------------------------------------------------------- 1. openings
say("== openings (need: Duels door 11.0 x 8.0; west portal + passage 9.0 x 12.0; tunnel end 22.0 x 18.0; mouth 52.4 x 17.0)")
local function opening(label, x, ys, top, needW, needH)
	local minw = math.huge
	for _, y in ys do local w, a, b = span(Vector3.new(x, y, 0), Vector3.zAxis, 40); minw = math.min(minw, w); say(label, "x" .. x, "width @y" .. y, f2(w), a, b) end
	local fl = floorAt(x, 0, top); local up = ray(Vector3.new(x, (fl or 0) + 0.3, 0), Vector3.new(0, 40, 0))
	local h = up and (up.Position.Y - fl) or 40
	say(label, "x" .. x, "floor", f2(fl), "clear height", f2(h), up and up.Instance.Name)
	flag(minw >= needW - 0.3, label, "narrow", f2(minw)); flag(h >= needH - 0.3, label, "low", f2(h)) -- PCD hulls take ~0.1-0.25
end
opening("Duels door", -95.5, {16.5, 20, 23.5}, 20, 11.0, 8.0)
opening("west portal", -141, {17, 22, 27}, 20, 9.0, 12.0)
for _, x in {-143, -146, -148.5, -151, -154} do opening("west passage", x, {17, 22, 27}, 20, 9.0, 12.0) end
opening("tunnel end", 105.5, {1, 9, 17}, 5, 22.0, 18.0)
-- mouth: cheeks 52.4 apart; the roll-up door guide channels (E_Mouth__dark_metal, 0.7 deep) stand inside them -> 51.0 clear
opening("hangar mouth", 126.1, {1, 9, 16.5}, 5, 51.0, 17.0)

---------------------------------------------------------------- 2. floors
say("== floors")
local function grid(label, x0, x1, z0, z1, top, want, tol)
	local lo, hi, miss = math.huge, -math.huge, 0
	for x = x0, x1, 2 do for z = z0, z1, 2 do
		local y = floorAt(x, z, top)
		if not y then miss += 1 else lo = math.min(lo, y); hi = math.max(hi, y) end
	end end
	say(label, "floor", f2(lo), "..", f2(hi), "missing", miss)
	flag(miss == 0 and lo >= want - tol, label, "floor gap / low")
	return lo, hi
end
-- Duels hall (lane, medallion, pads with their 16.34 team plates on top; obstacles excluded by taking the walkable band)
local lo, hi = math.huge, -math.huge
local hallMiss, hallHigh = 0, {}
-- [FEAT] the feature pass's drop pits (LobbyMap.Features.DropPits.Pit_*.Catch footprints) are holes on purpose: skipped here
local pitBoxes = {}
local FDP = LM:FindFirstChild("Features") and LM.Features:FindFirstChild("DropPits")
for _, d in (FDP and FDP:GetDescendants() or {}) do if d:IsA("BasePart") and d.Name == "Catch" then table.insert(pitBoxes, d) end end
local function inPit(x, z) for _, c in pitBoxes do if math.abs(x - c.Position.X) <= c.Size.X / 2 and math.abs(z - c.Position.Z) <= c.Size.Z / 2 then return true end end return false end
local pitSkipped = 0
for x = -137, -97, 2 do for z = -42, 42, 2 do
	local y, who = floorAt(x, z, 21)
	if not y and inPit(x, z) then pitSkipped += 1 elseif not y then hallMiss += 1 elseif y > 16.6 then hallHigh[who] = (hallHigh[who] or 0) + 1 else lo = math.min(lo, y); hi = math.max(hi, y) end
end end
local hh = {}; for k, v in hallHigh do table.insert(hh, k .. " x" .. v) end
say("Duels hall walkable floor", f2(lo), "..", f2(hi), "missing", hallMiss, "| raised (obstacles: pylons, props):", #hh > 0 and table.concat(hh, ", ") or "none")
say("Duels hall drop-pit points skipped (holes by design, [FEAT])", pitSkipped)
flag(hallMiss == 0 and lo >= 15.9, "Duels hall floor gap")
grid("west deck", -197, -158, -26, 26, 21, 15.95, 0.1)
-- hangar / pad: props (workbench, lockers, bowser, GPU, crates) stand on the floor; only floor-level hits count
local function deckGrid(label, x0, x1, z0, z1)
	local lo2, hi2, miss = math.huge, -math.huge, 0
	for x = x0, x1, 2 do for z = z0, z1, 2 do local y = deckAt(x, z, 6); if not y then miss += 1 elseif y < 0.5 then lo2 = math.min(lo2, y); hi2 = math.max(hi2, y) end end end
	say(label, "floor (under-prop points skipped)", f2(lo2), "..", f2(hi2), "missing", miss); flag(miss == 0 and lo2 > -0.1, label, "floor gap")
end
deckGrid("hangar", 107, 123, -24, 24)
deckGrid("pad deck", 129, 149, -24, 24)
say("profile z0 hub top landing -> deck (x:y):")
local prof, prev, maxstep = {}, nil, 0
for x = -84, -196, -1 do --[[ deck end kerb at x -198.5 is the edge, not a step ]] local y = floorAt(x, 0, 21) or -99; if prev then maxstep = math.max(maxstep, math.abs(y - prev)) end; prev = y; if x % 8 == 0 then table.insert(prof, ("%d:%.2f"):format(x, y)) end end
say(table.concat(prof, " "), "max step", f2(maxstep)); flag(maxstep < 0.6, "step on the Duels axis")
for _, z in {-6, 0, 6} do
	prof, prev, maxstep = {}, nil, 0
	for x = 70, 149, 1 do --[[ open-edge kerb (1.4) at x 150.6+ is the edge, not a step ]] local y = deckAt(x, z, 6) or -99; if prev then maxstep = math.max(maxstep, math.abs(y - prev)) end; prev = y; if x % 10 == 0 then table.insert(prof, ("%d:%.2f"):format(x, y)) end end
	say("profile z" .. z .. " tunnel -> pad (heli excluded):", table.concat(prof, " "), "max step", f2(maxstep)); flag(maxstep < 0.6, "step tunnel/hangar/pad", z)
end
-- kit under the team plates: nothing of the kit above the plate top (16.34)
local rk = RaycastParams.new(); rk.FilterType = Enum.RaycastFilterType.Include; rk.FilterDescendantsInstances = {R3}; rk.RespectCanCollide = true
for _, m in LM.Duels:GetChildren() do if m:IsA("Model") and m:GetAttribute("QueueName") then
	local top, corner, cornerAt = -99, -99, ""
	for _, zn in {"Team1", "Team2"} do local z = m:FindFirstChild(zn); if z then
		local h = z.Size / 2
		for gx = -h.X + 0.25, h.X - 0.25, 0.5 do for gz = -h.Z + 0.25, h.Z - 0.25, 0.5 do
			local r = workspace:Raycast(z.Position + Vector3.new(gx, 4, gz), Vector3.new(0, -12, 0), rk)
			if r then
				local core = math.abs(gx) <= h.X - 2 and math.abs(gz) <= h.Z - 2
				if core then top = math.max(top, r.Position.Y) elseif r.Position.Y > corner then corner = r.Position.Y; cornerAt = zn .. " " .. r.Instance.Name .. " " .. f3(r.Position) end
			end
		end end
	end end
	say(m.Name, "highest kit surface in the cell cores (2 studs in from the edge)", f2(top), "| on the cell rims", f2(corner), corner > 16.4 and cornerAt or "")
	flag(top <= 16.36, m.Name, "kit above the team plate")
end end

---------------------------------------------------------------- 3. walk routes (block cast 2 x 4.5 x 2, bottom 0.75 above the floor)
say("== routes")
local function route(name, pts, top)
	local hits = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ya = (floorAt(a.X, a.Y, top) or 0) + 3; local yb = (floorAt(b.X, b.Y, top) or 0) + 3
		local A, B = Vector3.new(a.X, ya, a.Y), Vector3.new(b.X, yb, b.Y)
		local r = workspace:Blockcast(CFrame.lookAt(A, B), Vector3.new(2, 4.5, 2), B - A, rp)
		if r then table.insert(hits, ("seg%d %s at %s"):format(i, r.Instance:GetFullName(), f3(r.Position))) end
	end
	say(name, #hits == 0 and "clear" or table.concat(hits, "; ")); flag(#hits == 0, "route blocked", name)
end
local V = Vector2.new
route("hub top landing (stairs foot of the landing, NPC spot) -> Duels door -> hall centre", {V(-86.5, 7.5), V(-86.5, 3), V(-88, 0), V(-95.5, 0), V(-104, 0), V(-114, -4)}, 21)
for _, m in LM.Duels:GetChildren() do if m:IsA("Model") and m:GetAttribute("QueueName") then
	for _, zn in {"Team1", "Team2"} do local z = m:FindFirstChild(zn)
		local c = V(z.Position.X, z.Position.Z)
		-- approach from the lane (z 0) along x, then straight along z into the cell
		route("hall -> " .. m.Name .. "." .. zn, {V(-114, 0), V(c.X, 0), c}, 21)
	end
end end
route("hall -> west portal -> passage -> deck", {V(-114, 0), V(-130, 0), V(-141, 0), V(-155, 0), V(-170, 0), V(-185, 12)}, 21)
route("deck -> back to the Duels door -> top landing", {V(-185, 12), V(-170, 0), V(-141, 0), V(-114, 4), V(-95.5, 0), V(-88, 0), V(-86.5, 3), V(-86.5, 7.5)}, 21)
route("hub -> east tunnel -> hangar (respawn)", {V(40, 0), V(80, 0), V(100, 0), V(112, 0)}, 6)
route("hangar -> ExfilBarrier face", {V(112, 0), V(120, 0), V(125.9, 0)}, 6)
route("hangar -> pad (round the barrier, z -18)", {V(112, 0), V(118, -18), V(126.1, -18), V(134, -18), V(144, -18)}, 6)
route("pad -> back to the hub (z -18)", {V(144, -18), V(134, -18), V(126.1, -18), V(118, -18), V(112, 0), V(90, 0), V(60, 0)}, 6)
-- north side: the heli tail (z 14..23) reaches over the walkway there (info only)
do local A, B = Vector3.new(144, 3, 24.5), Vector3.new(118, 3, 24.5); local r = workspace:Blockcast(CFrame.lookAt(A, B), Vector3.new(2, 4.5, 2), B - A, rp); say("info: pad north side z 24.5 -> hangar", r and (r.Instance:GetFullName() .. " at " .. f3(r.Position)) or "clear") end

---------------------------------------------------------------- 4. Exfil hooks: barrier reach, respawn, camera + lift path, heli clearance
say("== Exfil")
local eb = LM.Exfil:FindFirstChild("ExfilBarrier")
say("ExfilBarrier", eb and f3(eb.Position), eb and f3(eb.Size), "CanTouch", eb and eb.CanTouch, "CanCollide", eb and eb.CanCollide, "tag", eb and CS:HasTag(eb, "ExfilBarrier"))
flag(eb and eb.CanTouch and CS:HasTag(eb, "ExfilBarrier"), "ExfilBarrier tag / CanTouch")
for _, z in {-10, -5, 0, 5, 10} do
	-- a character (2 x 5 x 1) walking along +x at this z: first colliding obstacle, and does its body reach the barrier?
	local o = Vector3.new(110, 3, z)
	local r = workspace:Blockcast(CFrame.new(o), Vector3.new(1, 4.5, 2), Vector3.new(eb.Position.X - 110, 0, 0), rp)
	local stopX = r and r.Position.X or eb.Position.X
	local reaches = stopX >= eb.Position.X - eb.Size.X / 2 - 0.05
	say("walk to barrier z" .. z, "first obstacle", r and r.Instance.Name or "none", "stop x", f2(stopX), "body reaches barrier", reaches)
	flag(reaches, "barrier out of reach at z", z)
end
local fl = floorAt(112, 0, 8)
local op = OverlapParams.new(); op.RespectCanCollide = true; op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = {LM.NPCs}
local names = bodyHits(CFrame.new(112, 3.5, 0), Vector3.new(2, 4.6, 2))
say("hangar respawn (112,3.5,0): floor", f2(fl), "parts in the body box:", #names == 0 and "none" or table.concat(names, ","))
flag(fl and math.abs(fl) < 0.1 and #names == 0, "hangar respawn")
-- lowest kit point vs the fall-catch line (-25)
local minY = math.huge; for _, d in R3:GetDescendants() do if d:IsA("BasePart") then minY = math.min(minY, d.Position.Y - d.Size.Y / 2) end end
say("lowest kit point", f2(minY), "(fall catch at -25)"); flag(minY > -25, "kit below -25")

-- camera: everything visible blocks the view (kit made queryable temporarily; glass / clip / Neon lines are see-through or flat)
local saved = {}
for _, d in R3:GetDescendants() do if d:IsA("BasePart") then saved[d] = d.CanQuery; d.CanQuery = d.Transparency < 0.5 end end
local rv = RaycastParams.new(); rv.FilterType = Enum.RaycastFilterType.Exclude
local vexcl = {LM.Heli, LM.Exfil, LM.NPCs, LM.Duels}
rv.FilterDescendantsInstances = vexcl
local function blockedView(a, b)
	local r = workspace:Raycast(a, b - a, rv)
	while r and r.Instance.Transparency >= 0.5 do -- skip invisible parts the kit did not make non-queryable
		local p = r.Position + (b - a).Unit * 0.05
		r = workspace:Raycast(p, b - p, rv)
	end
	return r
end
local cab = LM.Exfil.CabinPoint.CFrame
local camHits = {}
for i = 0, 26 do
	local e = i / 10
	local off = CFrame.new(e * e * 3.2, math.min(e, 4) ^ 1.5 * 2.2, 0) * CFrame.Angles(0, 0, -math.min(e * 0.06, 0.18))
	local liftT = CFrame.new(cab.Position) * off * CFrame.new(-cab.Position)
	local tgt = (liftT * cab).Position
	local cam = Vector3.new(120, 9 + e * 1.5, -18 - e * 2)
	for _, dy in {0, 3, -2} do
		local r = blockedView(cam, tgt + Vector3.new(0, dy, 0))
		if r then camHits[r.Instance:GetFullName()] = (camHits[r.Instance:GetFullName()] or "") .. ("e%.1f/%d "):format(e, dy) end
	end
end
local ch = {}; for k, v in camHits do table.insert(ch, k .. ": " .. v) end
say("ExfilFX camera -> heli (e 0..2.6, target +0/+3/-2):", #ch == 0 and "clear" or table.concat(ch, " | "))
flag(#ch == 0, "cutscene camera blocked")
local r0 = blockedView(Vector3.new(120, 9, -18), Vector3.new(133, 4, 2)); say("start shot lookAt((120,9,-18),(133,4,2))", r0 and r0.Instance:GetFullName() or "clear")
flag(not r0, "start shot blocked")
-- heli lift sweep: heli parts moved by the lift transform vs visible kit
local heliParts = {}; for _, p in LM.Heli:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then table.insert(heliParts, p) end end
local ok = OverlapParams.new(); ok.FilterType = Enum.RaycastFilterType.Include; ok.FilterDescendantsInstances = {R3}
local lhits, base = {}, {}
for _, p in heliParts do base[p] = p.CFrame end
for i = 0, 26, 2 do
	local e = i / 10
	local off = CFrame.new(e * e * 3.2, math.min(e, 4) ^ 1.5 * 2.2, 0) * CFrame.Angles(0, 0, -math.min(e * 0.06, 0.18))
	local liftT = CFrame.new(cab.Position) * off * CFrame.new(-cab.Position)
	for _, p in heliParts do p.CFrame = liftT * base[p] end
	if e > 0.1 then for _, p in heliParts do for _, h in workspace:GetPartsInPart(p, ok) do if h.Transparency < 1 then lhits[h.Name] = (lhits[h.Name] or "") .. ("e%.1f "):format(e) end end end end
end
for p, cf in base do p.CFrame = cf end
local lh = {}; for k, v in lhits do table.insert(lh, k .. ": " .. v:sub(1, 60)) end
say("heli lift sweep vs visible kit (e 0.2..2.6; skids rest on the deck at e 0):", #lh == 0 and "no overlap" or table.concat(lh, " | "))
flag(#lh == 0, "heli overlaps kit during lift")
for d, q in saved do d.CanQuery = q end
say("Heli attrs Mast", LM.Heli:GetAttribute("Mast"), "TailHub", LM.Heli:GetAttribute("TailHub"), "TailAxis", LM.Heli:GetAttribute("TailAxis"))
local nRot = 0; for _, p in LM.Heli:GetDescendants() do if p:GetAttribute("Rotor") then nRot += 1 end end
say("Heli rotor parts", nRot, "pivot", f3(LM.Heli:GetPivot().Position))
for _, n in {"HatchPoint", "CabinPoint", "L_Hangar", "L_Pad"} do local p = LM.Exfil:FindFirstChild(n); say("Exfil." .. n, p and f3(p.Position), p and CS:HasTag(p, "RoomLight") and ("RoomLight " .. tostring(p:GetAttribute("Room")) .. " dist to RoomFX centre " .. f2((p.Position - Vector3.new(150, 10, 0)).Magnitude)) or "") end
for _, n in {"HeliN", "HeliS", "HeliEnd"} do local p = LM.FX.FX2:FindFirstChild(n); say("FX2." .. n, p and ("cc " .. tostring(p.CanCollide) .. " T " .. p.Transparency) or "MISSING"); flag(p and p.CanCollide, n) end

---------------------------------------------------------------- 5. Duels hooks, 1v1 boards, step-off spots
say("== Duels")
say("QueuePad tagged", #CS:GetTagged("QueuePad"), "DuelQueued x DuelBarrier collidable:", PS:CollisionGroupsAreCollidable("DuelQueued", "DuelBarrier"))
flag(#CS:GetTagged("QueuePad") == 6, "QueuePad count"); flag(not PS:CollisionGroupsAreCollidable("DuelQueued", "DuelBarrier"), "collision groups")
local pads, zones, rings = {}, {}, {}
for _, m in LM.Duels:GetChildren() do if m:IsA("Model") and m:GetAttribute("QueueName") then
	table.insert(pads, m)
	local nb, cgOk = 0, true
	for _, c in m:GetChildren() do if c.Name:match("Barrier$") then nb += 1; if c.CollisionGroup ~= "DuelBarrier" then cgOk = false end end end
	for _, zn in {"Team1", "Team2"} do table.insert(zones, {m = m, z = m[zn]}) end
	-- barrier ring (outer box of the 8 barrier parts)
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, c in m:GetChildren() do if c.Name:match("Barrier$") then local h = c.Size / 2; x0 = math.min(x0, c.Position.X - h.X); x1 = math.max(x1, c.Position.X + h.X); z0 = math.min(z0, c.Position.Z - h.Z); z1 = math.max(z1, c.Position.Z + h.Z) end end
	rings[m] = {x0, x1, z0, z1}
	say(m.Name, "tag", CS:HasTag(m, "QueuePad"), "QueueName", m:GetAttribute("QueueName"), "PlayersPerTeam", m:GetAttribute("PlayersPerTeam"), "barriers", nb, "DuelBarrier", cgOk,
		"Holo", f3(m.Holo.Position), "PostCollide", f3(m.PostCollide.Position), "pivot", f3(m:GetPivot().Position), "pivot to Duels door", f2((m:GetPivot().Position - Vector3.new(-95.5, 21, 0)).Magnitude))
	flag(CS:HasTag(m, "QueuePad") and nb == 8 and cgOk, m.Name, "hook")
end end
-- Holo / PostCollide not buried (Holo point free of colliding geometry other than its own post; post's top above any kit except the pylon)
for _, m in pads do
	local nm = bodyHits(m.Holo.CFrame, Vector3.new(0.6, 0.6, 0.6), {LM.Duels})
	local pc = bodyHits(m.PostCollide.CFrame, m.PostCollide.Size * 0.98, {LM.Duels})
	local at = {}; for _, a in m.Holo:GetChildren() do if a:IsA("Attachment") then table.insert(at, f3(a.WorldPosition)) end end
	say(m.Name, "Holo point inside:", #nm == 0 and "nothing" or table.concat(nm, ","), "| PostCollide inside:", #pc == 0 and "nothing" or table.concat(pc, ","), "| Holo beam attachments at", table.concat(at, " "))
end
-- board visibility (billboard 11 x 6 at Holo + 2.6; corners at +-4 lateral, +-2 vertical) from the pads, the door and the hall
local function boardVis(holo, eye)
	local c = holo.Position + Vector3.new(0, 2.6, 0)
	local dir = (c - eye); local lat = Vector3.new(-dir.Z, 0, dir.X).Unit
	local n, clear = 0, 0
	for _, u in {-5, -2.5, 0, 2.5, 5} do for _, v in {-2.5, 0, 2.5} do
		n += 1
		if not blockedView(eye, c + lat * u + Vector3.new(0, v, 0)) then clear += 1 end
	end end
	return math.floor(clear / n * 100 + 0.5), n
end
for _, d in R3:GetDescendants() do if d:IsA("BasePart") then saved[d] = d.CanQuery; d.CanQuery = d.Transparency < 0.5 end end
local eyes = {{"door threshold", Vector3.new(-96.5, 20.5, 0)}, {"inside door", Vector3.new(-100, 20.5, 0)}, {"hall centre", Vector3.new(-114, 20.5, 0)}, {"west portal", Vector3.new(-136, 20.5, 0)}}
for _, m in pads do
	local res = {}
	local own = {}
	for _, zn in {"Team1", "Team2"} do local z = m[zn]; table.insert(own, {m.Name .. "." .. zn, Vector3.new(z.Position.X, 20.5, z.Position.Z)}) end
	local list = {}; for _, e in eyes do table.insert(list, e) end; for _, e in own do table.insert(list, e) end
	local worst = 100
	for _, e in list do local c = boardVis(m.Holo, e[2]); table.insert(res, e[1] .. " " .. c .. "%"); worst = math.min(worst, c) end
	say(m.Name, "board visibility (11 x 6 billboard, 15 rays):", table.concat(res, ", "))
	if m.Name:match("1v1") then flag(worst >= 90, m.Name, "board partly hidden from a viewpoint") end
end
for d, q in saved do d.CanQuery = q end
-- QueueManager stepOffCFrame: zone + dir(screen -> zone) * (half + 4); dir from the Holo (bay.screens[1])
local function stepOff(zone, screenPos)
	local flat = Vector3.new(zone.Position.X - screenPos.X, 0, zone.Position.Z - screenPos.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
	local half = math.abs(dir.X) * zone.Size.X / 2 + math.abs(dir.Z) * zone.Size.Z / 2
	local floorY = zone.Position.Y - zone.Size.Y / 2
	return Vector3.new(zone.Position.X, floorY + 3.2, zone.Position.Z) + dir * (half + 4)
end
local function inZone(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos); local h = zone.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and rel.Y > -h.Y - 1 and rel.Y < h.Y + 2
end
local function landing(m, zn, screenPos)
	local p = stepOff(m[zn], screenPos)
	local notes = {}
	for _, z in zones do if z.z ~= m[zn] and inZone(z.z, p) then table.insert(notes, "IN " .. z.m.Name .. "." .. z.z.Name) end end
	for om, r in rings do if om ~= m and p.X > r[1] and p.X < r[2] and p.Z > r[3] and p.Z < r[4] then table.insert(notes, "inside barrier ring of " .. om.Name) end end
	local y = floorAt(p.X, p.Z, 21)
	local bn = bodyHits(CFrame.new(p), Vector3.new(2, 4.6, 1), {LM.Duels}) -- QueueManager puts the root at zone floor + 3.2
	if #bn > 0 then table.insert(notes, "body overlaps " .. table.concat(bn, ",")) end
	return p, y, notes
end
say("step-off spots (QueueManager.stepOffCFrame: LeaveQueue / kick-off / side full)")
for _, m in pads do for _, zn in {"Team1", "Team2"} do
	local p, y, notes = landing(m, zn, m.Holo.Position)
	local line = ("%s.%s -> (%.2f, %.2f) floor %s %s"):format(m.Name, zn, p.X, p.Z, f2(y), #notes == 0 and "ok" or table.concat(notes, "; "))
	local o = m.Holo:GetAttribute("Rooms3_OrigCF")
	if o then local po, yo, no = landing(m, zn, o.Position); line ..= (" | old Holo: (%.2f, %.2f) %s"):format(po.X, po.Z, #no == 0 and "ok" or table.concat(no, "; ")) end
	say(line)
	if m.Name:match("1v1") then flag(#notes == 0, m.Name, zn, "step-off spot") end
end end

---------------------------------------------------------------- 6. state
say("== state")
local hid = 0; for _, d in LM:GetDescendants() do if d:GetAttribute("Rooms3Hidden") then hid += 1 end end
say("Rooms3Hidden instances", hid)
for _, n in {"Arcs", "EnergyMotes", "SparkDuels"} do local p = LM.FX:FindFirstChild(n); say("FX." .. n, p and p:GetAttribute("Rooms3Hidden") and "hidden" or "visible", p and CS:HasTag(p, "LobbySpark") and "LobbySpark tag" or "") end
for _, n in {"TargetTop", "PointLight"} do local p = LM.Lights:FindFirstChild(n); local l = p and p:FindFirstChildWhichIsA("Light"); say("Lights." .. n, p and f3(p.Position), l and ("enabled " .. tostring(l.Enabled))) end
local rem = game.ServerStorage:FindFirstChild("_RebuildRemoved")
say("K_Scale3 / K_Marker3 in _RebuildRemoved", rem and rem:FindFirstChild("K_Scale3") ~= nil, rem and rem:FindFirstChild("K_Marker3") ~= nil, "workspace.rooms3", workspace:FindFirstChild("rooms3") ~= nil)
for _, n in {"Duels", "Exfil", "Heli", "Lights", "FX", "Unique", "Rooms3"} do say(n, LM:FindFirstChild(n) and "ok" or "MISSING") end
local cnt, nm = {}, 0
for _, d in R3:GetDescendants() do if d:IsA("MeshPart") then nm += 1; if d.CanCollide then cnt[d.CollisionFidelity.Name] = (cnt[d.CollisionFidelity.Name] or 0) + 1 end end end
local cs = {}; for k, v in cnt do table.insert(cs, k .. " " .. v) end
say("kit meshes", nm, "colliding:", table.concat(cs, ", "))
say("== FAILS", bad)
return table.concat(out, "\n")
