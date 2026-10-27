-- client step 1 (round 6): wait for the vote, vote Warehouse 2, wait until the round is live on it
local RS = game:GetService("ReplicatedStorage")
local flow = RS:WaitForChild("MatchFlow")
local t0 = os.clock()
while RS:GetAttribute("MatchPhase") ~= "MapVote" and os.clock() - t0 < 60 do task.wait(0.25) end
log("phase", RS:GetAttribute("MatchState"), RS:GetAttribute("MatchPhase"), string.format("%.1fs", os.clock() - t0))
flow:FireServer("Vote", "Warehouse2")
log("voted Warehouse2")
while RS:GetAttribute("MatchPhase") ~= "Live" and os.clock() - t0 < 150 do task.wait(0.25) end
task.wait(1)
char = lp.Character; hum = char:FindFirstChildOfClass("Humanoid"); root = char:FindFirstChild("HumanoidRootPart")
local L = game:GetService("Lighting")
log("phase", RS:GetAttribute("MatchPhase"), "ArenaMap", tostring(RS:GetAttribute("ArenaMap") or (RS:FindFirstChild("ArenaMap") and RS.ArenaMap.Value)),
	string.format("%.1fs", os.clock() - t0), "me", where(), "clock", L.ClockTime, "ambient", tostring(L.Ambient))
for _, d in game:GetService("CollectionService"):GetTagged("Warehouse2Door") do log(d.Name, "Open", d:GetAttribute("Open"), "shutter collide", d.Shutter.CanCollide) end
return table.concat(LOG, "\n")
