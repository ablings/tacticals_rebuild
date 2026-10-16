-- polish_shop.lua : overnight polish, the Shop (quartermaster store). Tacticals_rebuild.rbxl ONLY.
-- Identity: warm, inviting quartermaster store. Warm ~3000K pools over the counter and shelves, wood shelving,
-- cream counter, price/stock boards, crates of stock. Cream dominant, olive trim. No ambient particles.
-- Idempotent: recolours store the original look in the attribute PolishShop_Orig (written once); every new
-- instance lives in Workspace.LobbyMap.Polish.Shop (rebuilt each run). Nothing old is deleted or hidden.
-- UNDO: python tools/run_luau.py fix/polish_shop.lua UNDO  (restores originals, removes Polish.Shop).
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap
local R2 = LM.Rooms2
local SS = game:GetService("ServerStorage")
local ATTR = "PolishShop_Orig"
local log = {}
local function say(s) table.insert(log, s) end

---------------------------------------------------------------------------------------------------
-- 1. Recolour table (the room's own Rooms2 meshes only: every S_* mesh is used by the Shop alone)
---------------------------------------------------------------------------------------------------
local C = Color3.fromRGB
local WARM_NEON = C(228, 186, 128)     -- ceiling strips + display lamps: warm white, not blue-white
local RECOLOUR = {
	-- walls: cream dominant (olive band, metal trim untouched)
	{"S_Walls", "S_Walls__wall_kick",   {Color = C(178, 170, 150)}},
	{"S_Walls", "S_Walls__wall_plate",  {Color = C(206, 199, 180)}},
	{"S_Walls", "S_Walls__wall_body",   {Color = C(190, 183, 164)}},
	{"S_Walls", "S_Walls__wall_light",  {Color = C(212, 206, 188)}},
	{"S_Piers", "S_Piers__wall_light",  {Color = C(212, 206, 188)}},
	{"S_Displays", "S_Displays__wall_light", {Color = C(206, 199, 180)}},
	-- ceiling: warm the cool grey so the warm pools read
	{"S_Ceiling", "S_Ceiling__ceiling",       {Color = C(128, 120, 106)}},
	{"S_Ceiling", "S_Ceiling__ceiling_gloss", {Color = C(74, 64, 52)}},
	-- counter: cream body, darker warm kick (olive band and trims kept)
	{"S_Counter", "S_Counter__wall_body",  {Color = C(222, 216, 198)}},
	{"S_Counter", "S_Counter__wall_plate", {Color = C(232, 226, 208)}},
	{"S_Counter", "S_Counter__wall_kick",  {Color = C(70, 64, 56)}},
	-- back shelving frames become wood
	{"S_Shelves", "S_Shelves__beam_metal", {Color = C(132, 92, 58), Material = Enum.Material.Wood, MaterialVariant = ""}},
	-- lamps: warm
	{"S_Lights", "S_Lights__neon_lamp",     {Color = WARM_NEON}},
	{"S_Displays", "S_Displays__neon_lamp", {Color = WARM_NEON}},
	{"S_Racks", "S_Racks__neon_lamp",       {Color = WARM_NEON}},
}
-- room lights (Rooms.Shop.L_*) and the counter truss spot: 3000K tint, slightly brighter
local WARM_LIGHT = C(255, 184, 120)
local LIGHTS = {
	{LM.Rooms.Shop:FindFirstChild("L_Counter"),   0.7},
	{LM.Rooms.Shop:FindFirstChild("L_Racks"),     0.55},
	{LM.Rooms.Shop:FindFirstChild("L_Pedestals"), 0.6},
	{LM.Rooms.Shop:FindFirstChild("L_Entry"),     0.45},
}
local spotHost = LM:FindFirstChild("Features") and LM.Features:FindFirstChild("Spotlights")
	and LM.Features.Spotlights:FindFirstChild("Spot_ShopCounter")

local function enc(t) return HttpService:JSONEncode(t) end
local function c3(t) return C(t[1], t[2], t[3]) end
local function rgb(c) return {math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)} end

local function restorePart(p)
	local s = p:GetAttribute(ATTR); if not s then return false end
	local o = HttpService:JSONDecode(s)
	p.Color = c3(o.Color); p.Material = Enum.Material[o.Material]; p.MaterialVariant = o.MaterialVariant
	p:SetAttribute(ATTR, nil); return true
end
local function restoreLight(l)
	local s = l:GetAttribute(ATTR); if not s then return false end
	local o = HttpService:JSONDecode(s)
	l.Color = c3(o.Color); l.Brightness = o.Brightness; l:SetAttribute(ATTR, nil); return true
end

