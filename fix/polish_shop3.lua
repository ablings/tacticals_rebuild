-- polish_shop3.lua : Shop round 3 -> UGC / COSMETIC shop (Edward 22:55). Tacticals_rebuild.rbxl ONLY.
-- Run AFTER fix/polish_shop.lua (it builds Polish.Shop; this pass hides its supply dressing and adds Polish.Shop.Round3).
-- If polish_shop.lua is re-run it rebuilds Polish.Shop (Round3 goes with it): re-run this script afterwards.
-- Presented like RIVALS' UGC shop stage + market hall, themed military: outfit walls with camo mannequins (Parts, R15
-- proportions), headgear walls, glass cases of dog tags / patches / insignia, FEATURED + NEW DROPS screens, a spotlit
-- featured-outfit stage on the centre plinth (Spin, RoomFX turns it), the counter kept as checkout, the NPC as outfitter.
-- Hides (never deletes) the supply dressing: ammo, rations, med kits, price boards, crates, guns.
-- Every changed property of an existing instance is stored once in attribute PolishShop3_Orig (JSON), so UNDO restores it.
-- Comments sit on their own lines (a trailing comment once swallowed the rest of a generated line).
-- UNDO: python tools/run_luau.py fix/polish_shop3.lua UNDO   (run it BEFORE polish_shop.lua UNDO)
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap
local R2 = LM.Rooms2
local ATTR = "PolishShop3_Orig"
local C = Color3.fromRGB
local log = {}
local function say(s) table.insert(log, s) end

---------------------------------------------------------------------------------------------------
-- Remember / restore any property set (typed JSON)
---------------------------------------------------------------------------------------------------
local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", v = tostring(v.EnumType), n = v.Name}
	elseif t == "UDim2" then return {t = "u", v = {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "CFrame" then return {t = "f", v = {v:GetComponents()}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.v][o.n]
	elseif o.t == "u" then return UDim2.new(o.v[1], o.v[2], o.v[3], o.v[4])
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "f" then return CFrame.new(table.unpack(o.v))
	else return o.v end
end
-- set props on inst, storing the original value of each prop the first time it is touched
local function setP(inst, props)
	if not inst then return end
	local s = inst:GetAttribute(ATTR)
	local orig = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if k == "__pivot" then
			if orig.__pivot == nil then orig.__pivot = encV(inst:GetPivot()) end
		elseif orig[k] == nil then
			orig[k] = encV(inst[k])
		end
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(orig))
	for k, v in pairs(props) do
		if k == "__pivot" then inst:PivotTo(v) else inst[k] = v end
	end
end
local function restore(inst)
	local s = inst:GetAttribute(ATTR); if not s then return false end
	local orig = HttpService:JSONDecode(s)
	for k, o in pairs(orig) do
		if k == "__pivot" then inst:PivotTo(decV(o)) else pcall(function() inst[k] = decV(o) end) end
	end
	inst:SetAttribute(ATTR, nil); return true
end
-- hide an instance and everything under it (UNDO-able)
local nHidden = 0
local function hideOne(d)
	if d:IsA("BasePart") then
		setP(d, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}); nHidden += 1
	elseif d:IsA("Decal") or d:IsA("Texture") then setP(d, {Transparency = 1})
	elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then setP(d, {Enabled = false})
	elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("ProximityPrompt") then setP(d, {Enabled = false})
	end
end
local function hide(inst)
	if not inst then return end
	hideOne(inst)
	for _, d in ipairs(inst:GetDescendants()) do hideOne(d) end
end

---------------------------------------------------------------------------------------------------
-- UNDO
---------------------------------------------------------------------------------------------------
local polish = LM:FindFirstChild("Polish")
local shopP = polish and polish:FindFirstChild("Shop")
if UNDO then
	local n = 0
	if shopP and shopP:FindFirstChild("Round3") then shopP.Round3:Destroy() end
	for _, d in ipairs(LM:GetDescendants()) do
		if d:GetAttribute(ATTR) and restore(d) then n += 1 end
		-- talk lines are an attribute, stored separately
		local tl = d:GetAttribute(ATTR .. "_TalkLines")
		if tl ~= nil then d:SetAttribute("TalkLines", tl ~= "" and tl or nil); d:SetAttribute(ATTR .. "_TalkLines", nil); n += 1 end
	end
	return "UNDO polish_shop3: restored " .. n .. " instances, removed Polish.Shop.Round3"
end
assert(shopP, "run fix/polish_shop.lua first (Polish.Shop missing)")

---------------------------------------------------------------------------------------------------
-- 1. Hide the supply dressing (rounds 1-2 and the pre-polish Rooms2 / Rooms.Shop props, guns included)
---------------------------------------------------------------------------------------------------
-- counter goods (keep the wood top runs; their four separate edges are replaced by one continuous fascia)
for _, p in ipairs(shopP.Counter:GetChildren()) do
	if not p.Name:match("^WoodTop") then hide(p) end
end
-- wall shelf units: keep the wood carcass, hide the supply goods (refilled with folded camo shirts + caps below)
local GOODS = {Ammo = true, AmmoLid = true, Ration = true, Canteen = true, CanteenCap = true, Uniform = true, MedKit = true, MedBand = true}
for _, n in ipairs({"WallShelfW", "WallShelfE"}) do
	local u = shopP:FindFirstChild(n)
	if u then for _, p in ipairs(u:GetChildren()) do if GOODS[p.Name] then hide(p) end end end
end
for _, n in ipairs({"Boards", "StockClusters", "EntryBins"}) do hide(shopP:FindFirstChild(n)) end
-- pre-polish dressing: pedestals with rifles, the gun rack, crates/drums, the old back-shelf stock, the plinth gun
for _, n in ipairs({"S_Displays", "S_Racks", "S_Props"}) do hide(R2:FindFirstChild(n)) end
for _, n in ipairs({"S_Shelves__crate_green", "S_Shelves__drum_olive", "S_Shelves__case_dark", "S_Shelves__label_cream"}) do
	hide(R2.S_Shelves:FindFirstChild(n, true))
end
-- the plinth's upper drum, gun and column trims go; its low base ring (floor border, Neon ring, metal rim, disc) stays as the stage base
for _, n in ipairs({"S_Plinth__case_dark", "S_Plinth__drum_olive", "S_Plinth__dark_metal", "S_Plinth__trim_metal", "S_Plinth__trim_light", "S_Plinth__neon_cream"}) do
	hide(R2.S_Plinth:FindFirstChild(n, true))
end
for _, m in ipairs(LM.Rooms.Shop:GetChildren()) do
	if m:IsA("Model") and m.Name:match("^K_") then hide(m) end
end
say("hidden parts: " .. nHidden)

