-- polish_exfil.lua : Exfil hangar + helipad as the OUTDOOR SKY EDGE of the base. Tacticals_rebuild.rbxl ONLY.
-- Identity (notes/overnight_polish.md): daylight, wind, amber runway and beacon lights, hazard markings, a windsock, tie-downs,
-- fuel/cargo carts, the pad H with its touchdown ring (kit), open sky views. Accents AMBER + cream, so the room reads apart
-- from the cream Shop, the gunmetal Armory and the charcoal Duels deck.
-- 1. Accents: every olive band of the hangar/pad kit (E_Walls/Piers/Portal/Mouth/PadWalls/Gear) -> amber hazard paint;
--    olive Neon (open-edge kerb line, EXFIL board outline, mast strips) -> amber Neon (measured values); L_Hangar daylight.
-- 2. Runway lights: amber Neon studs (no Light instances) along the open sky edge and both pad side walls, and lead-in studs
--    along the tunnel lane edges from the hub to the hangar.
-- 3. A windsock on a mast at the north-east pad corner (amber/cream fabric, amber obstruction lamp), wind from the north.
-- 4. Hazard markings: an amber/near-black hazard band inside the open edge, deck stencils (ROTOR AREA, DECK EDGE).
-- 5. Ground gear: a cargo dolly with strapped crates (south side, clear of the cutscene camera zone x 116..127, z -27..+4)
--    and a fuel-drum hand truck against the north pad wall; tie-down eyes round the H.
-- Hooks untouched: Exfil.ExfilBarrier / HatchPoint / CabinPoint / L_Pad, the Heli model, FX2, Rooms3.X_Clip.
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishExfil_Orig; new parts in
-- Workspace.LobbyMap.Polish.Exfil. Net new lights 0. Comments on their own line.
-- UNDO: python tools/run_luau.py fix/polish_exfil.lua UNDO
local UNDO = false --@UNDO
-- Edward's open question (lap1 R1): the TimesSquare towers fill the pad's open-sky view east. Off by default; set true to
-- hide LobbyMap.TimesSquare UNDO-ably (preview captures: out/polish/exfil/noTS_*.png).
local HIDE_TIMESSQUARE = false

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local R3 = LM.Rooms3
local ATTR = "PolishExfil_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	else return o.v end
end
local touched = 0
local function setP(inst, props)
	if not inst then return end
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
	touched += 1
end

local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if polish and polish:FindFirstChild("Exfil") then polish.Exfil:Destroy() end
	return "UNDO polish_exfil: restored " .. n .. " instances, removed Polish.Exfil"
end
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Exfil") then polish.Exfil:Destroy() end
local root = Instance.new("Folder"); root.Name = "Exfil"
root:SetAttribute("PolishPass", "polish_exfil.lua")

-- palette (Neon values picked by measurement: Neon renders ~1.5x its colour, see vault 7.7j)
local AMBER_PAINT = C(212, 122, 42)
local AMBER_NEON = C(190, 108, 26)
local AMBER_FABRIC = C(214, 128, 40)
local CREAM = C(236, 232, 218)
local NEAR_BLACK = C(10, 12, 10)
local DARK = C(40, 37, 34)
local METAL = C(108, 107, 104)
local OLIVE_D = C(107, 122, 58)
local HAZARD_TEX = "rbxassetid://79584884795039"

---------------------------------------------------------------------------------------------------
-- 1. Accents
---------------------------------------------------------------------------------------------------
local nRe = 0
for _, kit in ipairs({"E_Walls", "E_Piers", "E_Portal", "E_Mouth", "E_PadWalls", "E_Gear"}) do
	local m = R3:FindFirstChild(kit)
	local b = m and m:FindFirstChild(kit .. "__band_olive")
	if b then setP(b, {Color = AMBER_PAINT}); nRe += 1 else say("WARN no band in " .. kit) end
end
for _, path in ipairs({{"E_Lines", "E_Lines__neon_olive"}, {"E_Signs", "E_Signs__neon_olive"}, {"E_Gear", "E_Gear__neon_olive"}}) do
	local m = R3:FindFirstChild(path[1]); local p = m and m:FindFirstChild(path[2])
	if p then setP(p, {Color = AMBER_NEON}); nRe += 1 else say("WARN missing " .. path[2]) end
