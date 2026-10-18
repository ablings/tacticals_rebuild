-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- ServerScriptService/Data/PlayerStore (ModuleScript)
-- The one place lobby code reads and writes saved player data.
-- Every write goes through the player's Replica, so the client's copy updates instantly
-- (the UI listens to it) and ProfileService saves it.

local DataManager = require(script.Parent.DataManager)
local LobbyConfig = require(game:GetService("ReplicatedStorage").Modules.Shared.Config.LobbyConfig)

local PlayerStore = {}

-- Wait (up to ~10s) for the player's profile to load. Returns data, replica or nil.
function PlayerStore.Wait(player: Player)
	for _ = 1, 40 do
		if not player.Parent then return nil end
		local data = DataManager:Get(player)
		local replica = DataManager.DataReplicas[player]
		if data and replica then return data, replica end
		task.wait(0.25)
	end
	return nil
end

function PlayerStore.Get(player: Player)
	return DataManager:Get(player), DataManager.DataReplicas[player]
end

-- path: array of keys, e.g. {"Owned", "Knife"}
function PlayerStore.Set(player: Player, path: { any }, value: any): boolean
	local _, replica = PlayerStore.Get(player)
	if not replica then return false end
	replica:SetValue(path, value)
	return true
end

function PlayerStore.Increment(player: Player, path: { any }, amount: number): number?
	local data, replica = PlayerStore.Get(player)
	if not replica then return nil end
	local t = data
	for i = 1, #path - 1 do t = t[path[i]] end
	local new = (t[path[#path]] or 0) + amount
	replica:SetValue(path, new)
	return new
end

function PlayerStore.Credits(player: Player): number
	local data = DataManager:Get(player)
	return data and data.Credits or 0
end

-- Spend credits if the player has enough. Returns true on success.
function PlayerStore.Spend(player: Player, amount: number): boolean
	local data = DataManager:Get(player)
	if not data or data.Credits < amount then return false end
	PlayerStore.Set(player, { "Credits" }, data.Credits - amount)
	return true
end

function PlayerStore.Owns(player: Player, itemId: string): boolean
	local data = DataManager:Get(player)
	if not data then return false end
	local item = LobbyConfig.Items[itemId]
	return item ~= nil and (item.Default == true or data.Owned[itemId] == true)
end

function PlayerStore.Grant(player: Player, itemId: string)
	if LobbyConfig.Items[itemId] then
		PlayerStore.Set(player, { "Owned", itemId }, true)
	end
end

-- Bump a quest stat (the match place does the same on its side of the profile).
function PlayerStore.AddStat(player: Player, stat: string, amount: number?)
	if not DataManager:Get(player) then return end
	PlayerStore.Increment(player, { "Stats", stat }, amount or 1)
end

-- Copy of the loadout, validated against what the player owns.
function PlayerStore.Loadout(player: Player)
	local data = DataManager:Get(player)
	local out = table.clone(LobbyConfig.DefaultLoadout)
	if data then
		for slot, id in data.Loadout do
			local item = LobbyConfig.Items[id]
			if item and item.Slot == slot and PlayerStore.Owns(player, id) then
				out[slot] = id
			end
		end
	end
	return out
end

-- Mirror the loadout onto attributes the gameplay code reads (KitGadget / KitMelee / KitWeapon).
function PlayerStore.ApplyLoadoutAttributes(player: Player)
	local l = PlayerStore.Loadout(player)
	player:SetAttribute("KitWeapon", l.Weapon)
	player:SetAttribute("KitGadget", l.Gadget)
	player:SetAttribute("KitMelee", l.Melee)
end

-- [RANKED] the unified ranked record of a mode's ladder (lazy migration): ServerScriptService.Shared.RankedServer
function PlayerStore.Ranked(player: Player, mode: string?)
	return require(game:GetService("ServerScriptService").Shared.RankedServer).Record(player, mode)
end

return PlayerStore
