-- fix/map_arena.lua [PRANGE] 2026-10-20, Edward's floor plan "PRACTICE RANGE (LARGE)" (150 x 110 studs, 1v1 / 2v2 / 3v3).
-- History: built as the "Practice Range" (file fix/map_practice_range.lua, ids PracticeRange); renamed to the Arena on 2026-10-26
-- (Edward: "so the confusion disappears in all code and labels" - the lobby's Training room was also called the practice range).
-- The [PRANGE] tags stay: port checks and the map_env anchors look for them. Instance name / registry id = "Arena" is safe:
-- every other "Arena" in the code is a prefix (ArenaLoader, ArenaMap, DuelArena), a keyword (MatchFlow kind "Arena", the test
-- Teleport "Arena"), or LobbyMap.Training.Arena, which is only looked up inside Training (fix/place_training.lua); nothing
-- finds an "Arena" by a recursive name search. fix/rename_arena.lua migrated the existing copies in place.
-- Builds Workspace.Arena in the match place (and its registry entry ReplicatedStorage.DuelMaps.Arena) as a
-- whitebox: an open-roofed box under daylight, no doors, no props, no shootables. A completely different feel from the dark,
-- enclosed Warehouse: bright, clean, colour-coded cover read at a glance.
-- Edward's calls: "fully whiteboxed or a blockout, no effects no special items", "a large box shaped whitebox map with an open
-- roof", "it shouldnt have doors", "whatever you disagree with on the floor plan just do".
-- Changes from the plan (lead's calls):
--   * no doors: the perimeter is closed, 16 tall (the box), with a pale accent band so the walls read as walls in the white
--   * ramps lead to platforms 6 high (the plan's "~20" would put players level with the box rim; 6 = over a head, under the
--     rim) with 3.4 parapets; each spawn has its own ramp up from the spawn side (the plan's rule), and the B corner gets a
--     second ramp facing the middle so its platform isn't a one-way perch
--   * windows = two tall posts with a 3.4 sill between (vaultable), no lintel (a lintel would clip the vault arc)
--   * plan doodles smaller than a stud or overlapping their neighbours are merged / dropped; everything sits on a 0.5 grid
-- Layout: the plan's px rectangles are converted to studs (plan x -75..75 -> world X, plan y 55..-55 -> world Z north..south)
-- around ORIGIN. Idempotent: rebuilds the model each run. UNDO removes the model and the registry entry.
local UNDO = false --@UNDO
local ORIGIN = Vector3.new(-600, 0, 0) -- clear of the Warehouse (x -126..-42), the range (x -37..190), the pseudo-lobby (x >= -200)
local FLOOR_TOP = 0.6
local RS = game:GetService("ReplicatedStorage")

-- Lobby (has ServerStorage._DuelSource): the map goes in as a duel source (_DuelSource.Arena.Arena) for
-- fix/duel_split_map.lua to split into arena layers. Match place: Workspace.Arena + its registry entry here.
local SS = game:GetService("ServerStorage")
local LOBBY = SS:FindFirstChild("_DuelSource") ~= nil
local sourceFolder = LOBBY and SS._DuelSource:FindFirstChild("Arena")
-- (2026-10-26) explicit branches: the old `LOBBY and (...) or workspace:FindFirstChild(...)` fell through to Workspace in the lobby
-- when the source model was missing, and a top-level "Arena" there is ArenaLoader's client clone, not this map's source
local old
if LOBBY then
	old = sourceFolder and sourceFolder:FindFirstChild("Arena")
else
	old = workspace:FindFirstChild("Arena")
end
if old then old:Destroy() end
local oldEntry = not LOBBY and RS:FindFirstChild("DuelMaps") and RS.DuelMaps:FindFirstChild("Arena")
if oldEntry then oldEntry:Destroy() end
if UNDO then
	if sourceFolder then sourceFolder:Destroy() end
	return "removed"
end

-- plan px -> studs (the plan image: map frame px x 50..1155 = 150 studs, px y 100..865 = 110 studs)
local SX, SY = 1105 / 150, 765 / 110
local function snap(v) return math.floor(v * 2 + 0.5) / 2 end
local function planX(px) return snap((px - 50) / SX - 75) end
local function planY(py) return snap(55 - (py - 100) / SY) end
-- plan point -> world (plan +y = north = world -Z)
local function W(x, y, h) return ORIGIN + Vector3.new(x, h or FLOOR_TOP, -y) end

-- [PRANGE2] 2026-10-20 Edward: "put the greybox repeating texture that we have in our training room and make all of the objects
-- white". Everything is white SmoothPlastic with the training room's grid (GRID_TEX, 5-stud tiles, dark at 0.32 transparency, as on
-- LobbyMap.Training); the floor is the training floor's grey, the box walls a shade under the cover; only the spawn pads keep a faint tint.
local WHITE, BOXWHITE = Color3.fromRGB(238, 238, 241), Color3.fromRGB(226, 226, 230)
local PALETTE = {
	Floor = Color3.fromRGB(214, 214, 218), Grid = Color3.fromRGB(214, 214, 218),
	Box = BOXWHITE, Band = BOXWHITE, Rim = BOXWHITE,
	P = WHITE, W = WHITE, C = WHITE, L = WHITE, R = WHITE, V = WHITE,
	SpawnA = Color3.fromRGB(206, 226, 238), SpawnB = Color3.fromRGB(238, 212, 212),
}
local GRID_TEX = "rbxassetid://86361987736184" -- the training room's greybox grid
local GRID_TILE, GRID_COLOR, GRID_ALPHA = 5, Color3.fromRGB(34, 34, 34), 0.32
local HEIGHT = { P = 10, W = 7, C = 5, L = 3.4, VPost = 7, VSill = 3.4, Platform = 6, Parapet = 3.4, Box = 16 }

local map = Instance.new("Model")
map.Name = "Arena"
local folders = {}
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or map
	folders[name] = f
	return f
end
folder("Floor"); folder("Box"); local cover = folder("Cover")
for _, n in { "Pillars", "Walls", "Cargo", "LowStone", "Windows", "Ramps" } do folder(n, cover) end

local count = 0
local function part(parent, name, size, cf, color, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	count += 1
	return p
end

-- a box from plan px rect (x1, y1)-(x2, y2), h tall, standing on `base` (default the floor)
local function block(parent, name, x1, y1, x2, y2, h, color, base)
	local ax, bx = planX(math.min(x1, x2)), planX(math.max(x1, x2))
	local ay, by = planY(math.max(y1, y2)), planY(math.min(y1, y2)) -- py grows downward
	local w, d = math.max(bx - ax, 1), math.max(by - ay, 1)
	local b = base or FLOOR_TOP
	return part(parent, name, Vector3.new(w, h, d), CFrame.new(W((ax + bx) / 2, (ay + by) / 2, b + h / 2)), color)
end

-- // Floor: 10-stud tiles with a 0.3 grout line (the whitebox grid), one slab under them
local SIZE_X, SIZE_Z = 150, 110
part(folders.Floor, "Slab", Vector3.new(SIZE_X + 4, 1, SIZE_Z + 4), CFrame.new(W(0, 0, FLOOR_TOP - 0.5)), PALETTE.Floor)
-- (the grid texture draws the tiles now: no separate tile parts)

-- // The box: perimeter walls, open roof, no doors. 2 thick, outside the 150 x 110 play area.
local T = 2
local boxH = HEIGHT.Box
for _, s in {
	{ "North", Vector3.new(SIZE_X + 2 * T, boxH, T), Vector3.new(0, 0, SIZE_Z / 2 + T / 2) },
	{ "South", Vector3.new(SIZE_X + 2 * T, boxH, T), Vector3.new(0, 0, -SIZE_Z / 2 - T / 2) },
	{ "East", Vector3.new(T, boxH, SIZE_Z), Vector3.new(SIZE_X / 2 + T / 2, 0, 0) },
	{ "West", Vector3.new(T, boxH, SIZE_Z), Vector3.new(-SIZE_X / 2 - T / 2, 0, 0) },
} do
	local c = s[3]
	local wall = part(folders.Box, s[1], s[2], CFrame.new(W(c.X, c.Z, FLOOR_TOP + boxH / 2)), PALETTE.Box)
	wall:SetAttribute("NotCover", true) -- the box itself isn't cover (no hugging the outer wall)
	-- a pale accent band at eye height and a darker rim on top
	local inset = s[2] + Vector3.new(0.1, 0, 0.1)
	part(folders.Box, s[1] .. "Rim", Vector3.new(inset.X, 0.6, inset.Z), CFrame.new(W(c.X, c.Z, FLOOR_TOP + boxH + 0.3)), PALETTE.Rim)
end

-- // Cover, transcribed from the plan (px rects)
local P = {
	{ 147, 174, 185, 212 }, { 461, 373, 499, 411 }, { 795, 343, 833, 381 }, { 691, 520, 727, 557 },
	{ 165, 545, 203, 582 }, { 292, 780, 328, 818 }, { 691, 123, 712, 161 }, { 566, 400, 590, 440 },
	{ 1025, 448, 1082, 472 }, { 1030, 568, 1083, 592 },
}
local Wl = {
	{ 58, 155, 90, 345 }, { 330, 252, 493, 288 }, { 463, 229, 493, 252 }, { 580, 207, 605, 302 }, { 800, 105, 823, 175 },
	{ 895, 137, 920, 210 }, { 1125, 163, 1148, 278 }, { 882, 242, 905, 300 }, { 962, 365, 1082, 392 }, { 1060, 392, 1082, 445 },
	{ 1123, 368, 1148, 490 }, { 113, 389, 138, 477 }, { 362, 412, 386, 493 }, { 58, 448, 88, 652 }, { 591, 400, 771, 428 },
	{ 836, 527, 920, 550 }, { 920, 480, 955, 568 }, { 485, 538, 590, 567 }, { 292, 605, 400, 635 }, { 370, 635, 400, 705 },
	{ 400, 676, 470, 705 }, { 1125, 578, 1148, 685 }, { 697, 740, 720, 825 }, { 720, 790, 834, 825 }, { 797, 690, 818, 757 },
	{ 797, 675, 955, 720 }, { 1025, 678, 1075, 805 }, { 205, 643, 235, 775 }, { 493, 753, 523, 862 }, { 880, 843, 943, 862 },
}
local C = {
	{ 432, 107, 480, 175, 8 }, { 90, 250, 120, 322 }, { 298, 198, 328, 266, 8 }, { 835, 242, 880, 276 }, { 1100, 235, 1125, 266 },
	{ 705, 430, 753, 453 }, { 265, 487, 312, 552, 8 }, { 485, 513, 533, 537 }, { 843, 615, 888, 688, 8 }, { 1083, 672, 1123, 728 },
	{ 237, 705, 273, 775 },
}
local L = {
	{ 220, 132, 312, 155 }, { 470, 290, 494, 330 }, { 514, 183, 604, 206 }, { 712, 128, 798, 151 }, { 988, 287, 1012, 360 },
	{ 400, 470, 448, 493 }, { 843, 438, 866, 520 }, { 400, 598, 424, 672 }, { 697, 667, 720, 740 }, { 387, 803, 490, 826 },
	{ 880, 823, 943, 840 },
}
for i, r in P do block(folders.Pillars, "Pillar" .. i, r[1], r[2], r[3], r[4], HEIGHT.P, PALETTE.P) end
for i, r in Wl do block(folders.Walls, "Wall" .. i, r[1], r[2], r[3], r[4], HEIGHT.W, PALETTE.W) end
for i, r in C do
	local h = r[5] or HEIGHT.C
	block(folders.Cargo, "Cargo" .. i, r[1], r[2], r[3], r[4], h, PALETTE.C)
end
for i, r in L do block(folders.LowStone, "Low" .. i, r[1], r[2], r[3], r[4], HEIGHT.L, PALETTE.L) end

-- // Windows: two tall posts + a vaultable sill between (horizontal: posts left/right; vertical: posts top/bottom)
local windows = {
	{ posts = { { 215, 290, 240, 345 }, { 323, 290, 348, 345 } }, sill = { 240, 312, 323, 328 } },
	{ posts = { { 606, 242, 624, 290 }, { 704, 236, 722, 290 } }, sill = { 624, 266, 704, 282 } },
	{ posts = { { 566, 615, 590, 663 }, { 665, 615, 689, 663 } }, sill = { 590, 624, 665, 640 } },
	{ posts = {}, sill = { 1048, 472, 1066, 568 } }, -- the east window uses the two pillars above / below it as its posts
}
for i, wdw in windows do
	for j, r in wdw.posts do block(folders.Windows, "Window" .. i .. "Post" .. j, r[1], r[2], r[3], r[4], HEIGHT.VPost, PALETTE.W) end
	block(folders.Windows, "Window" .. i .. "Sill", wdw.sill[1], wdw.sill[2], wdw.sill[3], wdw.sill[4], HEIGHT.VSill, PALETTE.V)
end

-- // Ramps + platforms (6 high, 3.4 parapets on open edges). A ramp is a WedgePart rising from `low` to `high` (plan px points).
local PH = HEIGHT.Platform
local function platform(name, x1, y1, x2, y2, parapets)
	local deck = block(folders.Ramps, name, x1, y1, x2, y2, PH, PALETTE.R)
	-- parapets: list of edges "N" / "S" / "E" / "W" that get a low wall on top of the deck
	local ax, bx = planX(math.min(x1, x2)), planX(math.max(x1, x2))
	local ay, by = planY(math.max(y1, y2)), planY(math.min(y1, y2))
	for _, e in parapets or {} do
		local cx, cy, w, d
		if e == "N" then cx, cy, w, d = (ax + bx) / 2, by - 0.5, bx - ax, 1
		elseif e == "S" then cx, cy, w, d = (ax + bx) / 2, ay + 0.5, bx - ax, 1
		elseif e == "E" then cx, cy, w, d = bx - 0.5, (ay + by) / 2, 1, by - ay
		else cx, cy, w, d = ax + 0.5, (ay + by) / 2, 1, by - ay end
		part(folders.Ramps, name .. "Parapet" .. e, Vector3.new(w, HEIGHT.Parapet, d), CFrame.new(W(cx, cy, FLOOR_TOP + PH + HEIGHT.Parapet / 2)), PALETTE.W)
	end
	return deck
end
local function ramp(name, lowPx, highPx, widthStuds)
	local a = W(planX(lowPx[1]), planY(lowPx[2]), FLOOR_TOP)
	local b = W(planX(highPx[1]), planY(highPx[2]), FLOOR_TOP)
	local flat = (b - a) * Vector3.new(1, 0, 1)
	local len = flat.Magnitude
	local dir = flat.Unit
	local centre = (a + b) / 2 + Vector3.new(0, PH / 2, 0)
	-- a WedgePart's slope rises toward its back (+Z local) from the front edge (-Z); front = LookVector = toward the low end
	local w = part(folders.Ramps, name, Vector3.new(widthStuds, PH, len), CFrame.lookAt(centre, centre - dir), PALETTE.R, "Wedge")
	w:SetAttribute("NotCover", true)
	return w
end
-- A corner (bottom-left, by spawn A): deck along the west lane, ramp up from the spawn (south) side
platform("PlatformA", 150, 643, 205, 700, { "E", "N" })
ramp("RampA", { 177, 840 }, { 177, 700 }, 7.5)
-- West mid platform: ramp up from the west lane
platform("PlatformWest", 205, 418, 362, 470, { "N", "S" })
ramp("RampWest", { 140, 444 }, { 205, 444 }, 7)
-- B corner (top-right, by spawn B): deck south of the spawn, a ramp down to the spawn (north) and one to the middle (west)
platform("PlatformB", 990, 163, 1125, 232, { "S" })
ramp("RampBSpawn", { 1030, 110 }, { 1030, 163 }, 6)
ramp("RampBMid", { 920, 197 }, { 990, 197 }, 9)
-- East low platform (bottom-right): a diagonal ramp up from the middle to a deck on the south wall
platform("PlatformEast", 1012, 805, 1133, 840, {}) -- (no parapet: the diagonal ramp arrives on its north edge)
ramp("RampEast", { 975, 725 }, { 1040, 812 }, 6.5)

-- // Spawns: team pads (tinted floor) + markers MatchSpawns.SpawnA / SpawnB facing the middle
local spawns = folder("MatchSpawns")
local function spawnPad(team, x1, y1, x2, y2, color)
	local pad = block(folders.Floor, "Spawn" .. team .. "Pad", x1, y1, x2, y2, 0.12, color, FLOOR_TOP - 0.02)
	pad.CanCollide = false
	local c = pad.Position
	local at = Vector3.new(c.X, FLOOR_TOP, c.Z)
	local look = (ORIGIN - at) * Vector3.new(1, 0, 1)
	local m = part(spawns, "Spawn" .. team, Vector3.new(4, 1, 4), CFrame.lookAt(at, at + look.Unit), color)
	m.Transparency, m.CanCollide, m.CanQuery, m.CanTouch = 1, false, false, false
	return m
end
spawnPad("A", 58, 755, 148, 860, PALETTE.SpawnA)
spawnPad("B", 1062, 108, 1148, 182, PALETTE.SpawnB)

map:SetAttribute("Whitebox", true)
-- the training room's grid on every visible face of every part (not the bottom; not the invisible spawn markers)
local textured = 0
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			local t = Instance.new("Texture")
			t.Name = "Grid"
			t.Texture = GRID_TEX
			t.Face = face
			t.StudsPerTileU, t.StudsPerTileV = GRID_TILE, GRID_TILE
			t.Color3 = GRID_COLOR
			t.Transparency = GRID_ALPHA
			t.Parent = p
			textured += 1
		end
	end
end
map.PrimaryPart = folders.Floor:FindFirstChild("Slab")
if LOBBY then
	if not sourceFolder then
		sourceFolder = Instance.new("Folder")
		sourceFolder.Name = "Arena"
		sourceFolder.Parent = SS._DuelSource
	end
	map.Parent = sourceFolder
	return ("Arena duel source built: %d parts (run fix/duel_split_map.lua next)"):format(count)
end
map.Parent = workspace

-- // Registry entry (ReplicatedStorage.DuelMaps.Arena): every mode
local root = RS:FindFirstChild("DuelMaps")
local entry = Instance.new("Folder")
entry.Name = "Arena"
entry:SetAttribute("DisplayName", "Arena")
entry:SetAttribute("Modes", "1v1,2v2,3v3")
entry:SetAttribute("MatchInstall", true)
local info = Instance.new("ModuleScript")
info.Name = "MapInfo"
info.Source = [[
-- MapInfo: registry entry for the ARENA (fix/map_arena.lua; Edward's floor plan 2026-10-20). A whitebox:
-- an open-roofed white box under daylight, colour-coded cover, no props / shootables / doors. Workspace.Arena is the
-- map at its native position; its own MatchSpawns hold the team markers (RoundManager points Workspace.MatchSpawns at them
-- when this map wins the vote, and applies Lighting below; the Warehouse's own values come back for the Warehouse).
return {
	Id = "Arena",
	DisplayName = "Arena",
	Image = "",
	Modes = { "1v1", "2v2", "3v3" },
	Size = Vector3.new(154, 17, 114),
	SpawnSpacing = 4,
	KillDepth = 30,
	WorkspaceName = "Arena",
	Dynamic = {},
	SourceOrigin = Vector3.new(-600, 0, 0),
	-- daylight in an open box: bright, crisp sun shadows, cool sky fill (the Warehouse is dim and enclosed)
	Lighting = {
		ClockTime = 15.2, GeographicLatitude = 40, Brightness = 1.6, ExposureCompensation = -0.55,
		Ambient = Color3.fromRGB(86, 86, 88), OutdoorAmbient = Color3.fromRGB(112, 112, 114),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.2, GlobalShadows = true,
		Atmosphere = { Density = 0.26, Offset = 0.05, Haze = 1, Glare = 0.1, Color = Color3.fromRGB(214, 220, 228), Decay = Color3.fromRGB(150, 160, 176) },
		Grade = { Brightness = 0, Contrast = 0.14, Saturation = 0.05, TintColor = Color3.fromRGB(255, 250, 244) },
		Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 },
	},
}
]]
info.Parent = entry
entry.Parent = root

return ("Arena built: %d parts at %s"):format(count, tostring(ORIGIN))
