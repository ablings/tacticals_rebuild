-- backdrop_sky.lua : replace the TimesSquare backdrop east of the Exfil pad with a FLOATING SKY MILITARY BASE backdrop.
-- Tacticals_rebuild.rbxl ONLY. Edward 2026-10-16: the TimesSquare towers "just don't fit the theme or look of the game".
-- 1. Hide LobbyMap.TimesSquare (kept in place, never deleted): parts Transparency 1 / CanQuery false / CastShadow false,
--    its SurfaceGuis disabled, and the CityBillboard tag taken off its 9 billboard parts (tags kept in attribute
--    Backdrop_Tags) so Client.Controllers.BillboardController never builds its runtime BillboardGui_Live on hidden parts.
--    Nothing else references TimesSquare (script grep: only BillboardController by tag; polish_exfil / polish_final use
--    FindFirstChild). The TimesSquare SurfaceLights stay as polish_final left them (off).
-- 2. Build the replacement as a Parts blockout under Workspace.LobbyMap.Polish.Backdrop, in the RIVALS craft (chamfered
--    slabs, neutral greys, thin olive / cream accent lines, readable silhouettes) and the Tacticals palette:
--    HangarDeck (SE, mid distance), CommsIsland (E, far and high: radome, lattice mast, dishes), LandingPad (NE, low:
--    the cutscene's background), FuelDepot (far SE, low: tanks), cables on pylons between them, sage / cream Neon
--    anti-grav rings under every hull, cloud banks below (y -50..-20) that also veil the City backdrop's tower tops.
--    The Blender kit of the same platforms is kit/backdrop.blend / .fbx (queued for import, see notes/backdrop_sky.md).
-- Backdrop only: every part Anchored, CanCollide / CanQuery / CanTouch false, CastShadow false, NotCover. No Light
-- objects (Neon only), no particles. Idempotent; UNDO restores TimesSquare and removes Polish.Backdrop.
-- UNDO: python tools/run_luau.py fix/backdrop_sky.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap
local ATTR = "Backdrop_Orig"
local TAGATTR = "Backdrop_Tags"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(...) local t = {} for _, v in ipairs({...}) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	else return o.v end
end
local function setP(inst, props)
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
end

local TS = LM:FindFirstChild("TimesSquare")
local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n, nt = 0, 0
	if TS then
		for _, d in ipairs(TS:GetDescendants()) do
			local s = d:GetAttribute(ATTR)
			if s then
				for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
				d:SetAttribute(ATTR, nil); n += 1
			end
			local tg = d:GetAttribute(TAGATTR)
			if tg then
				for _, t in ipairs(string.split(tg, ",")) do CS:AddTag(d, t) end
				d:SetAttribute(TAGATTR, nil); nt += 1
			end
		end
	end
	if polish and polish:FindFirstChild("Backdrop") then polish.Backdrop:Destroy() end
	return ("UNDO backdrop_sky: TimesSquare restored (%d instances, %d re-tagged), Polish.Backdrop removed"):format(n, nt)
end

---------------------------------------------------------------------------------------------------
-- 1. hide TimesSquare
---------------------------------------------------------------------------------------------------
if TS then
	local np, ng, nt = 0, 0, 0
	for _, d in ipairs(TS:GetDescendants()) do
		if d:IsA("BasePart") then
			setP(d, {Transparency = 1, CanQuery = false, CastShadow = false}); np += 1
			if CS:HasTag(d, "CityBillboard") then
				d:SetAttribute(TAGATTR, "CityBillboard"); CS:RemoveTag(d, "CityBillboard"); nt += 1
			end
		elseif d:IsA("SurfaceGui") then setP(d, {Enabled = false}); ng += 1 end
	end
	say(("1. TimesSquare hidden: %d parts, %d SurfaceGuis off, %d CityBillboard tags parked (Backdrop_Tags)"):format(np, ng, nt))
else say("WARN no LobbyMap.TimesSquare") end

---------------------------------------------------------------------------------------------------
-- 2. build
---------------------------------------------------------------------------------------------------
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Backdrop") then polish.Backdrop:Destroy() end
local root = Instance.new("Folder"); root.Name = "Backdrop"
root:SetAttribute("PolishPass", "backdrop_sky.lua")

-- palette (Tacticals loading screen + RIVALS neutral greys)
local DECK = C(163, 162, 165)
local SIDE = C(124, 123, 126)
local HULL = C(84, 84, 88)
local HULL_D = C(58, 58, 62)
local NEAR_BLACK = C(10, 12, 10)
local CREAM = C(236, 232, 218)
-- painted olive: the lobby band value (polish_olive: 138,156,74 renders lime in daylight, 138,130,60 renders olive)
local OLIVE = C(138, 130, 60)
local OLIVE_D = C(107, 122, 58)
local WARM = C(200, 196, 186)
local SAGE = C(167, 173, 152)
local NEON_SAGE = C(150, 166, 120)
local NEON_CREAM = C(226, 220, 196)
local CLOUD = C(236, 239, 242)
local CLOUD_B = C(208, 215, 224)

local count = 0
local function part(parent, name, size, cf, color, mat, shape, class)
	local p = Instance.new(class or "Part")
	if shape then p.Shape = shape end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	count += 1
	return p
end
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local V = Vector3.new
local CF = CFrame.new
local UP = CFrame.Angles(0, 0, math.pi / 2)
-- chamfered slab: a box with its four vertical edges cut at 45 degrees (2 boxes + 4 rotated corner squares)
local function cslab(parent, name, cx, cy, cz, sx, sy, sz, c, color, mat)
	part(parent, name, V(sx, sy, sz - 2 * c), CF(cx, cy, cz), color, mat)
	part(parent, name, V(sx - 2 * c, sy, sz), CF(cx, cy, cz), color, mat)
	local s = c * math.sqrt(2)
	for _, sg in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
		part(parent, name, V(s, sy, s), CF(cx + sg[1] * (sx / 2 - c), cy, cz + sg[2] * (sz / 2 - c)) * CFrame.Angles(0, math.pi / 4, 0), color, mat)
	end
end
local function disc(parent, name, cx, cy, cz, d, h, color, mat)
	return part(parent, name, V(h, d, d), CF(cx, cy, cz) * UP, color, mat, Enum.PartType.Cylinder)
end
-- hull under a deck: stepped chamfered tiers, a Neon anti-grav ring and a thruster pod
local function hull(parent, cx, top, cz, sx, sz, c, ringD, neon)
	cslab(parent, "Hull1", cx, top - 3, cz, sx * 0.78, 6, sz * 0.78, c * 0.78, HULL)
	cslab(parent, "Hull2", cx, top - 8, cz, sx * 0.52, 4, sz * 0.52, c * 0.52, HULL_D)
	disc(parent, "AntiGravRing", cx, top - 10.6, cz, ringD, 1.2, neon or NEON_SAGE, M.Neon)
	disc(parent, "Thruster", cx, top - 12.6, cz, ringD - 4, 3, HULL_D)
	disc(parent, "ThrusterCore", cx, top - 14.3, cz, ringD * 0.4, 0.6, NEON_CREAM, M.Neon)
end
local function mast(parent, x, y0, z, h, lamp)
	part(parent, "Mast", V(1.2, h, 1.2), CF(x, y0 + h / 2, z), SIDE, M.Metal)
	part(parent, "MastBand", V(1.4, 1.4, 1.4), CF(x, y0 + h * 0.6, z), OLIVE)
	part(parent, "MastLamp", V(1.8, 1.8, 1.8), CF(x, y0 + h + 0.9, z), lamp or NEON_CREAM, M.Neon)
	return V(x, y0 + h - 1.5, z)
end
local cables = grp("Cables", root)
local function cable(a, b, sag, segs)
	local prev = a
	for i = 1, segs do
		local t = i / segs
		local p = a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0)
		local len = (p - prev).Magnitude
		part(cables, "Cable", V(1.3, 1.3, len + 0.4), CFrame.lookAt((p + prev) / 2, p), HULL_D, M.Metal)
		prev = p
	end