end
-- daylight: the hangar fill was a green-tinted 222,228,196
local lh = LM.Exfil:FindFirstChild("L_Hangar")
local pl = lh and lh:FindFirstChildWhichIsA("Light")
if pl then setP(pl, {Color = C(255, 246, 232)}) end
say(("accents: %d meshes recoloured amber, L_Hangar daylight"):format(nRe))
if HIDE_TIMESSQUARE and LM:FindFirstChild("TimesSquare") then
	for _, d in ipairs(LM.TimesSquare:GetDescendants()) do
		if d:IsA("BasePart") then setP(d, {Transparency = 1, CanQuery = false, CastShadow = false})
		elseif d:IsA("SurfaceGui") then setP(d, {Enabled = false}) end
	end
	say("TimesSquare hidden (HIDE_TIMESSQUARE)")
end

---------------------------------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------------------------------
local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new(o.class or "Part")
	if o.shape then p.Shape = o.shape end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = o.collide == true; p.CanQuery = o.collide == true; p.CanTouch = false
	p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.variant then p.MaterialVariant = o.variant end
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local function hazardTex(p, face, u, v, tint)
	local t = Instance.new("Texture"); t.Texture = HAZARD_TEX; t.Face = face or Enum.NormalId.Top
	t.StudsPerTileU = u or 2; t.StudsPerTileV = v or 0.5; t.Color3 = tint or AMBER_PAINT; t.Parent = p
	return t
end
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local function stencil(p, face, text, color, pps)
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 60; g.LightInfluence = 1; g.Parent = p
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.96, 0.86)
	t.Position = UDim2.fromScale(0.02, 0.07); t.Text = text; t.TextScaled = true; t.FontFace = FONT
	t.TextColor3 = color or CREAM; t.Parent = g
	return g
end

-- measuring: visible map parts queryable (lines, lamps, trims are CanQuery off); restored at the end
local qsaved = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 1 then qsaved[d] = true; d.CanQuery = true end
end
local function restoreQuery() for d in pairs(qsaved) do if d.Parent then d.CanQuery = false end end end
local rp = RaycastParams.new()
rp.FilterDescendantsInstances = {root, LM.Exfil, R3.X_Clip}
local function floorAt(x, z, from)
	local h = workspace:Raycast(Vector3.new(x, from or 6, z), Vector3.new(0, -10, 0), rp)
	return h and h.Position.Y, h and h.Instance
end
-- top of the floor under a flat footprint (centre + 4 corners), nil if anything there is not floor (y > 0.2)
local function floorTop(x, z, hx, hz)
	local top = -1e9
	for _, o in ipairs({{0, 0}, {hx, hz}, {-hx, hz}, {hx, -hz}, {-hx, -hz}}) do
		local y = floorAt(x + o[1], z + o[2])
		if not y or y > 0.2 then return nil end
		top = math.max(top, y)
	end
	return top
