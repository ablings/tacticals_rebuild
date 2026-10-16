-- polish_duels2.lua : Duels taste tweaks from notes/review_duels.md (overnight pass). Tacticals_rebuild.rbxl ONLY.
-- RE-RUN ORDER: fix/polish_duels.lua -> fix/polish_duels2.lua (polish_duels rebuilds Polish.Duels, which drops Round2 and the
-- touched Polish parts: run this again after it). UNDO this one first, then polish_duels UNDO.
-- 1. Brightness ladder (pads lead): team frames brightest, cream lane lines down to ~170 rendered, aisle chevrons and the
--    old pad dashes (D_Pads__label_cream) lower again. Values picked by measurement (tools/part_pixels.py).
-- 2. Team B olive frames shifted toward olive (they rendered lime under the lamps; G/R measured).
-- 3. Mode plates 1.5x and readable from the aisle: 1v1 / 2v2 plates hang lower at the pad's aisle edge (z +-9.8, above the
--    head line and above the Play PadBoard as seen from the aisle); 3v3 plates stand on top of their cross gantry (their
--    PadBoard sits in front of the gantry, so lower would put the plate behind it).
-- 4. ARENA DECK board: only the title and STEP ON A PLATE TO QUEUE, both large enough to read from the door.
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishDuels2_Orig; new parts in
-- Workspace.LobbyMap.Polish.Duels.Round2. Nothing new collides, no lights.
-- UNDO: python tools/run_luau.py fix/polish_duels2.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local PD = LM.Polish:FindFirstChild("Duels")
assert(PD, "run fix/polish_duels.lua first")
local ATTR = "PolishDuels2_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(...) local t = {} for _, v in ipairs({...}) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

