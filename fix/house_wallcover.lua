-- fix/house_wallcover.lua [WALLCOVER1029] (2026-10-29, systems session; needs fix/move_rework_1029.lua for the rule)
-- Edward's change (1): WALL COVER PER MAP. A map whose MapInfo says WallCover = true (and whose model carries the attribute
-- WallCover = true, which is what the cover code reads: MoveRules.IsWallCover walks up from the part) lets its wall proxies
-- count as tall cover. This turns it on for House:
--   * every room-wall proxy (House CollisionProxies with Role "wall", floor to ceiling: not the "_Above" lintels over openings)
--     gets WallProxy = true. It keeps NotCover = true, so with WallCover off (or this UNDOne) nothing changes;
--   * windows (sills "_Win_", glass), barriers (BAR_*), door leaves and NotCover obstacles get nothing: they stay no cover;
--   * DuelMaps.House.MapInfo gets `WallCover = true`, the House model (and in the lobby the pad-duel layers) the attribute.
-- Runs on top of the House map builder's fix/map_house.lua output (never edits that file). House with wall cover is for the
-- Test place only until Edward has played it: do not run this on the live match places or the lobby.
-- Idempotent; marks what it set (attribute WallCoverBy1029) so UNDO removes only that.
-- python tools/run_luau_at.py <studio id> fix/house_wallcover.lua [UNDO]
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local MAP = "House"
local LINE = "\tWallCover = true, -- [WALLCOVER1029] its room-wall proxies (WallProxy) are tall cover (fix/house_wallcover.lua)\n"
local res = {}
local nProxy, nModel = 0, 0

local function isRoomWall(p: Instance): boolean
	return p:IsA("BasePart") and p:GetAttribute("Role") == "wall" and not p.Name:find("Above", 1, true)
		and not p.Name:find("_Win_", 1, true) and p:GetAttribute("NotCover") == true
end

local function markModel(m: Instance)
	if UNDO then
		if m:GetAttribute("WallCoverBy1029") then m:SetAttribute("WallCover", nil) m:SetAttribute("WallCoverBy1029", nil) nModel += 1 end
		for _, d in m:GetDescendants() do
			if d:GetAttribute("WallCoverBy1029") then d:SetAttribute("WallProxy", nil) d:SetAttribute("WallCoverBy1029", nil) nProxy += 1 end
		end
		return
	end
	if m:GetAttribute("WallCover") ~= true then m:SetAttribute("WallCover", true) m:SetAttribute("WallCoverBy1029", true) nModel += 1 end
	for _, d in m:GetDescendants() do
		if isRoomWall(d) and d:GetAttribute("WallProxy") ~= true then
			d:SetAttribute("WallProxy", true)
			d:SetAttribute("WallCoverBy1029", true)
			nProxy += 1
		end
	end
end

-- the registry entry's MapInfo
local entry = RS:FindFirstChild("DuelMaps") and RS.DuelMaps:FindFirstChild(MAP)
local info = entry and entry:FindFirstChild("MapInfo")
local wsName = MAP
if info and info:IsA("ModuleScript") then
	local s = info.Source
	if UNDO then
		local a, b = s:find(LINE, 1, true)
		if a then info.Source = s:sub(1, a - 1) .. s:sub(b + 1) table.insert(res, "MapInfo -") else table.insert(res, "MapInfo =") end
	elseif s:find(LINE, 1, true) then
		table.insert(res, "MapInfo =")
	else
		local a, b = s:find("return%s*{%s*\r?\n")
		assert(a, "House MapInfo: no 'return {' line")
		local new = s:sub(1, b) .. LINE .. s:sub(b + 1)
		assert(loadstring(new), "House MapInfo would not parse")
		info.Source = new
		table.insert(res, "MapInfo +")
	end
	local ok, t = pcall(function() return loadstring(info.Source)() end)
	if ok and type(t) == "table" and t.WorkspaceName then wsName = t.WorkspaceName end
end

-- match / Test places: the map in Workspace and any staging copy; lobby: the pad-duel layers and their source
local ws = workspace:FindFirstChild(wsName)
if ws then markModel(ws) table.insert(res, "Workspace." .. wsName) end
local staging = SS:FindFirstChild("StagingMaps") and SS.StagingMaps:FindFirstChild(MAP)
if staging and staging:FindFirstChild("Workspace") then
	local m = staging.Workspace:FindFirstChild(wsName)
	if m then markModel(m) table.insert(res, "staging") end
end
local dm = SS:FindFirstChild("DuelMaps") and SS.DuelMaps:FindFirstChild(MAP)
for _, layer in { "Solid", "Visual" } do
	local l = dm and dm:FindFirstChild(layer)
	if l then markModel(l) table.insert(res, "lobby " .. layer) end
end
local src = SS:FindFirstChild("_DuelSource") and SS._DuelSource:FindFirstChild(MAP)
local srcModel = src and src:FindFirstChild(MAP)
if srcModel then markModel(srcModel) table.insert(res, "lobby source") end
assert(#res > 0 and (ws or dm or staging), "no House in this place")
return (UNDO and "UNDO " or "") .. ("WALLCOVER1029 House: %s | %d wall proxies, %d map models"):format(table.concat(res, ", "), nProxy, nModel)