end
local function stencil(p, face, text, color)
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 8; g.LightInfluence = 1; g.Parent = p
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Text = text
	t.TextScaled = true; t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	t.TextColor3 = color; t.Parent = g
end

-- A. HangarDeck: the big one, south-east, mid distance; hangar door faces the pad (west)
do
	local g = grp("HangarDeck", root)
	local x, top, z = 300, 12, -120
	cslab(g, "Deck", x, top - 4, z, 130, 8, 80, 14, SIDE)
	cslab(g, "DeckTop", x, top - 0.2, z, 130.2, 0.4, 80.2, 14.05, DECK)
	cslab(g, "EdgeBand", x, top - 2.2, z, 130.3, 1.0, 80.3, 14.1, OLIVE)
	hull(g, x - 25, top - 8, z, 80, 70, 12, 30)
	hull(g, x + 32, top - 8, z, 60, 60, 10, 24)
	-- hangar shed: body, chamfered roof, dark door with a cream frame, olive band, number
	local bx, bz = x + 18, z - 6
	part(g, "Shed", V(66, 22, 48), CF(bx, top + 11, bz), WARM, M.Concrete)
	part(g, "ShedRoof", V(66.4, 6, 32), CF(bx, top + 25, bz), SIDE, M.Metal)
	part(g, "ShedRoofEdge", V(66.4, 6, 8), CF(bx, top + 25, bz - 20), SIDE, M.Metal, nil, "WedgePart")
	part(g, "ShedRoofEdge", V(66.4, 6, 8), CF(bx, top + 25, bz + 20) * CFrame.Angles(0, math.pi, 0), SIDE, M.Metal, nil, "WedgePart")
	part(g, "ShedBand", V(66.6, 1.2, 48.6), CF(bx, top + 19.5, bz), OLIVE)
	part(g, "ShedDoor", V(0.6, 13, 34), CF(bx - 33.1, top + 6.5, bz), C(34, 35, 36), M.Concrete)
	part(g, "DoorFrame", V(0.8, 1, 36), CF(bx - 33.3, top + 13.5, bz), CREAM)
	part(g, "DoorFrame", V(0.8, 13, 1), CF(bx - 33.3, top + 6.5, bz - 17.5), CREAM)
	part(g, "DoorFrame", V(0.8, 13, 1), CF(bx - 33.3, top + 6.5, bz + 17.5), CREAM)
	local plate = part(g, "SignPlate", V(0.5, 4, 14), CF(bx - 33.2, top + 16.6, bz), NEAR_BLACK)
	stencil(plate, Enum.NormalId.Left, "H-07", CREAM)
	-- apron: cream lead-in lines + a parked cargo stack for scale
	part(g, "ApronLine", V(40, 0.2, 1.2), CF(x - 40, top + 0.1, bz - 6), CREAM)
	part(g, "ApronLine", V(40, 0.2, 1.2), CF(x - 40, top + 0.1, bz + 6), CREAM)
	part(g, "ApronLine", V(1.2, 0.2, 30), CF(x - 58, top + 0.1, bz), CREAM)
	part(g, "Cargo", V(8, 5, 6), CF(x - 50, top + 2.5, z + 28), OLIVE_D)
	part(g, "Cargo", V(8, 5, 6), CF(x - 41, top + 2.5, z + 28), OLIVE_D)
	part(g, "Cargo", V(8, 5, 6), CF(x - 45.5, top + 7.5, z + 28), SAGE)
	-- pylons at the deck corners (cable anchors)
	local pNW = mast(g, x - 58, top, z + 33, 22)
	local pNE = mast(g, x + 58, top, z + 33, 22)
	local pSW = mast(g, x - 58, top, z - 33, 18)
	root:SetAttribute("_pNW", pNW); root:SetAttribute("_pNE", pNE); root:SetAttribute("_pSW", pSW)
