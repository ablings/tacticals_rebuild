-- arena_lookdev bays: identical geometry (the Arena's pieces at the Arena's sizes), one surface recipe per bay. Idempotent: each run
-- rebuilds the bays named in ONLY (or all). Old versions of a rebuilt bay go to ServerStorage.LookdevOld (UNDO path: move back).
local ONLY = nil --@ONLY e.g. { C = true }
local GRID = "rbxassetid://86361987736184" -- our own grid (tex/hub_overlay_grid.png): white lines on the tile edges, 2 px of 512
local ANCHOR = Vector3.new(0, 0.6, 0)      -- world lattice: x, z multiples of 5; y = floor top 0.6 + 5k (the Arena's FLOOR_TOP)
local FT = 0.6
local ARENA_WHITE, ARENA_BOX, ARENA_FLOOR = Color3.fromRGB(238, 238, 241), Color3.fromRGB(226, 226, 230), Color3.fromRGB(214, 214, 218)
local BAYS = { --@BAYS
	A = { z = 0, mat = Enum.Material.SmoothPlastic, structure = ARENA_WHITE, box = ARENA_BOX, floor = ARENA_FLOOR, cover = ARENA_WHITE,
		gridColor = Color3.fromRGB(34, 34, 34), gridAlpha = 0.32, aligned = false, shellInnerOnly = false },
	B = { z = 200, mat = Enum.Material.Plastic, structure = Color3.fromRGB(151, 153, 163), cover = Color3.fromRGB(132, 134, 143),
		gridColor = Color3.new(0, 0, 0), gridAlpha = 0.75, aligned = true, shellInnerOnly = true },
	C = { z = 400, mat = Enum.Material.Plastic, structure = Color3.fromRGB(203, 196, 182), cover = Color3.fromRGB(177, 171, 158),
		gridColor = Color3.new(0, 0, 0), gridAlpha = 0.75, aligned = true, shellInnerOnly = true },
	D = { z = 600, mat = Enum.Material.Plastic, structure = Color3.fromRGB(203, 196, 182), cover = Color3.fromRGB(177, 171, 158),
		gridColor = Color3.new(0, 0, 0), gridAlpha = 0.65, aligned = true, shellInnerOnly = true },
}
-- pieces: name, class, size, centre (bay-local), role (floor / box / rim / structure / cover), grid faces when shellInnerOnly
local ALL5 = { "Top", "Front", "Back", "Left", "Right" }
local PIECES = {
	{ "Floor", "Part", Vector3.new(72, 1, 64), Vector3.new(-16, FT - 0.5, 0), "floor", { "Top" } },
	{ "BackWall", "Part", Vector3.new(2, 16, 68), Vector3.new(21, FT + 8, 0), "box", { "Left" } },
	{ "SideWall", "Part", Vector3.new(72, 16, 2), Vector3.new(-16, FT + 8, -33), "box", { "Back" } },
	{ "BackWallRim", "Part", Vector3.new(2.1, 0.6, 68.1), Vector3.new(21, FT + 16.3, 0), "box", {} },
	{ "SideWallRim", "Part", Vector3.new(72.1, 0.6, 2.1), Vector3.new(-16, FT + 16.3, -33), "box", {} },
	{ "Pillar_5x10x5", "Part", Vector3.new(5, 10, 5), Vector3.new(9, FT + 5, 0), "cover", ALL5 },
	{ "Wall_10x7x3", "Part", Vector3.new(3, 7, 10), Vector3.new(3.5, FT + 3.5, -9), "cover", ALL5 },
	{ "LowWall_6x3.4x2", "Part", Vector3.new(2, 3.4, 6), Vector3.new(-2, FT + 1.7, 7.5), "cover", ALL5 },
	{ "WindowPost1", "Part", Vector3.new(8, 7, 3.5), Vector3.new(7, FT + 3.5, 14.25), "structure", ALL5 },
	{ "WindowSill_3.4", "Part", Vector3.new(2.5, 3.4, 11), Vector3.new(7, FT + 1.7, 21.5), "structure", ALL5 },
	{ "WindowPost2", "Part", Vector3.new(8, 7, 3.5), Vector3.new(7, FT + 3.5, 28.75), "structure", ALL5 },
	{ "Platform", "Part", Vector3.new(8, 6, 8), Vector3.new(16, FT + 3, -26), "structure", ALL5 },
	{ "PlatformParapet", "Part", Vector3.new(8, 3.4, 1), Vector3.new(16, FT + 6 + 1.7, -22.5), "structure", ALL5 },
	{ "Ramp", "WedgePart", Vector3.new(7.5, 6, 20), Vector3.new(2, FT + 3, -26), "structure", { "Top", "Back", "Left", "Right" } },
}
local SS = game:GetService("ServerStorage")
local oldStore = SS:FindFirstChild("LookdevOld") or Instance.new("Folder")
oldStore.Name = "LookdevOld"; oldStore.Parent = SS
local root = workspace:FindFirstChild("Lookdev") or Instance.new("Folder")
root.Name = "Lookdev"; root.Parent = workspace
local report = {}
for key, cfg in BAYS do
	if ONLY and not ONLY[key] then continue end
	local prev = root:FindFirstChild("Bay_" .. key)
	if prev then prev.Name = prev.Name .. "_" .. os.time(); prev.Parent = oldStore end
	local bay = Instance.new("Model"); bay.Name = "Bay_" .. key
	local origin = Vector3.new(0, 0, cfg.z)
	local textures = 0
	for _, pc in PIECES do
		local name, class, size, pos, role, innerFaces = pc[1], pc[2], pc[3], pc[4], pc[5], pc[6]
		local p = Instance.new(class); p.Name = name; p.Anchored = true; p.Size = size
		if name == "Ramp" then
			local c = origin + pos; local dir = Vector3.new(1, 0, 0) -- low end -x, high end +x (onto the platform)
			p.CFrame = CFrame.lookAt(c, c - dir)
		else
			p.CFrame = CFrame.new(origin + pos)
		end
		p.Material = cfg.mat
		p.Color = (role == "floor" and (cfg.floor or cfg.structure)) or (role == "box" and (cfg.box or cfg.structure))
			or (role == "cover" and cfg.cover) or cfg.structure
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = bay
		local faces = cfg.shellInnerOnly and innerFaces or ALL5
		for _, face in faces do
			local t = Instance.new("Texture"); t.Name = "Grid"; t.Texture = GRID; t.Face = Enum.NormalId[face]
			t.StudsPerTileU, t.StudsPerTileV = 5, 5
			t.Color3, t.Transparency = cfg.gridColor, cfg.gridAlpha
			if cfg.aligned then t.OffsetStudsU, t.OffsetStudsV = worldOffsets(p, face, ANCHOR, 5) end
			t.Parent = p; textures += 1
		end
	end
	bay:SetAttribute("Recipe", key)
	bay.Parent = root
	table.insert(report, ("%s: %d parts, %d textures"):format(key, #PIECES, textures))
end
local gt = workspace:FindFirstChild("GridTest"); if gt then gt.Parent = oldStore end
return table.concat(report, " | ")
