	-- [SMOKEALARM] 2026-10-28 shootable ceiling smoke alarms (models with Shootable = "SmokeAlarm"; fix/smoke_alarm.lua,
	-- notes/smoke_alarm.md; the rules: Shared.SmokeAlarm). A quiet low-battery chirp every ChirpMin..ChirpMax seconds (random per
	-- alarm); the first bullet, melee swing or blast sets it blaring for BlareTime seconds, which masks footsteps and reloads
	-- within MaskRadius on its floor for players and the AI (like a steam valve; gunshots and fire stay audible); then it's
	-- broken and silent until the round resets.
	SmokeAlarm = {
		Enabled = true,          -- false: alarms are plain props (no chirp, can't be shot out)
		ChirpMin = 25,           -- seconds between chirps (random per alarm, every gap)
		ChirpMax = 40,
		ChirpVolume = 0.16,      -- quiet: a location cue (heard to ~45 studs), not an annoyance
		BlareTime = 7,           -- seconds it blares once shot
		BlareVolume = 0.75,
		MaskRadius = 28,         -- studs (flat) around the alarm where footsteps / reloads are masked while it blares
		MaskBelow = 16,          -- ... from this far below the alarm (its own floor) ...
		MaskAbove = 2,           -- ... to this far above it (never the floor upstairs)
		ListenerInBlare = true,  -- standing in the blare you can't hear people either (the steam's rule)
		HitPadding = 0.3,        -- studs around the alarm for the bullet test
		BlastScale = 1,          -- a blast breaks alarms within its Radius x this, with no wall in between
	},
