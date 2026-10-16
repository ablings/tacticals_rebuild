-- polish_armory2.lua : Armory round 2 (Edward 23:05: every weapon is a PLACEHOLDER). Tacticals_rebuild.rbxl ONLY.
-- Run AFTER fix/polish_armory.lua (a re-run of polish_armory.lua rebuilds Polish.Armory and drops Round2: re-run this after).
-- 1. Swap-ready weapon slots: every weapon spot is a Model WeaponSlot_<Area>_<n> with an invisible Anchor part (PrimaryPart,
--    Attachment "Mount"), attributes WeaponId / MaxLength / Align, holding one placeholder weapon Model "Weapon" (no welds).
--    Areas: Featured (inside Rooms.Armory.FeaturedScissors, hook name + Spin kept), GunWall (9), RackW/RackE (eye-level
--    pegboard niches that replace the two low rack units per side, 4 each), Bench (2). The config ModuleScript
--    ServerStorage.ArmoryWeaponSlots (slot -> WeaponsDisplay model name) and its Apply() fill the slots; swap = one edit.
-- 2. The weapons baked into merged room meshes are hidden (gun wall guns, bench guns, the rack units); the round-1 high
--    bays lose their guns and become stencilled ammo lockers.
-- 3. Colour: the room read navy (cool lights + cool Neon + the blue sky diffuse). Lights and Neon to neutral, ceiling and
--    upper walls to Plastic, wall/floor colours with the blue pulled out (see the measured ratios in notes/polish_armory.md).
-- 4. Review leftovers: SUPPLY CLERK tag sized in studs and lowered clear of the sign; kelly-green crates to dark olive.
-- Idempotent and UNDO-able: every touched property of an existing instance is stored once (typed JSON) in the attribute
-- PolishArmory2_Orig; new parts live in Workspace.LobbyMap.Polish.Armory.Round2 (+ FeaturedScissors.WeaponSlot_Featured_1).
-- No new Light instances. UNDO: python tools/run_luau.py fix/polish_armory2.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local LM = workspace.LobbyMap
local R2 = LM.Rooms2
local AR = LM.Rooms.Armory
local ATTR = "PolishArmory2_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

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
		elseif d:IsA("Light") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			setP(d, {Enabled = false})
		elseif d:IsA("Decal") or d:IsA("Texture") then
			setP(d, {Transparency = 1})
		end
	end
end

local polish = LM:FindFirstChild("Polish")
local PA = polish and polish:FindFirstChild("Armory")
local FS = AR:FindFirstChild("FeaturedScissors")

if UNDO then
	local n = 0
	for _, d in ipairs(game:GetDescendants()) do
		local ok, s = pcall(function() return d:GetAttribute(ATTR) end)
		if ok and s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if PA and PA:FindFirstChild("Round2") then PA.Round2:Destroy() end
	if FS and FS:FindFirstChild("WeaponSlot_Featured_1") then FS.WeaponSlot_Featured_1:Destroy() end
	local mod = SS:FindFirstChild("ArmoryWeaponSlots"); if mod then mod:Destroy() end
	return "UNDO polish_armory2: restored " .. n .. " instances, removed Round2, the featured slot and the config module"
end
assert(PA, "run fix/polish_armory.lua first")

---------------------------------------------------------------------------------------------------
-- 1. Hide the weapons baked into merged meshes (only meshes that are the weapons alone)
---------------------------------------------------------------------------------------------------
local HIDE = {
	-- gun wall: the 12 baked rifles (bodies, olive furniture, receivers); rails/posts/backing stay
	{"A_GunWall", "A_GunWall__case_dark"}, {"A_GunWall", "A_GunWall__drum_olive"}, {"A_GunWall", "A_GunWall__dark_metal"},
	-- benches: the loose guns on the two tops
	{"A_Benches", "A_Benches__case_dark"},
	-- glass display case by the dais: the two guns on its bed (the magazine/ammo blocks stay). Under the 0.6-stud glass
	-- there is no room for a full-size rifle slot, so the case now shows ammo only (see notes/armory_weapon_slots.md).
	{"A_Displays", "A_Displays__dark_metal"}, {"A_Displays", "A_Displays__drum_olive"},
}
for _, h in ipairs(HIDE) do
	local m = R2:FindFirstChild(h[1]); local p = m and m:FindFirstChild(h[2], true)
	if p then hide(p) else say("WARN missing " .. h[2]) end
