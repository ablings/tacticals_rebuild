-- StarterPlayer/StarterPlayerScripts/Client/Controllers/ReloadVariantFX (ModuleScript) [RELOADVAR] (2026-10-30, systems session;
-- installed by fix/reload_variants.lua, source fix/reload_variants/ReloadVariantFX.lua)
-- The reload variants' gun-part markers (MagHide / MagShow, RoundHide / RoundShow, LoaderShow / LoaderHide): on every player's
-- body and every bot, each client hides / shows the named parts of the held gun locally (LocalTransparencyModifier; the track
-- replicates, so every client sees the same thing). Everything a track hid comes back when it stops.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RVC = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ReloadVariantConfig"))

local controller = {}
local hooked = {} -- [Animator] = true (strong; cleared on Destroying)
local hookedTracks = {} -- [AnimationTrack] = true: hooked once (strong; cleared with its animator)
local variantIds = nil -- [AnimationId] = true: the published variant clips (other bodies' tracks are matched by id)

local function isVariantName(n: string): boolean
	return n:find("Reload_", 1, true) ~= nil or n:find("ReloadShell_", 1, true) ~= nil or n:find("ReloadStart_", 1, true) ~= nil
end

local function ids()
	if variantIds then return variantIds end
	variantIds = {}
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	local src = repo and repo:FindFirstChild("AnimationSources")
	for _, s in (src and src:GetChildren() or {}) do
		local id = s:GetAttribute("PublishedId")
		if type(id) == "string" and id ~= "" and isVariantName(s.Name) then variantIds[id] = true end
	end
	return variantIds
end

local function partsOf(model: Model, names: { string }): { BasePart }
	local tool = model:FindFirstChildOfClass("Tool")
	local out = {}
	if not tool then return out end
	local want = {}
	for _, n in names do want[n] = true end
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and want[d.Name] then table.insert(out, d) end
	end
	return out
end

local function hookTrack(model: Model, track: AnimationTrack)
	if hookedTracks[track] then return end
	hookedTracks[track] = model
	local changed = {} -- parts this track touched
	for marker, rule in RVC.PartMarkers do
		local ok, sig = pcall(track.GetMarkerReachedSignal, track, marker)
		if ok and sig then
			sig:Connect(function(value)
				if RVC.Enabled == false then return end
				local names = (type(value) == "string" and value ~= "") and { value } or rule.default
				for _, p in partsOf(model, names) do
					p.LocalTransparencyModifier = rule.hide and 1 or 0
					changed[p] = true
				end
			end)
		end
	end
	track.Stopped:Connect(function()
		for p in changed do if p.Parent then p.LocalTransparencyModifier = 0 end end
		changed = {}
	end)
end

-- your own body: WeaponController hands over the variant track it plays (Studio plays unpublished sources by a temporary id)
function controller.Hook(model: Model, track: AnimationTrack)
	if model and track then hookTrack(model, track) end
end

local function hookModel(model: Model)
	local hum = model:WaitForChild("Humanoid", 10)
	local animator = hum and hum:WaitForChild("Animator", 10)
	if not animator or hooked[animator] then return end
	hooked[animator] = true
	animator.Destroying:Connect(function()
		hooked[animator] = nil
		for t, m in hookedTracks do if m == model then hookedTracks[t] = nil end end
	end)
	animator.AnimationPlayed:Connect(function(track)
		if ids()[track.Animation and track.Animation.AnimationId or ""] then hookTrack(model, track) end
	end)
end

function controller.Start()
	local function onPlayer(p: Player)
		if p.Character then task.spawn(hookModel, p.Character) end
		p.CharacterAdded:Connect(function(c) task.spawn(hookModel, c) end)
	end
	for _, p in Players:GetPlayers() do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	for _, m in CollectionService:GetTagged("Bot") do if m:IsA("Model") then task.spawn(hookModel, m) end end
	CollectionService:GetInstanceAddedSignal("Bot"):Connect(function(m) if m:IsA("Model") then task.spawn(hookModel, m) end end)
end

return controller
