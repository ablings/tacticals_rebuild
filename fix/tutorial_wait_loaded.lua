-- fix/tutorial_wait_loaded.lua (2026-10-17, Edward: "my friend just loaded in and got placed into the tutorial ... the tutorial
-- started before the map loaded"). The starter tutorial auto-started on a fixed timer (character spawned + AutoStartDelay 2 s),
-- so on a slow device it began while the loading screen / map was still loading. Now autoStart waits for THIS client's
-- loading screen to report in (MatchFlow "Loaded": place, assets, character and UI loaded; ReplicatedFirst.LoadingScreen),
-- up to 60 s, then the usual AutoStartDelay. Tagged "[TUTORIAL] loaded". Match place copies (the Tutorial place).
-- Idempotent; UNDO restores autoStart / Start.
local UNDO = false --@UNDO
local tm = game.ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers.TutorialManager
local src = tm.Source
local TAG = "[TUTORIAL] loaded"

local OLD1 = "\t\tlocal character = player.Character or player.CharacterAdded:Wait()\n\t\tcharacter:WaitForChild(\"HumanoidRootPart\", 10)\n\t\ttask.wait(Config.AutoStartDelay or 2)\n"
local NEW1 = "\t\tlocal character = player.Character or player.CharacterAdded:Wait()\n\t\tcharacter:WaitForChild(\"HumanoidRootPart\", 10)\n"
	.. "\t\t-- " .. TAG .. ": wait for this client's loading screen to report in (MatchFlow \"Loaded\": map + assets), max 60 s\n"
	.. "\t\tlocal t0 = os.clock()\n"
	.. "\t\twhile player.Parent and not clientLoaded[player] and os.clock() - t0 < 60 do task.wait(0.2) end\n"
	.. "\t\t-- the loading screen still crumbles away for ~2-3 s after it reports in\n"
	.. "\t\ttask.wait(math.max(Config.AutoStartDelay or 2, 3.5))\n"
local OLD2 = "local function autoStart(player: Player)\n"
local NEW2 = "-- " .. TAG .. ": [Player] = true once that client's loading screen sent MatchFlow \"Loaded\"\n"
	.. "local clientLoaded = setmetatable({}, { __mode = \"k\" })\n"
	.. "local loadedHooked = false\n"
	.. "local function hookLoaded()\n"
	.. "\tif loadedHooked then return end\n"
	.. "\tloadedHooked = true\n"
	.. "\ttask.spawn(function()\n"
	.. "\t\tlocal mf = game:GetService(\"ReplicatedStorage\"):WaitForChild(\"MatchFlow\", 30)\n"
	.. "\t\tif mf then mf.OnServerEvent:Connect(function(p, kind) if kind == \"Loaded\" then clientLoaded[p] = true end end) end\n"
	.. "\tend)\n"
	.. "end\n"
	.. "local function autoStart(player: Player)\n"
	.. "\thookLoaded()\n"

if UNDO then
	local a, b = src:find(NEW1, 1, true); if a then src = src:sub(1, a - 1) .. OLD1 .. src:sub(b + 1) end
	a, b = src:find(NEW2, 1, true); if a then src = src:sub(1, a - 1) .. OLD2 .. src:sub(b + 1) end
	tm.Source = src
	return "undone"
end
-- (2026-10-18) a half-applied state (the wait loop in, the clientLoaded definition missing) broke the live tutorial: the
-- auto-start threw "attempt to index nil" and never started. "Already applied" now means BOTH parts are in.
if src:find(TAG, 1, true) and src:find("local clientLoaded", 1, true) then return "already applied" end
if src:find(TAG, 1, true) then error("half-applied [TUTORIAL] loaded edit found: fix it by hand (see notes) before re-running") end
assert(src:find(OLD1, 1, true), "autoStart wait not found")
assert(src:find(OLD2, 1, true), "autoStart not found")
local a, b = src:find(OLD1, 1, true); src = src:sub(1, a - 1) .. NEW1 .. src:sub(b + 1)
a, b = src:find(OLD2, 1, true); src = src:sub(1, a - 1) .. NEW2 .. src:sub(b + 1)
local f, err = loadstring(src)
assert(f, "syntax: " .. tostring(err))
tm.Source = src
return "tutorial now waits for the client's Loaded"