end
-- the low rack units (both sides, guns baked in): replaced by the eye-level pegboard niches below
if R2:FindFirstChild("A_Racks") then hide(R2.A_Racks) end
-- round-1 high bays: guns and pegs off, stencil -> ammo locker (the slotted panel reads as a louvred locker front)
local bays = PA:FindFirstChild("WeaponBays")
if bays then
	for _, bay in ipairs(bays:GetChildren()) do
		for _, c in ipairs(bay:GetChildren()) do
			if c.Name:sub(1, 4) == "Gun_" or c.Name == "Peg" then hide(c) end
		end
		local st = bay:FindFirstChild("Stencil")
		local g = st and st:FindFirstChildWhichIsA("SurfaceGui")
		if g then
			local labels = {}
			for _, t in ipairs(g:GetChildren()) do if t:IsA("TextLabel") then table.insert(labels, t) end end
			local side, idx = bay.Name:match("Bay(%a)(%d+)")
			if labels[1] then setP(labels[1], {Text = ("LOCKER %s-%s"):format(side or "?", idx or "0")}) end
			if labels[2] then setP(labels[2], {Text = "AMMO · SEALED"}) end
		end
	end
end
-- featured: the scissors parts hidden inside the hook model (name, pivot and Spin untouched)
if FS then
	for _, d in ipairs(FS:GetDescendants()) do
		if d:IsA("BasePart") and not d:FindFirstAncestor("WeaponSlot_Featured_1") then hide(d) end
	end
end

