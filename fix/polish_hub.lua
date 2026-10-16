-- polish_hub.lua : the Hub as the COMMAND DECK (overnight polish). Tacticals_rebuild.rbxl ONLY. Run after polish_olive.lua.
-- Identity (notes/overnight_polish.md): the heart of the base. Open, bright, the spawn disc as the hero, warm sun from the
-- skylight, warm-white ceiling strips, concrete panels, olive bands, flag/insignia banners, ops screens, sky views. Olive
-- dominant with cream lines; wayfinding to OUTFITTERS (N), ARMORY (S), DUELS (W) and EXFIL (E) must read from the disc.
-- RIVALS method (its central lobby, read-only captures out/polish/hub/ref_*): the centre disc lit from above, a ring of
-- warm truss spots, every exit marked by a big sign with a Neon accent in that destination's colour and lane lines leading in.
-- 1. Envelope warmed: the hub kit rendered cool (walls B-R +12..+23, measured): every neutral wall/trim/ceiling mesh of
--    Hub1 (+ the LapFix infill) divided by its render ratio at 60% (R x1.14, B x0.89). Floors keep their hub2 compensation.
-- 2. Warm-white lamps: ceiling strips, wall capsules, bridge/catwalk and tunnel lamps (Neon) warm white.
-- 3. Warm sun from the skylight: glass warm-clear, and three soft warm light shafts (Beams, no Light) from the skylight onto
--    the disc. The spawn hologram's tint goes from green-grey to cream.
-- 4. Insignia banners: 8 hanging olive banners (cream border, winged roundel with chevrons, TACTICALS / SKY BASE) on the
--    upper N and S walls between the windows and piers, each on a rod with brackets and a bottom batten.
-- 5. Wayfinding: a Neon bar in the destination room's colour under each gate sign (OUTFITTERS warm cream, ARMORY cool white,
--    EXFIL amber, DUELS cream + olive teams); the floor stencil SHOP reads OUTFITTERS like the sign.
-- Lights: none added (net 0); the hologram PointLight only changes colour. Nothing new collides or is queryable.
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishHub_Orig; new parts in
-- Workspace.LobbyMap.Polish.Hub. Comments on their own line. UNDO: python tools/run_luau.py fix/polish_hub.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local H = LM.Hub1
local ATTR = "PolishHub_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "UDim2" then return {t = "u", v = {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}}
	elseif t == "ColorSequence" then
		local k = {}
		for _, kp in ipairs(v.Keypoints) do table.insert(k, {kp.Time, kp.Value.R, kp.Value.G, kp.Value.B}) end
		return {t = "cs", v = k}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "u" then return UDim2.new(o.v[1], o.v[2], o.v[3], o.v[4])
	elseif o.t == "cs" then
		local k = {}
		for _, kp in ipairs(o.v) do table.insert(k, ColorSequenceKeypoint.new(kp[1], Color3.new(kp[2], kp[3], kp[4]))) end
		return ColorSequence.new(k)
	else return o.v end
end
local touched = 0
local function orig(inst, k)
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	return o[k] and decV(o[k]) or inst[k]
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
	if polish and polish:FindFirstChild("Hub") then polish.Hub:Destroy() end
	return "UNDO polish_hub: restored " .. n .. " instances, removed Polish.Hub"
end
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Hub") then polish.Hub:Destroy() end
local root = Instance.new("Folder"); root.Name = "Hub"
root:SetAttribute("PolishPass", "polish_hub.lua")

local CREAM = C(236, 232, 218)
local NEAR_BLACK = C(10, 12, 10)
local DARK = C(40, 37, 34)
local BANNER = C(138, 130, 60)
local BANNER_DEEP = C(70, 66, 30)
local WARM_LAMP = C(182, 164, 132)
local SUN = C(255, 232, 192)

---------------------------------------------------------------------------------------------------
-- 1. envelope: warm the neutral greys (60% of the measured render-ratio correction)
---------------------------------------------------------------------------------------------------
local WARM = {wall_plate = true, wall_body = true, wall_light = true, wall_dark = true, wall_kick = true, wall_upper = true,
	trim_light = true, trim_metal = true, beam_metal = true, dark_metal = true, door_leaf = true, ceiling = true,
	ceiling_gloss = true, stair = true, plate_metal = true}
