-- data_release_install.lua : profile hand-off around teleports + headshot flag on HitConfirm (notes/data_release.md), 2026-10-16.
-- Runs in BOTH places (idempotent; the place is detected: lobby = Workspace.LobbyMap exists):
--   lobby       python tools/run_luau.py fix/data_release_install.lua            (studio id in tools/run_luau.py, 8ef4e21a)
--   match place same file through execute_luau in 331cb3a0 (or mcpcli.py call execute_luau)
-- [DATA] edits (string swap; UNDO swaps back; backups ServerStorage._RebuildRemoved.DATA_<name>_Orig taken before the first edit):
--   Data.DataManager (both): LoadProfileAsync(.., "ForceLoad") + load time log; release listener ignores teleport releases;
--     new DataManager.ReleaseForTeleport / RestoreAfterTeleportFail / IsReleased (+ TeleportInitFailed hook, 30 s auto-restore)
--   lobby: QueueManager.deploy, MatchmakingManager.deliver, NewPlayerTutorial: release before TeleportAsync, restore on failure
--   match: RoundManager.backToLobby, TutorialManager (tutorial done -> lobby): release before, restore after 3 failed tries
--   CombatManager (both): HitConfirm gets a 4th client argument `headshot` (true = critical headshot)
-- NOTE: tools/match_place_build.py rewrites RoundManager from scripts/match/: re-run this install after it.
-- UNDO: python tools/run_luau.py fix/data_release_install.lua UNDO   (match place: set the --@UNDO line to true)
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil
local rec = CHS:TryBeginRecording("DATA release install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = { "place: " .. (IS_LOBBY and "lobby" or "match") }
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function manager(name)
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	local m = init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
	return m and m:FindFirstChild(name)
end
local function dataManager() return SSS:FindFirstChild("Data") and SSS.Data:FindFirstChild("DataManager") end

-- DataManager: the hand-off block, inserted before PlayerAdded (profileStore / dataManager / Players are in scope there)
local DM_BLOCK = [==[
-- [DATA] teleport hand-off (notes/data_release.md). Profiles are otherwise released only on PlayerRemoving, so the
-- destination server waited for this server's session lock (up to ~1 min with ForceLoad) after every teleport.
-- ReleaseForTeleport saves + releases right before TeleportAsync; the data table stays readable and writable, but
-- nothing written after the release is saved. If the teleport fails the profile is loaded again here (see Restore).
dataManager.Released = {}
local TeleportService = game:GetService("TeleportService")
-- [DATA] a released player still here this long after the release gets the profile back (teleport silently lost)
local AUTO_RESTORE_AFTER = 30
local hooked = false

function dataManager._logLoad(player: Player, secs: number, ok: boolean, what: string?)
	local msg = ("[DATA] profile %s for %s (%d) in %.2f s"):format(what or (ok and "loaded" or "FAILED"), player.Name, player.UserId, secs)
	if ok and secs < 5 then print(msg) else warn(msg) end
	player:SetAttribute("DataLoadTime", math.floor(secs * 100 + 0.5) / 100)
end

-- the profile's release listener: a release we made for a teleport keeps the player and the data; any other release
-- (another server took the profile, or the player is leaving) drops the data and kicks, as before
function dataManager._onReleased(player: Player, profile)
	local r = dataManager.Released[player]
	if r and r.profile == profile then return end
	if dataManager.Profiles[player] == profile then dataManager.Profiles[player] = nil end
	player:Kick()
end

function dataManager.IsReleased(player: Player): boolean
	return dataManager.Released[player] ~= nil
end

local function waitHopReady(profile, timeout: number): boolean
	local ready = false
	profile:ListenToHopReady(function() ready = true end)
	local deadline = os.clock() + timeout
	while not ready and os.clock() < deadline do task.wait(0.05) end
	return ready
end

local function ensureHooks()
	if hooked then return end
	hooked = true
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		if dataManager.Released[player] then
			task.spawn(dataManager.RestoreAfterTeleportFail, player, tostring(result) .. ": " .. tostring(message))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if not dataManager.Released[player] then return end
		-- deferred: PlayerRemoving above destroys the replica first; the released profile is never released twice
		task.defer(function()
			local replica = dataManager.DataReplicas[player]
			if replica then replica:Destroy(); dataManager.DataReplicas[player] = nil end
			dataManager.Profiles[player] = nil
			dataManager.Released[player] = nil
		end)
	end)
end

-- Save + release the profiles of `players` (a Player or a list) right before a teleport. Yields until the release
-- saves have landed (ProfileService hop-ready) or `timeout` (default 8 s). Returns true when every save landed.
-- Safe to call twice and for players without a profile.
function dataManager.ReleaseForTeleport(players, timeout: number?): boolean
	if typeof(players) == "Instance" then players = { players } end
	ensureHooks()
	local pending = {}
	for _, player in players do
		local profile = dataManager.Profiles[player]
		local r = dataManager.Released[player]
		if r then
			if r.profile == profile then table.insert(pending, profile) end
		elseif profile and profile:IsActive() then
			r = { profile = profile, at = os.clock(), loadCount = profile.MetaData.SessionLoadCount }
			dataManager.Released[player] = r
			profile:Release()
			table.insert(pending, profile)
			print(("[DATA] released %s for a teleport"):format(player.Name))
			task.delay(AUTO_RESTORE_AFTER, function()
				if dataManager.Released[player] == r and player.Parent then
					dataManager.RestoreAfterTeleportFail(player, "still here " .. AUTO_RESTORE_AFTER .. " s after the release")
				end
			end)
		end
	end
	local t0, ok = os.clock(), true
	for _, profile in pending do
		ok = waitHopReady(profile, math.max(0, (timeout or 8) - (os.clock() - t0))) and ok
	end
	if not ok then warn("[DATA] release save not confirmed before the teleport (the destination's ForceLoad still gets it)") end
	return ok
end

-- The teleport failed and the player is still here: load the profile again (the release made it free, so the load is
-- instant). The reloaded profile adopts the data table everyone already holds (replica, readers), so nothing has to
-- re-bind; writes made while released are kept from now on. If another server loaded the profile in between (its copy
-- is newer) or it can't be loaded, the player is kicked with a message instead: never two live copies.
function dataManager.RestoreAfterTeleportFail(player: Player, why: string?): boolean
	local r = dataManager.Released[player]
	if not r or r.restoring then return false end
	r.restoring = true
	warn(("[DATA] teleport failed for %s (%s): loading the profile again"):format(player.Name, tostring(why)))
	waitHopReady(r.profile, 10)
	local t0 = os.clock()
	local profile = player.Parent and profileStore:LoadProfileAsync("Player_" .. player.UserId, function() return "Cancel" end)
	if dataManager.Released[player] ~= r or not player.Parent then
		if profile then profile:Release() end
		return false
	end
	if profile and profile.MetaData.SessionLoadCount == (r.loadCount or 0) + 1 then
		profile.Data = r.profile.Data
		profile:AddUserId(player.UserId)
		dataManager.Profiles[player] = profile
		dataManager.Released[player] = nil
		profile:ListenToRelease(function() dataManager._onReleased(player, profile) end)
		dataManager._logLoad(player, os.clock() - t0, true, "re-loaded after a failed teleport")
		return true
	end
	if profile then profile:Release() end
	dataManager._logLoad(player, os.clock() - t0, false, "NOT re-loaded (another server has or had it): kicking")
	dataManager.Released[player] = nil
	dataManager.Profiles[player] = nil
	local replica = dataManager.DataReplicas[player]
	if replica then replica:Destroy(); dataManager.DataReplicas[player] = nil end
	player:Kick("Your teleport didn't go through and your save couldn't be reopened on this server. Please rejoin.")
	return false
end
-- [/DATA]

]==]

