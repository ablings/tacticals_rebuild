-- Client/Controllers/SettingsEffectsController (ModuleScript, auto-loaded): the settings that change the world on
-- this client. SettingsConfig.Apply turns the saved profile into player attributes (Setting_<Name>); this follows them.
--   Optimized Lighting  - no global shadows, the lobby bloom / depth of field off
--   Optimized Textures  - surface images (SurfaceAppearance / Texture / Decal) under the lobby map hidden
--   SFX Volume          - FlashController routes every world sound through SoundService.World; it is nested under
--                         SoundService.Effects so the SFX slider (Effects.Volume) reaches them (volumes multiply)
--   Master / SFX Volume - SoundService.Effects volume from the Setting_ attributes. The lobby's SettingsConfig.Apply
--                         does the same; the match place only gets the attributes (its SettingsBridge is server-side)
-- Everything is restored when the setting goes back off. (UI session 2026-10-16)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local SettingsEffects = {}
local player = Players.LocalPlayer

local function setting(name) return player:GetAttribute("Setting_" .. name) end

-- Optimized Lighting ------------------------------------------------------------------------------------------
local lightingSaved
local function applyLighting()
	local on = setting("OptimizedLighting") == true
	if on and not lightingSaved then
		lightingSaved = { shadows = Lighting.GlobalShadows, fx = {} }
		Lighting.GlobalShadows = false
		for _, name in { "Lobby_Bloom", "Lobby_DOF", "Lobby_SunRays" } do
			local fx = Lighting:FindFirstChild(name)
			if fx and fx:IsA("PostEffect") then lightingSaved.fx[fx] = fx.Enabled; fx.Enabled = false end
		end
	elseif not on and lightingSaved then
		Lighting.GlobalShadows = lightingSaved.shadows
		for fx, was in lightingSaved.fx do if fx.Parent then fx.Enabled = was end end
		lightingSaved = nil
	end
end

-- Optimized Textures ------------------------------------------------------------------------------------------
local hiddenMap -- the LobbyMap those belong to
local hidden -- [instance] = original Transparency (Texture / Decal) or original Parent (SurfaceAppearance)
local function applyTextures()
	local on = setting("OptimizedTextures") == true
	local map = workspace:FindFirstChild("LobbyMap")
	-- the after-match lobby brings a fresh copy of the map each time: what was hidden belonged to the last one
	if hidden and hiddenMap ~= map then hidden = nil end
	if on and not hidden and map then
		hidden, hiddenMap = {}, map
		for _, d in map:GetDescendants() do
			if d:IsA("Decal") then -- Texture is a Decal too
				hidden[d] = d.Transparency
				d.Transparency = 1
			elseif d:IsA("SurfaceAppearance") then
				hidden[d] = d.Parent
				d.Parent = nil
			end
		end
		-- [STREAM] decals / surface appearances streamed in later are hidden too while the setting is on
		map.DescendantAdded:Connect(function(d)
			if not hidden or hiddenMap ~= map or hidden[d] ~= nil then return end
			if d:IsA("Decal") then hidden[d] = d.Transparency d.Transparency = 1
			elseif d:IsA("SurfaceAppearance") then hidden[d] = d.Parent task.defer(function() if hidden and hidden[d] then d.Parent = nil end end) end
		end)
	elseif not on and hidden then
		for d, v in hidden do
			if d:IsA("SurfaceAppearance") then
				if v and v.Parent then d.Parent = v end
			else
				d.Transparency = v
			end
		end
		hidden = nil
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
	for _, name in { "OptimizedLighting", "OptimizedTextures" } do
		player:GetAttributeChangedSignal("Setting_" .. name):Connect(function()
			applyLighting()
			applyTextures()
		end)
	end
	applyLighting()
	applyTextures()
	-- the match places move a LobbyMap in after a match (pseudo lobby): apply Optimized Textures to it when it arrives
	workspace.ChildAdded:Connect(function(c) if c.Name == "LobbyMap" then task.defer(applyTextures) end end)
	SoundService.ChildAdded:Connect(function(c) if c.Name == "World" then task.defer(nestWorld) end end)
	nestWorld()
	for _, name in { "MasterVolume", "SFXVolume" } do player:GetAttributeChangedSignal("Setting_" .. name):Connect(applyVolume) end
	applyVolume()
end

return SettingsEffects