---------------------------------------------------------------------------------------------------
-- 2. Taste fixes on existing pieces
---------------------------------------------------------------------------------------------------
local function mesh(model, name) local m = R2:FindFirstChild(model); return m and m:FindFirstChild(name, true) end
-- walls: darker, more yellow cream (read white-cool at distance)
setP(mesh("S_Walls", "S_Walls__wall_body"),  {Color = C(206, 182, 146)})
setP(mesh("S_Walls", "S_Walls__wall_plate"), {Color = C(200, 176, 140)})
setP(mesh("S_Walls", "S_Walls__wall_kick"),  {Color = C(172, 148, 116)})
setP(mesh("S_Walls", "S_Walls__wall_light"), {Color = C(212, 194, 160)})
setP(mesh("S_Piers", "S_Piers__wall_light"), {Color = C(212, 194, 160)})
-- ceiling: warm tan instead of cool grey
setP(mesh("S_Ceiling", "S_Ceiling__ceiling"),       {Color = C(176, 152, 116)})
setP(mesh("S_Ceiling", "S_Ceiling__ceiling_gloss"), {Color = C(112, 90, 64)})
-- the coffer faces players actually see between the strips are the ceiling trim mesh: it rendered 77,77,72 at 92,78,62
-- (sky ambient cancels the warmth: render/colour ~ 0.84, 0.99, 1.16), so it is pushed warm to land on a tan
setP(mesh("S_Ceiling", "S_Ceiling__trim_metal"), {Color = C(132, 100, 68)})
-- back sign: SUPPLY -> OUTFITTERS
local signLabel = R2.Overlays:FindFirstChild("SignText_ShopCounter") and R2.Overlays.SignText_ShopCounter:FindFirstChild("Label", true)
setP(signLabel, {Text = "OUTFITTERS"})
-- pendant shades: near-black shade with a dark-olive cap (read lime before); pools dimmer (light moves onto products)
for _, pm in ipairs(shopP.CounterPendants:GetChildren()) do
	for _, p in ipairs(pm:GetChildren()) do
		if p.Name == "Shade" then setP(p, {Color = C(30, 30, 27), Material = Enum.Material.SmoothPlastic})
		elseif p.Name == "ShadeTop" or p.Name == "Cap" then setP(p, {Color = C(78, 88, 48), Material = Enum.Material.SmoothPlastic}) end
	end
	for _, l in ipairs(pm:GetDescendants()) do if l:IsA("SpotLight") then setP(l, {Brightness = 2.6}) end end
end
-- countertop runs: one darker walnut tone (four runs read as loose planks); a continuous fascia ties them below
for _, p in ipairs(shopP.Counter:GetChildren()) do
	if p.Name:match("^WoodTop") then setP(p, {Color = C(96, 66, 42)}) end
end
-- NPC as outfitter: tag text + a studs-sized tag (Scale = studs on a BillboardGui) lowered under the screens;
-- prompt text and talk lines (OpenPanel unchanged: Edward to confirm Shop vs Kit). Hook instances are not renamed or moved.
local npc = LM.NPCs:FindFirstChild("NPC_Quartermaster")
if npc then
	local tag = npc:FindFirstChild("Tag")
	if tag then
		setP(tag, {Size = UDim2.fromScale(4.2, 0.9), StudsOffset = Vector3.new(0, 2.55, 0)})
		setP(tag:FindFirstChildWhichIsA("TextLabel"), {Text = "OUTFITTER"})
	end
	local pr = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if pr then
		setP(pr, {ObjectText = "OUTFITTER"})
		local tl = pr:GetAttribute("TalkLines")
		if pr:GetAttribute(ATTR .. "_TalkLines") == nil then pr:SetAttribute(ATTR .. "_TalkLines", tl or "") end
		pr:SetAttribute("TalkLines", "New drops land every day. The featured set is on the stage.|Camo, patches, tags. All cosmetic, all yours.|Try the Sky Ranger set. It suits a pilot.")
	end
end
local counterPrompt = LM.Interact:FindFirstChild("Shop_Counter") and LM.Interact.Shop_Counter:FindFirstChildWhichIsA("ProximityPrompt", true)
setP(counterPrompt, {ObjectText = "CHECKOUT", ActionText = "Browse outfits"})
-- counter truss spot: out of the entrance -> OUTFITTERS sightline, re-aimed as the stage rim/back light
local spot = LM.Features:FindFirstChild("Spotlights") and LM.Features.Spotlights:FindFirstChild("Spot_ShopCounter")
local STAGE = Vector3.new(0, 0, 88)
if spot then
	local lens = spot:FindFirstChild("F_TrussSpot__lens_warm", true)
	-- start from the original pivot every run (idempotent)
	local s = spot:GetAttribute(ATTR)
	local pv0 = s and HttpService:JSONDecode(s).__pivot and CFrame.new(table.unpack(HttpService:JSONDecode(s).__pivot.v)) or spot:GetPivot()
	local lensRel = pv0:ToObjectSpace(lens.CFrame)
	local newPos = Vector3.new(7.5, 11.6, 95.0)
	local target = Vector3.new(0, 4.6, 88)
	-- rotate the original pivot so the lens look vector points at the target
	local look0 = (pv0 * lensRel).LookVector
	local want = (target - newPos).Unit
	local axis = look0:Cross(want)
	local rot = CFrame.identity
	if axis.Magnitude > 1e-4 then rot = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(look0:Dot(want), -1, 1))) end
	setP(spot, {__pivot = CFrame.new(newPos) * rot * pv0.Rotation})
	for _, l in ipairs(spot:GetDescendants()) do if l:IsA("SpotLight") then setP(l, {Angle = 34, Brightness = 2.2, Range = 18}) end end
end
-- the old pedestal fill (invisible host, pedestals gone) is replaced by the stage key spot below (net 0 lights)
local lPed = LM.Rooms.Shop:FindFirstChild("L_Pedestals")
if lPed then for _, l in ipairs(lPed:GetDescendants()) do if l:IsA("Light") then setP(l, {Enabled = false}) end end end

---------------------------------------------------------------------------------------------------
-- 3. Build helpers (Round3 folder rebuilt every run)
---------------------------------------------------------------------------------------------------
if shopP:FindFirstChild("Round3") then shopP.Round3:Destroy() end
local root = Instance.new("Folder"); root.Name = "Round3"
root:SetAttribute("PolishPass", "polish_shop3.lua")
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent or root; return m end
local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanTouch = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = o.collide == true; p.CanQuery = o.collide == true
	p.CastShadow = o.shadow == true
	if o.shape then p.Shape = o.shape end
	if o.tr then p.Transparency = o.tr end
	if o.refl then p.Reflectance = o.refl end
	if not p.CanCollide then p:SetAttribute("NotCover", true) end
	p.Parent = parent
	return p
end
local function special(p, mtype, scale)
	local m = Instance.new("SpecialMesh"); m.MeshType = mtype; m.Scale = scale or Vector3.one; m.Parent = p; return m
end
local FONT_B = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_M = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
-- a SurfaceGui with Scale-only children. rows: {text, x, y, w, h, color, bold, align, bg}
local function gui(adornee, face, pps, rows, o)
	o = o or {}
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps; g.LightInfluence = o.light or 1; g.Brightness = o.bright or 1
	g.Adornee = adornee; g.Parent = adornee
	g.ResetOnSpawn = false
	for _, r in ipairs(rows) do
		if r.box then
			local f = Instance.new("Frame"); f.BorderSizePixel = 0
			f.Position = UDim2.fromScale(r.x, r.y); f.Size = UDim2.fromScale(r.w, r.h); f.BackgroundColor3 = r.box
			f.BackgroundTransparency = r.bt or 0; f.Parent = g
		else
			local t = Instance.new("TextLabel"); t.BackgroundTransparency = r.bg and 0 or 1
			if r.bg then t.BackgroundColor3 = r.bg; t.BorderSizePixel = 0 end
			t.Position = UDim2.fromScale(r.x or 0, r.y); t.Size = UDim2.fromScale(r.w or 1, r.h)
			t.Text = r.text; t.TextScaled = true; t.TextColor3 = r.color or C(10, 12, 10)
			t.FontFace = r.bold == false and FONT_M or FONT_B
			t.TextXAlignment = r.align or Enum.TextXAlignment.Center
			t.Parent = g
		end
	end
	return g
end
local function roomLight(host)
	CS:AddTag(host, "RoomLight"); host:SetAttribute("Room", "Shop")
end

-- palette
local OLIVE, OLIVE_D, CREAM, SAGE, NEAR_BLACK = C(138, 156, 74), C(107, 122, 58), C(236, 232, 218), C(167, 173, 152), C(10, 12, 10)
local WARM_GREY = C(200, 196, 186)
local WOOD, WOOD_D = C(116, 80, 50), C(78, 54, 34)
local DUMMY = C(206, 198, 182)
local BOOT = C(28, 26, 24)
local WARM_BULB = C(236, 196, 146)
local METAL_D = C(40, 40, 38)

