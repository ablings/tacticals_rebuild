--[[ fix/place_rooms3.lua : place the rooms3 kit (Duels hall + west gate/deck, Exfil hangar + helipad) in Tacticals_rebuild.rbxl
(LOCAL copy only; never the live place). Runs after fix/place_hub1.lua, fix/hub2.lua and fix/place_rooms2.lua.
Idempotent: run as often as you like. UNDO = true puts everything back (kit returns to Workspace.rooms3 with its imported look,
old Duels/Exfil shell un-hidden, energy-wall FX back (tags too), L_Hangar and the two 1v1 Holo/PostCollide parts back,
K_Scale3/K_Marker3 back in rooms3).
Runner: python tools/run_luau.py fix/place_rooms3.lua [UNDO]
Data: kit/rooms3_manifest.json (slot -> colour/material/variant/collision), notes/rooms3_kit.md (hide/keep, hooks),
notes/hub2.md + notes/rooms2_place.md (Future tuning). Report: notes/rooms3_place.md. Own assets only (TacHub1 variants, own ids).
]]
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
local M, F = Enum.Material, Enum.NormalId

---------------------------------------------------------------- tuned values (rooms2_place / hub2: measured under Future)
local OLIVE_BAND = rgb(111, 114, 57)   -- manifest 120,136,66 (lime under Future)
local OLIVE_NEON = rgb(66, 72, 36)     -- manifest 88,101,48
-- walkway metal floor plates (passage plate, lane plate at the medallion, mouth sill): TacFloorPlate 108 renders cool and light
local NAME_COLOUR = {}
for _, n in {"D_Pass__plate_metal", "D_Floor__plate_metal", "E_Floor__plate_metal"} do NAME_COLOUR[n] = rgb(95, 85, 78) end

---------------------------------------------------------------- slot table (= kit/rooms3_manifest.json, with the tuning above)
local SLOT = {
	floor_field   = {rgb(76, 62, 50), M.Concrete, "TacFloorConcrete"},
	floor_border  = {rgb(46, 38, 30), M.Concrete, "TacFloorConcrete"},
	floor_insert  = {rgb(94, 80, 66), M.Metal, "TacCorrugatedMetal"},
	plate_metal   = {rgb(108, 107, 104), M.Metal, "TacFloorPlate"},
	wall_body     = {rgb(107, 106, 102), M.Concrete, "TacConcretePanels"},
	wall_plate    = {rgb(102, 101, 97), M.Concrete, "TacConcretePanels"},
	wall_light    = {rgb(120, 119, 115), M.Concrete, "TacConcrete"},
	wall_kick     = {rgb(88, 87, 83), M.Concrete, "TacConcrete"},
	wall_dark     = {rgb(79, 78, 74), M.Concrete, "TacConcrete"},
	wall_upper    = {rgb(141, 140, 134), M.Concrete, "TacRibbed"},
	ceiling       = {rgb(112, 111, 107), M.Concrete, "TacConcrete"},
	ceiling_gloss = {rgb(66, 68, 62), M.SmoothPlastic, ""},
	band_olive    = {OLIVE_BAND, M.Concrete, "TacConcrete"},
	trim_metal    = {rgb(108, 107, 104), M.Metal, "TacMetal"},
	trim_light    = {rgb(124, 123, 119), M.Metal, "TacMetal"},
	beam_metal    = {rgb(67, 67, 65), M.Metal, "TacMetal"},
	dark_metal    = {rgb(48, 48, 46), M.Metal, "TacMetal"},
	door_leaf     = {rgb(72, 72, 70), M.Metal, "TacCorrugatedMetal"},
	neon_lamp     = {rgb(161, 157, 145), M.Neon, ""},
	neon_cream    = {rgb(180, 177, 166), M.Neon, ""},
	neon_olive    = {OLIVE_NEON, M.Neon, ""},
	glass         = {rgb(150, 190, 215), M.Glass, ""},
	label_cream   = {rgb(236, 232, 218), M.SmoothPlastic, ""},
	sign_board    = {rgb(39, 40, 37), M.SmoothPlastic, ""},
	hazard        = {rgb(10, 12, 10), M.SmoothPlastic, ""},      -- as hub1/rooms2: the texture carries the stripes
	crate_green   = {rgb(65, 94, 56), M.SmoothPlastic, ""},
	case_dark     = {rgb(48, 49, 46), M.SmoothPlastic, ""},
	drum_olive    = {rgb(70, 82, 52), M.Metal, ""},
	disc_center   = {rgb(92, 90, 48), M.SmoothPlastic, ""},      -- manifest 107,122,58 (rooms2 dais cap value)
	screen        = {rgb(18, 22, 20), M.Glass, ""},
	clip          = {rgb(255, 255, 255), M.SmoothPlastic, ""},   -- invisible clip walls (Transparency 1, CanQuery false)
}
local TEX = {hazard = "rbxassetid://79584884795039", grime = "rbxassetid://110762390496312",
	louvre = "rbxassetid://136153789620409", panel_lines = "rbxassetid://119251552384756"}

