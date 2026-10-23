-- ReplicatedStorage.UIKit.Badges (UI session 2026-10-20, Edward: "your player name should show all roblox badges ... i am
-- verified so leaderboard should show roblox verified symbol and my name unless i have display badges off, i am roblox plus
-- my name should show that")
-- Roblox's own glyphs, drawn by any TextLabel: utf8.char(0xE000) = the verified badge, utf8.char(0xE001) = Premium (Roblox Plus).
-- Settings > Game > Display Badges (attribute Setting_DisplayBadges) shows / hides the verified badge for everyone.
--   Badges.Name(player)       -> "DisplayName <verified>" or "DisplayName <premium>" (just the name for bots / non-players)
--   Badges.Prefix(player) / Badges.Suffix(player)
local Badges = {}

Badges.VERIFIED = utf8.char(0xE000)
Badges.PREMIUM = utf8.char(0xE001)

local function isPlayer(p) return typeof(p) == "Instance" and p:IsA("Player") end

function Badges.Show(p)
	return isPlayer(p) and p:GetAttribute("Setting_DisplayBadges") ~= false
end

local function premium(p) return isPlayer(p) and p.MembershipType == Enum.MembershipType.Premium end -- (RIVALS: Premium shows either way)

-- RIVALS' order (checked live 2026-10-20): name, then the verified badge, then Premium (and the device icon, drawn by the
-- caller). The leaderboard keeps Premium in its own column left of the name (Badges.Prefix there, Badges.Suffix after).
function Badges.Prefix(p)
	return premium(p) and (Badges.PREMIUM .. " ") or ""
end

function Badges.Suffix(p)
	if Badges.Show(p) and p.HasVerifiedBadge then return " " .. Badges.VERIFIED end
	return ""
end

-- One badge after the name, like RIVALS (checked live 2026-10-20 with Edward): the verified badge while Display Badges is on,
-- else Premium. (RIVALS only re-reads the setting when you join; ours follows the attribute live.)
function Badges.Name(p, name)
	name = name or (isPlayer(p) and p.DisplayName) or ""
	if not isPlayer(p) then return name end
	if Badges.Show(p) and p.HasVerifiedBadge then return name .. " " .. Badges.VERIFIED end
	if p.MembershipType == Enum.MembershipType.Premium then return name .. " " .. Badges.PREMIUM end
	return name
end

-- (2026-10-20, RIVALS) the device a player uses, after their name (server attribute Device, lead's DeviceBridge; cosmetic only).
-- White silhouettes from ui/art/device (codex), empty until uploaded under the group.
Badges.DEVICE = { PC = "rbxassetid://86339845799720", Controller = "rbxassetid://98322586396958", Phone = "rbxassetid://97418735352975", Tablet = "rbxassetid://71841984291846" } -- (Gunsy Funsy uploads 2026-10-20)
function Badges.DeviceIcon(p)
	local dev = isPlayer(p) and p:GetAttribute("Device") or ""
	if dev == "Console" then dev = "Controller" end -- (Edward: controller and console share the icon)
	local id = Badges.DEVICE[dev]
	return (id and id ~= "") and id or nil
end

-- (2026-10-20, Edward, RIVALS) the ONE icon beside a name (nameplates, killer banner, match boxes), picked by the VIEWER's
-- leaderboard mode (Settings > Lobby Data): Level / Streak / Wins -> their win-streak flame if they have one, else their level
-- (Wins: their wins); Rank -> their rank emblem if ranked, else their level.
--   Badges.Icon(player) -> "streak", n | "rank", imageId | "level", n | "wins", n
function Badges.Icon(p)
	local viewer = game:GetService("Players").LocalPlayer
	-- (2026-10-23, Edward) one rule everywhere: the viewer's leaderboard picks it - Streak: flame if they have one; Rank: emblem if
	-- ranked; else (Level, Wins, none) their level
	local mode = (viewer and (viewer:GetAttribute("LeaderboardStat") or viewer:GetAttribute("Setting_LobbyData"))) or "Level"
	if not isPlayer(p) then return "level", 1 end
	local sn = tonumber(p:GetAttribute("WinStreak")) or 0
	if sn > 0 and mode == "Streak" then return "streak", sn end
	if mode == "Rank" then
		local ok, RankArt = pcall(function() return require(script.Parent:WaitForChild("RankArt", 2)) end)
		local r = ok and RankArt and RankArt.Of and RankArt.Of(p)
		if r and r.image then return "rank", r.image end
	end
	return "level", tonumber(p:GetAttribute("Level")) or 1
end

return Badges
