-- polish_duels.lua : Duels polish (overnight pass). Tacticals_rebuild.rbxl ONLY.
-- Identity: a dramatic ARENA DECK. Dark envelope (charcoal walls, near-black floor) so the pads read as lit pools; per-team pads
-- (team A cream / team B olive Neon frames, tinted panel-line insets, a reticle emblem with a stepped glow pool); an overhead
-- lamp per team zone with a light shaft (Beam), hung from a gantry rig spanning the hall (the arena-rig look); mode plates per
-- pad, an ARENA DECK briefing board over the entrance, cream lane lines along the centre aisle. The sky edge (west glass,
-- open skylight) stays.
-- RIVALS method (read-only capture of its pad hallway): near-black aisle, pads brighter than the floor, thin Neon team frames,
-- light logo rings, white mode plates hung overhead. RIVALS lights its pads with surfaces + Neon, not with SpotLights.
-- Lights: no new Light instances. FX.SparkBridgeA/B/SparkGantry (Brightness 0, enabled) switched off (-3 enabled lights);
-- Lights.TargetTop retuned into a tight key on the centre disc.
-- Hooks: nothing under LobbyMap.Duels is touched except the old Holo.Display text colours (Edit-only board, hidden in Play).
-- PadBoards: team colours red/blue -> cream/olive (source backed up in ServerStorage._RebuildRemoved.PolishDuels_PadBoards_Orig).
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishDuels_Orig; new parts in
-- Workspace.LobbyMap.Polish.Duels. Nothing new collides. UNDO: python tools/run_luau.py fix/polish_duels.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local SP = game:GetService("StarterPlayer")
local LM = workspace.LobbyMap
local R3 = LM.Rooms3
local DU = LM.Duels
local ATTR = "PolishDuels_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(...) local t = {} for _, v in ipairs({...}) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

