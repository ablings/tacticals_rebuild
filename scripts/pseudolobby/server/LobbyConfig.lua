-- [PSEUDOLOBBY] the hub's LobbyConfig, copied to the match places (2026-10-18): the lobby code there (Shop, passes, queues by id)
-- needs GamePasses / QueueById, and the match place's older copy pointed TutorialPlaceId at the old combined place.
-- ReplicatedStorage/Modules/Shared/Config/LobbyConfig (ModuleScript)
-- Everything the lobby sells, tracks and queues for lives here. Server and client both read it,
-- so prices shown in the UI are the prices the server charges.
--
-- Adding an item:   add an entry to Items (Slot must be Weapon / Gadget / Melee).
-- Adding a bundle:  add an entry to Bundles (list item ids; Price is in Credits).
-- Robux:            paste the real Developer Product / Game Pass ids from the Creator Dashboard.
--                   Id = 0 means "not created yet": in Studio the buy button grants it for free
--                   (marked TEST) so you can try the flow; in a live server it says "coming soon".

local LobbyConfig = {}

LobbyConfig.MatchPlaceId = 81861384114744 -- "tutorial spot / matchmaking test" place
LobbyConfig.StartingCredits = 500

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
	-- [ABILITY2] new guns
	PumpShotgun = { Name = "Pump Shotgun", Slot = "Weapon", Price = 2500, Rarity = "Epic",
		Desc = "Point-blank power. A close hit knocks them out of cover. Reloads shell by shell." },
	DualPistols = { Name = "Dual Pistols", Slot = "Weapon", Price = 2200, Rarity = "Rare",
		Desc = "No aiming in. Dead accurate from the hip, twice the fire rate on the move." },
	-- gadgets (GadgetConfig ids)
	Smoke = { Name = "Smoke", Slot = "Gadget", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Blocks sight lines. Cross open ground safely." },
	Flash = { Name = "Flashbang", Slot = "Gadget", Price = 1200, Rarity = "Rare",
		Desc = "Blinds anyone looking at it." },
	Frag = { Name = "Frag", Slot = "Gadget", Price = 2000, Rarity = "Epic",
		Desc = "Flush enemies out of cover." },
	-- [ABILITY2] new gadgets
	StickyGrenade = { Name = "Sticky Grenade", Slot = "Gadget", Price = 1500, Rarity = "Rare",
		Desc = "Sticks to walls and people, then blows." },
	Landmine = { Name = "Landmine", Slot = "Gadget", Price = 1800, Rarity = "Epic",
		Desc = "Put it down, it arms. The next enemy to walk over it won't." },
	Medkit = { Name = "Medkit", Slot = "Gadget", Price = 1000, Rarity = "Rare",
		Desc = "Patch up 60 HP over a couple of seconds. Getting hit stops it." },
	-- melee (MeleeConfig ids)
	Fists = { Name = "Fists", Slot = "Melee", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Fast jabs. Lethal from behind." },
	Knife = { Name = "Knife", Slot = "Melee", Price = 800, Rarity = "Rare",
		Desc = "More damage and reach than fists." },
	-- [ABILITY2] new melee
	Bat = { Name = "Bat", Slot = "Melee", Price = 1000, Rarity = "Rare",
		Desc = "Hold to charge: a charged hit knocks them out of cover or off a ledge." },
	Katana = { Name = "Katana", Slot = "Melee", Price = 2500, Rarity = "Epic",
		Desc = "Right after a swing, bullets from the front are deflected." },
	RiotShield = { Name = "Riot Shield", Slot = "Melee", Price = 3000, Rarity = "Legendary",
		Desc = "Blocks bullets from the front while held. Bash to stun. Slow to carry." },
}

-- Card art. Paste "rbxassetid://..." per item; "" = placeholder card with the name.
LobbyConfig.Images = {}

-------------------------------------------------------------------------------
-- Bundles (bought with Credits). Price should beat buying the items one by one.
-------------------------------------------------------------------------------
LobbyConfig.Bundles = {
	{ Id = "Operator", Name = "OPERATOR KIT", Items = { "Knife", "Flash" }, Price = 1600,
		Tag = "SAVE 20%", Color = Color3.fromRGB(70, 160, 255) },
	{ Id = "Breacher", Name = "BREACHER KIT", Items = { "Revolver", "Frag" }, Price = 3600,
		Tag = "SAVE 20%", Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "Ghost", Name = "GHOST KIT", Items = { "SilencedPistol", "Smoke", "Knife" }, Price = 1900,
		Tag = "SAVE 17%", Color = Color3.fromRGB(150, 160, 175) },
}

-- What a bundle costs you: items you already own are taken off at their share of the bundle price.
-- owns(itemId) -> bool. Returns cost, number of items you'd get.
function LobbyConfig.BundleCost(bundle, owns)
	local total, ownedValue, missing = 0, 0, 0
	for _, id in bundle.Items do
		local price = LobbyConfig.Items[id].Price
		total += price
		if owns(id) then
			ownedValue += price
		else
			missing += 1
		end
	end
	if missing == 0 or total == 0 then return 0, missing end
	return math.ceil(bundle.Price * (1 - ownedValue / total) / 10) * 10, missing
end

-------------------------------------------------------------------------------
-- Robux store
-------------------------------------------------------------------------------
-- Developer products (can be bought again and again)
LobbyConfig.RobuxProducts = {
	{ Key = "Credits500", ProductId = 0, Name = "Pocket", Credits = 500, Robux = 49 },
	{ Key = "Credits1200", ProductId = 0, Name = "Pouch", Credits = 1200, Robux = 99, Tag = "+20%" },
	{ Key = "Credits3000", ProductId = 0, Name = "Toolkit", Credits = 3000, Robux = 229, Tag = "+30%" },
	{ Key = "Credits7500", ProductId = 0, Name = "Vault", Credits = 7500, Robux = 499, Tag = "Best value" },
	-- a Robux bundle: items + credits in one purchase
	{ Key = "FounderBundle", ProductId = 0, Name = "FOUNDER'S BUNDLE", Credits = 1000,
		Items = { "Revolver", "Knife", "Frag" }, Robux = 399, Tag = "LIMITED", Bundle = true },
}

-- SCISSORS are the game's only currency. In the data they're still called Credits (Items[x].Price, Credits
-- on products and codes) so the match place's saved data keeps working. The Robux packs above are scissor packs.

-- Game passes (bought once, owned forever)
LobbyConfig.GamePasses = {
	{ Key = "VIP", PassId = 0, Name = "VIP", Robux = 299,
		Desc = "VIP tag over your head and in chat, plus +25% scissors from matches and missions." },
	{ Key = "DoubleCredits", PassId = 0, Name = "2X SCISSORS", Robux = 499,
		Desc = "Double scissors from every match and mission." },
}

-------------------------------------------------------------------------------
-- Quests. Progress = how much a Stat has gone up since the quest was handed out.
-- The match place only has to increment profile.Data.Stats.<Stat>; the lobby does the rest.
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
-- Matchmaking
-------------------------------------------------------------------------------
LobbyConfig.Modes = {
	{ Id = "1v1", Name = "1V1", TeamSize = 1, Desc = "Pure duel. One life, one winner." },
	{ Id = "2v2", Name = "2V2", TeamSize = 2, Desc = "Bring a partner. Trade and flank." },
	{ Id = "3v3", Name = "3V3", TeamSize = 3, Desc = "Full squads. Smokes and crossfires." },
}
LobbyConfig.CountdownTime = 5      -- seconds after a bay fills before everyone deploys
LobbyConfig.SlotRadius = 3.6       -- how close to a pad's centre you must stand to take it
LobbyConfig.SlotKeepRadius = 4.4   -- ...and how far you can drift before you lose it
-- Studio only: start a bay's countdown when you're the only player in the server, so you can
-- test the whole flow alone. (Teleports don't work in Studio; you'll get a message instead.)
LobbyConfig.StudioSoloStart = false

-------------------------------------------------------------------------------
-- Armory (KIT) camera transition. Pick one:
--   "Doors"     hazard-striped blast doors slam shut, camera jolts, doors part on the armory
--   "Cinematic" letterbox bars close in, cut to black with the room name, slow dolly in
--   "WhipPan"   fast blurred swing away, landing on the armory mid-swing
--   "PunchIn"   camera rushes forward into a white flash, then pulls back from the item
--   "Rise"      camera lifts up out of the lobby and drops into the armory (first version)
-- In Studio you can try them live: Settings -> ARMORY TRANSITION (Studio only).
-------------------------------------------------------------------------------
LobbyConfig.ArmoryTransition = "WhipPan"

-------------------------------------------------------------------------------
-- Levels. Each level costs a bit more XP than the one before:
--   level 1 -> 2 costs First, every level after that costs Step more, up to Max.
-- ItemLevel(xp) / AccountLevel(xp) return level, xp into this level, xp needed for the next.
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

-------------------------------------------------------------------------------
-- Online queues (the PLAY button). Every lobby server shares them, so you're matched with whoever is
-- searching anywhere (MatchmakingManager). The pads in the Deployment wing are LOBBY queues: only
-- people in this server (QueueManager). Every queue is separate. Ranked opens at RankedLevel.
-------------------------------------------------------------------------------
LobbyConfig.Queues = {
	{ Id = "1v1", Mode = "1v1", TeamSize = 1, Ranked = false },
	{ Id = "2v2", Mode = "2v2", TeamSize = 2, Ranked = false },
	{ Id = "3v3", Mode = "3v3", TeamSize = 3, Ranked = false },
	{ Id = "R1v1", Mode = "1v1", TeamSize = 1, Ranked = true },
	{ Id = "R2v2", Mode = "2v2", TeamSize = 2, Ranked = true },
	{ Id = "R3v3", Mode = "3v3", TeamSize = 3, Ranked = true },
}
LobbyConfig.StartingRating = 1000
-- ranked only puts players together inside this rating gap; the gap widens the longer you wait
LobbyConfig.RatingWindow = { Start = 150, PerSecond = 10, Max = 1200 }
-- lobby pads that are ranked (bay ids per mode): they glow purple and need the ranked level too
LobbyConfig.RankedBays = { ["1v1"] = {}, ["2v2"] = {}, ["3v3"] = {} } -- ranked pads live in the ranked hallway (not built yet)
-- Studio only: ranked is open at any level so it can be tested
LobbyConfig.StudioUnlockRanked = false -- (pass 32) Edward: the lock must show in Studio too

function LobbyConfig.QueueById(id: string?)
	for _, q in LobbyConfig.Queues do
		if q.Id == id then return q end
	end
	return nil
end

function LobbyConfig.QueueFor(mode: string, ranked: boolean)
	for _, q in LobbyConfig.Queues do
		if q.Mode == mode and q.Ranked == (ranked == true) then return q end
	end
	return nil
end

function LobbyConfig.IsRankedBay(mode: string, bayId: number): boolean
	local list = LobbyConfig.RankedBays[mode]
	return list ~= nil and table.find(list, bayId) ~= nil
end

function LobbyConfig.CanPlayRanked(xp: number?, isStudio: boolean?): boolean
	if isStudio and LobbyConfig.StudioUnlockRanked then return true end
	return (LobbyConfig.AccountLevel(xp or 0)) >= LobbyConfig.RankedLevel
end

-- accounts raised to at least this level when their data loads (DataManager) - Edward's dev account
LobbyConfig.AutoLevel = { [281164661] = 50 }
-- total XP needed to reach an account level
function LobbyConfig.XPForLevel(level: number): number
	local curve, xp = LobbyConfig.AccountLevels, 0
	for l = 1, math.min(level, curve.Max) - 1 do xp += curve.First + (l - 1) * curve.Step end
	return xp
end

-- PLAY screen tile art (Codex, my_lobby/tex/play)
LobbyConfig.PlayArt = { Training = "rbxassetid://93902639138481", ["1v1"] = "rbxassetid://104720105351713", ["2v2"] = "rbxassetid://138152887022034", ["3v3"] = "rbxassetid://135962749833336", Ranked = "rbxassetid://135887181995437" }

-- (pass 35) STARTER TUTORIAL: brand-new players (no TutorialDone, no XP) are sent (every time they join, until they FINISH it) to their own private
-- server of the tutorial place, learn the basics (Q / E / slide / vault / aim + shoot), and come back here.
-- [SPLIT] 2026-10-16 (notes/place_split.md): three places in this experience, one per kind. 0 = not created yet: that kind
-- still goes to MatchPlaceId (81861384114744, the old combined "tutorial spot / matchmaking test" place). Fill in the ids
-- once the places exist (Creator Hub > the experience > Places).
LobbyConfig.TutorialPlaceId = 118492914954668 -- [SPLIT] Tutorial place (created 2026-10-17)
LobbyConfig.MatchmakingPlaceId = 97339328188402 -- [SPLIT] Matchmaking place (created 2026-10-17)
LobbyConfig.RankedPlaceId = 122908502889013 -- [SPLIT] Ranked place (created 2026-10-17)
-- [SPLIT] the place a kind ("Tutorial" / "Matchmaking" / "Ranked") teleports to: its id, or MatchPlaceId while that id is 0
function LobbyConfig.PlaceIdFor(kind: string): number
	local id = tonumber(LobbyConfig[tostring(kind) .. "PlaceId"]) or 0
	if id > 0 then return id end
	return LobbyConfig.MatchPlaceId
end
LobbyConfig.SendNewPlayersToTutorial = true

-- [PSEUDOLOBBY] the match places' copy also keeps the hub's place id (RoundManager / admin read it)
if LobbyConfig.LobbyPlaceId == nil then LobbyConfig.LobbyPlaceId = 126491009194165 end

return LobbyConfig
