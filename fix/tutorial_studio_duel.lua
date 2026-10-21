-- fix/tutorial_studio_duel.lua [TUTSTUDIO] 2026-10-21: in Studio the starter tutorial auto-starts (TutorialConfig.AutoStartInStudio),
-- even while ReplicatedStorage.StudioTeleportData simulates a duel, so duel tests showed the cover tutorial's "LEAVE COVER" box
-- and the Instructor bot shot into the arena (overnight playtest + UI session's 4:3 check). Live is unchanged: there it only
-- starts for players sent with TeleportData { Tutorial = true }. Now Studio skips the auto-start while a duel is simulated.
-- Match places (TutorialManager). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local TM = game:GetService("ServerScriptService"):FindFirstChild("TutorialManager", true)
assert(TM, "no TutorialManager")
local old = "if RunService:IsStudio() then return Config.AutoStartInStudio == true end"
local new = "if RunService:IsStudio() then return Config.AutoStartInStudio == true and not game:GetService(\"ReplicatedStorage\"):GetAttribute(\"StudioTeleportData\") end -- [TUTSTUDIO] not during a simulated duel"
local s = TM.Source
if UNDO then old, new = new, old end
if s:find(new, 1, true) then return UNDO and "already undone" or "already" end
local a, b = s:find(old, 1, true)
assert(a, "anchor not found")
assert(not s:find(old, b + 1, true), "anchor not unique")
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
TM.Source = s
return "TutorialManager ok"
