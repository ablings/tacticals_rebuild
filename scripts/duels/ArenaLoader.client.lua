-- StarterPlayerScripts/ArenaLoader (LocalScript): lobby pad duels, client side (notes/lobby_duels_design.md section 3).
-- Loads the chosen map's Visual layer on THIS client only, while the player is in (or watching) a lobby match:
--   state = ReplicatedStorage.LobbyDuels[DuelMatch or DuelSpectate]; when it has ArenaMap + ArenaOrigin:
--   preload the meshes / SurfaceAppearances, clone ReplicatedStorage.DuelMaps.<map>.Visual to the slot origin
--   (named MapInfo.WorkspaceName), swap Lighting to the map's (local only), then MatchFlow:FireServer(id, "Loaded").
-- Unloads (destroy the clone, restore the lobby's Lighting) when the attribute clears or the state object goes away.
-- Fades: black on MatchFlow "Return" (the trip back to the pads) and a fade-in when the first round starts.
-- Nothing here names a map: everything comes from MapRegistry. Lobby players never get a clone, so they never draw an arena.
-- Phase 2: the arena's moving / reacting pieces follow the server state on the Solid layer (ArenaShootables):
--   doors (DoorOpen / DoorMoving / DoorAt: the Visual shutter tweens like the server's, the Led turns amber / green / red),
--   fire barrels (Exploded hides the Visual barrel; FireAt / FireRadius / FireUntil draw the burning ground here),
--   steam valves (SteamUntil: the jet + hiss play on the Visual valve). All local: only this match's clients see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ROLL_TIME = 1.6 -- = ArenaShootables.ROLL_TIME (server shutter tween)
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local HISS = "rbxassetid://4772620521"

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

-- // Dynamic pieces: follow the Solid layer's state attributes -------------------------------------------------------------------
local function seq(...)
	local pts = {}
	for _, p in { ... } do table.insert(pts, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(pts)
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

local function bindDoor(solidModel: Model, visModel: Model, conns)
	local shutter = visModel:FindFirstChild("Shutter")
	if not (shutter and shutter:IsA("BasePart")) then return end
	local closed = shutter.CFrame
	local led = visModel:FindFirstChild("Led")
	local tween
	local function apply()
		local open = solidModel:GetAttribute("DoorOpen") == true
		local moving = solidModel:GetAttribute("DoorMoving") == true
		local h = solidModel:GetAttribute("DoorHeight") or 10
		local goal = open and closed + Vector3.new(0, h, 0) or closed
		if tween then tween:Cancel(); tween = nil end
		local left = ROLL_TIME - (workspace:GetServerTimeNow() - (solidModel:GetAttribute("DoorAt") or 0))
		if moving and left > 0.03 then
			tween = TweenService:Create(shutter, TweenInfo.new(left, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal })
			tween:Play()
		else
			shutter.CFrame = goal
		end
		if led and led:IsA("BasePart") then
			led.Color = moving and Color3.fromRGB(255, 170, 30) or open and Color3.fromRGB(60, 230, 90) or Color3.fromRGB(255, 60, 40)
			led.Material = Enum.Material.Neon
		end
	end
	for _, a in { "DoorOpen", "DoorMoving", "DoorAt" } do table.insert(conns, solidModel:GetAttributeChangedSignal(a):Connect(apply)) end
	apply()
end

local function firePatch(at: Vector3, r: number): Part
	-- burning ground (the match place's ShootableManager.spawnFire, drawn locally)
	local fire = Instance.new("Part")
	fire.Name = "FirePatch"; fire.Anchored = true; fire.CanCollide = false; fire.CanQuery = false; fire.CanTouch = false
	fire.Transparency = 1; fire.Size = Vector3.new(r * 2, 0.2, r * 2); fire.Position = at - Vector3.new(0, 1.3, 0)
	for i = 1, 11 do
		local ang = (i / 11) * math.pi * 2 + math.random() * 0.5
		local dist = i == 1 and 0 or r * (0.25 + math.random() * 0.65)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(ang) * dist, 0.15, math.sin(ang) * dist)
		a.Parent = fire
		local sz = 2.4 + math.random() * 1.6
		emitter(a, { Texture = FIRE_TEX, LightEmission = 1, LightInfluence = 0, Rate = 22,
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 140, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)) }),
			Size = seq({ 0, sz * 0.6 }, { 0.4, sz }, { 1, sz * 0.2 }), Transparency = seq({ 0, 0.25 }, { 0.7, 0.45 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, 7, 0), RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top })
	end
	emitter(fire, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(35, 32, 30)), Size = seq({ 0, 2 }, { 1, 9 }),
		Transparency = seq({ 0, 0.55 }, { 1, 1 }), Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(3, 6),
		Acceleration = Vector3.new(0.4, 2, 0), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Rate = 7, LightInfluence = 1 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 45); light.Brightness = 4; light.Range = r * 3; light.Shadows = false
	light.Parent = fire
	local roar = Instance.new("Sound")
	roar.SoundId = HISS; roar.PlaybackSpeed = 0.38; roar.Volume = 0.8; roar.Looped = true
	roar.RollOffMinDistance = 8; roar.RollOffMaxDistance = 140; roar.Parent = fire
	roar.TimePosition = 0.08
	roar:Play()
	return fire
