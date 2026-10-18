-- [PSEUDOLOBBY] the hub's profile template, copied to the match places (2026-10-18) so a profile first made there has every key
-- the lobby code reads (Quests, Owned, Loadout, ...). Same store (gameStore) and Reconcile on both sides.
-- Saved player data. New keys are filled in for existing players automatically (profile:Reconcile).
-- The match place shares this profile (same experience = same DataStore), so it can bump Stats
-- for quests and read Loadout.
local module = {
	Credits = 500,             -- SCISSORS: the game's only currency (kept as "Credits" so the match place's saves still line up)
	Owned = {},                 -- [itemId] = true (Default items are owned without being listed)
	Loadout = { Weapon = "Pistol", Gadget = "Smoke", Melee = "Fists" },
	Stats = { MatchesPlayed = 0, Wins = 0, Kills = 0, Headshots = 0, CoverKills = 0, MeleeKills = 0, GadgetsThrown = 0 },
	Quests = {
		Daily = { Key = "", List = {} },  -- List entries: { Id, Base (stat value when assigned), Claimed }
		Weekly = { Key = "", List = {} },
	},
	XP = 0,                     -- account XP (level = LobbyConfig.AccountLevel(XP); ranked unlocks at 50)
	Favorites = {},             -- [itemId] = true (starred in the Armory)
	ItemXP = {},                -- [itemId] = XP earned with that item (level = LobbyConfig.ItemLevel)
	-- [RANKED] [ladder key] = { V, Elo, Peak, Placed, Wins, Losses, Streak, ShieldDay, LastPlayed, Decayed, Rating (= Elo, mirror) };
	-- created / migrated from the old { Rating, Wins, Losses } / { Rating, Played, Wins } by ServerScriptService.Shared.RankedServer
	Ranked = {},
	Passes = {},                -- [passKey] = true
	Receipts = {},              -- [PurchaseId] = os.time()  (developer products granted once)

	Settings = {},               -- [key] = value; keys, ranges and defaults in Shared/Config/SettingsConfig
	RedeemedCodes = {},         -- [CODE] = os.time()

	-- // Version tracking
	ProfileVersion = 1
}

export type Data = typeof(module)

return module