end

-- B. CommsIsland: far east and high: radome, lattice mast with dishes, a hut
do
	local g = grp("CommsIsland", root)
	local x, top, z = 470, 50, 55
	cslab(g, "Deck", x, top - 2.5, z, 52, 5, 52, 13, SIDE)
	cslab(g, "DeckTop", x, top - 0.2, z, 52.2, 0.4, 52.2, 13.05, DECK)
	cslab(g, "EdgeBand", x, top - 1.6, z, 52.3, 0.8, 52.3, 13.1, CREAM)
	hull(g, x, top - 5, z, 40, 40, 10, 24, NEON_CREAM)
	part(g, "RadomeBase", V(5, 14, 14), CF(x + 10, top + 2.5, z + 10) * UP, SIDE, M.Concrete, Enum.PartType.Cylinder)
	part(g, "Radome", V(18, 18, 18), CF(x + 10, top + 12, z + 10), CREAM, M.SmoothPlastic, Enum.PartType.Ball)
	-- lattice mast: 4 legs + cross bars + top beacon
	local mx, mz, mh = x - 8, z - 8, 64
	for _, s in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
		part(g, "MastLeg", V(1, mh, 1), CF(mx + s[1] * 2.2, top + mh / 2, mz + s[2] * 2.2), SIDE, M.Metal)
	end
	for i = 1, 4 do
		local y = top + i * mh / 5
		part(g, "MastBar", V(5.4, 0.8, 5.4), CF(mx, y, mz), i % 2 == 0 and OLIVE or CREAM)
	end
	part(g, "MastBar", V(5.4, 0.8, 5.4), CF(mx, top + mh, mz), CREAM)
	part(g, "MastTip", V(0.8, 14, 0.8), CF(mx, top + mh + 7, mz), SIDE, M.Metal)
	part(g, "MastBeacon", V(2.2, 2.2, 2.2), CF(mx, top + mh + 14.6, mz), NEON_CREAM, M.Neon)
	-- dishes on the mast, aimed west / south-west at the base
	for _, d in ipairs({{top + 38, -0.5, 12}, {top + 24, 0.6, 9}}) do
		local cf = CF(mx - 5, d[1], mz) * CFrame.Angles(0, d[2], 0)
		part(g, "Dish", V(1.2, d[3], d[3]), cf * CFrame.Angles(0, 0, 0.25), CREAM, M.SmoothPlastic, Enum.PartType.Cylinder)
		part(g, "DishArm", V(4, 0.8, 0.8), cf * CF(2.5, 0, 0), SIDE, M.Metal)
	end
	-- big ground dish on a pedestal
	part(g, "DishPedestal", V(3, 6, 3), CF(x - 12, top + 3, z + 13), SIDE, M.Metal)
	part(g, "GroundDish", V(1.4, 20, 20), CF(x - 12, top + 11, z + 13) * CFrame.Angles(0, -0.4, 0) * CFrame.Angles(0, 0, 0.55), CREAM, M.SmoothPlastic, Enum.PartType.Cylinder)
	part(g, "Hut", V(12, 8, 10), CF(x + 12, top + 4, z - 12), WARM, M.Concrete)
	part(g, "HutBand", V(12.3, 1, 10.3), CF(x + 12, top + 6.4, z - 12), OLIVE)
	part(g, "HutDoor", V(0.4, 5, 3), CF(x + 5.9, top + 2.5, z - 12), NEAR_BLACK)
	root:SetAttribute("_pComms", V(mx, top + 30, mz))
