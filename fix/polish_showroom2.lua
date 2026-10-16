-- polish_showroom2.lua : the Showroom (Kit menu viewer) as a SMALL SKY-BASE ARMORY NOOK, round 2 (Edward approved 2026-10-16).
-- Tacticals_rebuild.rbxl ONLY (studio 8ef4e21a). Run after place_showroom.lua, polish_olive.lua and polish_showroom.lua.
-- Why: round 1 made a cream photo-studio cyclorama that the UI blurs into a grey wash. RIVALS' Weapons screen shows the weapon
-- in a SHARP, lit little room. This builds that room in the Tacticals palette and military-sky theme.
-- What players see (LobbyUIController.Armory): a Scriptable camera at CameraPoint (0,407.4,-5) looking +z (pitch -4.6 deg),
-- FOV 40; the item is drawn in a full-screen ViewportFrame (never occluded by the world, lit only by its own Ambient/
-- LightColor and LightDirection = KeyLight -> DisplayPoint), centred on DisplayPoint (0,406.3,8) and scaled to at most
-- 7.5 * 1.05 studs corner to corner (sphere r 3.94); the user can turn it freely, zoom it toward the camera, and items
-- slide in/out along screen-right (+-16). The fake contact shadow lies on BenchTop's top (404.43). The camera never moves.
-- UI cover (1268x785 capture): left list panel 0..21% of the width, right cards from 80%, slot bar at the bottom centre:
-- the set reads mostly in the centre and in the upper third, so the window, the vent and the rack's top shelves sit high.
-- Layout (screen-left = +x, screen-right = -x):
--   foreground  the bench (existing SR_Stage, restyled as a maintenance bench) with a cutting mat, a desk lamp and a tool tray
--   mid-ground  the weapon at DisplayPoint; a crate stack (+x) and an ammo crate (-x) on the floor beside the bench
--   background  the nook: back wall at z 21 (13 studs behind the weapon) with a pegboard of tools and kit (no weapons), a strip
--               lamp, a window onto the sky (+x), a louvred vent (-x), a cable run along the top, shelving (-x); side cheeks at x +-15
-- Light: warm key (KeyLight, shadows), cool rim from the window and the work light, practical sources everywhere (strip lamp,
--   desk lamp, shelf LED, bulkhead lamp, window). Existing 6 RoomLights moved/retuned; +2 new (WorkLight, BulkheadLamp),
--   each a tagged RoomLight part with Room=Showroom (RoomFX switches direct child lights).
-- Rules: everything CanCollide/CanQuery/CanTouch false, NotCover; nothing new inside the item sphere except the bench mat
--   (the shadow surface); hooks DisplayPoint / CameraPoint / BenchTop / KeyLight part untouched.
-- Round 1's cyclorama and lamp cans are HIDDEN (not deleted). Idempotent; touched properties stored once (typed JSON) in
-- attribute PolishShowroom2_Orig; new parts in Workspace.LobbyMap.Polish.Showroom2.
-- UNDO: python tools/run_luau.py fix/polish_showroom2.lua UNDO   (returns to round 1's photo studio)
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap
local S = LM.Showroom
local K = S.Rooms4
local ATTR = "PolishShowroom2_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "CFrame" then return {t = "cf", v = {v:GetComponents()}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "cf" then return CFrame.new(table.unpack(o.v))
	else return o.v end
end
local function setP(inst, props)
	if not inst then return end
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
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
	if polish and polish:FindFirstChild("Showroom2") then polish.Showroom2:Destroy() end
	return "UNDO polish_showroom2: restored " .. n .. " instances, removed Polish.Showroom2"
end
assert(polish and polish:FindFirstChild("Showroom"), "run polish_showroom.lua first")
if polish:FindFirstChild("Showroom2") then polish.Showroom2:Destroy() end
local root = Instance.new("Folder"); root.Name = "Showroom2"
root:SetAttribute("PolishPass", "polish_showroom2.lua")

---------------------------------------------------------------------------------------------------
-- palette (paint values; the sky fill cools and compresses near-whites in this set, so creams lean warm: round 1 measured
-- 244,214,180 -> renders ~cream 225,224,213)
---------------------------------------------------------------------------------------------------
-- measured in this set (r2_v1): paint renders ~1.3x brighter and bluer (olive 138,156,74 -> 185,204,112; cream 240,222,192
-- -> 228,229,221 cool white), so paints are the palette divided by that: they RENDER as the Tacticals palette
local OLIVE = C(104, 114, 46)       -- renders ~ olive 138,150,70
local OLIVE_D = C(82, 92, 38)       -- renders ~ dark olive
local OLIVE_DD = C(62, 68, 30)
local CREAM = C(196, 172, 134)      -- renders ~ cream (a mid cream: a white wall flattens the set)
local CREAM_T = C(236, 232, 218)    -- stencil text (SurfaceGui, not affected the same way)
local WARM_GREY = C(176, 160, 138)  -- renders ~ warm grey 200,196,186
local WARM_GREY_D = C(132, 122, 108)
local SAGE = C(132, 130, 106)       -- renders ~ sage
local SAGE_D = C(100, 104, 82)
local NEAR_BLACK = C(10, 12, 10)
local DARK = C(34, 36, 32)
local STEEL = C(120, 120, 118)
local WARM_LIGHT = C(255, 214, 162)
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local TEX = {grate = "rbxassetid://119843963596060", louvre = "rbxassetid://136153789620409",
	hazard = "rbxassetid://79584884795039", grime = "rbxassetid://110762390496312",
	panel = "rbxassetid://119251552384756"}

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	if o.shape then p.Shape = o.shape end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = o.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.transparent then p.Transparency = 1; p.CastShadow = false end
	if o.t then p.Transparency = o.t end
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
-- axis-aligned box from its extents
local function box(parent, name, x0, x1, y0, y1, z0, z1, color, mat, o)
	return part(parent, name, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, mat, o)
end
local function cyl(parent, name, a, b, d, color, mat, o)
	-- cylinder from point a to point b, diameter d
	local len = (b - a).Magnitude
	o = o or {}; o.shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, mat, o)
end
local function texture(p, id, su, sv, color, tr, face)
	local t = Instance.new("Texture"); t.Texture = id; t.Face = face or Enum.NormalId.Front
	t.StudsPerTileU = su; t.StudsPerTileV = sv; t.Color3 = color or Color3.new(1, 1, 1); t.Transparency = tr or 0; t.Parent = p
	return t
