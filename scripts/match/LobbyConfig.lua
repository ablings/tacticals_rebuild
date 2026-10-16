-- ReplicatedStorage/Modules/Shared/Config/LobbyConfig (ModuleScript) - MATCH PLACE PORT (subset)
-- [MATCH] 2026-10-16 (notes/match_place_flow.md): the parts of the lobby's LobbyConfig the match place needs, copied verbatim:
--   Items / Slots / DefaultLoadout / Rarities / Images (OwnedItems, the Loadout pick screen, Pick validation, admin give/take),
--   QuestStats / Quests (admin ;missions), the level curves + AccountLevel / ItemLevel / XPForLevel (the Level attribute, admin),
--   StartingRating, the place ids. Shop, bundles, Robux, queues and the armory camera stay lobby-only.
-- KEEP IN SYNC with the lobby's ReplicatedStorage.Modules.Shared.Config.LobbyConfig: an item or curve change there must be
-- copied here (scripts/match/LobbyConfig.lua, then python tools/match_place_build.py --run).

local LobbyConfig = {}

LobbyConfig.MatchPlaceId = 81861384114744 -- "tutorial spot / matchmaking test" place
LobbyConfig.TutorialPlaceId = 81861384114744
LobbyConfig.LobbyPlaceId = 126491009194165
LobbyConfig.StartingCredits = 500
LobbyConfig.StartingRating = 1000

-------------------------------------------------------------------------------
-- Items (the kit). Default = everyone owns it from the start.
-------------------------------------------------------------------------------
LobbyConfig.Slots = { "Weapon", "Gadget", "Melee" }
LobbyConfig.SlotNames = { Weapon = "WEAPON", Gadget = "GADGET", Melee = "MELEE" }
LobbyConfig.DefaultLoadout = { Weapon = "Pistol", Gadget = "Smoke", Melee = "Fists" }