end

-- C. LandingPad: north-east, low; the background of the cutscene lift
do
	local g = grp("LandingPad", root)
	local x, top, z = 245, 2, 120
	disc(g, "Pad", x, top - 2, z, 66, 4, SIDE)
	disc(g, "PadTop", x, top - 0.12, z, 66.2, 0.24, HULL)
	disc(g, "PadRing", x, top + 0.02, z, 58, 0.06, CREAM)
	disc(g, "PadInner", x, top + 0.05, z, 55, 0.06, HULL)
	disc(g, "PadEdge", x, top - 1.2, z, 66.6, 1, OLIVE)
	-- H facing the base (west)
	part(g, "H", V(18, 0.1, 2.6), CF(x, top + 0.1, z - 7), CREAM)
	part(g, "H", V(18, 0.1, 2.6), CF(x, top + 0.1, z + 7), CREAM)
	part(g, "H", V(2.6, 0.1, 11.4), CF(x, top + 0.1, z), CREAM)
	for i = 0, 7 do
		local a = i * math.pi / 4
		part(g, "Beacon", V(1.6, 1, 1.6), CF(x + math.cos(a) * 31, top + 0.5, z + math.sin(a) * 31), i % 2 == 0 and NEON_CREAM or NEON_SAGE, M.Neon)
	end
	-- underside: cone of tiers, ring, pod
	disc(g, "Hull1", x, top - 6, z, 50, 4, HULL)
	disc(g, "Hull2", x, top - 9.5, z, 34, 3, HULL_D)
	disc(g, "AntiGravRing", x, top - 11.6, z, 30, 1.2, NEON_SAGE, M.Neon)
	disc(g, "Thruster", x, top - 13.6, z, 24, 3, HULL_D)
	disc(g, "ThrusterCore", x, top - 15.3, z, 10, 0.6, NEON_CREAM, M.Neon)
	-- outrigger with a control kiosk and a mast
	part(g, "Outrigger", V(12, 3, 10), CF(x + 36, top - 1.5, z + 6), SIDE)
	part(g, "Kiosk", V(9, 10, 8), CF(x + 38, top + 5, z + 6), WARM, M.Concrete)
	part(g, "KioskGlass", V(9.2, 2.4, 8.2), CF(x + 38, top + 7.6, z + 6), NEAR_BLACK, M.Glass)
	part(g, "KioskBand", V(9.3, 0.8, 8.3), CF(x + 38, top + 9.4, z + 6), OLIVE)
	root:SetAttribute("_pPad", mast(g, x + 40, top + 10, z + 9, 10))
end

