--[[ fix/place_hub1.lua : place the hub1 kit in Tacticals_rebuild.rbxl (LOCAL copy only; never the live place).
Idempotent: run as often as you like. Run with UNDO = true to put everything back (kit returns to Workspace.hub_r1,
old shell un-hidden, spawns restored, overrides restored, LobbyFX pulse height restored).
Runner: python tools/run_luau.py fix/place_hub1.lua [UNDO]   (sends this file through the stdio MCP bridge)
Data sources: kit/hub_r1_manifest.json (slot -> colour/material), tex/asset_ids.json (uploaded ids, group Gunsy Funsy),
tex/textures.json (StudsPerTile), notes/hub1_kit.md (hide list, collision), notes/hooks.md (hooks to keep).
]]
local UNDO = false --@UNDO

local MS = game:GetService("MaterialService")
local SS = game:GetService("ServerStorage")
local LM = workspace:WaitForChild("LobbyMap")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end

---------------------------------------------------------------- ids (own uploads, Gunsy Funsy)
local ID = {
	concrete_smooth  = {c = "rbxassetid://127975492069244", n = "rbxassetid://134698104080164", r = "rbxassetid://77416348183156"},
	concrete_panels  = {c = "rbxassetid://92560807606107",  n = "rbxassetid://111307272317855", r = "rbxassetid://139321089617915"},
	corrugated_fine  = {c = "rbxassetid://110810239487571", n = "rbxassetid://100113956000407", r = "rbxassetid://130426907573272"},
	corrugated_metal = {c = "rbxassetid://129791259335401", n = "rbxassetid://73528077989924",  r = "rbxassetid://136833705922600", m = "rbxassetid://123612396854451"},
	floor_concrete   = {c = "rbxassetid://101352263098180", n = "rbxassetid://103891709493199", r = "rbxassetid://135116245015934"},
	metal_floorplate = {c = "rbxassetid://123397734921602", n = "rbxassetid://136513665535643", r = "rbxassetid://99797696454588",  m = "rbxassetid://123612396854451"},
	metal_satin      = {c = "rbxassetid://122079640706171", n = "rbxassetid://140513148485798", r = "rbxassetid://133742999882020", m = "rbxassetid://123612396854451"},
}
local TEX = {
	chevron = "rbxassetid://98980453133784", grime = "rbxassetid://110762390496312", hazard = "rbxassetid://79584884795039",
	lane = "rbxassetid://89900701267026", louvre = "rbxassetid://136153789620409", grid = "rbxassetid://86361987736184",
	panel_lines = "rbxassetid://119251552384756", trim_strip = "rbxassetid://102180834807718",
	grate = "rbxassetid://119843963596060",
}
-- name, base, set, StudsPerTile, pattern
local VARIANTS = {
	{"TacConcrete",        Enum.Material.Concrete, "concrete_smooth",  12, Enum.MaterialPattern.Organic},
	{"TacConcretePanels",  Enum.Material.Concrete, "concrete_panels",  20, Enum.MaterialPattern.Regular},
	{"TacRibbed",          Enum.Material.Concrete, "corrugated_fine",  10, Enum.MaterialPattern.Regular},
	{"TacFloorConcrete",   Enum.Material.Concrete, "floor_concrete",   20, Enum.MaterialPattern.Organic},
	{"TacCorrugatedMetal", Enum.Material.Metal,    "corrugated_metal", 16, Enum.MaterialPattern.Regular},
	{"TacFloorPlate",      Enum.Material.Metal,    "metal_floorplate", 20, Enum.MaterialPattern.Regular},
	{"TacMetal",           Enum.Material.Metal,    "metal_satin",      10, Enum.MaterialPattern.Regular},
}

