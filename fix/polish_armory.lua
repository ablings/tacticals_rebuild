-- polish_armory.lua : overnight polish, the Armory (weapons vault). Tacticals_rebuild.rbxl ONLY.
-- Identity: a darker gunmetal weapons vault, cool and focused. Cool ~6500K rack and ceiling light, a hard spotlight on
-- the featured weapon, dark metal envelope, perforated (slotted) rack panels with weapons on them, olive racks with a
-- sage glow, military stencils and serial markings. Contrast with the warm cream Shop. No ambient particles.
-- No new Light instances: every new fixture glows with Neon only (the lobby is over its light budget).
-- Idempotent: recolours store the original look in the attribute PolishArmory_Orig (written once); every new
-- instance lives in Workspace.LobbyMap.Polish.Armory (rebuilt each run). Nothing old is deleted or hidden.
-- UNDO: python tools/run_luau.py fix/polish_armory.lua UNDO  (restores originals, removes Polish.Armory).
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local R2 = LM.Rooms2
local AR = LM.Rooms.Armory
local SS = game:GetService("ServerStorage")
local ATTR = "PolishArmory_Orig"
local log = {}
local function say(s) table.insert(log, s) end

---------------------------------------------------------------------------------------------------
-- 1. Recolour table (Rooms2 A_* meshes: every A_* mesh belongs to the Armory alone)
---------------------------------------------------------------------------------------------------
local C = Color3.fromRGB
local M = Enum.Material
-- cool 6500K emissive white for ceiling strips, pier capsules, bench and gun-wall lamps
local COOL_NEON = C(206, 222, 240)
-- sage glow for the rack lamps
local SAGE_NEON = C(150, 178, 122)
local GUN_A = C(74, 79, 86)      -- gunmetal, lighter (piers, frames, door surround)
local GUN_B = C(60, 64, 70)      -- gunmetal wall plates
local GUN_C = C(46, 49, 54)      -- dark kick / backing
local GUN_D = C(34, 36, 40)      -- darkest (beams, gloss ceiling, borders)
local RECOLOUR = {
	-- walls: gunmetal envelope (olive band kept as the accent line)
	{"A_Walls", "A_Walls__wall_plate", {Color = GUN_B, Material = M.Metal, MaterialVariant = "TacMetal"}},
	{"A_Walls", "A_Walls__wall_body",  {Color = C(66, 70, 76)}},
	{"A_Walls", "A_Walls__wall_kick",  {Color = GUN_C}},
	{"A_Walls", "A_Walls__wall_light", {Color = GUN_A}},
	{"A_Walls", "A_Walls__wall_dark",  {Color = C(28, 30, 33)}},
	{"A_Walls", "A_Walls__wall_upper", {Color = C(70, 74, 80)}},
	{"A_Walls", "A_Walls__trim_metal", {Color = C(84, 88, 94)}},
	{"A_Walls", "A_Walls__trim_light", {Color = C(96, 100, 106)}},
	{"A_Piers", "A_Piers__wall_light", {Color = GUN_A}},
	{"A_Piers", "A_Piers__trim_metal", {Color = C(84, 88, 94)}},
	-- ceiling and beams: dark, so the cool strips read as the light source
	{"A_Ceiling", "A_Ceiling__ceiling",       {Color = C(52, 55, 60)}},
	{"A_Ceiling", "A_Ceiling__ceiling_gloss", {Color = C(28, 30, 34)}},
	{"A_Ceiling", "A_Ceiling__trim_metal",    {Color = C(70, 74, 80)}},
	{"A_Beams", "A_Beams__beam_metal",        {Color = GUN_D}},
	{"A_Lights", "A_Lights__dark_metal",      {Color = C(26, 28, 31)}},
	{"A_Lights", "A_Lights__trim_metal",      {Color = C(70, 74, 80)}},
	{"A_Lights", "A_Lights__neon_lamp",       {Color = COOL_NEON}},
	-- floor: cool near-black (was warm brown)
	{"A_Floor", "A_Floor__floor_field",  {Color = C(48, 50, 53)}},
	{"A_Floor", "A_Floor__floor_border", {Color = C(30, 32, 34)}},
	{"A_Floor", "A_Floor__floor_insert", {Color = C(72, 76, 80)}},
	{"A_Floor", "A_Floor__plate_metal",  {Color = C(70, 74, 78)}},
	{"A_Floor", "A_Floor__trim_metal",   {Color = C(84, 88, 94)}},
	-- doorway surround
	{"A_Door", "A_Door__wall_light",  {Color = GUN_A}},
	{"A_Door", "A_Door__trim_metal",  {Color = C(84, 88, 94)}},
	{"A_Door", "A_Door__plate_metal", {Color = C(70, 74, 78)}},
	-- gun wall: dark backing so the weapons and their lamp carry it
	{"A_GunWall", "A_GunWall__wall_light",  {Color = GUN_A}},
	{"A_GunWall", "A_GunWall__wall_plate",  {Color = GUN_C}},
	{"A_GunWall", "A_GunWall__trim_metal",  {Color = C(84, 88, 94)}},
	{"A_GunWall", "A_GunWall__label_cream", {Color = C(44, 48, 52), Material = M.Metal, MaterialVariant = "TacMetal"}},
	{"A_GunWall", "A_GunWall__neon_lamp",   {Color = COOL_NEON}},
	-- supply counter body
	{"A_Supply", "A_Supply__wall_body",  {Color = C(66, 70, 76)}},
	{"A_Supply", "A_Supply__wall_plate", {Color = GUN_B}},
	{"A_Supply", "A_Supply__wall_kick",  {Color = GUN_C}},
	{"A_Supply", "A_Supply__trim_metal", {Color = C(84, 88, 94)}},
	{"A_Supply", "A_Supply__stair",      {Color = C(64, 67, 72)}},
	-- dais: cool plate and border (olive/cream neon rings kept)
	{"A_Dais", "A_Dais__floor_border", {Color = C(30, 32, 34)}},
	{"A_Dais", "A_Dais__disc_plate",   {Color = C(70, 74, 78)}},
	{"A_Dais", "A_Dais__neon_lamp",    {Color = COOL_NEON}},
	-- lamps
	{"A_Benches", "A_Benches__neon_lamp", {Color = COOL_NEON}},
	{"A_Racks", "A_Racks__neon_lamp",     {Color = SAGE_NEON}},
}
-- existing lights: cool 6500K, the dais spot becomes the hard featured key (narrow, bright)
local COOL_LIGHT = C(212, 226, 255)
local LIGHTS = {
	{AR:FindFirstChild("L_BenchA"),  {Color = COOL_LIGHT, Brightness = 0.8}},
	{AR:FindFirstChild("L_BenchB"),  {Color = COOL_LIGHT, Brightness = 0.8}},
	{AR:FindFirstChild("L_Fill"),    {Color = C(150, 166, 192), Brightness = 0.3}},
	{AR:FindFirstChild("L_GunWall"), {Color = COOL_LIGHT, Brightness = 3.0}},
	{AR:FindFirstChild("L_Dais"),    {Color = C(236, 242, 255), Brightness = 9, Angle = 26, Range = 24}},
}
local SPOTS = LM:FindFirstChild("Features") and LM.Features:FindFirstChild("Spotlights")
local SPOT_HOSTS = {SPOTS and SPOTS:FindFirstChild("Spot_ArmoryDais"), SPOTS and SPOTS:FindFirstChild("Spot_GunWall")}