end

local function bindBarrel(solidModel: Model, visModel: Model, conns)
	local saved = {}
	for _, p in visModel:GetDescendants() do if p:IsA("BasePart") then saved[p] = p.Transparency end end
	local fire
	local function apply()
		local gone = solidModel:GetAttribute("Exploded") == true
		for p, t in saved do p.Transparency = gone and 1 or t end
		for _, g in visModel:GetDescendants() do if g:IsA("SurfaceGui") then g.Enabled = not gone end end
		local untilT = solidModel:GetAttribute("FireUntil")
		local at = solidModel:GetAttribute("FireAt")
		local left = untilT and (untilT - workspace:GetServerTimeNow()) or 0
		if fire and (left <= 0 or not gone) then
			for _, e in fire:GetDescendants() do if e:IsA("ParticleEmitter") then e.Rate = 0 end end
			local snd = fire:FindFirstChildOfClass("Sound")
			if snd then TweenService:Create(snd, TweenInfo.new(1.2), { Volume = 0 }):Play() end
			Debris:AddItem(fire, 2)
			fire = nil
		end
		if not fire and gone and left > 0 and typeof(at) == "Vector3" then
			fire = firePatch(at, solidModel:GetAttribute("FireRadius") or 6)
			fire.Parent = visModel
			local mine = fire
			task.delay(left, function() if fire == mine then apply() end end)
		end
	end
	for _, a in { "Exploded", "FireUntil" } do table.insert(conns, solidModel:GetAttributeChangedSignal(a):Connect(apply)) end
	apply()
end

local function bindValve(solidModel: Model, visModel: Model, conns)
	local body = visModel:FindFirstChild("ValveBody")
	local wheel = visModel:FindFirstChild("Wheel")
	if not (body and body:IsA("BasePart")) then return end
	local out = wheel and (wheel.Position - body.Position) * Vector3.new(1, 0, 1) or Vector3.new(1, 0, 0)
	out = out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)
	local att = Instance.new("Attachment")
	att.Name = "SteamJet"
	att.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)
	att.Parent = body
	local jet = emitter(att, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(240, 242, 245)), LightInfluence = 1,
		Size = seq({ 0, 0.35 }, { 0.5, 1.6 }, { 1, 2.6 }), Transparency = seq({ 0, 0.25 }, { 0.6, 0.6 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(22, 30), Drag = 3, SpreadAngle = Vector2.new(6, 6),
		EmissionDirection = Enum.NormalId.Front, Rate = 110, RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360), Enabled = false })
	local wisp = emitter(att, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(225, 228, 232)), LightInfluence = 1,
		Size = seq({ 0, 0.5 }, { 1, 2 }), Transparency = seq({ 0, 0.6 }, { 1, 1 }), Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 3, 0),
		EmissionDirection = Enum.NormalId.Front, Rate = 18, Enabled = false })
	local hiss = Instance.new("Sound")
	hiss.SoundId = HISS; hiss.PlaybackSpeed = 1.35; hiss.Looped = true; hiss.Volume = 0.9
	hiss.RollOffMinDistance = 10; hiss.RollOffMaxDistance = 160; hiss.Parent = att
	local token
	local function apply()
		local untilT = solidModel:GetAttribute("SteamUntil")
		local left = untilT and (untilT - workspace:GetServerTimeNow()) or 0
		local on = left > 0
		jet.Enabled, wisp.Enabled = on, on
		if on and not hiss.IsPlaying then hiss.TimePosition = 0.08; hiss:Play() elseif not on then hiss:Stop() end
		local t = {}
		token = t
		if on then task.delay(left, function() if token == t then apply() end end) end
	end
	table.insert(conns, solidModel:GetAttributeChangedSignal("SteamUntil"):Connect(apply))
	apply()
end

-- the server's Solid layer of this match (Workspace.DuelArenas.<id>.<WorkspaceName>); doors / barrels / valves follow it
local function bindDynamic(id: string, info, clone: Model)
	local conns = {}
	task.spawn(function()
		local arenas = workspace:WaitForChild("DuelArenas", 10)
		local folder = arenas and arenas:WaitForChild(id, 10)
		local solid = folder and folder:WaitForChild(info.WorkspaceName or info.Id, 10)
		if not solid or not loaded or loaded.clone ~= clone then return end
		local n = 0
		for _, f in { "Interactive", "Shootables" } do
			local sf, vf = solid:FindFirstChild(f), clone:FindFirstChild(f)
			for _, sm in (sf and vf and sf:GetChildren() or {}) do
				local vm = vf:FindFirstChild(sm.Name)
				if vm then
					local kind = sm:GetAttribute("Shootable")
					if sm:FindFirstChild("Shutter") then bindDoor(sm, vm, conns); n += 1
					elseif kind == "FireBarrel" then bindBarrel(sm, vm, conns); n += 1
					elseif kind == "SteamValve" then bindValve(sm, vm, conns); n += 1 end
				end
			end
		end
		clone:SetAttribute("DynamicBound", n)
		print(`[ArenaLoader] {id}: {n} dynamic pieces follow the server`)
	end)
	return conns
end

local function unload()
	if not loaded then return end
	for _, c in loaded.conns or {} do c:Disconnect() end
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
	loaded.conns = bindDynamic(id, info, clone)
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