local function warm(c) return Color3.new(math.min(c.R * 1.14, 1), c.G, c.B * 0.89) end
local nEnv = 0
for _, d in ipairs(H:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local suf = d.Name:match("__(.+)$")
		local isLap = d.Parent and d.Parent.Name == "LapFix" and d.Name ~= "TunnelThreshold"
		if (suf and WARM[suf]) or isLap then
			setP(d, {Color = warm(orig(d, "Color"))}); nEnv += 1
		end
	end
end
say("envelope warmed: " .. nEnv .. " meshes")

---------------------------------------------------------------------------------------------------
-- 2. warm-white lamps (Neon)
---------------------------------------------------------------------------------------------------
local nLamp = 0
for _, m in ipairs({H.H_CeilLights, H.H_WallLights, H.H_Bridges, H.H_Catwalks, H.H_Tunnel}) do
	local p = m:FindFirstChild(m.Name .. "__neon_lamp")
	if p then setP(p, {Color = WARM_LAMP}); nLamp += 1 end
end
say("lamps warm white: " .. nLamp)

---------------------------------------------------------------------------------------------------
-- 3. sun: warm skylight glass, three light shafts onto the disc, hologram tint cream
---------------------------------------------------------------------------------------------------
setP(H.H_Skylight:FindFirstChild("H_Skylight__glass"), {Color = C(232, 220, 196)})
local sunF = Instance.new("Folder"); sunF.Name = "SunShafts"; sunF.Parent = root
local function carrier(parent, name, pos)
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(0.2, 0.2, 0.2); p.CFrame = CFrame.new(pos)
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Transparency = 1
	p:SetAttribute("NotCover", true); p.Parent = parent
	return p
end
-- the sun is overhead at ClockTime 12 (GetSunDirection ~ +Y): vertical shafts from under the skylight (y 67.4) to the
-- floor round the disc, offset so they never sit on the hologram axis
for i, s in ipairs({{-7, 5, 13}, {8, -4, 15}, {1, 11, 10}}) do
	local top = carrier(sunF, "Shaft" .. i, Vector3.new(s[1], 67.2, s[2]))
	local a0 = Instance.new("Attachment"); a0.Parent = top
	-- parent first: WorldPosition on an unparented attachment is taken as a local offset
	local a1 = Instance.new("Attachment"); a1.Parent = top; a1.WorldPosition = Vector3.new(s[1], 0.8, s[2])
	local b = Instance.new("Beam"); b.Attachment0 = a0; b.Attachment1 = a1
	b.Width0 = s[3]; b.Width1 = s[3] * 1.15; b.FaceCamera = true; b.Segments = 1
	b.Color = ColorSequence.new(SUN); b.LightEmission = 1; b.LightInfluence = 0
	b.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 0.98)})
	b.Parent = top
end
local holo = LM.FX:FindFirstChild("Hologram")
if holo then
	for _, d in ipairs(holo:GetDescendants()) do
		if d:IsA("Decal") then setP(d, {Color3 = CREAM})
		elseif d:IsA("Beam") then setP(d, {Color = ColorSequence.new(C(236, 228, 206))})
		elseif d:IsA("PointLight") then setP(d, {Color = C(240, 230, 210)})
		elseif d:IsA("BasePart") and d.Material == M.Neon then setP(d, {Color = C(150, 146, 120)}) end
	end
end
say("sun: skylight glass warm, 3 shafts, hologram cream")

---------------------------------------------------------------------------------------------------
-- measuring (visible parts queryable while we scan)
---------------------------------------------------------------------------------------------------
local qOn = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and math.abs(d.Position.Z) < 60 and math.abs(d.Position.X) < 100 then
		d.CanQuery = true; table.insert(qOn, d)
	end
end
local skip = {polish}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	if o.shape then p.Shape = o.shape end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local function frame(parent, pos, size, color, rot, round)
	local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = pos; f.Size = size; f.Rotation = rot or 0
	if round then local u = Instance.new("UICorner"); u.CornerRadius = UDim.new(0.5, 0); u.Parent = f end
	f.Parent = parent
	return f
end
local function text(parent, pos, size, t, color)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos; l.Size = size; l.Text = t; l.TextScaled = true; l.FontFace = FONT; l.TextColor3 = color; l.Parent = parent
	return l
end

