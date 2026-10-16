-- check_polish_gates.lua (read-only; restores what it toggles): logic checks for Polish.Gates (fix/polish_gates.lua).
-- 1. clip (rays): from each new part's centre to its 6 face centres and 8 corners (shrunk 0.05) against old visible geometry,
--    which includes the Shop / Armory polish (Polish.Shop / Polish.Armory) at the corridor ends; (probe) GetPartsInPart with a
--    copy 0.1 smaller. Flat sills (<= 0.1 thick) touching floor meshes count as contact (floor hulls sit above the floor).
-- 2. support: sills rest on the floor (gap 0..0.08); wall pieces have the wall within 0.1 behind them.
-- 3. clearance: minimum clear width (x) per corridor at y 1..11 and clear height at x -3..3, every 0.25 in z, measured with
--    Polish excluded and included: the two must be equal (nothing new narrows or lowers the corridor); width
--    is reported (the N junction box narrows the body width to 9.54 before this pass), height >= 12.
-- 4. hooks / budget: SHOP sign reads OUTFITTERS, ARMORY sign unchanged, no Light inside Polish.Gates, 0 new collidable parts,
--    enabled lights in Edit, Shop_Counter / GunWall_Kit / Armory_Dais prompts enabled.
-- 5. walk routes (block cast 2 x 4.5 x 2, collidable only): hub -> Shop counter front, hub -> Armory dais front.
local LM = workspace.LobbyMap
local root = LM.Polish:FindFirstChild("Gates")
assert(root, "run fix/polish_gates.lua first")
local out = {}
local function say(s) table.insert(out, s) end

local newParts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(newParts, d) end end
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 then d.CanQuery = true; table.insert(q, d) end
end
local skip = {root}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip

-- 1. clips
local clips, seen = {}, {}
local function note(p, h, how)
	local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Gates.", "") .. " x " .. h:GetFullName():gsub("Workspace.LobbyMap.", "")
	if not seen[key] then seen[key] = true; table.insert(clips, key .. " (" .. how .. ")") end
end
local function isFloor(h) return h.Name:find("plate_metal") or h.Name:find("floor_") or h.Name:find("Floor__") end
for _, p in ipairs(newParts) do
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
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = skip
local probe = 0
for _, p in ipairs(newParts) do
	local c = Instance.new("Part"); c.Anchored = true; c.CanCollide = false; c.Transparency = 1
	c.Shape = p.Shape
	c.Size = Vector3.new(math.max(p.Size.X - 0.1, 0.02), math.max(p.Size.Y - 0.1, 0.02), math.max(p.Size.Z - 0.1, 0.02))
	c.CFrame = p.CFrame
	for _, h in ipairs(workspace:GetPartsInPart(c, op)) do
		local flat = math.min(p.Size.X, p.Size.Y, p.Size.Z) <= 0.1
		if h.Transparency < 0.95 and not (flat and isFloor(h)) then note(p, h, "probe") end
	end
	c:Destroy(); probe += 1
