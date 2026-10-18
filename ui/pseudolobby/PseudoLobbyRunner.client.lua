-- StarterPlayerScripts/PseudoLobbyRunner (LocalScript, match places only): runs the hub's lobby look scripts (screens,
-- tickers, labels, heli rotor, room FX, billboards, lobby screens / features FX) while the after-match lobby map is out.
-- The server moves ServerStorage.PseudoLobby.LobbyMap into Workspace on PostMatch and back on Rematch, so every show is
-- a fresh copy of the map on this client: the scripts are cloned from ReplicatedStorage.PseudoLobbyClient on each show
-- and destroyed on hide (that disconnects everything they hooked), and the world GUIs they left behind go with them.
-- (2026-10-18, UI session. Contract with the lead session: ReplicatedStorage attribute PseudoLobbyMap = true while shown.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("PseudoLobbyClient")
local running = {}
local gen = 0

local function stop()
	gen += 1
	for _, s in running do s:Destroy() end
	table.clear(running)
	-- surface / billboard GUIs those scripts parented to PlayerGui, now pointing at the map copy that just went away
	local pg = player:FindFirstChild("PlayerGui")
	for _, g in pg and pg:GetChildren() or {} do
		if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then
			local a = g.Adornee
			if a == nil or not a:IsDescendantOf(workspace) then g:Destroy() end
		end
	end
end

local function start()
	stop()
	local my = gen
	local map = workspace:WaitForChild("LobbyMap", 30)
	if not map or my ~= gen or ReplicatedStorage:GetAttribute("PseudoLobbyMap") ~= true then return end
	local ps = player:WaitForChild("PlayerScripts")
	for _, t in templates:GetChildren() do
		if t:IsA("LocalScript") then
			local c = t:Clone()
			c.Parent = ps
			table.insert(running, c)
		end
	end
end

local shown = false
local function update()
	local now = ReplicatedStorage:GetAttribute("PseudoLobbyMap") == true
	if now == shown then return end
	shown = now
	if now then task.spawn(start) else stop() end
end
ReplicatedStorage:GetAttributeChangedSignal("PseudoLobbyMap"):Connect(update)
update()
