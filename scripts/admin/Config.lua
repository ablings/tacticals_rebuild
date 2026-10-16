-- ServerScriptService/AdminFramework/Config (ModuleScript): who is an admin and how the framework behaves.
-- Shared by the lobby and the match place (notes/admin_framework.md). Server only: never put this in ReplicatedStorage.
--
-- Levels (highest wins): Owner > Admin > Tester > None. A player's level is the best of:
--   * Users[userId] below (explicit list);
--   * their rank in the owning group (GroupRanks: rank >= the number gives that level);
--   * Studio: always StudioLevel (Owner), unless a Studio-only simulated level is set (`;simlevel`, AdminBindable "simlevel").
-- Every check runs on the server; the client only sends text.
local Config = {}

Config.Prefix = ";"            -- chat prefix for every command (";setlevel me 20")
Config.LegacyPrefix = "/"      -- the old AdminCommands names keep working with "/" (/scissors, /give, /wipeweapons, /unlockall, /admin)

-- the group that owns Tacticals: "gunsy funsy" (owner ocxa). In a published game game.CreatorId is used when the
-- creator is a group; this id is the fallback for local files (CreatorId 0) and Studio.
Config.GroupId = 102028987
Config.GroupRanks = {
	Owner = 255,  -- group owner
	Admin = 254,  -- the group's "Admin" role
	-- Tester = 200, -- uncomment and create a Tester role at this rank to grant Tester by group rank
}

-- explicit list: [userId] = "Owner" | "Admin" | "Tester"
Config.Users = {
	[281164661] = "Owner", -- Edward: username ocxa, display name "debits"; owner of gunsy funsy
	-- NOT 63563472: that is a different account whose username is "debits" (checked 2026-10-16)
}

Config.StudioLevel = "Owner"
Config.ConfirmWindow = 10      -- seconds to repeat a destructive command with "confirm"
Config.RateLimit = 0.25        -- seconds between commands per player
Config.MaxTextLength = 200
Config.GroupCacheTime = 120    -- seconds a group rank lookup is trusted

-- audit log: last AuditMemory entries in memory; a capped copy in a DataStore (skipped quietly where DataStores fail, e.g. Studio)
Config.AuditMemory = 200
Config.AuditStore = "AdminAudit_v1"
Config.AuditStoreCap = 100
Config.AuditFlushEvery = 30

-- level curve used when the place has no LobbyConfig (the match place): must match LobbyConfig.AccountLevels
Config.AccountLevels = { First = 400, Step = 150, Max = 999 }

return Config