local function eachLight(host, fn)
	if not host then return end
	for _, l in ipairs(host:GetDescendants()) do if l:IsA("Light") then fn(l) end end
end

---------------------------------------------------------------------------------------------------
-- UNDO
---------------------------------------------------------------------------------------------------
local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n = 0
	for _, r in ipairs(RECOLOUR) do
		local m = R2:FindFirstChild(r[1]); local p = m and m:FindFirstChild(r[2], true)
		if p and restorePart(p) then n += 1 end
	end
	for _, e in ipairs(LIGHTS) do eachLight(e[1], function(l) if restoreLight(l) then n += 1 end end) end
	eachLight(spotHost, function(l) if restoreLight(l) then n += 1 end end)
	if polish and polish:FindFirstChild("Shop") then polish.Shop:Destroy() end
	if polish and #polish:GetChildren() == 0 then polish:Destroy() end
	return "UNDO polish_shop: restored " .. n .. " originals, removed Polish.Shop"
end

---------------------------------------------------------------------------------------------------
-- APPLY recolours
---------------------------------------------------------------------------------------------------
local nRe = 0
for _, r in ipairs(RECOLOUR) do
	local m = R2:FindFirstChild(r[1]); local p = m and m:FindFirstChild(r[2], true)
	if not p then say("WARN missing " .. r[1] .. "." .. r[2]) else
		if not p:GetAttribute(ATTR) then
			p:SetAttribute(ATTR, enc({Color = rgb(p.Color), Material = p.Material.Name, MaterialVariant = p.MaterialVariant}))
		end
		for k, v in pairs(r[3]) do p[k] = v end
		nRe += 1
	end
end
local nL = 0
for _, e in ipairs(LIGHTS) do
	eachLight(e[1], function(l)
		if not l:GetAttribute(ATTR) then l:SetAttribute(ATTR, enc({Color = rgb(l.Color), Brightness = l.Brightness})) end
		l.Color = WARM_LIGHT; l.Brightness = e[2]; nL += 1
	end)
end
eachLight(spotHost, function(l)
	if not l:GetAttribute(ATTR) then l:SetAttribute(ATTR, enc({Color = rgb(l.Color), Brightness = l.Brightness})) end
	l.Color = C(255, 196, 140); nL += 1
end)
say(("recoloured %d meshes, retinted %d lights"):format(nRe, nL))