---------------------------------------------------------------------------------------------------
-- 4. insignia banners (upper N and S walls; wall face ~44.0, a ledge above ~y 53)
---------------------------------------------------------------------------------------------------
local banF = Instance.new("Folder"); banF.Name = "Banners"; banF.Parent = root
local BW, BH = 5, 12.5
local nBan = 0
for _, sgn in ipairs({1, -1}) do
	-- the S wall carries a tilted board at x -46..-36 (y 38-47): its fourth banner hangs at x 10 (free wall x 0..19)
	for _, bx in ipairs(sgn > 0 and {-70, -40, 40, 70} or {-70, 10, 40, 70}) do
		-- find a span where the wall is flat (one plane within 0.15) over the banner rectangle, shifting x if needed
		local best
		for _, dx in ipairs({0, 0.5, -0.5, 1, -1, 1.5, -1.5, 2, -2, 2.5, -2.5, 3, -3}) do
			local x0 = bx + dx
			local zs, ok = {}, true
			for _, y in ipairs({38.5, 41, 44, 47, 50, 52}) do
				for _, xx in ipairs({x0 - BW / 2 - 0.2, x0, x0 + BW / 2 + 0.2}) do
					local h = workspace:Raycast(Vector3.new(xx, y, 30 * sgn), Vector3.new(0, 0, 20 * sgn), rp)
					if not h then ok = false else table.insert(zs, math.abs(h.Position.Z)) end
				end
			end
			if ok then
				local mn, mx = math.huge, -math.huge
				for _, z in ipairs(zs) do mn = math.min(mn, z); mx = math.max(mx, z) end
				if mx - mn < 0.15 then best = {x = x0, face = mn}; break end
			end
		end
		if best then
			-- ledge underside above the banner: first y (going up from 50) where the wall comes out by more than 0.3
			local ledge = 54
			for y = 50, 56, 0.1 do
				local h = workspace:Raycast(Vector3.new(best.x, y, 30 * sgn), Vector3.new(0, 0, 20 * sgn), rp)
				if h and math.abs(h.Position.Z) < best.face - 0.3 then ledge = y; break end
			end
			local topY = math.min(ledge - 0.45, 52.6)
			local zf = (best.face - 0.32) * sgn
			local m = Instance.new("Model"); m.Name = ("Banner_%s_%d"):format(sgn > 0 and "N" or "S", best.x)
			local cy = topY - 0.25 - BH / 2
			local pos = Vector3.new(best.x, cy, zf)
			-- the cloth faces the hall (toward z = 0)
			local cf = CFrame.lookAt(pos, pos - Vector3.new(0, 0, sgn))
			local cloth = part(m, "Cloth", Vector3.new(BW, BH, 0.06), cf, BANNER, M.Fabric)
			-- rod, brackets into the wall, bottom batten
			local rodY = topY - 0.1
			part(m, "Rod", Vector3.new(BW + 0.6, 0.16, 0.16), CFrame.new(best.x, rodY, zf) * CFrame.Angles(0, 0, 0), DARK, M.Metal, {shape = Enum.PartType.Cylinder})
			for _, ex in ipairs({-BW / 2 - 0.15, BW / 2 + 0.15}) do
				part(m, "Bracket", Vector3.new(0.14, 0.14, 0.42), CFrame.new(best.x + ex, rodY, (best.face - 0.2) * sgn), DARK, M.Metal)
			end
			part(m, "Batten", Vector3.new(BW + 0.2, 0.14, 0.14), CFrame.new(best.x, cy - BH / 2 - 0.07, zf) , DARK, M.Metal, {shape = Enum.PartType.Cylinder})
			-- artwork (Scale only): cream border, TACTICALS, winged roundel with three chevrons, stripe, SKY BASE
			local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 40; g.LightInfluence = 1; g.Parent = cloth
			for _, b in ipairs({{UDim2.fromScale(0.5, 0.025), UDim2.fromScale(0.9, 0.012)}, {UDim2.fromScale(0.5, 0.975), UDim2.fromScale(0.9, 0.012)},
				{UDim2.fromScale(0.05, 0.5), UDim2.fromScale(0.024, 0.95)}, {UDim2.fromScale(0.95, 0.5), UDim2.fromScale(0.024, 0.95)}}) do
				frame(g, b[1], b[2], CREAM)
			end
			text(g, UDim2.fromScale(0.5, 0.09), UDim2.fromScale(0.78, 0.07), "TACTICALS", CREAM)
			-- wings (three tapered bars each side) behind the roundel
			for i = 0, 2 do
				local w = 0.4 - i * 0.08
				local yy = 0.33 + i * 0.035
				frame(g, UDim2.fromScale(0.5 - 0.16 - w / 2 + 0.12, yy), UDim2.fromScale(w, 0.014), CREAM)
				frame(g, UDim2.fromScale(0.5 + 0.16 + w / 2 - 0.12, yy), UDim2.fromScale(w, 0.014), CREAM)
			end
			-- roundel: cream disc, deep-olive inner disc (circles in Scale: width as a fraction of the 5 x 12.5 canvas)
			local ring = frame(g, UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.5, 0.2), CREAM, 0, true)
			local inner = frame(ring, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.82, 0.82), BANNER_DEEP, 0, true)
			for i = 0, 2 do
				local cy2 = 0.34 + i * 0.17
				frame(inner, UDim2.fromScale(0.37, cy2), UDim2.fromScale(0.34, 0.07), CREAM, 35)
				frame(inner, UDim2.fromScale(0.63, cy2), UDim2.fromScale(0.34, 0.07), CREAM, -35)
			end
			frame(g, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.8, 0.012), CREAM)
			frame(g, UDim2.fromScale(0.5, 0.645), UDim2.fromScale(0.8, 0.006), CREAM)
			text(g, UDim2.fromScale(0.5, 0.71), UDim2.fromScale(0.7, 0.06), "SKY BASE", CREAM)
			text(g, UDim2.fromScale(0.5, 0.77), UDim2.fromScale(0.5, 0.035), ("DECK %s"):format(sgn > 0 and "NORTH" or "SOUTH"), CREAM)
			-- three cream rank bars near the foot
			for i = 0, 2 do frame(g, UDim2.fromScale(0.5, 0.85 + i * 0.03), UDim2.fromScale(0.36, 0.012), CREAM) end
			m.Parent = banF
			nBan += 1
		else
			say(("WARN no flat wall for banner at x %d sgn %d"):format(bx, sgn))
		end
	end
