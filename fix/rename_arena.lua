-- fix/rename_arena.lua [ARENANAME] 2026-10-26 (Edward: rename the map "Practice Range" to "Arena" "so the confusion disappears in
-- all code and labels"; the lobby's Training room was also called the practice range). Migrates a working copy IN PLACE (no
-- rebuild, so nothing about the map's geometry changes). Works in both kinds of place:
--   match place: Workspace.PracticeRange -> Workspace.Arena; ReplicatedStorage.DuelMaps.PracticeRange -> .Arena (DisplayName
--                attribute + MapInfo Id / DisplayName / WorkspaceName / header)
--   lobby:       ServerStorage._DuelSource.PracticeRange(.PracticeRange) -> .Arena(.Arena); ReplicatedStorage.DuelMaps and
--                ServerStorage.DuelMaps PracticeRange -> Arena (then fix/duel_split_map.lua with ONLY = "Arena" regenerates the
--                layers + MapInfo from the renamed source)
--   both:        the comments / toasts that still said practice range in live scripts (TEXT below). Archives in ServerStorage
--                (_RebuildRemoved, _MainGame_*, LobbyMap_V2, _PreMatchV2, RoqerWorld) are history and stay as they were.
-- Why the bare name "Arena" is safe: every other "Arena" in the code is a prefix (ArenaLoader, ArenaShootables, ArenaMap /
-- ArenaOrigin / ArenaSize attributes, DuelArena), a keyword value (MatchFlow kind "Arena", the test-mode Teleport "Arena" =
-- back to MatchSpawns), or LobbyMap.Training.Arena, which is only looked up inside Training (fix/place_training.lua). No script
-- searches for an "Arena" by name recursively (checked 2026-10-26 in both copies), and map lookups are top-level:
-- workspace:FindFirstChild(id) in the match place, DuelMaps:FindFirstChild(id), the lobby clone at workspace top level.
-- Idempotent ("=" = already done). UNDO puts every name and text back.
local UNDO = false --@UNDO
local OLD, NEW = "PracticeRange", "Arena"
local OLD_DN, NEW_DN = "Practice Range", "Arena"
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local log = {}
local function say(s) table.insert(log, s) end
local from, to = OLD, NEW
if UNDO then from, to = NEW, OLD end

-- MapInfo text (the match place's hand-written entry from fix/map_arena.lua, and the lobby's generated one)
local MAPINFO = {
	{ "-- MapInfo: registry entry for the PRACTICE RANGE (fix/map_practice_range.lua; Edward's floor plan 2026-10-20). A whitebox:",
		"-- MapInfo: registry entry for the ARENA (fix/map_arena.lua; Edward's floor plan 2026-10-20). A whitebox:" },
	{ "doors. Workspace.PracticeRange is the", "doors. Workspace.Arena is the" },
	{ '\tId = "PracticeRange",', '\tId = "Arena",' },
	{ '\tDisplayName = "Practice Range",', '\tDisplayName = "Arena",' },
	{ '\tWorkspaceName = "PracticeRange",', '\tWorkspaceName = "Arena",' },
}
-- live scripts: comments + two toasts that named the old map or used "practice range" for Training / exfil
local TEXT = {
	{ "(Warehouse, PracticeRange)", "(Warehouse, Arena)" },
	{ "no picture uploaded yet (Practice Range)", "no picture uploaded yet (the Arena)" },
	{ "readable over the bright Practice Range walls", "readable over the bright Arena walls" },
	{ "--   practice range (InTraining) the Training dummies", "--   Training room (InTraining) the Training dummies" },
	{ '-- the practice range (Edward: "it should work in the practice range"): while InTraining',
		'-- the Training room (Edward: aim assist "should work" in Training): while InTraining' },
	{ 'toast("The practice range isn\'t open yet.", "bad")', 'toast("That teleport isn\'t open yet.", "bad")' },
	{ "-- jumping onto the helicopter = exfil to the practice range (teleport wired later)",
		"-- jumping onto the helicopter = exfil (its destination is wired later)" },
	{ 'toast("Exfil: the practice range isn\'t open yet.", "bad")', 'toast("Exfil isn\'t open yet.", "bad")' },
}

local function swapText(src, list)
	local n = 0
	for _, e in list do
		local a, b = e[1], e[2]
		if UNDO then a, b = b, a end
		local i = 1
		while true do
			local s, f = src:find(a, i, true)
			if not s then break end
			src = src:sub(1, s - 1) .. b .. src:sub(f + 1)
			i = s + #b
			n += 1
		end
	end
	return src, n
end

local function rename(parent, what)
	if not parent then return end
	local o, n = parent:FindFirstChild(from), parent:FindFirstChild(to)
	if o and n then error(what .. ": both " .. from .. " and " .. to .. " exist under " .. parent:GetFullName()) end
	if o then o.Name = to; say(what .. " +") elseif n then say(what .. " =") end
	return parent:FindFirstChild(to)
end

-- instances
local LOBBY = SS:FindFirstChild("_DuelSource") ~= nil
if LOBBY then
	local src = rename(SS._DuelSource, "_DuelSource")
	if src then rename(src, "_DuelSource model") end
	rename(SS:FindFirstChild("DuelMaps"), "ServerStorage.DuelMaps")
else
	local m = rename(workspace, "Workspace map")
	assert(m and m:IsA("Model"), "no Workspace." .. to .. " model")
end
local entry = rename(RS:FindFirstChild("DuelMaps"), "ReplicatedStorage.DuelMaps")
assert(entry, "no ReplicatedStorage.DuelMaps." .. to)
entry:SetAttribute("DisplayName", UNDO and OLD_DN or NEW_DN)
local info = entry:FindFirstChild("MapInfo")
if info then
	local s, n = swapText(info.Source, MAPINFO)
	if n > 0 then info.Source = s end
	say("MapInfo " .. n)
end

-- live script texts (skip the archives in ServerStorage)
local changed = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") and not d:IsDescendantOf(SS) and d ~= info then
		local ok, src = pcall(function() return d.Source end)
		if ok and src then
			local s, n = swapText(src, TEXT)
			if n > 0 then
				local f, err = loadstring(s)
				assert(f, d:GetFullName() .. " would not parse: " .. tostring(err))
				d.Source = s
				table.insert(changed, d.Name .. " x" .. n)
			end
		end
	end
end
say("texts: " .. (#changed > 0 and table.concat(changed, ", ") or "none"))
return (LOBBY and "lobby" or "match") .. (UNDO and " UNDO" or "") .. " | " .. table.concat(log, " | ")
