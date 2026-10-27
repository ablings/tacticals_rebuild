-- convention test rig at z = -120 (two 7x7x7 blocks off the 5-grid: one per Top-face hypothesis). Red floor lines, blue block lines.
local GRID = "rbxassetid://86361987736184"
local ANCHOR = Vector3.new(0, 0.6, 0)
local old = workspace:FindFirstChild("GridTest"); if old then old:Destroy() end
local m = Instance.new("Model"); m.Name = "GridTest"
local function part(size, pos, color)
	local p = Instance.new("Part"); p.Anchored = true; p.Size = size; p.Position = pos; p.Color = color
	p.Material = Enum.Material.SmoothPlastic; p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m; return p
end
local function tex(p, face, color, u, v)
	local t = Instance.new("Texture"); t.Texture = GRID; t.Face = Enum.NormalId[face]; t.StudsPerTileU, t.StudsPerTileV = 5, 5
	t.Color3 = color; t.Transparency = 0; t.OffsetStudsU, t.OffsetStudsV = u, v; t.Parent = p
end
local floor = part(Vector3.new(40, 1, 30), Vector3.new(0, 0.1, -120), Color3.new(1, 1, 1))
tex(floor, "Top", Color3.new(1, 0, 0), worldOffsets(floor, "Top", ANCHOR, 5))
for i, up in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) } do
	FACES.Top[2] = up
	local b = part(Vector3.new(7, 7, 7), Vector3.new(i == 1 and -6.5 or 8.5, 0.6 + 3.5, -120 + 1.5), Color3.new(1, 1, 1))
	b.Name = "H" .. i
	for _, face in { "Top", "Front", "Back", "Left", "Right" } do tex(b, face, Color3.new(0, 0, 1), worldOffsets(b, face, ANCHOR, 5)) end
end
m.Parent = workspace
return "ok"
