-- ReplicatedStorage/Modules/Shared/Binds (ModuleScript): the key a player has bound to an action in
-- Settings > Hotkeys, with the game's config key as the fallback. SettingsConfig.Apply writes the binds as player
-- attributes Bind_<storage key without spaces> (first PC key); the storage keys stay RIVALS' names so old saves load.
--   local Binds = require(ReplicatedStorage.Modules.Shared.Binds)
--   Binds.Key(player, "Reload", Enum.KeyCode.R)      -> Enum.KeyCode / Enum.UserInputType
--   Binds.Matches(player, "Reload", input, fallback)  -> true when this InputObject is that action
--   Binds.Changed(player, "Reload", fn)               -> fn() whenever the bind changes (rebind ContextActionService)
-- (UI session 2026-10-16)
local Binds = {}

-- Tacticals action -> settings storage key (SettingsData row key)
Binds.Keys = {
	Fire = "Attack", Aim = "Ability", Reload = "Reload", ShoulderSwap = "Shoulder Swap", GunBash = "Quick Melee",
	ThrowGadget = "Quick Utility", Jump = "Jump", Sprint = "Sprint", Crouch = "Crouch", Slide = "Slide",
	TakeCover = "Take Cover", Dash = "Dash", EquipGun = "Equip Primary", EquipMelee = "Equip Melee",
	EquipGadget = "Equip Utility", CycleWeapon = "Switch Weapons", FreeCursor = "Free Cursor",
	PlayerList = "Open Scoreboard", HideHUD = "Hide HUD",
}

local function attrName(action)
	local key = Binds.Keys[action] or action
	return "Bind_" .. key:gsub("[^%w_]", "")
end

local function toInput(name)
	if type(name) ~= "string" or name == "" then return nil end
	if name:match("^MouseButton%d$") then return Enum.UserInputType[name] end
	local ok, kc = pcall(function() return Enum.KeyCode[name] end)
	return ok and kc or nil
end

function Binds.Key(player, action, fallback)
	return toInput(player:GetAttribute(attrName(action))) or fallback
end

function Binds.Matches(player, action, input, fallback)
	local k = Binds.Key(player, action, fallback)
	if not k then return false end
	if k.EnumType == Enum.UserInputType then return input.UserInputType == k end
	return input.KeyCode == k
end

function Binds.Changed(player, action, fn)
	return player:GetAttributeChangedSignal(attrName(action)):Connect(fn)
end

return Binds