end
say("banners: " .. nBan)

---------------------------------------------------------------------------------------------------
-- 5. wayfinding: destination-colour Neon bars under the gate signs, floor stencil SHOP -> OUTFITTERS
---------------------------------------------------------------------------------------------------
local wayF = Instance.new("Folder"); wayF.Name = "SignBars"; wayF.Parent = root
local DEST = {
	SignText_SHOP = {C(160, 138, 108)},
	SignText_ARMORY = {C(136, 144, 150)},
	SignText_EXFIL = {C(190, 108, 26)},
	SignText_DUELS = {C(150, 148, 140), C(100, 102, 44)},
}
local nBar = 0
for name, cols in pairs(DEST) do
	local p = H.Overlays:FindFirstChild(name)
	if p then
		local w = p.Size.X * 0.66
		local yb = -p.Size.Y / 2 + 0.26
		-- front face is the part's -Z (its LookVector side); sit 0.03 in front of it
		local zoff = -(p.Size.Z / 2 + 0.035)
		if #cols == 1 then
			part(wayF, "Bar_" .. name, Vector3.new(w, 0.22, 0.05), p.CFrame * CFrame.new(0, yb, zoff), cols[1], M.Neon)
		else
			part(wayF, "Bar_" .. name .. "_A", Vector3.new(w / 2 - 0.1, 0.22, 0.05), p.CFrame * CFrame.new(-w / 4, yb, zoff), cols[1], M.Neon)
			part(wayF, "Bar_" .. name .. "_B", Vector3.new(w / 2 - 0.1, 0.22, 0.05), p.CFrame * CFrame.new(w / 4, yb, zoff), cols[2], M.Neon)
		end
		nBar += 1
	end
end
local st = LM.Features:FindFirstChild("Wayfinding") and LM.Features.Wayfinding:FindFirstChild("Stencil_SHOP")
if st then
	local l = st:FindFirstChildWhichIsA("TextLabel", true)
	if l then setP(l, {Text = "OUTFITTERS"}) end
	setP(st, {Size = Vector3.new(8.4, st.Size.Y, st.Size.Z)})
end
say(("sign bars: %d; floor stencil SHOP -> OUTFITTERS"):format(nBar))

for _, d in ipairs(qOn) do d.CanQuery = false end
root.Parent = polish
say("touched " .. touched)
return table.concat(log, "\n")
