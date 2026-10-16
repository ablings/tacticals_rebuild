-- StarterPlayerScripts/ArenaLoader (LocalScript): lobby pad duels, client side (notes/lobby_duels_design.md section 3).
-- Loads the chosen map's Visual layer on THIS client only, while the player is in (or watching) a lobby match:
--   state = ReplicatedStorage.LobbyDuels[DuelMatch or DuelSpectate]; when it has ArenaMap + ArenaOrigin:
--   preload the meshes / SurfaceAppearances, clone ReplicatedStorage.DuelMaps.<map>.Visual to the slot origin
--   (named MapInfo.WorkspaceName), swap Lighting to the map's (local only), then MatchFlow:FireServer(id, "Loaded").
-- Unloads (destroy the clone, restore the lobby's Lighting) when the attribute clears or the state object goes away.
-- Fades: black on MatchFlow "Return" (the trip back to the pads) and a fade-in when the first round starts.
-- Nothing here names a map: everything comes from MapRegistry. Lobby players never get a clone, so they never draw an arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local MapRegistry = require(Shared:WaitForChild("MapRegistry"))

local loaded = nil -- { id, map, clone, saved }
local busy = false

-- // Fade ----------------------------------------------------------------------------------------------------------------
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "DuelFade"; fadeGui.IgnoreGuiInset = true; fadeGui.ResetOnSpawn = false; fadeGui.DisplayOrder = 40
local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1); black.BackgroundColor3 = Color3.new(0, 0, 0); black.BackgroundTransparency = 1; black.BorderSizePixel = 0
black.Parent = fadeGui
fadeGui.Parent = player:WaitForChild("PlayerGui")
local function fade(to: number, t: number)
	TweenService:Create(black, TweenInfo.new(t), { BackgroundTransparency = to }):Play()
end

-- // Lighting swap (local) ---------------------------------------------------------------------------------------------------
local function swapLighting(cfg: Instance?)
	if not cfg then return nil end
	local saved = { props = {}, moved = {}, disabled = {}, added = {} }
	for k, v in cfg:GetAttributes() do
		local ok, old = pcall(function() return (Lighting :: any)[k] end)
		if ok then saved.props[k] = old; pcall(function() (Lighting :: any)[k] = v end) end
	end
	-- the lobby's effects step aside: Atmosphere / Sky can't be disabled, so they move out (local only) and come back
	local hasAtmo = cfg:FindFirstChildOfClass("Atmosphere") ~= nil
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") and hasAtmo then
			table.insert(saved.moved, c); c.Parent = script
		elseif c:IsA("PostEffect") and c.Enabled then
			table.insert(saved.disabled, c); c.Enabled = false
		end
	end
	for _, c in cfg:GetChildren() do
		local cl = c:Clone(); cl.Parent = Lighting
		table.insert(saved.added, cl)
	end
	return saved
end
local function restoreLighting(saved)
	if not saved then return end
	for _, c in saved.added do c:Destroy() end
	for k, v in saved.props do pcall(function() (Lighting :: any)[k] = v end) end
	for _, c in saved.moved do c.Parent = Lighting end
	for _, c in saved.disabled do if c.Parent then c.Enabled = true end end
end

-- // Load / unload ----------------------------------------------------------------------------------------------------------
local function matchId(): string?
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	return id and tostring(id) or nil
end
local function stateOf(id: string?)
	local f = ReplicatedStorage:FindFirstChild("LobbyDuels")
	return id and f and f:FindFirstChild(id) or nil
end

local function unload()
	if not loaded then return end
	if loaded.clone then loaded.clone:Destroy() end
	restoreLighting(loaded.saved)
	loaded = nil
end

local function load(id: string, state: Instance)
	local mapId, origin = state:GetAttribute("ArenaMap"), state:GetAttribute("ArenaOrigin")
	local info = MapRegistry.Get(mapId)
	if not info or typeof(origin) ~= "Vector3" then return end
	local template = info.Folder:FindFirstChild("Visual")
	if not template then warn("[ArenaLoader] no Visual layer for " .. tostring(mapId)); return end
	busy = true
	-- preload behind the loadout screen (capped, so a slow asset can't hold the match)
	local assets = {}
	for _, d in template:GetDescendants() do
		if d:IsA("MeshPart") or d:IsA("SurfaceAppearance") then table.insert(assets, d) end
	end
	local done = false
	task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, assets); done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do task.wait(0.1) end
	if matchId() ~= id or not state.Parent then busy = false; return end
	local clone = template:Clone()
	clone.Name = info.WorkspaceName or info.Id
	clone:PivotTo(CFrame.new(origin))
	clone:SetAttribute("DuelArena", id)
	clone.Parent = workspace
	loaded = { id = id, map = mapId, clone = clone, saved = swapLighting(info.Folder:FindFirstChild("Lighting")) }
	busy = false
	local flow = ReplicatedStorage:FindFirstChild("MatchFlow")
	if flow then flow:FireServer(id, "Loaded") end
	print(`[ArenaLoader] {mapId} loaded for {id} ({#clone:GetDescendants()} instances, preload {string.format("%.1f", os.clock() - t0)} s)`)
end

local lastPhase
local function tick()
	local id = matchId()
	local state = stateOf(id)
	if loaded and (loaded.id ~= id or not state or state:GetAttribute("ArenaMap") ~= loaded.map) then unload() end
	if not loaded and not busy and state and state:GetAttribute("ArenaMap") and state:GetAttribute("ArenaOrigin") then
		task.spawn(load, id, state)
	end
	-- fade in from black when the match first goes to its rounds
	local phase = state and state:GetAttribute("MatchPhase")
	if phase == "Playing" and lastPhase ~= "Playing" then
		black.BackgroundTransparency = 0; fade(1, 0.8)
	end
	if not id and black.BackgroundTransparency < 1 then fade(1, 0.6) end
	lastPhase = phase
end

task.spawn(function()
	local flow = ReplicatedStorage:WaitForChild("MatchFlow", 60)
	if flow then
		flow.OnClientEvent:Connect(function(_, kind)
			if kind == "Return" then fade(0, 0.5) end
		end)
	end
end)
while true do
	pcall(tick)
	task.wait(0.2)
end
