-- client step 1: wait for the vote, vote House, wait until the round is live on it; report spawns, doors, lighting
local flow = RS:WaitForChild("MatchFlow")
local t0 = os.clock()
while RS:GetAttribute("MatchPhase") ~= "MapVote" and os.clock() - t0 < 90 do task.wait(0.25) end
log("phase", RS:GetAttribute("MatchState"), RS:GetAttribute("MatchPhase"), string.format("%.1fs", os.clock() - t0))
local opts = {}
for _, e in RS:WaitForChild("DuelMaps"):GetChildren() do table.insert(opts, e.Name) end
log("registry", table.concat(opts, ","))
flow:FireServer("Vote", "House")
log("voted House")
while RS:GetAttribute("MatchPhase") ~= "Live" and os.clock() - t0 < 180 do task.wait(0.25) end
task.wait(1)
char = lp.Character; hum = char:FindFirstChildOfClass("Humanoid"); root = char:FindFirstChild("HumanoidRootPart")
local Lg = game:GetService("Lighting")
log("phase", RS:GetAttribute("MatchPhase"), "ArenaMap", tostring(RS:GetAttribute("ArenaMap") or (RS:FindFirstChild("ArenaMap") and RS.ArenaMap.Value)),
	string.format("%.1fs", os.clock() - t0), "me", where(), "clock", Lg.ClockTime, "ambient", tostring(Lg.Ambient))
for _, d in workspace.House.Doors:GetChildren() do log(d.Name, d:GetAttribute("DoorState"), "leaf collide", d.Leaf.CanCollide) end
for _, p in game:GetService("Players"):GetPlayers() do log("player", p.Name, p.Character and p.Character:FindFirstChild("HumanoidRootPart") and tostring(plan(p.Character.HumanoidRootPart.Position))) end
for _, m in workspace:GetChildren() do if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(m) then log("npc", m.Name, tostring(plan(m:GetPivot().Position))) end end
return table.concat(LOG, "\n")
