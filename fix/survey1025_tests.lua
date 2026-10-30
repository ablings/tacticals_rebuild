-- fix/survey1025_tests.lua [SURVEY1025] unit tests (Edit mode, any place after fix/survey1025_data.lua):
--   python tools/ranked_test.py --survey1025 <studio_id>      (or paste into execute_luau)
-- 1. LeaveRule.Costs, every case of the leave rule (Systems 7c) on a fresh module instance (the plugin VM caches require).
-- 2. The installed sources carry each fix (structure checks, so a port that drops one fails here).
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local pass, fail, lines = 0, 0, {}
local function check(name, cond)
	if cond then pass += 1 else fail += 1; table.insert(lines, "FAIL " .. name) end
end

-- 1. the rule
local src = SSS.Shared:FindFirstChild("LeaveRule")
check("LeaveRule installed", src ~= nil)
if src then
	local fresh = src:Clone()
	local LR = require(fresh)
	local base = { real = true, roundStarted = true }
	local function with(t) local o = table.clone(base) for k, v in t do o[k] = v end return o end
	check("round 1 started, real match: costs", LR.Costs(base) == true)
	check("before round 1 (loading / vote / loadout): free", LR.Costs(with({ roundStarted = false })) == false)
	check("roundStarted nil: free", LR.Costs({ real = true }) == false)
	check("Studio test-bot match: free", LR.Costs(with({ real = false })) == false)
	check("admin end: free", LR.Costs(with({ aborted = true })) == false)
	check("shutdown: free", LR.Costs(with({ closing = true })) == false)
	check("already charged (Leave then disconnect): once", LR.Costs(with({ charged = true })) == false)
	check("results written: free", LR.Costs(with({ resulted = true })) == false)
	check("victory beat, leaver lost: costs", LR.Costs(with({ over = true, lost = true })) == true)
	check("victory beat, leaver won: free", LR.Costs(with({ over = true, lost = false })) == false)
	check("over with no winner (draw): free", LR.Costs(with({ over = true })) == false)
	check("not a table: free", LR.Costs(nil) == false)
	check("Apply refuses without cost (no write)", LR.Apply(game:GetService("Players").LocalPlayer or Instance.new("Folder"), with({ roundStarted = false }), "test") == false)
	fresh:Destroy()
end

-- 2. the fixes are in the sources of this place
local IS_MATCH = RS:FindFirstChild("PlaceKind") ~= nil
check("round stamp: security round 2", SSS:GetAttribute("Survey1025SecurityRound") == 2)
check("round stamp: data round 2", SSS:GetAttribute("Survey1025DataRound") == 2)
local M =SSS.ServerScripts["[Server] Init"].GameManager.Managers
local function has(inst, text) return inst ~= nil and string.find(inst.Source, text, 1, true) ~= nil end
local DM = SSS.Data.DataManager
check("(2) DataManager class-token cache", has(DM, "classTokens[player.UserId] = token"))
check("(2) DataManager owner guard", has(DM, "DataManagerOwner"))
check("(2b) DataManager before-release hooks", has(DM, "function dataManager.OnBeforeRelease(fn)") and has(DM, "if profile then runBeforeRelease(player, profile) end"))
check("(2b) DataManager shutdown flag", has(DM, "dataManager.Closing = true"))
check("(9) MarkPending settles another server's mark", has(SSS.Shared.RankedServer, "if type(old) == \"table\" and old.job ~= game.JobId then"))
check("(13) Studio_ leaderboards", has(SSS:FindFirstChild("LobbyLeaderboard"), "IsStudio() and \"Studio_\" or \"\") .. b.store"))
local T = require(DM.Template:Clone())
check("(12) Template TutorialDone", T.TutorialDone == false)
check("(12) Template Wraps", type(T.Wraps) == "table" and type(T.Wraps.Owned) == "table" and type(T.Wraps.Equipped) == "table" and type(T.Wraps.Favorites) == "table")
check("(12) Template DuelPairs", type(T.DuelPairs) == "table")
check("(6) SelectWeapon ownership", has(M.CombatManager, "not PlayerStore.Owns(player, weaponId) then return end"))
check("(8) ProcessReceipt waits for the save", has(M.LobbyManager, "if receiptSaved(player) then return Enum.ProductPurchaseDecision.PurchaseGranted end"))
if IS_MATCH then
	check("(10) RoundManager rewards via PlayerStore", has(M.RoundManager, "if replica then PS.Increment(player, path, n) return end"))
	check("(3) RoundManager Leave + disconnect", has(M.RoundManager, "casualLeave(match, m, \"leave\")") and has(M.RoundManager, "casualLeave(match, m, \"disconnect\")"))
	check("(3) RoundManager: a judged Leave is never re-judged", has(M.RoundManager, "m.leaveSettled = true") and has(M.RoundManager, "charged = m.leaveCharged or m.leaveSettled"))
else
	check("(1) lobby FindMatch refuses a caller in a match", has(M.MatchmakingManager, "You're in a match right now!"))
	check("(3) LobbyDuelManager Leave + disconnect", has(M.LobbyDuelManager, "casualLeave(rec.match, rec.member, \"leave\")") and has(M.LobbyDuelManager, "casualLeave(match, m, \"disconnect\")"))
	check("(3) LobbyDuelManager: current duel only, settled leaves skipped", has(M.LobbyDuelManager, "matches[player:GetAttribute(\"DuelMatch\")]") and has(M.LobbyDuelManager, "rec.member.leaveSettled = true"))
	check("(3) LobbyDuelManager: admin end flagged", has(M.LobbyDuelManager, "match.aborted = true -- [SURVEY1025]"))
	check("(7) AssetCheck parked", SSS:FindFirstChild("AssetCheckServer") == nil and game.StarterPlayer.StarterPlayerScripts:FindFirstChild("AssetCheck") == nil)
end
table.insert(lines, 1, ("SURVEY1025 tests (%s): %d passed, %d failed"):format(IS_MATCH and "match" or "lobby", pass, fail))
return table.concat(lines, "\n")
