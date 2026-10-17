-- ReplicatedStorage/Modules/Shared/Config/MatchConfig (ModuleScript)
-- Match rules. Times in seconds. [DUEL] lobby copy = the match place's MatchConfig (pass 38 superset) + the lobby duel keys
-- at the bottom (lobby duels phase 1, 2026-10-16; original lobby copy in ServerStorage._RebuildRemoved.DUEL_MatchConfig_Orig).
return {
	TestMode = true,        -- match place test servers only; ignored by lobby duels.
	PlayerHealth = 150,     -- everyone's max health in a match (lobby duels set it on every round spawn)
	RoundsToWin = 3,        -- best of 5
	CountdownTime = 3,      -- frozen at spawn before each round
	RoundTime = 90,         -- round timer; on timeout the player with more health wins (tie = draw)
	RoundEndDelay = 3,      -- pause after a round before the next countdown
	MatchEndDelay = 6,      -- pause after a match before the rematch starts
	WaitingRespawnTime = 3, -- respawn delay while waiting for an opponent (free practice)
	SpawnFolderName = "MatchSpawns", -- match place: Workspace folder with parts named SpawnA and SpawnB
	LobbyPlaceId = 126491009194165,
	ArrivalTimeout = 30,
	ResultsTime = 12,       -- results screen
	MaxRounds = 9,          -- safety cap (endless draws)
	StartingRating = 1000,
	Rewards = {             -- per match; scissors are multiplied by 2X SCISSORS (x2) and VIP (x1.25)
		XPMatch = 100, XPKill = 50, XPWin = 150,
		ScissorsMatch = 25, ScissorsKill = 10, ScissorsWin = 50,
		GunXPMatch = 50, GunXPKill = 25,
		RankedK = 32,
	},

	-- [DUEL] lobby pad duels (in-lobby matches on an arena slot; notes/lobby_duels_design.md)
	PadDuelsInLobby = true, -- false = the pads teleport to the match place as before
	DuelMapVote = true,     -- false = skip the vote (first eligible map)
	LoadingTime = 3,
	MapVoteTime = 10,
	LoadoutTime = 15,       -- ends early when everyone is Ready and Loaded
	LoadedGrace = 5,        -- extra time for a client that hasn't loaded the arena, then it counts as left
	MaxArenas = 6,          -- concurrent in-lobby matches (lead default, Edward may change)
	ArenaBaseX = 4000,      -- slot n origin = (ArenaBaseX + spacing * (n - 1), ArenaY, 0); spacing from MapRegistry
	ArenaY = 100,
	DuelRanked = false,     -- pad duels are casual only (lead default, Edward may change)
	DuelRewardCooldown = 600, -- one reward per opponent pair per 10 minutes (anti-farming; lead default)
	ReturnFade = 1,

	-- [MATCH] the match place (notes/match_place_flow.md): Loading waits for every client's "Loaded", then a short Intro
	MatchLoadTimeout = 60,  -- safety: start with whoever is present (a team with nobody = cancelled, no rewards)
	IntroTime = 2.5,        -- the logo crumble between Loading and MapVote
}
