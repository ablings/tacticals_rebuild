-- duel_split_map.lua : lobby duels map registry. Builds every map in MAPS from its ported source
-- (ServerStorage._DuelSource.<Id>, made by tools/duel_map_port.py from the match place) into two layers + a MapInfo module:
--   ReplicatedStorage.DuelMaps.<Id>            Folder (attrs DisplayName, Image, Modes)
--     MapInfo   ModuleScript   the registry entry (generated, see below); read by MapRegistry on server and client
--     Visual    Model          the whole map, nothing collides / queries / touches, no prompts. Client-only clone (ArenaLoader).
--     Lighting  Configuration  Lighting property attributes + effect children (Atmosphere / Bloom / ColorCorrection)
--   ServerStorage.DuelMaps.<Id>.Solid  Model   only the parts that collide / query / touch, invisible, no shadows, no
--     lights / SurfaceAppearances / GUIs / prompts; + Spawns (A1.., B1.. markers).
-- Both layers are re-centred so the template origin (0,0,0) = the middle of the map's footprint at floor level;
-- an arena is placed with Model:PivotTo(CFrame.new(slotOrigin)). Every part with a twin in the other layer has SolidId = n.
-- Nothing here assumes one map's geometry: footprint, floor, spawns and modes all come from MAPS + the source model.
-- Lobby duels phase 1 (2026-10-16). Idempotent (rebuilds the outputs). Tacticals_rebuild.rbxl only (studio 8ef4e21a).
-- UNDO: python tools/run_luau.py fix/duel_split_map.lua UNDO  (removes the outputs; the _DuelSource stays)
local UNDO = false --@UNDO
local ONLY = nil --@ONLY (a map id: build just that one; the others' layers stay as they are)

-- One entry per map. Model = the map model inside the source folder; Spawns = team -> list of marker paths (inside the
-- source folder); a team with one marker and several players lines teammates up beside it (SpawnSpacing studs).
-- Modes = which pad modes may play this map (Edward 2026-10-16: the Warehouse suits 1v1 only).
local MAPS = {
	Warehouse = {
		DisplayName = "Warehouse",
		Image = "rbxassetid://123421617826154", -- map-vote tile (Edward upload 2026-10-17) -- ui/art/map_warehouse.png once uploaded (needs Edward's OK)
		Modes = { "1v1" },
		Model = "Warehouse",
		Spawns = { A = { "MatchSpawns.SpawnA" }, B = { "MatchSpawns.SpawnB" } },
		SpawnSpacing = 4,
		-- dynamic pieces: phase 2 (ArenaDoors / ArenaShootables); listed so the loader can follow their Solid twins
		Dynamic = { "Interactive" },
		-- phase 2 performance (notes/lobby_duels_phase2.md): 8 shadowed PointLights cost ~3.8 M shadow triangles a frame
		-- once anything moves (each = a 6-face cube map of the whole batched mesh set). Keep 2 shadow sources, as 120-degree
		-- downward SpotLights (one shadow frustum each); the original PointLights stay as unshadowed fill.
		LightBudget = { Shadows = 2, SpotAngle = 120, SpotShare = 0.75, PointShare = 0.4, NoShadowBelow = 1.5, NoShadowSheets = true },
		Lighting = {
			props = { Brightness = 2, ClockTime = 13, Ambient = Color3.fromRGB(72, 76, 84), OutdoorAmbient = Color3.fromRGB(78, 82, 90),
				ExposureCompensation = -0.1, EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.08, ShadowSoftness = 0.12,
				ColorShift_Top = Color3.new(0, 0, 0), ColorShift_Bottom = Color3.new(0, 0, 0) },
			effects = {
				{ "Atmosphere", { Density = 0.38, Offset = 0.1, Color = Color3.fromRGB(60, 62, 70), Decay = Color3.fromRGB(20, 20, 26), Glare = 0, Haze = 1.4 } },
				{ "BloomEffect", { Intensity = 0.2, Size = 20, Threshold = 2.4 } },
				{ "ColorCorrectionEffect", { Brightness = 0, Contrast = 0.28, Saturation = -0.15, TintColor = Color3.fromRGB(236, 240, 255) } },
			},
		},
	},
	-- [PRANGE] 2026-10-20 Edward's floor plan: the open-roofed whitebox (fix/map_arena.lua builds the source). Named the Arena on
	-- 2026-10-26 (was PracticeRange / "Practice Range"; fix/rename_arena.lua migrated the copies).
	Arena = {
		DisplayName = "Arena",
		Image = "",
		Modes = { "1v1", "2v2", "3v3" },
		Model = "Arena",
		Spawns = { A = { "Arena.MatchSpawns.SpawnA" }, B = { "Arena.MatchSpawns.SpawnB" } },
		SpawnSpacing = 4,
		Dynamic = {},
		Lighting = {
			props = { Brightness = 1.6, ClockTime = 15.2, GeographicLatitude = 40, Ambient = Color3.fromRGB(86, 86, 88),
				OutdoorAmbient = Color3.fromRGB(112, 112, 114), ExposureCompensation = -0.55, EnvironmentDiffuseScale = 0.25,
				EnvironmentSpecularScale = 0.2, ShadowSoftness = 0.2, ColorShift_Top = Color3.new(0, 0, 0), ColorShift_Bottom = Color3.new(0, 0, 0) },
			effects = {
				{ "Atmosphere", { Density = 0.26, Offset = 0.05, Color = Color3.fromRGB(214, 220, 228), Decay = Color3.fromRGB(150, 160, 176), Glare = 0.1, Haze = 1 } },
				{ "BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 1.6 } },
				{ "ColorCorrectionEffect", { Brightness = 0, Contrast = 0.14, Saturation = 0.05, TintColor = Color3.fromRGB(255, 250, 244) } },
			},
		},
	},
	-- [WH2] 2026-10-28 (live port 45): Warehouse 2, 1v1 like the Warehouse (fix/map_warehouse2.lua builds the source in the lobby:
	-- _DuelSource.Warehouse2.{Warehouse2,Warehouse2Exterior}; only the hall is the duel map: the doors stay shut). Lighting = the
	-- installer's NIGHT block (MapInfo.Lighting of the match places). Steam fill in the slot: fix/lobby_steam_fill.lua.
	Warehouse2 = {
		DisplayName = "Warehouse 2",
		Image = "",
		Modes = { "1v1" },
		Model = "Warehouse2",
		Spawns = { A = { "Warehouse2.MatchSpawns.SpawnA" }, B = { "Warehouse2.MatchSpawns.SpawnB" } },
		SpawnSpacing = 4,
		Dynamic = { "Interactive" },
		Lighting = {
			props = { Brightness = 1, ClockTime = 0, GeographicLatitude = 35, Ambient = Color3.fromRGB(38, 41, 50),
				OutdoorAmbient = Color3.fromRGB(84, 88, 100), ExposureCompensation = 0, EnvironmentDiffuseScale = 0.12,
				EnvironmentSpecularScale = 0.2, GlobalShadows = true, ColorShift_Top = Color3.new(0, 0, 0), ColorShift_Bottom = Color3.new(0, 0, 0) },
			effects = {
				{ "Atmosphere", { Density = 0.32, Offset = 0, Color = Color3.fromRGB(52, 56, 64), Decay = Color3.fromRGB(26, 28, 34), Glare = 0, Haze = 0.4 } },
				{ "BloomEffect", { Intensity = 0.6, Size = 24, Threshold = 1.3 } },
				{ "ColorCorrectionEffect", { Brightness = 0, Contrast = 0.16, Saturation = -0.12, TintColor = Color3.fromRGB(255, 250, 242) } },
			},
		},
	},
	-- [HOUSE] 2026-10-28: the two-storey suburban house (fix/map_house.lua builds the source in the match place; tools/duel_map_port.py
	-- roots House,HouseExterior; fix/house_lobby_prep.lua folds a trimmed exterior into the model). Values = MapInfo.Lighting of
	-- fix/map_house.lua (tools/house_lua.py LIGHTING).
	House = {
		DisplayName = "House",
		Image = "",
		Modes = { "1v1", "2v2", "3v3" },
		Model = "House",
		Spawns = { A = { "House.MatchSpawns.SpawnA" }, B = { "House.MatchSpawns.SpawnB" } },
		SpawnSpacing = 4,
		Dynamic = {},
		Lighting = {
			props = { Brightness = 2.6, ClockTime = 16.2, GeographicLatitude = 35, Ambient = Color3.fromRGB(112, 110, 106),
				OutdoorAmbient = Color3.fromRGB(128, 126, 122), ExposureCompensation = 0, EnvironmentDiffuseScale = 0.45,
				EnvironmentSpecularScale = 0.25, ShadowSoftness = 0.2, ColorShift_Top = Color3.new(0, 0, 0), ColorShift_Bottom = Color3.new(0, 0, 0) },
			effects = {
				{ "Atmosphere", { Density = 0.24, Offset = 0.1, Color = Color3.fromRGB(205, 214, 224), Decay = Color3.fromRGB(150, 160, 176), Glare = 0.1, Haze = 1.2 } },
				{ "BloomEffect", { Intensity = 0.3, Size = 22, Threshold = 2.0 } },
				{ "ColorCorrectionEffect", { Brightness = 0, Contrast = 0.08, Saturation = -0.04, TintColor = Color3.fromRGB(255, 250, 244) } },
			},
		},
	},
}

local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function at(root, path) local o = root; for p in path:gmatch("[^%.]+") do o = o and o:FindFirstChild(p) end return o end

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name; f.Parent = parent
	return f
end

if UNDO then
	for id in MAPS do
		local a = RS:FindFirstChild("DuelMaps") and RS.DuelMaps:FindFirstChild(id)
		local b = SS:FindFirstChild("DuelMaps") and SS.DuelMaps:FindFirstChild(id)
		if a then a:Destroy() end
		if b then b:Destroy() end
		say(id, "layers removed")
	end
	for _, f in { RS:FindFirstChild("DuelMaps"), SS:FindFirstChild("DuelMaps") } do
		if f and #f:GetChildren() == 0 then f:Destroy() end
	end
	return table.concat(log, "\n")
end

local function v3(v) return string.format("Vector3.new(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z) end

for id, cfg in MAPS do
	if ONLY and id ~= ONLY then continue end
	local src = SS:FindFirstChild("_DuelSource") and SS._DuelSource:FindFirstChild(id)
	local model = src and src:FindFirstChild(cfg.Model)
	if not model then say(id, "SKIPPED: no ServerStorage._DuelSource." .. id .. "." .. cfg.Model .. " (run tools/duel_map_port.py)"); continue end

	-- template origin: footprint centre, floor = lowest spawn marker bottom
	local bbCF, bbSize = model:GetBoundingBox()
	local floorY = math.huge
	local spawnMarkers = {}
	for team, paths in cfg.Spawns do
		spawnMarkers[team] = {}
		for _, p in paths do
			local m = at(src, p)
			if m then
				-- floor under the marker = the highest colliding part top below it (the source is in ServerStorage: no raycasts)
				local best = m.Position.Y - m.Size.Y / 2
				local top = -math.huge
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and d.CanCollide then
						local rel = d.CFrame:PointToObjectSpace(m.Position)
						local h = d.Size / 2
						local t = d.Position.Y + h.Y
						if math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and t <= m.Position.Y + 0.5 and t > top then top = t end
					end
				end
				if top > -math.huge then best = top end
				floorY = math.min(floorY, best)
				table.insert(spawnMarkers[team], m)
			else say(id, "WARN spawn marker missing:", p) end
		end
	end
	if floorY == math.huge then floorY = bbCF.Position.Y - bbSize.Y / 2 end
	local origin = Vector3.new(bbCF.Position.X, floorY, bbCF.Position.Z)
	local shift = CFrame.new(-origin)

	-- work copy: give every BasePart a SolidId if it will have a Solid twin
	local work = model:Clone()
	local nSolid = 0
	for _, d in work:GetDescendants() do
		if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then nSolid += 1; d:SetAttribute("SolidId", nSolid) end
	end
	work:PivotTo(shift * work:GetPivot())

	-- light budget (per map, MAPS.<Id>.LightBudget): which lights cast shadows and which parts cast them
	local function applyLightBudget(root, budget)
		if not budget then return "no budget" end
		local lights = {}
		for _, d in root:GetDescendants() do
			if d:IsA("PointLight") and d.Shadows and d.Parent:IsA("BasePart") then table.insert(lights, d) end
		end
		local centre = root:GetBoundingBox().Position
		local picks = {}
		local function pos(l) return l.Parent.Position end
		-- the most central lights, spread apart (among equally central ones: the farthest from the picks so far)
		while #picks < math.min(budget.Shadows or 2, #lights) do
			local best, bestKey
			for _, l in lights do
				if not table.find(picks, l) then
					local spread = 0
					if #picks > 0 then
						spread = math.huge
						for _, p in picks do spread = math.min(spread, (pos(l) - pos(p)).Magnitude) end
					end
					local key = math.floor(((pos(l) - centre) * Vector3.new(1, 0, 1)).Magnitude / 2) * 100000 - math.min(spread, 99999)
					if not bestKey or key < bestKey then best, bestKey = l, key end
				end
			end
			table.insert(picks, best)
		end
		for _, l in lights do
			if table.find(picks, l) and budget.SpotAngle then
				local sp = Instance.new("SpotLight")
				sp.Name = "ShadowSpot"; sp.Face = Enum.NormalId.Bottom; sp.Angle = budget.SpotAngle
				sp.Brightness = l.Brightness * (budget.SpotShare or 1); sp.Range = l.Range; sp.Color = l.Color; sp.Shadows = true
				sp.Parent = l.Parent
				l.Brightness = l.Brightness * (budget.PointShare or 1)
				l.Shadows = false
			elseif not table.find(picks, l) then
				l.Shadows = false
			end
		end
		local small, sheets = 0, 0
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.CastShadow then
				local sz = d.Size
				local mn, mx = math.min(sz.X, sz.Y, sz.Z), math.max(sz.X, sz.Y, sz.Z)
				local md = sz.X + sz.Y + sz.Z - mn - mx
				if mx < (budget.NoShadowBelow or 0) then d.CastShadow = false; small += 1
				-- floors / ceilings / wall skins: big thin sheets (they only shade the outside)
				elseif budget.NoShadowSheets and mn <= 1.2 and md >= 20 then d.CastShadow = false; sheets += 1 end
			end
		end
		return string.format("%d shadow sources of %d lights, %d small + %d sheet parts stop casting", #picks, #lights, small, sheets)
	end

	-- Visual layer
	local visual = work:Clone()
	visual.Name = "Visual"
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.Anchored = true
		elseif d:IsA("ProximityPrompt") then d:Destroy() end
	end
	say(id, "light budget:", applyLightBudget(visual, cfg.LightBudget))

	-- Solid layer
	local solid = work:Clone()
	solid.Name = "Solid"
	local drop = {}
	for _, d in solid:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("SolidId") then
				d.Transparency = 1; d.CastShadow = false; d.Anchored = true
			else table.insert(drop, d) end
		elseif not (d:IsA("Model") or d:IsA("Folder")) then
			table.insert(drop, d)
		end
	end
	for _, d in drop do
		if d.Parent then
			for _, c in d:GetChildren() do if c:IsA("BasePart") or c:IsA("Model") or c:IsA("Folder") then c.Parent = d.Parent end end
			d:Destroy()
		end
	end
	local pruned = true
	while pruned do
		pruned = false
		for _, d in solid:GetDescendants() do
			if (d:IsA("Model") or d:IsA("Folder")) and #d:GetChildren() == 0 then d:Destroy(); pruned = true end
		end
	end
	-- spawns (waiting / dead players stand in the slot's Hold, made by LobbyDuelManager, not in the map)
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = solid
	for team, list in spawnMarkers do
		for i, m in list do
			local s = Instance.new("Part")
			s.Name = team .. i; s.Size = Vector3.new(2, 0.2, 2); s.Transparency = 1; s.Anchored = true
			s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.CastShadow = false
			local cf = shift * m.CFrame
			s.CFrame = cf - Vector3.new(0, cf.Position.Y - 0.1, 0)
			s:SetAttribute("Team", team); s:SetAttribute("Index", i)
			s.Parent = spawns
		end
	end
	solid.WorldPivot = CFrame.new()
	visual.WorldPivot = CFrame.new()

	-- outputs
	local rsMaps, ssMaps = folder(RS, "DuelMaps"), folder(SS, "DuelMaps")
	local old = rsMaps:FindFirstChild(id); if old then old:Destroy() end
	old = ssMaps:FindFirstChild(id); if old then old:Destroy() end
	local entry = Instance.new("Folder"); entry.Name = id
	entry:SetAttribute("DisplayName", cfg.DisplayName); entry:SetAttribute("Image", cfg.Image)
	entry:SetAttribute("Modes", table.concat(cfg.Modes, ","))
	visual.Parent = entry
	local light = Instance.new("Configuration"); light.Name = "Lighting"
	for k, v in cfg.Lighting.props do light:SetAttribute(k, v) end
	for _, e in cfg.Lighting.effects do
		local fx = Instance.new(e[1]); fx.Name = "Duel" .. e[1]
		for k, v in e[2] do fx[k] = v end
		fx.Parent = light
	end
	light.Parent = entry
	local _, vSize = visual:GetBoundingBox()
	local modes = {}
	for _, m in cfg.Modes do table.insert(modes, string.format("%q", m)) end
	local dyn = {}
	for _, m in cfg.Dynamic or {} do table.insert(dyn, string.format("%q", m)) end
	local info = Instance.new("ModuleScript"); info.Name = "MapInfo"
	info.Source = table.concat({
		"-- MapInfo: lobby duels map registry entry, GENERATED by fix/duel_split_map.lua (edit MAPS there and re-run, not this).",
		"-- Template origin (0,0,0) = footprint centre at floor level. Size = the map's bounding box.",
		"return {",
		string.format("\tId = %q,", id),
		string.format("\tDisplayName = %q,", cfg.DisplayName),
		string.format("\tImage = %q,", cfg.Image),
		"\tModes = { " .. table.concat(modes, ", ") .. " },",
		"\tSize = " .. v3(vSize) .. ",",
		"\tSpawnSpacing = " .. (cfg.SpawnSpacing or 4) .. ",",
		"\tKillDepth = 30,",
		"\tWorkspaceName = " .. string.format("%q", cfg.Model) .. ",",
		"\tDynamic = { " .. table.concat(dyn, ", ") .. " },",
		"\tSourceOrigin = " .. v3(origin) .. ",",
		"}",
	}, "\n")
	info.Parent = entry
	entry.Parent = rsMaps
	local sEntry = Instance.new("Folder"); sEntry.Name = id
	solid.Parent = sEntry
	sEntry.Parent = ssMaps
	work:Destroy()
	local nv, ns = 0, 0
	for _, d in visual:GetDescendants() do if d:IsA("BasePart") then nv += 1 end end
	for _, d in solid:GetDescendants() do if d:IsA("BasePart") then ns += 1 end end
	say(id, "visual parts", nv, "instances", #visual:GetDescendants(), "| solid parts", ns, "instances", #solid:GetDescendants(),
		"| size", vSize, "| origin", origin, "| modes", table.concat(cfg.Modes, ","))
end
return table.concat(log, "\n")
