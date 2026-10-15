-- Managers/TrainingBinsManager (server, lobby place): weapon-swap bins in Training (notes/training_extras_done.md).
-- Remote Events.Training.SwapWeapon(weaponId) (created here). Checks: InTraining, 4/s, standing within Reach of a bin in
-- LobbyMap.Training.Extras.SwapBins, id in WeaponConfig.Loadout. Then CombatManager.SetWeapon (swaps the gun in hand).
-- Owned gun: a normal pick (same as Z: session attribute Loadout). Gun you don't own (AllowUnowned): a TRIAL. The player
-- attribute TrialWeapon is set; the trial ends when the player leaves Training (Loadout goes back to what it was) or picks
-- another bin. NOTHING here writes saved data: no PlayerStore.Set/Grant, no Owned, no saved Loadout (PlayerStore is only read).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local WeaponConfig = require(ReplicatedStorage.Modules.Shared.Config.WeaponConfig)
local manager = {}

local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
local trials = {}       -- [Player] = { prev = Loadout before the first trial (or false), id = trial gun }
local lastCall = {}

local function owns(player, id)
	local okPS, PlayerStore = pcall(require, ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerStore"))
	if not (okPS and PlayerStore and PlayerStore.Owns) then return false end
	return PlayerStore.Owns(player, id) == true
end
local function ownedList(player)
	local list = {}
	for _, id in WeaponConfig.Loadout do if owns(player, id) then table.insert(list, id) end end
	return table.concat(list, ",")
end
local function nearBin(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("LobbyMap")
	local f = map and map:FindFirstChild("Training") and map.Training:FindFirstChild("Extras") and map.Training.Extras:FindFirstChild("SwapBins")
	if not (root and f) then return false end
	for _, m in f:GetChildren() do
		local pivot = m:IsA("Model") and m:GetPivot()
		if pivot and (pivot.Position - root.Position).Magnitude <= TX.SwapBins.Reach then return true end
	end
	return false
end
local function endTrial(player, restore)
	local tr = trials[player]
	if not tr then return end
	trials[player] = nil
	player:SetAttribute("TrialWeapon", nil)
	if restore then player:SetAttribute("Loadout", tr.prev or nil) end
end

local function onSwap(player, id)
	if not (ok and TX.On("SwapBins")) then return end
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.25 then return end
	lastCall[player] = now
	if player:GetAttribute("InTraining") ~= true then return end
	if type(id) ~= "string" or not table.find(WeaponConfig.Loadout, id) then return end
	if not nearBin(player) then return end
	local combat = shared.Get and shared.Get("CombatManager")
	if not (combat and combat.SetWeapon) then return end
	local mine = owns(player, id)
	if not mine and not TX.SwapBins.AllowUnowned then return end
	local prev = trials[player] and trials[player].prev or (player:GetAttribute("Loadout") or false)
	if mine then
		endTrial(player, false)                       -- picking another bin ends a trial; an owned pick is a normal pick
		combat.SetWeapon(player, id, true)
	else
		trials[player] = { prev = prev, id = id }    -- set first: the Loadout watcher below sees the trial gun as expected
		player:SetAttribute("TrialWeapon", id)
		combat.SetWeapon(player, id, true)
	end
end

local function watch(player)
	player:SetAttribute("TX_OwnedGuns", nil)
	player:GetAttributeChangedSignal("InTraining"):Connect(function()
		if player:GetAttribute("InTraining") == true then
			player:SetAttribute("TX_OwnedGuns", ownedList(player))   -- the picker marks the others as TRIAL (display only)
		else
			endTrial(player, true)                     -- left Training: the trial gun is gone, Loadout back as it was
		end
	end)
	player:GetAttributeChangedSignal("Loadout"):Connect(function()
		local tr = trials[player]
		if tr and player:GetAttribute("Loadout") ~= tr.id then trials[player] = nil; player:SetAttribute("TrialWeapon", nil) end   -- Z picked an owned gun
	end)
end

function manager.Start()
	if not (ok and TX.On("SwapBins")) then return end
	local ev = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training")
	local swap = ev:FindFirstChild("SwapWeapon")
	if not swap then swap = Instance.new("RemoteEvent"); swap.Name = "SwapWeapon"; swap.Parent = ev end
	swap.OnServerEvent:Connect(onSwap)
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerRemoving:Connect(function(p) trials[p] = nil; lastCall[p] = nil end)
end

return manager
