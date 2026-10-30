-- ReplicatedStorage.Modules.Shared.Config.AnimFinalConfig [ANIMFINAL] (2026-10-30, systems session; installed by
-- fix/anim_final_1030.lua, source in fix/anim_final_1030/). Every knob of the final animation pass in one place.
-- Clips are found BY NAME in ReplicatedStorage.Repository.AnimationSources (PublishedId on the source live; the
-- KeyframeSequence itself in Studio). Each logical clip lists candidate names: the first that exists is used. A clip
-- nobody has made yet is simply skipped, so every feature below is off until its clip lands (nothing plays wrong).
local C = {}

C.Enabled = true -- false = the whole pass is off (every hook returns at once; the old behaviour stays)

-- // Clip names --------------------------------------------------------------------------------------------------------
C.Clips = { -- names from notes/anim_style_targets.md (2026-10-30) first, older guesses after
	-- locomotion with a gun (legs + hips; the owner's client plays them; they replicate)
	WalkF = { "MoveRun", "MoveWalkForward" },      -- the gun jog at the 10 studs/s base
	AimF = { "MoveWalkAim" },                       -- aimed walk forward
	WalkB = { "MoveBackpedal", "MoveWalkBack" },
	WalkL = { "MoveStrafeLeft", "MoveWalkLeft" },
	WalkR = { "MoveStrafeRight", "MoveWalkRight" },
	Sprint = { "MoveSprint", "MoveSprintGunLow" },  -- sprint, gun low and canted (keys the arms)
	SprintPistol = { "MoveSprintPistol", "MoveSprint" }, -- one-handed guns (Pistol / Revolver sets)
	Start = { "MoveStart" },
	Stop = { "MoveStop" },
	TurnL = { "TurnInPlaceLeft", "MoveTurnLeft" },
	TurnR = { "TurnInPlaceRight", "MoveTurnRight" },
	LandHard = { "MoveLandHard", "MoveHardLanding" },
	Limp = { "MoveLimp", "MoveWalkLimp" },
	DiveAim = { "DiveAim", "CoverDiveAim", "MoveDiveAim" }, -- author it UPRIGHT: the code pitches the root (aimed: 25% of DivePitch)
	-- hit reactions (own body: own client; bots: every client locally)
	FlinchF = { "HitFlinchF", "HitFlinchFront", "HitFlinch" },
	FlinchB = { "HitFlinchB", "HitFlinchBack", "HitFlinch" },
	FlinchL = { "HitFlinchL", "HitFlinchLeft", "HitFlinch" },
	FlinchR = { "HitFlinchR", "HitFlinchRight", "HitFlinch" },
	HeadSnap = { "HitHeadshot", "HitHeadSnap" },
	Stagger = { "HitExplosionStagger", "HitStagger" },
	Burning = { "HitBurning", "HitBurn" },
	-- deaths (the server plays them, then ragdolls)
	DeathFromFront = { "DeathBackward" },  -- shot from the front: thrown back
	DeathFromBehind = { "DeathForward" },  -- shot from behind: falls face down
	DeathSide = { "DeathCrumple" },        -- from the side
	DeathInCover = { "DeathCover", "DeathCrumple" }, -- in cover (a wall at your back)
	DeathHeadshot = { "DeathHeadshot" },
	DeathExplosion = { "DeathExplosion" },
	DeathAny = { "DeathCrumple", "DeathBackward", "DeathForward" },
	-- life
	Fidgets = { "IdleFidgetShift", "IdleFidgetGunCheck", "IdleFidgetLook", "IdleFidget1", "IdleFidget2" }, -- all that exist
	RoundReady = { "RoundReady" },
	Victory = { "Victory" },
	Defeat = { "Defeat" },
	DoorOpen = { "DoorOpen" },
	Breathing = { "BreatheCalm", "BreathingCalm", "Breathing" },  -- unarmed only (a weapon Hold keys the torso: code breath)
	BreathingHeavy = { "BreatheHeavy", "BreathingHeavy" },
}

-- weapon clips per AnimationSourcePrefix: <Prefix><Base>(Left). Missing in the gun's set -> its AnimationFallbackPrefix.
C.GunExtras = { "Holster", "Draw", "Inspect", "ReloadEmpty", "ReloadTactical", "ReloadStart", "ReloadShell", "ReloadEnd", "ReloadEndEmpty" }
C.GunPrefixes = { -- weapon id -> its own set (the clips fall back to Pistol until the set exists)
	MiniUzi = "SMG", AutoRifle = "Rifle", SemiAuto = "Rifle", PumpShotgun = "Shotgun", Sniper = "Sniper",
}
C.GunFallbackPrefix = "Pistol"

-- melee: per melee id, the swing kinds (the first existing name wins; nil = the config's AnimationSource)
C.Melee = {
	Knife = { Swing = { "MeleeSlash" }, Lunge = { "MeleeKnifeHeavy" }, Backstab = { "MeleeKnifeBackstab" } },
	Fists = { Swing = { "MeleePunch" } },
	Bat = { Swing = { "BatSwing" }, Windup = { "BatChargeWindup" }, ChargeHold = { "BatChargeHold" }, Charged = { "BatSwingCharged" },
		Hold = { "BatHold" }, Equip = { "BatEquip" } },
	Katana = { Swing = { "KatanaSlash" }, Hold = { "KatanaHold" }, Equip = { "KatanaEquip" } },
	RiotShield = { Swing = { "RiotShieldBash" }, Hold = { "RiotShieldHold" }, Impact = { "RiotShieldImpact" }, Break = { "RiotShieldBreak" } },
	Quick = { Swing = { "QuickMeleeBash" } }, -- the gun-butt bash ([F])
}
C.MeleeBackstabRange = 6 -- the knife swing plays the backstab clip when the nearest enemy within this is facing away (the server decides the hit)

-- gadgets: per gadget id, its own throw (fallback: the Smoke set)
C.Gadgets = {
	Frag = { Throw = { "FragThrow" }, ThrowLeft = { "FragThrowLeft" }, Hold = { "FragCook" }, Press = { "FragPinPull" } },
	Flash = { Throw = { "FlashThrow" }, ThrowLeft = { "FlashThrowLeft" }, Roll = { "FlashRoll" }, Hold = { "FlashHold" } },
	Flashbang = { Throw = { "FlashThrow" }, ThrowLeft = { "FlashThrowLeft" }, Roll = { "FlashRoll" }, Hold = { "FlashHold" } },
	StickyGrenade = { Throw = { "StickyThrow", "FragThrow" }, Hold = { "FragCook" } },
	Landmine = { Throw = { "LandminePlace" }, Roll = { "LandminePlace" } }, -- the mine is still thrown (code); the clip plays on the throw
	Medkit = { Use = { "MedkitUse", "MedkitHeal" } },
}

-- // Weapons -------------------------------------------------------------------------------------------------------------
C.Weapon = {
	HolsterWait = true,         -- switching away waits for the Holster clip before the gun leaves the hand
	HolsterMaxWait = 0.45,      -- ...but never longer than this (s); the clip is sped up to fit
	DrawFirstPullOutOnly = true, -- the Draw clip on the first pull-out of a life; later pull-outs use the quick Equip
	InspectKey = Enum.KeyCode.F, -- Inspect key (Settings bind "Inspect" overrides). F is also the gun bash: see InspectNearEnemy
	InspectNearEnemy = 12,      -- with the bash on the same key: an enemy within this many studs -> F bashes, else inspects
	InspectFightLock = 3,       -- no inspect for this long after you fired, were hit, or hit someone (s)
	EmptyReloadClip = true,     -- an empty magazine plays <Prefix>ReloadEmpty (if it exists); otherwise the tactical one
	SprintPose = true,          -- sprinting with the gun out: <Prefix>Sprint (or the body's Sprint clip) instead of Lowered
	ShellClipSpeed = 1,         -- shell-by-shell: the ReloadShell clip is fitted to ShellTime; this scales it
}

-- // Locomotion (own body; its tracks replicate) -------------------------------------------------------------------------
C.Loco = {
	Enabled = true,
	Priority = Enum.AnimationPriority.Movement, -- over Roblox's walk / run (Core); the weapon Hold (Action) keeps the arms
	Authored = { WalkF = 10, AimF = 6, WalkB = 7.5, WalkL = 10, WalkR = 10, Sprint = 20, SprintPistol = 20, Limp = 8 }, -- studs/s at 1x
	SprintSpeed = 17,   -- at or over this with the sprint on: the sprint clip (it keys the arms: the gun goes low)
	MinMoveSpeed = 0.6, -- below this you are standing still
	BlendRate = 10,     -- weights move toward their target this fast (per s)
	StopMinSpeed = 8,   -- the Stop clip plays when you stop from at least this speed
	TurnInPlaceAngle = 55, -- standing still, the body turning this many degrees within TurnWindow plays a turn clip
	TurnWindow = 0.35,
	HardLandSpeed = 45, -- a landing from a fall faster than this (studs/s) plays MoveLandHard (look only: speed unchanged)
	LimpHealth = 40,    -- HP at or below which you limp (MatchConfig.PlayerHealth is 150)
	LimpWeight = 0.85,
	OffWhileInCover = true, -- cover moves own the legs in cover
}

-- // Life --------------------------------------------------------------------------------------------------------------
C.Life = {
	FidgetAfter = 6,      -- seconds standing still (no input, no aim) before an idle fidget
	FidgetEvery = { 7, 12 }, -- then one every this many seconds (random in the range)
	BeatClips = true,     -- RoundReady / Victory / Defeat at the match beats
	DiveAim = true,       -- the DiveAim clip while aiming in the airborne part of a dive
}

-- // Hit reactions -------------------------------------------------------------------------------------------------------
C.Hits = {
	Enabled = true,
	Priority = Enum.AnimationPriority.Action3, -- reactions key the torso + neck only, so the gun keeps working
	FlinchCooldown = 0.18, -- s between two flinches on one body
	HeadRadius = 1.2,      -- a hit this close to the head centre plays the headshot snap
	HeadSnapWeight = 1,
	StaggerMinDamage = 20, -- an explosion hit of at least this much staggers
	StaggerKinds = { Frag = true, Blast = true, Explosion = true, Barrel = true, Sticky = true, StickyGrenade = true, Landmine = true, Mine = true },
	BurnWeight = 0.8,
}

-- // Deaths (server) ----------------------------------------------------------------------------------------------------
C.Death = {
	Enabled = true,
	-- the death clip plays, then the ragdoll takes over at the clip's ground contact (its `Ground` / `Ragdoll` marker, in s);
	-- a clip not listed: RagdollDelay. 0 = ragdoll at once (the old behaviour)
	RagdollAt = { DeathForward = 0.67, DeathBackward = 0.6, DeathCrumple = 0.83, DeathHeadshot = 0.5, DeathExplosion = 0.2 },
	RagdollDelay = 0.6,
	MaxDelay = 1.2,
	SideAngle = 50,      -- degrees off the front / back beyond which a hit counts as from the side
	FadeIn = 0.05,
	Bots = true,         -- bots die the same way
}

-- // Breathing (procedural, every client draws every body) --------------------------------------------------------------
C.Breath = {
	Enabled = true,
	CalmRate = 0.22,      -- breaths per second at rest
	HeavyRate = 0.75,     -- ...when fully out of breath
	CalmChest = 0.9,      -- degrees of chest rise (waist pitch) at rest
	HeavyChest = 3.2,     -- ...out of breath
	CalmShoulder = 0.025, -- studs of shoulder rise at rest
	HeavyShoulder = 0.09,
	StaminaFull = 100,    -- MovementConfig.Stamina.Max
	ExertGainSprint = 0.12, -- exertion (0..1) gained per second while sprinting
	ExertGainBurst = 0.35,  -- added at once by a dash, a vault, a climb or a slide
	SettleTime = 4,       -- seconds for a full exertion to settle back to calm
	SprintSpeed = 16,     -- other bodies: a flat speed over this counts as sprinting (their stamina is theirs)
	BurstSpeed = 24,      -- ...and over this as a burst (dash / slide / dive)
	LayerPriority = Enum.AnimationPriority.Idle, -- the animator's BreatheCalm / BreatheHeavy (unarmed only: a Hold keys the torso)
	LayerWeightCalm = 0.35, -- the Breathing layer (own body, replicates) at rest...
	LayerWeightHeavy = 1,   -- ...and out of breath
	ProceduralWithLayer = 0.35, -- when the layer clip plays, the procedural rise is scaled by this
	SwayDegrees = 0.18,   -- aim sway (camera) at full exertion while aiming, degrees
	SwayCalm = 0.02,      -- ...at rest
	SoundId = "",         -- out-of-breath sound (an owned asset id; "" = off)
	SoundVolume = 0.18,
	SoundFrom = 0.55,     -- exertion over this plays it
	SoundMaxDistance = 14, -- studs: other players hear it only this close (no AI noise event: it is not a noise)
	MaxBodies = 12,       -- nearest bodies drawn per frame
	MaxDistance = 80,     -- studs from the camera
}

return C