end
-- painted text: a transparent plate whose Front face carries the lines
local function stencil(parent, name, size, cf, lines, color, align, face)
	local p = part(parent, name, size, cf, CREAM, M.SmoothPlastic, {transparent = true})
	local g = Instance.new("SurfaceGui"); g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 100; g.LightInfluence = 1; g.Parent = p
	local n = #lines
	for i, ln in ipairs(lines) do
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.96, 0.9 / n)
		t.Position = UDim2.fromScale(0.02, 0.05 + (i - 1) * 0.9 / n)
		t.Text = ln; t.TextScaled = true; t.FontFace = FONT; t.TextColor3 = color
		t.TextXAlignment = align or Enum.TextXAlignment.Center; t.Parent = g
	end
	return p
end
-- a lit RoomLight holder (tag + Room attribute; RoomFX toggles its direct child lights)
local function roomLight(parent, name, cf, class, props)
	local h = part(parent, name, Vector3.new(0.2, 0.2, 0.2), cf, NEAR_BLACK, M.SmoothPlastic, {transparent = true})
	local l = Instance.new(class)
	for k, v in pairs(props) do l[k] = v end
	l.Shadows = false; l.Parent = h
	CS:AddTag(h, "RoomLight"); h:SetAttribute("Room", "Showroom")
	return h