---------------------------------------------------------------- collision (generated from kit/rooms3_manifest.json)
local NOCOLLIDE = {D_Walls__glass = true, D_Lights__neon_lamp = true, D_Lights__trim_metal = true, D_Lights__dark_metal = true, D_Door__hazard = true, D_Signs__label_cream = true, D_West__glass = true, D_West__hazard = true, D_Signs__sign_board = true, D_Signs__neon_olive = true, D_Pass__neon_cream = true, D_Pass__neon_lamp = true, D_Pass__hazard = true, D_Lines__neon_cream = true, D_Lines__neon_olive = true, D_Pads__label_cream = true, D_Roof__ceiling = true, D_Roof__ceiling_gloss = true, D_Roof__trim_metal = true, D_Roof__trim_light = true, D_Trusses__neon_olive = true, D_Trusses__beam_metal = true, D_Base__wall_dark = true, D_Base__trim_metal = true, D_Base__band_olive = true, D_Base__beam_metal = true, D_Deck__hazard = true, D_DeckRail__neon_cream = true, D_Props__label_cream = true, D_Props__neon_lamp = true, D_Props__neon_olive = true, E_Lights__trim_metal = true, E_Lights__neon_lamp = true, E_Lights__dark_metal = true, E_Portal__hazard = true, E_Signs__label_cream = true, E_Ceiling__ceiling = true, E_Ceiling__ceiling_gloss = true, E_Ceiling__trim_metal = true, E_Beams__beam_metal = true, E_Signs__sign_board = true, E_Signs__neon_olive = true, E_Lines__neon_cream = true, E_Floor__hazard = true, E_Helipad__label_cream = true, E_Helipad__case_dark = true, E_Helipad__hazard = true, E_Helipad__neon_cream = true, E_Lines__neon_olive = true, E_Base__wall_dark = true, E_Base__band_olive = true, E_Base__beam_metal = true, E_Props__label_cream = true, E_Props__neon_lamp = true, E_Gear__label_cream = true, E_Gear__screen = true, E_Gear__neon_olive = true, E_Gear__neon_lamp = true}
local BOX = {D_Pass__plate_metal = true, D_Pass__floor_border = true, D_Floor__floor_field = true, D_Floor__floor_border = true, D_Floor__floor_insert = true, D_Floor__plate_metal = true, D_Deck__floor_field = true, D_Deck__floor_border = true, D_Deck__floor_insert = true, D_Deck__wall_dark = true, E_Floor__floor_field = true, E_Floor__floor_border = true, E_Floor__floor_insert = true, E_Floor__plate_metal = true, X_Clip__clip = true}

