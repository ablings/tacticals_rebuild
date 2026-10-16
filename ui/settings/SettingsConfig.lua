-- ReplicatedStorage/Modules/Shared/Config/SettingsConfig (ModuleScript)
-- Saved settings, shared by every place in the game. The rows themselves live in UIKit.SettingsData
-- (the lobby SETTINGS screen draws from the same list); this module knows how they are stored,
-- checks saves on the server and applies them on the client.
--
-- Saved in the profile as data.Settings:
--   { Active = 1..3, Profiles = { [1] = { [tabName] = { [rowKey] = value } }, [2] = ..., [3] = ... } }
-- Values: toggle = boolean, slider = number, dropdown = option string, swatch = "#rrggbb",
-- bind = { pc, pc2, pad, pad2 } (input names, "" = unbound). Anything missing falls back to its default.
--
-- Another place (tutorial, match) follows the player's settings with:
--   local SettingsConfig = require(ReplicatedStorage.Modules.Shared.Config.SettingsConfig)
--   SettingsConfig.Apply(data.Settings, player)  -- after the profile replica loads
-- Gameplay scripts then read player attributes: Setting_<RowKey> with spaces removed (e.g.
-- "Setting_InvertedY"), Bind_<Action> (first PC key, e.g. "Bind_QuickMelee" = "F") and
-- AimSensitivity (1 = 100%).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("SettingsData"))

local SettingsConfig = {}
SettingsConfig.Profiles = 3

local rows = {} -- [tabName][rowKey] = row
for _, tab in ipairs(Data.tabs) do
	rows[tab.name] = {}
	for _, sec in ipairs(tab.sections) do
		for _, row in ipairs(sec.rows) do
			row.key = row.key or row.name
			rows[tab.name][row.key] = row
		end
	end
end
SettingsConfig.Rows = rows

local function toStored(row, v)
	if typeof(v) == "Color3" then return "#" .. v:ToHex():lower() end
	if type(v) == "table" then return table.clone(v) end
	return v
end

local function default(row)
	if row.kind == "swatch" then return toStored(row, row.color) end
	return toStored(row, row.value)
end
SettingsConfig.DefaultOf = default

local function validInput(name)
	if name == "" then return true end
	if name == "MouseButton1" or name == "MouseButton2" or name == "MouseButton3" then return true end
	local ok, kc = pcall(function() return Enum.KeyCode[name] end)
	return ok and kc ~= nil
end

-- one value, cleaned; nil if it isn't valid for that row
local function clean(row, v)
	if row.kind == "toggle" then
		return type(v) == "boolean" and v or nil
	elseif row.kind == "slider" then
		if type(v) ~= "number" or v ~= v then return nil end
		return math.clamp(v, row.min, row.max)
	elseif row.kind == "dropdown" then
		return (type(v) == "string" and table.find(row.options, v)) and v or nil
	elseif row.kind == "swatch" then
		return (type(v) == "string" and v:match("^#%x%x%x%x%x%x$")) and v:lower() or nil
	elseif row.kind == "bind" then
		if type(v) ~= "table" then return nil end
		local out = {}
		for i = 1, 4 do
			local s = v[i]
			if type(s) ~= "string" or #s > 40 or not validInput(s) then s = (row.value and row.value[i]) or "" end
			out[i] = s
		end
		return out
	end
	return nil
end

local function defaultProfile()
	local p = {}
	for tabName, list in rows do
		p[tabName] = {}
		for key, row in list do p[tabName][key] = default(row) end
	end
	return p
end

function SettingsConfig.Defaults()
	local profiles = {}
	for i = 1, SettingsConfig.Profiles do profiles[i] = defaultProfile() end
	return { Active = 1, Profiles = profiles }
end

-- Whatever came in (a client save, or old/partial profile data) -> a complete, valid settings table.
function SettingsConfig.Sanitize(raw)
	local out = SettingsConfig.Defaults()
	if type(raw) ~= "table" then return out end
	if type(raw.Active) == "number" and raw.Active == raw.Active then
		out.Active = math.clamp(math.floor(raw.Active), 1, SettingsConfig.Profiles)
	end
	local profiles = type(raw.Profiles) == "table" and raw.Profiles or {}
	for i = 1, SettingsConfig.Profiles do
		local p = profiles[i]
		if type(p) == "table" then
			for tabName, list in rows do
				local t = p[tabName]
				if type(t) == "table" then
					for key, row in list do
						local v = clean(row, t[key])
						if v ~= nil then out.Profiles[i][tabName][key] = v end
					end
				end
			end
		end
	end
	return out
end

function SettingsConfig.ActiveProfile(settings)
	local s = SettingsConfig.Sanitize(settings)
	return s.Profiles[s.Active], s
end

function SettingsConfig.Get(settings, tabName: string, key: string)
	local p = SettingsConfig.ActiveProfile(settings)
	return p[tabName] and p[tabName][key]
end

-- Client: put the active profile into effect.
function SettingsConfig.Apply(settings, player: Player)
	local p = SettingsConfig.ActiveProfile(settings)
	local audio = p.Audio or {}
	local master = (audio["Master Volume"] or 50) / 100
	local SoundService = game:GetService("SoundService")
	local function vol(name, v)
		local g = SoundService:FindFirstChild(name)
		if g then pcall(function() g.Volume = v end) end
	end
	vol("Music", (audio["Music Volume"] or 50) / 100 * master)
	vol("Effects", (audio["SFX Volume"] or 100) / 100 * master)
	vol("Finishers", (audio["Finisher Volume"] or 100) / 100 * master)

	for tabName, list in rows do
		for key, row in list do
			local v = p[tabName][key]
			local name = key:gsub("[^%w_]", "") -- attribute names can't hold spaces
			if row.kind == "bind" then
				player:SetAttribute("Bind_" .. name, v[1] ~= "" and v[1] or nil)
			else
				player:SetAttribute("Setting_" .. name, v)
			end
		end
	end
	local video = p.Video or {}
	player:SetAttribute("AimSensitivity", (video.Sensitivity or 100) / 100)
end

return SettingsConfig