---------------------------------------------------------------------------------------------------
-- 2. Colour: neutral light, blue pulled out, ceiling / upper walls to Plastic
---------------------------------------------------------------------------------------------------
local NEUTRAL_NEON = C(214, 212, 204)
local function gm(r, g, b) return C(r, g, b) end
local RECOLOUR = {
	-- ceiling + beams + light housings: Plastic, warm-neutral darks
	{"A_Ceiling", "A_Ceiling__ceiling",       {Color = gm(70, 62, 54), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Ceiling", "A_Ceiling__ceiling_gloss", {Color = gm(40, 36, 32), Material = M.Plastic}},
	{"A_Ceiling", "A_Ceiling__trim_metal",    {Color = gm(94, 74, 61), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Beams", "A_Beams__beam_metal",        {Color = gm(56, 41, 33), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Lights", "A_Lights__dark_metal",      {Color = gm(34, 31, 28), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Lights", "A_Lights__trim_metal",      {Color = gm(91, 75, 62), Material = M.Plastic, MaterialVariant = ""}},
	-- upper walls: Plastic, blue pulled out
	{"A_Walls", "A_Walls__wall_upper", {Color = gm(92, 80, 70), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Walls", "A_Walls__wall_light", {Color = gm(90, 82, 72), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Walls", "A_Walls__wall_dark",  {Color = gm(42, 35, 31), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Walls", "A_Walls__trim_light", {Color = gm(118, 100, 87), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Walls", "A_Walls__wall_body",  {Color = gm(91, 77, 67)}},
	{"A_Walls", "A_Walls__trim_metal", {Color = gm(109, 90, 77), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Piers", "A_Piers__trim_metal", {Color = gm(108, 90, 78), Material = M.Plastic, MaterialVariant = ""}},
	{"A_Piers", "A_Piers__wall_light", {Color = gm(95, 81, 70)}},
	-- lower walls keep their metal, blue pulled out
	{"A_Walls", "A_Walls__wall_plate", {Color = gm(84, 73, 64)}},
	{"A_Walls", "A_Walls__wall_kick",  {Color = gm(69, 51, 41)}},
	-- floor
	{"A_Floor", "A_Floor__floor_field",  {Color = gm(66, 52, 43)}},
	{"A_Floor", "A_Floor__floor_border", {Color = gm(43, 33, 26)}},
	{"A_Floor", "A_Floor__floor_insert", {Color = gm(84, 78, 72)}},
	{"A_Floor", "A_Floor__plate_metal",  {Color = gm(84, 77, 68)}},
	{"A_Floor", "A_Floor__trim_metal",   {Color = gm(100, 92, 82)}},
	-- door surround, gun wall, supply counter, dais
	{"A_Door", "A_Door__wall_light",  {Color = gm(93, 82, 72)}},
	{"A_Door", "A_Door__trim_metal",  {Color = gm(108, 90, 77)}},
	{"A_GunWall", "A_GunWall__wall_light",  {Color = gm(92, 82, 72)}},
	{"A_GunWall", "A_GunWall__wall_plate",  {Color = gm(55, 46, 40)}},
	{"A_GunWall", "A_GunWall__trim_metal",  {Color = gm(102, 91, 81)}},
	{"A_GunWall", "A_GunWall__label_cream", {Color = gm(46, 42, 38)}},
	{"A_Supply", "A_Supply__wall_body",  {Color = gm(84, 77, 68)}},
	{"A_Supply", "A_Supply__wall_plate", {Color = gm(78, 72, 64)}},
	{"A_Supply", "A_Supply__wall_kick",  {Color = gm(58, 52, 46)}},
	{"A_Supply", "A_Supply__trim_metal", {Color = gm(100, 92, 82)}},
	{"A_Dais", "A_Dais__floor_border", {Color = gm(44, 34, 27)}},
	{"A_Dais", "A_Dais__disc_plate",   {Color = gm(84, 77, 68)}},
	-- furniture metal (benches, display case, dais, props, supply): same correction, kept a little lighter than the walls
	{"A_Benches", "A_Benches__dark_metal",  {Color = gm(58, 50, 44)}},
	{"A_Benches", "A_Benches__beam_metal",  {Color = gm(80, 68, 60)}},
	{"A_Benches", "A_Benches__trim_light",  {Color = gm(134, 120, 110)}},
	{"A_Benches", "A_Benches__trim_metal",  {Color = gm(122, 106, 94)}},
	{"A_Benches", "A_Benches__plate_metal", {Color = gm(118, 104, 96)}},
	{"A_Displays", "A_Displays__case_dark",  {Color = gm(58, 49, 42)}},
	{"A_Displays", "A_Displays__trim_metal", {Color = gm(122, 106, 94)}},
	{"A_Dais", "A_Dais__trim_metal",  {Color = gm(122, 106, 94)}},
	{"A_Dais", "A_Dais__plate_metal", {Color = gm(122, 106, 94)}},
	{"A_Props", "A_Props__dark_metal", {Color = gm(56, 46, 44)}},
	{"A_Supply", "A_Supply__trim_light", {Color = gm(140, 122, 108)}},
	{"A_Supply", "A_Supply__plate_metal", {Color = gm(122, 106, 94)}},
	-- Neon: neutral and a step down so the dais key and the niche strips stay the brightest things
	{"A_Lights", "A_Lights__neon_lamp",   {Color = NEUTRAL_NEON}},
	{"A_GunWall", "A_GunWall__neon_lamp", {Color = NEUTRAL_NEON}},
	{"A_Benches", "A_Benches__neon_lamp", {Color = NEUTRAL_NEON}},
	{"A_Dais", "A_Dais__neon_lamp",       {Color = C(236, 232, 222)}},
	-- kelly-green crates -> dark olive
	{"A_Props", "A_Props__crate_green",     {Color = C(78, 82, 46)}},
	{"A_Benches", "A_Benches__crate_green", {Color = C(78, 82, 46)}},
	{"A_Supply", "A_Supply__crate_green",   {Color = C(78, 82, 46)}},
}
local nRe = 0
for _, r in ipairs(RECOLOUR) do
	local m = R2:FindFirstChild(r[1]); local p = m and m:FindFirstChild(r[2], true)
	if p then setP(p, r[3]); nRe += 1 else say("WARN missing " .. r[2]) end
end
for _, d in ipairs(PA:GetDescendants()) do
	if d:IsA("BasePart") and not d:FindFirstAncestor("Round2") then
		if d.Name == "F_Crate4A__crate_green" then setP(d, {Color = C(78, 82, 46)}) end
		if d.Name == "HoodStrip" then setP(d, {Color = NEUTRAL_NEON}) end
		if d.Name == "SlotPanel" then
			setP(d, {Color = C(30, 24, 20)})
			local t = d:FindFirstChildWhichIsA("Texture"); if t then setP(t, {Color3 = C(128, 118, 106)}) end
		end
	end
end
-- lights: neutral (no new Light instances)
local LIGHTS = {
	{AR:FindFirstChild("L_BenchA"),  {Color = C(240, 236, 226)}},
	{AR:FindFirstChild("L_BenchB"),  {Color = C(240, 236, 226)}},
	{AR:FindFirstChild("L_Fill"),    {Color = C(196, 186, 170)}},
	{AR:FindFirstChild("L_GunWall"), {Color = C(244, 238, 228)}},
	{AR:FindFirstChild("L_Dais"),    {Color = C(255, 250, 240)}},
}
local SPOTS = LM:FindFirstChild("Features") and LM.Features:FindFirstChild("Spotlights")
for _, n in ipairs({"Spot_ArmoryDais", "Spot_GunWall"}) do
	table.insert(LIGHTS, {SPOTS and SPOTS:FindFirstChild(n), {Color = C(244, 238, 228)}})
end
local nL = 0
for _, e in ipairs(LIGHTS) do
	if e[1] then for _, l in ipairs(e[1]:GetDescendants()) do if l:IsA("Light") then setP(l, e[2]); nL += 1 end end end
end
say(("recoloured %d meshes, %d lights neutral"):format(nRe, nL))

-- SUPPLY CLERK tag: sized in studs (Scale on a BillboardGui = studs), lowered clear of the SUPPLY sign (bottom ~11.1)
local npc = LM.NPCs:FindFirstChild("NPC_Supply")
local tag = npc and npc:FindFirstChild("Tag")
if tag then setP(tag, {Size = UDim2.fromScale(3.6, 0.72), StudsOffset = Vector3.new(0, 2.0, 0)}) end

---------------------------------------------------------------------------------------------------
-- 3. Build: niches + slot anchors (Round2) and the featured slot
---------------------------------------------------------------------------------------------------
if PA:FindFirstChild("Round2") then PA.Round2:Destroy() end
if FS and FS:FindFirstChild("WeaponSlot_Featured_1") then FS.WeaponSlot_Featured_1:Destroy() end
local root = Instance.new("Folder"); root.Name = "Round2"
root:SetAttribute("PolishPass", "polish_armory2.lua")

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.variant then p.MaterialVariant = o.variant end
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function label(p, lines, pps)
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 100; g.Parent = p
	for _, ln in ipairs(lines) do
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(ln.w or 0.9, ln.h)
		t.Position = UDim2.fromScale(ln.x or 0.05, ln.y); t.Text = ln.text; t.TextScaled = true
		t.FontFace = ln.mono and FONT_MONO or FONT; t.TextColor3 = ln.color or C(10, 12, 10)
		t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = g
	end
end

-- a slot: Model + invisible Anchor (PrimaryPart). Anchor frame: RightVector = barrel (muzzle +), UpVector = weapon top,
-- LookVector = out of the mounting surface. Align "Bottom" rests the weapon's lowest point on the anchor (rails, pegs,
-- bench tops); "Centre" puts its centre there (spinning featured display). The weapon sits Gap studs off the surface.
local function slot(parent, name, pos, out, up, maxLen, align, area, gap)
	local m = grp(name, parent)
	local a = Instance.new("Part"); a.Name = "Anchor"; a.Size = Vector3.new(maxLen, 0.1, 0.1)
	a.CFrame = CFrame.fromMatrix(pos, out:Cross(up), up)
	a.Transparency = 1; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false; a.CastShadow = false
	a:SetAttribute("NotCover", true); a.Parent = m
	local at = Instance.new("Attachment"); at.Name = "Mount"; at.Parent = a
	m.PrimaryPart = a
	m:SetAttribute("WeaponId", "")
	m:SetAttribute("MaxLength", maxLen)
	m:SetAttribute("Align", align)
	m:SetAttribute("Gap", gap or 0)
	m:SetAttribute("Area", area)
	return m
end

local CREAM = C(236, 232, 218)
local OLIVE_D = C(107, 122, 58)
local SAGE_NEON = C(150, 178, 122)
local SLOT_TEX = "rbxassetid://119843963596060"   -- own TX_grate_alpha

-- 3a. eye-level pegboard niches in the two former rack bays per side wall (z -80..-88.2, -91..-100: the first bay's
-- pier plinth is 1.1 proud from z -88.4; wall face |x| 30.70; top 6.5 keeps the hood under the band trim)
local niches = grp("Niches", root)
local BAYS = {{-80.0, -88.2}, {-91.0, -100.0}}
local WALL = 30.70
local Y0, Y1 = 0.95, 6.5
for _, sign in ipairs({-1, 1}) do
	local side = sign < 0 and "W" or "E"
	local outN = Vector3.new(-sign, 0, 0)
	local k = 0
	for bi, b in ipairs(BAYS) do
		local zc = (b[1] + b[2]) / 2
		local w = math.abs(b[1] - b[2]) - 0.7
		local h = Y1 - Y0
		local yc = (Y0 + Y1) / 2
		local face = sign * WALL - sign * 0.02
		local look = CFrame.lookAt(Vector3.new(face, yc, zc), Vector3.new(face, yc, zc) + outN)
		local function at(dx, dy, dz) return look * CFrame.new(dx, dy, -dz) end
		local nm = grp(("Niche%s%d"):format(side, bi), niches)
		part(nm, "Backing", Vector3.new(w, h, 0.1), at(0, 0, 0.05), C(16, 15, 14), M.Metal)
		local pnl = part(nm, "Pegboard", Vector3.new(w - 0.5, h - 0.5, 0.06), at(0, 0, 0.13), C(54, 44, 36), M.Plastic)
		local tx = Instance.new("Texture"); tx.Face = Enum.NormalId.Front; tx.Texture = SLOT_TEX
		tx.StudsPerTileU = 0.6; tx.StudsPerTileV = 0.6; tx.Color3 = C(160, 144, 128); tx.Parent = pnl
		-- side cheeks + frame (olive) make it a niche, a near-black hood carries the light strip
		part(nm, "CheekL", Vector3.new(0.3, h, 0.75), at(-w / 2 + 0.15, 0, 0.42), C(40, 37, 34), M.Metal)
		part(nm, "CheekR", Vector3.new(0.3, h, 0.75), at(w / 2 - 0.15, 0, 0.42), C(40, 37, 34), M.Metal)
		part(nm, "FrameT", Vector3.new(w, 0.22, 0.2), at(0, h / 2 - 0.11, 0.2), OLIVE_D, M.Metal)
		part(nm, "Hood", Vector3.new(w, 0.24, 0.95), at(0, h / 2 + 0.08, 0.5), C(24, 22, 20), M.Metal)
		part(nm, "HoodStrip", Vector3.new(w - 0.8, 0.06, 0.55), at(0, h / 2 - 0.07, 0.58), C(236, 232, 222), M.Neon)
		-- base ledge with a sage glow lip and a stencil plate
		part(nm, "Ledge", Vector3.new(w, 0.3, 0.9), at(0, -h / 2 + 0.15, 0.45), C(40, 37, 34), M.Metal)
		part(nm, "LedgeGlow", Vector3.new(w - 0.8, 0.05, 0.05), at(0, -h / 2 + 0.33, 0.86), SAGE_NEON, M.Neon)
		local plate = part(nm, "Stencil", Vector3.new(2.2, 0.26, 0.03), at(-w / 2 + 1.5, -h / 2 + 0.15, 0.915), CREAM, M.SmoothPlastic)
		label(plate, {{text = ("RACK %s-%d  ·  SN 4471-TAC-%03d"):format(side, bi, 200 + bi * 11 + (sign < 0 and 0 or 5)), y = 0.08, h = 0.84, mono = true}}, 120)
		-- two weapon rows; the slot anchor is the rest line (the magazine foot), the two pegs carry the handguard and
		-- stock about 0.8 above it (placeholder rifle at 1.45x)
		for ri, ry in ipairs({-h / 2 + 1.05, 0.55}) do
			k += 1
			local pos = (look * CFrame.new(0, ry, -0.18)).Position
			local s = slot(nm, ("WeaponSlot_Rack%s_%d"):format(side, k), pos, outN, Vector3.yAxis, math.min(w - 1.1, 6.4), "Bottom", "Rack" .. side, 0.06)
			for _, px in ipairs({-1.55, 1.55}) do
				part(s, "Peg", Vector3.new(0.1, 0.1, 0.5), at(px, ry + 0.75, 0.4), C(120, 116, 108), M.Metal)
			end
		end
	end
end

-- 3b. gun wall: 3 rows on the existing rails (tops 2.7 / 6.2 / 9.7, rail front z -111.21) x 3 columns
local gw = grp("GunWallSlots", root)
local gi = 0
for _, ry in ipairs({9.72, 6.22, 2.72}) do
	for _, cx in ipairs({-11.75, -6.25, -0.75}) do
		gi += 1
		slot(gw, "WeaponSlot_GunWall_" .. gi, Vector3.new(cx, ry, -111.21), Vector3.zAxis, Vector3.yAxis, 4.7, "Bottom", "GunWall", 0.1)
	end
end
-- 3c. benches: one weapon standing on its magazine along each bench top (top 3.03), facing the entrance (+z)
local bw = grp("BenchSlots", root)
slot(bw, "WeaponSlot_Bench_1", Vector3.new(12.25, 3.04, -83.55), Vector3.zAxis, Vector3.yAxis, 4.4, "Bottom", "Bench", 0)
slot(bw, "WeaponSlot_Bench_2", Vector3.new(20.25, 3.04, -88.05), Vector3.zAxis, Vector3.yAxis, 4.4, "Bottom", "Bench", 0)
-- 3d. featured: inside the hook model, centred on the dais axis (RoomFX spins and bobs the whole model about its pivot)
if FS then
	local piv = FS:GetPivot().Position
	slot(FS, "WeaponSlot_Featured_1", Vector3.new(piv.X, 3.45, piv.Z), Vector3.zAxis, Vector3.yAxis, 5.9, "Centre", "Featured", 0)
end
root.Parent = PA

---------------------------------------------------------------------------------------------------
-- 4. Config module (ServerStorage.ArmoryWeaponSlots) and Apply()
---------------------------------------------------------------------------------------------------
local MODULE_SRC = [==[
-- ArmoryWeaponSlots: which weapon model sits in each Armory weapon slot (Edward picks the real weapons later).
-- Swap: change the model name next to a slot (or Default), then run in the Studio command bar:
--   require(game.ServerStorage.ArmoryWeaponSlots).Apply()
-- Models are looked up by name in Workspace.LobbyMap.Rooms.Armory.WeaponsDisplay, then ServerStorage.ArmoryWeapons
-- (drop new weapon Models there). Each slot (Model WeaponSlot_<Area>_<n>) has an Anchor part: RightVector = barrel
-- (muzzle +), UpVector = weapon top, LookVector = out of the wall/bench; attributes MaxLength (longest side after fit),
-- Align (Bottom = rest the lowest point on the anchor, Centre = centre on it), Gap (studs off the surface), WeaponId.
-- Apply() clones the model, strips scripts/welds/constraints, anchors it, scales it to MaxLength (max 1.5x), points the
-- muzzle along the anchor (part or attachment named Muzzle/Barrel), hangs the magazine down (Mag/Handle/Grip) and
-- replaces the slot's "Weapon" child. Nothing is welded to the room. Idempotent.
local M = {}

M.Default = "Display_AutoRifle"   -- the neutral placeholder rifle

M.Slots = {
	WeaponSlot_Featured_1 = "Display_AutoRifle",
	WeaponSlot_GunWall_1 = "Display_AutoRifle", WeaponSlot_GunWall_2 = "Display_AutoRifle", WeaponSlot_GunWall_3 = "Display_AutoRifle",
	WeaponSlot_GunWall_4 = "Display_AutoRifle", WeaponSlot_GunWall_5 = "Display_AutoRifle", WeaponSlot_GunWall_6 = "Display_AutoRifle",
	WeaponSlot_GunWall_7 = "Display_AutoRifle", WeaponSlot_GunWall_8 = "Display_AutoRifle", WeaponSlot_GunWall_9 = "Display_AutoRifle",
	WeaponSlot_RackW_1 = "Display_AutoRifle", WeaponSlot_RackW_2 = "Display_AutoRifle", WeaponSlot_RackW_3 = "Display_AutoRifle", WeaponSlot_RackW_4 = "Display_AutoRifle",
	WeaponSlot_RackE_1 = "Display_AutoRifle", WeaponSlot_RackE_2 = "Display_AutoRifle", WeaponSlot_RackE_3 = "Display_AutoRifle", WeaponSlot_RackE_4 = "Display_AutoRifle",
	WeaponSlot_Bench_1 = "Display_AutoRifle", WeaponSlot_Bench_2 = "Display_AutoRifle",
}

M.MaxScale = 1.5

local function source(name)
	local lm = workspace:FindFirstChild("LobbyMap")
	local wd = lm and lm:FindFirstChild("Rooms") and lm.Rooms:FindFirstChild("Armory") and lm.Rooms.Armory:FindFirstChild("WeaponsDisplay")
	local s = wd and wd:FindFirstChild(name)
	if not s then
		local ss = game:GetService("ServerStorage"):FindFirstChild("ArmoryWeapons")
		s = ss and ss:FindFirstChild(name)
	end
	return s
end

function M.FindSlots()
	local list = {}
	for _, d in ipairs(workspace.LobbyMap:GetDescendants()) do
		if d:IsA("Model") and d.Name:match("^WeaponSlot_") and d:FindFirstChild("Anchor") then table.insert(list, d) end
	end
	return list
end

local function named(m, names)
	for _, n in ipairs(names) do
		local f = m:FindFirstChild(n, true)
		if f then return f:IsA("Attachment") and f.WorldPosition or (f:IsA("BasePart") and f.Position) end
	end
end

function M.Fit(slotModel, modelName)
	local anchor = slotModel:FindFirstChild("Anchor")
	local src = source(modelName)
	if not (anchor and src) then return false, "missing " .. (anchor and modelName or "Anchor") end
	local old = slotModel:FindFirstChild("Weapon"); if old then old:Destroy() end
	local w = src:Clone(); w.Name = "Weapon"
	if not w:IsA("Model") then local m = Instance.new("Model"); w.Parent = m; w = m; w.Name = "Weapon" end
	for _, d in ipairs(w:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("WeldConstraint") then d:Destroy()
		elseif d:IsA("BasePart") then
			d.Transparency = (d.Material == Enum.Material.Glass) and 0.2 or 0
			d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
			d:SetAttribute("NotCover", true)
		end
	end
	local _, sz0 = w:GetBoundingBox()
	local maxLen = slotModel:GetAttribute("MaxLength") or 4
	w:ScaleTo(w:GetScale() * math.min(M.MaxScale, maxLen / math.max(sz0.X, sz0.Y, sz0.Z)))
	-- weapon frame from its bounding box: long = barrel, middle = height, shortest = thickness
	local cf, sz = w:GetBoundingBox()
	local axes = {{cf.RightVector, sz.X}, {cf.UpVector, sz.Y}, {cf.LookVector, sz.Z}}
	table.sort(axes, function(a, b) return a[2] > b[2] end)
	local long, tall, thin = axes[1][1], axes[2][1], axes[3]
	local c = cf.Position
	local muzzle = named(w, {"Muzzle", "MuzzleBrake", "Barrel"})
	if muzzle and (muzzle - c):Dot(long) < 0 then long = -long end
	local mag = named(w, {"Mag", "Magazine", "Handle", "Grip"})
	if mag and (mag - c):Dot(tall) > 0 then tall = -tall end
	local gunFrame = CFrame.fromMatrix(c, long, tall)
	local rel = gunFrame:ToObjectSpace(w:GetPivot())
	local a = anchor.CFrame
	local pos = a.Position
	if slotModel:GetAttribute("Align") == "Bottom" then
		-- off the wall/bench by Gap + half the thickness, resting on the anchor line
		pos += a.LookVector * ((slotModel:GetAttribute("Gap") or 0) + thin[2] / 2) + a.UpVector * (axes[2][2] / 2)
	end
	w:PivotTo(CFrame.fromMatrix(pos, a.RightVector, a.UpVector) * rel)
	w:SetAttribute("SourceModel", modelName)
	w.Parent = slotModel
	slotModel:SetAttribute("WeaponId", modelName)
	return true
end

function M.Apply()
	local n, bad = 0, {}
	for _, s in ipairs(M.FindSlots()) do
		local ok, err = M.Fit(s, M.Slots[s.Name] or M.Default)
		if ok then n += 1 else table.insert(bad, s.Name .. ": " .. tostring(err)) end
	end
	return n, bad
end

return M
]==]
local mod = SS:FindFirstChild("ArmoryWeaponSlots")
if not mod then mod = Instance.new("ModuleScript"); mod.Name = "ArmoryWeaponSlots"; mod.Parent = SS end
mod.Source = MODULE_SRC
local cfg = require(mod:Clone())
local nFit, bad = cfg.Apply()
say(("slots filled: %d%s"):format(nFit, #bad > 0 and (" BAD " .. table.concat(bad, "; ")) or ""))

local n = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
say(("Round2: %d parts, %d new lights; %d property records"):format(n, nl, touched))
return table.concat(log, "\n")
