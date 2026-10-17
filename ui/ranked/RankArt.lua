-- UIKit/RankArt (ModuleScript): the rank emblem images and a player's rank as the UI shows it (UI session 2026-10-17).
-- One source for RankedScreen, the nameplates and the player list. Images: Gunsy Funsy uploads of ui/art/ranks/v2
-- (decal / image ids in notes/ranked_design.md).
--   RankArt.EMBLEM[rank] -> "rbxassetid://..."
--   RankArt.Of(player) -> { placed = bool, rank = "Gold"|nil, name = "Gold 2"|"Unranked", elo = number, image = id|nil }
local RankArt = {}

RankArt.EMBLEM = {
	Bronze = "rbxassetid://127275551172420", Silver = "rbxassetid://85182973115869", Gold = "rbxassetid://112298763732792",
	Platinum = "rbxassetid://124376885255343", Diamond = "rbxassetid://80103384303847", Elite = "rbxassetid://120281929548886",
	Commander = "rbxassetid://136618251030474", Warlord = "rbxassetid://128657545561698",
}

-- placements unfinished (RankPlaced < RankPlacements) = unranked: no emblem, no ELO shown
function RankArt.Of(p: Player)
	local placed, need = p:GetAttribute("RankPlaced") or 0, p:GetAttribute("RankPlacements") or 0
	local elo = p:GetAttribute("RankElo") or 100
	if need > 0 and placed < need then
		return { placed = false, rank = nil, name = "Unranked", elo = elo, image = nil }
	end
	local rank = p:GetAttribute("RankWarlord") and "Warlord" or p:GetAttribute("RankTier")
	return { placed = rank ~= nil, rank = rank, name = p:GetAttribute("RankName") or rank or "Unranked", elo = elo, image = rank and RankArt.EMBLEM[rank] or nil }
end

return RankArt
