-- Server: start a Test-place match through the Studio hook. MAP, MODE (1v1/3v3), VS (bots/admins); or CMD=info / end
local SS = game:GetService("ServerStorage")
local hook = SS:WaitForChild("TestPlaceHook", 20)
if "{{CMD}}" == "info" then local i = hook:Invoke("info"); return game:GetService("HttpService"):JSONEncode(i) end
local p = game.Players:GetPlayers()[1]
local ok, r1, r2 = pcall(function() return hook:Invoke("start", p.UserId, "{{MAP}}", "{{MODE}}", "{{VS}}") end)
return tostring(ok) .. " " .. tostring(r1) .. " " .. tostring(r2) .. " state " .. tostring(game.ReplicatedStorage:GetAttribute("MatchState"))
