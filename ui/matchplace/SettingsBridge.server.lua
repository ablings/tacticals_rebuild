-- ServerScriptService.SettingsBridge (match place; UI session 2026-10-16 replaces pass 43/45)
-- The match place has no settings screen. It reads the saved lobby settings from the shared profile and puts every
-- row on the player the same way the lobby does: Setting_<Row> / Bind_<Action> attributes plus AimSensitivity
-- (SettingsConfig.Rows, the same list the lobby saves against). Server-set attributes replicate, so the client
-- controllers read them exactly as in the lobby. Volumes are applied per client by SettingsEffectsController
-- (never here: a SoundGroup volume set on the server would change everyone's).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DM = require(game:GetService("ServerScriptService"):WaitForChild("Data"):WaitForChild("DataManager"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))

local function apply(player: Player)
	local data
	for _ = 1, 60 do
		local ok, d = pcall(function() return DM:Get(player) end)
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
for _, p in Players:GetPlayers() do task.spawn(apply, p) end
