-- split_lobby_install.lua : lobby routing to the three split places (notes/place_split.md), 2026-10-16.
-- Run:   python tools/split_build.py lobby <studio_id> [UNDO]     (lobby working copy today: 829eb64d)
-- Idempotent; UNDO puts every edited script back (the hashes printed at the end match the ones before the install).
-- [SPLIT] edits (string swap; backups ServerStorage._RebuildRemoved.SPLIT_<name>_Orig, taken before the first edit):
--   LobbyConfig: TutorialPlaceId / MatchmakingPlaceId / RankedPlaceId (0 = not created yet) + LobbyConfig.PlaceIdFor(kind), which
--     falls back to MatchPlaceId (81861384114744, the old combined place) while an id is 0. TutorialPlaceId was 81861384114744.
--   NewPlayerTutorial: teleports to PlaceIdFor("Tutorial") (TeleportData { Tutorial = true } as before).
--   QueueManager.deploy (pads -> a match server; only when in-lobby duels are off): ranked bays -> PlaceIdFor("Ranked"), casual ->
--     PlaceIdFor("Matchmaking"), the same id for ReserveServer and TeleportAsync.
--   MatchmakingManager (PLAY): startMatch reserves on PlaceIdFor(q.Ranked and "Ranked" or "Matchmaking") and writes `place` into the
--     MM_Results entry; deliver teleports to res.place (an entry from a server without [SPLIT] has none: MatchPlaceId, where it reserved).
-- Order: after lobby_duels -> admin -> data_release -> ranked. The QueueManager / MatchmakingManager edits change lines written by
-- data_release: UNDO this one first if data_release has to be undone or re-run, then install this again.
-- After the lead creates the places: set the three ids in LobbyConfig by hand (see notes/place_split.md "Ids"), nothing else.
local UNDO = false --@UNDO

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
assert(workspace:FindFirstChild("LobbyMap") ~= nil, "not the lobby: use fix/split_place_install.lua in a match place copy")

local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do h = bit32.bxor(h, string.byte(s, i)); h = (h * 16777619) % 4294967296 end
	return string.format("%08x", h)
end
local function manager(name)
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	local m = init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
	return m and m:FindFirstChild(name)
end
local GET = {
	LobbyConfig = function() return RS.Modules.Shared.Config:FindFirstChild("LobbyConfig") end,
	NewPlayerTutorial = function() return SSS:FindFirstChild("NewPlayerTutorial") end,
	QueueManager = function() return manager("QueueManager") end,
	MatchmakingManager = function() return manager("MatchmakingManager") end,
}
local ORDER = { "LobbyConfig", "NewPlayerTutorial", "QueueManager", "MatchmakingManager" }
local function stateHash()
	local parts = {}
	for _, n in ORDER do local s = GET[n](); table.insert(parts, n .. "=" .. (s and fnv(s.Source) or "-")) end
	local bin = SS:FindFirstChild("_RebuildRemoved")
	local baks = 0
	if bin then for _, c in bin:GetChildren() do if c.Name:match("^SPLIT_") then baks += 1 end end end
	table.insert(parts, "backups=" .. baks)
	return fnv(table.concat(parts, ";")), table.concat(parts, "; ")
end
local h0, d0 = stateHash()
say("before:", h0, "(" .. d0 .. ")")

