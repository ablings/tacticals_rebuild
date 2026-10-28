
	-- [GLASS] breakable window glass (fix/breakable_glass.lua, notes/breakable_glass.md; the rules: Shared.Openings).
	-- A window = a model with the attribute Shootable = "Glass" holding a Glass part (and an optional BrokenGlass look). Bullets,
	-- melee and blasts pass through it and the hit lands behind it; the first one breaks it (reset every round). The opening stays
	-- shut to players by a part tagged WindowBarrier (invisible, ignored by every ray).
	Glass = {
		Enabled = true,          -- false: panes never break (bullets still pass through)
		HitPadding = 0.1,        -- studs around a pane for the bullet test
		MeleeReach = 1.5,        -- a swing reaches a pane this much further than a body (panes sit in a wall)
		BlastScale = 1,          -- a blast breaks panes within its Radius x this, with no wall in between
		NoiseRadius = 50,        -- the AI hears a pane break this far away (match places)
		Shards = 18,             -- falling shards per window (client)
		ShardLife = 2.5,         -- seconds a shard lives
		ShatterWindow = 1.5,     -- clients play the shatter only for a break this recent (late joiners see it broken)
		SoundVolume = 1.3,       -- x the Glass impact sounds (ImpactSounds)
		SoundPitch = 0.8,        -- a big pane sounds lower than a bottle
		BarrierGroup = "WindowBarrier",
		CharacterGroups = { "Characters", "DuelQueued" }, -- the collision groups a barrier blocks (players and the AI)
	},
