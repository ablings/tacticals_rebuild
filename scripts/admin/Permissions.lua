-- ServerScriptService/AdminFramework/Permissions (ModuleScript): admin levels, decided on the server only.
--   Permissions.LevelOf(player) -> number, why     (0 None, 1 Tester, 2 Admin, 3 Owner; console = Owner)
--   Permissions.Name(n) / Permissions.Value("Admin")
--   Permissions.SetSimulated(userId, "None"|"Tester"|"Admin"|"Owner"|nil)   Studio only: pretend to be that level
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.Config)

local IS_STUDIO = RunService:IsStudio()
local Permissions = {}

local VALUES = { None = 0, Tester = 1, Admin = 2, Owner = 3 }
local NAMES = { [0] = "None", [1] = "Tester", [2] = "Admin", [3] = "Owner" }
Permissions.Values = VALUES
Permissions.Names = NAMES

function Permissions.Value(name: string?): number
	return VALUES[name or ""] or 0
end
function Permissions.Name(n: number): string
	return NAMES[n] or "None"
end
function Permissions.Parse(token: string?): string?
	if not token then return nil end
	local t = string.lower(token)
	for name in VALUES do if string.lower(name) == t then return name end end
	return nil
end

local function groupId(): number
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId ~= 0 then return game.CreatorId end
	return Config.GroupId or 0
end
Permissions.GroupId = groupId

local rankCache = {} -- [userId] = { rank, t }
local function groupRank(player: Player): number
	local gid = groupId()
	if gid == 0 or player.UserId <= 0 then return 0 end
	local c = rankCache[player.UserId]
	if c and os.clock() - c.t < (Config.GroupCacheTime or 120) then return c.rank end
	local ok, rank = pcall(player.GetRankInGroup, player, gid)
	rank = ok and tonumber(rank) or (c and c.rank) or 0
	rankCache[player.UserId] = { rank = rank, t = os.clock() }
	return rank
end
Players.PlayerRemoving:Connect(function(p) rankCache[p.UserId] = nil end)

-- the level a player really has (ignores Studio)
local function realLevel(player: Player): (number, string)
	local best, why = 0, "not on the admin list"
	local listed = Config.Users[player.UserId]
	if listed and VALUES[listed] then best, why = VALUES[listed], "admin list" end
	local rank = groupRank(player)
	for name, need in Config.GroupRanks or {} do
		if rank >= need and VALUES[name] > best then best, why = VALUES[name], ("group rank %d"):format(rank) end
	end
	return best, why
end

function Permissions.LevelOf(player: any): (number, string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return VALUES.Owner, "server console" end
	if IS_STUDIO then
		local sim = ServerStorage:GetAttribute("AdminSim_" .. player.UserId)
		if type(sim) == "string" and VALUES[sim] then return VALUES[sim], "Studio simulated level" end
		return VALUES[Config.StudioLevel] or VALUES.Owner, "Studio test"
	end
	return realLevel(player)
end
Permissions.RealLevel = realLevel

-- Studio only: pretend `userId` has `levelName` (nil = back to normal). The attribute lives in ServerStorage (server only).
function Permissions.SetSimulated(userId: number, levelName: string?): (boolean, string?)
	if not IS_STUDIO then return false, "simulated levels exist only in Studio" end
	if levelName ~= nil and not VALUES[levelName] then return false, "unknown level " .. tostring(levelName) end
	ServerStorage:SetAttribute("AdminSim_" .. userId, levelName)
	return true
end

return Permissions
