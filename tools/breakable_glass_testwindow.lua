-- tools/breakable_glass_testwindow.lua [GLASS] TEST ONLY: never run it on a shipped place. Builds a test wall with a window
-- (fix/breakable_glass.lua conventions) on a test copy, away from the map's play space, with its own floor:
--   Match place: in Workspace.<MAP> (a registry map placed in Workspace): CollisionProxies.TestWin_* (floor, 4 wall pieces, the
--                barrier tagged WindowBarrier) and Shootables.TestWindow (Shootable = "Glass": Glass + BrokenGlass).
--   Hub:         the same in ServerStorage.DuelMaps.<MAP>.Solid (collision, barrier, the server's window) and the look in
--                ReplicatedStorage.DuelMaps.<MAP>.Visual (wall, Glass, BrokenGlass; no barrier), in each layer's own frame.
-- The wall runs along X; the window faces Z. Shooter side = -Z (TestWin_ShooterSpot), target side = +Z (TestWin_TargetSpot).
-- Idempotent: removes its previous parts first. REMOVE = true removes them only.
local REMOVE = false --@REMOVE
local MAP = "Warehouse2" --@MAP
local OFFSET = Vector3.new(0, 0, -200) --@OFFSET  (from the map's pivot / spawn A: an empty spot outside the map)
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local layers = {}
local hub = workspace:FindFirstChild("LobbyMap") ~= nil
if hub then
	local solid = ServerStorage.DuelMaps[MAP].Solid
	local visual = RS.DuelMaps[MAP].Visual
	table.insert(layers, { root = solid, solid = true, visible = false })
	table.insert(layers, { root = visual, solid = false, visible = true })
else
	table.insert(layers, { root = workspace[MAP], solid = true, visible = true })
end

local function clear(root: Instance)
	for _, d in root:GetDescendants() do
		if d.Name:sub(1, 8) == "TestWin_" or (d.Name == "TestWindow" and d.Parent and d.Parent.Name == "Shootables") then d:Destroy() end
	end
end
for _, l in layers do clear(l.root) end
if REMOVE then return "removed" end

local function folder(root: Instance, name: string): Instance
	local f = root:FindFirstChild(name)
	if not f then f = Instance.new("Folder") f.Name = name f.Parent = root end
	return f
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.Material = Enum.Material.Concrete
	p.Color = Color3.fromRGB(151, 153, 163)
	for k, v in props or {} do (p :: any)[k] = v end
	p.Parent = parent
	return p
end

local out = {}
for _, l in layers do
	local root = l.root
	-- where: the map's spawn A (match place) or the layer's pivot (hub) + OFFSET, on a floor of our own at the spawn's height
	local base
	local spawnA = (not hub) and root:FindFirstChild("MatchSpawns") and root.MatchSpawns:FindFirstChild("SpawnA") -- (hub: both layers share the pivot frame)
	if spawnA then base = CFrame.new(spawnA.Position.X, spawnA.Position.Y - spawnA.Size.Y / 2, spawnA.Position.Z)
	else local pv = root:GetPivot(); base = CFrame.new(pv.Position) end
	base = base + OFFSET
	local col = folder(root, l.solid and "CollisionProxies" or "TestWin_Look")
	local shoot = folder(root, "Shootables")
	local vis = l.visible and 0 or 1
	local wallProps = { Transparency = vis, CanCollide = l.solid }
	-- floor 40 x 40, top at base height
	part(col, "TestWin_Floor", Vector3.new(40, 1, 40), base * CFrame.new(0, -0.5, 0), { Transparency = vis, CanCollide = l.solid, Color = Color3.fromRGB(108, 107, 106) })
	-- wall 14 wide x 12 tall x 1 thick with a 6 x 5 opening, sill at 3
	local W, H, T, OW, OH, SILL = 14, 12, 1, 6, 5, 3
	part(col, "TestWin_WallL", Vector3.new((W - OW) / 2, H, T), base * CFrame.new(-(OW / 2 + (W - OW) / 4), H / 2, 0), wallProps)
	part(col, "TestWin_WallR", Vector3.new((W - OW) / 2, H, T), base * CFrame.new(OW / 2 + (W - OW) / 4, H / 2, 0), wallProps)
	part(col, "TestWin_Sill", Vector3.new(OW, SILL, T), base * CFrame.new(0, SILL / 2, 0), wallProps)
	part(col, "TestWin_Lintel", Vector3.new(OW, H - SILL - OH, T), base * CFrame.new(0, SILL + OH + (H - SILL - OH) / 2, 0), wallProps)
	local mid = base * CFrame.new(0, SILL + OH / 2, 0)
	if l.solid then
		local barrier = part(col, "TestWin_Barrier", Vector3.new(OW, OH, T), mid, { Transparency = 1 })
		CollectionService:AddTag(barrier, "WindowBarrier")
		-- marks for the test (not part of the convention)
		part(col, "TestWin_ShooterSpot", Vector3.new(1, 0.2, 1), base * CFrame.new(0, 0.1, -10), { Transparency = 1, CanCollide = false, CanQuery = false })
		part(col, "TestWin_TargetSpot", Vector3.new(1, 0.2, 1), base * CFrame.new(0, 0.1, 6), { Transparency = 1, CanCollide = false, CanQuery = false })
	end
	-- the window: Shootables.TestWindow (Shootable = "Glass") with Glass + BrokenGlass. Left at the authoring defaults (CanCollide /
	-- CanQuery on) on purpose: the game must switch them off itself.
	local win = Instance.new("Model")
	win.Name = "TestWindow"
	win:SetAttribute("Shootable", "Glass")
	local glass = part(win, "Glass", Vector3.new(OW, OH, 0.2), mid, { Material = Enum.Material.Glass, Color = Color3.fromRGB(167, 196, 205),
		Transparency = l.visible and 0.55 or 1 })
	local broken = Instance.new("Model")
	broken.Name = "BrokenGlass"
	broken.Parent = win
	-- jagged leftovers round the frame: four slanted strips
	for i, spec in { { -OW / 2 + 0.5, 0, 25 }, { OW / 2 - 0.5, 0, -20 }, { 0, OH / 2 - 0.4, 8 }, { -1, -OH / 2 + 0.4, -12 } } do
		local horizontal = i > 2
		part(broken, "Shard" .. i, horizontal and Vector3.new(OW * 0.6, 0.8, 0.2) or Vector3.new(1, OH * 0.7, 0.2),
			mid * CFrame.new(spec[1], spec[2], 0) * CFrame.Angles(0, 0, math.rad(spec[3])),
			{ Material = Enum.Material.Glass, Color = Color3.fromRGB(167, 196, 205), Transparency = l.visible and 0.45 or 1 })
	end
	win.PrimaryPart = glass
	win.Parent = shoot
	table.insert(out, root:GetFullName() .. " window at " .. tostring(mid.Position))
end
return table.concat(out, "\n")