local REQ = 'require(game:GetService("ServerScriptService").Data.DataManager)'
local EDITS = {
	-- 1-3 DataManager (both places)
	{ dataManager, "both",
		'\tlocal profile = profileStore:LoadProfileAsync("Player_"..player.UserId)\n',
		'\t-- [DATA] explicit not_released_handler + load time per player (slow loads warn)\n'
			.. '\tlocal loadStart = os.clock()\n'
			.. '\tlocal profile = profileStore:LoadProfileAsync("Player_"..player.UserId, "ForceLoad")\n'
			.. '\tdataManager._logLoad(player, os.clock() - loadStart, profile ~= nil)\n' },
	{ dataManager, "both",
		'\t\tprofile:ListenToRelease(function()\n\t\t\tdataManager.Profiles[player] = nil\n\t\t\tplayer:Kick()\n\t\tend)\n',
		'\t\t-- [DATA] a release made for a teleport keeps the player (DataManager._onReleased)\n'
			.. '\t\tprofile:ListenToRelease(function() dataManager._onReleased(player, profile) end)\n' },
	{ dataManager, "both",
		'local function PlayerAdded(player : Player)\n',
		DM_BLOCK .. 'local function PlayerAdded(player : Player)\n' },
	-- 4 lobby QueueManager.deploy (pads -> match place; only when in-lobby duels are off)
	{ function() return manager("QueueManager") end, "lobby",
		'\t\tlocal okTp, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, players, options)\n'
			.. '\t\tif not okTp then\n'
			.. '\t\t\twarn("[QueueManager] TeleportAsync failed: " .. tostring(err))\n',
		'\t\t-- [DATA] save + release the profiles first so the match server loads them at once; restore if the call fails\n'
			.. '\t\tlocal DataManager = ' .. REQ .. '\n'
			.. '\t\tDataManager.ReleaseForTeleport(players)\n'
			.. '\t\tlocal okTp, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, players, options)\n'
			.. '\t\tif not okTp then\n'
			.. '\t\t\tfor _, p in players do task.spawn(DataManager.RestoreAfterTeleportFail, p, tostring(err)) end\n'
			.. '\t\t\twarn("[QueueManager] TeleportAsync failed: " .. tostring(err))\n' },
	-- 5 lobby MatchmakingManager.deliver (PLAY / global queue -> match place)
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, { player }, options)\n'
			.. '\tif not ok then\n'
			.. '\t\twarn("[Matchmaking] TeleportAsync failed: " .. tostring(err))\n',
		'\t-- [DATA] save + release the profile first so the match server loads it at once; restore if the call fails\n'
			.. '\tlocal DataManager = ' .. REQ .. '\n'
			.. '\tDataManager.ReleaseForTeleport(player)\n'
			.. '\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.MatchPlaceId, { player }, options)\n'
			.. '\tif not ok then\n'
			.. '\t\ttask.spawn(DataManager.RestoreAfterTeleportFail, player, tostring(err))\n'
			.. '\t\twarn("[Matchmaking] TeleportAsync failed: " .. tostring(err))\n' },
	-- 6 lobby NewPlayerTutorial (new player -> tutorial place)
	{ function() return SSS:FindFirstChild("NewPlayerTutorial") end, "lobby",
		'\ttask.wait(1.5) -- let the profile save its release before the hop\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.TutorialPlaceId, { player }, opts) end)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[NewPlayerTutorial] teleport failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n',
		'\ttask.wait(1.5) -- let the profile save its release before the hop\n'
			.. '\t-- [DATA] actually save + release it (the wait above never did); restore after 3 failed tries\n'
			.. '\tDataManager.ReleaseForTeleport(player)\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.TutorialPlaceId, { player }, opts) end)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[NewPlayerTutorial] teleport failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n'
			.. '\tif player.Parent then DataManager.RestoreAfterTeleportFail(player, "3 teleport tries failed") end\n' },
	-- 7 match RoundManager.backToLobby (results / leave / cancel / admin end -> lobby)
	{ function() return manager("RoundManager") end, "match",
		'\tif #list == 0 then return end\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, LOBBY_PLACE, list)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[RoundManager] back to lobby failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n',
		'\tif #list == 0 then return end\n'
			.. '\t-- [DATA] save + release the profiles first so the lobby loads them at once; restore after 3 failed tries\n'
			.. '\tlocal DataManager = ' .. REQ .. '\n'
			.. '\tDataManager.ReleaseForTeleport(list)\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, LOBBY_PLACE, list)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[RoundManager] back to lobby failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n'
			.. '\tfor _, p in list do if p.Parent then task.spawn(DataManager.RestoreAfterTeleportFail, p, "3 teleport tries failed") end end\n' },
	-- 8 match TutorialManager (tutorial done -> lobby)
	{ function() return manager("TutorialManager") end, "match",
		'\tlocal TeleportService = game:GetService("TeleportService")\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.LobbyPlaceId, { player }) end)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[TutorialManager] teleport to lobby failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n',
		'\tlocal TeleportService = game:GetService("TeleportService")\n'
			.. '\t-- [DATA] save + release the profile (TutorialDone included) first; restore after 3 failed tries\n'
			.. '\tlocal DataManager = ' .. REQ .. '\n'
			.. '\tDataManager.ReleaseForTeleport(player)\n'
			.. '\tfor attempt = 1, 3 do\n'
			.. '\t\tlocal ok, err = pcall(function() TeleportService:TeleportAsync(Config.LobbyPlaceId, { player }) end)\n'
			.. '\t\tif ok then return end\n'
			.. '\t\twarn("[TutorialManager] teleport to lobby failed (" .. attempt .. "): " .. tostring(err))\n'
			.. '\t\ttask.wait(3)\n'
			.. '\tend\n'
			.. '\tif player.Parent then DataManager.RestoreAfterTeleportFail(player, "3 teleport tries failed") end\n' },
	-- 9 CombatManager (both): critical-headshot flag for the shooter's crosshair
	{ function() return manager("CombatManager") end, "both",
		'\tCombat.HitConfirm:FireClient(player, zone, damage, victimHumanoid.Health <= 0)\n',
		'\t-- [DATA] HitConfirm 4th client arg headshot = critical headshot: Head zone and the gun\'s Head damage beats its Body damage (the 2x crit)\n'
			.. '\tlocal headshot = zone == "Head" and (config.Damage.Head or 0) > (config.Damage.Body or 0)\n'
			.. '\tCombat.HitConfirm:FireClient(player, zone, damage, victimHumanoid.Health <= 0, headshot)\n' },
}

local function backup(s)
	local name = "DATA_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[DATA]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

local function applies(e) return e[2] == "both" or (e[2] == "lobby") == IS_LOBBY end

if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = applies(e) and e[1]()
		if s then
			local a, b = s.Source:find(e[4], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "not applied")
			else say("WARN edit", i, s.Name, "neither text found (changed by hand? backup DATA_" .. s.Name .. "_Orig kept)") end
			local bak = bin:FindFirstChild("DATA_" .. s.Name .. "_Orig")
			if bak and not s.Source:find("[DATA]", 1, true) then
				say(s.Name, bak.Source == s.Source and "matches its backup" or "WARN differs from its backup")
				bak:Destroy()
			end
		end
	end
else
	for i, e in EDITS do
		local s = applies(e) and e[1]()
		if not applies(e) then -- other place
		elseif not s then say("WARN missing script for edit", i)
		elseif s.Source:find(e[4], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[3], 1, true)
			if a then
				backup(s)
				s.Source = s.Source:sub(1, a - 1) .. e[4] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
