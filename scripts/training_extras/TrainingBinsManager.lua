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

-- (2026-10-19, Edward: "the bins do not allow you to change your gadget or melee") Remote Events.Training.TrialItem(slot, itemId):
-- slot "Weapon" / "Melee" / "Gadget", itemId a LobbyConfig.Items key of that slot, owned or not. Checks: InTraining, 4/s (no bin
-- reach: the picker also opens on entering Training). Weapon = the trial above without the bin check. Melee / Gadget set the
-- KitMelee / KitGadget attributes for Training only (MeleeManager gives the tool, GadgetManager refills the charges on that change);
-- TrialMelee / TrialGadget name an unowned pick. Leaving Training puts all three back from the saved loadout
-- (PlayerStore.ApplyLoadoutAttributes), so a trial never reaches a duel, a match or saved data.
local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
local okLC, LobbyConfig = pcall(require, ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
local trials = {}       -- [Player] = { prev = Loadout before the first trial (or false), id = trial gun }
local kitTrials = {}    -- [Player] = { Melee = id?, Gadget = id? }: Training-only KitMelee / KitGadget picks
local lastCall = {}
local lastItemCall = {}
local KIT_ATTR = { Melee = "KitMelee", Gadget = "KitGadget" }
local pickWeapon   -- (below) swaps the gun in hand: a normal pick if owned, else a trial

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
	pickWeapon(player, id, TX.SwapBins.AllowUnowned)
end

local function endKitTrials(player, restore)
	local kt = kitTrials[player]
	if not kt then return end
	kitTrials[player] = nil
	player:SetAttribute("TrialMelee", nil)
	player:SetAttribute("TrialGadget", nil)
	if restore then
		local okPS, PlayerStore = pcall(require, ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerStore"))
		if okPS and PlayerStore and PlayerStore.ApplyLoadoutAttributes then PlayerStore.ApplyLoadoutAttributes(player) end
	end
end

local function onTrialItem(player, slot, id)
	if not (ok and TX.On("SwapBins") and okLC) then return end
	local now = os.clock()
	if lastItemCall[player] and now - lastItemCall[player] < 0.25 then return end
	lastItemCall[player] = now
	if player:GetAttribute("InTraining") ~= true then return end
	if type(slot) ~= "string" or type(id) ~= "string" then return end
	local item = LobbyConfig.Items[id]
	if not (item and item.Slot == slot) then return end
	if slot == "Weapon" then
		if table.find(WeaponConfig.Loadout, id) then pickWeapon(player, id, true) end
		return
	end
	local attr = KIT_ATTR[slot]
	if not attr then return end
	local kt = kitTrials[player] or {}
	kitTrials[player] = kt
	kt[slot] = id                                      -- set first: the KitMelee / KitGadget watcher sees the pick as expected
	player:SetAttribute("Trial" .. slot, (not owns(player, id)) and id or nil)
	if player:GetAttribute(attr) == id then
		-- same item again: no attribute change, so give / refill by hand
		local name = slot == "Melee" and "MeleeManager" or "GadgetManager"
		local mgr = shared.Get and shared.Get(name)
		if not mgr and script.Parent:FindFirstChild(name) then
			local okM, m = pcall(require, script.Parent[name]); mgr = okM and m or nil
		end
		if slot == "Melee" and mgr and mgr.GiveMelee then mgr.GiveMelee(player) end
		if slot == "Gadget" and mgr and mgr.Refill then mgr.Refill(player) end
	else
		player:SetAttribute(attr, id)
	end
end

pickWeapon = function(player, id, allowUnowned)
	local combat = shared.Get and shared.Get("CombatManager")
	if not (combat and combat.SetWeapon) then return end
	local mine = owns(player, id)
	if not mine and not allowUnowned then return end
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
			endKitTrials(player, true)                 -- and KitMelee / KitGadget back from the saved loadout
		end
	end)
	player:GetAttributeChangedSignal("Loadout"):Connect(function()
		local tr = trials[player]
		if tr and player:GetAttribute("Loadout") ~= tr.id then trials[player] = nil; player:SetAttribute("TrialWeapon", nil) end   -- Z picked an owned gun
	end)
	for slot, attr in KIT_ATTR do
		player:GetAttributeChangedSignal(attr):Connect(function()
			local kt = kitTrials[player]
			if kt and kt[slot] and player:GetAttribute(attr) ~= kt[slot] then   -- the real kit changed (Kit screen): no longer a trial
				kt[slot] = nil
				player:SetAttribute("Trial" .. slot, nil)
			end
		end)
	end
end

function manager.Start()
	if not (ok and TX.On("SwapBins")) then return end
	local ev = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training")
	local swap = ev:FindFirstChild("SwapWeapon")
	if not swap then swap = Instance.new("RemoteEvent"); swap.Name = "SwapWeapon"; swap.Parent = ev end
	swap.OnServerEvent:Connect(onSwap)
	local trial = ev:FindFirstChild("TrialItem")
	if not trial then trial = Instance.new("RemoteEvent"); trial.Name = "TrialItem"; trial.Parent = ev end
	trial.OnServerEvent:Connect(onTrialItem)
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerRemoving:Connect(function(p) trials[p] = nil; kitTrials[p] = nil; lastCall[p] = nil; lastItemCall[p] = nil end)
end

return manager
