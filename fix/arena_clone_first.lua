-- fix/arena_clone_first.lua [ARENAFIRST] 2026-10-23 (lobby only). Edward (mobile, fresh account): in a lobby pad duel "the other
-- player stands in an empty void instead of the picked map" during the vote / loadout. ArenaLoader (StarterPlayerScripts) waited
-- for ContentProvider:PreloadAsync (up to 8 s, slow on a cold phone cache) BEFORE cloning the map's Visual layer, so the arena was
-- empty for most of the loadout. Now the map is cloned at once and the preload runs behind it; "Loaded" still waits for it.
-- Same edit as scripts/duels/ArenaLoader.client.lua. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local AL = game:GetService("StarterPlayer"):FindFirstChild("ArenaLoader", true)
assert(AL, "no ArenaLoader")
local old, new = [==[	local done = false
	task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, assets); done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do task.wait(0.1) end
	if matchId() ~= id or not state.Parent then busy = false; return end
	local clone = template:Clone()
	clone.Name = info.WorkspaceName or info.Id
	clone:PivotTo(CFrame.new(origin))
	clone:SetAttribute("DuelArena", id)
	clone.Parent = workspace
	loaded = { id = id, map = mapId, clone = clone, saved = swapLighting(info.Folder:FindFirstChild("Lighting")) }
	loaded.conns = bindDynamic(id, info, clone)
	busy = false
]==], [==[	-- [ARENAFIRST] 2026-10-23 (Edward, mobile / fresh account: "the other player stands in an empty void instead of the picked
	-- map"): the map goes in at once and the meshes / textures stream in behind the loadout screen; "Loaded" still waits for the
	-- preload (capped at 8 s). Before, the clone waited for the preload, which on a cold phone cache took most of the loadout.
	local clone = template:Clone()
	clone.Name = info.WorkspaceName or info.Id
	clone:PivotTo(CFrame.new(origin))
	clone:SetAttribute("DuelArena", id)
	clone.Parent = workspace
	loaded = { id = id, map = mapId, clone = clone, saved = swapLighting(info.Folder:FindFirstChild("Lighting")) }
	loaded.conns = bindDynamic(id, info, clone)
	busy = false
	local done = false
	task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, assets); done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do task.wait(0.1) end
	if matchId() ~= id or not state.Parent then return end
]==]
local s = AL.Source:gsub("\r\n", "\n")
if UNDO then old, new = new, old end
local done
if UNDO then done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
if done then return "ArenaLoader =" end
local a, b = s:find(old, 1, true)
assert(a, "ArenaLoader anchor not found")
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "ArenaLoader would not parse")
AL.Source = s
return "ArenaLoader +"
