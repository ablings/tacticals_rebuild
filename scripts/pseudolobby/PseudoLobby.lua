-- ServerScriptService.Shared.PseudoLobby (ModuleScript, match places) [PSEUDOLOBBY] 2026-10-18, Edward (via the UI session):
-- "the after-match lobby": RIVALS keeps everyone on the match server after the results, standing in a copy of the lobby with
-- the duel pads barricaded, so Rematch can start on the same server. Phase 2 of the post-match flow (fix/postmatch_install.lua).
--
-- The map: ServerStorage.PseudoLobby.LobbyMap is a copy of the hub's Workspace.LobbyMap (tools/pseudolobby_build.py map),
--   moved OFFSET studs away so it never overlaps the match map (Warehouse sits inside the hub's footprint), Training stripped,
--   the QueuePad / ExfilBarrier / DuelArena tags removed, each duel pad and the Exfil hatch barricaded ("AVAILABLE IN THE HUB").
--   ServerStorage.PseudoLobby.Lighting holds the hub's Lighting children; its attributes hold the hub's Lighting properties.
-- Show(): the map goes into Workspace (named LobbyMap) and STAYS there for the rest of the server (UI session: moving it back
--   would hand clients fresh instances on the next Show and the hub's client scripts keep references to the old ones; it is
--   OFFSET away from the arena, barricaded, and combat is off there). The lighting swaps to the hub's, anyone with InPseudoLobby
--   who respawns or falls off is put back at LobbySpawn. Hide() swaps the lighting back and stops the respawn / fall catch.
-- Contract with the UI: ReplicatedStorage.PseudoLobbyMap = false from server start on a match place (set when this module is
--   first required, and saved false in the place), true once the map is in Workspace (then stays true). Whether the lobby is
--   OPEN is the player attribute InPseudoLobby, never the map.
-- RoundManager [PSEUDOLOBBY]: postMatch() calls Show() and spawns at SpawnCFrame(i); Hide() when the phase ends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local PseudoLobby = {}
local LIGHT_PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude", "ExposureCompensation",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ColorShift_Top", "ColorShift_Bottom", "FogColor", "FogEnd", "FogStart",
	"GlobalShadows", "ShadowSoftness" }

local shown = false
if ReplicatedStorage:GetAttribute("PseudoLobbyMap") == nil and not workspace:FindFirstChild("LobbyMap") then
	ReplicatedStorage:SetAttribute("PseudoLobbyMap", false)
end
local matchLight = nil -- { props = {}, folder = Folder } while shown
local conns = {}

local function store() return ServerStorage:FindFirstChild("PseudoLobby") end
local function map()
	if ReplicatedStorage:GetAttribute("PseudoLobbyMap") == true then return workspace:FindFirstChild("LobbyMap") end
	local s = store()
	return s and s:FindFirstChild("LobbyMap")
end

function PseudoLobby.Available(): boolean
	return map() ~= nil
end

function PseudoLobby.IsShown(): boolean
	return shown
end

-- spawn i of n: a ring around LobbySpawn, everyone facing the same way as the spawn pad
function PseudoLobby.SpawnCFrame(i: number?): CFrame?
	local m = map()
	local sp = m and m:FindFirstChild("LobbySpawn")
	if not (sp and sp:IsA("BasePart")) then return nil end
	i = i or 1
	local ang = (i - 1) * 2.399 -- golden angle: no two players on the same spot
	local r = i == 1 and 0 or 3 + (i % 3)
	local offset = Vector3.new(math.cos(ang) * r, sp.Size.Y / 2 + 3, math.sin(ang) * r)
	return CFrame.new(sp.Position + offset) * (sp.CFrame - sp.CFrame.Position)
end

local function swapLighting(toLobby: boolean)
	local s = store()
	local saved = s and s:FindFirstChild("Lighting")
	if not saved then return end
	if toLobby then
		matchLight = { props = {}, folder = Instance.new("Folder") }
		matchLight.folder.Name = "_MatchLighting"
		for _, k in LIGHT_PROPS do
			local ok, v = pcall(function() return Lighting[k] end)
			if ok then matchLight.props[k] = v end
			local lv = saved:GetAttribute(k)
			if lv ~= nil then pcall(function() Lighting[k] = lv end) end
		end
		for _, c in Lighting:GetChildren() do
			if c:IsA("PostEffect") or c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("Clouds") then c.Parent = matchLight.folder end
		end
		matchLight.folder.Parent = s
		for _, c in saved:GetChildren() do c.Parent = Lighting end
	elseif matchLight then
		for _, c in Lighting:GetChildren() do
			if c:IsA("PostEffect") or c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("Clouds") then c.Parent = saved end
		end
		for k, v in matchLight.props do pcall(function() Lighting[k] = v end) end
		for _, c in matchLight.folder:GetChildren() do c.Parent = Lighting end
		matchLight.folder:Destroy()
		matchLight = nil
	end
end

-- no kit in the lobby (UI session: the hotbar keys still equipped): CombatManager / MeleeManager hand the gun and melee out on
-- every CharacterAdded, so tools are taken away while InPseudoLobby; the next match's spawn hands them out again
local function strip(player: Player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		for _, t in (container and container:GetChildren() or {}) do
			if t:IsA("Tool") then t:Destroy() end
		end
	end
end

local function home(player: Player)
	if not (shown and player:GetAttribute("InPseudoLobby")) then return end
	local character = player.Character
	local cf = PseudoLobby.SpawnCFrame(math.random(1, 8))
	if character and cf then character:PivotTo(cf) end
end

local function hookPlayer(player: Player)
	table.insert(conns, player.CharacterAdded:Connect(function(character)
		-- a reset / death in the pseudo lobby: RoundManager respawns at the match spawn; bring them back here
		task.defer(function()
			if character.Parent then home(player) end
		end)
		task.delay(1, function() if shown and player:GetAttribute("InPseudoLobby") then strip(player) end end)
	end))
end

function PseudoLobby.Show(): boolean
	if shown then return true end
	local m = map()
	if not m then return false end
	shown = true
	if m.Parent ~= workspace then m.Parent = workspace end -- first time only: then it stays
	swapLighting(true)
	ReplicatedStorage:SetAttribute("PseudoLobbyMap", true)
	-- the match's test bots don't come along (RoundManager makes new ones for a rematch)
	for _, b in game:GetService("CollectionService"):GetTagged("Bot") do
		if b:IsDescendantOf(workspace) then b:Destroy() end
	end
	for _, p in Players:GetPlayers() do hookPlayer(p) end
	table.insert(conns, Players.PlayerAdded:Connect(hookPlayer))
	-- fall catch (the hub's LobbyFallCatch is not on the match server): well below the spawn = back on the spawn
	task.spawn(function()
		local sp = m:FindFirstChild("LobbySpawn")
		local floor = sp and sp.Position.Y - 120 or -400
		while shown do
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if p:GetAttribute("InPseudoLobby") then
					if root and root.Position.Y < floor then home(p) end
					strip(p)
				end
			end
			task.wait(0.5)
		end
	end)
	return true
end

function PseudoLobby.Hide()
	if not shown then return end
	shown = false
	for _, c in conns do c:Disconnect() end
	conns = {}
	-- the map stays in Workspace (see the header); only the lighting goes back to the match's
	swapLighting(false)
end

return PseudoLobby
