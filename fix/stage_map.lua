-- stage_map.lua [TESTPLACE] 2026-10-28 (notes/test_place.md): turn a map that a map installer built in a Test place copy (the
-- usual ReplicatedStorage.DuelMaps.<Id> + Workspace.<WorkspaceName>) into a STAGING map, which only the Test place offers:
--     ServerStorage.StagingMaps.<Id>            = the DuelMaps entry (MapInfo + attributes, unchanged)
--     ServerStorage.StagingMaps.<Id>.Workspace  = its Workspace model(s) (the main one + EXTRA, e.g. an exterior model)
--     python tools/test_place_build.py stage <studio window name> <MapId> [UNDO]
-- UNDO moves everything back where it was (ReplicatedStorage.DuelMaps / Workspace). Run it in the Test place copy only:
-- never in match_place_ref / the lobby (there the map should stay live, or not be installed at all).
local UNDO = false --@UNDO
local MAP = "" --@MAP
local EXTRA = {} -- more Workspace model names that belong to the map (default: MapInfo.ExtraModels, if the map lists them)

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
assert(MAP ~= "", "set MAP")
assert(workspace:FindFirstChild("LobbyMap") == nil, "not in the lobby")
local kind = RS:FindFirstChild("PlaceKind")
assert(kind and kind.Value == "Test", "only on the Test place (PlaceKind = Test)")
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

local root = SS:FindFirstChild("StagingMaps")
if not root then root = Instance.new("Folder"); root.Name = "StagingMaps"; root.Parent = SS end
if UNDO then
	local f = root:FindFirstChild(MAP)
	assert(f, "no staging map " .. MAP)
	local ws = f:FindFirstChild("Workspace")
	for _, m in (ws and ws:GetChildren() or {}) do m.Parent = workspace; say("back to Workspace:", m.Name) end
	if ws then ws:Destroy() end
	f:SetAttribute("StagedFrom", nil)
	f.Parent = RS:FindFirstChild("DuelMaps")
	say("back to ReplicatedStorage.DuelMaps:", MAP)
else
	local entry = RS.DuelMaps:FindFirstChild(MAP)
	if not entry then
		if root:FindFirstChild(MAP) then return MAP .. " is already a staging map" end
		error("no ReplicatedStorage.DuelMaps." .. MAP)
	end
	local info = require(entry.MapInfo)
	local names = { info.WorkspaceName or MAP }
	for _, n in (#EXTRA > 0 and EXTRA or (type(info.ExtraModels) == "table" and info.ExtraModels or {})) do table.insert(names, n) end
	local models = {}
	for _, n in names do
		local m = workspace:FindFirstChild(n)
		assert(m, "no Workspace." .. n)
		table.insert(models, m)
	end
	assert(not root:FindFirstChild(MAP), "StagingMaps already has " .. MAP)
	local ws = Instance.new("Folder"); ws.Name = "Workspace"
	for _, m in models do m.Parent = ws; say("staged model:", m.Name) end
	ws.Parent = entry
	entry:SetAttribute("StagedFrom", "DuelMaps")
	entry.Parent = root
	say("staged:", MAP, "-> ServerStorage.StagingMaps (live places never see it)")
end
return table.concat(log, "\n")