end
-- a crate: body, a batten frame on the front face, chamfered vertical and top edges, stencil on the front
-- cf = centre; local -Z (front) faces the camera
local function crate(parent, name, cf, size, body, edge, lines, ink)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent
	local w, h, d = size.X, size.Y, size.Z
	part(m, "Body", size, cf, body, M.SmoothPlastic)
	local b = 0.2
	local fz = -d / 2 - 0.04
	part(m, "BattenT", Vector3.new(w - 0.1, b, 0.08), cf * CFrame.new(0, h / 2 - b / 2 - 0.05, fz), edge, M.SmoothPlastic)
	part(m, "BattenB", Vector3.new(w - 0.1, b, 0.08), cf * CFrame.new(0, -h / 2 + b / 2 + 0.05, fz), edge, M.SmoothPlastic)
	part(m, "BattenL", Vector3.new(b, h - 0.5, 0.08), cf * CFrame.new(-w / 2 + b / 2 + 0.05, 0, fz), edge, M.SmoothPlastic)
	part(m, "BattenR", Vector3.new(b, h - 0.5, 0.08), cf * CFrame.new(w / 2 - b / 2 - 0.05, 0, fz), edge, M.SmoothPlastic)
	-- chamfers: 45-degree strips over the 4 vertical edges and the 4 top edges
	local c = 0.26
	for _, sx in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
		part(m, "ChamferV", Vector3.new(c, h - 0.02, c), cf * CFrame.new(sx * w / 2, 0, sz * d / 2) * CFrame.Angles(0, math.rad(45), 0), edge, M.SmoothPlastic)
	end end
	for _, sz in ipairs({-1, 1}) do
		part(m, "ChamferTop", Vector3.new(w - 0.02, c, c), cf * CFrame.new(0, h / 2, sz * d / 2) * CFrame.Angles(math.rad(45), 0, 0), edge, M.SmoothPlastic)
	end
	for _, sx in ipairs({-1, 1}) do
		part(m, "ChamferTop", Vector3.new(c, c, d - 0.02), cf * CFrame.new(sx * w / 2, h / 2, 0) * CFrame.Angles(0, 0, math.rad(45)), edge, M.SmoothPlastic)
	end
	-- grime: own overlay, faint
	local body_ = m:FindFirstChild("Body")
	texture(body_, TEX.grime, 3, 3, C(60, 56, 48), 0.82)
	if lines then
		stencil(m, "Stencil", Vector3.new(w * 0.62, math.min(h * 0.42, 0.55 * #lines), 0.02), cf * CFrame.new(0, 0.05, -d / 2 - 0.012), lines, ink or CREAM_T)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- 0. hide round 1's cyclorama and lamp cans (round 1 stays intact underneath: UNDO brings it back)
---------------------------------------------------------------------------------------------------
local nHid = 0
for _, d in ipairs(polish.Showroom:GetDescendants()) do
	if d:IsA("BasePart") then setP(d, {Transparency = 1, CastShadow = false}); nHid += 1 end
end
say("round 1 hidden: " .. nHid .. " parts (cyclorama, lamp cans)")

---------------------------------------------------------------------------------------------------
-- 1. the nook: back wall (front face z 21), side cheeks (inner faces x +-15), cable run
---------------------------------------------------------------------------------------------------
local WZ = 21
local FL = 400.07 -- floor trim top
local wall = Instance.new("Folder"); wall.Name = "Wall"; wall.Parent = root
local wu = box(wall, "WallUpper", -15.6, 15.6, 404.2, 419.5, WZ, WZ + 0.6, CREAM, M.SmoothPlastic)
-- own overlays: faint panel lines and grime so the cream reads as painted plate, not a flat card
texture(wu, TEX.panel, 6, 6, C(120, 108, 90), 0.75)
texture(wu, TEX.grime, 7, 7, C(90, 80, 64), 0.8)
local wains = box(wall, "Wainscot", -15, 15, FL, 404.2, WZ - 0.18, WZ, OLIVE_DD, M.SmoothPlastic)
texture(wains, TEX.grime, 4, 4, C(30, 30, 24), 0.85)
box(wall, "Rail", -15, 15, 404.2, 404.6, WZ - 0.3, WZ, OLIVE, M.SmoothPlastic)
part(wall, "RailChamfer", Vector3.new(30, 0.2, 0.2), CFrame.new(0, 404.6, WZ - 0.3) * CFrame.Angles(math.rad(45), 0, 0), OLIVE, M.SmoothPlastic)
-- panel seams on the cream wall (clear of the pegboard)
for _, x in ipairs({-13.6, -7.4, 7.4, 13.6}) do
	box(wall, "Seam", x - 0.05, x + 0.05, 404.6, 417, WZ - 0.02, WZ, WARM_GREY_D, M.SmoothPlastic, {shadow = false})
end
box(wall, "SeamH", -15, 15, 415.45, 415.55, WZ - 0.02, WZ, WARM_GREY_D, M.SmoothPlastic, {shadow = false})
-- crown: dark band under the ceiling with a chamfered lower edge
box(wall, "Crown", -15, 15, 417, 419.5, WZ - 0.35, WZ, DARK, M.Metal)
part(wall, "CrownChamfer", Vector3.new(30, 0.3, 0.3), CFrame.new(0, 417, WZ - 0.35) * CFrame.Angles(math.rad(45), 0, 0), DARK, M.Metal)
-- cable run: a tray along the crown, a clipped bundle of three cables under it, drops to the junction box and the lamp
local cab = Instance.new("Folder"); cab.Name = "CableRun"; cab.Parent = root
box(cab, "Tray", -15, 15, 416.3, 416.75, WZ - 0.75, WZ - 0.35, NEAR_BLACK, M.Metal)
box(cab, "TrayLip", -15, 15, 416.75, 416.85, WZ - 0.78, WZ - 0.7, STEEL, M.Metal)
local cols = {OLIVE, DARK, SAGE}
for i, col in ipairs(cols) do
	local y, z = 415.92 - (i - 1) * 0.0, WZ - 0.12 - (i - 1) * 0.17
	cyl(cab, "Cable", Vector3.new(-15, y, z), Vector3.new(15, y, z), 0.15, col, M.SmoothPlastic)
end
for x = -13.5, 13.5, 3 do
	box(cab, "Clip", x - 0.09, x + 0.09, 415.72, 416.12, WZ - 0.6, WZ, STEEL, M.Metal)
end
-- drop: the bundle turns down at x 6.6 to a junction box beside the pegboard
cyl(cab, "Drop", Vector3.new(6.6, 415.9, WZ - 0.12), Vector3.new(6.6, 409.3, WZ - 0.12), 0.15, OLIVE, M.SmoothPlastic)
cyl(cab, "Drop", Vector3.new(6.85, 415.9, WZ - 0.12), Vector3.new(6.85, 409.3, WZ - 0.12), 0.15, DARK, M.SmoothPlastic)
box(cab, "JunctionBox", 6.15, 7.3, 408.0, 409.3, WZ - 0.45, WZ, WARM_GREY, M.Metal)
box(cab, "JunctionLid", 6.22, 7.23, 408.07, 409.23, WZ - 0.5, WZ - 0.45, WARM_GREY_D, M.Metal)
box(cab, "JunctionLED", 6.62, 6.82, 408.85, 409.0, WZ - 0.53, WZ - 0.5, OLIVE, M.Neon, {shadow = false})
stencil(cab, "JunctionText", Vector3.new(0.9, 0.3, 0.02), CFrame.new(6.72, 408.4, WZ - 0.515), {"240V"}, NEAR_BLACK)
-- the second drop feeds the vent fan (screen right)
cyl(cab, "Drop", Vector3.new(-7.0, 415.9, WZ - 0.12), Vector3.new(-7.0, 413.2, WZ - 0.12), 0.15, DARK, M.SmoothPlastic)
-- side cheeks
for _, s in ipairs({-1, 1}) do
	local xi = s * 15
	local function xr(a, b) return math.min(xi + s * a, xi + s * b), math.max(xi + s * a, xi + s * b) end
	local a0, a1 = xr(0, 0.6)
	box(wall, "Cheek", a0, a1, FL, 419.5, 12, WZ + 0.6, WARM_GREY, M.SmoothPlastic)
	local b0, b1 = xr(-0.15, 0)
	box(wall, "CheekWainscot", b0, b1, FL, 404.2, 12, WZ, OLIVE_DD, M.SmoothPlastic)
	local c0, c1 = xr(-0.25, 0)
	box(wall, "CheekRail", c0, c1, 404.2, 404.6, 12, WZ, OLIVE, M.SmoothPlastic)
	local d0, d1 = xr(-0.08, 0)
	box(wall, "CheekBand", d0, d1, 408.6, 409.6, 12, WZ, OLIVE, M.SmoothPlastic)
	box(wall, "CheekCrown", c0 - (s > 0 and 0.1 or 0), c1 + (s < 0 and 0.1 or 0), 417, 419.5, 12, WZ, DARK, M.Metal)
	-- front edge post, chamfered
	part(wall, "CheekPost", Vector3.new(0.7, 419.5 - FL, 0.7), CFrame.new(xi + s * 0.3, (419.5 + FL) / 2, 12) * CFrame.Angles(0, math.rad(45), 0), DARK, M.Metal)
end
say("nook: back wall z 21 (cream over a dark olive wainscot, olive rail, seams, crown), cheeks x +-15, cable run")

---------------------------------------------------------------------------------------------------
-- 2. pegboard (centre, behind the weapon) with tools and kit on shadow-board outlines; strip lamp above
---------------------------------------------------------------------------------------------------
local pb = Instance.new("Folder"); pb.Name = "Pegboard"; pb.Parent = root
local PZ = WZ - 0.25 -- board front face
local board = box(pb, "Board", -5.6, 5.6, 405.0, 412.6, PZ, WZ, C(150, 138, 120), M.SmoothPlastic)
texture(board, TEX.grate, 0.8, 0.8, C(96, 92, 84), 0.35)
for _, e in ipairs({
	{"FrameT", -5.8, 5.8, 412.6, 412.85}, {"FrameB", -5.8, 5.8, 404.75, 405.0},
	{"FrameL", 5.6, 5.85, 405.0, 412.6}, {"FrameR", -5.85, -5.6, 405.0, 412.6}}) do
	box(pb, e[1], e[2], e[3], e[4], e[5], PZ - 0.12, WZ, OLIVE_D, M.Metal)
end
local TZ = PZ - 0.02 -- outline paint
local function outline(name, cx, cy, w, h, rot)
	part(pb, name, Vector3.new(w, h, 0.02), CFrame.new(cx, cy, TZ + 0.01) * CFrame.Angles(0, 0, math.rad(rot or 0)), C(112, 104, 90), M.SmoothPlastic, {shadow = false})
end
local function peg(x, y)
	cyl(pb, "Peg", Vector3.new(x, y, PZ), Vector3.new(x, y, PZ - 0.35), 0.09, DARK, M.Metal)
end
local tz = PZ - 0.2 -- tool centre depth
-- wrenches (rotated), top corners
for _, s in ipairs({-1, 1}) do
	local cx, cy, r = s * 4.5, 410.7, s * 18
	outline("Outline", cx, cy, 0.48, 2.7, r)
	local cf = CFrame.new(cx, cy, tz) * CFrame.Angles(0, 0, math.rad(r))
	part(pb, "WrenchHandle", Vector3.new(0.26, 2.1, 0.1), cf, STEEL, M.Metal)
	part(pb, "WrenchHead", Vector3.new(0.62, 0.38, 0.1), cf * CFrame.new(0, 1.15, 0), STEEL, M.Metal)
	part(pb, "WrenchJawL", Vector3.new(0.16, 0.3, 0.1), cf * CFrame.new(-0.23, 1.42, 0), STEEL, M.Metal)
	part(pb, "WrenchJawR", Vector3.new(0.16, 0.3, 0.1), cf * CFrame.new(0.23, 1.42, 0), STEEL, M.Metal)
	part(pb, "WrenchRing", Vector3.new(0.12, 0.55, 0.55), cf * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(90), 0), STEEL, M.Metal, {shape = Enum.PartType.Cylinder})
	peg(cx, cy + 0.2)
end
-- screwdrivers: three, handles olive / sage / near-black
for i, col in ipairs({OLIVE, SAGE_D, DARK}) do
	local x = -3.3 + (i - 1) * 0.55
	outline("Outline", x, 410.75, 0.32, 2.25)
	cyl(pb, "DriverHandle", Vector3.new(x, 411.75, tz), Vector3.new(x, 410.95, tz), 0.26, col, M.SmoothPlastic)
	cyl(pb, "DriverShaft", Vector3.new(x, 410.95, tz), Vector3.new(x, 409.75, tz), 0.07, STEEL, M.Metal)
	peg(x, 411.95)
end
-- maintenance log clipboard (top centre)
box(pb, "Clipboard", -1.2, 1.2, 409.3, 412.25, tz - 0.03, tz + 0.03, C(70, 62, 50), M.SmoothPlastic)
box(pb, "ClipPaper", -1.05, 1.05, 409.42, 411.85, tz - 0.05, tz - 0.03, C(206, 192, 162), M.SmoothPlastic)
box(pb, "Clip", -0.45, 0.45, 411.85, 412.15, tz - 0.12, tz - 0.03, STEEL, M.Metal)
do
	local g = stencil(pb, "LogText", Vector3.new(2.0, 2.3, 0.02), CFrame.new(0, 410.62, tz - 0.065),
		{"MAINT LOG", "BENCH 02", "CLEAN  /  OIL", "CHECK  ZERO", "SIGN: ______"}, C(40, 40, 36))
	g.SurfaceGui.LightInfluence = 1
end
peg(0, 412.3)
-- ear defenders (sage cups on a dark band)
do
	local cx, cy = 2.75, 410.9
	outline("Outline", cx, cy, 1.55, 1.75)
	for _, s in ipairs({-1, 1}) do
		cyl(pb, "Cup", Vector3.new(cx + s * 0.55, cy - 0.35, tz - 0.12), Vector3.new(cx + s * 0.55, cy - 0.35, tz + 0.12), 0.75, SAGE_D, M.SmoothPlastic)
		cyl(pb, "CupPad", Vector3.new(cx + s * 0.55, cy - 0.35, tz - 0.16), Vector3.new(cx + s * 0.55, cy - 0.35, tz - 0.12), 0.55, DARK, M.SmoothPlastic)
	end
	for k = 0, 6 do
		local a = math.rad(-90 + k * 30)
		local px, py = cx + math.sin(a) * 0.55, cy - 0.15 + math.cos(a) * 0.62
		part(pb, "Band", Vector3.new(0.34, 0.12, 0.1), CFrame.new(px, py, tz) * CFrame.Angles(0, 0, -a), DARK, M.SmoothPlastic)
	end
	peg(cx, cy + 0.55)
end
-- lower side columns: spare magazines (left of screen = +x) and a cable spool (screen right)
for i = 0, 2 do
	local x = 4.0 + i * 0.5
	outline("Outline", x, 406.6, 0.42, 1.45, -6)
	part(pb, "Magazine", Vector3.new(0.3, 1.25, 0.24), CFrame.new(x, 406.6, tz) * CFrame.Angles(0, 0, math.rad(-6)), DARK, M.Metal)
	part(pb, "MagBase", Vector3.new(0.38, 0.12, 0.3), CFrame.new(x + 0.06, 405.98, tz) * CFrame.Angles(0, 0, math.rad(-6)), OLIVE_D, M.SmoothPlastic)
	peg(x - 0.05, 407.35)
end
do
	local cx, cy = -4.4, 406.7
	outline("Outline", cx, cy, 1.6, 1.6, 0)
	cyl(pb, "SpoolFlange", Vector3.new(cx, cy, tz - 0.22), Vector3.new(cx, cy, tz - 0.16), 1.45, OLIVE_D, M.SmoothPlastic)
	cyl(pb, "SpoolFlange", Vector3.new(cx, cy, tz + 0.12), Vector3.new(cx, cy, tz + 0.18), 1.45, OLIVE_D, M.SmoothPlastic)
	cyl(pb, "SpoolWire", Vector3.new(cx, cy, tz - 0.16), Vector3.new(cx, cy, tz + 0.12), 1.1, C(180, 120, 60), M.SmoothPlastic)
	cyl(pb, "SpoolHub", Vector3.new(cx, cy, tz - 0.26), Vector3.new(cx, cy, tz - 0.22), 0.35, STEEL, M.Metal)
end
-- board label under the frame
stencil(pb, "BoardLabel", Vector3.new(3.4, 0.36, 0.02), CFrame.new(0, 412.72, PZ - 0.135),
	{"TOOL BOARD  02  -  RETURN AFTER USE"}, CREAM_T)
-- strip lamp over the board (its light: Pendant2)
local lamp = Instance.new("Folder"); lamp.Name = "StripLamp"; lamp.Parent = root
box(lamp, "Housing", -4.8, 4.8, 413.05, 413.5, WZ - 1.0, WZ - 0.3, NEAR_BLACK, M.Metal)
part(lamp, "HousingChamfer", Vector3.new(9.6, 0.32, 0.32), CFrame.new(0, 413.5, WZ - 1.0) * CFrame.Angles(math.rad(45), 0, 0), NEAR_BLACK, M.Metal)
box(lamp, "Diffuser", -4.6, 4.6, 413.0, 413.05, WZ - 0.92, WZ - 0.38, WARM_LIGHT, M.Neon, {shadow = false})
for _, x in ipairs({-3.8, 3.8}) do
	box(lamp, "Arm", x - 0.1, x + 0.1, 413.15, 413.4, WZ - 0.3, WZ, DARK, M.Metal)
	cyl(lamp, "Hanger", Vector3.new(x, 413.5, WZ - 0.6), Vector3.new(x, 416.3, WZ - 0.6), 0.06, STEEL, M.Metal)
end
cyl(lamp, "Feed", Vector3.new(0, 413.5, WZ - 0.5), Vector3.new(0, 416.3, WZ - 0.5), 0.1, DARK, M.SmoothPlastic)
say("pegboard: slotted board, olive frame, 2 wrenches, 3 drivers, log clipboard, ear defenders, 3 magazines, spool; strip lamp")

---------------------------------------------------------------------------------------------------
-- 3. window onto the sky (screen left, high: above the left list panel)
---------------------------------------------------------------------------------------------------
local win = Instance.new("Folder"); win.Name = "Window"; win.Parent = root
local X0, X1, Y0, Y1 = 7.9, 13.1, 408.6, 413.8
local FZ0 = WZ - 0.5 -- frame front
-- sky panel, flush with the wall face inside the frame: gradient, clouds, a distant platform
do
	local sky = box(win, "Sky", X0, X1, Y0, Y1, WZ - 0.03, WZ - 0.01, C(170, 200, 230), M.SmoothPlastic, {shadow = false})
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.LightInfluence = 0; g.Brightness = 1.15
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60; g.Parent = sky
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BorderSizePixel = 0; bg.BackgroundColor3 = Color3.new(1, 1, 1); bg.Parent = g
	local gr = Instance.new("UIGradient"); gr.Rotation = 90
	gr.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C(120, 168, 214)), ColorSequenceKeypoint.new(0.65, C(182, 210, 232)),
		ColorSequenceKeypoint.new(1, C(226, 232, 230))}); gr.Parent = bg
	local function blob(x, y, w, h, tr)
		local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = C(250, 250, 246); f.BackgroundTransparency = tr
		f.Position = UDim2.fromScale(x, y); f.Size = UDim2.fromScale(w, h); f.Parent = bg
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f
	end
	blob(-0.1, 0.72, 0.6, 0.16, 0.1); blob(0.25, 0.66, 0.4, 0.14, 0.15); blob(0.55, 0.76, 0.6, 0.14, 0.1)
	blob(0.6, 0.3, 0.35, 0.07, 0.45); blob(0.05, 0.22, 0.3, 0.06, 0.55)
	-- a distant floating platform with a mast (the base's sister pad), soft blue-grey
	local plat = Instance.new("Frame"); plat.BorderSizePixel = 0; plat.BackgroundColor3 = C(118, 132, 146); plat.BackgroundTransparency = 0.15
	plat.Position = UDim2.fromScale(0.58, 0.6); plat.Size = UDim2.fromScale(0.26, 0.035); plat.Parent = bg
	local under = Instance.new("Frame"); under.BorderSizePixel = 0; under.BackgroundColor3 = C(128, 142, 154); under.BackgroundTransparency = 0.2
	under.Position = UDim2.fromScale(0.63, 0.633); under.Size = UDim2.fromScale(0.16, 0.04); under.Parent = bg
	local mast = Instance.new("Frame"); mast.BorderSizePixel = 0; mast.BackgroundColor3 = C(118, 132, 146); mast.BackgroundTransparency = 0.15
	mast.Position = UDim2.fromScale(0.67, 0.52); mast.Size = UDim2.fromScale(0.012, 0.08); mast.Parent = bg
end
-- reveals (depth), frame with chamfered inner corners, mullions, glass, sill
box(win, "RevealT", X0, X1, Y1 - 0.12, Y1, FZ0, WZ - 0.03, WARM_GREY_D, M.SmoothPlastic)
box(win, "RevealB", X0, X1, Y0, Y0 + 0.12, FZ0, WZ - 0.03, WARM_GREY_D, M.SmoothPlastic)
box(win, "RevealL", X0, X0 + 0.12, Y0, Y1, FZ0, WZ - 0.03, WARM_GREY_D, M.SmoothPlastic)
box(win, "RevealR", X1 - 0.12, X1, Y0, Y1, FZ0, WZ - 0.03, WARM_GREY_D, M.SmoothPlastic)
local FW = 0.42
box(win, "FrameT", X0 - FW, X1 + FW, Y1, Y1 + FW, FZ0 - 0.08, WZ, DARK, M.Metal)
box(win, "FrameB", X0 - FW, X1 + FW, Y0 - FW, Y0, FZ0 - 0.08, WZ, DARK, M.Metal)
box(win, "FrameL", X0 - FW, X0, Y0, Y1, FZ0 - 0.08, WZ, DARK, M.Metal)
box(win, "FrameR", X1, X1 + FW, Y0, Y1, FZ0 - 0.08, WZ, DARK, M.Metal)
for _, cx in ipairs({X0, X1}) do for _, cy in ipairs({Y0, Y1}) do
	part(win, "CornerChamfer", Vector3.new(0.7, 0.7, 0.4), CFrame.new(cx, cy, FZ0 + 0.12) * CFrame.Angles(0, 0, math.rad(45)), DARK, M.Metal)
end end
local mx, my = (X0 + X1) / 2, (Y0 + Y1) / 2
box(win, "MullionV", mx - 0.07, mx + 0.07, Y0, Y1, WZ - 0.32, WZ - 0.05, DARK, M.Metal)
box(win, "MullionH", X0, X1, my - 0.07, my + 0.07, WZ - 0.32, WZ - 0.05, DARK, M.Metal)
box(win, "Glass", X0 + 0.12, X1 - 0.12, Y0 + 0.12, Y1 - 0.12, WZ - 0.2, WZ - 0.17, C(200, 222, 236), M.Glass, {t = 0.82, shadow = false})
box(win, "Sill", X0 - 0.6, X1 + 0.6, Y0 - FW - 0.22, Y0 - FW, WZ - 0.85, WZ, CREAM, M.SmoothPlastic)
part(win, "SillChamfer", Vector3.new(X1 - X0 + 1.2, 0.16, 0.16), CFrame.new(mx, Y0 - FW, WZ - 0.85) * CFrame.Angles(math.rad(45), 0, 0), CREAM, M.SmoothPlastic)
stencil(win, "WinPlate", Vector3.new(2.4, 0.3, 0.02), CFrame.new(mx, Y0 - FW - 0.45, WZ - 0.015), {"OBS PORT 2  -  ALT 4,000 FT"}, OLIVE_DD)
say("window: sky panel (gradient, clouds, distant platform), chamfered dark frame, mullions, glass, cream sill")

---------------------------------------------------------------------------------------------------
-- 4. louvred vent (screen right, high) with its duct up to the cable tray
---------------------------------------------------------------------------------------------------
local vent = Instance.new("Folder"); vent.Name = "Vent"; vent.Parent = root
local V0, V1, VY0, VY1 = -12.6, -8.2, 411.6, 414.2
box(vent, "Back", V0, V1, VY0, VY1, WZ - 0.06, WZ, NEAR_BLACK, M.SmoothPlastic)
box(vent, "FrameT", V0 - 0.3, V1 + 0.3, VY1, VY1 + 0.3, WZ - 0.4, WZ, WARM_GREY_D, M.Metal)
box(vent, "FrameB", V0 - 0.3, V1 + 0.3, VY0 - 0.3, VY0, WZ - 0.4, WZ, WARM_GREY_D, M.Metal)
box(vent, "FrameL", V1, V1 + 0.3, VY0, VY1, WZ - 0.4, WZ, WARM_GREY_D, M.Metal)
box(vent, "FrameR", V0 - 0.3, V0, VY0, VY1, WZ - 0.4, WZ, WARM_GREY_D, M.Metal)
for i = 0, 5 do
	local y = VY0 + 0.25 + i * 0.42
	part(vent, "Slat", Vector3.new(V1 - V0, 0.4, 0.06), CFrame.new((V0 + V1) / 2, y, WZ - 0.2) * CFrame.Angles(math.rad(-40), 0, 0), STEEL, M.Metal)
end
box(vent, "Duct", -11.3, -9.5, VY1 + 0.3, 416.3, WZ - 0.7, WZ, WARM_GREY, M.Metal)
for _, y in ipairs({415.0, 415.9}) do
	box(vent, "DuctBand", -11.38, -9.42, y, y + 0.12, WZ - 0.76, WZ, WARM_GREY_D, M.Metal)
end
stencil(vent, "VentText", Vector3.new(4.0, 0.32, 0.02), CFrame.new((V0 + V1) / 2, VY0 - 0.6, WZ - 0.015), {"VENT 3B   -   AIRFLOW  ^"}, OLIVE_DD)
say("vent: dark frame, 6 chamfered steel slats, duct to the tray, stencil")

---------------------------------------------------------------------------------------------------
-- 5. shelving rack (screen right) with kit: ammo cans, hard case, radio, helmet, spare boxes; LED under the top shelf
---------------------------------------------------------------------------------------------------
local rk = Instance.new("Model"); rk.Name = "Rack"; rk.Parent = root
local RX0, RX1, RZ0, RZ1 = -14.4, -8.6, 18.4, 20.8
for _, x in ipairs({RX0 + 0.11, RX1 - 0.11}) do for _, z in ipairs({RZ0 + 0.11, RZ1 - 0.11}) do
	box(rk, "Upright", x - 0.11, x + 0.11, FL, 410.9, z - 0.11, z + 0.11, DARK, M.Metal)
end end
local SH = {402.9, 406.1, 409.3}
for _, y in ipairs(SH) do
	box(rk, "Shelf", RX0, RX1, y, y + 0.14, RZ0, RZ1, WARM_GREY_D, M.Metal)
	box(rk, "Lip", RX0, RX1, y - 0.06, y + 0.2, RZ0 - 0.06, RZ0, OLIVE, M.SmoothPlastic)
end
box(rk, "TopCap", RX0 - 0.05, RX1 + 0.05, 410.9, 411.04, RZ0 - 0.05, RZ1, DARK, M.Metal)
-- floor: two ammo cans
for i, x in ipairs({-13.1, -10.9}) do
	crate(rk, "AmmoCan", CFrame.new(x, FL + 0.55, 19.4), Vector3.new(1.8, 1.1, 1.0), OLIVE_D, OLIVE_DD, {i == 1 and "5.56" or "7.62"})
	box(rk, "Handle", x - 0.4, x + 0.4, FL + 1.1, FL + 1.24, 19.3, 19.5, DARK, M.Metal)
end
-- shelf 1: a hard case and an optics box
do
	local y = SH[1] + 0.14
	local m = crate(rk, "HardCase", CFrame.new(-12.4, y + 0.42, 19.6), Vector3.new(2.6, 0.84, 1.5), DARK, C(54, 56, 50))
	for _, dx in ipairs({-0.7, 0.7}) do box(m, "Latch", -12.4 + dx - 0.12, -12.4 + dx + 0.12, y + 0.42, y + 0.68, 18.8, 18.85, STEEL, M.Metal) end
	crate(rk, "OpticsBox", CFrame.new(-9.9, y + 0.5, 19.5), Vector3.new(1.6, 1.0, 1.2), CREAM, WARM_GREY, {"OPTICS"}, OLIVE_DD)
end
-- shelf 2: radio, helmet
do
	local y = SH[2] + 0.14
	box(rk, "Radio", -13.6, -12.3, y, y + 1.45, 19.2, 20.0, SAGE_D, M.SmoothPlastic)
	box(rk, "RadioFace", -13.5, -12.4, y + 0.15, y + 1.3, 19.15, 19.2, DARK, M.SmoothPlastic)
	for k, dy in ipairs({0.95, 0.55}) do
		cyl(rk, "Knob", Vector3.new(-13.2 + (k - 1) * 0.5, y + dy, 19.15), Vector3.new(-13.2 + (k - 1) * 0.5, y + dy, 19.0), 0.22, STEEL, M.Metal)
	end
	box(rk, "RadioScreen", -13.35, -12.55, y + 1.0, y + 1.2, 19.12, 19.15, OLIVE, M.Neon, {shadow = false})
	cyl(rk, "Antenna", Vector3.new(-12.5, y + 1.45, 19.6), Vector3.new(-12.4, y + 2.9, 19.6), 0.06, DARK, M.SmoothPlastic)
	-- helmet: a flattened dome on a short dark stand, with a brim band
	box(rk, "HelmetStand", -10.4, -9.9, y, y + 0.35, 19.3, 19.8, DARK, M.SmoothPlastic)
	part(rk, "Helmet", Vector3.new(1.55, 1.2, 1.75), CFrame.new(-10.15, y + 0.95, 19.55), OLIVE_D, M.SmoothPlastic, {shape = Enum.PartType.Ball})
	part(rk, "HelmetBrim", Vector3.new(0.14, 1.6, 1.8), CFrame.new(-10.15, y + 0.55, 19.55) * CFrame.Angles(0, 0, math.rad(90)), OLIVE_DD, M.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	box(rk, "HelmetStrap", -10.25, -10.05, y + 0.05, y + 0.6, 18.8, 18.9, DARK, M.SmoothPlastic)
end
-- shelf 3: stacked spare boxes and a cable spool
do
	local y = SH[3] + 0.14
	crate(rk, "SpareBox", CFrame.new(-13.0, y + 0.45, 19.6), Vector3.new(2.0, 0.9, 1.4), CREAM, WARM_GREY, {"SPARES"}, OLIVE_DD)
	crate(rk, "SpareBox", CFrame.new(-12.9, y + 1.2, 19.6) * CFrame.Angles(0, math.rad(-6), 0), Vector3.new(1.6, 0.6, 1.2), SAGE, SAGE_D, {"FILTERS"}, OLIVE_DD)
	cyl(rk, "SpoolBig", Vector3.new(-10.4, y + 0.6, 19.0), Vector3.new(-10.4, y + 0.6, 20.0), 1.2, DARK, M.SmoothPlastic)
	cyl(rk, "SpoolCore", Vector3.new(-10.4, y + 0.6, 18.95), Vector3.new(-10.4, y + 0.6, 19.0), 0.4, OLIVE, M.SmoothPlastic)
end
-- warm LED strip under shelf 3 (its light: Pendant4) and under shelf 2
box(rk, "LED", RX0 + 0.3, RX1 - 0.3, SH[3] - 0.04, SH[3], RZ0 + 0.15, RZ0 + 0.35, WARM_LIGHT, M.Neon, {shadow = false})
stencil(rk, "RackTag", Vector3.new(1.4, 0.2, 0.02), CFrame.new(-11.5, SH[2] + 0.07, RZ0 - 0.07), {"RACK B-2"}, NEAR_BLACK)
say("rack: 3 shelves, olive lips, ammo cans, hard case, optics box, radio, helmet, spare boxes, spool, LED strip")

---------------------------------------------------------------------------------------------------
-- 6. crates on the floor: a stack on screen left under the window (the work light on top), an ammo crate on screen right
---------------------------------------------------------------------------------------------------
local cr = Instance.new("Folder"); cr.Name = "Crates"; cr.Parent = root
crate(cr, "SupplyCrate", CFrame.new(9.0, FL + 1.5, 16.2) * CFrame.Angles(0, math.rad(-8), 0), Vector3.new(4.2, 3.0, 3.0), OLIVE, OLIVE_D,
	{"TAC-04", "SUPPLY"}, CREAM_T)
crate(cr, "AmmoCrate", CFrame.new(8.6, FL + 3.0 + 0.9, 16.0) * CFrame.Angles(0, math.rad(6), 0), Vector3.new(3.0, 1.8, 2.2), SAGE_D, OLIVE_DD,
	{"7.62 x 51"}, CREAM_T)
crate(cr, "SmallCase", CFrame.new(7.9, FL + 4.8 + 0.4, 15.6) * CFrame.Angles(0, math.rad(-14), 0), Vector3.new(1.6, 0.8, 1.1), DARK, C(54, 56, 50))
-- hazard band on the big crate's top edge
do
	local hz = part(cr, "HazardTape", Vector3.new(4.0, 0.25, 0.02), CFrame.new(9.0, FL + 2.68, 16.2) * CFrame.Angles(0, math.rad(-8), 0) * CFrame.new(0, 0, -1.535), OLIVE, M.SmoothPlastic, {shadow = false})
	texture(hz, TEX.hazard, 1.2, 0.25, Color3.new(1, 1, 1), 0)
end
crate(cr, "FloorCrate", CFrame.new(-9.3, FL + 1.0, 15.2) * CFrame.Angles(0, math.rad(10), 0), Vector3.new(3.2, 2.0, 2.2), OLIVE_D, OLIVE_DD,
	{"FRAGILE", "OPTICS"}, CREAM_T)
say("crates: supply crate + ammo crate + case (screen left), floor crate (screen right)")

---------------------------------------------------------------------------------------------------
-- 7. the bench: restyled as a maintenance bench (round 1's paint kept in its own attribute), a cutting mat, a desk lamp
--    (screen right, back corner) and a tool tray (screen left, back corner). BenchTop itself is an invisible hook: untouched.
---------------------------------------------------------------------------------------------------
local st = K:FindFirstChild("SR_Stage")
if st then
	setP(st:FindFirstChild("SR_Stage__bench_top"), {Color = C(112, 106, 96), Material = M.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__trim_metal"), {Color = OLIVE_DD, Material = M.Metal})
	setP(st:FindFirstChild("SR_Stage__neon_cream"), {Color = OLIVE, Material = M.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__band_olive"), {Color = DARK, Material = M.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__wall_kick"), {Color = DARK, Material = M.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__dark_metal"), {Color = DARK, Material = M.SmoothPlastic})
end
local bn = Instance.new("Folder"); bn.Name = "Bench"; bn.Parent = root
local TOP = 404.395 -- bench_top mesh top (the fake shadow lies at 404.42..404.44)
do
	-- turned 90 degrees about Y so the Top-face SurfaceGui reads upright from the camera (GUI up = away from the camera)
	local mat = part(bn, "Mat", Vector3.new(5.4, 0.015, 9.8), CFrame.new(0, TOP + 0.0075, 8.7) * CFrame.Angles(0, math.rad(90), 0), C(108, 108, 86), M.SmoothPlastic, {shadow = false})
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Top; g.LightInfluence = 1
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 50; g.Parent = mat
	local fr = Instance.new("Frame"); fr.BackgroundTransparency = 1; fr.Size = UDim2.fromScale(1, 1); fr.Parent = g
	local function line(x, y, w, h, tr)
		local l = Instance.new("Frame"); l.BorderSizePixel = 0; l.BackgroundColor3 = C(52, 56, 44); l.BackgroundTransparency = tr
		l.Position = UDim2.fromScale(x, y); l.Size = UDim2.fromScale(w, h); l.Parent = fr
	end
	for i = 1, 9 do line(i / 10, 0, 0.003, 1, 0.55) end
	for i = 1, 5 do line(0, i / 6, 1, 0.005, 0.55) end
	line(0.02, 0.03, 0.96, 0.012, 0.1); line(0.02, 0.955, 0.96, 0.012, 0.1); line(0.02, 0.03, 0.006, 0.937, 0.1); line(0.974, 0.03, 0.006, 0.937, 0.1)
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.7, 0.07); t.Position = UDim2.fromScale(0.15, 0.06)
	t.Text = "ARMORY  MAINTENANCE   -   BENCH 02   -   NO LIVE ROUNDS"; t.TextScaled = true; t.FontFace = FONT; t.TextColor3 = C(214, 206, 180); t.Parent = fr
end
-- tool tray, screen left back corner: tray, oil bottle, brush, rag
do
	local x0, x1, z0, z1 = 3.7, 5.9, 10.3, 11.7
	box(bn, "TrayBase", x0, x1, TOP, TOP + 0.08, z0, z1, NEAR_BLACK, M.Metal)
	box(bn, "TrayWall", x0, x1, TOP, TOP + 0.36, z0, z0 + 0.08, DARK, M.Metal)
	box(bn, "TrayWall", x0, x1, TOP, TOP + 0.36, z1 - 0.08, z1, DARK, M.Metal)
	box(bn, "TrayWall", x0, x0 + 0.08, TOP, TOP + 0.36, z0, z1, DARK, M.Metal)
	box(bn, "TrayWall", x1 - 0.08, x1, TOP, TOP + 0.36, z0, z1, DARK, M.Metal)
	cyl(bn, "OilBottle", Vector3.new(5.3, TOP + 0.08, 11.1), Vector3.new(5.3, TOP + 0.95, 11.1), 0.42, OLIVE, M.SmoothPlastic)
	cyl(bn, "OilNozzle", Vector3.new(5.3, TOP + 0.95, 11.1), Vector3.new(5.3, TOP + 1.3, 11.1), 0.1, DARK, M.SmoothPlastic)
	part(bn, "Brush", Vector3.new(1.2, 0.1, 0.16), CFrame.new(4.4, TOP + 0.16, 10.8) * CFrame.Angles(0, math.rad(20), 0), C(120, 86, 52), M.Wood)
	part(bn, "Rag", Vector3.new(1.0, 0.05, 0.7), CFrame.new(4.5, TOP + 0.12, 11.35) * CFrame.Angles(0, math.rad(-12), 0), CREAM, M.Fabric)
end
-- desk lamp, screen right back corner: base, two arms, head with a Neon lens (its light: Pendant3)
local LAMP_HEAD = Vector3.new(-4.15, 408.15, 10.15)
do
	local base = Vector3.new(-4.9, TOP, 11.3)
	cyl(bn, "LampBase", base, base + Vector3.new(0, 0.18, 0), 1.0, NEAR_BLACK, M.Metal)
	local elbow = Vector3.new(-5.0, 407.2, 11.9)
	cyl(bn, "LampArm1", base + Vector3.new(0, 0.18, 0), elbow, 0.12, DARK, M.Metal)
	part(bn, "LampJoint", Vector3.new(0.26, 0.26, 0.26), CFrame.new(elbow), OLIVE, M.Metal, {shape = Enum.PartType.Ball})
	local neck = LAMP_HEAD + Vector3.new(-0.3, 0.45, 0.4)
	cyl(bn, "LampArm2", elbow, neck, 0.12, DARK, M.Metal)
	-- head: a short shade pointing down and toward the bench centre
	local dir = (Vector3.new(-2.8, TOP, 9.0) - LAMP_HEAD).Unit
	cyl(bn, "LampShade", LAMP_HEAD - dir * 0.35, LAMP_HEAD + dir * 0.25, 0.85, OLIVE_D, M.SmoothPlastic)
	cyl(bn, "LampCap", LAMP_HEAD - dir * 0.5, LAMP_HEAD - dir * 0.35, 0.45, DARK, M.Metal)
	cyl(bn, "LampLens", LAMP_HEAD + dir * 0.25, LAMP_HEAD + dir * 0.28, 0.7, WARM_LIGHT, M.Neon, {shadow = false})
	-- the lamp cable over the bench's back edge
	cyl(bn, "LampCable", base + Vector3.new(0, 0.05, 0.45), Vector3.new(-4.9, TOP + 0.05, 12.0), 0.08, DARK, M.SmoothPlastic)
end
say("bench: worktop steel grey, dark olive front, olive line; sage cutting mat with grid + stencil; tool tray; desk lamp")

---------------------------------------------------------------------------------------------------
-- 8. light. KeyLight stays the warm key (and the item's LightDirection); the other 5 RoomLights move to visible sources;
--    +2 new tagged RoomLights (WorkLight cool rim on the crate stack, BulkheadLamp warm over the rack).
---------------------------------------------------------------------------------------------------
local key = S.KeyLight:FindFirstChildWhichIsA("SpotLight")
if key then setP(key, {Color = C(255, 228, 194), Brightness = 2.4, Angle = 70}) end
local L = S.Lights
local function relight(name, pos, props)
	local p = L:FindFirstChild(name)
	if not p then return end
	setP(p, {CFrame = CFrame.new(pos)})
	local l = p:FindFirstChildWhichIsA("Light")
	if l then setP(l, props) end
end
-- window daylight: cool, from just inside the window (rim on the crates, the sill, the left cheek)
relight("Pendant1", Vector3.new((X0 + X1) / 2, 411.2, WZ - 0.9), {Color = C(190, 214, 255), Brightness = 1.3, Range = 14})
-- strip lamp over the pegboard: warm
relight("Pendant2", Vector3.new(0, 412.6, WZ - 0.75), {Color = C(255, 216, 168), Brightness = 1.8, Range = 10})
-- desk lamp: warm pool at the bench's back corner
relight("Pendant3", LAMP_HEAD + Vector3.new(0.2, -0.55, -0.3), {Color = C(255, 204, 146), Brightness = 1.1, Range = 7})
-- rack LED: warm white under the top shelf
relight("Pendant4", Vector3.new(-11.5, 408.9, RZ0 + 0.6), {Color = C(255, 234, 206), Brightness = 0.8, Range = 7})
-- fill: dim and slightly cool so the shadows stay readable
relight("Fill", L.Fill and L.Fill.Position or Vector3.new(0, 418, 18), {Color = C(214, 224, 240), Brightness = 0.32})
local lt = Instance.new("Folder"); lt.Name = "Lights"; lt.Parent = root
-- work light: a small LED flood on the crate stack aiming across at the pegboard wall (cool rim)
do
	local pos = Vector3.new(7.6, FL + 5.6 + 0.35, 15.4)
	local aim = Vector3.new(-2, 410, WZ)
	local cf = CFrame.lookAt(pos, aim)
	part(lt, "WorkLightBase", Vector3.new(0.6, 0.12, 0.5), CFrame.new(pos.X, FL + 5.6 + 0.06, pos.Z), DARK, M.Metal)
	part(lt, "WorkLightYoke", Vector3.new(0.08, 0.35, 0.08), CFrame.new(pos.X, FL + 5.6 + 0.2, pos.Z), DARK, M.Metal)
	part(lt, "WorkLightHead", Vector3.new(0.7, 0.5, 0.3), cf, DARK, M.Metal)
	part(lt, "WorkLightLens", Vector3.new(0.58, 0.38, 0.02), cf * CFrame.new(0, 0, -0.16), C(226, 236, 255), M.Neon, {shadow = false})
	roomLight(lt, "WorkLight", cf * CFrame.new(0, 0, -0.3), "SpotLight", {Color = C(210, 226, 255), Brightness = 1.4, Range = 16, Angle = 70, Face = Enum.NormalId.Front})
end
-- bulkhead lamp: caged, on the right cheek above the rack
do
	local pos = Vector3.new(-14.75, 414.6, 17.0)
	cyl(lt, "BulkheadBody", pos + Vector3.new(0.25, 0, 0), pos - Vector3.new(0.25, 0, 0), 0.9, DARK, M.Metal)
	part(lt, "BulkheadGlass", Vector3.new(0.5, 0.6, 0.6), CFrame.new(pos + Vector3.new(0.35, 0, 0)), WARM_LIGHT, M.Neon, {shape = Enum.PartType.Ball, shadow = false})
	for k = 0, 2 do
		local a = math.rad(k * 60)
		part(lt, "Cage", Vector3.new(0.06, 0.72, 0.06), CFrame.new(pos + Vector3.new(0.4, 0, 0)) * CFrame.Angles(a, 0, 0), DARK, M.Metal)
	end
	roomLight(lt, "BulkheadLamp", CFrame.new(pos + Vector3.new(0.9, -0.2, 0)), "PointLight", {Color = C(255, 214, 160), Brightness = 0.8, Range = 10})
end
say("light: KeyLight warm 2.4/70; Pendant1 window cool, Pendant2 strip lamp, Pendant3 desk lamp, Pendant4 rack LED, Fill dim cool; +WorkLight (spot, cool), +BulkheadLamp (warm)")

root.Parent = polish
-- report
local nParts, nLights = 0, 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then nParts += 1 elseif d:IsA("Light") then nLights += 1 end end
say(("Showroom2: %d parts, %d new lights"):format(nParts, nLights))
return table.concat(log, "\n")
