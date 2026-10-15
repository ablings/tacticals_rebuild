--[[ fix/place_rooms2.lua : place the rooms2 kit (Shop + Armory + both corridors) in Tacticals_rebuild.rbxl (LOCAL copy only;
never the live place). Runs after fix/place_hub1.lua and fix/hub2.lua.
Idempotent: run as often as you like. UNDO = true puts everything back (kit returns to Workspace.rooms2 with its imported
look, old rooms un-hidden, CounterEmblem / RoomLights / NPCs back, hub olive back, K_Scale2/K_Marker2 back in rooms2).
Runner: python tools/run_luau.py fix/place_rooms2.lua [UNDO]
Data: kit/rooms2_manifest.json (slot -> colour/material/variant/collision), notes/rooms2_kit.md (hide/keep, hooks, RoomLight homes),
notes/hub2.md (Future tuning). Report: notes/rooms2_place.md. Own assets only (TacHub1 variants, ids from fix/place_hub1.lua).
]]
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local M, F = Enum.Material, Enum.NormalId

---------------------------------------------------------------- tuned values (measured under Future, see notes/rooms2_place.md)
-- Floors: same sky-specular compensation as hub2 (warm base so the render lands on neutral 36-62).
-- Olive: band and Neon one step down from hub1 (read lime under Future).
local OLIVE_BAND = rgb(111, 114, 57)
local OLIVE_NEON = rgb(66, 72, 36)
-- walkway metal floors (corridor plates, door thresholds, gun-wall mat): TacFloorPlate 108 rendered 64,71,75 (cool, light);
-- warm-compensated like the hub2 floors
local NAME_COLOUR = {}
for _, n in {"C_CorrN__plate_metal", "C_CorrS__plate_metal", "S_Door__plate_metal", "A_Door__plate_metal", "A_Floor__plate_metal"} do
	NAME_COLOUR[n] = rgb(95, 85, 78)
end
-- bench task lights now hang 2 studs lower (under the lamp heads, y 6): the warm pool burnt the floor to 93,91,77
local LIGHT_BRIGHT = {L_BenchA = 0.9, L_BenchB = 0.9}
local APPLY_TO_HUB = true -- same band / Neon values on the hub's olive (Hub1 *__band_olive, *__neon_olive)

