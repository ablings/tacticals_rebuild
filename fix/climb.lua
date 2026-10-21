-- fix/climb.lua [CLIMB] 2026-10-21, Edward in the Shadow PC lead chat:
--  "on vaultable objects lets say an object is very wide it shouldn't default to a vault with spacebar it should be a climb
--   animation instead to get ontop of it this can also work on taller objects aswell if your head is over the object" /
--  "if the object is too long instead of vaulting a really long object it climbs ontop of it"
-- The climb itself lives in ui/set/CoverController.lua ([CLIMB]: startClimb / climbSpot, deployed by ui/deploy_ui.py). This
-- script adds what the place needs for it:
--  1. CoverConfig.MoveAnimations.Climb = "" (+ ClimbMinDepth / ClimbMaxAboveRoot / ClimbTime tunables).
--  2. ReplicatedStorage.Repository.AnimationSources.CoverClimb: a KeyframeSequence (1 s, sped to the climb's length): reach up,
--     pull with a knee up onto the edge, push over the top, step up and stand. Same pose tree / conventions as CoverVault
--     (UpperLeg +X = knee up, LowerLeg -X = knee bend, LowerTorso / UpperTorso +X = lean forward, Head -X = look up;
--     checked on posed R15 dummies). Live needs the group upload: after
--     "Save to Roblox" (Gunsy Funsy) set attribute PublishedId = "rbxassetid://<id>"; a rebuild keeps an existing PublishedId.
-- Both places. Idempotent; UNDO = true removes both.
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local res = {}

-- 1. config
local cfg = RS.Modules.Shared.Config.CoverConfig
do
	local s = cfg.Source
	local OLD = "\t\tVault = \"\", -- vault over low cover (one shot)\n\t},\n"
	local NEW = "\t\tVault = \"\", -- vault over low cover (one shot)\n"
		.. "\t\tClimb = \"\", -- [CLIMB] climb on top of deep / head-high cover (one shot)\n\t},\n"
		.. "\t-- [CLIMB] Space climbs instead of vaulting: cover deeper than ClimbMinDepth (studs), or a wall whose top is at most\n"
		.. "\t-- ClimbMaxAboveRoot above the root (under the top of the head); ClimbTime + 0.06 s per stud of rise\n"
		.. "\tClimbMinDepth = 5,\n\tClimbMaxAboveRoot = 2.6,\n\tClimbTime = 0.62,\n"
	if UNDO then OLD, NEW = NEW, OLD end
	if s:find(NEW, 1, true) then table.insert(res, "config =")
	else
		local a, b = s:find(OLD, 1, true)
		assert(a, "CoverConfig anchor not found")
		s = s:sub(1, a - 1) .. NEW .. s:sub(b + 1)
		assert(loadstring(s), "CoverConfig would not parse")
		cfg.Source = s
		table.insert(res, "config +")
	end
end

-- 2. the animation
local SRC = RS.Repository.AnimationSources
local KEYS = {
	{ 0.00, { LowerTorso = { 20, 0, 0, -0.4 }, UpperTorso = { 10, 0, 0 }, Head = { -25, 0, 0 },
		LeftUpperArm = { 140, 0, -8 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 140, 0, 8 }, RightLowerArm = { 10, 0, 0 },
		LeftUpperLeg = { 30, 0, 0 }, LeftLowerLeg = { -45, 0, 0 }, RightUpperLeg = { 30, 0, 0 }, RightLowerLeg = { -45, 0, 0 } } },
	{ 0.28, { LowerTorso = { 15, 0, 0, -0.2 }, UpperTorso = { 25, 0, 0 }, Head = { -25, 0, 0 },
		LeftUpperArm = { 120, 0, -10 }, LeftLowerArm = { 80, 0, 0 }, RightUpperArm = { 120, 0, 10 }, RightLowerArm = { 80, 0, 0 },
		LeftUpperLeg = { 10, 0, 0 }, LeftLowerLeg = { -30, 0, 0 }, RightUpperLeg = { 95, 0, 0 }, RightLowerLeg = { -100, 0, 0 } } },
	{ 0.52, { LowerTorso = { 30, 0, 0, -0.3 }, UpperTorso = { 20, 0, 0 }, Head = { -20, 0, 0 },
		LeftUpperArm = { 35, 0, -15 }, LeftLowerArm = { 25, 0, 0 }, RightUpperArm = { 35, 0, 15 }, RightLowerArm = { 25, 0, 0 },
		LeftUpperLeg = { -15, 0, 0 }, LeftLowerLeg = { -60, 0, 0 }, RightUpperLeg = { 85, 0, 0 }, RightLowerLeg = { -90, 0, 0 } } },
	{ 0.76, { LowerTorso = { 10, 0, 0, -0.1 }, UpperTorso = { 5, 0, 0 }, Head = { -5, 0, 0 },
		LeftUpperArm = { 10, 0, -10 }, LeftLowerArm = { 15, 0, 0 }, RightUpperArm = { 10, 0, 10 }, RightLowerArm = { 15, 0, 0 },
		LeftUpperLeg = { 40, 0, 0 }, LeftLowerLeg = { -70, 0, 0 }, RightUpperLeg = { 40, 0, 0 }, RightLowerLeg = { -40, 0, 0 } } },
	{ 1.00, {} },
}

local function build(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "CoverClimb"
	ks.Loop = false
	ks.Priority = Enum.AnimationPriority.Action4 -- like CoverVault (over the weapon hold poses)
	for _, key in KEYS do
		local kf = Instance.new("Keyframe")
		kf.Time = key[1]
		local function pose(name, parent)
			local p = Instance.new("Pose")
			p.Name = name
			local e = key[2][name]
			if e then p.CFrame = CFrame.new(0, e[4] or 0, 0) * CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3])) end
			p.Parent = parent
			return p
		end
		local root = pose("HumanoidRootPart", kf)
		local lower = pose("LowerTorso", root)
		local upper = pose("UpperTorso", lower)
		pose("Head", upper)
		for _, side in { "Left", "Right" } do
			pose(side .. "Hand", pose(side .. "LowerArm", pose(side .. "UpperArm", upper)))
			pose(side .. "Foot", pose(side .. "LowerLeg", pose(side .. "UpperLeg", lower)))
		end
		kf.Parent = ks
	end
	return ks
end

local old = SRC:FindFirstChild("CoverClimb")
local keepId = old and old:GetAttribute("PublishedId")
if old then old:Destroy() end
if UNDO then
	table.insert(res, "removed CoverClimb")
else
	local ks = build()
	if keepId then ks:SetAttribute("PublishedId", keepId) end
	ks.Parent = SRC
	table.insert(res, "CoverClimb" .. (keepId and (" (kept " .. keepId .. ")") or " (no PublishedId: Studio preview only)"))
end
return (UNDO and "UNDO " or "CLIMB ") .. table.concat(res, " | ")
