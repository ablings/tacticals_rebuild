-- tools/steam_fill_testmap.lua [STEAMFILL] TEST ONLY, never for a shipped place: in a match-place COPY (out/steam_fill/test.rbxl),
-- Edit mode, makes a stand-in "Warehouse2" = a copy of the Warehouse 400 studs north with SteamFill = true, its own MatchSpawns,
-- the doors left open (no DoorManager there), and a registry entry (ReplicatedStorage.DuelMaps.Warehouse2) so the map vote,
-- spawns, cover (BotConfig.CoverFolders) and ShootableManager all treat it like the real Warehouse 2 will be treated.
-- UNDO = true removes both. Idempotent.
local UNDO = false --@UNDO
local OFFSET = Vector3.new(0, 0, 400)
local RS = game:GetService("ReplicatedStorage")
assert(game.PlaceId == 0 or not game:GetService("RunService"):IsRunning(), "Edit mode only")
local old = workspace:FindFirstChild("Warehouse2")
local oldReg = RS.DuelMaps:FindFirstChild("Warehouse2")
if UNDO then
	if old and old:GetAttribute("SteamFillTestMap") then old:Destroy() end
	if oldReg and oldReg:GetAttribute("SteamFillTestMap") then oldReg:Destroy() end
	return "test map removed"
end
assert(not old or old:GetAttribute("SteamFillTestMap"), "a real Warehouse2 is here: this script is for the stand-in only")
if old then old:Destroy() end
if oldReg then oldReg:Destroy() end

local map = workspace.Warehouse:Clone()
map.Name = "Warehouse2"
map:SetAttribute("SteamFill", true)
map:SetAttribute("SteamFillTestMap", true)
local inter = map:FindFirstChild("Interactive")
if inter then inter:Destroy() end -- the shutters are DoorManager's (Warehouse only): leave the doorways open
map:PivotTo(map:GetPivot() + OFFSET)
local spawns = Instance.new("Folder")
spawns.Name = "MatchSpawns"
for _, s in workspace.MatchSpawns:GetChildren() do
	local c = s:Clone()
	c.CFrame = s.CFrame + OFFSET
	c.Parent = spawns
end
spawns.Parent = map
map.Parent = workspace

local reg = RS.DuelMaps.Warehouse:Clone()
reg.Name = "Warehouse2"
reg:SetAttribute("SteamFillTestMap", true)
local info = reg:FindFirstChild("MapInfo")
local src = info.Source
src = src:gsub('Id = "Warehouse"', 'Id = "Warehouse2"', 1)
src = src:gsub('DisplayName = "Warehouse"', 'DisplayName = "Warehouse 2 (steam test)"', 1)
src = src:gsub('WorkspaceName = "Warehouse"', 'WorkspaceName = "Warehouse2"', 1)
src = src:gsub("Image = \"[^\"]*\"", 'Image = ""', 1)
src = src:gsub("SourceOrigin = Vector3.new%(([%-%d%.]+), ([%-%d%.]+), ([%-%d%.]+)%)", function(x, y, z)
	return ("SourceOrigin = Vector3.new(%s, %s, %.3f)"):format(x, y, tonumber(z) + OFFSET.Z)
end, 1)
info.Source = src
reg.Parent = RS.DuelMaps
local valves = {}
for _, v in map.Shootables:GetChildren() do if v.Name:find("SteamValve") then table.insert(valves, v.Name .. " " .. tostring(v.ValveBody.Position)) end end
return "Warehouse2 stand-in at +" .. tostring(OFFSET) .. ", valves: " .. table.concat(valves, "; ")
