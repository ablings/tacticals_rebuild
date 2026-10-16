-- ReplicatedStorage/Modules/Shared/Config/LobbyFeaturesConfig (ModuleScript, lobby place only)
-- Lobby feature pass (Edward's picks 3, 4, 18-21, 23, 29-32; notes/features_done.md). Every feature sits behind a flag here.
-- Play-mode switch without editing code: ReplicatedStorage:SetAttribute("LF_<Name>", false) (or true) before Play / at runtime.
-- Off = LobbyFeaturesManager moves that feature's geometry (LobbyMap.Features.<Name>, or Signs.Screen_Leaderboard) to
-- ServerStorage._LobbyFeaturesOff, so nothing is left in the world. A missing or broken config means "all off".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = {
	-- 3: drop pits in the Duels hall; falling in puts you back at the Duels start (LobbyMap.Features.DropPits.ReturnPoint)
	DropPits = { Enabled = true },
	-- 4: screen on the hub east wall by the Exfil tunnel listing who is in Training (player attribute InTraining)
	TrainingScreen = { Enabled = true, MaxNames = 8 },
	-- 18: the existing LeaderboardScreen + LobbyLeaderboard draw on LobbyMap.Signs.Screen_Leaderboard (only the part was missing)
	Leaderboard = { Enabled = true },
	-- 19: live duels TV. Matches are logged when a pad bay deploys (QueueManager snapshot) or an online search is found
	-- (MM_Status). Shared with every lobby server through MessagingService (topic below) when it is available.
	-- MatchMinutes: how long a started match stays listed as LIVE (the match place reports no result to the lobby yet).
	DuelsTV = { Enabled = true, MatchMinutes = 6, Topic = "TacLiveDuels_v1", UseMessaging = true, MaxRows = 5 },
	-- 20a: likes goal. No API returns a game's live like count inside a server, so the numbers are values Edward sets:
	-- here, or at runtime with ReplicatedStorage attributes LF_LikesCurrent / LF_LikesGoal / LF_LikesReward.
	LikesBoard = { Enabled = true, Current = 0, Goal = 1000, Reward = "GOAL REWARD: A FREE CODE FOR EVERYONE" },
	-- 20b: rewarded video ad board (AdService rewarded video). Needs a Developer Product id whose receipt grants the reward
	-- (ProcessReceipt). 0 = not set up: the board shows COMING SOON and its prompt stays off (documented stub).
	AdBoard = { Enabled = true, DevProductId = 0, RewardText = "WATCH A SHORT AD · GET 100 CREDITS", Cooldown = 30 },
	-- 21: live strip under the hub DUELS sign with pad queue counts and online searches per mode
	DuelsSign = { Enabled = true },
	-- 23: floor chevrons, floor stencils and label plates to Shop / Armory / Duels / Exfil / Training (static geometry)
	Wayfinding = { Enabled = true },
	-- 29-32 effects in the map's theme (olive / cream / warm white; no purple; no ambient particles)
	Spotlights = { Enabled = true },          -- warm-white SpotLights on the bridges and room ceilings aimed at features
	Beacons = { Enabled = true, Period = 2.6 }, -- slow amber/red aviation beacons (hangar mouth, pad masts, Duels roof)
	InteractFX = { Enabled = true },          -- cream/olive hologram cones + a few sparkles on the Shop counter, gun wall, dais
	VentPuffs = { Enabled = true, MinGap = 6, MaxGap = 12 }, -- small puffs from 4 real hub floor vents, now and then
	-- [FEAT] 14: top-player reward stand in the hub (kit F_RewardStand, placed by fix/place_features_kit.lua in
	-- LobbyMap.Features.RewardStand). The name plate shows #1 of ReplicatedStorage.LobbyTopWins (LobbyLeaderboard's list);
	-- the reward model spins through LobbyFX's LobbySpin tag (attribute spin = deg/s on its SpinRoot part).
	RewardStand = { Enabled = true, Title = "TOP OPERATOR", Empty = "CLAIM THE TOP SPOT" }, -- [FEAT]
}

-- Is this feature on? The LF_<name> attribute on ReplicatedStorage wins over the value above.
function C.On(name: string): boolean
	local a = ReplicatedStorage:GetAttribute("LF_" .. name)
	if a ~= nil then return a == true end
	local v = C[name]
	if type(v) == "table" then return v.Enabled == true end
	return v ~= nil and v ~= false
end

-- Live value with a ReplicatedStorage attribute override (used by the likes board).
function C.Value(attr: string, default)
	local a = ReplicatedStorage:GetAttribute(attr)
	if a ~= nil then return a end
	return default
end

-- Every feature name (the manager and the installer walk this list).
C.Features = { "DropPits", "TrainingScreen", "Leaderboard", "DuelsTV", "LikesBoard", "AdBoard", "DuelsSign", "Wayfinding",
	"Spotlights", "Beacons", "InteractFX", "VentPuffs", "RewardStand" } -- [FEAT] RewardStand

return C
