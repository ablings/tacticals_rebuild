-- split_place_install.lua : turn an opened COPY of the match place into one of the three split places (notes/place_split.md),
-- 2026-10-16. One codebase for all three; the kind is the StringValue ReplicatedStorage.PlaceKind.
-- Run:   python tools/split_build.py place <studio_id> Tutorial|Matchmaking|Ranked      (or UNDO)
--        (or paste this file into execute_luau after setting the two tagged lines below by hand)
-- Idempotent: a second run with the same kind changes nothing; a run with another kind switches the kind (content restored, then
-- stripped for the new kind). UNDO puts the place back exactly (the hashes printed at the end match the ones before the install).
-- What it does:
--   1. code layer (the same in every kind, [SPLIT] edits, backups ServerStorage._RebuildRemoved.SPLIT_<name>_Orig):
--      new ModuleScript ReplicatedStorage.Modules.Shared.PlaceKind (attribute SplitInstall);
--      Managers.RoundManager: PLACE_KIND, splitFirst (server kind by place kind), runRejectServer (wrong / missing TeleportData ->
--        back to the lobby), MatchTestHook "split";
--      Managers.TutorialManager: no auto-start / Start on the Matchmaking and Ranked places.
--      Without ReplicatedStorage.PlaceKind the edited code behaves exactly as before (the old combined place).
--   2. kind layer: ReplicatedStorage.PlaceKind (StringValue, attribute SplitInstall) = KIND, and content the kind never uses moved
--      (not deleted) into ServerStorage._SplitStripped (each item keeps attribute SplitFrom = its old parent's full name):
--        Tutorial    : ReplicatedStorage.DuelMaps (the map-vote registry; the tutorial's map IS Workspace.Warehouse, which stays)
--        Matchmaking : Workspace.FiringRange (test servers only; a split place never runs a test server)
--        Ranked      : Workspace.FiringRange
-- Order: after match_place_build -> data_release -> ranked (this file edits text those installers wrote; UNDO this one first if one
-- of them has to be undone or re-run, then install this again).
local KIND = "Matchmaking" --@KIND
local UNDO = false --@UNDO

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
local KINDS = { Tutorial = true, Matchmaking = true, Ranked = true }
assert(UNDO or KINDS[KIND], "KIND must be Tutorial, Matchmaking or Ranked")
assert(workspace:FindFirstChild("LobbyMap") == nil, "this is the lobby: use fix/split_lobby_install.lua")

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
local shared = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Shared")

-- a fingerprint of everything this installer can touch (equal before the install and after UNDO)
local function stateHash()
	local parts = {}
	for _, n in { "RoundManager", "TutorialManager" } do local s = manager(n); table.insert(parts, n .. "=" .. (s and fnv(s.Source) or "-")) end
	table.insert(parts, "PlaceKindModule=" .. tostring(shared and shared:FindFirstChild("PlaceKind") ~= nil))
	local v = RS:FindFirstChild("PlaceKind"); table.insert(parts, "PlaceKindValue=" .. (v and v.Value or "-"))
	local fr = workspace:FindFirstChild("FiringRange", false) or (SS:FindFirstChild("_SplitStripped") and SS._SplitStripped:FindFirstChild("FiringRange"))
	table.insert(parts, "FiringRange=" .. (fr and fr.Parent:GetFullName() .. "/" .. #fr:GetDescendants() or "-"))
	local dm = RS:FindFirstChild("DuelMaps") or (SS:FindFirstChild("_SplitStripped") and SS._SplitStripped:FindFirstChild("DuelMaps"))
	table.insert(parts, "DuelMaps=" .. (dm and dm.Parent:GetFullName() .. "/" .. #dm:GetDescendants() or "-"))
	table.insert(parts, "stash=" .. tostring(SS:FindFirstChild("_SplitStripped") ~= nil))
	local bin = SS:FindFirstChild("_RebuildRemoved")
	local baks = 0
	if bin then for _, c in bin:GetChildren() do if c.Name:match("^SPLIT_") then baks += 1 end end end
	table.insert(parts, "backups=" .. baks)
	return fnv(table.concat(parts, ";")), table.concat(parts, "; ")
end
local h0, d0 = stateHash()
say("before:", h0, "(" .. d0 .. ")")

local rec = CHS:TryBeginRecording("SPLIT place install " .. (UNDO and "UNDO" or KIND))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS

--@EMBED_BEGIN PlaceKind (tools/split_build.py copies scripts/split/PlaceKind.lua here)
local PLACEKIND_SRC = [==[
-- ReplicatedStorage/Modules/Shared/PlaceKind (ModuleScript)
-- [SPLIT] 2026-10-16 (notes/place_split.md): which split place this is. One codebase serves the Tutorial, Matchmaking and Ranked
-- places; the only per-place difference is the StringValue ReplicatedStorage.PlaceKind ("Tutorial" / "Matchmaking" / "Ranked"),
-- set by fix/split_place_install.lua. No value (or an unknown one) = nil = the old combined match place (81861384114744),
-- whose behaviour is unchanged. Server and client may require it. No side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceKind = {}
PlaceKind.Kinds = { Tutorial = true, Matchmaking = true, Ranked = true }

-- "Tutorial" / "Matchmaking" / "Ranked", or nil on the old combined place (and in the lobby)
function PlaceKind.Get(): string?
	local v = ReplicatedStorage:FindFirstChild("PlaceKind")
	local kind = v and v:IsA("StringValue") and v.Value or nil
	if kind and PlaceKind.Kinds[kind] then return kind end
	return nil
end

function PlaceKind.Is(kind: string): boolean
	return PlaceKind.Get() == kind
end

-- the starter tutorial may run here (the Tutorial place, or the old combined place)
function PlaceKind.TutorialAllowed(): boolean
	local kind = PlaceKind.Get()
	return kind == nil or kind == "Tutorial"
end

-- a match with this Ranked flag may run here: the Matchmaking place plays casual only, the Ranked place ranked only,
-- the Tutorial place none, the old combined place both
function PlaceKind.MatchAllowed(ranked: boolean?): boolean
	local kind = PlaceKind.Get()
	if kind == nil then return true end
	if kind == "Matchmaking" then return ranked ~= true end
	if kind == "Ranked" then return ranked == true end
	return false
end

return PlaceKind
]==]
--@EMBED_END

-- RoundManager: the split server kinds (inserted before hookWaitingDeaths: joinMatchData, backToLobby, setState are in scope)
local RM_BLOCK = [==[
-- [SPLIT] the server kind on a split place, from the first player: "tutorial", a match TeleportData table, or
-- { SplitReject = reason } (the wrong kind for this place, or no / invalid TeleportData: everyone goes back to the lobby)
local function splitFirst()
	while #Players:GetPlayers() == 0 do task.wait(0.25) end
	local p = Players:GetPlayers()[1]
	local d = joinMatchData(p)
	local ok, td = pcall(function() return p:GetJoinData().TeleportData end)
	td = (ok and type(td) == "table") and td or nil
	local tutorial = (td ~= nil and td.Tutorial == true) or (IS_STUDIO and ReplicatedStorage:GetAttribute("StudioTutorialServer") == true)
	-- Studio only: StudioSoloMatch = "1v1" / "R1v1" plays a solo forfeit match, as on the old place
	local solo = IS_STUDIO and ReplicatedStorage:GetAttribute("StudioSoloMatch")
	if not d and type(solo) == "string" and solo ~= "" then
		d = { Mode = (solo:gsub("^R", "")), Ranked = solo:sub(1, 1) == "R", Teams = { A = { p.UserId }, B = {} }, StudioSolo = true }
	end
	if PLACE_KIND == "Tutorial" then
		if d then return { SplitReject = "a match was sent to the Tutorial place" } end
		-- Studio with no switch: the tutorial (Play in Studio tests this place)
		if tutorial or IS_STUDIO then return "tutorial" end
		return { SplitReject = "no tutorial TeleportData" }
	end
	if tutorial then return { SplitReject = "the tutorial was sent to the " .. PLACE_KIND .. " place" } end
	if not d then return { SplitReject = "no match TeleportData" } end
	if not PlaceKind.MatchAllowed(d.Ranked) then
		return { SplitReject = (d.Ranked == true and "a ranked" or "a casual") .. " match was sent to the " .. PLACE_KIND .. " place" }
	end
	-- the Ranked place always plays ranked (RankedCore deltas), the Matchmaking place never does
	d.Ranked = PLACE_KIND == "Ranked"
	return d
end

-- [SPLIT] nothing runs on a split place that got the wrong players: everyone here (and anyone who arrives) is told and sent
-- back to the lobby after a short notice, again every ~20 s while still here. Studio: the return is only logged (manager._returns).
local function runRejectServer(reason: string)
	manager._rejected = reason
	warn("[RoundManager] [SPLIT] " .. tostring(PLACE_KIND) .. " place: " .. reason .. " - sending everyone back to the lobby")
	ReplicatedStorage:SetAttribute("TestMode", false)
	ReplicatedStorage:SetAttribute("LiveMatch", false)
	setState("Cancelled", 4)
	local sent = {}
	while true do
		for _, p in Players:GetPlayers() do
			if not sent[p] then
				sent[p] = true
				Announce:FireClient(p, "WRONG SERVER", "Taking you back to the lobby...")
				task.delay(4, function()
					if p.Parent then backToLobby({ p }) end
					task.wait(15)
					if p.Parent then sent[p] = nil end
				end)
			end
		end
		task.wait(1)
	end
end

]==]

local EDITS = {
	-- RoundManager 1: the place kind
	{ "RoundManager",
		"local IS_STUDIO = RunService:IsStudio()\nlocal C = MatchConfig\n",
		"local IS_STUDIO = RunService:IsStudio()\n"
			.. "-- [SPLIT] split places (notes/place_split.md): ReplicatedStorage.PlaceKind = Tutorial / Matchmaking / Ranked; nil = the old combined place\n"
			.. "local PlaceKind = require(Shared.PlaceKind)\n"
			.. "local PLACE_KIND = PlaceKind.Get()\n"
			.. "local C = MatchConfig\n" },
	-- RoundManager 2: splitFirst + runRejectServer
	{ "RoundManager",
		"local function hookWaitingDeaths(player: Player)\n",
		RM_BLOCK .. "local function hookWaitingDeaths(player: Player)\n" },
	-- RoundManager 3: a split place decides by its kind
	{ "RoundManager",
		"\t\tlocal first = nil\n\t\twhile first == nil do\n",
		"\t\tlocal first = nil\n"
			.. "\t\t-- [SPLIT] a split place decides by its own kind (splitFirst); without PlaceKind the old loop below runs unchanged\n"
			.. "\t\tif PLACE_KIND then first = splitFirst() end\n"
			.. "\t\twhile first == nil do\n" },
	-- RoundManager 4: rejected -> back to the lobby
	{ "RoundManager",
		"\t\tif first == \"tutorial\" then runTutorialServer()\n",
		"\t\t-- [SPLIT] wrong / missing TeleportData on a split place: back to the lobby\n"
			.. "\t\tif type(first) == \"table\" and first.SplitReject then runRejectServer(first.SplitReject)\n"
			.. "\t\telseif first == \"tutorial\" then runTutorialServer()\n" },
	-- RoundManager 5: test evidence
	{ "RoundManager",
		"\telseif cmd == \"config\" then local old = C[a]; C[a] = b; return old\n",
		"\telseif cmd == \"config\" then local old = C[a]; C[a] = b; return old\n"
			.. "\t-- [SPLIT] the place kind and why this server sent everyone back (nil = it didn't)\n"
			.. "\telseif cmd == \"split\" then return { kind = PLACE_KIND or \"combined\", rejected = manager._rejected, returns = #manager._returns }\n" },
	-- TutorialManager 1: the place kind
	{ "TutorialManager",
		"local Config = require(ReplicatedStorage.Modules.Shared.Config.TutorialConfig)\n",
		"local Config = require(ReplicatedStorage.Modules.Shared.Config.TutorialConfig)\n"
			.. "-- [SPLIT] split places (notes/place_split.md): no tutorial on the Matchmaking / Ranked places\n"
			.. "local PlaceKind = require(ReplicatedStorage.Modules.Shared.PlaceKind)\n" },
	-- TutorialManager 2: no Start (T / Y / U, admin) there
	{ "TutorialManager",
		"local function onStart(player: Player, which: any, chained: boolean?)\n\tif sessions[player] then return end\n",
		"local function onStart(player: Player, which: any, chained: boolean?)\n\tif sessions[player] then return end\n"
			.. "\t-- [SPLIT] the Matchmaking / Ranked places never run the tutorial\n"
			.. "\tif not PlaceKind.TutorialAllowed() then return end\n" },
	-- TutorialManager 3: no auto-start there (Studio's AutoStartInStudio included)
	{ "TutorialManager",
		"local function wantsAutoStart(player: Player): boolean\n",
		"local function wantsAutoStart(player: Player): boolean\n"
			.. "\t-- [SPLIT] never on the Matchmaking / Ranked places (also not in Studio)\n"
			.. "\tif not PlaceKind.TutorialAllowed() then return false end\n" },
}

local STRIP = {
	Tutorial = { { RS, "DuelMaps" } },
	Matchmaking = { { workspace, "FiringRange" } },
	Ranked = { { workspace, "FiringRange" } },
}

local function backup(s)
	local name = "SPLIT_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[SPLIT]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

-- kind layer: put everything in the stash back where it came from
local function restoreStash()
	local stash = SS:FindFirstChild("_SplitStripped")
	if not stash then return end
	for _, item in stash:GetChildren() do
		local from = item:GetAttribute("SplitFrom")
		local parent = from == "Workspace" and workspace or from == "ReplicatedStorage" and RS or nil
		if parent then
			item:SetAttribute("SplitFrom", nil)
			item.Parent = parent
			say("restored", item.Name, "->", parent:GetFullName())
		else
			say("WARN stash item", item.Name, "has no known SplitFrom (" .. tostring(from) .. "): left in the stash")
		end
	end
	if #stash:GetChildren() == 0 then stash:Destroy() end
end

if UNDO then
	restoreStash()
	local v = RS:FindFirstChild("PlaceKind")
	if v and v:GetAttribute("SplitInstall") then v:Destroy(); say("removed ReplicatedStorage.PlaceKind") end
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = manager(e[1])
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[2], 1, true) then say("edit", i, s.Name, "not applied")
			else say("WARN edit", i, s.Name, "neither text found (changed by hand? backup SPLIT_" .. s.Name .. "_Orig kept)") end
		end
	end
	for _, n in { "RoundManager", "TutorialManager" } do
		local s = manager(n)
		local bak = bin:FindFirstChild("SPLIT_" .. n .. "_Orig")
		if s and bak and not s.Source:find("[SPLIT]", 1, true) then
			say(n, bak.Source == s.Source and "matches its backup" or "WARN differs from its backup")
			bak:Destroy()
		end
	end
	local m = shared and shared:FindFirstChild("PlaceKind")
	if m and m:GetAttribute("SplitInstall") then m:Destroy(); say("removed Modules.Shared.PlaceKind") end
else
	-- 1. code layer
	local m = shared:FindFirstChild("PlaceKind")
	if not m then
		m = Instance.new("ModuleScript"); m.Name = "PlaceKind"; m:SetAttribute("SplitInstall", true)
		m.Source = PLACEKIND_SRC; m.Parent = shared
		say("added Modules.Shared.PlaceKind")
	elseif m.Source ~= PLACEKIND_SRC then m.Source = PLACEKIND_SRC; say("updated Modules.Shared.PlaceKind")
	else say("Modules.Shared.PlaceKind already in") end
	for i, e in EDITS do
		local s = manager(e[1])
		if not s then say("WARN missing", e[1])
		elseif s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[2], 1, true)
			if a then
				backup(s)
				s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
	-- 2. kind layer
	local v = RS:FindFirstChild("PlaceKind")
	if v and v.Value ~= KIND then
		say("switching kind", v.Value, "->", KIND)
		restoreStash()
	end
	if not v then
		v = Instance.new("StringValue"); v.Name = "PlaceKind"; v:SetAttribute("SplitInstall", true); v.Parent = RS
	end
	v.Value = KIND
	local stash = SS:FindFirstChild("_SplitStripped")
	for _, t in STRIP[KIND] do
		local item = t[1]:FindFirstChild(t[2])
		if item then
			if not stash then
				stash = Instance.new("Folder"); stash.Name = "_SplitStripped"; stash:SetAttribute("SplitInstall", true); stash.Parent = SS
			end
			item:SetAttribute("SplitFrom", t[1] == workspace and "Workspace" or "ReplicatedStorage")
			item.Parent = stash
			say("stripped", t[1].Name .. "." .. t[2], "-> ServerStorage._SplitStripped")
		elseif stash and stash:FindFirstChild(t[2]) then say(t[2], "already stripped")
		else say("WARN", t[1].Name .. "." .. t[2], "not found") end
	end
	say("PlaceKind =", KIND)
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local h1, d1 = stateHash()
say("after:", h1, "(" .. d1 .. ")")
return table.concat(log, "\n")