local rec = CHS:TryBeginRecording("SPLIT lobby install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS

local EDITS = {
	-- 1 LobbyConfig: the three place ids + the resolver
	{ "LobbyConfig",
		"LobbyConfig.TutorialPlaceId = 81861384114744\n",
		"-- [SPLIT] 2026-10-16 (notes/place_split.md): three places in this experience, one per kind. 0 = not created yet: that kind\n"
			.. "-- still goes to MatchPlaceId (81861384114744, the old combined \"tutorial spot / matchmaking test\" place). Fill in the ids\n"
			.. "-- once the places exist (Creator Hub > the experience > Places).\n"
			.. "LobbyConfig.TutorialPlaceId = 118492914954668\n"
			.. "LobbyConfig.MatchmakingPlaceId = 97339328188402\n"
			.. "LobbyConfig.RankedPlaceId = 122908502889013\n"
			.. "-- [SPLIT] the place a kind (\"Tutorial\" / \"Matchmaking\" / \"Ranked\") teleports to: its id, or MatchPlaceId while that id is 0\n"
			.. "function LobbyConfig.PlaceIdFor(kind: string): number\n"
			.. "\tlocal id = tonumber(LobbyConfig[tostring(kind) .. \"PlaceId\"]) or 0\n"
			.. "\tif id > 0 then return id end\n"
			.. "\treturn LobbyConfig.MatchPlaceId\n"
			.. "end\n",
		-- (already-in check: the resolver, so filled-in ids still count as installed)
		"function LobbyConfig.PlaceIdFor(kind: string): number\n" },
	-- 2 NewPlayerTutorial
	{ "NewPlayerTutorial",
		"\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.TutorialPlaceId, { player }, opts) end)\n",
		"\t\t-- [SPLIT] the Tutorial place (LobbyConfig.TutorialPlaceId; 0 = the old combined place)\n"
			.. "\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.PlaceIdFor(\"Tutorial\"), { player }, opts) end)\n" },
	-- 3-4 QueueManager.deploy
	{ "QueueManager",
		"\t\tlocal okReserve, code = pcall(TeleportService.ReserveServer, TeleportService, Config.MatchPlaceId)\n",
		"\t\t-- [SPLIT] ranked bays play in the Ranked place, casual ones in the Matchmaking place (0 = the old combined place)\n"
			.. "\t\tlocal placeId = Config.PlaceIdFor(bay.ranked and \"Ranked\" or \"Matchmaking\")\n"
			.. "\t\tlocal okReserve, code = pcall(TeleportService.ReserveServer, TeleportService, placeId)\n" },
	{ "QueueManager",
		"\t\tlocal okTp, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, players, options)\n",
		"\t\t-- [SPLIT] the place the server was reserved on\n"
			.. "\t\tlocal okTp, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, players, options)\n" },
	-- 5-7 MatchmakingManager (PLAY)
	{ "MatchmakingManager",
		"\tlocal code = \"STUDIO\"\n\tif not IS_STUDIO then\n\t\tlocal ok, res = pcall(TeleportService.ReserveServer, TeleportService, Config.MatchPlaceId)\n",
		"\tlocal code = \"STUDIO\"\n"
			.. "\t-- [SPLIT] ranked queues play in the Ranked place, casual ones in the Matchmaking place (0 = the old combined place);\n"
			.. "\t-- the id goes into the result, so the delivering server (any lobby server) teleports to the place the code belongs to\n"
			.. "\tlocal placeId = Config.PlaceIdFor(q.Ranked and \"Ranked\" or \"Matchmaking\")\n"
			.. "\tif not IS_STUDIO then\n"
			.. "\t\tlocal ok, res = pcall(TeleportService.ReserveServer, TeleportService, placeId)\n" },
	{ "MatchmakingManager",
		"\tlocal result = { m = matchId, code = code, q = q.Id, mode = q.Mode, ranked = q.Ranked, teams = splitTeams(group, q.Ranked) }\n",
		"\t-- [SPLIT] place = the reserved place id\n"
			.. "\tlocal result = { m = matchId, code = code, q = q.Id, mode = q.Mode, ranked = q.Ranked, teams = splitTeams(group, q.Ranked), place = placeId }\n" },
	{ "MatchmakingManager",
		"\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, { player }, options)\n",
		"\t-- [SPLIT] the place the match server was reserved on (a result written by a lobby server without [SPLIT] has none: the old place)\n"
			.. "\tlocal placeId = tonumber(res.place) or Config.MatchPlaceId\n"
			.. "\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)\n" },
}

local function backup(s)
	local name = "SPLIT_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[SPLIT]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = GET[e[1]]()
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[2], 1, true) then say("edit", i, s.Name, "not applied")
			else say("WARN edit", i, s.Name, "neither text found (changed by hand, e.g. a place id filled in? backup SPLIT_" .. s.Name .. "_Orig kept)") end
		end
	end
	for _, n in ORDER do
		local s = GET[n]()
		local bak = bin:FindFirstChild("SPLIT_" .. n .. "_Orig")
		if s and bak and not s.Source:find("[SPLIT]", 1, true) then
			say(n, bak.Source == s.Source and "matches its backup" or "WARN differs from its backup")
			bak:Destroy()
		end
	end
else
	for i, e in EDITS do
		local s = GET[e[1]]()
		if not s then say("WARN missing", e[1])
		elseif s.Source:find(e[4] or e[3], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[2], 1, true)
			if a then
				backup(s)
				s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local h1, d1 = stateHash()
say("after:", h1, "(" .. d1 .. ")")
return table.concat(log, "\n")