local function enc(t) return HttpService:JSONEncode(t) end
local function c3(t) return C(t[1], t[2], t[3]) end
local function rgb(c) return {math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)} end
local function eachLight(host, fn)
	if not host then return end
	for _, l in ipairs(host:GetDescendants()) do if l:IsA("Light") then fn(l) end end
end
local function lightOrig(l)
	local o = {Color = rgb(l.Color), Brightness = l.Brightness, Range = l.Range}
	if l:IsA("SpotLight") or l:IsA("SurfaceLight") then o.Angle = l.Angle end
	return o
end
local function restore(p)
	local s = p:GetAttribute(ATTR); if not s then return false end
	local o = HttpService:JSONDecode(s)
	for k, v in pairs(o) do
		if k == "Color" then p.Color = c3(v)
		elseif k == "Material" then p.Material = M[v]
		else p[k] = v end
	end
	p:SetAttribute(ATTR, nil); return true
end

---------------------------------------------------------------------------------------------------
-- UNDO
---------------------------------------------------------------------------------------------------
local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n = 0
	for _, r in ipairs(RECOLOUR) do
		local m = R2:FindFirstChild(r[1]); local p = m and m:FindFirstChild(r[2], true)
		if p and restore(p) then n += 1 end
	end
	for _, e in ipairs(LIGHTS) do eachLight(e[1], function(l) if restore(l) then n += 1 end end) end
	for _, h in ipairs(SPOT_HOSTS) do eachLight(h, function(l) if restore(l) then n += 1 end end) end
	if polish and polish:FindFirstChild("Armory") then polish.Armory:Destroy() end
	if polish and #polish:GetChildren() == 0 then polish:Destroy() end
	return "UNDO polish_armory: restored " .. n .. " originals, removed Polish.Armory"