end
-- a footprint is free up to height h when every downward ray on a 0.5 grid lands on floor (merged kit meshes have
-- room-sized bounding boxes, so box queries can't be used here)
local function areaFree(x, z, hx, hz, h)
	for dx = -hx, hx + 0.001, math.max(0.25, hx / 4) do
		for dz = -hz, hz + 0.001, math.max(0.25, hz / 4) do
			local hit = workspace:Raycast(Vector3.new(x + dx, h, z + dz), Vector3.new(0, -(h + 2), 0), rp)
			if hit and hit.Position.Y > 0.2 then return false, hit.Instance end
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- 2. Runway lights (amber Neon studs: dark rim + lens, flush, 0.1 proud)
---------------------------------------------------------------------------------------------------
local lights = grp("RunwayLights", root)
local nStud = 0
local function stud(x, z, tag)
	local top = floorTop(x, z, 0.35, 0.35)
	if not top then return false end
	local up = CFrame.Angles(0, 0, math.rad(90))
	part(lights, tag .. "_Rim", Vector3.new(0.06, 0.7, 0.7), CFrame.new(x, top + 0.03, z) * up, DARK, M.Metal, {shape = Enum.PartType.Cylinder})
	part(lights, tag .. "_Lens", Vector3.new(0.05, 0.42, 0.42), CFrame.new(x, top + 0.085, z) * up, AMBER_NEON, M.Neon, {shape = Enum.PartType.Cylinder})
	nStud += 1
	return true
end
-- open sky edge (inside the kerb face x 150.8)
for z = -21, 21, 2.625 do stud(150.25, z, ("Edge_%d"):format(math.floor(z + 0.5))) end
-- both pad side walls (floor runs to z +-26.5)
for _, sz in ipairs({-1, 1}) do
	for x = 129.5, 148.5, 3.2 do stud(x, sz * 25.7, ("Side%s_%d"):format(sz < 0 and "S" or "N", math.floor(x))) end
end
-- tunnel lead-in: outside the cream lane lines (z +-8.4), hub -> hangar
for _, sz in ipairs({-1, 1}) do
	for x = 90.5, 103.5, 3.25 do stud(x, sz * 9.7, ("Lead%s_%d"):format(sz < 0 and "S" or "N", math.floor(x))) end
end
say(("runway studs: %d (Neon only)"):format(nStud))

---------------------------------------------------------------------------------------------------
-- 3. Windsock (north-east corner, clear of the rotor disc z -14..13 and the tail x 129-134)
---------------------------------------------------------------------------------------------------
local ws = grp("Windsock", root)
do
	local x, z = 149.4, 18.5
	local top = floorTop(x, z, 0.7, 0.7) or 0.02
	local H = 10
	part(ws, "Base", Vector3.new(1.4, 0.2, 1.4), CFrame.new(x, top + 0.1, z), DARK, M.Metal, {collide = true})
	part(ws, "BaseBand", Vector3.new(1.42, 0.08, 1.42), CFrame.new(x, top + 0.17, z), AMBER_PAINT, M.SmoothPlastic)
	part(ws, "Pole", Vector3.new(H, 0.3, 0.3), CFrame.new(x, top + 0.2 + H / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		METAL, M.Metal, {shape = Enum.PartType.Cylinder, collide = true, shadow = true})
	-- pole bands (amber/near-black) at the foot, like the beacon masts
	for i = 0, 3 do
		part(ws, "PoleBand" .. i, Vector3.new(0.5, 0.34, 0.34), CFrame.new(x, top + 0.55 + i * 0.5, z) * CFrame.Angles(0, 0, math.rad(90)),
			i % 2 == 0 and AMBER_PAINT or NEAR_BLACK, M.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	end
	local ty = top + 0.2 + H
	part(ws, "Lamp", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, ty + 0.25, z), AMBER_NEON, M.Neon, {shape = Enum.PartType.Ball})
	part(ws, "LampCap", Vector3.new(0.12, 0.56, 0.56), CFrame.new(x, ty + 0.03, z) * CFrame.Angles(0, 0, math.rad(90)), DARK, M.Metal, {shape = Enum.PartType.Cylinder})
	-- swivel arm out to the sock ring; wind from the north: the sock streams toward -z, drooping 12 degrees
	local dir = Vector3.new(0, -math.sin(math.rad(12)), -math.cos(math.rad(12)))
	local ringC = Vector3.new(x, ty - 0.55, z - 0.75)
	part(ws, "Arm", Vector3.new(0.12, 0.12, 0.8), CFrame.new(x, ty - 0.55, z - 0.35), DARK, M.Metal)
	local function along(pos, d) return CFrame.lookAt(pos, pos + d) * CFrame.Angles(0, math.rad(90), 0) end
	local dia = {1.3, 1.17, 1.04, 0.91, 0.78}
	local pos = ringC + dir * 0.06
	for i, d in ipairs(dia) do
		local len = 0.95
		-- each segment droops a little more (sock sags at the tail in light wind)
		local di = (dir + Vector3.new(0, -0.035 * i, 0)).Unit
		local c = pos + di * (len / 2)
		part(ws, "Sock" .. i, Vector3.new(len, d, d), along(c, di), i % 2 == 1 and AMBER_FABRIC or CREAM, M.Fabric,
			{shape = Enum.PartType.Cylinder, shadow = true})
		pos = pos + di * len
	end
end
say("windsock: mast 10 high at (149.4, 18.5), sock streaming south")

---------------------------------------------------------------------------------------------------
-- 4. Hazard markings
---------------------------------------------------------------------------------------------------
local hz = grp("Hazard", root)
-- amber/near-black hazard band inside the open edge (the kit kerb line stays the edge)
do
	local x0, x1 = 148.55, 149.25
	local tops = {}
	for z = -21, 21, 1.5 do local y = floorTop((x0 + x1) / 2, z, 0.3, 0.6); if y then table.insert(tops, y) end end
	local top = math.max(table.unpack(tops))
	local band = part(hz, "EdgeBand", Vector3.new(x1 - x0, 0.04, 42), CFrame.new((x0 + x1) / 2, top + 0.02 + 0.04, 0), NEAR_BLACK, M.SmoothPlastic)
	hazardTex(band, Enum.NormalId.Top, 2, 2, AMBER_PAINT)
end
-- deck stencils, read from the hangar (text runs along z, its top toward +x)
local function deckStencil(name, x, z, w, d, text, color)
	local top = floorTop(x, z, d / 2, w / 2)
	if not top then say("WARN stencil " .. name .. " not on a clear floor"); return end
	local p = part(hz, name, Vector3.new(d, 0.03, w), CFrame.new(x, top + 0.04 + 0.015, z) * CFrame.Angles(0, math.pi, 0),
		Color3.new(0, 0, 0), M.SmoothPlastic)
	p.Transparency = 1
	stencil(p, Enum.NormalId.Top, text, color, 50)
end
deckStencil("Stencil_Rotor", 130.6, -18.2, 9, 1.3, "ROTOR AREA · KEEP CLEAR", CREAM)
deckStencil("Stencil_Edge", 147.4, 0, 8, 1.1, "DECK EDGE · NO STEP", AMBER_PAINT)
-- tie-down eyes round the H (outside the hazard brackets at +-8.5)
local nTie = 0
for _, x in ipairs({131, 137, 143}) do
	for _, z in ipairs({-9.6, 9.6}) do
		local top = floorTop(x, z, 0.35, 0.35)
		if top and areaFree(x, z, 0.4, 0.4, 4) then
			local up = CFrame.Angles(0, 0, math.rad(90))
			part(hz, ("TieDown_%d_%d"):format(x, z), Vector3.new(0.05, 0.75, 0.75), CFrame.new(x, top + 0.025, z) * up, DARK, M.Metal, {shape = Enum.PartType.Cylinder})
			part(hz, ("TieDownRing_%d_%d"):format(x, z), Vector3.new(0.06, 0.5, 0.5), CFrame.new(x, top + 0.07, z) * up, METAL, M.Metal, {shape = Enum.PartType.Cylinder})
			part(hz, ("TieDownEye_%d_%d"):format(x, z), Vector3.new(0.07, 0.28, 0.28), CFrame.new(x, top + 0.075, z) * up, NEAR_BLACK, M.Metal, {shape = Enum.PartType.Cylinder})
			nTie += 1
		end
	end
end
say(("hazard band, 2 deck stencils, %d tie-down eyes"):format(nTie))

---------------------------------------------------------------------------------------------------
-- 5. Ground gear
---------------------------------------------------------------------------------------------------
local gear = grp("GroundGear", root)
-- cargo dolly, south side, tow bar toward the pad (+x)
do
	local cx, cz = 133.2, -23.1
	local top = floorTop(cx, cz, 2.9, 1.3) or 0.02
	local cart = grp("CargoDolly", gear)
	local deckY = top + 0.95
	local ok, hit = areaFree(cx + 0.5, cz, 3.4, 1.4, 20)
	if not ok then say("WARN dolly box hits " .. hit:GetFullName()) end
	part(cart, "Deck", Vector3.new(5.6, 0.22, 2.4), CFrame.new(cx, deckY, cz), C(52, 50, 46), M.Metal, {collide = true, shadow = true})
	for _, s in ipairs({-1, 1}) do
		local rail = part(cart, "SideRail", Vector3.new(5.6, 0.3, 0.12), CFrame.new(cx, deckY - 0.05, cz + s * 1.24), NEAR_BLACK, M.SmoothPlastic)
		hazardTex(rail, s > 0 and Enum.NormalId.Back or Enum.NormalId.Front, 1.2, 1.2, AMBER_PAINT)
	end
	for _, wx in ipairs({-2.1, 2.1}) do
		for _, s in ipairs({-1, 1}) do
			part(cart, "Wheel", Vector3.new(0.28, 0.62, 0.62), CFrame.new(cx + wx, top + 0.31, cz + s * 1.05) * CFrame.Angles(0, math.rad(90), 0),
				C(24, 24, 22), M.Rubber, {shape = Enum.PartType.Cylinder})
			part(cart, "Hub", Vector3.new(0.3, 0.26, 0.26), CFrame.new(cx + wx, top + 0.31, cz + s * 1.05) * CFrame.Angles(0, math.rad(90), 0),
				METAL, M.Metal, {shape = Enum.PartType.Cylinder})
			part(cart, "Fork", Vector3.new(0.18, 0.5, 0.12), CFrame.new(cx + wx, deckY - 0.36, cz + s * 0.9), DARK, M.Metal)
		end
	end
	part(cart, "TowBar", Vector3.new(1.7, 0.12, 0.12), CFrame.new(cx + 3.55, top + 0.62, cz) * CFrame.Angles(0, 0, math.rad(-12)), DARK, M.Metal)
	part(cart, "TowEye", Vector3.new(0.1, 0.36, 0.36), CFrame.new(cx + 4.4, top + 0.45, cz) * CFrame.Angles(0, 0, math.rad(90)), AMBER_PAINT, M.Metal, {shape = Enum.PartType.Cylinder})
	-- cargo: two dark-olive crates and a cream-strapped bundle, stencilled
	local function crate(name, x, w, h, d)
		local c = part(cart, name, Vector3.new(w, h, d), CFrame.new(cx + x, deckY + 0.11 + h / 2, cz), OLIVE_D:Lerp(Color3.new(0, 0, 0), 0.35), M.SmoothPlastic, {collide = true, shadow = true})
		part(cart, name .. "_StrapA", Vector3.new(0.14, h + 0.04, d + 0.04), CFrame.new(cx + x - w * 0.28, deckY + 0.11 + h / 2, cz), CREAM, M.Fabric)
		part(cart, name .. "_StrapB", Vector3.new(0.14, h + 0.04, d + 0.04), CFrame.new(cx + x + w * 0.28, deckY + 0.11 + h / 2, cz), CREAM, M.Fabric)
		return c
	end
	local c1 = crate("CrateA", -1.25, 2.6, 1.5, 2.0)
	crate("CrateB", 1.45, 2.2, 1.15, 1.8)
	local lab = part(cart, "CrateA_Label", Vector3.new(1.0, 0.5, 0.03), CFrame.new(cx - 1.25, deckY + 0.11 + 0.95, cz + 1.016), CREAM, M.SmoothPlastic)
	stencil(lab, Enum.NormalId.Front, "EXFIL · 04", NEAR_BLACK, 100)
end
-- fuel-drum hand truck against the north pad wall (keeps the walk under the tail at z ~16 open)
do
	local cx, cz = 132.6, 22.3
	local top = floorTop(cx, cz, 1.2, 1.0) or 0.02
	local ok, hit = areaFree(cx, cz, 1.4, 1.2, 6)
	if not ok then say("WARN drum truck box hits " .. hit:GetFullName()) end
	local tr = grp("DrumTruck", gear)
	part(tr, "Plate", Vector3.new(2.5, 0.12, 1.5), CFrame.new(cx, top + 0.3, cz), DARK, M.Metal, {collide = true})
	for _, s in ipairs({-1, 1}) do
		part(tr, "Wheel", Vector3.new(0.22, 0.6, 0.6), CFrame.new(cx + 0.6, top + 0.3, cz + s * 0.9) * CFrame.Angles(0, math.rad(90), 0),
			C(24, 24, 22), M.Rubber, {shape = Enum.PartType.Cylinder})
		part(tr, "Upright", Vector3.new(0.1, 2.3, 0.1), CFrame.new(cx + 1.2, top + 1.45, cz + s * 0.7) * CFrame.Angles(0, 0, math.rad(-8)), DARK, M.Metal)
	end
	part(tr, "Handle", Vector3.new(0.1, 0.1, 1.5), CFrame.new(cx + 1.36, top + 2.55, cz), AMBER_PAINT, M.Metal)
	for i, dz in ipairs({-0.36, 0.36}) do
		local dc = CFrame.new(cx - 0.15, top + 0.36 + 0.95, cz + dz * 1.0)
		part(tr, "Drum" .. i, Vector3.new(1.9, 0.68, 0.68), dc * CFrame.Angles(0, 0, math.rad(90)), C(70, 82, 52), M.Metal, {shape = Enum.PartType.Cylinder, collide = true, shadow = true})
		for _, hy in ipairs({-0.55, 0.55}) do
			part(tr, "DrumHoop", Vector3.new(0.06, 0.71, 0.71), dc * CFrame.new(0, hy, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, M.Metal, {shape = Enum.PartType.Cylinder})
		end
		part(tr, "DrumBand", Vector3.new(0.18, 0.7, 0.7), dc * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), AMBER_PAINT, M.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	end
	part(tr, "Strap", Vector3.new(0.08, 0.12, 1.5), CFrame.new(cx - 0.15 + 0.36, top + 1.75, cz), CREAM, M.Fabric)
end
say("ground gear: cargo dolly (south), fuel-drum truck (north)")

root.Parent = polish
restoreQuery()
local n, nl, nc = 0, 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then n += 1; if d.CanCollide then nc += 1 end end
	if d:IsA("Light") then nl += 1 end
end
say(("Polish.Exfil: %d parts (%d collide), %d new lights; %d property records"):format(n, nc, nl, touched))
return table.concat(log, "\n")