---------------------------------------------------------------- slot table (= kit/rooms2_manifest.json, with the tuning above)
local SLOT = {
	floor_field   = {rgb(76, 62, 50), M.Concrete, "TacFloorConcrete"},   -- manifest 62,62,60 (hub2 compensation)
	floor_border  = {rgb(46, 38, 30), M.Concrete, "TacFloorConcrete"},   -- manifest 36,36,34
	floor_insert  = {rgb(94, 80, 66), M.Metal, "TacCorrugatedMetal"},   -- manifest 80,79,76
	plate_metal   = {rgb(108, 107, 104), M.Metal, "TacFloorPlate"},
	disc_plate    = {rgb(88, 76, 64), M.Metal, "TacFloorPlate"},         -- manifest 75,75,72 (hub2 disc value)
	wall_body     = {rgb(107, 106, 102), M.Concrete, "TacConcretePanels"},
	wall_plate    = {rgb(102, 101, 97), M.Concrete, "TacConcretePanels"},
	wall_light    = {rgb(120, 119, 115), M.Concrete, "TacConcrete"},
	wall_kick     = {rgb(88, 87, 83), M.Concrete, "TacConcrete"},
	wall_dark     = {rgb(79, 78, 74), M.Concrete, "TacConcrete"},
	wall_upper    = {rgb(141, 140, 134), M.Concrete, "TacRibbed"},
	stair         = {rgb(94, 93, 89), M.Concrete, "TacConcrete"},
	ceiling       = {rgb(112, 111, 107), M.Concrete, "TacConcrete"},
	ceiling_gloss = {rgb(66, 68, 62), M.SmoothPlastic, ""},
	band_olive    = {OLIVE_BAND, M.Concrete, "TacConcrete"},              -- manifest 120,136,66
	trim_metal    = {rgb(108, 107, 104), M.Metal, "TacMetal"},
	trim_light    = {rgb(124, 123, 119), M.Metal, "TacMetal"},
	beam_metal    = {rgb(67, 67, 65), M.Metal, "TacMetal"},
	dark_metal    = {rgb(48, 48, 46), M.Metal, "TacMetal"},
	door_leaf     = {rgb(72, 72, 70), M.Metal, "TacCorrugatedMetal"},
	neon_lamp     = {rgb(161, 157, 145), M.Neon, ""},
	neon_cream    = {rgb(180, 177, 166), M.Neon, ""},
	neon_olive    = {OLIVE_NEON, M.Neon, ""},                              -- manifest 88,101,48
	glass         = {rgb(150, 190, 215), M.Glass, ""},
	label_cream   = {rgb(236, 232, 218), M.SmoothPlastic, ""},
	sign_board    = {rgb(39, 40, 37), M.SmoothPlastic, ""},
	hazard        = {rgb(10, 12, 10), M.SmoothPlastic, ""},               -- as hub1: the texture carries the stripes
	crate_green   = {rgb(65, 94, 56), M.SmoothPlastic, ""},
	case_dark     = {rgb(48, 49, 46), M.SmoothPlastic, ""},
	drum_olive    = {rgb(70, 82, 52), M.Metal, ""},                       -- manifest 107,122,58 -> hub2 drum value
	disc_center   = {rgb(92, 90, 48), M.SmoothPlastic, ""},              -- manifest 107,122,58 (dark-olive cap; lime under Future)
	screen        = {rgb(18, 22, 20), M.Glass, ""},
}
local TEX = {hazard = "rbxassetid://79584884795039", grime = "rbxassetid://110762390496312",
	louvre = "rbxassetid://136153789620409", panel_lines = "rbxassetid://119251552384756"}

---------------------------------------------------------------- collision (generated from the manifest: can_collide false / Box)
local NOCOLLIDE = {A_Beams__beam_metal = true, A_Benches__label_cream = true, A_Benches__neon_lamp = true, A_Ceiling__ceiling = true, A_Ceiling__ceiling_gloss = true, A_Ceiling__trim_metal = true, A_Dais__neon_cream = true, A_Dais__neon_lamp = true, A_Dais__neon_olive = true, A_Displays__glass = true, A_Displays__label_cream = true, A_Displays__neon_cream = true, A_Door__hazard = true, A_Floor__hazard = true, A_GunWall__label_cream = true, A_GunWall__neon_lamp = true, A_Lights__dark_metal = true, A_Lights__neon_lamp = true, A_Lights__trim_light = true, A_Lights__trim_metal = true, A_Lines__neon_cream = true, A_Lines__neon_olive = true, A_Props__label_cream = true, A_Racks__label_cream = true, A_Racks__neon_lamp = true, A_Signs__label_cream = true, A_Signs__neon_olive = true, A_Signs__sign_board = true, A_Supply__label_cream = true, A_Supply__neon_cream = true, A_Supply__screen = true, C_CorrN__hazard = true, C_CorrN__neon_cream = true, C_CorrN__neon_lamp = true, C_CorrS__hazard = true, C_CorrS__neon_cream = true, C_CorrS__neon_lamp = true, S_Beams__beam_metal = true, S_Ceiling__ceiling = true, S_Ceiling__ceiling_gloss = true, S_Ceiling__trim_metal = true, S_Counter__label_cream = true, S_Counter__neon_cream = true, S_Counter__screen = true, S_Displays__label_cream = true, S_Displays__neon_cream = true, S_Displays__neon_lamp = true, S_Door__hazard = true, S_Floor__hazard = true, S_Lights__dark_metal = true, S_Lights__neon_lamp = true, S_Lights__trim_metal = true, S_Lines__neon_cream = true, S_Lines__neon_olive = true, S_Plinth__neon_cream = true, S_Plinth__neon_olive = true, S_Props__label_cream = true, S_Racks__label_cream = true, S_Racks__neon_lamp = true, S_Shelves__label_cream = true, S_Signs__label_cream = true, S_Signs__neon_olive = true, S_Signs__sign_board = true}
local BOX = {A_Floor__floor_border = true, A_Floor__floor_field = true, A_Floor__floor_insert = true, A_Floor__plate_metal = true, S_Floor__floor_border = true, S_Floor__floor_field = true, S_Floor__floor_insert = true}

