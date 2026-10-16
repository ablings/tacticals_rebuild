-- check_polish_exfil.lua (read-only; restores what it toggles and removes its temporary clones): logic checks for
-- Polish.Exfil (fix/polish_exfil.lua).
-- 1. clip (rays): from each new part's centre to its 6 face centres and 8 corners (shrunk 0.05) against old visible
--    geometry; (probe) GetPartsInPart with a copy 0.1 smaller.
-- 2. support: every new Model / loose part group rests on the floor (lowest point 0..0.12 above the hit below it).
-- 3. hooks: ExfilBarrier (tag, CanTouch, pose unchanged), HatchPoint / CabinPoint, Heli (Mast / TailHub / TailAxis, Rotor
--    parts, no polish attribute inside), L_Hangar / L_Pad (RoomLight, Room = Exfil), X_Clip (collides), no new lights.
-- 4. ExfilFX: the cutscene camera path (start shot + lift e = 0..2.6, camera to the cabin target and +3/-2 from it) is
--    clear of new parts, and the heli lift sweep (ExfilFX's own transform) never overlaps a new part.
-- 5. walk routes (block cast 2 x 4.5 x 2, collidable only): hub -> tunnel -> hangar respawn, hangar -> barrier face,
--    hangar -> pad round the barrier (z -18), along the open edge, the north side; hangar respawn body box clear.
local LM = workspace.LobbyMap
local root = LM.Polish:FindFirstChild("Exfil")
assert(root, "run fix/polish_exfil.lua first")
local CS = game:GetService("CollectionService")
local out = {}
local function say(s) table.insert(out, s) end

local newParts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(newParts, d) end end
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 then d.CanQuery = true; table.insert(q, d) end
end
local skip = {root, LM.Exfil, LM.Rooms3.X_Clip}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip

-- 1. clips
local clips, seen = {}, {}
local function note(p, h, how)
	local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Exfil.", "") .. " x " .. h:GetFullName():gsub("Workspace.LobbyMap.", "")
	if not seen[key] then seen[key] = true; table.insert(clips, key .. " (" .. how .. ")") end
end
for _, p in ipairs(newParts) do
	if p.Transparency < 1 then
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
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = skip
local probe = 0
for _, p in ipairs(newParts) do
	if p.Transparency < 1 and p.Size.Magnitude > 0.3 then
		local c = Instance.new("Part"); c.Anchored = true; c.CanCollide = false; c.Transparency = 1
		c.Shape = p:IsA("Part") and p.Shape or Enum.PartType.Block
		c.Size = Vector3.new(math.max(p.Size.X - 0.1, 0.02), math.max(p.Size.Y - 0.1, 0.02), math.max(p.Size.Z - 0.1, 0.02))
		c.CFrame = p.CFrame
		for _, h in ipairs(workspace:GetPartsInPart(c, op)) do
			-- flat floor fixtures (studs, tie-downs, decals) sit on the floor: the floor meshes' collision hulls are a little
			-- above their visible top, so a probe touching a floor mesh is contact, not a clip (rays above catch real ones)
			local flat = math.min(p.Size.X, p.Size.Y, p.Size.Z) <= 0.1
			local isFloor = h.Name:find("Floor__") ~= nil or h.Name:find("Tunnel__floor") ~= nil
			if h.Transparency < 0.95 and not h:IsDescendantOf(root) and not (flat and isFloor) then note(p, h, "probe") end
		end
		c:Destroy(); probe += 1
	end
end
say(("CLIPS (%d, probes %d, new parts %d):"):format(#clips, probe, #newParts))
for _, c in ipairs(clips) do say("  " .. c) end

-- 2. support: per Model (or per part for loose ones), lowest point vs the floor hit below it
say("SUPPORT:")
local function low(m)
	local y, at = 1e9, nil
	for _, p in ipairs(m:IsA("BasePart") and {m} or m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local cf, s = p.CFrame, p.Size
			for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
				local w = cf * Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
				if w.Y < y then y = w.Y; at = w end
			end end end
		end
	end
	return y, at
end
local bad = 0
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and m.Name ~= "RunwayLights" and m.Name ~= "Hazard" and m.Name ~= "GroundGear" then
		local y, at = low(m)
		if at then
			local h = workspace:Raycast(Vector3.new(at.X, y + 0.05, at.Z), Vector3.new(0, -3, 0), rp)
			local gap = h and (y - h.Position.Y) or 99
			if gap < -0.03 or gap > 0.12 then bad += 1; say(("  %s bottom %.2f gap %.3f"):format(m.Name, y, gap)) end
		end
	end
end
-- runway studs / tie-downs / stencils: each sits 0..0.1 above the floor
for _, p in ipairs(newParts) do
	if (p.Name:find("_Rim") or p.Name:find("TieDown_") or p.Name:find("Stencil_") or p.Name == "EdgeBand") then
		local y = p.Position.Y - (p.Name:find("Stencil_") and 0.015 or (p.Name == "EdgeBand" and 0.02 or 0.03))
		local h = workspace:Raycast(Vector3.new(p.Position.X, y + 0.01, p.Position.Z), Vector3.new(0, -2, 0), rp)
		local gap = h and (y - h.Position.Y) or 99
		if gap < -0.005 or gap > 0.1 then bad += 1; say(("  %s gap %.3f"):format(p.Name, gap)) end
	end
end
say(("  bad %d"):format(bad))

-- 3. hooks
say("HOOKS:")
local ex = LM.Exfil
local b = ex:FindFirstChild("ExfilBarrier")
say(("  ExfilBarrier tag %s CanTouch %s at %s size %s"):format(tostring(b and CS:HasTag(b, "ExfilBarrier")), tostring(b and b.CanTouch),
	b and tostring(b.Position) or "-", b and tostring(b.Size) or "-"))
say(("  HatchPoint %s  CabinPoint %s"):format(tostring(ex.HatchPoint.Position), tostring(ex.CabinPoint.Position)))
local heli = LM.Heli
local nRot, polished = 0, 0
for _, d in ipairs(heli:GetDescendants()) do
	if d:GetAttribute("Rotor") then nRot += 1 end
	for k in pairs(d:GetAttributes()) do if k:find("Polish") then polished += 1 end end
end
say(("  Heli Mast %s TailHub %s TailAxis %s rotor parts %d, polish attributes inside %d, pivot %s"):format(
	tostring(heli:GetAttribute("Mast") ~= nil), tostring(heli:GetAttribute("TailHub") ~= nil), tostring(heli:GetAttribute("TailAxis") ~= nil),
	nRot, polished, tostring(heli:GetPivot().Position)))
for _, n in ipairs({"L_Hangar", "L_Pad"}) do
	local l = ex:FindFirstChild(n)
	say(("  %s RoomLight %s Room %s light enabled %s"):format(n, tostring(l and CS:HasTag(l, "RoomLight")), tostring(l and l:GetAttribute("Room")),
		tostring(l and l:FindFirstChildWhichIsA("Light") and l:FindFirstChildWhichIsA("Light").Enabled)))
end
local clip = LM.Rooms3.X_Clip.X_Clip__clip
say(("  X_Clip collide %s transparency %.1f"):format(tostring(clip.CanCollide), clip.Transparency))
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
local en = 0; for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Light") and d.Enabled then en += 1 end end
local nc = 0; for _, p in ipairs(newParts) do if p.CanCollide then nc += 1 end end
say(("  new lights %d, enabled lights (Edit, workspace) %d, new collidable parts %d"):format(nl, en, nc))

-- 4. ExfilFX camera path and heli lift sweep (new parts only)
local incl = RaycastParams.new(); incl.FilterType = Enum.RaycastFilterType.Include; incl.FilterDescendantsInstances = {root}
local saveQ = {}
for _, p in ipairs(newParts) do saveQ[p] = p.CanQuery; p.CanQuery = true end
local camHits = {}
local pivot = ex.CabinPoint.CFrame
local function lift(e)
	local off = CFrame.new(e * e * 3.2, math.min(e, 4) ^ 1.5 * 2.2, 0) * CFrame.Angles(0, 0, -math.min(e * 0.06, 0.18))
	return CFrame.new(pivot.Position) * off * CFrame.new(-pivot.Position)
end
do
	local h = workspace:Raycast(Vector3.new(120, 9, -18), Vector3.new(133, 4, 2) - Vector3.new(120, 9, -18), incl)
	if h then table.insert(camHits, "start " .. h.Instance.Name) end
	for e = 0, 2.6, 0.1 do
		local camPos = Vector3.new(120, 9 + e * 1.5, -18 - e * 2)
		local tgt = (lift(e) * pivot).Position
		for _, dy in ipairs({0, 3, -2}) do
			local hh = workspace:Raycast(camPos, tgt + Vector3.new(0, dy, 0) - camPos, incl)
			if hh then table.insert(camHits, ("e %.1f dy %d %s"):format(e, dy, hh.Instance.Name)) end
		end
	end
end
say(("EXFILFX camera path hits on new parts: %d %s"):format(#camHits, table.concat(camHits, ", ")))
local tmp = Instance.new("Folder"); tmp.Name = "_CheckExfilTmp"; tmp.Parent = workspace
local clones = {}
for _, p in ipairs(heli:GetDescendants()) do
	if p:IsA("BasePart") and p.Transparency < 1 then
		local c = p:Clone(); c:ClearAllChildren(); c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.Transparency = 1; c.Parent = tmp
		table.insert(clones, {c, p.CFrame})
	end
end
local opIn = OverlapParams.new(); opIn.FilterType = Enum.RaycastFilterType.Include; opIn.FilterDescendantsInstances = {root}
local sweep, sseen = {}, {}
for e = 0, 2.6, 0.1 do
	local T = lift(e)
	for _, c in ipairs(clones) do
		c[1].CFrame = T * c[2]
		for _, h in ipairs(workspace:GetPartsInPart(c[1], opIn)) do
			local k = c[1].Name .. " x " .. h.Name
			if not sseen[k] then sseen[k] = true; table.insert(sweep, ("%s @e%.1f"):format(k, e)) end
		end
	end
end
tmp:Destroy()
for p, v in pairs(saveQ) do p.CanQuery = v end
say(("HELI lift sweep overlaps with new parts: %d %s"):format(#sweep, table.concat(sweep, ", ")))

-- 5. walk routes, collidable geometry only
local wp = RaycastParams.new(); wp.FilterType = Enum.RaycastFilterType.Exclude; wp.FilterDescendantsInstances = {LM.Exfil}
wp.RespectCanCollide = true
local routes = {
	{"hub -> tunnel -> hangar respawn", {Vector3.new(70, 2.6, 0), Vector3.new(96, 2.6, 0), Vector3.new(112, 2.6, 0)}},
	{"hangar -> barrier face", {Vector3.new(112, 2.6, 0), Vector3.new(127, 2.6, 0)}},
	{"hangar -> pad round the barrier (z -18)", {Vector3.new(112, 2.6, 0), Vector3.new(118, 2.6, -18), Vector3.new(148, 2.6, -18)}},
	{"open edge south -> north", {Vector3.new(148.5, 2.6, -18), Vector3.new(148.5, 2.6, 0), Vector3.new(148.5, 2.6, 14)}},
	{"pad north side (z 16)", {Vector3.new(130, 2.6, 16), Vector3.new(146, 2.6, 16)}},
	{"pad -> hub", {Vector3.new(140, 2.6, -18), Vector3.new(118, 2.6, -18), Vector3.new(100, 2.6, -4), Vector3.new(70, 2.6, 0)}},
}
local blocked = 0
for _, r in ipairs(routes) do
	local pts = r[2]; local hitTxt = "clear"
	for i = 1, #pts - 1 do
		local a, bb = pts[i], pts[i + 1]
		local h = workspace:Blockcast(CFrame.lookAt(a, bb), Vector3.new(2, 4.5, 2), bb - a, wp)
		if h then hitTxt = ("BLOCKED by %s at %s"):format(h.Instance:GetFullName():gsub("Workspace.LobbyMap.", ""), tostring(h.Position)); blocked += 1; break end
	end
	say(("  route %s: %s"):format(r[1], hitTxt))
end
local inBox = workspace:GetPartBoundsInBox(CFrame.new(112, 3.5, 0), Vector3.new(2, 5, 2), op)
local solid = 0; for _, p in ipairs(inBox) do if p.CanCollide and p.Transparency < 1 then solid += 1 end end
say(("WALK: routes blocked %d; hangar respawn (112,3.5,0) solid parts in body box %d"):format(blocked, solid))

for _, d in ipairs(q) do d.CanQuery = false end
return table.concat(out, "\n")
