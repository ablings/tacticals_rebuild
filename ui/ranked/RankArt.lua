-- UIKit/RankArt (ModuleScript): the rank emblem images and a player's rank as the UI shows it (UI session 2026-10-17).
-- One source for RankedScreen, the nameplates and the player list. Images: Gunsy Funsy uploads of ui/art/ranks/v2
-- (decal / image ids in notes/ranked_design.md).
--   RankArt.EMBLEM[rank] -> "rbxassetid://..."
--   RankArt.Of(player) -> { placed = bool, rank = "Gold"|nil, name = "Gold 2"|"Unranked", elo = number, image = id|nil }
local RankArt = {}

-- (2026-10-18, Edward) RIVALS-style: every rank has three looks, plainer at division 1, ornate at division 3
-- (ui/art/ranks/v3 by codex on the v2 base; art file _3 = plainest, _1 = most ornate). [rank][division] -> image
RankArt.DIVISION = {
	Bronze = { "rbxassetid://130391926217351", "rbxassetid://118363837007429", "rbxassetid://127748736992267" },
	Silver = { "rbxassetid://91131371183688", "rbxassetid://136212328518757", "rbxassetid://111897768916327" },
	Gold = { "rbxassetid://78234658895314", "rbxassetid://84418891669063", "rbxassetid://98082313898586" },
	Platinum = { "rbxassetid://80666077023283", "rbxassetid://136499863580471", "rbxassetid://114510792631859" },
	Diamond = { "rbxassetid://113503268936718", "rbxassetid://95004595091228", "rbxassetid://102586067050732" },
	Elite = { "rbxassetid://72346912684028", "rbxassetid://134538555392548", "rbxassetid://76384395433761" },
	Commander = { "rbxassetid://71016268090692", "rbxassetid://133116421173139", "rbxassetid://90571529637637" },
	Warlord = { "rbxassetid://133155537235820", "rbxassetid://121982775921411", "rbxassetid://122063253678079" },
}
-- one picture per rank (the middle look) for places that show only the rank
RankArt.EMBLEM = {}
for r, d in RankArt.DIVISION do RankArt.EMBLEM[r] = d[2] end
RankArt.EMBLEM.Warlord = RankArt.DIVISION.Warlord[3]
-- the emblem for a rank and division (1..3; Warlord and unknown -> the top / middle look)
function RankArt.Emblem(rank: string?, division: number?): string?
	local d = rank and RankArt.DIVISION[rank]
	if not d then return nil end
	if rank == "Warlord" then return d[3] end
	return d[math.clamp(tonumber(division) or 2, 1, 3)]
end

-- placements unfinished (RankPlaced < RankPlacements) = unranked: no emblem, no ELO shown
function RankArt.Of(p: Player)
	local placed, need = p:GetAttribute("RankPlaced") or 0, p:GetAttribute("RankPlacements") or 0
	local elo = p:GetAttribute("RankElo") or 100
	if need > 0 and placed < need then
		return { placed = false, rank = nil, name = "Unranked", elo = elo, image = nil }
	end
	local rank = p:GetAttribute("RankWarlord") and "Warlord" or p:GetAttribute("RankTier")
	return { placed = rank ~= nil, rank = rank, name = p:GetAttribute("RankName") or rank or "Unranked", elo = elo, image = rank and RankArt.Emblem(rank, tonumber(tostring(p:GetAttribute("RankName") or ""):match("(%d+)%s*$"))) or nil, division = tonumber(tostring(p:GetAttribute("RankName") or ""):match("(%d+)%s*$")) }
end

return RankArt