---------------------------------------------------------------- slot table (= kit/hub_r1_manifest.json)
local M = Enum.Material
local SLOT = {
	floor_field   = {62, 62, 60, M.Concrete, "TacFloorConcrete"},
	floor_border  = {36, 36, 34, M.Concrete, "TacFloorConcrete"},
	floor_insert  = {80, 79, 76, M.Metal, "TacCorrugatedMetal"},
	plate_metal   = {108, 107, 104, M.Metal, "TacFloorPlate"},
	disc_plate    = {75, 75, 72, M.Metal, "TacFloorPlate"},
	wall_body     = {107, 106, 102, M.Concrete, "TacConcretePanels"},
	wall_plate    = {102, 101, 97, M.Concrete, "TacConcretePanels"},
	wall_light    = {120, 119, 115, M.Concrete, "TacConcrete"},
	wall_kick     = {88, 87, 83, M.Concrete, "TacConcrete"},
	wall_dark     = {79, 78, 74, M.Concrete, "TacConcrete"},
	stair         = {94, 93, 89, M.Concrete, "TacConcrete"},
	ceiling       = {112, 111, 107, M.Concrete, "TacConcrete"},
	wall_upper    = {141, 140, 134, M.Concrete, "TacRibbed"},
	band_olive    = {120, 136, 66, M.Concrete, "TacConcrete"},   -- manifest 138,156,74 read lime in Studio; stepped down per hub1_kit.md
	trim_metal    = {108, 107, 104, M.Metal, "TacMetal"},
	trim_light    = {124, 123, 119, M.Metal, "TacMetal"},
	beam_metal    = {67, 67, 65, M.Metal, "TacMetal"},
	dark_metal    = {48, 48, 46, M.Metal, "TacMetal"},
	door_leaf     = {72, 72, 70, M.Metal, "TacCorrugatedMetal"},
	ceiling_gloss = {66, 68, 62, M.SmoothPlastic, ""},
	neon_lamp     = {161, 157, 145, M.Neon, ""},
	neon_cream    = {180, 177, 166, M.Neon, ""},
	neon_olive    = {88, 101, 48, M.Neon, ""},        -- manifest 107,122,58 glowed lime; Neon brightens, so darker base
	void          = {10, 12, 10, M.Neon, ""},
	glass         = {150, 190, 215, M.Glass, ""},
	label_cream   = {236, 232, 218, M.SmoothPlastic, ""},
	sign_board    = {39, 40, 37, M.SmoothPlastic, ""},
	hazard        = {10, 12, 10, M.SmoothPlastic, ""},   -- texture carries cream/near-black stripes
	grate         = {22, 23, 21, M.SmoothPlastic, ""},
	crate_green   = {65, 94, 56, M.SmoothPlastic, ""},
	case_dark     = {48, 49, 46, M.Metal, "TacMetal"},
	drum_olive    = {107, 122, 58, M.Metal, "TacMetal"},
	disc_center   = {107, 122, 58, M.SmoothPlastic, ""},
	screen        = {18, 22, 20, M.Glass, ""},
}

---------------------------------------------------------------- collision rules (hub1_kit.md step 4)
local NOCOLLIDE_PIECE = {H_Roof = true, H_Beams = true, H_Skylight = true, H_CeilLights = true, H_WallLights = true, H_Signs = true,
	H_FloorLines = true, H_Catwalks = true, H_Bridges = true}
local NOCOLLIDE_SLOT = {neon_lamp = true, neon_cream = true, neon_olive = true, void = true, glass = true, label_cream = true,
	wall_upper = true, wall_dark = true, hazard = true, screen = true}
-- cornice (wall_light 52-58) and the y36 trim on the long/end walls are visual only
local NOCOLLIDE_NAME = {H_WallN__wall_light = true, H_WallS__wall_light = true, H_WallE__wall_light = true, H_WallW__wall_light = true,
	H_WallN__trim_light = true, H_WallS__trim_light = true, H_WallE__trim_light = true}
-- flat slabs get Box, everything with openings/steps PreciseConvexDecomposition
local BOX = {H_Floor__floor_field = true, H_Floor__floor_border = true, H_Floor__floor_insert = true, H_Tunnel__plate_metal = true,
	H_Tunnel__floor_border = true, H_Landing__plate_metal = true, H_Landing__stair = true}

---------------------------------------------------------------- hide list (hub1_kit.md mapping table)
local HIDE_UNIQUE_PREFIX = {"U_Floor__", "U_Ceiling__", "U_Braces__", "U_Spine__", "U_Cables__", "U_PodCables__", "U_WestWall__", "U_GateBulkhead__"}
local HIDE_UNIQUE_NAME = {
	U_SpawnDisc__spawn_logo = true,                     -- AssetCheck name: kept present, hidden
	U_East__panel_metal = true, U_East__emit_amber = true, U_East__emit_cyan = true, U_East__steel = true, -- riser/stairs/rails (hub side only)
	U_GateN__emit_amber = true, U_GateS__emit_amber = true,                                               -- hub-face strip, now inside the new wall
}
-- kept on purpose: U_East__concrete / dark_metal / floor_metal (they also carry the Duels floor y16 and Duels base walls x<-90),
-- U_GateN/S corridor meshes (corridor beyond the hub mouth stays as is), everything of Shop/Armory/Exfil/Duels/EnergyWall.
local HIDE_FOLDERS = {"Instances", "HubProps", "Clutter"}
-- the four hub sign models stay in LobbyMap.Signs (folder kept, names kept) but are hidden: their text now sits on the
-- H_Signs boards as SurfaceGuis (Hub1.Overlays.SignText_*). TRAINING signs (y 626) are untouched.
local HIDE_SIGNS = {"U_Sign_SHOP", "U_Sign_ARMORY", "U_Sign_EXFIL", "U_Sign_DUELS"}