end

---------------------------------------------------------------------------------------------------
-- APPLY recolours + lights
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
		if not l:GetAttribute(ATTR) then l:SetAttribute(ATTR, enc(lightOrig(l))) end
		for k, v in pairs(e[2]) do
			if k ~= "Angle" or l:IsA("SpotLight") then l[k] = v end
		end
		nL += 1
	end)
end
for _, h in ipairs(SPOT_HOSTS) do
	eachLight(h, function(l)
		if not l:GetAttribute(ATTR) then l:SetAttribute(ATTR, enc(lightOrig(l))) end
		l.Color = COOL_LIGHT; nL += 1
	end)
end
say(("recoloured %d meshes, retuned %d lights"):format(nRe, nL))

---------------------------------------------------------------------------------------------------
-- Measuring (merged kit meshes are CanQuery off: switch on, restore after)
---------------------------------------------------------------------------------------------------
local qOn = {}
for _, d in ipairs(R2:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Name:sub(1, 2) == "A_" then d.CanQuery = true; table.insert(qOn, d) end
end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {R2}
local function ray(o, d) return workspace:Raycast(o, d, rp) end
local floorAt = function(x, z) local h = ray(Vector3.new(x, 2, z), Vector3.new(0, -4, 0)); return h and h.Position.Y or 0.0 end

-- side wall scan at the bay height: wall plane = the most common hit; anything proud of it by > 0.2 is a pier/capsule
local BAY_Y0, BAY_Y1 = 10.35, 15.05
local function scanSide(sign)
	-- a z is free when the three heights hit flat wall (spread <= 0.35, no lamp): capsule lights and piers break it.
	-- Each run of free z becomes a span; its face is the most proud hit in the run (panels never sink into the wall).
	local spans, cur = {}, nil
	for z = -68.75, -110.75, -0.25 do
		local xs, lamp = {}, false
		for _, y in ipairs({BAY_Y0 + 0.15, (BAY_Y0 + BAY_Y1) / 2, BAY_Y1 - 0.15}) do
			local h = ray(Vector3.new(sign * 18, y, z), Vector3.new(sign * 16, 0, 0))
			if h then
				table.insert(xs, math.abs(h.Position.X))
				if h.Instance.Name:find("neon") then lamp = true end
			end
		end
		local free = (#xs == 3) and not lamp and (math.max(xs[1], xs[2], xs[3]) - math.min(xs[1], xs[2], xs[3]) <= 0.35)
			and math.min(xs[1], xs[2], xs[3]) > 28.5
		if free then
			local f = math.min(xs[1], xs[2], xs[3])
			if not cur then cur = {z1 = z, z0 = z, face = f} else cur.z0 = z; cur.face = math.min(cur.face, f) end
		elseif cur then table.insert(spans, cur); cur = nil end
	end
	if cur then table.insert(spans, cur) end
	return spans
end

---------------------------------------------------------------------------------------------------
-- Build helpers
---------------------------------------------------------------------------------------------------
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Armory") then polish.Armory:Destroy() end
local root = Instance.new("Folder"); root.Name = "Armory"
root:SetAttribute("PolishPass", "polish_armory.lua")

local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent or root; return m end
local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanTouch = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = o.collide == true; p.CanQuery = o.collide == true
	p.CastShadow = o.shadow == true
	if o.shape then p.Shape = o.shape end
	if o.variant then p.MaterialVariant = o.variant end
	if not p.CanCollide then p:SetAttribute("NotCover", true) end
	p.Parent = parent
	return p
end
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function label(p, face, lines, opts)
	opts = opts or {}
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.pps or 60; g.LightInfluence = opts.light or 1; g.Parent = p
	g:SetAttribute("PolishArmory", true)
	for _, ln in ipairs(lines) do
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(ln.w or 1, ln.h)
		t.Position = UDim2.fromScale(ln.x or 0, ln.y or 0); t.Text = ln.text; t.TextScaled = true
		t.FontFace = ln.mono and FONT_MONO or FONT; t.TextColor3 = ln.color or C(10, 12, 10)
		t.TextTransparency = ln.tt or 0
		t.TextXAlignment = ln.align or Enum.TextXAlignment.Center; t.Parent = g
		if ln.bg then t.BackgroundTransparency = 0; t.BackgroundColor3 = ln.bg; t.BorderSizePixel = 0 end
	end
	return g
end

-- palette
local CREAM = C(236, 232, 218)
local OLIVE, OLIVE_D, SAGE = C(138, 156, 74), C(107, 122, 58), C(167, 173, 152)
local NEAR_BLACK = C(10, 12, 10)
local SLOT_TEX = "rbxassetid://119843963596060"   -- own TX_grate_alpha (slotted bars, alpha holes)

---------------------------------------------------------------------------------------------------
-- 2. Weapon bays on both side walls: slotted gunmetal rack panels in the free wall between the piers
--    (above the olive band), olive frame, cool Neon hood strip on top, sage Neon underglow, two long
--    guns on pegs per bay, a cream stencil plate with rack number and serial.
---------------------------------------------------------------------------------------------------
local W = AR:FindFirstChild("WeaponsDisplay")
local GUNS = {"Display_AutoRifle", "Display_SemiAuto", "Display_Sniper"}
-- (the sniper only goes in bays wide enough for it: placeGun scales every gun to the bay)
local function placeGun(name, parent, centre, R, n, maxLen)
	local src = W and W:FindFirstChild(name); if not src then return nil end
	local m = src:Clone(); m.Name = "Gun_" .. name:gsub("Display_", "")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = (d.Material == M.Glass) and 0.2 or 0
			d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
		end
	end
	local _, sz0 = m:GetBoundingBox()
	m:ScaleTo(math.min(1.45, maxLen / math.max(sz0.X, sz0.Y, sz0.Z)))
	local cf, sz = m:GetBoundingBox()
	-- the bbox frame: X = barrel axis (longest), Y = thin side, Z = gun height (guns lie on their side)
	local axes = {{cf.RightVector, sz.X}, {cf.UpVector, sz.Y}, {-cf.LookVector, sz.Z}}
	table.sort(axes, function(a, b) return a[2] > b[2] end)
	local long, tall, thin = axes[1], axes[2], axes[3]
	local rel = CFrame.fromMatrix(cf.Position, long[1], thin[1], long[1]:Cross(thin[1])):ToObjectSpace(m:GetPivot())
	local up = R:Cross(n)
	local target = CFrame.fromMatrix(centre + n * (thin[2] / 2 + 0.12), R, n, R:Cross(n))
	m:PivotTo(target * rel)
	-- upright: magazine and grip hang below the receiver; flip about the barrel axis if not
	local mag, rec = m:FindFirstChild("Mag", true) or m:FindFirstChild("Handle", true), m:FindFirstChild("Receiver", true)
	if mag and rec and mag.Position.Y > rec.Position.Y then
		m:PivotTo(CFrame.new(target.Position) * CFrame.fromAxisAngle(R, math.pi) * (target - target.Position) * rel)
	end
	m.Parent = parent
	return m, long[2], tall[2]
end

local bays = grp("WeaponBays")
local nBay = 0
for si, sign in ipairs({-1, 1}) do
	local spans = scanSide(sign)
	for _, sp in ipairs(spans) do say(("  side %d span z %.2f..%.2f face %.2f"):format(sign, sp.z0, sp.z1, sp.face)) end
	local n = Vector3.new(-sign, 0, 0)
	local idx = 0
	for _, s in ipairs(spans) do
		local len = s.z1 - s.z0
		if len >= 4.6 then
			idx += 1; nBay += 1
			local w = math.min(len - 0.5, 10)
			local wall = sign * s.face
			local zc = (s.z0 + s.z1) / 2
			local h = BAY_Y1 - BAY_Y0
			local yc = (BAY_Y0 + BAY_Y1) / 2
			local face = wall + (-sign) * 0.06
			local look = CFrame.lookAt(Vector3.new(face, yc, zc), Vector3.new(face, yc, zc) + n)
			local R = look.RightVector
			local m = grp(("Bay%s%02d"):format(sign < 0 and "W" or "E", idx), bays)
			local function at(dx, dy, dz) return look * CFrame.new(dx, dy, -dz) end
			-- backing (near-black) + slotted face (Texture bars over a dark base)
			part(m, "Backing", Vector3.new(w, h, 0.1), at(0, 0, 0.05), C(18, 20, 22), M.Metal)
			local pnl = part(m, "SlotPanel", Vector3.new(w - 0.5, h - 0.5, 0.06), at(0, 0, 0.13), C(16, 18, 20), M.Metal, {variant = "TacMetal"})
			local tx = Instance.new("Texture"); tx.Face = Enum.NormalId.Front; tx.Texture = SLOT_TEX
			tx.StudsPerTileU = 0.9; tx.StudsPerTileV = 0.9; tx.Color3 = C(112, 118, 126); tx.Parent = pnl
			-- olive frame
			part(m, "FrameT", Vector3.new(w, 0.25, 0.22), at(0, h / 2 - 0.125, 0.17), OLIVE_D, M.Metal)
			part(m, "FrameB", Vector3.new(w, 0.25, 0.22), at(0, -h / 2 + 0.125, 0.17), OLIVE_D, M.Metal)
			part(m, "FrameL", Vector3.new(0.25, h - 0.5, 0.22), at(-w / 2 + 0.125, 0, 0.17), OLIVE_D, M.Metal)
			part(m, "FrameR", Vector3.new(0.25, h - 0.5, 0.22), at(w / 2 - 0.125, 0, 0.17), OLIVE_D, M.Metal)
			-- hood: near-black housing over the top with a cool Neon strip facing down
			part(m, "Hood", Vector3.new(w - 0.3, 0.22, 0.75), at(0, h / 2 - 0.05, 0.55), C(20, 22, 24), M.Metal)
			part(m, "HoodStrip", Vector3.new(w - 0.6, 0.05, 0.4), at(0, h / 2 - 0.18, 0.6), COOL_NEON, M.Neon)
			-- sage underglow along the bottom frame
			part(m, "Underglow", Vector3.new(w - 0.6, 0.06, 0.06), at(0, -h / 2 + 0.26, 0.29), SAGE_NEON, M.Neon)
			-- two long guns on pegs
			for gi, gy in ipairs({1.05, -0.75}) do
				local gname = GUNS[((nBay + gi) % #GUNS) + 1]
				local centre = (look * CFrame.new(0, gy, -0.16)).Position
				local g, glen = placeGun(gname, m, centre, R, n, w - 0.7)
				if g then
					for _, px in ipairs({-glen * 0.28, glen * 0.28}) do
						part(m, "Peg", Vector3.new(0.09, 0.09, 0.42), at(px, gy - 0.42, 0.37), C(120, 126, 134), M.Metal)
					end
				end
			end
			-- stencil plate, bottom left: rack number + serial
			local plate = part(m, "Stencil", Vector3.new(2.3, 0.62, 0.04), at(-w / 2 + 1.55, -h / 2 + 0.75, 0.2), CREAM, M.SmoothPlastic)
			label(plate, Enum.NormalId.Front, {
				{text = ("RACK %s-%02d"):format(sign < 0 and "W" or "E", idx), x = 0.05, y = 0.04, w = 0.9, h = 0.52, align = Enum.TextXAlignment.Left},
				{text = ("SN 4471-TAC-%03d"):format(100 + nBay * 7), x = 0.05, y = 0.58, w = 0.9, h = 0.36, mono = true, color = C(60, 66, 40), align = Enum.TextXAlignment.Left},
			}, {pps = 100})
		end
	end
end
say("weapon bays: " .. nBay)

---------------------------------------------------------------------------------------------------
-- 3. Floor stencils: bay name at the entrance, a safety line at the gun-wall hazard strip
---------------------------------------------------------------------------------------------------
local function floorText(name, pos, dir, size, lines)
	-- thin part flat on the floor, Front face up; the text top points along dir
	local right = dir:Cross(-Vector3.yAxis)
	local p = part(root, name, size, CFrame.fromMatrix(pos, right, dir, -Vector3.yAxis), C(40, 42, 45), M.SmoothPlastic)
	p.Transparency = 1
	label(p, Enum.NormalId.Front, lines, {pps = 40})
	return p
end
local fy = floorAt(0, -84.2)
-- players walk in heading -Z: text top points -Z
floorText("Stencil_Bay", Vector3.new(0, fy + 0.03, -84.2), Vector3.new(0, 0, -1), Vector3.new(11, 2.2, 0.05), {
	{text = "WEAPONS BAY  S-2", y = 0.0, h = 0.62, color = CREAM, tt = 0.25},
	{text = "AUTHORISED PERSONNEL ONLY", y = 0.66, h = 0.32, color = SAGE, tt = 0.3, mono = true},
})
local hz = floorAt(-6, -103.6)
floorText("Stencil_Clear", Vector3.new(-6.2, hz + 0.03, -103.6), Vector3.new(0, 0, -1), Vector3.new(14, 0.9, 0.05), {
	{text = "CLEAR ALL WEAPONS  ·  NO LIVE ROUNDS PAST THIS LINE", y = 0.05, h = 0.9, color = CREAM, tt = 0.3, mono = true},
})

---------------------------------------------------------------------------------------------------
-- 4. Ammo stock with serial stencils (east wall by the entrance, a free corner)
---------------------------------------------------------------------------------------------------
local function kit(name, folder, pos, yaw, parent)
	local src = SS:FindFirstChild(folder) and SS[folder]:FindFirstChild(name)
	if not src then say("WARN no kit " .. folder .. "." .. name); return nil end
	local m = src:Clone()
	local cf, sz = m:GetBoundingBox()
	local rel = cf:ToObjectSpace(m:GetPivot())
	m:PivotTo(CFrame.new(pos.X, pos.Y + sz.Y / 2, pos.Z) * CFrame.Angles(0, math.rad(yaw), 0) * rel)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanTouch = false; d.CastShadow = true end
	end
	m.Parent = parent
	return m, sz
end
local function serial(parent, cf, w, h, top, bottom)
	local p = part(parent, "Serial", Vector3.new(w, h, 0.03), cf, CREAM, M.SmoothPlastic)
	p.Transparency = 1
	label(p, Enum.NormalId.Front, {
		{text = top, y = 0.02, h = 0.55, color = CREAM},
		{text = bottom, y = 0.6, h = 0.36, color = CREAM, mono = true},
	}, {pps = 90})
	return p
end
do
	local m = grp("AmmoStock")
	local x, z = 26.6, -76.6
	local y0 = floorAt(x, z) + 0.01
	local big, bs = kit("F_Crate4A", "FeaturesKit", Vector3.new(x, y0, z), 90, m)
	local top = y0 + (bs and bs.Y or 4.1)
	kit("Prop_CrateS", "PropKit", Vector3.new(x + 0.1, top, z + 0.2), 86, m)
	kit("Prop_AmmoCase", "PropKit", Vector3.new(x - 2.8, y0, z - 3.0), 0, m)
	kit("Prop_AmmoCase", "PropKit", Vector3.new(x - 2.8, y0 + 1.2, z - 3.0), 4, m)
	-- stencils on the faces toward the room (-X)
	local fx = x - (bs and bs.Z or 4.2) / 2 - 0.03
	serial(m, CFrame.lookAt(Vector3.new(fx, y0 + 2.6, z), Vector3.new(fx - 1, y0 + 2.6, z)), 3.2, 1.2, "7.62 NATO", "LOT 0419 · 840 RDS")
end

---------------------------------------------------------------------------------------------------
root.Parent = polish
for _, d in ipairs(qOn) do d.CanQuery = false end
local n = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
say(("Polish.Armory: %d parts, %d new lights"):format(n, nl))
return table.concat(log, "\n")