-- tuned by measurement (see notes/polish_duels.md round 2)
local LANE = C(103, 101, 94)
local OLIVE_FRAME = C(94, 99, 46)
local CHEV = C(150, 140, 122)

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "CFrame" then return {t = "f", v = {v:GetComponents()}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "f" then return CFrame.new(table.unpack(o.v))
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

-- the places this script touches
local roots = {PD, LM.Features.Wayfinding, LM.Rooms3.D_Pads}
if UNDO then
	local n = 0
	for _, r in ipairs(roots) do
		for _, d in ipairs(r:GetDescendants()) do
			local s = d:GetAttribute(ATTR)
			if s then
				for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
				d:SetAttribute(ATTR, nil); n += 1
			end
		end
	end
	if PD:FindFirstChild("Round2") then PD.Round2:Destroy() end
	local bg = PD:FindFirstChild("BriefingBoard") and PD.BriefingBoard:FindFirstChild("Round2Gui")
	if bg then bg:Destroy() end
	return "UNDO polish_duels2: restored " .. n .. " instances, removed Polish.Duels.Round2"
end

if PD:FindFirstChild("Round2") then PD.Round2:Destroy() end
local R2 = Instance.new("Folder"); R2.Name = "Round2"

local function part(parent, name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local function cyl(parent, name, dia, h, pos, color, mat)
	local p = part(parent, name, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local S = UDim2.fromScale
local function sgui(p, face, ppsd, name)
	local g = Instance.new("SurfaceGui")
	g.Name = name or "SurfaceGui"
	g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppsd or 40
	g.LightInfluence = 0; g.Brightness = 1.2; g.Parent = p
	return g
end
local function text(parent, str, pos, size, color, font)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = pos; l.Size = size; l.BackgroundTransparency = 1
	l.Text = str; l.TextScaled = true; l.TextColor3 = color; l.FontFace = font or OSWALD; l.ZIndex = 3
	l.Parent = parent
	return l
end
local ROD = C(52, 40, 33)
local CREAM, NEAR, DOLIVE = C(236, 232, 218), C(10, 12, 10), C(107, 122, 58)

---------------------------------------------------------------------------------------------------
-- 1 + 2. Brightness ladder and the olive frames
---------------------------------------------------------------------------------------------------
local nLane, nFrame, nChev = 0, 0, 0
for _, p in ipairs(PD.Lanes:GetChildren()) do
	if p:IsA("BasePart") then setP(p, {Color = LANE}); nLane += 1 end
end
for _, pad in ipairs(PD.Pads:GetChildren()) do
	local t2 = pad:FindFirstChild("Team2")
	if t2 then
		for _, p in ipairs(t2:GetChildren()) do
			if p.Name == "Frame" then setP(p, {Color = OLIVE_FRAME}); nFrame += 1 end
		end
	end
end
for _, p in ipairs(LM.Features.Wayfinding:GetDescendants()) do
	-- the aisle chevrons inside the Duels hall only (x < -94)
	if p:IsA("BasePart") and p.Parent.Name == "Chevrons" and p.Position.X < -94 and p.Position.Y > 14 then
		setP(p, {Color = CHEV}); nChev += 1
	end
end
local dash = LM.Rooms3.D_Pads:FindFirstChild("D_Pads__label_cream")
if dash then setP(dash, {Color = CHEV}); nChev += 1 end
say("lanes", nLane, "olive frames", nFrame, "chevrons/dashes", nChev)

---------------------------------------------------------------------------------------------------
-- 3. Mode plates (1.5x): the old plate, stripe and hangers are hidden (their gui too); new ones in Round2
---------------------------------------------------------------------------------------------------
local XB = 33.0
local ZTOP = 31.4 + 1.4 + 0.18
local PW, PH = 7.8, 2.25
local nPlates = 0
for _, pf in ipairs(PD.Pads:GetChildren()) do
	local old = pf:FindFirstChild("ModePlate")
	if old then
		for _, d in ipairs(pf:GetChildren()) do
			if d.Name == "ModePlate" or d.Name == "ModePlateStripe" or d.Name == "Hanger" then
				setP(d, {Transparency = 1})
				for _, g in ipairs(d:GetChildren()) do if g:IsA("SurfaceGui") then setP(g, {Enabled = false}) end end
			end
		end
		local mode = pf.Name:match("Pad_(%w+)_") or "?"
		local side = old.Position.Z > 0 and 1 or -1
		local toAisle = Vector3.new(0, 0, -side)
		local pos, hangTo, posts
		if mode == "3v3" then
			-- stands on top of the cross gantry (z +-35.2), above the PadBoard as seen from the aisle
			pos = Vector3.new(old.Position.X, ZTOP + 0.32 + PH / 2, old.Position.Z)
			posts = true
		else
			-- hangs from the long gantry at the pad's aisle edge, 10.5+ over the floor
			pos = Vector3.new(old.Position.X, 27.6, side * 9.8)
		end
		local cf = CFrame.lookAt(pos, pos + toAisle) * CFrame.Angles(math.rad(posts and -8 or -20), 0, 0)
		local m = Instance.new("Model"); m.Name = pf.Name
		local mp = part(m, "ModePlate", Vector3.new(PW, PH, 0.2), cf, CREAM, M.SmoothPlastic)
		part(m, "ModePlateStripe", Vector3.new(PW, 0.32, 0.22), cf * CFrame.new(0, -PH / 2 + 0.16, 0), DOLIVE, M.SmoothPlastic)
		for _, dx in ipairs({-2.9, 2.9}) do
			if posts then
				local foot = (cf * CFrame.new(dx, -PH / 2, 0)).Position
				part(m, "Post", Vector3.new(0.3, 0.32, 0.3), CFrame.new(foot.X, ZTOP + 0.16, foot.Z), ROD, M.Metal)
			else
				-- the long gantry runs along z, so the two hangers drop from a yoke fixed under the beam
				local top = (cf * CFrame.new(dx, PH / 2, 0)).Position
				local len = (XB - 0.25) - top.Y
				cyl(m, "Hanger", 0.14, len, Vector3.new(top.X, top.Y + len / 2, top.Z), ROD, M.Metal)
			end
		end
		if not posts then
			part(m, "Yoke", Vector3.new(PW - 1.4, 0.25, 0.4), CFrame.new(pos.X, XB - 0.125, (cf * CFrame.new(0, PH / 2, 0)).Position.Z), ROD, M.Metal)
		end
		local id = string.format("%02d", (pf.Name:sub(-1) == "B") and 2 or 1)
		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local g = sgui(mp, face, 50)
			g.Brightness = 1
			text(g, string.upper(mode), S(0.3, 0.44), S(0.44, 0.78), NEAR, OSWALD)
			text(g, "PAD " .. id, S(0.75, 0.44), S(0.4, 0.48), C(60, 62, 56), MONO)
		end
		m.Parent = R2
		nPlates += 1
	end
end
say("mode plates rebuilt:", nPlates)

---------------------------------------------------------------------------------------------------
-- 4. ARENA DECK board: title + one instruction line, sized to read from the door (~45 studs)
---------------------------------------------------------------------------------------------------
local bd = PD:FindFirstChild("BriefingBoard")
if bd then
	for _, g in ipairs(bd:GetChildren()) do
		if g:IsA("SurfaceGui") and g.Face == Enum.NormalId.Front then setP(g, {Enabled = false}) end
	end
	local prev = bd:FindFirstChild("Round2Gui")
	if prev then prev:Destroy() end
	local g = sgui(bd, Enum.NormalId.Front, 40, "Round2Gui")
	text(g, "ARENA DECK", S(0.5, 0.3), S(0.9, 0.46), CREAM, OSWALD)
	text(g, "STEP ON A PLATE TO QUEUE", S(0.5, 0.75), S(0.96, 0.38), C(190, 194, 176), OSWALD)
	g:SetAttribute("PolishDuels2_New", true)
	say("briefing board: front gui replaced")
end

R2.Parent = PD
say("touched", touched)
return table.concat(log, "\n")