---------------------------------------------------------------- hooks: new homes (notes/rooms2_kit.md hooks table)
local LIGHT_HOME = {
	Shop = {L_Entry = Vector3.new(0, 12.6, 74), L_Counter = Vector3.new(0, 12.6, 97), L_Pedestals = Vector3.new(-17.5, 12.6, 85), L_Racks = Vector3.new(22, 12.6, 86)},
	Armory = {L_Dais = Vector3.new(-10, 18.3, -96), L_GunWall = Vector3.new(-6, 17.0, -106), L_Fill = Vector3.new(0, 13.8, -90),
		L_BenchA = Vector3.new(12, 6.0, -83), L_BenchB = Vector3.new(20, 6.0, -87.5)},
}
local NPC_FEET = {NPC_Quartermaster = 0.06, NPC_Supply = 1.0} -- staff deck plate top / supply deck top
-- CounterEmblem: was inside the new counter body (z 102.84); onto the cream emblem plate (front face z 100.30), facing -Z
local EMBLEM_CF, EMBLEM_SIZE = CFrame.lookAt(Vector3.new(7, 1.65, 100.27), Vector3.new(7, 1.65, 90)), Vector3.new(3.0, 1.1, 0.05)
-- sign text: {name, board mesh, centre x, centre y, plate w, plate h, face normal z sign, text}
-- Words from the current purpose: shop counter prompt "Browse SUPPLY" (OpenPanel Shop) -> SUPPLY; gun wall -> ARMORY;
-- supply counter (NPC_Supply "SUPPLY CLERK", OpenPanel Shop) -> SUPPLY.
local SIGNS = {
	{"SignText_ShopCounter", "S_Signs__sign_board", 0, 11.2, 10.2, 1.15, -1, "SUPPLY"},
	{"SignText_GunWall", "A_Signs__sign_board", -6.5, 17.15, 11.0, 2.4, 1, "ARMORY"},
	{"SignText_Supply", "A_Signs__sign_board", 11.6, 11.8, 9.6, 1.35, 1, "SUPPLY"},
}

