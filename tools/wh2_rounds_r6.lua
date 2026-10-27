-- server step (round 6): 5 rounds me vs the Studio test bot on Warehouse 2 via MatchTestHook "kill"; each round logs both
-- spawns (plan coords), the map, and that both doors are shut and solid at round start
local SS, RS, CS = game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), game:GetService("CollectionService")
local hook = SS:WaitForChild("MatchTestHook", 10)
local O = Vector3.new(-84.2, 0.4, -300)
local function plan(v) local p = v - O return string.format("(%.1f, %.1f)", -p.X, p.Z) end
local log = {}
local info = hook:Invoke("info")
-- info.members are display strings; the test bot is userId -1 (RoundManager: { isBot = true, userId = -botN })
local me = game:GetService("Players"):GetPlayers()[1].UserId
local bot = -1
local function rootOf(uid)
	for _, p in game:GetService("Players"):GetPlayers() do if p.UserId == uid then return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end end
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m.Name:find("TestBot") and m:FindFirstChild("HumanoidRootPart") then return m.HumanoidRootPart end
	end
end
for r = 1, 5 do
	local t0 = os.clock()
	while RS:GetAttribute("MatchPhase") ~= "Playing" and os.clock() - t0 < 25 do task.wait(0.2) end
	task.wait(0.5)
	local a, b = rootOf(me), rootOf(bot)
	if r == 1 then table.insert(log, "score before: A " .. tostring(hook:Invoke("info").scoreA) .. " B " .. tostring(hook:Invoke("info").scoreB)) end
	local doors = {}
	for _, d in CS:GetTagged("Warehouse2Door") do table.insert(doors, d.Name .. (d:GetAttribute("Open") and " OPEN" or " shut") .. (d.Shutter.CanCollide and "/solid" or "/NOT SOLID")) end
	table.insert(log, string.format("round %d: me %s bot %s map %s doors %s phase %s", r, a and plan(a.Position) or "?", b and plan(b.Position) or "?",
		tostring(RS:GetAttribute("ArenaMap")), table.concat(doors, ", "), tostring(RS:GetAttribute("MatchPhase"))))
	local ok, err = hook:Invoke("kill", bot, me)
	if not ok then table.insert(log, "  kill failed: " .. tostring(err)) end
	task.wait(1)
	local t1 = os.clock()
	while RS:GetAttribute("MatchPhase") == "Playing" and os.clock() - t1 < 10 do task.wait(0.2) end
	if RS:GetAttribute("MatchState") ~= "Live" then break end
end
task.wait(3)
local fin = hook:Invoke("info")
table.insert(log, "end " .. tostring(RS:GetAttribute("MatchState")) .. " " .. tostring(RS:GetAttribute("MatchPhase")) .. " score A " .. tostring(fin and fin.scoreA) .. " B " .. tostring(fin and fin.scoreB))
table.insert(log, "phases: " .. tostring(hook:Invoke("phases")):sub(-400))
return table.concat(log, "\n")
