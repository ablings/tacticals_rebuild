-- StarterPlayer.StarterPlayerScripts.RunInClient (2026-10-17, Edward: "a cutscene ... before the countdown where the players
-- run to each side of each pillar"). The client half of MatchCore.runIn: the client owns its character's physics, so the
-- run happens here. MatchCore sets player attributes RunInRoute (JSON list of {x,y,z} waypoints, pathfound round the
-- pillar), RunInSpeed, then bumps RunInGo; we run the route with player controls off, and the server snaps us onto the
-- spawn at the end (it clears RunInRoute). Works for lobby pad duels and the match places alike.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function controls()
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	return ok and pm and pm:GetControls() or nil
end

local runToken = 0
local function run()
	runToken += 1
	local my = runToken
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local okJ, pts = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("RunInRoute") or "[]")
	if not (hum and okJ and type(pts) == "table" and #pts > 0) then return end
	local ctl = controls()
	if ctl then ctl:Disable() end
	local oldSpeed = hum.WalkSpeed
	hum.WalkSpeed = tonumber(player:GetAttribute("RunInSpeed")) or 20
	for _, p in pts do
		if my ~= runToken or not hum.Parent or hum.Health <= 0 or player:GetAttribute("RunInRoute") == nil then break end
		if p[4] == 1 then hum.Jump = true end
		local target = Vector3.new(p[1], p[2], p[3])
		local reached = false
		local conn = hum.MoveToFinished:Once(function() reached = true end)
		hum:MoveTo(target)
		local t0 = os.clock()
		while not reached and os.clock() - t0 < 1.2 and player:GetAttribute("RunInRoute") ~= nil do task.wait() end
		conn:Disconnect()
	end
	-- hold still until the server snaps us home (it clears RunInRoute), then hand control back
	local t1 = os.clock()
	while my == runToken and player:GetAttribute("RunInRoute") ~= nil and os.clock() - t1 < 4 do task.wait(0.05) end
	if hum.Parent then hum.WalkSpeed = oldSpeed end
	if my == runToken and ctl then ctl:Enable() end
end

player:GetAttributeChangedSignal("RunInGo"):Connect(function() task.spawn(run) end)
