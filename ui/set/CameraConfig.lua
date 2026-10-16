-- ReplicatedStorage/Modules/Shared/Config/CameraConfig (ModuleScript)
-- Every tunable value for the over-the-shoulder camera. Tweak here, not in the controller.
-- Distances are in studs, angles in degrees, speeds are smoothing rates (higher = snappier).

return {
	-- Mouse look
	Sensitivity = 0.3,               -- degrees of rotation per pixel of mouse movement
	AimSensitivityMultiplier = 0.6,  -- slower look while aiming, for precision
	InvertY = false,
	PitchMin = -75,                  -- how far down you can look
	PitchMax = 75,                   -- how far up you can look

	-- Where the camera orbits around: this far above the HumanoidRootPart (roughly neck height)
	PivotHeight = 1.5,

	-- Hip (not aiming): GTA-style wide view
	Hip = {
		Distance = 8,         -- behind the shoulder
		ShoulderOffset = 2.5, -- to the side
		HeightOffset = 0.6,   -- above the pivot
		FOV = 70,
	},

	-- Aiming: tighter, closer over the shoulder
	Aim = {
		Distance = 5.5,
		ShoulderOffset = 2.4,
		HeightOffset = 0.6,
		FOV = 55,
	},

	AimTransitionSpeed = 14, -- how fast hip <-> aim blends
	ShoulderSwapSpeed = 9,   -- how fast the camera slides to the other shoulder

	-- Smoothness. The camera rides a spring that follows your velocity, so it never lags behind while
	-- you run but soaks up every snap (sliding into cover, rounding a corner, landing a vault) instead
	-- of jerking with it. It also hides the 60Hz physics step on high refresh-rate screens.
	PivotFollow = 16,        -- sideways/forward catch-up (higher = tighter)
	PivotInertia = 12,       -- how quickly the camera picks up / sheds your speed (lower = more weight)
	PivotFollowY = 9,        -- up/down catch-up (softer: absorbs crouches, hops, vault arcs)
	CrouchDrop = 0.9,        -- the camera sinks this much while you're crouched (cover or on foot)
	CollisionReturnSpeed = 5, -- after a wall pushed the camera in, how gently it slides back out
	AimTurnRate = 1000,      -- degrees/second: turning your body to face where you aim (no instant snap)
	BodyTurnRate = 720,      -- degrees/second: on foot, turning to face a new direction (Roblox's own turn is near-instant)
	DefaultShoulder = 1,     -- 1 = right shoulder, -1 = left

	-- Camera collision: the camera is pushed in front of walls instead of clipping through them
	CollisionRadius = 0.35,
	CollisionPadding = 0.1,

	-- Your own character fades out when the camera is pushed very close to it
	FadeStartDistance = 2.5,
	FadeEndDistance = 1.0,

	-- Aim point raycast length (used by weapons)
	MaxAimDistance = 500,

	-- Death camera (GTA "wasted" style, no effects): pulls back and up over your body, slowly circling
	DeathCamDistance = 13,
	DeathCamHeight = 9,
	DeathCamOrbitSpeed = 0.12, -- radians per second
	DeathCamEaseSpeed = 0.7,   -- how quickly it pulls back

	Keybinds = {
		Aim = Enum.UserInputType.MouseButton2,
		ShoulderSwap = Enum.KeyCode.V,
	},
}
