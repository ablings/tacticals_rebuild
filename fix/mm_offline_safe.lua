-- fix/mm_offline_safe.lua  (Edward 2026-10-16: "yes, small safe fix")
-- MatchmakingManager called MemoryStoreService:GetHashMap at require time. In an unpublished place that throws, the module
-- fails to load and FindMatch answers "Unknown action". This patch loads the module anyway: when MemoryStore isn't
-- available it sets OFFLINE, FindMatch replies "offline", and the matchmaker loop doesn't start. A published game gets the
-- maps as before, so nothing changes live.
-- Idempotent. `python tools/run_luau.py fix/mm_offline_safe.lua UNDO` restores the original from the backup.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local mod = SSS.ServerScripts["[Server] Init"].GameManager.Managers.MatchmakingManager
local rr = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
rr.Name = "_RebuildRemoved"; rr.Parent = SS
local BACK = "MatchmakingManager_Orig"

if UNDO then
	local b = rr:FindFirstChild(BACK)
	if not b then return "no backup; nothing to undo" end
	mod.Source = b.Source
	b:Destroy()
	return "restored original MatchmakingManager"
end

local src = mod.Source
if src:find("%[MM%] offline%-safe init", 1) then return "already patched" end
if not rr:FindFirstChild(BACK) then
	local b = Instance.new("ModuleScript"); b.Name = BACK; b.Source = src; b.Parent = rr
end

local function replaceOnce(s, old, new)
	local a, z = s:find(old, 1, true)
	assert(a, "pattern not found: " .. old:sub(1, 60))
	return s:sub(1, a - 1) .. new .. s:sub(z + 1)
end

src = replaceOnce(src,
	'local results = MemoryStoreService:GetHashMap(PREFIX .. "MM_Results")\n'
	.. 'local locks = MemoryStoreService:GetHashMap(PREFIX .. "MM_Locks")\n'
	.. 'local stats = MemoryStoreService:GetHashMap(PREFIX .. "MM_Stats")\n',
	'-- [MM] offline-safe init (Edward 2026-10-16): MemoryStore throws in an unpublished place; load anyway and report offline\n'
	.. 'local OFFLINE = false\n'
	.. 'local function memMap(name: string)\n'
	.. '\tlocal ok, map = pcall(function() return MemoryStoreService:GetHashMap(name) end)\n'
	.. '\tif ok then return map end\n'
	.. '\tOFFLINE = true\n'
	.. '\treturn nil\n'
	.. 'end\n'
	.. 'local results = memMap(PREFIX .. "MM_Results")\n'
	.. 'local locks = memMap(PREFIX .. "MM_Locks")\n'
	.. 'local stats = memMap(PREFIX .. "MM_Stats")\n'
	.. 'MatchmakingManager.IsOffline = function() return OFFLINE end\n')

src = replaceOnce(src,
	'\tif not q then return { ok = false, msg = "Unknown queue" } end\n',
	'\tif not q then return { ok = false, msg = "Unknown queue" } end\n'
	.. '\t-- [MM] offline-safe: no MemoryStore here (unpublished place)\n'
	.. '\tif OFFLINE then return { ok = false, offline = true, msg = "Online matchmaking is offline here" } end\n')

src = replaceOnce(src,
	'\tReplicatedStorage:SetAttribute("MM_Counts", "{}")\n',
	'\tReplicatedStorage:SetAttribute("MM_Counts", "{}")\n'
	.. '\t-- [MM] offline-safe: no matchmaker loop without MemoryStore\n'
	.. '\tif OFFLINE then print("[Matchmaking] offline: MemoryStore unavailable (unpublished place)"); return end\n')

mod.Source = src
return "patched MatchmakingManager (backup in ServerStorage._RebuildRemoved." .. BACK .. ")"