---------------------------------------------------------------- hooks: new homes (notes/rooms3_kit.md hooks table)
local L_HANGAR_HOME = Vector3.new(114, 19.0, 0)        -- under the E_Lights downlight housing (was y 15)
-- 1v1 pad boards: the hub1 west wall (x -95..-90) buries the old Holo (x -92.8) and PostCollide (x -93.8..-91.8).
-- Move them onto the kit's 1v1 pylon (x -97.6..-95.6, z +-17.5..19.5). sign = z side of the pad.
local ONE_V_ONE = {Pad_1v1_A = -1, Pad_1v1_B = 1}
-- Holo: rooms3_kit.md proposed (-96.6, 24.5, +-18.5) over the pylon, but the PadBoards billboard is 11 wide and only 1.6 studs
-- from the wall face there: 40 % of it was behind the wall from the pads, the door and the hall (ray test), and QueueManager's
-- stepOffCFrame (dir = Holo -> team zone) put Team2 leavers inside the 3v3 Team1 zone. At x -100.5 (over the pad's centre line,
-- between the two team cells) the board is 100 % visible from every viewpoint and both step-off spots are free floor in no zone.
local HOLO_POS = Vector3.new(-100.5, 24.5, 18.5)       -- z multiplied by the sign
local POST_POS = Vector3.new(-96.6, 18.4, 18.5)        -- inside the kit pylon (x -97.6..-95.6); same size 2 x 4.8 x 2, bottom 16.0
-- Duels doorway floor: the hub1 west wall has no floor through its door (x -95..-90); the old U_East / U_DuelsShell meshes carried
-- it. Own threshold plate from the Duels floor to the hub top landing plate (west edge x -90.0), top 16.0.
local DOOR_FILL = {x0 = -95.3, x1 = -90.0, z = 5.6, top = 16.0}
-- sign text on solid backing plates in front of the boards (hub2 lesson): {name, board mesh, face normal x sign, centre y,
-- centre z, plate w (along z), plate h, text}. Boards face along x.
local SIGNS = {
	{"SignText_Deck", "D_Signs__sign_board", 1, 34.0, 0, 8.8, 1.5, "DECK"},       -- over the west portal, faces the hall (+x)
	{"SignText_Exfil", "E_Signs__sign_board", -1, 16.65, 0, 10.6, 1.55, "EXFIL"}, -- hangar header, faces the tunnel (-x)
}