---------------------------------------------------------------------------------------------------
-- typed remember / restore
---------------------------------------------------------------------------------------------------
local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "UDim2" then return {t = "u", v = {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "u" then return UDim2.new(o.v[1], o.v[2], o.v[3], o.v[4])
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
local function hide(inst)
	local list = inst:IsA("BasePart") and {inst} or {}
	for _, d in ipairs(inst:GetDescendants()) do table.insert(list, d) end
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			setP(d, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
		end
	end
end

local polish = LM:FindFirstChild("Polish")
local store = SS:FindFirstChild("_RebuildRemoved")
local padBoards = SP.StarterPlayerScripts:FindFirstChild("PadBoards")

if UNDO then
	local n = 0
	for _, d in ipairs(game:GetDescendants()) do
		local ok, s = pcall(function() return d:GetAttribute(ATTR) end)
		if ok and s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if polish and polish:FindFirstChild("Duels") then polish.Duels:Destroy() end
	local bak = store and store:FindFirstChild("PolishDuels_PadBoards_Orig")
	if bak and padBoards then padBoards.Source = bak.Source; bak:Destroy(); say("PadBoards source restored") end
	say("UNDO polish_duels: restored", n, "instances, removed Polish.Duels")
	return table.concat(log, "\n")
end

if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Duels") then polish.Duels:Destroy() end
local PD = Instance.new("Folder"); PD.Name = "Duels"

---------------------------------------------------------------------------------------------------
-- palette
---------------------------------------------------------------------------------------------------
local CREAM, OLIVE, DOLIVE, NEAR = C(236, 232, 218), C(138, 156, 74), C(107, 122, 58), C(10, 12, 10)
local TEAM = {
	-- olive Neon at 138,156,74 glows lime-white; 90,106,42 renders olive (measured)
	A = {neon = CREAM, panel = C(66, 60, 52), tint = C(132, 128, 116), emblem = CREAM, label = "A"},
	B = {neon = C(90, 106, 42), panel = C(50, 52, 28), tint = C(104, 118, 56), emblem = C(157, 176, 90), label = "B"},
}
local LAMP = C(255, 244, 226)
local RIG = C(60, 36, 26)
local ROD = C(52, 40, 33)

---------------------------------------------------------------------------------------------------
-- 1. Envelope: charcoal walls (Plastic above the kick: sky specular turns dark Concrete/Metal blue), near-black floor,
--    dark-olive bands. The west glass / skylight stay as the sky edge.
---------------------------------------------------------------------------------------------------
local ENV = {
	-- values = neutral charcoal divided by the measured render ratio (60% of the full correction; tools/part_pixels.py on
	-- three views: the dark room rendered blue, B-R +12..+34, because the sky fill dominates dark colours)
	wall_body = {C(68, 53, 47), M.Plastic}, wall_dark = {C(48, 36, 30), M.Plastic}, wall_light = {C(81, 66, 58), M.Plastic},
	wall_upper = {C(62, 46, 38), M.Plastic}, wall_plate = {C(64, 50, 43), M.Concrete}, wall_kick = {C(44, 30, 23), M.Plastic},
	trim_metal = {C(70, 62, 57), M.Plastic}, trim_light = {C(97, 82, 75), M.Plastic}, band_olive = {C(76, 71, 40), M.Concrete},
	beam_metal = {C(56, 42, 35), M.Metal}, ceiling = {C(50, 38, 32), M.Plastic}, ceiling_gloss = {C(40, 31, 26), M.Plastic},
	dark_metal = {C(40, 33, 29), M.Metal}, door_leaf = {C(58, 48, 42), M.Metal},
}
local ENV_FOLDERS = {"D_Walls", "D_Piers", "D_West", "D_Door", "D_Roof", "D_Trusses", "D_Lights", "D_Pass", "D_Pads", "D_Floor"}
local OVERRIDE = {
	-- pad bases a step lighter than the floor (the pads must read brighter than the aisle)
	D_Pads__plate_metal = {C(84, 71, 64), M.Metal}, D_Pads__trim_metal = {C(70, 61, 56), M.Metal},
	D_Pads__wall_light = {C(95, 84, 78), M.Plastic}, D_Pads__dark_metal = {C(44, 36, 31), M.Metal},
	D_Floor__floor_insert = {C(53, 40, 34), M.Plastic}, D_Floor__plate_metal = {C(67, 57, 50), M.Metal},
	D_Floor__trim_metal = {C(66, 54, 47), M.Metal}, D_Floor__dark_metal = {C(36, 30, 26), M.Metal},
	-- wall pill lamps a touch dimmer (lower ambient feel), still the visible source of the wall light
	D_Lights__neon_lamp = {C(157, 146, 134), M.Neon}, D_Lights__trim_metal = {C(66, 58, 54), M.Plastic},
}
local nEnv = 0
for _, fname in ipairs(ENV_FOLDERS) do
	local f = R3:FindFirstChild(fname)
	if f then
		for _, p in ipairs(f:GetChildren()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local spec = OVERRIDE[p.Name] or ENV[p.Name:match("__(.+)$") or ""]
				if spec then setP(p, {Color = spec[1], Material = spec[2]}); nEnv += 1 end
			end
		end
	else say("WARN missing", fname) end
end
for _, s in ipairs(LM.Features.DropPits.FloorSlabs:GetChildren()) do
	if s:IsA("BasePart") then
		-- Plastic: the dark Concrete floor picked up sky specular (B-R +13 after the colour correction)
		setP(s, {Color = s.Name == "Slab_border" and C(36, 23, 16) or C(52, 32, 22), Material = M.Plastic}); nEnv += 1
	end
end
say("envelope meshes recoloured:", nEnv)

-- the shared cream/olive pad-outline meshes cannot be split per team: hidden, rebuilt per team below
for _, n in ipairs({"D_Lines__neon_cream", "D_Lines__neon_olive"}) do
	local p = R3.D_Lines:FindFirstChild(n); if p then hide(p) end
end

---------------------------------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------------------------------
local function part(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true)
	for k, v in pairs(extra or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local function cyl(parent, name, dia, h, pos, color, mat)
	-- vertical cylinder (Part cylinders run along X)
	local p = part(parent, name, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function sgui(p, face, ppsd)
	local g = Instance.new("SurfaceGui")
	g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppsd or 40
	g.LightInfluence = 0; g.Brightness = 1.2; g.Parent = p
	return g
end
local function frame(parent, pos, size, color, tr, round, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = pos; f.Size = size
	f.BackgroundColor3 = color; f.BackgroundTransparency = tr or 0; f.BorderSizePixel = 0; f.ZIndex = z or 1
	if round then
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f
		local a = Instance.new("UIAspectRatioConstraint"); a.AspectRatio = 1; a.Parent = f
	end
	f.Parent = parent
	return f
end
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function text(parent, str, pos, size, color, font, xa, z)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = pos; l.Size = size; l.BackgroundTransparency = 1
	l.Text = str; l.TextScaled = true; l.TextColor3 = color; l.FontFace = font or OSWALD; l.ZIndex = z or 3
	l.TextXAlignment = xa or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end
local S = UDim2.fromScale

-- measuring: visible meshes with CanQuery off (wall lamps, trims) must be hit too: switch on, restored at the end
local qOn = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and d.Position.X < -84 and d.Position.X > -165 then
		d.CanQuery = true; table.insert(qOn, d)
	end
end
-- ray filter: visible old geometry only (not Polish, not the invisible hook parts, not characters)
local skip = {PD, polish}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end
end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
-- the most proud wall face along dir from origin: several heights and lateral offsets, nearest hit wins
local function wallDist(origin, dir, lateral)
	local best
	for _, dy in ipairs({-0.7, 0, 0.7}) do
		for _, dl in ipairs({-0.6, 0, 0.6}) do
			local o = origin + Vector3.new(0, dy, 0) + lateral * dl
			local h = workspace:Raycast(o, dir * 70, rp)
			if h then local d = (h.Position - o):Dot(dir); if not best or d < best then best = d end end
		end
	end
	return best
end

---------------------------------------------------------------------------------------------------
-- 2. Gantry rig (arena lighting rig spanning the open hall). Two long beams along z over the 1v1 / 2v2 pad columns
--    (bottom y 33), two cross beams along x over the 3v3 pads (hung under them, bottom 31.4). Wall brackets at each end.
---------------------------------------------------------------------------------------------------
local rig = Instance.new("Folder"); rig.Name = "Rig"
-- clear of the wall pill lamps (long walls x -128.75 / -117.5 / -106.25 / -96.5; east wall z +-37.5 / +-43.5; west z +-26)
local GX = {-99, -131}
local GZ = {-35.2, 35.2}
local XB, ZB = 33.0, 31.4
local function gantry(name, a, b, bottom, alongZ)
	-- a, b: the two wall-face end points at beam centre height
	local h = 1.4
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	local beam = part(rig, name, Vector3.new(1.1, h, len), cf, RIG, M.Plastic)
	-- lattice look: a lighter top chord and the cream Neon line under the beam (high-contrast line work overhead)
	part(rig, name .. "_Chord", Vector3.new(0.7, 0.18, len - 0.2), cf * CFrame.new(0, h / 2 + 0.09, 0), C(82, 70, 63), M.Metal)
	part(rig, name .. "_Line", Vector3.new(0.28, 0.06, len - 0.6), cf * CFrame.new(0, -h / 2 - 0.03, 0), CREAM, M.Neon)
	for _, e in ipairs({a, b}) do
		local inward = (mid - e).Unit
		part(rig, name .. "_Bracket", Vector3.new(2.0, 2.6, 0.3), CFrame.lookAt(e + inward * 0.17, e + inward * 2), C(58, 46, 40), M.Metal)
	end
	return beam
end
local rigInfo = {}
for i, x in ipairs(GX) do
	local y = XB + 0.7
	local o = Vector3.new(x, y, 0)
	local dN = wallDist(o, Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))
	local dS = wallDist(o, Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
	if dN and dS then
		local a, b = o + Vector3.new(0, 0, -(dS - 0.02)), o + Vector3.new(0, 0, dN - 0.02)
		gantry("GantryX" .. i, a, b, XB, true)
		table.insert(rigInfo, string.format("GantryX%d x %.0f z %.2f..%.2f", i, x, a.Z, b.Z))
	else say("WARN no wall for GantryX", i, dN, dS) end
end
for i, z in ipairs(GZ) do
	local y = ZB + 0.7
	local o = Vector3.new(-114, y, z)
	local dE = wallDist(o, Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
	local dW = wallDist(o, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
	if dE and dW then
		local a, b = o + Vector3.new(-(dW - 0.02), 0, 0), o + Vector3.new(dE - 0.02, 0, 0)
		gantry("GantryZ" .. i, a, b, ZB, false)
		table.insert(rigInfo, string.format("GantryZ%d z %.0f x %.2f..%.2f", i, z, a.X, b.X))
	else say("WARN no wall for GantryZ", i, dE, dW) end
end
say("rig:", table.concat(rigInfo, "; "))
rig.Parent = PD
task.wait()

---------------------------------------------------------------------------------------------------
-- 3. Pads: per team zone a tinted panel-line inset, a Neon frame in the team colour, a reticle emblem with a stepped glow
--    pool (SurfaceGui, LightInfluence 0), an overhead lamp with a light shaft. Per pad a cream mode plate under the rig.
---------------------------------------------------------------------------------------------------
local PANEL_TEX = "rbxassetid://119251552384756" -- TX_overlay_panel_lines (own)
local padsF = Instance.new("Folder"); padsF.Name = "Pads"; padsF.Parent = PD
-- lamp position: on the gantry line nearest the zone centre (1v1 / 2v2 under the x gantries, 3v3 under the z gantries)
local function lampFor(cx, cz)
	for _, x in ipairs(GX) do if math.abs(cx - x) < 1.6 then return Vector3.new(x, 0, cz), XB end end
	for _, z in ipairs(GZ) do if math.abs(cz - z) < 1.6 then return Vector3.new(cx, 0, z), ZB end end
	return Vector3.new(cx, 0, cz), ZB
end
-- fit a pad rectangle to the free area over the plate: rays along the edges, from the centre to edge midpoints and corners
-- at panel and frame height; any edge that touches old geometry (curbs, terminal posts, wall trim) steps in 0.2
local function fitRect(c, half)
	local e = {xp = half, xn = half, zp = half, zn = half}
	local function hit(a, b) return workspace:Raycast(a, b - a, rp) ~= nil or workspace:Raycast(b, a - b, rp) ~= nil end
	for _ = 1, 60 do
		local moved = false
		for _, y in ipairs({c.Y + 0.03, c.Y + 0.11}) do
			local x0, x1, z0, z1 = c.X - e.xn, c.X + e.xp, c.Z - e.zn, c.Z + e.zp
			local function P(x, z) return Vector3.new(x, y, z) end
			local c0 = P(c.X, c.Z)
			local edges = {xp = {P(x1, z0), P(x1, z1)}, xn = {P(x0, z0), P(x0, z1)}, zp = {P(x0, z1), P(x1, z1)}, zn = {P(x0, z0), P(x1, z0)}}
			for k, sg in pairs(edges) do
				if hit(sg[1], sg[2]) or hit(c0, (sg[1] + sg[2]) / 2) then e[k] -= 0.2; moved = true end
			end
			for _, cn in ipairs({{"xp", "zp"}, {"xp", "zn"}, {"xn", "zp"}, {"xn", "zn"}}) do
				local x = cn[1] == "xp" and x1 or x0; local z = cn[2] == "zp" and z1 or z0
				if hit(c0, P(x, z)) then e[cn[1]] -= 0.2; e[cn[2]] -= 0.2; moved = true end
			end
		end
		if not moved then break end
	end
	for k, v in pairs(e) do e[k] = v - 0.05 end
	return e
end
local nZones = 0
for _, pad in ipairs(DU:GetChildren()) do
	if pad:IsA("Model") and pad:GetAttribute("QueueName") then
		local pf = Instance.new("Model"); pf.Name = pad.Name
		local mode = pad:GetAttribute("QueueName")
		local centres = {}
		for _, tn in ipairs({"Team1", "Team2"}) do
			local plate = pad:FindFirstChild(tn .. "Plate")
			if plate then
				local t = TEAM[tn == "Team1" and "A" or "B"]
				local tm = Instance.new("Model"); tm.Name = tn
				local s = plate.Size.X
				local top = plate.Position.Y + plate.Size.Y / 2
				local c = Vector3.new(plate.Position.X, top, plate.Position.Z)
				table.insert(centres, c)
				-- inset panel (0.05 thick, sits on the invisible collide plate top 16.34)
				local r = fitRect(c, s / 2 - 0.35)
				local wx, wz = r.xp + r.xn, r.zp + r.zn
				local pc = Vector3.new(c.X + (r.xp - r.xn) / 2, c.Y, c.Z + (r.zp - r.zn) / 2)
				local w = math.min(wx, wz)
				-- text top points away from the centre aisle, so the emblem reads upright for players walking up from the aisle
				local rot = c.Z < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new()
				local panel = part(tm, "Panel", Vector3.new(wx, 0.05, wz), CFrame.new(pc + Vector3.new(0, 0.025 + 0.01, 0)) * rot, t.panel, M.SmoothPlastic)
				local tx = Instance.new("Texture"); tx.Texture = PANEL_TEX; tx.Face = Enum.NormalId.Top
				tx.StudsPerTileU = wx; tx.StudsPerTileV = wz; tx.Color3 = t.tint; tx.Transparency = 0.35; tx.Parent = panel
				-- Neon frame in the team colour (0.38 wide like RIVALS' pad frames)
				local fy = c.Y + 0.035 + 0.04
				local hx, hz = wx / 2 - 0.19, wz / 2 - 0.19
				for _, e in ipairs({{0, hz, wx, 0.38}, {0, -hz, wx, 0.38}, {hx, 0, 0.38, wz - 0.76}, {-hx, 0, 0.38, wz - 0.76}}) do
					part(tm, "Frame", Vector3.new(e[3], 0.08, e[4]), CFrame.new(pc.X + e[1], fy, pc.Z + e[2]), t.neon, M.Neon)
				end
				c = pc
				-- emblem + glow pool on the panel top
				local g = sgui(panel, Enum.NormalId.Top, 24)
				for k, r in ipairs({0.96, 0.78, 0.6}) do frame(g, S(0.5, 0.5), S(r, r), LAMP, 0.9 - k * 0.0, true, k) end
				frame(g, S(0.5, 0.5), S(0.5, 0.5), t.emblem, 0.05, true, 5)
				frame(g, S(0.5, 0.5), S(0.43, 0.43), t.panel, 0, true, 6)
				for _, tick in ipairs({{0.5, 0.2, 0.035, 0.16}, {0.5, 0.8, 0.035, 0.16}, {0.2, 0.5, 0.16, 0.035}, {0.8, 0.5, 0.16, 0.035}}) do
					frame(g, S(tick[1], tick[2]), S(tick[3], tick[4]), t.emblem, 0.05, false, 7)
				end
				text(g, t.label, S(0.5, 0.5), S(0.22, 0.22), t.emblem, OSWALD, nil, 8)
				-- overhead lamp under the rig + light shaft
				local lp, lb = lampFor(c.X, c.Z)
				local hTop = 31.1
				local rodLen = lb - hTop
				if rodLen > 0.05 then cyl(tm, "Rod", 0.3, rodLen, Vector3.new(lp.X, hTop + rodLen / 2, lp.Z), ROD, M.Metal) end
				cyl(tm, "Housing", 2.1, 1.5, Vector3.new(lp.X, hTop - 0.75, lp.Z), C(42, 28, 22), M.Metal)
				cyl(tm, "Collar", 2.3, 0.22, Vector3.new(lp.X, hTop - 0.2, lp.Z), t.neon, M.SmoothPlastic)
				local lens = cyl(tm, "Lens", 1.7, 0.08, Vector3.new(lp.X, hTop - 1.54, lp.Z), LAMP, M.Neon)
				local a0 = Instance.new("Attachment"); a0.Name = "ShaftTop"; a0.Parent = lens
				a0.WorldCFrame = CFrame.new(lp.X, hTop - 1.6, lp.Z)
				local a1 = Instance.new("Attachment"); a1.Name = "ShaftFoot"; a1.Parent = panel
				a1.WorldCFrame = CFrame.new(c.X, c.Y + 0.1, c.Z)
				local bm = Instance.new("Beam"); bm.Name = "Shaft"
				bm.Attachment0 = a0; bm.Attachment1 = a1; bm.FaceCamera = true; bm.Segments = 1
				bm.Width0 = 1.7; bm.Width1 = w * 0.78; bm.LightEmission = 1; bm.LightInfluence = 0
				bm.Color = ColorSequence.new(LAMP)
				bm.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 0.95)})
				bm.Parent = lens
				tm.Parent = pf
				nZones += 1
			end
		end
		-- mode plate: cream, hung under the rig between the two team lamps, angled 20 deg down, faces the centre aisle
		if #centres == 2 then
			local mid = (centres[1] + centres[2]) / 2
			local lpm, lb = lampFor(mid.X, mid.Z)
			mid = Vector3.new(lpm.X, mid.Y, lpm.Z)
			local along = (centres[2] - centres[1]).Unit
			local toAisle = Vector3.new(0, 0, -math.sign(mid.Z))
			local py = lb - 1.25
			local pos = Vector3.new(mid.X, py, mid.Z)
			local plateW = 5.2
			local cf = CFrame.lookAt(pos, pos + toAisle) * CFrame.Angles(math.rad(-20), 0, 0)
			-- pads along z (1v1 / 2v2) hang across a z-running gantry: one centre hanger; 3v3 plates run along their gantry: two
			local hx = math.abs(along:Dot(toAisle)) > 0.9 and {0} or {-1.9, 1.9}
			local mp = part(pf, "ModePlate", Vector3.new(plateW, 1.5, 0.16), cf, CREAM, M.SmoothPlastic)
			part(pf, "ModePlateStripe", Vector3.new(plateW, 0.22, 0.18), cf * CFrame.new(0, -0.64, 0), DOLIVE, M.SmoothPlastic)
			for _, dx in ipairs(hx) do
				local top = (cf * CFrame.new(dx, 0.75, 0)).Position
				local len = lb - top.Y
				if len > 0.05 then cyl(pf, "Hanger", 0.12, len, Vector3.new(top.X, top.Y + len / 2, top.Z), ROD, M.Metal) end
			end
			for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
				local g = sgui(mp, face, 50)
				g.Brightness = 1
				text(g, string.upper(mode), S(0.3, 0.42), S(0.42, 0.72), NEAR, OSWALD)
				text(g, "PAD " .. string.format("%02d", pad:GetAttribute("BayId") or (pad.Name:sub(-1) == "B" and 2 or 1)), S(0.74, 0.32), S(0.4, 0.34), C(60, 62, 56), MONO)
				text(g, "CREAM v OLIVE", S(0.74, 0.62), S(0.4, 0.22), C(84, 96, 44), MONO)
			end
		end
		pf.Parent = padsF
		task.wait()
	end
end
say("pad zones dressed:", nZones)

---------------------------------------------------------------------------------------------------
-- 4. Briefing board: stands on top of GantryX2 (x -130) facing the door, so players see it as they walk in, and above the
--    eye line from the door to the DECK sign on the west wall. A small EXIT plate hangs under GantryX1 facing into the hall.
---------------------------------------------------------------------------------------------------
do
	local x = GX[2]
	local gTop = XB + 1.4 + 0.18
	local pos = Vector3.new(x, gTop + 0.3 + 1.5, 0)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	local bd = part(PD, "BriefingBoard", Vector3.new(13, 3.0, 0.3), cf, C(20, 22, 20), M.SmoothPlastic)
	part(PD, "BoardTopLine", Vector3.new(13, 0.12, 0.34), cf * CFrame.new(0, 1.44, 0), CREAM, M.Neon)
	part(PD, "BoardBottomLine", Vector3.new(13, 0.12, 0.34), cf * CFrame.new(0, -1.44, 0), C(90, 106, 42), M.Neon)
	for _, dz in ipairs({-4.5, 4.5}) do
		-- two posts from the gantry top chord to the board
		local foot = (cf * CFrame.new(dz, -1.5, 0)).Position
		part(PD, "BoardPost", Vector3.new(0.3, 0.32, 0.3), CFrame.new(foot.X, gTop + 0.16, foot.Z), ROD, M.Metal)
	end
	local g = sgui(bd, Enum.NormalId.Front, 40)
	text(g, "ARENA DECK", S(0.3, 0.42), S(0.5, 0.56), CREAM, OSWALD)
	text(g, "STEP ON A PLATE TO QUEUE  ·  1V1  ·  2V2  ·  3V3", S(0.3, 0.82), S(0.54, 0.16), C(167, 173, 152), MONO)
	frame(g, S(0.6, 0.5), S(0.004, 0.7), C(70, 74, 64), 0, false, 2)
	frame(g, S(0.66, 0.42), S(0.05, 0.3), CREAM, 0, false, 2)
	text(g, "TEAM A", S(0.78, 0.42), S(0.16, 0.3), CREAM, OSWALD, Enum.TextXAlignment.Left)
	frame(g, S(0.66, 0.74), S(0.05, 0.3), C(100, 116, 48), 0, false, 2)
	text(g, "TEAM B", S(0.78, 0.74), S(0.16, 0.3), C(157, 176, 90), OSWALD, Enum.TextXAlignment.Left)
	local gb = sgui(bd, Enum.NormalId.Back, 40)
	text(gb, "ARENA DECK", S(0.5, 0.45), S(0.6, 0.5), CREAM, OSWALD)
	text(gb, "HUB EXIT  ·  EAST DOOR", S(0.5, 0.82), S(0.6, 0.16), C(167, 173, 152), MONO)
	-- exit plate under GantryX1, facing into the hall (-x)
	local ep = Vector3.new(GX[1], XB - 1.0, 0)
	local ecf = CFrame.lookAt(ep, ep + Vector3.new(-1, 0, 0))
	local plate = part(PD, "ExitPlate", Vector3.new(6, 1.4, 0.2), ecf, C(20, 22, 20), M.SmoothPlastic)
	part(PD, "ExitPlateLine", Vector3.new(6, 0.1, 0.24), ecf * CFrame.new(0, -0.65, 0), CREAM, M.Neon)
	for _, dz in ipairs({-2.4, 2.4}) do
		local top = (ecf * CFrame.new(dz, 0.7, 0)).Position
		cyl(PD, "ExitHanger", 0.12, XB - top.Y, Vector3.new(top.X, top.Y + (XB - top.Y) / 2, top.Z), ROD, M.Metal)
	end
	local ge = sgui(plate, Enum.NormalId.Front, 50)
	text(ge, "EXIT  ·  HUB", S(0.5, 0.5), S(0.8, 0.62), CREAM, OSWALD)
end
do
	-- cream lane lines along both edges of the centre aisle (RIVALS' lane-line method; door x -96 -> energy wall)
	local lanes = Instance.new("Folder"); lanes.Name = "Lanes"; lanes.Parent = PD
	local x0, x1 = -97.6, -137.4
	for _, z in ipairs({-7.4, 7.4}) do
		-- sample the floor every 0.25 under the line (both edges); runs of one height become one segment
		local runs, cur = {}, nil
		for x = x0, x1 + 0.001, -0.25 do
			local top = -1e9
			for _, dz in ipairs({-0.15, 0.15}) do
				for _, dx in ipairs({0, -0.25}) do
					local h = workspace:Raycast(Vector3.new(x + dx, 20, z + dz), Vector3.new(0, -10, 0), rp)
					if h then top = math.max(top, h.Position.Y) end
				end
			end
			top = math.floor(top * 100 + 0.5) / 100
			if cur and math.abs(cur.y - top) < 0.005 then cur.b = x - 0.25 else cur = {a = x, b = x - 0.25, y = top}; table.insert(runs, cur) end
		end
		for _, rn in ipairs(runs) do
			local len = rn.a - rn.b
			part(lanes, "Lane", Vector3.new(len, 0.06, 0.3), CFrame.new((rn.a + rn.b) / 2, rn.y + 0.03 + 0.002, z), CREAM, M.Neon)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- 5. Lights (no new instances): b0 spark hosts off, TargetTop -> tight key on the centre disc
---------------------------------------------------------------------------------------------------
local off = 0
for _, n in ipairs({"SparkBridgeA", "SparkBridgeB", "SparkGantry"}) do
	local h = LM.FX:FindFirstChild(n)
	local l = h and h:FindFirstChildWhichIsA("Light")
	if l and l.Enabled and l.Brightness == 0 then setP(l, {Enabled = false}); off += 1 end
end
local tt = LM.Lights:FindFirstChild("TargetTop")
local ttl = tt and tt:FindFirstChildWhichIsA("SpotLight")
if ttl then setP(ttl, {Angle = 30, Brightness = 3, Range = 42, Color = C(255, 244, 226), Shadows = false}) end
say("lights: switched off", off, "zero-brightness hosts; TargetTop retuned:", ttl ~= nil)

---------------------------------------------------------------------------------------------------
-- 6. Team colours in text: old Edit-time Holo.Display counts and the PadBoards script (red/blue -> cream/olive)
---------------------------------------------------------------------------------------------------
for _, pad in ipairs(DU:GetChildren()) do
	local d = pad:FindFirstChild("Holo") and pad.Holo:FindFirstChild("Display")
	local fr = d and d:FindFirstChild("Frame")
	if fr then
		if fr:FindFirstChild("CountA") then setP(fr.CountA, {TextColor3 = CREAM}) end
		if fr:FindFirstChild("CountB") then setP(fr.CountB, {TextColor3 = C(157, 176, 90)}) end
	end
end
if padBoards then
	local src = padBoards.Source
	if src:find("TEAM_A", 1, true) then
		say("PadBoards already patched")
	else
		if not store then store = Instance.new("Folder"); store.Name = "_RebuildRemoved"; store.Parent = SS end
		if not store:FindFirstChild("PolishDuels_PadBoards_Orig") then
			local bak = padBoards:Clone(); bak.Name = "PolishDuels_PadBoards_Orig"; bak.Disabled = true; bak.Parent = store
		end
		local anchor = 'local RED, BLUE, VIOLET = Color3.fromRGB(214, 52, 52), Color3.fromRGB(60, 140, 240), Color3.fromRGB(176, 120, 255)'
		local a, b = src:find(anchor, 1, true)
		if a then
			src = src:sub(1, b) .. '\n-- [PolishDuels] team colours match the floor: team A cream, team B olive\nlocal TEAM_A, TEAM_B = Color3.fromRGB(236, 232, 218), Color3.fromRGB(157, 176, 90)' .. src:sub(b + 1)
			local n
			src, n = src:gsub('team == "A" and RED or BLUE', 'team == "A" and TEAM_A or TEAM_B')
			padBoards.Source = src
			say("PadBoards patched, team colour uses:", n)
		else say("WARN PadBoards anchor line not found: not patched") end
	end
end

for _, d in ipairs(qOn) do d.CanQuery = false end
PD.Parent = polish
local np = 0
for _, d in ipairs(PD:GetDescendants()) do if d:IsA("BasePart") then np += 1 end end
say("Polish.Duels parts:", np, " touched properties sets:", touched)
return table.concat(log, "\n")
