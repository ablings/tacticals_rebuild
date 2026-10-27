		-- [STEAMFILL] 2026-10-27 maps whose model carries the attribute SteamFill = true (Warehouse 2): the valve STEAMS THE ROOM UP.
		-- Same hiss + jet, then a cloud billows out of the valve and fills the room (drawn on each client of the match from the
		-- valve's SteamAt / SteamUntil), thick at the valve, a light haze across the room. The noise mask grows with it and
		-- ends when it has faded. Maps without the attribute (the Warehouse, the tutorial) keep the classic jet above.
		Fill = {
			Enabled = true,          -- false: every map plays the classic jet
			Duration = 7,            -- seconds of hissing on a fill map (the cloud holds this long)
			GrowTime = 3,            -- seconds for the cloud to billow out to the walls
			FadeTime = 3,            -- seconds for it to thin away after the hiss stops (the mask ends with it)
			Radius = 30,             -- studs: how far the haze spreads from the valve (walls stop it sooner)
			MaskStartRadius = 8,     -- studs masked the moment it's shot (the jet's own cloud)
			MaskRadius = 30,         -- studs masked once the cloud is full (footsteps + reloads; players and AI)
			MaskHeight = 14,         -- only up to this far above the valve's floor (a floor above stays audible)
			MaskEdge = 2,            -- studs of slack past the cloud's edge at a wall (someone hugging the wall is covered)
			-- the cloud's shape: rays from just in front of the valve; a hit on a long part stops the steam, cover doesn't
			CentreOut = 3,           -- studs out from the valve to the cloud's centre
			FanHeight = 6,           -- the rays run this high above the floor (over low cover)
			FanRays = 24,
			WallMinLength = 16,      -- a part at least this long (flat) is a wall; shorter (crates, pillars) the steam rolls round
			WallPad = 1,
			-- look
			Color = Color3.fromRGB(205, 210, 215),
			LightInfluence = 1,       -- lit by the room only (no glow of its own in a dark warehouse)
			ScreenWash = 0.45,       -- standing inside it greys the picture a little (0 = off)
			-- round 3 (Edward 2026-10-27): the AI is blinded by the steam, and footsteps in, near or through it are muddied to very faint
			Sight = {
				BlindDepth = 6,      -- studs of steam a bot's sight line may cross before it can't see (a player 6+ studs into the haze is hidden)
				CoreRadius = 9,      -- studs around the cloud's centre that count as the thick core
				CoreWeight = 3,      -- a stud of core counts this much (the valve corner blinds after 2 studs)
				Step = 1,            -- studs between samples along the sight line
			},
			Footsteps = {
				ListenerInSteam = true, -- standing in the steam you can't hear people either (false: only steps IN or THROUGH it)
				ThroughDepth = 6,    -- steps on the far side of this much steam (weighted like Sight) are muffled too (0 = off)
				Volume = 0.06,       -- other people's muffled steps: x this (very faint; you can't place them)
				OwnVolume = 0.5,     -- your own steps in the steam: x this, muffled
				HighGain = -40, MidGain = -18, LowGain = -2, -- the muffle (EqualizerSoundEffect, dB): steam swallows the crisp part
			},
			-- mobile-safe: Particles = how many puffs are alive at once (Low: touch-only devices, saved graphics quality
			-- 1..LowQualityAt, or < 40 fps). Low draws fewer, bigger, denser puffs so the valve corner hides just as well.
			LowQualityAt = 4,
			Quality = {
				High = {
					Particles = 170,
					Core = { BillowShare = 0.24, PoolShare = 0.22, Size = { 7, 12 }, Alpha = 0.42 },
					Haze = { Directions = 12, Rings = { 0.4, 0.8 }, Heights = { 4, 8 }, MinDistance = 4, Size = { 16, 26 }, Alpha = { 0.76, 0.87 } },
				},
				Low = {
					Particles = 60,
					Core = { BillowShare = 0.25, PoolShare = 0.28, Size = { 9, 15 }, Alpha = 0.32 },
					Haze = { Directions = 6, Rings = { 0.55 }, Heights = { 5 }, MinDistance = 4, Size = { 20, 30 }, Alpha = { 0.78 } },
				},
			},
		},