end
say(("CLIPS (%d, probes %d, new parts %d):"):format(#clips, probe, #newParts))
for _, c in ipairs(clips) do say("  " .. c) end

-- 2. support
local bad = 0
for _, p in ipairs(newParts) do
	if p.Name:find("^Sill") then
		local h = workspace:Raycast(p.Position + Vector3.new(0, 0.02, 0), Vector3.new(0, -1, 0), rp)
		local gap = h and (p.Position.Y - p.Size.Y / 2 - h.Position.Y) or 99
		if gap < -0.06 or gap > 0.08 then bad += 1; say(("  %s gap %.3f"):format(p:GetFullName(), gap)) end
	elseif p.Name == "Housing" or p.Name:find("^Strip") or p.Name:find("^Dest") then
		local side = p.Position.X > 0 and 1 or -1
		local back = p.Position + Vector3.new(side * (p.Size.X / 2 - 0.01), 0, 0)
		local h = workspace:Raycast(back, Vector3.new(side * 0.12, 0, 0), rp)
		if not h then bad += 1; say(("  no wall behind %s at %s"):format(p:GetFullName():gsub("Workspace.LobbyMap.Polish.Gates.", ""), tostring(p.Position))) end
	end
end
say(("SUPPORT bad %d"):format(bad))

-- 3. clearance with and without Polish
local rpIn = RaycastParams.new(); rpIn.FilterType = Enum.RaycastFilterType.Exclude
local skipNo = table.clone(skip)
local function clearance(withPolish, sgn)
	rpIn.FilterDescendantsInstances = withPolish and skip or (function() local t = table.clone(skipNo); table.insert(t, LM.Polish); return t end)()
	local minW, minWBody, minH, atW, atH = 99, 99, 99, 0, 0
	for i = 0, 64 do
		local z = (48 + i * 0.25) * sgn
		for _, y in ipairs({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}) do
			local a = workspace:Raycast(Vector3.new(0, y, z), Vector3.new(-12, 0, 0), rpIn)
			local b = workspace:Raycast(Vector3.new(0, y, z), Vector3.new(12, 0, 0), rpIn)
			local w = (b and b.Position.X or 12) - (a and a.Position.X or -12)
			if w < minW then minW = w; atW = z end
			if y >= 2 and y <= 7 and w < minWBody then minWBody = w end
		end
		for _, x in ipairs({-3, -1.5, 0, 1.5, 3}) do
			local f = workspace:Raycast(Vector3.new(x, 3, z), Vector3.new(0, -5, 0), rpIn)
			local u = workspace:Raycast(Vector3.new(x, 3, z), Vector3.new(0, 20, 0), rpIn)
			local hgt = (u and u.Position.Y or 23) - (f and f.Position.Y or 0)
			if hgt < minH then minH = hgt; atH = z end
		end
	end
	return minW, minWBody, minH, atW, atH
end
for _, c in ipairs({{"N", 1}, {"S", -1}}) do
	local w0, wb0, h0 = clearance(false, c[2])
	local w1, wb1, h1, aw, ah = clearance(true, c[2])
	local ok = math.abs(w0 - w1) < 0.005 and math.abs(wb0 - wb1) < 0.005 and math.abs(h0 - h1) < 0.005 and h1 >= 12
	say(("CLEAR %s: width min %.2f (y 1-11, at z %.2f) / %.2f (body y 2-7), height min %.2f (at z %.2f); without polish %.2f / %.2f / %.2f -> %s"):format(
		c[1], w1, aw, wb1, h1, ah, w0, wb0, h0, ok and "OK" or "FAIL"))
end

-- 4. hooks and budget
local function signText(n)
	local p = LM.Hub1.Overlays:FindFirstChild(n)
	local l = p and p:FindFirstChild("Text") and p.Text:FindFirstChild("Label")
	return l and l.Text or "?"
end
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
local en = 0; for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Light") and d.Enabled then en += 1 end end
local nc = 0; for _, p in ipairs(newParts) do if p.CanCollide then nc += 1 end end
say(("HOOKS: SHOP sign '%s', ARMORY sign '%s'; new lights %d, enabled lights (Edit, workspace) %d, new collidable %d"):format(
	signText("SignText_SHOP"), signText("SignText_ARMORY"), nl, en, nc))
for _, n in ipairs({"Shop_Counter", "GunWall_Kit", "Armory_Dais"}) do
	local p = LM.Interact:FindFirstChild(n)
	local pr = p and p:FindFirstChildWhichIsA("ProximityPrompt", true)
	say(("  %s prompt %s OpenPanel %s"):format(n, tostring(pr and pr.Enabled), tostring(pr and pr:GetAttribute("OpenPanel"))))
end

-- 5. walk routes
local wp = RaycastParams.new(); wp.FilterType = Enum.RaycastFilterType.Exclude; wp.FilterDescendantsInstances = {}
wp.RespectCanCollide = true
local routes = {
	{"hub -> N corridor -> Shop counter front", {Vector3.new(0, 2.6, 20), Vector3.new(0, 2.6, 46), Vector3.new(0, 2.6, 66), Vector3.new(8, 2.6, 76), Vector3.new(8, 2.6, 92), Vector3.new(2.4, 2.6, 96.5)}},
	{"hub -> S corridor -> Armory dais front", {Vector3.new(0, 2.6, -20), Vector3.new(0, 2.6, -46), Vector3.new(0, 2.6, -66), Vector3.new(0, 2.6, -78), Vector3.new(-3.8, 2.6, -88)}},
	{"N corridor edges (x +-3.6)", {Vector3.new(-3.6, 2.6, 47), Vector3.new(-3.6, 2.6, 65)}},
	{"S corridor edges (x +-3.6)", {Vector3.new(3.6, 2.6, -47), Vector3.new(3.6, 2.6, -65)}},
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

for _, d in ipairs(q) do d.CanQuery = false end
return table.concat(out, "\n")