LobbyConfig.Rarities = {
	Standard = { Order = 1, Color = Color3.fromRGB(170, 176, 184) },
	Rare = { Order = 2, Color = Color3.fromRGB(70, 160, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(190, 100, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(214, 58, 70) }, -- crimson (pass 34: no amber),
}

LobbyConfig.Items = {
	-- guns (WeaponConfig ids). Every gun: 150 HP to chew through, damage falls off with range.
	Pistol = { Name = "Pistol", Slot = "Weapon", Price = 0, Default = true, Rarity = "Standard",
		Desc = "12-round semi-auto. Honest at every range." },
	SilencedPistol = { Name = "Suppressed", Slot = "Weapon", Price = 1500, Rarity = "Rare",
		Desc = "Hits harder than the pistol and barely makes a sound. Fades past 30m." },
	Revolver = { Name = "Revolver", Slot = "Weapon", Price = 2500, Rarity = "Epic",
		Desc = "One headshot up close. Loses its bite fast past 12m." },
	MiniUzi = { Name = "Mini Uzi", Slot = "Weapon", Price = 2000, Rarity = "Rare",
		Desc = "Hold to spray. Shreds up close, light on your feet, weak at range." },
	AutoRifle = { Name = "Automatic Rifle", Slot = "Weapon", Price = 3000, Rarity = "Epic",
		Desc = "Full-auto all-rounder. Heavier: slower to move and reload." },
	SemiAuto = { Name = "Semi-Auto", Slot = "Weapon", Price = 3000, Rarity = "Epic",
		Desc = "Hard-hitting marksman rifle that holds its damage at long range." },
	Sniper = { Name = "Sniper", Slot = "Weapon", Price = 4000, Rarity = "Legendary",
		Desc = "Bolt-action. A headshot kills at any range. Slow, heavy, punishing to miss." },
	-- gadgets (GadgetConfig ids)
	Smoke = { Name = "Smoke", Slot = "Gadget", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Blocks sight lines. Cross open ground safely." },
	Flash = { Name = "Flashbang", Slot = "Gadget", Price = 1200, Rarity = "Rare",
		Desc = "Blinds anyone looking at it." },
	Frag = { Name = "Frag", Slot = "Gadget", Price = 2000, Rarity = "Epic",
		Desc = "Flush enemies out of cover." },
	-- melee (MeleeConfig ids)
	Fists = { Name = "Fists", Slot = "Melee", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Fast jabs. Lethal from behind." },
	Knife = { Name = "Knife", Slot = "Melee", Price = 800, Rarity = "Rare",
		Desc = "More damage and reach than fists." },
}

-- Card art. Paste "rbxassetid://..." per item; "" = placeholder card with the name.
LobbyConfig.Images = {}

-------------------------------------------------------------------------------
-- Quests (stats the match place increments; the lobby hands them out and pays them)
-------------------------------------------------------------------------------
LobbyConfig.QuestStats = { "MatchesPlayed", "Wins", "Kills", "Headshots", "CoverKills", "MeleeKills", "GadgetsThrown" }

LobbyConfig.Quests = {
	Daily = {
		Count = 3,
		Pool = {
			{ Id = "D_Play", Text = "Play 3 matches", Stat = "MatchesPlayed", Goal = 3, Reward = 150 },
			{ Id = "D_Win", Text = "Win 2 matches", Stat = "Wins", Goal = 2, Reward = 200 },
			{ Id = "D_Kills", Text = "Get 8 eliminations", Stat = "Kills", Goal = 8, Reward = 175 },
			{ Id = "D_Heads", Text = "Land 5 headshot kills", Stat = "Headshots", Goal = 5, Reward = 175 },
			{ Id = "D_Cover", Text = "Get 3 eliminations from cover", Stat = "CoverKills", Goal = 3, Reward = 200 },
			{ Id = "D_Melee", Text = "Get a melee elimination", Stat = "MeleeKills", Goal = 1, Reward = 175 },
			{ Id = "D_Gadget", Text = "Throw 6 gadgets", Stat = "GadgetsThrown", Goal = 6, Reward = 125 },
		},
	},
	Weekly = {
		Count = 3,
		Pool = {
			{ Id = "W_Win", Text = "Win 10 matches", Stat = "Wins", Goal = 10, Reward = 1000 },
			{ Id = "W_Play", Text = "Play 20 matches", Stat = "MatchesPlayed", Goal = 20, Reward = 750 },
			{ Id = "W_Kills", Text = "Get 50 eliminations", Stat = "Kills", Goal = 50, Reward = 900 },
			{ Id = "W_Heads", Text = "Land 25 headshot kills", Stat = "Headshots", Goal = 25, Reward = 900 },
			{ Id = "W_Cover", Text = "Get 15 eliminations from cover", Stat = "CoverKills", Goal = 15, Reward = 1000 },
		},
	},
}

-------------------------------------------------------------------------------
-- Levels
-------------------------------------------------------------------------------
LobbyConfig.ItemLevels = { First = 250, Step = 100, Max = 50 }
LobbyConfig.AccountLevels = { First = 400, Step = 150, Max = 999 }
LobbyConfig.RankedLevel = 50 -- account level that unlocks ranked queues

local function levelFrom(xp: number, curve): (number, number, number)
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level, need = 1, curve.First
	while level < curve.Max and xp >= need do
		xp -= need
		level += 1
		need += curve.Step
	end
	if level >= curve.Max then return curve.Max, need, need end
	return level, xp, need
end

function LobbyConfig.ItemLevel(xp: number?): (number, number, number)
	return levelFrom(xp or 0, LobbyConfig.ItemLevels)
end

function LobbyConfig.AccountLevel(xp: number?): (number, number, number)
	return levelFrom(xp or 0, LobbyConfig.AccountLevels)
end

-- total XP needed to reach an account level
function LobbyConfig.XPForLevel(level: number): number
	local curve, xp = LobbyConfig.AccountLevels, 0
	for l = 1, math.min(level, curve.Max) - 1 do xp += curve.First + (l - 1) * curve.Step end
	return xp
end

return LobbyConfig