---------------------------------------------------------------- helpers
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function ensureFolder(parent, name, class)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new(class or "Folder"); f.Name = name; f.Parent = parent end
	return f
end
local function hideOne(inst)
	if inst:GetAttribute("Hub1Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Hub1_T", inst.Transparency); inst:SetAttribute("Hub1_C", inst.CanCollide)
		inst:SetAttribute("Hub1_Q", inst.CanQuery); inst:SetAttribute("Hub1_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then -- Texture inherits Decal
		inst:SetAttribute("Hub1_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst:SetAttribute("Hub1_E", inst.Enabled); inst.Enabled = false
	else
		return 0
	end
	inst:SetAttribute("Hub1Hidden", true)
	return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("Hub1Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Hub1_T"); inst.CanCollide = inst:GetAttribute("Hub1_C")
		inst.CanQuery = inst:GetAttribute("Hub1_Q"); inst.CanTouch = inst:GetAttribute("Hub1_Tc")
	elseif inst:IsA("Decal") then
		inst.Transparency = inst:GetAttribute("Hub1_T")
	else
		inst.Enabled = inst:GetAttribute("Hub1_E")
	end
	for _, a in {"Hub1Hidden", "Hub1_T", "Hub1_C", "Hub1_Q", "Hub1_Tc", "Hub1_E"} do inst:SetAttribute(a, nil) end
	return 1
end
local function hideTree(root, fn)
	local n = fn(root)
	for _, d in root:GetDescendants() do n += fn(d) end
	return n
end
local function shellTargets()
	local list = {}
	for _, c in LM.Unique:GetChildren() do
		local hit = HIDE_UNIQUE_NAME[c.Name]
		for _, p in HIDE_UNIQUE_PREFIX do if c.Name:sub(1, #p) == p then hit = true end end
		if hit then table.insert(list, c) end
	end
	for _, fn in HIDE_FOLDERS do local f = LM:FindFirstChild(fn); if f then for _, c in f:GetChildren() do table.insert(list, c) end end end
	for _, n in HIDE_SIGNS do local s = LM.Signs:FindFirstChild(n); if s then table.insert(list, s) end end
	return list
end

-- LobbyFX walkway pulses: client script hard-codes y 0.03, which puts the 0.06 pulse bottom on the floor-field top (0.00)
-- and through the lane insert top (0.03) -> z-fight while the pulse fades. Raise to 0.08 (pulse 0.05..0.11).
local PULSE_OLD, PULSE_NEW = "CFrame.new(x, 0.03, s.z)", "CFrame.new(x, 0.08, s.z)"
-- LobbyFX drone loop: y 22 +-3 (+1 model half height) clips the new bridge undersides (24.8) at x +-49; lower the
-- loop centre to 20 (max top 24.0, 0.8 clear).
local DRONE_EDITS = {
	{"Vector3.new(math.sin(a) * 62, 22 + math.sin(a * 2.3) * 3", "Vector3.new(math.sin(a) * 62, 20 + math.sin(a * 2.3) * 3"},
	{"Vector3.new(math.sin(a + 0.05) * 62, 22 + math.sin((a + 0.05) * 2.3) * 3", "Vector3.new(math.sin(a + 0.05) * 62, 20 + math.sin((a + 0.05) * 2.3) * 3"},
}
local function setPulse(fromS, toS)
	local fx = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("LobbyFX")
	if not fx then return "LobbyFX missing" end
	local src = fx.Source
	local i = src:find(fromS, 1, true)
	if not i then return src:find(toS, 1, true) and "already" or "pattern not found" end
	local new = src:sub(1, i - 1) .. toS .. src:sub(i + #fromS)
	local ok, err = pcall(function()
		game:GetService("ScriptEditorService"):UpdateSourceAsync(fx, function() return new end)
	end)
	if not ok then ok, err = pcall(function() fx.Source = new end) end
	return ok and "changed" or ("failed " .. tostring(err))
end

---------------------------------------------------------------- UNDO
if UNDO then
	local n = 0
	for _, d in LM:GetDescendants() do if d:GetAttribute("Hub1Hidden") then n += unhideOne(d) end end
	say("unhidden", n)
	local hub = LM:FindFirstChild("Hub1")
	if hub then
		local m = workspace:FindFirstChild("hub_r1") or Instance.new("Model"); m.Name = "hub_r1"; m.Parent = workspace
		for _, d in hub:GetDescendants() do if d:IsA("MeshPart") then d.Parent = m end end
		hub:Destroy(); say("kit back in Workspace.hub_r1")
	end
	local rem = SS:FindFirstChild("_RebuildRemoved")
	if rem then
		for _, c in rem:GetChildren() do
			if c.Name == "LobbySpawn" then c.Parent = LM
			elseif c.Name == "K_Scale1" or c.Name == "K_Marker1" then c.Parent = workspace:FindFirstChild("hub_r1") end
		end
	end
	for _, c in LM:GetChildren() do
		if c.Name == "LobbySpawn" and c:GetAttribute("Hub1_OrigPos") then c.Position = c:GetAttribute("Hub1_OrigPos"); c:SetAttribute("Hub1_OrigPos", nil) end
	end
	local tex = SS:FindFirstChild("hub_r1_tex"); if tex then tex.Parent = workspace end
	local vf = MS:FindFirstChild("TacHub1")
	if vf then
		MS:SetBaseMaterialOverride(Enum.Material.Concrete, vf:GetAttribute("PrevConcrete") or "")
		MS:SetBaseMaterialOverride(Enum.Material.Metal, vf:GetAttribute("PrevMetal") or "")
		vf:Destroy()
	end
	say("pulse", setPulse(PULSE_NEW, PULSE_OLD))
	for _, e in DRONE_EDITS do say("drone", setPulse(e[2], e[1])) end
	local npc = LM.NPCs:FindFirstChild("NPC_DuelsOfficer")
	if npc and npc:GetAttribute("Hub1_OrigPivot") then npc:PivotTo(npc:GetAttribute("Hub1_OrigPivot")); npc:SetAttribute("Hub1_OrigPivot", nil) end
	return table.concat(log, "\n")
end

---------------------------------------------------------------- 1. MaterialVariants + overrides
local vf = ensureFolder(MS, "TacHub1")
if vf:GetAttribute("PrevConcrete") == nil then
	vf:SetAttribute("PrevConcrete", MS:GetBaseMaterialOverride(Enum.Material.Concrete))
	vf:SetAttribute("PrevMetal", MS:GetBaseMaterialOverride(Enum.Material.Metal))
end
for _, v in VARIANTS do
	local name, base, set, spt, pat = v[1], v[2], v[3], v[4], v[5]
	local mv = vf:FindFirstChild(name) or Instance.new("MaterialVariant")
	mv.Name = name; mv.BaseMaterial = base; mv.StudsPerTile = spt; mv.MaterialPattern = pat
	local ids = ID[set]
	mv.ColorMap = ids.c; mv.NormalMap = ids.n; mv.RoughnessMap = ids.r; mv.MetalnessMap = ids.m or ""
	mv.Parent = vf
end
MS:SetBaseMaterialOverride(Enum.Material.Concrete, "TacConcrete")
MS:SetBaseMaterialOverride(Enum.Material.Metal, "TacMetal")
say("variants", #vf:GetChildren(), "overrides", MS:GetBaseMaterialOverride(Enum.Material.Concrete), MS:GetBaseMaterialOverride(Enum.Material.Metal))

---------------------------------------------------------------- 2. move kit into LobbyMap.Hub1 (one Model per piece)
local hub = ensureFolder(LM, "Hub1")
local src = workspace:FindFirstChild("hub_r1")
local rem = ensureFolder(SS, "_RebuildRemoved")
if src then
	for _, c in src:GetChildren() do
		if c.Name == "K_Scale1" or c.Name == "K_Marker1" then
			c.Parent = rem
		elseif c:IsA("MeshPart") then
			local piece = c.Name:match("^(.-)__") or "Misc"
			ensureFolder(hub, piece, "Model")
			c.Parent = hub[piece]
		end
	end
	if #src:GetChildren() == 0 then src:Destroy() end
end
for _, d in hub:GetDescendants() do
	if d.Name == "K_Scale1" or d.Name == "K_Marker1" then d.Parent = rem end
end
task.wait()

---------------------------------------------------------------- 3. per-mesh look + collision
local function overlay(part, name, tex, faces, u, v, color, transp)
	for _, f in faces do
		local nm = "Tac_" .. name .. "_" .. f.Name
		local t = part:FindFirstChild(nm) or Instance.new("Texture")
		t.Name = nm; t.Texture = tex; t.Face = f; t.StudsPerTileU = u; t.StudsPerTileV = v
		t.Color3 = color; t.Transparency = transp; t.Parent = part
	end
end
local F = Enum.NormalId
local SIDES = {F.Front, F.Back, F.Left, F.Right}
local nMesh, nCol = 0, 0
for _, part in hub:GetDescendants() do
	if not part:IsA("MeshPart") then continue end
	local piece, slot = part.Name:match("^(.-)__(.+)$")
	local s = SLOT[slot]
	if not s then say("no slot for", part.Name); continue end
	part.Anchored = true
	part.Color = Color3.fromRGB(s[1], s[2], s[3])
	part.Material = s[4]
	part.MaterialVariant = s[5]
	part.Transparency = (slot == "glass") and 0.6 or 0
	part.Reflectance = 0
	part.CastShadow = not (s[4] == M.Neon or slot == "glass")
	local collide = not (NOCOLLIDE_PIECE[piece] or NOCOLLIDE_SLOT[slot] or NOCOLLIDE_NAME[part.Name])
	part.CanCollide = collide; part.CanQuery = collide; part.CanTouch = false
	if collide then
		nCol += 1
		local cf = BOX[part.Name] and Enum.CollisionFidelity.Box or Enum.CollisionFidelity.PreciseConvexDecomposition
		if part.CollisionFidelity ~= cf then part.CollisionFidelity = cf end
	end
	-- overlays
	if slot == "hazard" then overlay(part, "hazard", TEX.hazard, {F.Top, F.Front, F.Back}, 4, 1, Color3.new(1, 1, 1), 0) end
	if slot == "grate" then overlay(part, "grate", TEX.grate, {F.Top}, 3, 3, Color3.fromRGB(76, 76, 72), 0) end
	if slot == "wall_kick" then overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.93) end
	if piece == "H_Props" and (slot == "crate_green" or slot == "case_dark" or slot == "drum_olive") then
		overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.94)
	end
	if piece == "H_CeilLights" and slot == "neon_lamp" then overlay(part, "louvre", TEX.louvre, {F.Bottom}, 0.6, 1, Color3.new(0, 0, 0), 0.5) end
	if piece == "H_SpawnDisc" and slot == "disc_plate" then overlay(part, "panel", TEX.panel_lines, {F.Top}, 20, 20, Color3.fromRGB(81, 81, 78), 0.35) end
	if (piece == "H_GateN" or piece == "H_GateS" or piece == "H_TunnelPortal" or piece == "H_DuelsDoor") and slot == "trim_metal" then
		overlay(part, "trim", TEX.trim_strip, {F.Left, F.Right}, 8, 1, Color3.fromRGB(70, 70, 67), 0)
	end
	nMesh += 1
end
say("meshes styled", nMesh, "colliding", nCol)
task.wait()

---------------------------------------------------------------- 3b. floor overlays on carrier parts (lane marking N/S, chevrons into the gates)
local ov = ensureFolder(hub, "Overlays", "Model")
local function carrier(name, cf, size)
	local p = ov:FindFirstChild(name) or Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = size; p.CFrame = cf; p.Material = M.SmoothPlastic
	p:SetAttribute("NotCover", true)
	p.Parent = ov
	return p
end
-- N/S walkway lanes between the disc (r 13.7) and the gate thresholds (z 41.4); insert top 0.03, carrier top 0.06
for _, sgn in {1, -1} do
	local zc = sgn * 27.6
	-- rotate 90 deg so the 16-stud U of the lane image runs along the walkway (z)
	local lane = carrier(sgn > 0 and "LaneN" or "LaneS", CFrame.new(0, 0.05, zc) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(27, 0.02, 3.2))
	-- one tile across (V = width) so the image reads as a single centre runway marking, not 2.6 repeats
	overlay(lane, "lane", TEX.lane, {F.Top}, 16, 3.2, Color3.fromRGB(236, 232, 218), 0.35)
	for i, z in {33, 37.5} do
		local ch = carrier((sgn > 0 and "ChevN" or "ChevS") .. i, CFrame.new(0, 0.06, sgn * z) * CFrame.Angles(0, math.rad(90 * sgn), 0), Vector3.new(4, 0.02, 4)) -- arrow = local -X: points into the gate
		local d = ch:FindFirstChild("Tac_chevron") or Instance.new("Decal")
		d.Name = "Tac_chevron"; d.Texture = TEX.chevron; d.Face = F.Top; d.Color3 = Color3.fromRGB(236, 232, 218); d.Transparency = 0.15; d.Parent = ch
	end
end

---------------------------------------------------------------- 3c. sign text on the new boards (SurfaceGui on carrier plates; one font, cream, caps)
local SIGNS = {
	{"SignText_SHOP",   CFrame.lookAt(Vector3.new(-3.75, 20.875, 43.0), Vector3.new(-3.75, 20.875, 0)),  Vector3.new(8.5, 3.75, 0.05), "SHOP"},
	{"SignText_ARMORY", CFrame.lookAt(Vector3.new(-3.75, 20.875, -43.0), Vector3.new(-3.75, 20.875, 0)),   Vector3.new(8.5, 3.75, 0.05), "ARMORY"},
	{"SignText_EXFIL",  CFrame.lookAt(Vector3.new(84.7, 27.375, 0.25), Vector3.new(0, 27.375, 0.25)),    Vector3.new(17.5, 3.75, 0.05), "EXFIL"},
	{"SignText_DUELS",  CFrame.lookAt(Vector3.new(-83.1, 12.625, 0), Vector3.new(0, 12.625, 0)),         Vector3.new(13, 3.25, 0.05), "DUELS"},
}
for _, s in SIGNS do
	local p = carrier(s[1], s[2], s[3])
	local g = p:FindFirstChild("Text") or Instance.new("SurfaceGui")
	g.Name = "Text"; g.Face = F.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
	g.LightInfluence = 0; g.Brightness = 1.2; g.Parent = p
	local l = g:FindFirstChild("Label") or Instance.new("TextLabel")
	l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.8); l.Position = UDim2.fromScale(0, 0.1)
	l.Text = s[4]; l.TextScaled = true; l.TextColor3 = Color3.fromRGB(236, 232, 218)
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy); l.Parent = g
end

---------------------------------------------------------------- 4. hide the old shell (restorable)
local hidden = 0
for i, inst in shellTargets() do
	hidden += hideTree(inst, hideOne)
	if i % 60 == 0 then task.wait() end
end
say("hidden instances (this run)", hidden)

---------------------------------------------------------------- 5. spawn: one LobbySpawn on the disc top (0.6)
local spawns = {}
for _, c in LM:GetChildren() do if c.Name == "LobbySpawn" and c:IsA("SpawnLocation") then table.insert(spawns, c) end end
for i = 2, #spawns do spawns[i].Parent = rem end
local sp = spawns[1]
if sp then
	if sp:GetAttribute("Hub1_OrigPos") == nil then sp:SetAttribute("Hub1_OrigPos", sp.Position) end
	sp.Position = Vector3.new(0, 0.6 + sp.Size.Y / 2, 0)
	say("spawns kept 1, moved", #spawns - 1, "pos", sp.Position)
end

---------------------------------------------------------------- 6. texture carriers to ServerStorage (keeps the uploaded ids referenced)
local tex = workspace:FindFirstChild("hub_r1_tex")
if tex then tex.Parent = SS end
say("hub_r1_tex in", (SS:FindFirstChild("hub_r1_tex") and "ServerStorage") or "?")

---------------------------------------------------------------- 7. LobbyFX pulse height
say("pulse", setPulse(PULSE_OLD, PULSE_NEW))
for _, e in DRONE_EDITS do say("drone", setPulse(e[1], e[2])) end

---------------------------------------------------------------- 8. NPC_DuelsOfficer: was at x -88, half inside the new Duels door cheek (x -87.8..-95,
-- z 5.8..8.8). Nudge 1.6 east and 0.6 south (right arm cleared the stair rail) onto the open top landing, same height/facing. Original pivot kept for UNDO.
local npc = LM.NPCs:FindFirstChild("NPC_DuelsOfficer")
if npc then
	local orig = npc:GetAttribute("Hub1_OrigPivot")
	if orig == nil then orig = npc:GetPivot(); npc:SetAttribute("Hub1_OrigPivot", orig) end
	npc:PivotTo(orig + Vector3.new(1.6, 0, -0.6))
	say("NPC_DuelsOfficer pivot", npc:GetPivot().Position)
end

return table.concat(log, "\n")
