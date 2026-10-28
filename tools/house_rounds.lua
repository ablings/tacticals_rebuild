-- server step: rounds me (+ bots) vs bots on House via MatchTestHook "kill"; each round logs every player's / bot's spawn
-- (plan coords), the map, door states, and the broken-glass count at round start (a pane broken in round 1 must be back in
-- round 2: GlassTestHook "shoot" breaks one in round 1)
local SS, RS = game:GetService("ServerStorage"), game:GetService("ReplicatedStorage")
local hook = SS:WaitForChild("MatchTestHook", 10)
local GH = SS:FindFirstChild("GlassTestHook")
local O = workspace.House:GetAttribute("PlanOrigin")
local function plan(v) local p = v - O return string.format("(%.1f, %.1f, %.1f)", p.X, -p.Z, p.Y - 3) end
local log = {}
local ROUNDS = 5 --@ROUNDS
local function bodies()
	local t = {}
	for _, p in game:GetService("Players"):GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(t, p.Name .. " " .. plan(r.Position)) end
	end
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m.Name:match("Bot") and m:FindFirstChild("HumanoidRootPart") then table.insert(t, m.Name .. " " .. plan(m.HumanoidRootPart.Position)) end
	end
	return table.concat(t, "; ")
end
local function broken()
	local n = 0
	for _, w in workspace.House.Shootables:GetChildren() do if w:GetAttribute("GlassBroken") then n += 1 end end
	return n
end
local me = game:GetService("Players"):GetPlayers()[1].UserId
for r = 1, ROUNDS do
	local t0 = os.clock()
	while RS:GetAttribute("MatchPhase") ~= "Playing" and os.clock() - t0 < 30 do task.wait(0.2) end
	task.wait(0.5)
	local doors = {}
	for _, d in workspace.House.Doors:GetChildren() do table.insert(doors, d.Name:sub(6) .. "=" .. tostring(d:GetAttribute("DoorState"))) end
	table.insert(log, string.format("round %d: map %s, broken panes at start %d; %s; doors %s", r, tostring(RS:GetAttribute("ArenaMap")), broken(), bodies(), table.concat(doors, ",")))
	if r == 1 and GH then
		-- break a pane the player can see from the living-room spawn side (the west window), then check the count
		GH:Invoke("shoot", "House/Win_LR_W")
		table.insert(log, "  round 1: shot Win_LR_W -> broken panes " .. broken())
	end
	local info = hook:Invoke("info")
	local victims = {}
	for _, m in workspace:GetChildren() do if m:IsA("Model") and m.Name:match("Bot") and m:FindFirstChildOfClass("Humanoid") then table.insert(victims, m) end end
	-- kill every bot on team B (the test hook takes user ids: bots are -1, -2, ...)
	for k = 1, 6 do local ok = hook:Invoke("kill", -k, me) end
	task.wait(1)
	local t1 = os.clock()
	while RS:GetAttribute("MatchPhase") == "Playing" and os.clock() - t1 < 10 do task.wait(0.2) end
	if RS:GetAttribute("MatchState") ~= "Live" then break end
end
task.wait(3)
local fin = hook:Invoke("info")
table.insert(log, "end " .. tostring(RS:GetAttribute("MatchState")) .. " " .. tostring(RS:GetAttribute("MatchPhase")) .. " score A " .. tostring(fin and fin.scoreA) .. " B " .. tostring(fin and fin.scoreB))
return table.concat(log, "\n")
