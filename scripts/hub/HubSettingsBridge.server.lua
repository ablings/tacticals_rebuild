-- ServerScriptService.HubSettingsBridge (Script, hub / lobby place only) 2026-10-20 (UI session: the badges' Display Badges row,
-- and every other setting other players should be able to see). The match places' SettingsBridge puts each saved settings row on
-- the player as server-set attributes (Setting_<Row> / Bind_<Action> + AimSensitivity), which replicate to everyone. The hub only
-- set them on the client (SettingsConfig.Apply), so other players never saw someone's choice. This does the same as SettingsBridge
-- from the hub's PlayerStore, on join and after every SaveSettings (LobbyManager calls shared.SettingsApply).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStore = require(game:GetService("ServerScriptService"):WaitForChild("Data"):WaitForChild("PlayerStore"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))

local function apply(player: Player)
	local data
	for _ = 1, 60 do
		local ok, d = pcall(PlayerStore.Get, player)
		data = ok and d or nil
		if data or not player.Parent then break end
		task.wait(0.25)
	end
	if not player.Parent then return end
	local p = SettingsConfig.ActiveProfile(data and data.Settings or nil)
	for tabName, list in SettingsConfig.Rows do
		for key, row in list do
			local v = p[tabName] and p[tabName][key]
			local name = key:gsub("[^%w_]", "")
			if row.kind == "bind" then
				player:SetAttribute("Bind_" .. name, type(v) == "table" and v[1] ~= "" and v[1] or nil)
			else
				player:SetAttribute("Setting_" .. name, v)
			end
		end
	end
	player:SetAttribute("AimSensitivity", ((p.Video or {}).Sensitivity or 100) / 100)
end

Players.PlayerAdded:Connect(apply)
if not shared.SettingsApply then shared.SettingsApply = apply end
for _, p in Players:GetPlayers() do task.spawn(apply, p) end