---------------------------------------------------------------------------------------------------
-- Measuring: rays against the room (merged kit meshes are CanQuery off: switch on, restore after)
---------------------------------------------------------------------------------------------------
local qOn = {}
for _, d in ipairs(R2:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Name:sub(1, 2) == "S_" then d.CanQuery = true; table.insert(qOn, d) end
end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {R2}
local function ray(o, d) return workspace:Raycast(o, d, rp) end
-- west/east wall face over a z span (the most proud surface between y 0.3 and 7)
local function wallFace(sign, z0, z1)
	local best = nil
	for z = z0, z1, 0.4 do for y = 0.3, 7, 0.6 do
		local h = ray(Vector3.new(sign * 20, y, z), Vector3.new(sign * 15, 0, 0))
		if h then local x = h.Position.X; if not best or (sign < 0 and x > best) or (sign > 0 and x < best) then best = x end end
	end end
	return best
end
local westFace = wallFace(-1, 99.6, 104.4)
local eastFace = wallFace(1, 99.6, 103.4)
-- back wall upper face (above the olive band) and the trim top under it
local backUpper = 999
for _, x in ipairs({-17.5, -15, -12, 12, 15, 17.5}) do for y = 10.6, 11.8, 0.3 do
	local h = ray(Vector3.new(x, y, 100), Vector3.new(0, 0, 15)); if h and h.Position.Z < backUpper and h.Position.Z > 110.2 then backUpper = h.Position.Z end
end end
local trimTop = 0
for _, x in ipairs({-19, -15, -11, 11, 15, 19}) do
	local h = ray(Vector3.new(x, 12.1, 109.95), Vector3.new(0, -3, 0)); if h and h.Position.Y > trimTop then trimTop = h.Position.Y end
end
local ceilY = {}
local function ceilingAt(x, z) local h = ray(Vector3.new(x, 8, z), Vector3.new(0, 8, 0)); return h and h.Position.Y or 13.3 end
local floorAt = function(x, z) local h = ray(Vector3.new(x, 2, z), Vector3.new(0, -4, 0)); return h and h.Position.Y or 0.02 end
say(("faces: west %.2f east %.2f backUpper %.2f trimTop %.2f"):format(westFace or -99, eastFace or 99, backUpper, trimTop))

---------------------------------------------------------------------------------------------------
-- Build helpers
---------------------------------------------------------------------------------------------------
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Shop") then polish.Shop:Destroy() end
local root = Instance.new("Folder"); root.Name = "Shop"
root:SetAttribute("PolishPass", "polish_shop.lua")

local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent or root; return m end
local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanTouch = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = o.collide == true; p.CanQuery = o.collide == true
	p.CastShadow = o.shadow == true
	if o.shape then p.Shape = o.shape end
	if not p.CanCollide then p:SetAttribute("NotCover", true) end
	p.Parent = parent
	return p
end
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_M = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local function label(p, face, lines, opts)
	opts = opts or {}
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.pps or 60; g.LightInfluence = opts.light or 1; g.Parent = p
	g:SetAttribute("PolishShop", true)
	local y = 0
	for _, ln in ipairs(lines) do
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(ln.w or 1, ln.h)
		t.Position = UDim2.fromScale(ln.x or 0, ln.y or y); t.Text = ln.text; t.TextScaled = true
		t.FontFace = ln.medium and FONT_M or FONT; t.TextColor3 = ln.color or C(10, 12, 10)
		t.TextXAlignment = ln.align or Enum.TextXAlignment.Center; t.Parent = g
		if ln.bg then t.BackgroundTransparency = 0; t.BackgroundColor3 = ln.bg; t.BorderSizePixel = 0 end
		y = (ln.y or y) + ln.h
	end
	return g
end
local function roomLight(host)
	CS:AddTag(host, "RoomLight"); host:SetAttribute("Room", "Shop")
end
local cardboard = Enum.Material.Cardboard

-- palette
local WOOD, WOOD_D, WOOD_L = C(132, 92, 58), C(84, 60, 40), C(150, 110, 72)
local CREAM, CREAM_D = C(236, 232, 218), C(214, 208, 190)
local OLIVE, OLIVE_D, SAGE = C(138, 156, 74), C(107, 122, 58), C(167, 173, 152)
local NEAR_BLACK, DARK = C(10, 12, 10), C(39, 40, 37)
local MIL = C(86, 98, 52)           -- military-green goods
local KRAFT = C(176, 146, 104)      -- ration cardboard
local WARM_BULB = C(240, 192, 128)

---------------------------------------------------------------------------------------------------
-- 2. Pendant lamps over the counter (the room's signature warm pools)
---------------------------------------------------------------------------------------------------
local pend = grp("CounterPendants")
for i, x in ipairs({-6.5, 0, 6.5, 14}) do
	local z = 102
	local top = ceilingAt(x, z)
	local m = grp("Pendant" .. i, pend)
	local shadeBot = 9.0   -- shade: olive drum 0.55 tall above a glowing diffuser disc (olive edge ring seen from below)
	local cordLen = top + 0.15 - (shadeBot + 1.35)
	local V = CFrame.Angles(0, 0, math.rad(90))
	part(m, "Cord", Vector3.new(cordLen, 0.1, 0.1), CFrame.new(x, shadeBot + 1.35 + cordLen / 2, z) * V, NEAR_BLACK, Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	part(m, "Cap", Vector3.new(0.45, 0.7, 0.7), CFrame.new(x, shadeBot + 1.13, z) * V, OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	part(m, "ShadeTop", Vector3.new(0.3, 1.25, 1.25), CFrame.new(x, shadeBot + 0.8, z) * V, OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	part(m, "Shade", Vector3.new(0.55, 1.9, 1.9), CFrame.new(x, shadeBot + 0.375, z) * V, OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	part(m, "Diffuser", Vector3.new(0.06, 1.55, 1.55), CFrame.new(x, shadeBot + 0.07, z) * V, WARM_BULB, Enum.Material.Neon, {shape = Enum.PartType.Cylinder})
	if i == 4 then continue end   -- the east pendant glows only (budget); the three over the service run cast the pools
	local host = part(m, "LightHost", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, shadeBot - 0.05, z), WARM_BULB, Enum.Material.SmoothPlastic)
	host.Transparency = 1
	local s = Instance.new("SpotLight"); s.Face = Enum.NormalId.Bottom; s.Angle = 82; s.Range = 13
	s.Brightness = 1.6; s.Color = WARM_LIGHT; s.Shadows = (i == 2); s.Parent = host
	roomLight(host)
end

---------------------------------------------------------------------------------------------------
-- 3. Wood countertop on the cream counter
---------------------------------------------------------------------------------------------------
local ctr = grp("Counter")
-- four runs: the KitEmitter_ShopCounter hook (x 2..4) and the two terminals (x -3.5..-1.5, 11.5..14.5, measured
-- by rays) keep their metal top plates, so nothing is buried in the wood
for i, r in ipairs({{-10.25, -3.65}, {-1.35, 1.85}, {4.15, 11.35}, {14.65, 16.25}}) do
	local w, cx = r[2] - r[1], (r[1] + r[2]) / 2
	part(ctr, "WoodTop" .. i, Vector3.new(w, 0.2, 3.25), CFrame.new(cx, 3.90, 101.78), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(ctr, "TopEdge" .. i, Vector3.new(w + 0.04, 0.08, 0.1), CFrame.new(cx, 3.86, 100.155 - 0.07), OLIVE_D, Enum.Material.Metal)
end
-- goods on the counter (front zone, clear of the three terminals and the screen strip)
local tY = 4.0
-- folded uniforms stack (sage / olive / sage)
for k, col in ipairs({SAGE, OLIVE_D, SAGE}) do
	part(ctr, "Uniform" .. k, Vector3.new(1.3, 0.22, 0.95), CFrame.new(-8.3 + (k % 2) * 0.05, tY + 0.11 + (k - 1) * 0.22, 101.6) * CFrame.Angles(0, math.rad(k * 3), 0), col, Enum.Material.Fabric)
end
-- ammo can with lid handle
part(ctr, "AmmoCan", Vector3.new(1.1, 0.7, 0.55), CFrame.new(-5.6, tY + 0.35, 101.5) * CFrame.Angles(0, math.rad(-8), 0), MIL, Enum.Material.Metal, {shadow = true})
part(ctr, "AmmoCanLid", Vector3.new(1.14, 0.08, 0.59), CFrame.new(-5.6, tY + 0.74, 101.5) * CFrame.Angles(0, math.rad(-8), 0), OLIVE_D, Enum.Material.Metal)
part(ctr, "AmmoCanHandle", Vector3.new(0.5, 0.06, 0.12), CFrame.new(-5.6, tY + 0.81, 101.5) * CFrame.Angles(0, math.rad(-8), 0), NEAR_BLACK, Enum.Material.Metal)
-- requisition ledger (open book) + pencil
part(ctr, "Ledger", Vector3.new(1.6, 0.08, 1.1), CFrame.new(7.6, tY + 0.04, 100.85) * CFrame.Angles(0, math.rad(6), 0), DARK, Enum.Material.Fabric)
local pg = part(ctr, "LedgerPages", Vector3.new(1.48, 0.05, 0.98), CFrame.new(7.6, tY + 0.105, 100.85) * CFrame.Angles(0, math.rad(6), 0), CREAM, Enum.Material.SmoothPlastic)
part(ctr, "Pencil", Vector3.new(0.9, 0.06, 0.06), CFrame.new(8.7, tY + 0.03, 100.7) * CFrame.Angles(0, math.rad(30), 0), OLIVE, Enum.Material.SmoothPlastic)
-- small stencilled supply box at the east end
local bx = part(ctr, "SupplyBox", Vector3.new(1.2, 0.85, 0.9), CFrame.new(15.55, tY + 0.425, 101.7) * CFrame.Angles(0, math.rad(-3), 0), KRAFT, cardboard, {shadow = true})
label(bx, Enum.NormalId.Front, {{text = "RATIONS", h = 0.4, y = 0.3, color = C(60, 52, 38)}}, {pps = 80})

---------------------------------------------------------------------------------------------------
-- 4. Wood wall shelving units (west + east, by the counter) stocked with supply goods
---------------------------------------------------------------------------------------------------
local function shelfUnit(name, baseCF, width, depth, height, seed)
	-- local frame: origin at floor, centre of the unit; front faces local -Z; back at +depth/2
	local m = grp(name)
	local function L(x, y, z) return baseCF * CFrame.new(x, y, z) end
	local t = 0.14
	part(m, "SideL", Vector3.new(t, height, depth), L(-width / 2 + t / 2, height / 2, 0), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "SideR", Vector3.new(t, height, depth), L(width / 2 - t / 2, height / 2, 0), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "Back", Vector3.new(width - 2 * t, height - 0.1, 0.08), L(0, height / 2, depth / 2 - 0.04), WOOD_D, Enum.Material.Wood, {collide = true})
	part(m, "Top", Vector3.new(width, 0.14, depth + 0.06), L(0, height + 0.07, -0.03), WOOD_L, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "Kick", Vector3.new(width - 2 * t, 0.42, 0.1), L(0, 0.21 + 0.03, -depth / 2 + 0.12), NEAR_BLACK, Enum.Material.SmoothPlastic, {collide = true})
	local levels = {0.5, 2.15, 3.8, 5.45}
	local rnd = Random.new(seed)
	for li, y in ipairs(levels) do
		part(m, "Shelf" .. li, Vector3.new(width - 2 * t, 0.12, depth - 0.1), L(0, y, -0.03), WOOD_L, Enum.Material.Wood, {collide = true})
		-- olive front lip with cream price tags
		part(m, "Lip" .. li, Vector3.new(width - 2 * t, 0.16, 0.05), L(0, y - 0.01, -depth / 2 + 0.005), OLIVE_D, Enum.Material.Metal)
		for k = 1, 3 do
			local tx = -width / 2 + width * (k / 4)
			local tag = part(m, "Tag" .. li .. k, Vector3.new(0.42, 0.13, 0.05), L(tx, y - 0.01, -depth / 2 - 0.07), CREAM, Enum.Material.SmoothPlastic)
		end
		-- goods: fill along the shelf with a deterministic mix
		local x = -width / 2 + t + 0.12
		local yb = y + 0.06
		local d = depth - 0.3
		while x < width / 2 - t - 0.5 do
			local kind = rnd:NextInteger(1, 5)
			if li == 4 and kind == 3 then kind = 4 end
			if kind == 1 then -- ammo cans x2 stacked
				local w = 0.95
				if x + w > width / 2 - t - 0.1 then break end
				part(m, "Ammo", Vector3.new(w, 0.62, 0.5), L(x + w / 2, yb + 0.31, 0), MIL, Enum.Material.Metal)
				part(m, "AmmoLid", Vector3.new(w + 0.03, 0.06, 0.53), L(x + w / 2, yb + 0.65, 0), OLIVE_D, Enum.Material.Metal)
				x += w + 0.12
			elseif kind == 2 then -- ration boxes
				local w = 0.8
				if x + w > width / 2 - t - 0.1 then break end
				local n = (li == 4) and 2 or rnd:NextInteger(2, 3)
				for s = 1, n do
					part(m, "Ration", Vector3.new(w, 0.42, d * 0.8), L(x + w / 2, yb + 0.21 + (s - 1) * 0.43, -0.05) * CFrame.Angles(0, math.rad(rnd:NextNumber(-4, 4)), 0), KRAFT, cardboard)
				end
				x += w + 0.1
			elseif kind == 3 then -- canteens (row of 3)
				local w = 1.25
				if x + w > width / 2 - t - 0.1 then break end
				for s = 0, 2 do
					part(m, "Canteen", Vector3.new(0.75, 0.36, 0.36), L(x + 0.2 + s * 0.42, yb + 0.375, -0.1) * CFrame.Angles(0, 0, math.rad(90)), OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
					part(m, "CanteenCap", Vector3.new(0.1, 0.16, 0.16), L(x + 0.2 + s * 0.42, yb + 0.8, -0.1) * CFrame.Angles(0, 0, math.rad(90)), NEAR_BLACK, Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder})
				end
				x += w + 0.1
			elseif kind == 4 then -- folded uniforms
				local w = 0.95
				if x + w > width / 2 - t - 0.1 then break end
				for s = 1, rnd:NextInteger(3, 5) do
					part(m, "Uniform", Vector3.new(w, 0.19, d * 0.75), L(x + w / 2 + rnd:NextNumber(-0.03, 0.03), yb + 0.095 + (s - 1) * 0.19, -0.05), (s % 2 == 0) and SAGE or C(120, 128, 92), Enum.Material.Fabric)
				end
				x += w + 0.1
			else -- med kit: cream case with olive band
				local w = 0.9
				if x + w > width / 2 - t - 0.1 then break end
				part(m, "MedKit", Vector3.new(w, 0.55, 0.55), L(x + w / 2, yb + 0.275, 0), CREAM_D, Enum.Material.SmoothPlastic)
				part(m, "MedBand", Vector3.new(w + 0.02, 0.14, 0.57), L(x + w / 2, yb + 0.3, 0), OLIVE, Enum.Material.SmoothPlastic)
				x += w + 0.12
			end
		end
	end
	-- warm strip light under the top (lights the goods), recessed 0.12 below the top board
	local bar = part(m, "LampBar", Vector3.new(width - 0.5, 0.12, 0.22), L(0, height - 0.06, -depth / 2 + 0.22), NEAR_BLACK, Enum.Material.Metal)
	part(m, "LampStrip", Vector3.new(width - 0.7, 0.04, 0.12), L(0, height - 0.14, -depth / 2 + 0.22), WARM_BULB, Enum.Material.Neon)
	-- header plate above the unit
	return m
end
local unitW, unitD, unitH = 4.8, 1.3, 6.9
-- west: front faces +X (yaw -90), back against the west wall face
local wBackX = (westFace or -28.8) + 0.06
local wUnit = shelfUnit("WallShelfW", CFrame.new(wBackX + unitD / 2, floorAt(-26, 102) + 0.01, 102) * CFrame.Angles(0, math.rad(-90), 0), unitW, unitD, unitH, 7)
local eBackX = (eastFace or 28.8) - 0.06
local eUnit = shelfUnit("WallShelfE", CFrame.new(eBackX - unitD / 2, floorAt(26, 101.5) + 0.01, 101.5) * CFrame.Angles(0, math.rad(90), 0), 3.6, unitD, unitH, 11)
-- no real light on the wall units: their Neon strip plus the pendants and display lamps carry them (light budget:
-- 66 lights were already enabled in Play near the Shop, against the ~45 comment in RoomFX)

---------------------------------------------------------------------------------------------------
-- 5. Back-shelf wash lights (wall brackets over both shelf banks behind the counter)
---------------------------------------------------------------------------------------------------
local wash = grp("ShelfWash")
for i, x in ipairs({-15, 15}) do
	local zWall = 109.88   -- band trim face; brackets start just in front of it
	local y = 9.85
	local m = grp("Wash" .. i, wash)
	for _, dx in ipairs({-3.2, 3.2}) do
		part(m, "Bracket", Vector3.new(0.12, 0.12, 1.25), CFrame.new(x + dx, y + 0.06, zWall - 0.66), NEAR_BLACK, Enum.Material.Metal)
	end
	local bar = part(m, "Housing", Vector3.new(7.2, 0.3, 0.42), CFrame.new(x, y, zWall - 1.3), NEAR_BLACK, Enum.Material.Metal)
	part(m, "Strip", Vector3.new(7.0, 0.04, 0.22), CFrame.new(x, y - 0.13, zWall - 1.3), WARM_BULB, Enum.Material.Neon)
	local s = Instance.new("SurfaceLight"); s.Face = Enum.NormalId.Bottom; s.Angle = 75; s.Range = 10; s.Brightness = 1.3
	s.Color = WARM_LIGHT; s.Shadows = false; s.Parent = bar
	roomLight(bar)
end

---------------------------------------------------------------------------------------------------
-- 6. Price / stock boards on the back wall (cream boards, olive header tab), flanking SUPPLY
---------------------------------------------------------------------------------------------------
local boards = grp("Boards")
local bBot = math.max(trimTop + 0.08, 10.45)
local bTop = 11.9   -- free wall between the pier (x 11.25) and the capsule light (x 18.75); ceiling strips hang in front above 11.65
local bH = bTop - bBot
local bZ = backUpper - 0.08 - 0.06   -- back face 0.08 in front of the wall face
local BOARDS = {
	{-14.6, "01", "FIELD STOCK", "RATIONS  ·  WATER  ·  MED KITS"},
	{14.6, "02", "REQUISITION", "SELECT AT COUNTER  ·  ISSUE BAY 2"},
}
for i, b in ipairs(BOARDS) do
	local frame = part(boards, "Frame" .. i, Vector3.new(6.0, bH, 0.12), CFrame.new(b[1], bBot + bH / 2, bZ), WOOD_D, Enum.Material.Wood)
	local face = part(boards, "Board" .. i, Vector3.new(5.7, bH - 0.24, 0.1), CFrame.new(b[1], bBot + bH / 2, bZ - 0.1), CREAM, Enum.Material.SmoothPlastic)
	label(face, Enum.NormalId.Front, {
		{text = b[2], x = 0, y = 0, w = 0.13, h = 1, color = CREAM, bg = OLIVE_D},
		{text = b[3], x = 0.16, y = 0.06, w = 0.82, h = 0.52, align = Enum.TextXAlignment.Left},
		{text = b[4], x = 0.16, y = 0.6, w = 0.82, h = 0.32, align = Enum.TextXAlignment.Left, medium = true, color = C(70, 76, 44)},
	}, {pps = 50})
end

---------------------------------------------------------------------------------------------------
-- 7. Stock waiting to be shelved: pallets + kit crates (Prop/Features kits from ServerStorage)
---------------------------------------------------------------------------------------------------
local stock = grp("StockClusters")
local function kit(name, folder, pos, yaw, parent)
	local src = SS:FindFirstChild(folder) and SS[folder]:FindFirstChild(name)
	if not src then say("WARN no kit " .. folder .. "." .. name); return nil end
	local m = src:Clone()
	local cf, sz = m:GetBoundingBox()
	local rel = cf:ToObjectSpace(m:GetPivot())
	local target = CFrame.new(pos.X, pos.Y + sz.Y / 2, pos.Z) * CFrame.Angles(0, math.rad(yaw), 0)
	m:PivotTo(target * rel)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanTouch = false; if d.Name ~= "Collider" then d.CastShadow = true end end
	end
	m.Parent = parent
	return m, sz
end
-- cluster W (x -16.5, z 102.5): pallet, two small crates, one on top, a barrel and an ammo case on the floor
do
	local m = grp("ClusterW", stock)
	local fy = floorAt(-16.5, 102.5) + 0.01
	local _, ps = kit("Prop_Pallet", "PropKit", Vector3.new(-16.5, fy, 102.6), 90, m)
	local py = fy + (ps and ps.Y or 0.55)
	kit("Prop_CrateS", "PropKit", Vector3.new(-17.65, py, 102.6), 90, m)
	kit("Prop_CrateS", "PropKit", Vector3.new(-15.25, py, 102.65), 90, m)
	kit("Prop_CrateS", "PropKit", Vector3.new(-16.4, py + 2.41, 102.6), 84, m)
	kit("Prop_AmmoCase", "PropKit", Vector3.new(-19.65, fy, 100.6), 75, m)
end
-- cluster E (x 22, z 101.5): big crate + small crate on it, cable spool beside
do
	local m = grp("ClusterE", stock)
	local fy = floorAt(22, 101.5) + 0.01
	kit("F_Crate4B", "FeaturesKit", Vector3.new(22.1, fy, 101.6), 4, m)
	kit("Prop_CrateS", "PropKit", Vector3.new(22.0, fy + 4.11, 101.5), -6, m)
	kit("Prop_AmmoCase", "PropKit", Vector3.new(25.5, fy, 100.2), 90, m)
end

---------------------------------------------------------------------------------------------------
-- 8. Entrance merchandise bins (open wood crates of goods on a low stand) + placards
---------------------------------------------------------------------------------------------------
local bins = grp("EntryBins")
local function bin(name, x, z, goods, title)
	local m = grp(name, bins)
	local fy = floorAt(x, z) + 0.01
	local W, D, H = 3.2, 2.3, 1.3
	local standH = 0.9
	-- stand legs + rails (dark metal), bin box of wood boards
	for _, sx in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
		part(m, "Leg", Vector3.new(0.16, standH, 0.16), CFrame.new(x + sx * (W / 2 - 0.15), fy + standH / 2, z + sz * (D / 2 - 0.15)), NEAR_BLACK, Enum.Material.Metal, {collide = true})
	end end
	part(m, "Base", Vector3.new(W, 0.12, D), CFrame.new(x, fy + standH + 0.06, z), WOOD_D, Enum.Material.Wood, {collide = true, shadow = true})
	local by = fy + standH + 0.12
	part(m, "WallF", Vector3.new(W, H, 0.12), CFrame.new(x, by + H / 2, z - D / 2 + 0.06), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "WallB", Vector3.new(W, H, 0.12), CFrame.new(x, by + H / 2, z + D / 2 - 0.06), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "WallL", Vector3.new(0.12, H, D - 0.24), CFrame.new(x - W / 2 + 0.06, by + H / 2, z), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "WallR", Vector3.new(0.12, H, D - 0.24), CFrame.new(x + W / 2 - 0.06, by + H / 2, z), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	-- slat grooves on the front (dark strips proud 0.12 of the front wall)
	for k = 1, 2 do
		part(m, "Slat", Vector3.new(W - 0.1, 0.06, 0.04), CFrame.new(x, by + k * H / 3, z - D / 2 - 0.02 - 0.08), WOOD_D, Enum.Material.Wood)
	end
	-- olive corner straps
	for _, sx in ipairs({-1, 1}) do
		part(m, "Strap", Vector3.new(0.18, H + 0.02, 0.18), CFrame.new(x + sx * (W / 2 - 0.02), by + H / 2, z - D / 2 + 0.02), OLIVE_D, Enum.Material.Metal)
	end
	-- goods heap: rows just below the rim
	local rnd = Random.new(#name * 13)
	local fill = by + H - 0.55
	part(m, "Fill", Vector3.new(W - 0.26, 0.1, D - 0.26), CFrame.new(x, fill, z), C(70, 56, 40), Enum.Material.Fabric)
	if goods == "canteen" then
		for ix = 0, 5 do for iz = 0, 3 do
			local px = x - W / 2 + 0.42 + ix * 0.47; local pz = z - D / 2 + 0.42 + iz * 0.47
			part(m, "Canteen", Vector3.new(0.7, 0.4, 0.4), CFrame.new(px, fill + 0.1 + 0.32, pz) * CFrame.Angles(math.rad(rnd:NextNumber(-12, 12)), 0, math.rad(90 + rnd:NextNumber(-12, 12))), (ix + iz) % 3 == 0 and MIL or OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
		end end
	else
		for ix = 0, 3 do for iz = 0, 2 do
			local px = x - W / 2 + 0.5 + ix * 0.72; local pz = z - D / 2 + 0.5 + iz * 0.65
			part(m, "Ration", Vector3.new(0.62, 0.36, 0.52), CFrame.new(px, fill + 0.05 + 0.18 + ((ix + iz) % 2) * 0.12, pz) * CFrame.Angles(math.rad(rnd:NextNumber(-8, 8)), math.rad(rnd:NextNumber(-20, 20)), math.rad(rnd:NextNumber(-8, 8))), (ix * iz) % 3 == 1 and CREAM_D or KRAFT, cardboard)
		end end
	end
	-- placard on a post at the back edge, facing the entrance (-Z)
	local postX = x
	part(m, "Post", Vector3.new(0.12, 1.5, 0.12), CFrame.new(postX, by + H + 0.65, z + D / 2 - 0.25), NEAR_BLACK, Enum.Material.Metal)
	local card = part(m, "Placard", Vector3.new(1.9, 0.85, 0.08), CFrame.new(postX, by + H + 1.35, z + D / 2 - 0.36), CREAM, Enum.Material.SmoothPlastic)
	label(card, Enum.NormalId.Front, {
		{text = title, y = 0.08, h = 0.5},
		{text = "ISSUE AT COUNTER", y = 0.62, h = 0.28, medium = true, color = C(70, 76, 44)},
	}, {pps = 90})
	return m
end
bin("BinW", -11.8, 76, "ration", "FIELD RATIONS")
bin("BinE", 11.8, 76, "canteen", "CANTEENS")

---------------------------------------------------------------------------------------------------
-- 9. A-frame "OPEN" board by the doorway (faces players coming in)
---------------------------------------------------------------------------------------------------
do
	local m = grp("AFrame")
	local x, z0 = 8.4, 71.2
	local fy = floorAt(x, z0) + 0.01
	local h, a = 2.9, math.rad(13)
	local yawCF = CFrame.Angles(0, math.rad(-18), 0)
	local base = CFrame.new(x, fy, z0) * yawCF
	local frontCF = base * CFrame.Angles(a, 0, 0) * CFrame.new(0, h / 2, 0)
	local backCF = base * CFrame.new(0, 0, 2 * h * math.sin(a)) * CFrame.Angles(-a, 0, 0) * CFrame.new(0, h / 2, 0)
	part(m, "FrontFrame", Vector3.new(1.9, h, 0.12), frontCF, WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "BackFrame", Vector3.new(1.9, h, 0.12), backCF, WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	local face = part(m, "Slate", Vector3.new(1.6, h - 0.5, 0.06), frontCF * CFrame.new(0, 0.05, -0.09), DARK, Enum.Material.SmoothPlastic)
	label(face, Enum.NormalId.Front, {
		{text = "QUARTERMASTER", y = 0.06, h = 0.13, color = CREAM},
		{text = "OPEN", y = 0.24, h = 0.24, color = C(176, 192, 108)},
		{text = "DAILY ISSUE", y = 0.56, h = 0.1, medium = true, color = CREAM},
		{text = "RATIONS · AMMO", y = 0.69, h = 0.09, medium = true, color = SAGE},
		{text = "MED · KIT", y = 0.8, h = 0.09, medium = true, color = SAGE},
	}, {pps = 90})
end

---------------------------------------------------------------------------------------------------
-- 10. Customer mat in front of the counter (olive field, warm-grey border, 0.04 step between them)
---------------------------------------------------------------------------------------------------
do
	local m = grp("CounterMat")
	local fy = floorAt(3, 98) + 0.01
	-- ends at z 99.35: the hazard strip at the counter foot (z 99.5..100.1) stays visible
	part(m, "Border", Vector3.new(24.0, 0.1, 3.35), CFrame.new(3, fy + 0.05, 97.675), C(118, 108, 90), Enum.Material.Fabric, {collide = true})
	part(m, "Field", Vector3.new(23.2, 0.14, 2.55), CFrame.new(3, fy + 0.07, 97.675), C(66, 72, 42), Enum.Material.Fabric, {collide = true})
end

---------------------------------------------------------------------------------------------------
root.Parent = polish
for _, d in ipairs(qOn) do d.CanQuery = false end
local n = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
say(("Polish.Shop: %d parts, %d new lights (RoomLight Room=Shop)"):format(n, nl))
return table.concat(log, "\n")