---------------------------------------------------------------- hide helpers (own attribute set Rooms2_*, independent of Hub1/Hub2)
local function hideOne(inst)
	if inst:GetAttribute("Rooms2Hidden") or inst:GetAttribute("Hub1Hidden") or inst:GetAttribute("Hub2Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Rooms2_T", inst.Transparency); inst:SetAttribute("Rooms2_C", inst.CanCollide)
		inst:SetAttribute("Rooms2_Q", inst.CanQuery); inst:SetAttribute("Rooms2_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then
		inst:SetAttribute("Rooms2_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst:SetAttribute("Rooms2_E", inst.Enabled); inst.Enabled = false
	else
		return 0
	end
	inst:SetAttribute("Rooms2Hidden", true)
	return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("Rooms2Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Rooms2_T"); inst.CanCollide = inst:GetAttribute("Rooms2_C")
		inst.CanQuery = inst:GetAttribute("Rooms2_Q"); inst.CanTouch = inst:GetAttribute("Rooms2_Tc")
	elseif inst:IsA("Decal") then
		inst.Transparency = inst:GetAttribute("Rooms2_T")
	else
		inst.Enabled = inst:GetAttribute("Rooms2_E")
	end
	for _, a in {"Rooms2Hidden", "Rooms2_T", "Rooms2_C", "Rooms2_Q", "Rooms2_Tc", "Rooms2_E"} do inst:SetAttribute(a, nil) end
	return 1
end
local function hideTree(root)
	local n = hideOne(root)
	for _, d in root:GetDescendants() do n += hideOne(d) end
	return n
end
local function inside(p, xmax, zmin, zmax) -- whole bounds of a part inside |x| < xmax, zmin < |z| < zmax (one side)
	local h = p.Size / 2
	local x0, x1, z0, z1 = p.Position.X - h.X, p.Position.X + h.X, p.Position.Z - h.Z, p.Position.Z + h.Z
	local az0, az1 = math.min(math.abs(z0), math.abs(z1)), math.max(math.abs(z0), math.abs(z1))
	return x0 > -xmax and x1 < xmax and z0 * z1 > 0 and az0 > zmin and az1 < zmax
end
local function hideTargets()
	local list, skipped = {}, {}
	for _, c in LM.Unique:GetChildren() do
		if c:IsA("BasePart") then
			if c.Name:match("^U_Shop__") or c.Name:match("^U_Armory__") then
				if inside(c, 35, 62, 116) then table.insert(list, c) else table.insert(skipped, c.Name) end
			elseif c.Name:match("^U_Gate[NS]__") then
				-- shared corridor meshes: hide only whole meshes inside the corridor box (hub1 lesson: by bounds)
				if inside(c, 8, 43.8, 66) then table.insert(list, c) else table.insert(skipped, c.Name) end
			end
		end
	end
	-- old corridor fillers (FX3.CorridorFiller: floor under the grate, side panels at x +-6.4), now inside the new lining / under the plate
	local fx3 = LM:FindFirstChild("FX") and LM.FX:FindFirstChild("FX3")
	if fx3 then for _, c in fx3:GetChildren() do if c.Name == "CorridorFiller" and c:IsA("BasePart") and inside(c, 8, 43.8, 66.5) then table.insert(list, c) end end end
	-- old LobbyMap.Lights point lights in the void beside the corridors (|x| > 8, behind the new lining); the two corridor
	-- lights at (0, 9, +-52) are kept
	local L = LM:FindFirstChild("Lights")
	if L then for _, c in L:GetChildren() do
		if c:IsA("BasePart") and math.abs(c.Position.X) > 8 and math.abs(c.Position.X) < 34 and math.abs(c.Position.Z) > 47 and math.abs(c.Position.Z) < 64 then table.insert(list, c) end
	end end
	for _, c in LM.Rooms.Shop:GetChildren() do if c.Name:match("^K_") then table.insert(list, c) end end
	for _, c in LM.Rooms.Armory:GetChildren() do if c.Name:match("^K_") or c.Name == "WeaponsDisplay" then table.insert(list, c) end end
	return list, skipped
end
local function npcFeet(n)
	local mn = math.huge
	for _, p in n:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then mn = math.min(mn, p.Position.Y - p.Size.Y / 2) end end
	return mn
end

---------------------------------------------------------------- UNDO
local R2 = LM:FindFirstChild("Rooms2")
local rem = SS:FindFirstChild("_RebuildRemoved")
if UNDO then
	local n = 0
	for _, d in LM:GetDescendants() do if d:GetAttribute("Rooms2Hidden") then n += unhideOne(d) end end
	say("unhidden", n)
	local src = workspace:FindFirstChild("rooms2") or Instance.new("Model"); src.Name = "rooms2"; src.Parent = workspace
	if R2 then
		for _, d in R2:GetDescendants() do
			if d:IsA("MeshPart") then
				local o = d:GetAttribute("Rooms2_Orig")
				if o then
					local c, mat, mv, col, qry, tch, cs, tr, cf = table.unpack(string.split(o, "|"))
					d.Color = Color3.fromHex(c); d.Material = Enum.Material[mat]; d.MaterialVariant = mv
					d.CanCollide = col == "true"; d.CanQuery = qry == "true"; d.CanTouch = tch == "true"; d.CastShadow = cs == "true"
					d.Transparency = tonumber(tr); if d.CollisionFidelity.Name ~= cf then d.CollisionFidelity = Enum.CollisionFidelity[cf] end
					d:SetAttribute("Rooms2_Orig", nil); d:SetAttribute("NotCover", nil)
				end
				for _, t in d:GetChildren() do if t:IsA("Texture") and t.Name:match("^R2_") then t:Destroy() end end
				d.Parent = src
			end
		end
		R2:Destroy(); say("kit back in Workspace.rooms2")
	end
	if rem then for _, c in rem:GetChildren() do if c.Name == "K_Scale2" or c.Name == "K_Marker2" then c.Parent = src end end end
	local e = LM.Rooms.Shop:FindFirstChild("CounterEmblem")
	if e and e:GetAttribute("Rooms2_OrigCF") then e.CFrame = e:GetAttribute("Rooms2_OrigCF"); e.Size = e:GetAttribute("Rooms2_OrigSize"); e:SetAttribute("Rooms2_OrigCF", nil); e:SetAttribute("Rooms2_OrigSize", nil) end
	for room in LIGHT_HOME do for _, l in LM.Rooms[room]:GetChildren() do
		if l:GetAttribute("Rooms2_OrigCF") then l.CFrame = l:GetAttribute("Rooms2_OrigCF"); l:SetAttribute("Rooms2_OrigCF", nil) end
		for _, li in l:GetChildren() do
			if li:GetAttribute("Rooms2_OrigBright") then li.Brightness = li:GetAttribute("Rooms2_OrigBright"); li:SetAttribute("Rooms2_OrigBright", nil) end
		end
	end end
	for name in NPC_FEET do local npc = LM.NPCs:FindFirstChild(name)
		if npc and npc:GetAttribute("Rooms2_OrigPivot") then npc:PivotTo(npc:GetAttribute("Rooms2_OrigPivot")); npc:SetAttribute("Rooms2_OrigPivot", nil) end
	end
	local hub = LM:FindFirstChild("Hub1")
	if hub then for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Rooms2_HubOrigColor") then d.Color = d:GetAttribute("Rooms2_HubOrigColor"); d:SetAttribute("Rooms2_HubOrigColor", nil) end
	end end
	say("UNDO done")
	return table.concat(log, "\n")
end

---------------------------------------------------------------- 1. move the kit into LobbyMap.Rooms2 (one Model per piece); markers out
local function ensure(parent, name, class)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new(class or "Folder"); f.Name = name; f.Parent = parent end
	return f
end
rem = ensure(SS, "_RebuildRemoved")
R2 = ensure(LM, "Rooms2")
local src = workspace:FindFirstChild("rooms2")
if src then
	for _, c in src:GetChildren() do
		if c.Name == "K_Scale2" or c.Name == "K_Marker2" then c.Parent = rem
		elseif c:IsA("MeshPart") then
			local piece = c.Name:match("^(.-)__") or "Misc"
			c.Parent = ensure(R2, piece, "Model")
		end
	end
	if #src:GetChildren() == 0 then src:Destroy() end
end
say("Rooms2 pieces", #R2:GetChildren(), "markers in _RebuildRemoved:", rem:FindFirstChild("K_Scale2") ~= nil, rem:FindFirstChild("K_Marker2") ~= nil)
task.wait()

---------------------------------------------------------------- 2. per-mesh look, overlays, collision (imported values kept in Rooms2_Orig)
local function overlay(part, name, tex, faces, u, v, color, transp)
	for _, f in faces do
		local nm = "R2_" .. name .. "_" .. f.Name
		local t = part:FindFirstChild(nm) or Instance.new("Texture")
		t.Name = nm; t.Texture = tex; t.Face = f; t.StudsPerTileU = u; t.StudsPerTileV = v
		t.Color3 = color; t.Transparency = transp; t.Parent = part
	end
end
local SIDES = {F.Front, F.Back, F.Left, F.Right}
local nMesh, nCol, nBox = 0, 0, 0
for _, part in R2:GetDescendants() do
	if not part:IsA("MeshPart") then continue end
	local piece, slot = part.Name:match("^(.-)__(.+)$")
	local s = SLOT[slot]
	if not s then say("no slot for", part.Name); continue end
	if part:GetAttribute("Rooms2_Orig") == nil then
		part:SetAttribute("Rooms2_Orig", table.concat({part.Color:ToHex(), part.Material.Name, part.MaterialVariant, tostring(part.CanCollide),
			tostring(part.CanQuery), tostring(part.CanTouch), tostring(part.CastShadow), tostring(part.Transparency), part.CollisionFidelity.Name}, "|"))
	end
	part.Anchored = true
	part.Color = NAME_COLOUR[part.Name] or s[1]; part.Material = s[2]; part.MaterialVariant = s[3]
	part.Transparency = (slot == "glass") and 0.6 or 0
	part.Reflectance = 0
	part.CastShadow = not (s[2] == M.Neon or slot == "glass")
	local collide = not NOCOLLIDE[part.Name]
	part.CanCollide = collide; part.CanQuery = collide; part.CanTouch = false
	if collide then
		nCol += 1
		local cf = BOX[part.Name] and Enum.CollisionFidelity.Box or Enum.CollisionFidelity.PreciseConvexDecomposition
		if BOX[part.Name] then nBox += 1 end
		if part.CollisionFidelity ~= cf then part.CollisionFidelity = cf end
	else
		part:SetAttribute("NotCover", true)
	end
	if slot == "hazard" then overlay(part, "hazard", TEX.hazard, {F.Top}, 4, 1, Color3.new(1, 1, 1), 0) end
	if slot == "wall_kick" then overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.93) end
	if (piece == "S_Props" or piece == "A_Props") and (slot == "crate_green" or slot == "case_dark" or slot == "drum_olive") then
		overlay(part, "grime", TEX.grime, SIDES, 4, 4, Color3.new(0, 0, 0), 0.94)
	end
	if (piece == "S_Lights" or piece == "A_Lights" or piece:match("^C_Corr")) and slot == "neon_lamp" then overlay(part, "louvre", TEX.louvre, {F.Bottom}, 0.6, 1, Color3.new(0, 0, 0), 0.5) end
	if (piece == "S_Plinth" or piece == "A_Dais") and slot == "disc_plate" then overlay(part, "panel", TEX.panel_lines, {F.Top}, 20, 20, rgb(81, 81, 78), 0.35) end
	nMesh += 1
	if nMesh % 50 == 0 then task.wait() end
end
say("meshes styled", nMesh, "colliding", nCol, "box", nBox)

---------------------------------------------------------------- 2b. same olive on the hub (band + Neon), originals kept
if APPLY_TO_HUB and LM:FindFirstChild("Hub1") then
	local nh = 0
	for _, d in LM.Hub1:GetDescendants() do
		if d:IsA("MeshPart") then
			local slot = d.Name:match("__(.+)$")
			local c = (slot == "band_olive" and OLIVE_BAND) or (slot == "neon_olive" and OLIVE_NEON)
			if c then
				if d:GetAttribute("Rooms2_HubOrigColor") == nil then d:SetAttribute("Rooms2_HubOrigColor", d.Color) end
				d.Color = c; nh += 1
			end
		end
	end
	say("hub olive parts retuned", nh)
end

---------------------------------------------------------------- 3. hide the old rooms / corridor shell and old Shop/Armory props (restorable)
local targets, skipped = hideTargets()
local hidden = 0
for i, inst in targets do hidden += hideTree(inst); if i % 40 == 0 then task.wait() end end
say("hide targets", #targets, "hidden instances this run", hidden, "skipped (bounds outside):", #skipped > 0 and table.concat(skipped, ",") or "none")

---------------------------------------------------------------- 4. hooks: CounterEmblem, RoomLights, NPCs
local e = LM.Rooms.Shop:FindFirstChild("CounterEmblem")
if e then
	if e:GetAttribute("Rooms2_OrigCF") == nil then e:SetAttribute("Rooms2_OrigCF", e.CFrame); e:SetAttribute("Rooms2_OrigSize", e.Size) end
	e.Size = EMBLEM_SIZE; e.CFrame = EMBLEM_CF
	say("CounterEmblem ->", e.Position)
end
for room, homes in LIGHT_HOME do
	for name, pos in homes do
		local l = LM.Rooms[room]:FindFirstChild(name)
		if l then
			if l:GetAttribute("Rooms2_OrigCF") == nil then l:SetAttribute("Rooms2_OrigCF", l.CFrame) end
			l.CFrame = l:GetAttribute("Rooms2_OrigCF").Rotation + pos -- keep orientation (SpotLight faces), move only
			for _, li in l:GetChildren() do
				if li:IsA("Light") and LIGHT_BRIGHT[name] then
					if li:GetAttribute("Rooms2_OrigBright") == nil then li:SetAttribute("Rooms2_OrigBright", li.Brightness) end
					li.Brightness = LIGHT_BRIGHT[name]
				end
			end
			if not CS:HasTag(l, "RoomLight") or l:GetAttribute("Room") ~= room then say("WARN", name, "tag/room") end
		else say("MISSING light", room, name) end
	end
end
for name, feet in NPC_FEET do
	local npc = LM.NPCs:FindFirstChild(name)
	if npc then
		if npc:GetAttribute("Rooms2_OrigPivot") == nil then npc:SetAttribute("Rooms2_OrigPivot", npc:GetPivot()) end
		npc:PivotTo(npc:GetAttribute("Rooms2_OrigPivot"))
		local dy = feet - npcFeet(npc)
		npc:PivotTo(npc:GetAttribute("Rooms2_OrigPivot") + Vector3.new(0, dy, 0))
		say(name, "raised", ("%.2f"):format(dy), "feet now", ("%.2f"):format(npcFeet(npc)))
	end
end

---------------------------------------------------------------- 5. sign text on solid backing plates 0.08 proud of the measured board face
local ov = ensure(R2, "Overlays", "Model")
for _, s in SIGNS do
	local name, boardName, cx, cy, w, h, nz, text = table.unpack(s)
	local board = R2:FindFirstChild(boardName, true)
	local q0 = board.CanQuery; board.CanQuery = true
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {board}
	-- nz = direction the board face looks (+1 = +Z); rays come from in front of the face
	local best
	for _, o in {Vector2.new(0, 0), Vector2.new(w * 0.4, 0), Vector2.new(-w * 0.4, 0), Vector2.new(0, h * 0.35), Vector2.new(0, -h * 0.35)} do
		local r = workspace:Raycast(Vector3.new(cx + o.X, cy + o.Y, board.Position.Z + nz * 8), Vector3.new(0, 0, -nz * 12), rp)
		if r then local z = r.Position.Z; if not best or z * nz > best * nz then best = z end end
	end
	board.CanQuery = q0
	if not best then say("WARN board face not found", name); continue end
	local th = 0.1
	local zc = best + nz * (0.08 + th / 2)
	local pos = Vector3.new(cx, cy, zc)
	local p = ov:FindFirstChild(name) or Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Size = Vector3.new(w, h, th); p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, nz))
	p.Material = M.SmoothPlastic; p.Color = rgb(39, 40, 37); p.Transparency = 0
	p:SetAttribute("NotCover", true); p.Parent = ov
	local g = p:FindFirstChild("Text") or Instance.new("SurfaceGui")
	g.Name = "Text"; g.Face = F.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
	g.LightInfluence = 0; g.Brightness = 1.2; g.MaxDistance = 0; g.Parent = p
	local l = g:FindFirstChild("Label") or Instance.new("TextLabel")
	l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.8); l.Position = UDim2.fromScale(0, 0.1)
	l.Text = text; l.TextScaled = true; l.TextColor3 = rgb(236, 232, 218)
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy); l.Parent = g
	say(name, text, "board face z", ("%.3f"):format(best), "plate front z", ("%.3f"):format(zc + nz * th / 2))
end

return table.concat(log, "\n")
