-- Client/Controllers/SettingsEffectsController (ModuleScript, auto-loaded): the settings that change the world on
-- this client. SettingsConfig.Apply turns the saved profile into player attributes (Setting_<Name>); this follows them.
--   Optimized Lighting  - no global shadows, no lamp shadows, the bloom / depth of field / sun rays off
--   Optimized Textures  - surface images (SurfaceAppearance / Texture / Decal) hidden on the maps (not on players)
--   Fewer Lights        - [PERFSET] lamps more than LIGHT_FAR studs from the camera are off
--   Low Effects         - [PERFSET] read by ExplosionController (fewer sparks, no debris, no shadowed flash)
--   Hide Far Screens    - [PERFSET] in-world screens and signs stop drawing past SCREEN_FAR studs
--   SFX Volume          - FlashController routes every world sound through SoundService.World; it is nested under
--                         SoundService.Effects so the SFX slider (Effects.Volume) reaches them (volumes multiply)
--   Master / SFX Volume - SoundService.Effects volume from the Setting_ attributes. The lobby's SettingsConfig.Apply
--                         does the same; the match place only gets the attributes (its SettingsBridge is server-side)
-- Everything is restored when the setting goes back off. (UI session 2026-10-16)
-- [PERFSET] 2026-10-30 (systems session, after the lag test notes/lag_test_1030.md; Edward: "with the in game settings what can
-- we turn off to lower this"): the performance rows cover every map (they were lobby-only), lamp shadows go with Optimized
-- Lighting, a map that turns GlobalShadows / bloom back on at match start (MapInfo.Lighting) is overruled while the setting is on,
-- and three new rows. Never shows MORE than as built: smoke, steam and gameplay markers are untouched.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local SettingsEffects = {}
local player = Players.LocalPlayer

local LIGHT_FAR = 70    -- Fewer Lights: lamps further than this from the camera go off ...
local LIGHT_NEAR = 62   -- ... and come back on inside this (a gap, so a lamp at the edge doesn't flicker)
local SCREEN_FAR = 60   -- Hide Far Screens: MaxDistance for in-world SurfaceGuis / BillboardGuis
local POST_FX = { Lobby_Bloom = true, Lobby_DOF = true, Lobby_SunRays = true, Bloom = true, SunRays = true, DepthOfField = true }

local function setting(name) return player:GetAttribute("Setting_" .. name) end

-- a player's body (or anything inside it) is never touched: avatars keep their look, nameplates their reach
local function onCharacter(d: Instance): boolean
	local m = d:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return true end
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- Optimized Lighting ------------------------------------------------------------------------------------------
local lightingSaved -- { shadows = bool, fx = { [PostEffect] = enabled }, lamps = { [Light] = true } }
local function lampOff(d: Instance)
	if lightingSaved and d:IsA("Light") and d.Shadows and not lightingSaved.lamps[d] then
		lightingSaved.lamps[d] = true
		d.Shadows = false
	end
end
local function fxOff(fx: Instance)
	if lightingSaved and fx:IsA("PostEffect") and POST_FX[fx.Name] and lightingSaved.fx[fx] == nil then
		lightingSaved.fx[fx] = fx.Enabled
		fx.Enabled = false
	end
end
local function applyLighting()
	local on = setting("OptimizedLighting") == true
	if on and not lightingSaved then
		lightingSaved = { shadows = Lighting.GlobalShadows, fx = {}, lamps = {} }
		Lighting.GlobalShadows = false
		for _, fx in Lighting:GetChildren() do fxOff(fx) end
		for _, d in workspace:GetDescendants() do lampOff(d) end
	elseif not on and lightingSaved then
		local saved = lightingSaved
		lightingSaved = nil
		Lighting.GlobalShadows = saved.shadows
		for fx, was in saved.fx do if fx.Parent then fx.Enabled = was end end
		for lamp in saved.lamps do if lamp.Parent then lamp.Shadows = true end end
	end
end

-- Optimized Textures ------------------------------------------------------------------------------------------
local hidden -- [instance] = original Transparency (Texture / Decal) or original Parent (SurfaceAppearance)
local function hideOne(d: Instance)
	if not hidden or hidden[d] ~= nil then return end
	if d:IsA("Decal") then -- Texture is a Decal too
		if onCharacter(d) then return end
		hidden[d] = d.Transparency
		d.Transparency = 1
	elseif d:IsA("SurfaceAppearance") then
		if onCharacter(d) then return end
		hidden[d] = d.Parent
		task.defer(function() if hidden and hidden[d] then d.Parent = nil end end)
	end
end
local function applyTextures()
	local on = setting("OptimizedTextures") == true
	if on and not hidden then
		hidden = {}
		for _, d in workspace:GetDescendants() do hideOne(d) end
	elseif not on and hidden then
		local list = hidden
		hidden = nil
		for d, v in list do
			if d:IsA("SurfaceAppearance") then
				if typeof(v) == "Instance" and v.Parent then d.Parent = v end
			else
				d.Transparency = v
			end
		end
	end
end

-- Fewer Lights ------------------------------------------------------------------------------------------------
local lamps = {} -- [Light] = true: every map lamp seen (not on a body)
local dimmed = {} -- [Light] = true: switched off by this setting
local function lampPos(l: Light): Vector3?
	local p = l.Parent
	if p and p:IsA("Attachment") then return p.WorldPosition end
	if p and p:IsA("BasePart") then return p.Position end
	return nil
end
local function trackLamp(d: Instance)
	if d:IsA("Light") and not onCharacter(d) then lamps[d] = true end
end
local lastLights = 0
local function stepLights(force: boolean?)
	local now = os.clock()
	if not force and now - lastLights < 0.5 then return end
	lastLights = now
	local on = setting("FewerLights") == true
	local cam = workspace.CurrentCamera
	local at = cam and cam.CFrame.Position
	for l in lamps do
		if not l.Parent then lamps[l] = nil; dimmed[l] = nil; continue end
		local pos = on and at and lampPos(l)
		if pos and (pos - at).Magnitude > LIGHT_FAR then
			if l.Enabled and not dimmed[l] then dimmed[l] = true; l.Enabled = false end
		elseif dimmed[l] and (not on or not pos or (pos - at).Magnitude <= LIGHT_NEAR) then
			dimmed[l] = nil
			l.Enabled = true
		end
	end
end

-- Hide Far Screens ----------------------------------------------------------------------------------------------
local screens -- [gui] = original MaxDistance
local function screenOne(g: Instance)
	if not screens or screens[g] ~= nil then return end
	if not (g:IsA("SurfaceGui") or g:IsA("BillboardGui")) then return end
	if g:IsA("BillboardGui") and (onCharacter(g) or not g:IsDescendantOf(workspace)) then return end -- nameplates / markers
	local ok, d = pcall(function() return g.MaxDistance end)
	if not ok then return end
	screens[g] = d
	if d == 0 or d > SCREEN_FAR then g.MaxDistance = SCREEN_FAR end
end
local function applyScreens()
	local on = setting("HideFarScreens") == true
	if on and not screens then
		screens = {}
		for _, d in workspace:GetDescendants() do screenOne(d) end
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if pg then for _, d in pg:GetDescendants() do if d:IsA("SurfaceGui") then screenOne(d) end end end
	elseif not on and screens then
		local list = screens
		screens = nil
		for g, d in list do if g.Parent then pcall(function() g.MaxDistance = d end) end end
	end
end

-- SFX: nest the World group under Effects -----------------------------------------------------------------------
local function nestWorld()
	local world = SoundService:FindFirstChild("World")
	local effects = SoundService:FindFirstChild("Effects")
	if not effects then
		effects = Instance.new("SoundGroup")
		effects.Name = "Effects"
		effects.Parent = SoundService
	end
	if world and world:IsA("SoundGroup") and world.Parent ~= effects then world.Parent = effects end
end

-- Volume: per client, from the attributes ---------------------------------------------------------------------------
local function applyVolume()
	local master, sfx = setting("MasterVolume"), setting("SFXVolume")
	if type(master) ~= "number" and type(sfx) ~= "number" then return end
	local effects = SoundService:FindFirstChild("Effects")
	if effects and effects:IsA("SoundGroup") then effects.Volume = (sfx or 100) / 100 * (master or 50) / 100 end
end

function SettingsEffects.Start()
	player:GetAttributeChangedSignal("Setting_OptimizedLighting"):Connect(applyLighting)
	player:GetAttributeChangedSignal("Setting_OptimizedTextures"):Connect(applyTextures)
	player:GetAttributeChangedSignal("Setting_FewerLights"):Connect(function() stepLights(true) end)
	player:GetAttributeChangedSignal("Setting_HideFarScreens"):Connect(applyScreens)
	for _, d in workspace:GetDescendants() do trackLamp(d) end
	applyLighting()
	applyTextures()
	applyScreens()
	stepLights(true)
	-- anything that arrives later (a match map, the after-match lobby, streamed parts, an explosion's flash) follows the settings
	workspace.DescendantAdded:Connect(function(d)
		trackLamp(d)
		if lightingSaved then lampOff(d) end
		if hidden then hideOne(d) end
		if screens then screenOne(d) end
	end)
	-- a map's lighting (MapInfo.Lighting, applied by the server at match start) can turn shadows / bloom back on
	Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		if lightingSaved and Lighting.GlobalShadows then
			lightingSaved.shadows = true
			Lighting.GlobalShadows = false
		end
	end)
	Lighting.ChildAdded:Connect(function(c) if lightingSaved then task.defer(fxOff, c) end end)
	RunService.Heartbeat:Connect(function() stepLights(false) end)
	SoundService.ChildAdded:Connect(function(c) if c.Name == "World" then task.defer(nestWorld) end end)
	nestWorld()
	for _, name in { "MasterVolume", "SFXVolume" } do player:GetAttributeChangedSignal("Setting_" .. name):Connect(applyVolume) end
	applyVolume()
end

return SettingsEffects
