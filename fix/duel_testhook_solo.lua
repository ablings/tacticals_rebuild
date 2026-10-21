-- fix/duel_testhook_solo.lua (Studio-only test hook) 2026-10-20: ServerStorage.DuelTestHook:Invoke("solo", userId, mode) starts a
-- solo duel for that player against a test bot (LobbyDuelManager._TestSolo), so the MCP can reproduce ;duelsolo. The hook itself
-- is never created in a live server. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local m = game:GetService("ServerScriptService"):FindFirstChild("LobbyDuelManager", true)
local old = "\tif cmd == \"bots\" then return manager._TestBots(a)\n"
local new = "\tif cmd == \"bots\" then return manager._TestBots(a)\n\telseif cmd == \"solo\" then return manager._TestSolo(Players:GetPlayerByUserId(a), b) -- (Studio test: ;duelsolo)\n"
local s = m.Source
if UNDO then old, new = new, old end
if s:find(new, 1, true) and not UNDO then return "already" end
local a, b = s:find(old, 1, true)
assert(a, "anchor not found")
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
m.Source = s
return "ok"