-- camo palettes: base + blotch colours
local CAMO = {
	woodland = {C(98, 104, 66),  {C(58, 50, 38), C(44, 58, 36), C(132, 124, 88)}},
	desert   = {C(196, 176, 136), {C(156, 126, 90), C(126, 104, 74), C(214, 200, 168)}},
	urban    = {C(142, 142, 138), {C(92, 92, 90), C(58, 58, 56), C(190, 190, 186)}},
	od       = {C(96, 102, 62),  {}},
	snow     = {C(222, 222, 216), {C(170, 172, 168), C(132, 134, 130)}},
	night    = {C(44, 46, 44),   {C(28, 30, 28), C(66, 68, 64)}},
	tiger    = {C(112, 116, 70), {C(36, 36, 28), C(86, 66, 40)}, true},
	sage     = {C(150, 158, 132), {}},
	multi    = {C(150, 140, 104), {C(106, 112, 70), C(96, 74, 50), C(184, 172, 136)}},
}

-- put camo blotches on the four vertical faces of a box part (deterministic)
local function camo(m, p, key, rnd, perFace)
	local pal = CAMO[key]; if not pal or #pal[2] == 0 then return end
	local s = p.Size
	local faces = {
		{Vector3.new(0, 0, -1), s.X, s.Y, s.Z / 2}, {Vector3.new(0, 0, 1), s.X, s.Y, s.Z / 2},
		{Vector3.new(-1, 0, 0), s.Z, s.Y, s.X / 2}, {Vector3.new(1, 0, 0), s.Z, s.Y, s.X / 2},
	}
	for _, f in ipairs(faces) do
		local n = f[1]
		local right = (n.Z ~= 0) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
		for k = 1, perFace do
			local bw = pal[3] and math.min(f[2] - 0.06, rnd:NextNumber(0.5, 0.9)) or rnd:NextNumber(0.28, 0.55) * math.min(1, f[2])
			local bh = pal[3] and rnd:NextNumber(0.08, 0.14) or rnd:NextNumber(0.2, 0.42) * math.min(1, f[3])
			bw = math.min(bw, f[2] - 0.06); bh = math.min(bh, f[3] - 0.06)
			local u = rnd:NextNumber(-(f[2] - bw) / 2 + 0.03, (f[2] - bw) / 2 - 0.03)
			local v = rnd:NextNumber(-(f[3] - bh) / 2 + 0.03, (f[3] - bh) / 2 - 0.03)
			local localPos = right * u + Vector3.new(0, v, 0) + n * (f[4] + 0.015)
			local size = (n.Z ~= 0) and Vector3.new(bw, bh, 0.03) or Vector3.new(0.03, bh, bw)
			local rot = pal[3] and CFrame.identity or CFrame.fromAxisAngle(n, math.rad(rnd:NextNumber(-25, 25)))
			part(m, "Camo", size, p.CFrame * CFrame.new(localPos) * rot, pal[2][rnd:NextInteger(1, #pal[2])], Enum.Material.Fabric)
		end
	end
end

-- headgear on a head whose top-centre is CFrame ht (facing ht.LookVector)
local function headgear(m, ht, kind, col)
	if kind == "helmet" then
		local h = part(m, "Helmet", Vector3.new(1, 1, 1), ht * CFrame.new(0, -0.18, 0.02), col, Enum.Material.SmoothPlastic, {shadow = true})
		special(h, Enum.MeshType.Sphere, Vector3.new(1.42, 0.98, 1.48))
		part(m, "HelmetRim", Vector3.new(0.08, 1.46, 1.52), ht * CFrame.new(0, -0.52, 0.02) * CFrame.Angles(0, 0, math.rad(90)), col:Lerp(NEAR_BLACK, 0.25), Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	elseif kind == "beret" then
		local b = part(m, "Beret", Vector3.new(1, 1, 1), ht * CFrame.new(0.12, -0.02, 0.05) * CFrame.Angles(0, 0, math.rad(-12)), col, Enum.Material.Fabric, {shadow = true})
		special(b, Enum.MeshType.Sphere, Vector3.new(1.36, 0.42, 1.3))
		part(m, "BeretBadge", Vector3.new(0.05, 0.22, 0.22), ht * CFrame.new(-0.42, -0.08, -0.48) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), CREAM, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	elseif kind == "boonie" then
		part(m, "Brim", Vector3.new(0.06, 1.95, 1.95), ht * CFrame.new(0, -0.28, 0) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.Material.Fabric, {shape = Enum.PartType.Cylinder, shadow = true})
		part(m, "Crown", Vector3.new(0.5, 1.22, 1.22), ht * CFrame.new(0, -0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.Material.Fabric, {shape = Enum.PartType.Cylinder})
		part(m, "Band", Vector3.new(0.1, 1.25, 1.25), ht * CFrame.new(0, -0.16, 0) * CFrame.Angles(0, 0, math.rad(90)), col:Lerp(NEAR_BLACK, 0.4), Enum.Material.Fabric, {shape = Enum.PartType.Cylinder})
	elseif kind == "cap" then
		local cr = part(m, "CapCrown", Vector3.new(1, 1, 1), ht * CFrame.new(0, -0.12, 0.04), col, Enum.Material.Fabric, {shadow = true})
		special(cr, Enum.MeshType.Sphere, Vector3.new(1.24, 0.66, 1.26))
		part(m, "CapBill", Vector3.new(0.86, 0.06, 0.6), ht * CFrame.new(0, -0.3, -0.78) * CFrame.Angles(math.rad(-6), 0, 0), col:Lerp(NEAR_BLACK, 0.2), Enum.Material.Fabric)
	end
end
local function goggles(m, ht)
	part(m, "GoggleStrap", Vector3.new(1.5, 0.16, 1.56), ht * CFrame.new(0, -0.5, 0.02), C(30, 30, 28), Enum.Material.Fabric)
	for _, sx in ipairs({-1, 1}) do
		part(m, "GoggleLens", Vector3.new(0.12, 0.34, 0.34), ht * CFrame.new(sx * 0.24, -0.48, -0.74) * CFrame.Angles(0, math.rad(90), 0), C(46, 40, 30), Enum.Material.Glass, {shape = Enum.PartType.Cylinder, refl = 0.3})
	end
end

-- an R15-proportioned mannequin from Parts. base = feet centre on the floor/plinth top, facing base.LookVector.
-- outfit = {camo = key, top = key?, gear = "helmet"|"beret"|"boonie"|"cap", gearCol, carrier = colour?, goggles, gaiter = colour?}
local function mannequin(parent, name, base, outfit, seed)
	local m = grp(name, parent)
	local rnd = Random.new(seed)
	local k = 0.92
	local function P(nm, size, x, y, z, col, mat, o)
		return part(m, nm, size * k, base * CFrame.new(x * k, y * k, z * k), col, mat, o)
	end
	local pants = CAMO[outfit.camo][1]
	local shirt = CAMO[outfit.top or outfit.camo][1]
	local skin = outfit.gloves and BOOT or DUMMY
	local parts = {}
	for _, sx in ipairs({-1, 1}) do
		P("Foot", Vector3.new(0.9, 0.35, 1.15), sx * 0.5, 0.175, -0.08, BOOT, Enum.Material.SmoothPlastic, {shadow = true})
		P("BootTop", Vector3.new(0.88, 0.45, 0.88), sx * 0.5, 0.575, 0, BOOT, Enum.Material.SmoothPlastic)
		table.insert(parts, {P("LowerLeg", Vector3.new(0.84, 0.72, 0.84), sx * 0.5, 1.16, 0, pants, Enum.Material.Fabric, {shadow = true}), outfit.camo})
		table.insert(parts, {P("UpperLeg", Vector3.new(0.94, 1.15, 0.94), sx * 0.5, 2.095, 0, pants, Enum.Material.Fabric, {shadow = true}), outfit.camo})
		-- arms hang slightly out (mannequin pose)
		local armCF = CFrame.new(sx * 1.45, 4.65, 0) * CFrame.Angles(0, 0, math.rad(sx * 7))
		local ua = part(m, "UpperArm", Vector3.new(0.84, 1.2, 0.84) * k, base * CFrame.new(armCF.Position * k) * armCF.Rotation * CFrame.new(0, -0.62 * k, 0), shirt, Enum.Material.Fabric, {shadow = true})
		table.insert(parts, {ua, outfit.top or outfit.camo})
		local la = part(m, "LowerArm", Vector3.new(0.78, 1.05, 0.78) * k, ua.CFrame * CFrame.new(0, -1.14 * k, 0), shirt, Enum.Material.Fabric, {shadow = true})
		table.insert(parts, {la, outfit.top or outfit.camo})
		part(m, "Hand", Vector3.new(0.7, 0.42, 0.7) * k, la.CFrame * CFrame.new(0, -0.74 * k, 0), skin, Enum.Material.SmoothPlastic)
	end
	table.insert(parts, {P("LowerTorso", Vector3.new(1.96, 0.5, 1.0), 0, 2.92, 0, pants, Enum.Material.Fabric, {shadow = true}), outfit.camo})
	P("Belt", Vector3.new(2.0, 0.16, 1.04), 0, 3.1, 0, C(34, 32, 28), Enum.Material.Fabric)
	table.insert(parts, {P("UpperTorso", Vector3.new(2.0, 1.48, 1.0), 0, 3.92, 0, shirt, Enum.Material.Fabric, {shadow = true}), outfit.top or outfit.camo})
	P("Neck", Vector3.new(0.45, 0.5, 0.5), 0, 4.78, 0, DUMMY, Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder}).CFrame = base * CFrame.new(0, 4.78 * k, 0) * CFrame.Angles(0, 0, math.rad(90))
	local head = P("Head", Vector3.new(1.2, 1.2, 1.2), 0, 5.55, 0, DUMMY, Enum.Material.SmoothPlastic, {shadow = true})
	special(head, Enum.MeshType.Head, Vector3.new(1.18, 1.18, 1.18))
	for _, e in ipairs(parts) do camo(m, e[1], e[2], rnd, e[1].Name == "UpperTorso" and 4 or 2) end
	if outfit.carrier then
		P("Carrier", Vector3.new(2.1, 1.28, 1.2), 0, 3.96, 0, outfit.carrier, Enum.Material.Fabric, {shadow = true})
		for i = -1, 1 do P("Pouch", Vector3.new(0.52, 0.56, 0.24), i * 0.62, 3.66, -0.7, outfit.carrier:Lerp(NEAR_BLACK, 0.15), Enum.Material.Fabric) end
		for _, sx in ipairs({-1, 1}) do P("Strap", Vector3.new(0.4, 0.14, 1.22), sx * 0.62, 4.67, 0, outfit.carrier, Enum.Material.Fabric) end
		P("Patch", Vector3.new(0.5, 0.32, 0.04), 0.5, 4.32, -0.62, OLIVE_D, Enum.Material.Fabric)
	end
	if outfit.gaiter then P("Gaiter", Vector3.new(0.9, 0.42, 0.9), 0, 4.86, 0, outfit.gaiter, Enum.Material.Fabric) end
	local ht = base * CFrame.new(0, 6.15 * k, 0)
	if outfit.gear then headgear(m, ht, outfit.gear, outfit.gearCol or CAMO[outfit.camo][1]) end
	if outfit.goggles then goggles(m, ht) end
	-- shoulder flag patch on the left sleeve
	part(m, "SleevePatch", Vector3.new(0.04, 0.34, 0.3), base * CFrame.new(-1.53 * k, 4.3 * k, 0) * CFrame.Angles(0, 0, math.rad(-7)), OLIVE_D, Enum.Material.Fabric)
	return m
end

-- name plate: cream plate with name + price, facing plateCF.LookVector
local function plate(parent, cf, name, price)
	local p = part(parent, "NamePlate", Vector3.new(2.2, 0.62, 0.06), cf, CREAM, Enum.Material.SmoothPlastic)
	gui(p, Enum.NormalId.Front, 110, {
		{box = OLIVE_D, x = 0, y = 0, w = 0.035, h = 1},
		{text = name, x = 0.08, y = 0.1, w = 0.88, h = 0.46, align = Enum.TextXAlignment.Left},
		{text = price, x = 0.08, y = 0.58, w = 0.6, h = 0.32, bold = false, color = C(70, 78, 40), align = Enum.TextXAlignment.Left},
	})
	return p
end

---------------------------------------------------------------------------------------------------
-- 4. Outfit walls: 2 bays per side wall (between the piers at z 79-81 / 89-91 / 99), 2 mannequins each
--    Wall faces measured: x -/+29.7 (bays), piers -/+28.6. Backdrop 0.08 off the wall.
---------------------------------------------------------------------------------------------------
local OUTFITS = {
	W = {
		{"WOODLAND RECON", "R$ 350", {camo = "woodland", gear = "boonie"}},
		{"DESERT RAIDER", "R$ 400", {camo = "desert", gear = "cap", gaiter = C(206, 190, 150)}},
		{"URBAN OPS", "R$ 550", {camo = "urban", gear = "helmet", gearCol = C(96, 96, 92), goggles = true, carrier = C(70, 72, 70), gloves = true}},
		{"OLIVE DRAB", "R$ 250", {camo = "od", gear = "beret", gearCol = C(70, 80, 42)}},
	},
	E = {
		{"ALPINE", "R$ 500", {camo = "snow", gear = "helmet", gearCol = C(214, 214, 208), goggles = true, gloves = true}},
		{"NIGHT OPS", "R$ 600", {camo = "night", gear = "cap", gearCol = C(36, 38, 36), carrier = C(34, 36, 34), gloves = true}},
		{"TIGER STRIPE", "R$ 450", {camo = "tiger", gear = "boonie"}},
		{"SKY PILOT", "R$ 300", {camo = "sage", gear = "cap", gearCol = OLIVE_D, gaiter = CREAM}},
	},
}
local walls = grp("OutfitWalls")
local BAYS = {{81.6, 87.6}, {92.2, 98.2}}
local seed = 100
for _, side in ipairs({"W", "E"}) do
	local sx = side == "W" and -1 or 1
	local wallX = sx * 29.7
	local sideM = grp("Outfits" .. side, walls)
	local i = 0
	for b, bay in ipairs(BAYS) do
		local zc = (bay[1] + bay[2]) / 2
		-- backdrop: dark olive fabric panel in a wood frame, header strip with the bay name
		-- 0.43 off the wall face: the wall's trims stand 0.3 proud
		local back = part(sideM, "Backdrop", Vector3.new(0.1, 5.4, bay[2] - bay[1]), CFrame.new(wallX - sx * 0.43, 0.6 + 2.7, zc), C(52, 58, 36), Enum.Material.Fabric)
		part(sideM, "FrameTop", Vector3.new(0.16, 0.18, bay[2] - bay[1] + 0.2), CFrame.new(wallX - sx * 0.46, 6.0, zc), WOOD_D, Enum.Material.Wood)
		part(sideM, "FrameBot", Vector3.new(0.16, 0.18, bay[2] - bay[1] + 0.2), CFrame.new(wallX - sx * 0.46, 0.6, zc), WOOD_D, Enum.Material.Wood)
		for _, ez in ipairs({bay[1] - 0.05, bay[2] + 0.05}) do
			part(sideM, "FrameSide", Vector3.new(0.16, 5.58, 0.18), CFrame.new(wallX - sx * 0.46, 3.3, ez), WOOD_D, Enum.Material.Wood)
		end
		for j = 0, 1 do
			i += 1; seed += 17
			local o = OUTFITS[side][i]
			local z = bay[1] + 1.55 + j * 2.9
			-- low plinth: dark wood block, cream top inset, near-black kick
			local px = sx * 27.4
			part(sideM, "PlinthKick", Vector3.new(2.3, 0.14, 2.3), CFrame.new(px, 0.1, z), NEAR_BLACK, Enum.Material.SmoothPlastic, {collide = true})
			part(sideM, "Plinth", Vector3.new(2.4, 0.42, 2.4), CFrame.new(px, 0.37, z), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
			part(sideM, "PlinthTop", Vector3.new(2.2, 0.04, 2.2), CFrame.new(px, 0.6, z), C(214, 206, 186), Enum.Material.SmoothPlastic)
			-- facing into the room, turned 20 degrees toward the entrance
			local look = Vector3.new(-sx, 0, -0.36).Unit
			local base = CFrame.lookAt(Vector3.new(px, 0.62, z), Vector3.new(px, 0.62, z) + look)
			mannequin(sideM, "Mannequin_" .. o[1]:gsub(" ", ""), base, o[3], seed)
			-- name plate leaning on the plinth front (room side), facing the room
			local pcf = CFrame.lookAt(Vector3.new(px - sx * 1.24, 0.38, z), Vector3.new(px - sx * 3, 0.38, z)) * CFrame.Angles(math.rad(12), 0, 0)
			plate(sideM, pcf, o[1], o[2])
		end
	end
	-- wash bar over both bays on two arms (one warm SurfaceLight per side; replaces a board picture light)
	local barX = sx * 27.55
	local bar = part(sideM, "WashBar", Vector3.new(0.34, 0.2, 15.6), CFrame.new(barX, 7.25, 89.9), NEAR_BLACK, Enum.Material.Metal)
	part(sideM, "WashStrip", Vector3.new(0.2, 0.04, 15.3), CFrame.new(barX, 7.13, 89.9), WARM_BULB, Enum.Material.Neon)
	for _, az in ipairs({84.6, 95.2}) do
		part(sideM, "WashArm", Vector3.new(math.abs(sx * 29.3 - barX), 0.1, 0.1), CFrame.new((sx * 29.3 + barX) / 2, 7.25, az), NEAR_BLACK, Enum.Material.Metal)
	end
	local sl = Instance.new("SurfaceLight"); sl.Face = Enum.NormalId.Bottom; sl.Angle = 75; sl.Range = 10; sl.Brightness = 1.3
	sl.Color = C(255, 196, 140); sl.Shadows = false; sl.Parent = bar
	roomLight(bar)
end

---------------------------------------------------------------------------------------------------
-- 5. Headgear walls in the entrance bays (z 70.5-77.5): two wood shelves of head forms
---------------------------------------------------------------------------------------------------
local hg = grp("HeadgearWalls")
local HEADS = {
	W = {{"helmet", C(98, 104, 66)}, {"beret", C(70, 80, 42)}, {"boonie", C(196, 176, 136)}, {"cap", C(44, 46, 44)}, {"helmet", C(150, 140, 104)}, {"beret", C(110, 40, 40)}},
	E = {{"cap", OLIVE_D}, {"helmet", C(214, 214, 208)}, {"boonie", C(112, 116, 70)}, {"beret", C(36, 38, 36)}, {"cap", C(196, 176, 136)}, {"helmet", C(70, 72, 70)}},
}
for _, side in ipairs({"W", "E"}) do
	local sx = side == "W" and -1 or 1
	-- the entrance bays' wall face is 29.4 (measured), 0.3 prouder than the outfit bays
	local wallX = sx * 29.4
	local m = grp("Headgear" .. side, hg)
	local z0, z1 = 70.8, 77.4
	local zc = (z0 + z1) / 2
	part(m, "Backdrop", Vector3.new(0.1, 4.6, z1 - z0), CFrame.new(wallX - sx * 0.13, 1.6 + 2.3, zc), C(52, 58, 36), Enum.Material.Fabric)
	local hdr = part(m, "Header", Vector3.new(0.08, 0.7, 3.6), CFrame.new(wallX - sx * 0.22, 6.55, zc), CREAM, Enum.Material.SmoothPlastic)
	gui(hdr, side == "W" and Enum.NormalId.Right or Enum.NormalId.Left, 100, {
		{box = OLIVE_D, x = 0, y = 0.82, w = 1, h = 0.18},
		{text = "HEADGEAR", x = 0.04, y = 0.08, w = 0.92, h = 0.68},
	})
	for s, sy in ipairs({2.6, 4.45}) do
		local shelfX = wallX - sx * 0.62
		part(m, "Shelf", Vector3.new(1.0, 0.12, z1 - z0 - 0.4), CFrame.new(shelfX, sy, zc), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
		part(m, "ShelfLip", Vector3.new(0.05, 0.16, z1 - z0 - 0.4), CFrame.new(shelfX - sx * 0.52, sy - 0.01, zc), OLIVE_D, Enum.Material.SmoothPlastic)
		for _, bz in ipairs({z0 + 1.2, z1 - 1.2}) do
			part(m, "Bracket", Vector3.new(0.9, 0.3, 0.08), CFrame.new(shelfX + sx * 0.04, sy - 0.21, bz), NEAR_BLACK, Enum.Material.Metal)
		end
		for h = 1, 3 do
			local e = HEADS[side][(s - 1) * 3 + h]
			local hz = z0 + 1.05 + (h - 1) * 2.2
			local bx = wallX - sx * 0.7
			part(m, "Stand", Vector3.new(0.5, 0.12, 0.12), CFrame.new(bx, sy + 0.31, hz) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 28), Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
			local hd = part(m, "HeadForm", Vector3.new(0.9, 0.9, 0.9), CFrame.new(bx, sy + 0.98, hz), DUMMY, Enum.Material.SmoothPlastic)
			special(hd, Enum.MeshType.Head, Vector3.new(1.0, 1.0, 1.0))
			local ht = CFrame.lookAt(Vector3.new(bx, sy + 1.43, hz), Vector3.new(bx - sx, sy + 1.43, hz - 0.3))
			local gm = grp("Gear", m)
			headgear(gm, ht, e[1], e[2])
			-- head forms are 0.8 of a mannequin head: scale the gear about the head top
			gm.WorldPivot = ht
			gm:ScaleTo(0.8)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- 6. Glass display cases at the entrance (where the supply bins stood): dog tags, unit patches, rank insignia, a beret
---------------------------------------------------------------------------------------------------
local cases = grp("GlassCases")
local function glassCase(name, x, z, title, sub, fill)
	local m = grp(name, cases)
	local W, D = 3.4, 2.0
	local bodyH = 2.7
	part(m, "Kick", Vector3.new(W - 0.1, 0.18, D - 0.1), CFrame.new(x, 0.125, z), NEAR_BLACK, Enum.Material.SmoothPlastic, {collide = true})
	part(m, "Body", Vector3.new(W, bodyH - 0.2, D), CFrame.new(x, 0.2 + (bodyH - 0.2) / 2, z), WOOD, Enum.Material.Wood, {collide = true, shadow = true})
	part(m, "BodyPanel", Vector3.new(W - 0.5, bodyH - 0.9, 0.04), CFrame.new(x, 0.2 + (bodyH - 0.2) / 2, z - D / 2 - 0.02), C(214, 206, 186), Enum.Material.SmoothPlastic)
	part(m, "TopRim", Vector3.new(W + 0.06, 0.1, D + 0.06), CFrame.new(x, bodyH + 0.05, z), OLIVE_D, Enum.Material.Metal, {collide = true})
	-- felt bed, warm Neon strip along the inside front edge (glows; no extra light)
	local bedY = bodyH + 0.1
	part(m, "Bed", Vector3.new(W - 0.3, 0.06, D - 0.3), CFrame.new(x, bedY + 0.03, z), C(44, 50, 30), Enum.Material.Fabric)
	part(m, "Glow", Vector3.new(W - 0.36, 0.04, 0.06), CFrame.new(x, bedY + 0.03, z - D / 2 + 0.22), WARM_BULB, Enum.Material.Neon)
	-- glass hood with metal corner posts
	local gH = 0.95
	part(m, "Glass", Vector3.new(W - 0.08, gH, D - 0.08), CFrame.new(x, bedY + gH / 2, z), C(210, 226, 220), Enum.Material.Glass, {tr = 0.82, refl = 0.08, collide = true})
	for _, a in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		part(m, "Post", Vector3.new(0.08, gH + 0.04, 0.08), CFrame.new(x + a[1] * (W / 2 - 0.04), bedY + gH / 2, z + a[2] * (D / 2 - 0.04)), C(60, 58, 52), Enum.Material.Metal)
	end
	-- thin metal frame round the glass top (front/back bars)
	for _, sz in ipairs({-1, 1}) do
		part(m, "GlassCap", Vector3.new(W, 0.06, 0.08), CFrame.new(x, bedY + gH + 0.03, z + sz * (D / 2 - 0.04)), C(60, 58, 52), Enum.Material.Metal)
	end
	-- placard on the front of the body
	local pl = part(m, "Placard", Vector3.new(2.3, 0.6, 0.05), CFrame.new(x, bodyH - 0.55, z - D / 2 - 0.05), CREAM, Enum.Material.SmoothPlastic)
	gui(pl, Enum.NormalId.Front, 110, {
		{box = OLIVE_D, x = 0, y = 0, w = 1, h = 0.1},
		{text = title, x = 0.05, y = 0.16, w = 0.9, h = 0.44},
		{text = sub, x = 0.05, y = 0.64, w = 0.9, h = 0.26, bold = false, color = C(70, 78, 40)},
	})
	fill(m, x, bedY + 0.06, z, W, D)
	return m
end
local function dogTag(m, cf)
	-- two stamped tags + a ball chain loop lying on the felt
	part(m, "Tag", Vector3.new(0.34, 0.03, 0.56), cf, C(186, 186, 180), Enum.Material.Metal, {refl = 0.15})
	part(m, "Tag", Vector3.new(0.34, 0.03, 0.56), cf * CFrame.new(0.14, 0.03, 0.12) * CFrame.Angles(0, math.rad(14), 0), C(170, 170, 164), Enum.Material.Metal, {refl = 0.15})
	for a = 0, 330, 30 do
		local r = math.rad(a)
		part(m, "Chain", Vector3.new(0.05, 0.05, 0.05), cf * CFrame.new(math.cos(r) * 0.42, 0, -0.62 + math.sin(r) * 0.36), C(150, 150, 144), Enum.Material.Metal, {shape = Enum.PartType.Ball})
	end
end
local function patch(m, cf, col, ring, txt)
	part(m, "PatchRing", Vector3.new(0.04, 0.62, 0.62), cf * CFrame.Angles(0, 0, math.rad(90)), ring, Enum.Material.Fabric, {shape = Enum.PartType.Cylinder})
	local p = part(m, "Patch", Vector3.new(0.05, 0.52, 0.52), cf * CFrame.new(0, 0.005, 0) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.Material.Fabric, {shape = Enum.PartType.Cylinder})
	local face = part(m, "PatchFace", Vector3.new(0.4, 0.01, 0.4), cf * CFrame.new(0, 0.035, 0), col, Enum.Material.Fabric, {tr = 1})
	gui(face, Enum.NormalId.Top, 160, {{text = txt, x = 0.05, y = 0.3, w = 0.9, h = 0.4, color = ring}})
end
local function chevrons(m, cf, n)
	for i = 0, n - 1 do
		for _, sx in ipairs({-1, 1}) do
			part(m, "Chevron", Vector3.new(0.36, 0.03, 0.08), cf * CFrame.new(sx * 0.15, 0, i * 0.15) * CFrame.Angles(0, math.rad(sx * 35), 0), C(196, 170, 96), Enum.Material.Fabric)
		end
	end
	part(m, "ChevronBack", Vector3.new(0.62, 0.02, 0.18 + n * 0.15), cf * CFrame.new(0, -0.02, (n - 1) * 0.075 + 0.02), OLIVE_D, Enum.Material.Fabric)
end
glassCase("CaseW", -11.8, 76, "DOG TAGS", "STAMPED · BALL CHAIN · FROM R$ 75", function(m, x, y, z, W, D)
	dogTag(m, CFrame.new(x - 1.05, y + 0.02, z + 0.1) * CFrame.Angles(0, math.rad(-12), 0))
	dogTag(m, CFrame.new(x, y + 0.02, z + 0.18) * CFrame.Angles(0, math.rad(8), 0))
	dogTag(m, CFrame.new(x + 1.05, y + 0.02, z + 0.05) * CFrame.Angles(0, math.rad(20), 0))
	-- a beret lying at the back
	local b = part(m, "Beret", Vector3.new(1, 1, 1), CFrame.new(x + 0.95, y + 0.12, z + 0.55), C(70, 80, 42), Enum.Material.Fabric)
	special(b, Enum.MeshType.Sphere, Vector3.new(0.95, 0.24, 0.85))
end)
glassCase("CaseE", 11.8, 76, "PATCHES & INSIGNIA", "UNIT · RANK · WINGS · FROM R$ 50", function(m, x, y, z, W, D)
	patch(m, CFrame.new(x - 1.1, y + 0.03, z - 0.25), OLIVE_D, CREAM, "SKY")
	patch(m, CFrame.new(x - 0.35, y + 0.03, z + 0.3), C(44, 46, 44), C(176, 192, 108), "TAC")
	patch(m, CFrame.new(x + 0.4, y + 0.03, z - 0.3), C(196, 176, 136), C(78, 54, 34), "AIR")
	chevrons(m, CFrame.new(x + 1.15, y + 0.03, z - 0.1), 3)
	-- pilot wings: two swept bars and a disc
	for _, sx in ipairs({-1, 1}) do
		part(m, "Wing", Vector3.new(0.5, 0.03, 0.1), CFrame.new(x + 0.6 + sx * 0.3, y + 0.03, z + 0.45) * CFrame.Angles(0, math.rad(sx * -10), 0), C(196, 186, 150), Enum.Material.Metal, {refl = 0.1})
	end
	part(m, "WingDisc", Vector3.new(0.04, 0.2, 0.2), CFrame.new(x + 0.6, y + 0.04, z + 0.45) * CFrame.Angles(0, 0, math.rad(90)), OLIVE, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
end)

---------------------------------------------------------------------------------------------------
-- 7. FEATURED / NEW DROPS screens on the back wall (where the price boards were), raised clear of the
--    outfitter's tag; near-black bezel, self-lit SurfaceGui (LightInfluence 0), all Scale
---------------------------------------------------------------------------------------------------
local scr = grp("Screens")
local function screen(name, x, rows)
	local m = grp(name, scr)
	local W, H = 5.8, 3.05
	local yc = 8.95 + H / 2
	local zb = 109.80
	part(m, "Bezel", Vector3.new(W, H, 0.16), CFrame.new(x, yc, zb - 0.08), C(22, 22, 20), Enum.Material.SmoothPlastic)
	local face = part(m, "Face", Vector3.new(W - 0.24, H - 0.24, 0.04), CFrame.new(x, yc, zb - 0.18), C(14, 16, 14), Enum.Material.SmoothPlastic)
	gui(face, Enum.NormalId.Front, 70, rows, {light = 0, bright = 1.2})
	part(m, "Lip", Vector3.new(W, 0.08, 0.24), CFrame.new(x, yc - H / 2 - 0.04, zb - 0.12), OLIVE_D, Enum.Material.Metal)
	return m
end
local TXT, DIM, OLV = C(236, 232, 218), C(150, 154, 136), C(176, 192, 108)
local L = Enum.TextXAlignment.Left
local R = Enum.TextXAlignment.Right
screen("ScreenFeatured", -14.6, {
	{box = C(14, 16, 14), x = 0, y = 0, w = 1, h = 1},
	{box = OLIVE_D, x = 0, y = 0, w = 1, h = 0.2},
	{text = "FEATURED", x = 0.04, y = 0.025, w = 0.6, h = 0.15, color = TXT, align = L},
	{text = "THIS WEEK", x = 0.6, y = 0.05, w = 0.36, h = 0.1, color = C(214, 222, 180), bold = false, align = R},
	{text = "SKY RANGER ELITE", x = 0.04, y = 0.25, w = 0.92, h = 0.16, color = TXT, align = L},
	{text = "MULTI-CAMO · HELMET · GOGGLES · PLATE CARRIER", x = 0.04, y = 0.43, w = 0.92, h = 0.08, color = DIM, bold = false, align = L},
	{box = C(150, 140, 104), x = 0.04, y = 0.56, w = 0.13, h = 0.2},
	{box = C(106, 112, 70), x = 0.19, y = 0.56, w = 0.13, h = 0.2},
	{box = C(96, 74, 50), x = 0.34, y = 0.56, w = 0.13, h = 0.2},
	{text = "R$ 900", x = 0.55, y = 0.56, w = 0.41, h = 0.2, color = OLV, align = R},
	{box = C(60, 64, 52), x = 0.04, y = 0.83, w = 0.92, h = 0.01},
	{text = "ROTATES IN 2D 14H · ON STAGE NOW", x = 0.04, y = 0.86, w = 0.92, h = 0.09, color = DIM, bold = false, align = L},
})
local drops = {
	{box = C(14, 16, 14), x = 0, y = 0, w = 1, h = 1},
	{box = CREAM, x = 0, y = 0, w = 1, h = 0.2},
	{text = "NEW DROPS", x = 0.04, y = 0.025, w = 0.6, h = 0.15, color = NEAR_BLACK, align = L},
	{text = "DAILY", x = 0.6, y = 0.05, w = 0.36, h = 0.1, color = OLIVE_D, bold = false, align = R},
}
local ITEMS = {{"ALPINE SET", "R$ 500"}, {"NIGHT OPS CAP", "R$ 120"}, {"PILOT WINGS PIN", "R$ 75"}, {"TIGER BOONIE", "R$ 150"}}
for i, it in ipairs(ITEMS) do
	local y = 0.25 + (i - 1) * 0.175
	table.insert(drops, {text = "NEW", x = 0.04, y = y + 0.025, w = 0.11, h = 0.09, color = NEAR_BLACK, bg = OLV})
	table.insert(drops, {text = it[1], x = 0.18, y = y + 0.015, w = 0.56, h = 0.11, color = TXT, align = L})
	table.insert(drops, {text = it[2], x = 0.72, y = y + 0.015, w = 0.24, h = 0.11, color = OLV, align = R})
	table.insert(drops, {box = C(52, 56, 46), x = 0.04, y = y + 0.155, w = 0.92, h = 0.008})
end
screen("ScreenNewDrops", 15.2, drops)

---------------------------------------------------------------------------------------------------
-- 8. Counter = checkout: one continuous olive fascia under the wood top, a CHECKOUT screen facing customers
---------------------------------------------------------------------------------------------------
local co = grp("Checkout")
part(co, "Fascia", Vector3.new(26.5, 0.24, 0.08), CFrame.new(3, 3.83, 100.05), OLIVE_D, Enum.Material.SmoothPlastic)
part(co, "FasciaLine", Vector3.new(26.5, 0.03, 0.03), CFrame.new(3, 3.69, 100.005), CREAM, Enum.Material.SmoothPlastic)
do
	local x, z, top = 7.4, 101.0, 4.0
	part(co, "StandFoot", Vector3.new(0.9, 0.06, 0.6), CFrame.new(x, top + 0.03, z), METAL_D, Enum.Material.Metal)
	part(co, "StandPost", Vector3.new(0.12, 0.7, 0.12), CFrame.new(x, top + 0.41, z + 0.12), METAL_D, Enum.Material.Metal)
	local scf = CFrame.new(x, top + 0.95, z + 0.05) * CFrame.Angles(math.rad(10), 0, 0)
	part(co, "ScreenBack", Vector3.new(1.9, 1.1, 0.1), scf, C(22, 22, 20), Enum.Material.SmoothPlastic)
	local f = part(co, "ScreenFace", Vector3.new(1.76, 0.96, 0.02), scf * CFrame.new(0, 0, -0.06), C(14, 16, 14), Enum.Material.SmoothPlastic)
	gui(f, Enum.NormalId.Front, 120, {
		{box = OLIVE_D, x = 0, y = 0, w = 1, h = 0.3},
		{text = "CHECKOUT", x = 0.06, y = 0.04, w = 0.88, h = 0.22, color = TXT},
		{text = "OUTFITS · TAGS · PATCHES", x = 0.06, y = 0.42, w = 0.88, h = 0.18, color = DIM, bold = false},
		{text = "PAY WITH R$", x = 0.06, y = 0.68, w = 0.88, h = 0.18, color = OLV},
	}, {light = 0, bright = 1.1})
end

---------------------------------------------------------------------------------------------------
-- 9. Featured stage on the centre plinth: stage disc, a turntable with the featured mannequin (Spin), a key spot
---------------------------------------------------------------------------------------------------
local st = grp("FeaturedStage")
-- low round dais resting on the plinth's metal rim (top 0.92, r 2.9-4.05); the lower inner disc (0.85) is covered
local baseY = 0.93
local topY = baseY + 0.7
part(st, "Dais", Vector3.new(0.7, 6.0, 6.0), CFrame.new(STAGE.X, baseY + 0.35, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)), C(36, 34, 30), Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder, collide = true, shadow = true})
part(st, "DaisTop", Vector3.new(0.04, 5.9, 5.9), CFrame.new(STAGE.X, topY + 0.01, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)), WOOD_D, Enum.Material.Wood, {shape = Enum.PartType.Cylinder})
part(st, "DaisRing", Vector3.new(0.08, 6.08, 6.08), CFrame.new(STAGE.X, topY - 0.12, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)), OLIVE_D, Enum.Material.Neon, {shape = Enum.PartType.Cylinder})
do
	-- turntable 0.16 over the dais so the RoomFX bob (+-0.15) never touches it
	local spin = grp("FeaturedOutfit", st)
	local ttY = topY + 0.03 + 0.16
	part(spin, "Turntable", Vector3.new(0.18, 4.2, 4.2), CFrame.new(STAGE.X, ttY + 0.09, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)), C(214, 206, 186), Enum.Material.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	part(spin, "TurntableEdge", Vector3.new(0.2, 4.26, 4.26), CFrame.new(STAGE.X, ttY + 0.08, STAGE.Z) * CFrame.Angles(0, 0, math.rad(90)), WOOD_D, Enum.Material.Wood, {shape = Enum.PartType.Cylinder})
	local base = CFrame.lookAt(Vector3.new(STAGE.X, ttY + 0.18, STAGE.Z), Vector3.new(STAGE.X, ttY + 0.18, STAGE.Z - 1))
	mannequin(spin, "Mannequin_SkyRangerElite", base, {camo = "multi", gear = "helmet", gearCol = C(106, 112, 70), goggles = true, carrier = C(120, 104, 72), gaiter = C(176, 160, 124), gloves = true}, 777)
	spin.WorldPivot = CFrame.new(STAGE.X, ttY, STAGE.Z)
	spin:SetAttribute("Spin", 12)
end
-- rope line round the stage (RIVALS' velvet rope, ours: near-black posts, olive rope), open toward the entrance
do
	local R = 6.1
	local posts = {}
	for i = 0, 5 do
		local a = math.rad(-90 + 30 + i * 60)
		local p = Vector3.new(STAGE.X + math.cos(a) * R, 0, STAGE.Z + math.sin(a) * R)
		table.insert(posts, p)
		part(st, "PostBase", Vector3.new(0.12, 0.8, 0.8), CFrame.new(p.X, 0.09, p.Z) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 28), Enum.Material.Metal, {shape = Enum.PartType.Cylinder, collide = true})
		part(st, "Post", Vector3.new(2.5, 0.16, 0.16), CFrame.new(p.X, 1.39, p.Z) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 28), Enum.Material.Metal, {shape = Enum.PartType.Cylinder, collide = true})
		part(st, "PostTop", Vector3.new(0.3, 0.3, 0.3), CFrame.new(p.X, 2.72, p.Z), OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Ball})
	end
	-- ropes between consecutive posts; posts 1..6 run from front-right round the back to front-left, so no rope 6 -> 1 (front gap)
	for i = 1, 5 do
		local a, b = posts[i], posts[i + 1]
		local y0, sag = 2.45, 0.35
		local prev = Vector3.new(a.X, y0, a.Z)
		for k = 1, 4 do
			local t = k / 4
			local q = a:Lerp(b, t)
			local cur = Vector3.new(q.X, y0 - sag * 4 * t * (1 - t), q.Z)
			local mid = (prev + cur) / 2
			part(st, "Rope", Vector3.new(0.09, 0.09, (cur - prev).Magnitude + 0.04), CFrame.lookAt(mid, cur), OLIVE_D, Enum.Material.Fabric)
			prev = cur
		end
	end
end
-- name plate on the stage front (faces the entrance)
plate(st, CFrame.lookAt(Vector3.new(STAGE.X, baseY + 0.35, STAGE.Z - 3.12), Vector3.new(STAGE.X, baseY + 0.35, STAGE.Z - 5)) * CFrame.Angles(math.rad(10), 0, 0), "SKY RANGER ELITE", "FEATURED · R$ 900")
-- key spot: a ceiling-hung truss can in front of the stage, aimed at the mannequin's chest (shadows on: the feature moment)
do
	-- hung from the ceiling beam at z 79-80 (bottom 12.65)
	local pos = Vector3.new(-1.5, 11.6, 79.5)
	local tgt = Vector3.new(STAGE.X, 4.6, STAGE.Z)
	local aim = CFrame.lookAt(pos, tgt)
	part(st, "KeyRod", Vector3.new(0.12, 0.98, 0.12), CFrame.new(pos.X, 12.15, pos.Z), NEAR_BLACK, Enum.Material.Metal)
	part(st, "KeyYoke", Vector3.new(1.0, 0.1, 0.1), CFrame.new(pos.X, 11.65, pos.Z), NEAR_BLACK, Enum.Material.Metal)
	part(st, "KeyCan", Vector3.new(1.3, 0.8, 0.8), aim * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(90), 0), C(30, 30, 28), Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	part(st, "KeyBand", Vector3.new(0.12, 0.84, 0.84), aim * CFrame.new(0, 0, 0.62) * CFrame.Angles(0, math.rad(90), 0), OLIVE_D, Enum.Material.Metal, {shape = Enum.PartType.Cylinder})
	local lens = part(st, "KeyLens", Vector3.new(0.6, 0.6, 0.04), aim * CFrame.new(0, 0, -0.47), WARM_BULB, Enum.Material.Neon)
	local s = Instance.new("SpotLight"); s.Face = Enum.NormalId.Front; s.Angle = 26; s.Range = 18; s.Brightness = 4.5
	s.Color = C(255, 214, 168); s.Shadows = true; s.Parent = lens
	roomLight(lens)
end

---------------------------------------------------------------------------------------------------
-- 10. Wall shelves: folded camo shirts and caps instead of ammo / rations / med kits
---------------------------------------------------------------------------------------------------
local fold = grp("ShelfGoods")
local SHIRTS = {"woodland", "desert", "urban", "night", "tiger", "snow", "od", "multi"}
local si = 0
for _, n in ipairs({"WallShelfW", "WallShelfE"}) do
	local u = shopP:FindFirstChild(n)
	if u then
		for _, sh in ipairs(u:GetChildren()) do
			if sh.Name:match("^Shelf%d") then
				-- shelf local frame: X along the shelf, Z = depth (the unit's front is -Z of its base frame)
				local cf, sz = sh.CFrame, sh.Size
				local nStack = math.floor((sz.X - 0.2) / 1.15)
				for k = 0, nStack - 1 do
					si += 1
					local key = SHIRTS[(si % #SHIRTS) + 1]
					local x = -sz.X / 2 + 0.2 + 0.5 + k * 1.15
					local layers = 2 + (si % 2)
					for l = 0, layers - 1 do
						local key2 = SHIRTS[((si + l) % #SHIRTS) + 1]
						local pc = cf * CFrame.new(x, sz.Y / 2 + 0.09 + l * 0.17, 0.02) * CFrame.Angles(0, math.rad((l % 2) * 3 - 1.5), 0)
						part(fold, "Shirt", Vector3.new(0.95, 0.16, sz.Z * 0.72), pc, CAMO[key2][1], Enum.Material.Fabric)
						local bl = CAMO[key2][2]
						if #bl > 0 then
							part(fold, "ShirtFold", Vector3.new(0.5, 0.17, sz.Z * 0.3), pc * CFrame.new(0.12, 0.003, -sz.Z * 0.12), bl[1], Enum.Material.Fabric)
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- 11. A-frame by the door: new text over the old slate (old label hidden, UNDO-able)
---------------------------------------------------------------------------------------------------
local af = shopP:FindFirstChild("AFrame")
local slate = af and af:FindFirstChild("Slate")
if slate then
	for _, g in ipairs(slate:GetChildren()) do if g:IsA("SurfaceGui") then setP(g, {Enabled = false}) end end
	local holder = grp("AFrameText")
	local g = gui(slate, Enum.NormalId.Front, 90, {
		{text = "OUTFITTERS", x = 0.05, y = 0.06, w = 0.9, h = 0.13, color = CREAM},
		{text = "NEW", x = 0.05, y = 0.24, w = 0.9, h = 0.2, color = C(176, 192, 108)},
		{text = "DROPS DAILY", x = 0.05, y = 0.44, w = 0.9, h = 0.1, color = CREAM},
		{text = "UNIFORMS · CAMO", x = 0.05, y = 0.62, w = 0.9, h = 0.09, bold = false, color = SAGE},
		{text = "TAGS · PATCHES", x = 0.05, y = 0.74, w = 0.9, h = 0.09, bold = false, color = SAGE},
	})
	-- keep the new gui under Round3 (adorned to the slate) so a re-run replaces it
	g.Parent = holder
	g.Adornee = slate
end

---------------------------------------------------------------------------------------------------
root.Parent = shopP
local n, nl = 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 elseif d:IsA("Light") then nl += 1 end
end
say(("Round3: %d parts, %d new lights; tagged %d originals"):format(n, nl, (function()
	local c = 0; for _, d in ipairs(LM:GetDescendants()) do if d:GetAttribute(ATTR) then c += 1 end end; return c end)()))
return table.concat(log, "\n")