---------------------------------------------------------------- hide helpers (own attribute set Rooms3_*, independent of Hub1/Hub2/Rooms2)
local UNTAG = {"LobbySpark", "LobbyBeacon", "LobbyRun"} -- LobbyFX drives these by tag (Emit / Transparency): untag, kept in Rooms3_Tags
local function hideOne(inst)
	if inst:GetAttribute("Rooms3Hidden") or inst:GetAttribute("Hub1Hidden") or inst:GetAttribute("Hub2Hidden") or inst:GetAttribute("Rooms2Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Rooms3_T", inst.Transparency); inst:SetAttribute("Rooms3_C", inst.CanCollide)
		inst:SetAttribute("Rooms3_Q", inst.CanQuery); inst:SetAttribute("Rooms3_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then
		inst:SetAttribute("Rooms3_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst:SetAttribute("Rooms3_E", inst.Enabled); inst.Enabled = false
	else
		return 0
	end
	local tags = {}
	for _, t in UNTAG do if CS:HasTag(inst, t) then table.insert(tags, t); CS:RemoveTag(inst, t) end end
	if #tags > 0 then inst:SetAttribute("Rooms3_Tags", table.concat(tags, ",")) end
	inst:SetAttribute("Rooms3Hidden", true)
	return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("Rooms3Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Rooms3_T"); inst.CanCollide = inst:GetAttribute("Rooms3_C")
		inst.CanQuery = inst:GetAttribute("Rooms3_Q"); inst.CanTouch = inst:GetAttribute("Rooms3_Tc")
	elseif inst:IsA("Decal") then
		inst.Transparency = inst:GetAttribute("Rooms3_T")
	else
		inst.Enabled = inst:GetAttribute("Rooms3_E")
	end
	local tags = inst:GetAttribute("Rooms3_Tags")
	if tags then for _, t in string.split(tags, ",") do CS:AddTag(inst, t) end end
	for _, a in {"Rooms3Hidden", "Rooms3_T", "Rooms3_C", "Rooms3_Q", "Rooms3_Tc", "Rooms3_E", "Rooms3_Tags"} do inst:SetAttribute(a, nil) end
	return 1
end
local function hideTree(root)
	local n = hideOne(root)
	for _, d in root:GetDescendants() do n += hideOne(d) end
	return n
end

---------------------------------------------------------------- UNDO
local R3 = LM:FindFirstChild("Rooms3")
local rem = SS:FindFirstChild("_RebuildRemoved")
if UNDO then
	local n = 0
	for _, d in LM:GetDescendants() do if d:GetAttribute("Rooms3Hidden") then n += unhideOne(d) end end
	say("unhidden", n)
	local src = workspace:FindFirstChild("rooms3") or Instance.new("Model"); src.Name = "rooms3"; src.Parent = workspace
	if R3 then
		for _, d in R3:GetDescendants() do
			if d:IsA("MeshPart") then
				local o = d:GetAttribute("Rooms3_Orig")
				if o then
					local c, mat, mv, col, qry, tch, cs, tr, cf = table.unpack(string.split(o, "|"))
					d.Color = Color3.fromHex(c); d.Material = Enum.Material[mat]; d.MaterialVariant = mv
					d.CanCollide = col == "true"; d.CanQuery = qry == "true"; d.CanTouch = tch == "true"; d.CastShadow = cs == "true"
					d.Transparency = tonumber(tr); if d.CollisionFidelity.Name ~= cf then d.CollisionFidelity = Enum.CollisionFidelity[cf] end
					d:SetAttribute("Rooms3_Orig", nil); d:SetAttribute("NotCover", nil)
				end
				for _, t in d:GetChildren() do if t:IsA("Texture") and t.Name:match("^R3_") then t:Destroy() end end
				d.Parent = src
			end
		end
		R3:Destroy(); say("kit back in Workspace.rooms3")
	end
	if rem then for _, c in rem:GetChildren() do if c.Name == "K_Scale3" or c.Name == "K_Marker3" then c.Parent = src end end end
	local lh = LM.Exfil:FindFirstChild("L_Hangar")
	if lh and lh:GetAttribute("Rooms3_OrigCF") then lh.CFrame = lh:GetAttribute("Rooms3_OrigCF"); lh:SetAttribute("Rooms3_OrigCF", nil) end
	for pad in ONE_V_ONE do
		local m = LM.Duels:FindFirstChild(pad)
		for _, nm in {"Holo", "PostCollide"} do
			local p = m and m:FindFirstChild(nm)
			if p and p:GetAttribute("Rooms3_OrigCF") then p.CFrame = p:GetAttribute("Rooms3_OrigCF"); p:SetAttribute("Rooms3_OrigCF", nil); say(pad, nm, "back to", f3(p.Position)) end
		end
	end
	say("UNDO done")
	return table.concat(log, "\n")
end

---------------------------------------------------------------- 1. move the kit into LobbyMap.Rooms3 (one Model per piece); markers out
local function ensure(parent, name, class)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new(class or "Folder"); f.Name = name; f.Parent = parent end
	return f
end
rem = ensure(SS, "_RebuildRemoved")
R3 = ensure(LM, "Rooms3")
local src = workspace:FindFirstChild("rooms3")
if src then
	for _, c in src:GetChildren() do
		if c.Name == "K_Scale3" or c.Name == "K_Marker3" then
			say(c.Name, "at", f3(c.Position), "size", f3(c.Size), "-> ServerStorage._RebuildRemoved")
			c.Parent = rem
		elseif c:IsA("MeshPart") then
			local piece = c.Name:match("^(.-)__") or "Misc"
			c.Parent = ensure(R3, piece, "Model")
		end
	end
	if #src:GetChildren() == 0 then src:Destroy() end
end
say("Rooms3 pieces", #R3:GetChildren(), "markers in _RebuildRemoved:", rem:FindFirstChild("K_Scale3") ~= nil, rem:FindFirstChild("K_Marker3") ~= nil)
task.wait()

---------------------------------------------------------------- 2. per-mesh look, overlays, collision (imported values kept in Rooms3_Orig)
local function overlay(part, name, tex, faces, u, v, color, transp)
	for _, f in faces do
		local nm = "R3_" .. name .. "_" .. f.Name
		local t = part:FindFirstChild(nm) or Instance.new("Texture")
		t.Name = nm; t.Texture = tex; t.Face = f; t.StudsPerTileU = u; t.StudsPerTileV = v
		t.Color3 = color; t.Transparency = transp; t.Parent = part
	end
end
local SIDES = {F.Front, F.Back, F.Left, F.Right}
local nMesh, nCol, nBox = 0, 0, 0
for _, part in R3:GetDescendants() do
	if not part:IsA("MeshPart") then continue end
	local piece, slot = part.Name:match("^(.-)__(.+)$")
	local s = SLOT[slot]
	if not s then say("no slot for", part.Name); continue end
	if part:GetAttribute("Rooms3_Orig") == nil then
		part:SetAttribute("Rooms3_Orig", table.concat({part.Color:ToHex(), part.Material.Name, part.MaterialVariant, tostring(part.CanCollide),
			tostring(part.CanQuery), tostring(part.CanTouch), tostring(part.CastShadow), tostring(part.Transparency), part.CollisionFidelity.Name}, "|"))
	end
	part.Anchored = true
	part.Color = NAME_COLOUR[part.Name] or s[1]; part.Material = s[2]; part.MaterialVariant = s[3]
	part.Transparency = (slot == "glass") and 0.6 or (slot == "clip") and 1 or 0
	part.Reflectance = 0
	part.CastShadow = not (s[2] == M.Neon or slot == "glass" or slot == "clip")
	local collide = not NOCOLLIDE[part.Name]
	part.CanCollide = collide; part.CanQuery = collide and slot ~= "clip"; part.CanTouch = false
	if collide then
		nCol += 1
		-- X_Clip: the manifest says Box, but one box around the whole clip mesh (open edge + both side walls) fills the pad
		-- (x 127.6..152.6, z +-28.6, y 1.4..18) and blocked the walk round the barrier: PCD keeps the separate clip slabs
		local box = BOX[part.Name] and slot ~= "clip"
		local cf = box and Enum.CollisionFidelity.Box or Enum.CollisionFidelity.PreciseConvexDecomposition
		if box then nBox += 1 end
		if part.CollisionFidelity ~= cf then part.CollisionFidelity = cf end
	end
	part:SetAttribute("NotCover", true) -- lobby only; cheap (rooms3_kit.md step 2)
	if slot == "hazard" then overlay(part, "hazard", TEX.hazard, {F.Top}, 4, 1, Color3.new(1, 1, 1), 0) end
	if slot == "wall_kick" then overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.93) end
	if (piece == "D_Props" or piece == "E_Props" or piece == "E_Gear") and (slot == "crate_green" or slot == "case_dark" or slot == "drum_olive") then
		overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.94)
	end
	if (piece == "D_Lights" or piece == "E_Lights" or piece == "D_Pass") and slot == "neon_lamp" then overlay(part, "louvre", TEX.louvre, {F.Bottom}, 0.6, 1, Color3.new(0, 0, 0), 0.5) end
	if piece == "D_Pads" and slot == "plate_metal" then overlay(part, "panel", TEX.panel_lines, {F.Top}, 20, 20, rgb(81, 81, 78), 0.35) end
	nMesh += 1
	if nMesh % 50 == 0 then task.wait() end
end
say("meshes styled", nMesh, "colliding", nCol, "box", nBox)

---------------------------------------------------------------- 2b. Duels doorway threshold plate (collides; NotCover); before the U_East check, which then sees it
do
	local fill = ensure(R3, "D_DoorFill", "Model")
	local p = fill:FindFirstChild("DoorThreshold") or Instance.new("Part")
	p.Name = "DoorThreshold"; p.Anchored = true; p.CanCollide = true; p.CanQuery = true; p.CanTouch = false; p.CastShadow = true
	p.Size = Vector3.new(DOOR_FILL.x1 - DOOR_FILL.x0, 1, DOOR_FILL.z * 2)
	p.CFrame = CFrame.new((DOOR_FILL.x0 + DOOR_FILL.x1) / 2, DOOR_FILL.top - 0.5, 0)
	p.Material = M.Metal; p.MaterialVariant = "TacFloorPlate"; p.Color = rgb(95, 85, 78); p.Reflectance = 0
	p:SetAttribute("NotCover", true); p.Parent = fill
	say("DoorThreshold", f3(p.Position), f3(p.Size))
end

---------------------------------------------------------------- 3. hide the old Duels / energy-wall / Exfil shell and the energy-wall FX (restorable)
local rpAll = RaycastParams.new(); rpAll.FilterType = Enum.RaycastFilterType.Exclude; rpAll.RespectCanCollide = true
local function floorRay(x, z, excl, top)
	rpAll.FilterDescendantsInstances = excl
	local r = workspace:Raycast(Vector3.new(x, top or 30, z), Vector3.new(0, -60, 0), rpAll)
	return r and r.Position.Y, r and r.Instance
end
local targets = {}
local eastList = {}
for _, c in LM.Unique:GetChildren() do
	if c:IsA("BasePart") then
		if c.Name:match("^U_DuelsShell__") or c.Name:match("^U_DuelWalls__") or c.Name:match("^U_DuelPads__") or c.Name:match("^U_EnergyWall__") or c.Name:match("^U_Exfil__") then
			table.insert(targets, c)
		elseif c.Name == "U_East__concrete" or c.Name == "U_East__dark_metal" or c.Name == "U_East__floor_metal" then
			table.insert(eastList, c)
		end
	end
end
-- U_East also reaches into the hub (x up to -72): hide it only if no hub-side walkable surface depends on it (rays with/without it)
local eastSet = {}; for _, c in eastList do eastSet[c] = true end
local lost, onEast = {}, 0
if #eastList > 0 and not eastList[1]:GetAttribute("Rooms3Hidden") then
	local base = {LM.NPCs}
	local without = {LM.NPCs}; for _, c in eastList do table.insert(without, c) end
	for x = -91, -66, 1 do for z = -45, 45, 1 do
		local y1, i1 = floorRay(x, z, base)
		if i1 and eastSet[i1] then
			onEast += 1
			local y2 = floorRay(x, z, without)
			-- allowed: a lip over a hub surface (drop <= 0.6, e.g. the old 4.47 lip over the 4.00 landing); the old riser side ramps
			-- outside the hub riser cheeks (|z| >= 9, x -78..-72: open hub floor at 0 beside the cheeks, not on the route);
			-- the hall corner inside the hub west wall (x -91, |z| 45)
			local ok = (y2 and y1 - y2 <= 0.6) or (y2 and y2 < 0.1 and math.abs(z) >= 9 and x >= -78 and x <= -72) or (x <= -90.5 and math.abs(z) >= 44.5)
			if not ok then table.insert(lost,("(%d,%d) %.2f->%s"):format(x, z, y1, y2 and ("%.2f"):format(y2) or "none")) end
		end
	end end
	say("U_East hub-side check: points whose top surface is U_East", onEast, "lost without it", #lost, #lost > 0 and table.concat(lost, " ", 1, math.min(#lost, 12)) or "")
end
if #lost == 0 then for _, c in eastList do table.insert(targets, c) end else say("WARN U_East kept visible (hub floor depends on it)") end
-- energy-wall FX (the energy wall is now the glazed sky screen); TargetTop, Shafts, DustDuels, FX3 beacons, Lights.PointLight kept
for _, n in {"Arcs", "EnergyMotes", "SparkDuels"} do local p = LM.FX:FindFirstChild(n); if p then table.insert(targets, p) end end
for _, c in LM.Lights:GetChildren() do if c.Name == "EnergyKey" then table.insert(targets, c) end end
local hidden = 0
for i, inst in targets do hidden += hideTree(inst); if i % 40 == 0 then task.wait() end end
say("hide targets", #targets, "hidden instances this run", hidden)
-- hub2's LipPlate covered the old U_East lip at the top landing; with U_East hidden it is a bump: hide it if the floor under it is 16.0
local add = LM.Hub1:FindFirstChild("Hub2Add")
local lipParts = {}
if add then for _, n in {"LipPlate", "LipRampW", "LipRampN", "LipRampS"} do local p = add:FindFirstChild(n); if p then table.insert(lipParts, p) end end end
if #lipParts > 0 and #lost == 0 then
	local excl = {LM.NPCs}; for _, p in lipParts do table.insert(excl, p) end
	local ok, lo, hi = true, math.huge, -math.huge
	for x = -85.8, -84.4, 0.35 do for z = -8.5, 8.5, 1 do
		local y = floorRay(x, z, excl)
		if not y then ok = false else lo = math.min(lo, y); hi = math.max(hi, y) end
	end end
	ok = ok and lo > 15.85 and hi < 16.15
	say("floor under LipPlate without it:", ("%.2f..%.2f"):format(lo, hi), ok and "-> hide LipPlate + ramps" or "-> keep")
	if ok then local n = 0; for _, p in lipParts do n += hideOne(p) end; say("lip parts hidden", n) end
end

---------------------------------------------------------------- 4. hooks: L_Hangar, 1v1 Holo + PostCollide
local lh = LM.Exfil:FindFirstChild("L_Hangar")
if lh then
	if lh:GetAttribute("Rooms3_OrigCF") == nil then lh:SetAttribute("Rooms3_OrigCF", lh.CFrame) end
	lh.CFrame = lh:GetAttribute("Rooms3_OrigCF").Rotation + L_HANGAR_HOME
	say("L_Hangar ->", f3(lh.Position), "RoomLight", CS:HasTag(lh, "RoomLight"), lh:GetAttribute("Room"))
end
for pad, sg in ONE_V_ONE do
	local m = LM.Duels:FindFirstChild(pad)
	if not m then say("MISSING", pad); continue end
	for nm, pos in {Holo = HOLO_POS, PostCollide = POST_POS} do
		local p = m:FindFirstChild(nm)
		if p then
			if p:GetAttribute("Rooms3_OrigCF") == nil then p:SetAttribute("Rooms3_OrigCF", p.CFrame) end
			p.CFrame = p:GetAttribute("Rooms3_OrigCF").Rotation + Vector3.new(pos.X, pos.Y, sg * pos.Z)
			say(pad, nm, f3(p:GetAttribute("Rooms3_OrigCF").Position), "->", f3(p.Position))
		end
	end
end

---------------------------------------------------------------- 5. sign text on solid backing plates 0.08 proud of the measured board face (x-facing boards)
local ov = ensure(R3, "Overlays", "Model")
for _, s in SIGNS do
	local name, boardName, nx, cy, cz, w, h, text = table.unpack(s)
	local board = R3:FindFirstChild(boardName, true)
	if not board then say("WARN no board", boardName); continue end
	local q0 = board.CanQuery; board.CanQuery = true
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {board}
	local best
	for _, o in {Vector2.new(0, 0), Vector2.new(w * 0.4, 0), Vector2.new(-w * 0.4, 0), Vector2.new(0, h * 0.35), Vector2.new(0, -h * 0.35)} do
		local r = workspace:Raycast(Vector3.new(board.Position.X + nx * 8, cy + o.Y, cz + o.X), Vector3.new(-nx * 12, 0, 0), rp)
		if r then local x = r.Position.X; if not best or x * nx > best * nx then best = x end end
	end
	board.CanQuery = q0
	if not best then say("WARN board face not found", name); continue end
	local th = 0.1
	local pos = Vector3.new(best + nx * (0.08 + th / 2), cy, cz)
	local p = ov:FindFirstChild(name) or Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Size = Vector3.new(w, h, th); p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(nx, 0, 0))
	p.Material = M.SmoothPlastic; p.Color = rgb(39, 40, 37); p.Transparency = 0
	p:SetAttribute("NotCover", true); p.Parent = ov
	local g = p:FindFirstChild("Text") or Instance.new("SurfaceGui")
	g.Name = "Text"; g.Face = F.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
	g.LightInfluence = 0; g.Brightness = 1.2; g.MaxDistance = 0; g.Parent = p
	local l = g:FindFirstChild("Label") or Instance.new("TextLabel")
	l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.8); l.Position = UDim2.fromScale(0, 0.1)
	l.Text = text; l.TextScaled = true; l.TextColor3 = rgb(236, 232, 218)
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy); l.Parent = g
	say(name, text, "board face x", ("%.3f"):format(best), "plate front x", ("%.3f"):format(pos.X + nx * th / 2))
end

return table.concat(log, "\n")