-- D. FuelDepot: far south-east, low: horizontal tanks on saddles, a sphere tank, pipe run
do
	local g = grp("FuelDepot", root)
	local x, top, z = 360, -6, -290
	cslab(g, "Deck", x, top - 3, z, 74, 6, 46, 10, SIDE)
	cslab(g, "DeckTop", x, top - 0.2, z, 74.2, 0.4, 46.2, 10.05, DECK)
	cslab(g, "EdgeBand", x, top - 2, z, 74.3, 0.8, 46.3, 10.1, OLIVE)
	hull(g, x, top - 6, z, 56, 36, 8, 24)
	for i, tz in ipairs({z - 12, z, z + 12}) do
		local tx = x - 8
		part(g, "Tank", V(40, 10, 10), CF(tx, top + 7, tz), i == 2 and SAGE or CREAM, M.SmoothPlastic, Enum.PartType.Cylinder)
		part(g, "TankBand", V(1.6, 10.4, 10.4), CF(tx - 12, top + 7, tz), OLIVE_D, M.SmoothPlastic, Enum.PartType.Cylinder)
		part(g, "TankBand", V(1.6, 10.4, 10.4), CF(tx + 12, top + 7, tz), OLIVE_D, M.SmoothPlastic, Enum.PartType.Cylinder)
		part(g, "Saddle", V(2, 3, 8), CF(tx - 14, top + 1.5, tz), HULL)
		part(g, "Saddle", V(2, 3, 8), CF(tx + 14, top + 1.5, tz), HULL)
	end
	part(g, "SphereTank", V(15, 15, 15), CF(x + 24, top + 9.5, z + 8), WARM, M.SmoothPlastic, Enum.PartType.Ball)
	part(g, "SphereLegs", V(9, 4, 9), CF(x + 24, top + 2, z + 8), HULL)
	part(g, "Pipe", V(2, 2, 40), CF(x + 24, top + 2, z - 10), SIDE, M.Metal, Enum.PartType.Cylinder).CFrame = CF(x + 8, top + 2, z - 19)
	part(g, "PipeRiser", V(2, 10, 2), CF(x + 26, top + 5, z - 19), SIDE, M.Metal)
	root:SetAttribute("_pDepot", mast(g, x - 32, top, z + 18, 18))
end

-- links: sagging cables on the pylons
do
	local a = function(n) return root:GetAttribute(n) end
	cable(a("_pNW"), a("_pPad"), 14, 8)
	cable(a("_pSW"), a("_pDepot"), 16, 8)
	for _, n in ipairs({"_pNW", "_pNE", "_pSW", "_pComms", "_pPad", "_pDepot"}) do root:SetAttribute(n, nil) end
end

-- clouds: soft banks below the platforms, laid out as long north-south banks (overlapping flat base discs, low rounded
-- tops sunk into them so only soft domes show), also veiling the City backdrop's tower tops (y -53)
do
	local g = grp("Clouds", root)
	local CLOUD_Y = -44
	-- {x, z, r, axis angle}
	local banks = {
		{240, 165, 26, 0.3}, {300, 50, 30, -0.2}, {335, -55, 34, 0.15}, {265, -215, 28, -0.4}, {410, -215, 34, 0.2},
		{455, 185, 30, -0.1}, {525, -40, 38, 0.1}, {570, 120, 32, 0.35}, {610, -190, 36, -0.25}, {395, 290, 28, 0.2},
		{450, -370, 30, 0.0},
	}
	for i, b in ipairs(banks) do
		local x, z, r, th = b[1], b[2], b[3], b[4]
		local rnd = Random.new(i * 7919)
		local y0 = CLOUD_Y + rnd:NextNumber(-5, 5)
		local ax = V(math.sin(th), 0, math.cos(th))
		local sd = V(ax.Z, 0, -ax.X)
		for k = -1, 1 do
			local c = V(x, y0 - r * 0.12, z) + ax * (k * r * 1.1)
			disc(g, "CloudBase", c.X, c.Y, c.Z, r * (k == 0 and 1.9 or 1.5), r * 0.16, CLOUD_B)
		end
		for k = 1, 6 do
			local t = (k - 3.5) / 2.5
			local s = r * (1.15 - math.abs(t) * 0.45) * rnd:NextNumber(0.85, 1.1)
			local c = V(x, y0 - s * 0.22, z) + ax * (t * r * 1.5) + sd * rnd:NextNumber(-0.3, 0.3) * r
			local pf = part(g, "CloudPuff", V(s, s, s), CF(c), CLOUD, M.SmoothPlastic, Enum.PartType.Ball)
			pf.Transparency = 0.06
		end
	end
end

root.Parent = polish
local lights, emit, coll = 0, 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Light") then lights += 1 end
	if d:IsA("ParticleEmitter") or d:IsA("Beam") then emit += 1 end
	if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CastShadow) then coll += 1 end
end
say(("2. Polish.Backdrop: %d parts (HangarDeck, CommsIsland, LandingPad, FuelDepot, Cables, Clouds); lights %d, emitters %d, collide/query/shadow %d"):format(count, lights, emit, coll))
return table.concat(log, "\n")
