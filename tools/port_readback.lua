-- Port read-back (tools/port_readback.lua, live port 51): ids, install stamps, UI markers, Test-only House work absent, leftovers, compile
local RS, SSS, SS, SG = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("StarterGui")
local CS = game:GetService("CollectionService")
local out = {}
local function add(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " ") end
add("PlaceId", game.PlaceId, "| PlaceVersion", game.PlaceVersion)
local pk = RS:FindFirstChild("PlaceKind") add("PlaceKind", pk and pk.Value or (workspace:FindFirstChild("LobbyMap") and "lobby" or "?"))
local maps = {} local dm = RS:FindFirstChild("DuelMaps") if dm then for _, m in dm:GetChildren() do maps[#maps+1] = m.Name end end
add("DuelMaps", table.concat(maps, ","))
local cc = RS:FindFirstChild("CoverConfig", true)
add("MoveRework1029Round", cc and cc:GetAttribute("MoveRework1029Round"), "| MoveRules", RS:FindFirstChild("MoveRules", true) ~= nil, "| NoClimb", (function() local n = #CS:GetTagged("NoClimb") for _, d in workspace:GetDescendants() do if d:GetAttribute("NoClimb") == true then n += 1 end end for _, d in SS:GetDescendants() do if d:GetAttribute("NoClimb") == true then n += 1 end end return n end)())
add("Survey1025 security", SSS:GetAttribute("Survey1025SecurityRound"), "data", SSS:GetAttribute("Survey1025DataRound"), "| LeaveRule", SSS:FindFirstChild("LeaveRule", true) ~= nil)
local th = RS:FindFirstChild("UIKit") and RS.UIKit:FindFirstChild("Theme")
local usc = game.StarterPlayer:FindFirstChild("UIStyleController", true)
add("UI r2: Theme.stroke", th and th.Source:find("Theme.stroke =", 1, true) ~= nil,
	"| UIStyleController", usc and (usc.Source:find("^%-%- %[UISURVEY%]") and "stubbed" or "original") or "none",
	"| MainUI.ResetOnSpawn", SG:FindFirstChild("MainUI") and SG.MainUI.ResetOnSpawn,
	"| HUD UISurveyScale", SG:FindFirstChild("HUD") and SG.HUD:GetAttribute("UISurveyScale"))
local cov = game.StarterPlayer:FindFirstChild("CoverController", true)
add("GLASS client edits (Cover)", cov and cov.Source:find("GLASS", 1, true) ~= nil)
-- the Test place's House 1965 / illusion work must not be here
local houseArt = nil
for _, h in ipairs({ workspace:FindFirstChild("House"), SS:FindFirstChild("House", true) }) do if h and h:GetAttribute("ArtVersion") then houseArt = h:GetAttribute("ArtVersion") end end
local rm = SSS:FindFirstChild("RoundManager", true)
add("House ArtVersion", houseArt, "| HouseIllusionKit", SS:FindFirstChild("HouseIllusionKit") ~= nil, "| HouseFarField", game:FindFirstChild("HouseFarField", true) ~= nil,
	"| applyMapSky", rm and rm.Source:find("applyMapSky", 1, true) ~= nil, "| WallCover maps", (function() local n = 0 for _, d in game:GetDescendants() do if d:GetAttribute("WallCover") == true then n += 1 end end return n end)())
add("SmokeAlarmRound", (function() for _, d in SSS:GetDescendants() do if d:GetAttribute("SmokeAlarmRound") then return d:GetAttribute("SmokeAlarmRound") end end return nil end)(),
	"| LobbySteamFillRound", (function() for _, d in game:GetDescendants() do if d:GetAttribute("LobbySteamFillRound") then return d:GetAttribute("LobbySteamFillRound") end end return nil end)())
local lc = RS:FindFirstChild("LobbyConfig", true)
if lc and workspace:FindFirstChild("LobbyMap") then add("TestPlaceId", require(lc).TestPlaceId, "| AssetCheck parked", SS:FindFirstChild("_Survey1025Disabled") and #SS._Survey1025Disabled:GetChildren()) end
add("StudioTeleportData", RS:GetAttribute("StudioTeleportData"), "| DuelTestSolo", RS:GetAttribute("DuelTestSolo"), "| StudioLeaveTest", RS:FindFirstChild("StudioLeaveTest") ~= nil,
	"| StudioTutorialServer", RS:GetAttribute("StudioTutorialServer"), "| hooks", SS:FindFirstChild("MatchTestHook") ~= nil or SS:FindFirstChild("DuelTestHook") ~= nil)
local bad, n, marks = {}, 0, {}
for _, s in game:GetDescendants() do
	if s:IsA("LuaSourceContainer") then
		n += 1
		local ok, src = pcall(function() return s.Source end)
		if ok then
			local f, err = loadstring(src)
			if not f then table.insert(bad, s:GetFullName() .. ": " .. tostring(err)) end
			if src:find("--TESTONLY", 1, true) or src:find("HOUSE2P", 1, true) then table.insert(marks, s:GetFullName()) end
		end
	end
end
add("compile", #bad == 0 and ("all ok (" .. n .. ")") or table.concat(bad, " | "))
add("test marks", #marks, table.concat(marks, ","))
return table.concat(out, "\n")
