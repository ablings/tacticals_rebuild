-- ReplicatedStorage/Modules/Shared/Config/MoveFeelConfig (ModuleScript) [MOVEFEEL] (2026-10-30, systems session; installed by
-- fix/move_feel_1030.lua, source fix/move_feel_1030/MoveFeelConfig.lua)
-- Every number of the movement feel pass. Look only: gameplay speeds (MovementConfig.Speeds), cover / vault / dive timings and
-- the server's checks are unchanged. Each block has its own Enabled switch; Enabled = false at the top turns the whole pass off.
-- Reduced motion = the existing Settings > Video "Camera Shake" (Setting_CameraShake = false): bob, dip, roll and FOV kicks off.

return {
	Enabled = true,

	-- // Momentum: your move input eases in and out instead of switching on / off in one frame (own body only)
	Momentum = {
		Enabled = true,
		AccelTime = 0.11,      -- s from standing to full input (Roblox's own: ~1 frame)
		DecelTime = 0.08,      -- s from full input to standing (stop distance at sprint +0.8 studs)
		TurnRateWalk = 900,    -- deg/s the move direction can swing at walk speed...
		TurnRateSprint = 420,  -- ...and at sprint speed (turn rate tied to speed: a sprint corners wider)
		ReverseAngle = 120,    -- a direction change wider than this brakes through standing (decel, then accel)
		WalkSpeed = 10, SprintSpeed = 20, -- the speeds the two turn rates belong to (MovementConfig.Speeds)
	},

	-- // Body lean into acceleration and turns (every body, drawn by each client; Transform never replicates)
	Lean = {
		Enabled = true,
		PitchPerAccel = 0.045,  -- deg of forward lean per stud/s^2 of forward acceleration (braking leans back)
		MaxPitchForward = 5,
		MaxPitchBack = 3,
		RollPerAccel = 0.06,    -- deg of roll into a turn per stud/s^2 of sideways (centripetal) acceleration
		MaxRoll = 5,
		Sharpness = 9,          -- how fast the lean follows (1/s); remote bodies use RemoteSharpness (their velocity is noisier)
		RemoteSharpness = 6,
		AccelFilter = 14,       -- low-pass on the measured acceleration (1/s)
		AimKeep = 0,            -- share of the lean kept while the gun is raised (0: the muzzle stays on line)
		MaxDistance = 120,      -- studs from the camera
		MaxBodies = 12,
	},

	-- // Feet: hips drop and each foot reaches its own ground on stairs and slopes (IK), standing or slow
	Feet = {
		Enabled = true,
		MaxSpeed = 3,           -- studs/s: over this the walk clip owns the feet (weight fades out)
		MinDrop = 0.08,         -- ground differences under this are ignored (flat floor costs nothing)
		MaxDrop = 0.9,          -- the most the hips sink to reach the lower foot's ground
		FootHeight = 0.12,      -- ankle-to-sole height (R15 foot)
		Sharpness = 14,         -- weight / drop smoothing (1/s)
		RayUp = 1.6, RayDown = 2.6,
		MaxDistance = 60,
		MaxBodies = 6,
	},

	-- // Camera (your own, a post-process undone each frame)
	Camera = {
		Enabled = true,
		StrideLength = 3.1,     -- studs per step (one bob per step)
		BobWalk = 0.035,        -- studs of vertical bob at walk speed...
		BobSprint = 0.075,      -- ...and at sprint speed
		BobCrouch = 0.02,
		BobRollSprint = 0.35,   -- deg of roll per step while sprinting
		BobAimKeep = 0.25,      -- share of the bob kept while aiming (0 while scoped)
		LandDipPerSpeed = 0.012, -- studs of dip per stud/s of landing speed
		LandDipMax = 0.35,
		LandPitchPerSpeed = 0.035, -- deg of nod down per stud/s of landing speed
		LandPitchMax = 1.2,
		LandMinSpeed = 14,      -- softer landings don't dip
		DipFrequency = 11,      -- spring omega (1/s)
		DipDamping = 0.8,       -- spring damping ratio (no wobble)
		SprintFOV = 4,          -- deg added while sprinting...
		SlideFOV = 5,           -- ...sliding...
		DiveFOV = 4,            -- ...diving
		FOVSharpness = 6,       -- FOV ease (1/s)
		SlideDrop = 0.35,       -- studs the camera sinks in a slide
		SlideRoll = 2,          -- deg of roll in a slide, toward the camera's side
		DiveRoll = 3,           -- deg of roll in a dive, by its sideways direction
		ShapeSharpness = 10,    -- drop / roll ease (1/s)
	},

	-- // Input buffering (own body): a press a moment early still happens, no dead frames between chained moves
	Buffer = {
		Enabled = true,
		Slide = 0.2,            -- s: Crouch / Slide pressed just before the sprint reaches speed still slides
		AirJump = 0.18,         -- s: Space pressed just before landing replays on touchdown (vault / climb / pull-up / hop)
		AfterVault = 0.35,      -- s: Space pressed mid-vault replays as a climb / pull-up on landing
	},

	-- // Fades between body states (seconds); the old hard-coded values in brackets
	Fades = {
		CrouchPose = 0.18,      -- MovementController crouch idle / walk / slide in and out (0.2)
		SlideOut = 0.22,        -- the slide pose back to standing (0.2)
		MoveIn = 0.12,          -- CoverController's move clips (vault, pull-up, climb, dash, roll, dive) fading in (0.08)
	},

	-- // Which clips own the legs. Every gun clip (Hold / Lowered at Action; Fire / Reload / Draw / Inspect / Holster at Action4)
	-- keys the legs in a fixed pose, so a walk below them (Movement) slid the frozen legs across the floor. The walk / strafe /
	-- backpedal / sprint / limp loops (AnimFinalConfig.Loco) and the crouch idle / walk play here instead, over Hold / Lowered.
	-- (The Action4 gun clips still freeze the legs while they play: the clips need re-exporting without leg keys.)
	LocoPriority = "Action2",

	-- // Measured locomotion speeds (studs/s at 1x) for AnimFinalConfig.Loco.Authored: playback speed = velocity / this, so the
	-- planted foot stays planted (foot drift per step measured in Studio, notes/move_feel_1030.md). nil = keep theirs.
	-- Measured 2026-10-30 (pistol, 12.5 studs/s walk, 25 sprint): slip per step was F +0.09, B +0.30, R +0.16, L +0.37,
	-- sprint +0.32 with their values (10 / 7.5 / 10 / 10 / 20); now within +-0.10. AimF and Limp not measured (kept).
	LocoAuthored = { WalkF = 9.1, WalkB = 5.6, WalkL = 6.9, WalkR = 8.4, Sprint = 15.5, SprintPistol = 15.5 },

	-- // Remote bodies: no extra smoothing of position (Roblox interpolates replicated physics); the lean above uses
	-- RemoteSharpness so their replicated velocity noise never shows as a wobble.
}
