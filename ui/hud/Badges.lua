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

return Badges
