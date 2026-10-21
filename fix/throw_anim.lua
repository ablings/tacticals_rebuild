-- fix/throw_anim.lua [THROWANIM] 2026-10-21 (Edward via the main PC: "I want the throwing to feel like how the RIVALS grenade is thrown":
-- an overhand - the off arm points forward at the aim, the throwing arm cocks back past the head, then whips forward and drops in a
-- follow-through). Rebuilds the gadget KeyframeSequences in ReplicatedStorage.Repository.AnimationSources, same pose tree / priority
-- (Action4) as before; the gun stays in the right hand, so the normal throw is LEFT-handed and SmokeThrowLeft is its mirror:
--   SmokeHold  (loop)  cocked: torso twisted back, throwing arm high behind the head, gun arm forward at the aim
--   SmokeThrow         wind -> whip (peak at 0.16 s = the release: GadgetConfig ThrowReleaseDelay 0.12 x AnimSpeed 1.3) ->
--                      follow-through (arm drops across the body, torso leans in) -> back to rest
--   SmokeThrowLeft     the mirror (right-hand throw around the left side of cover)
-- Conventions checked on posed R15 dummies (fix/climb.lua): UpperArm +X raises the arm forward / up (180 = straight up), UpperTorso
-- +X leans forward, Y twists. An existing PublishedId is KEPT (live keeps the old upload until Edward re-uploads these under gunsy funsy
-- and sets the new ids). Both places. Idempotent; UNDO = true restores the previous keyframes (kept in ServerStorage._ThrowAnimUndo).
local UNDO = false --@UNDO
local SRC = game:GetService("ReplicatedStorage").Repository.AnimationSources
local SS = game:GetService("ServerStorage")

local HOLD = { UpperTorso = { 0, 28, 0 }, LeftUpperArm = { 175, 0, -28 }, LeftLowerArm = { 105, 0, 0 }, LeftHand = { 25, 0, 0 },
	RightUpperArm = { 85, 0, 12 }, RightLowerArm = { 8, 0, 0 } }
local DEFS = {
	SmokeHold = { loop = true, keys = { { 0, HOLD }, { 1, HOLD } } },
	SmokeThrow = { loop = false, keys = {
		{ 0.00, HOLD },
		{ 0.08, { UpperTorso = { 6, 8, 0 }, LeftUpperArm = { 150, 0, -18 }, LeftLowerArm = { 70, 0, 0 }, LeftHand = { 10, 0, 0 },
			RightUpperArm = { 70, 0, 12 }, RightLowerArm = { 10, 0, 0 } } },
		{ 0.16, { UpperTorso = { 14, -24, 0 }, LeftUpperArm = { 85, 0, 4 }, LeftLowerArm = { 12, 0, 0 }, LeftHand = { -18, 0, 0 },
			RightUpperArm = { 40, 0, 10 }, RightLowerArm = { 15, 0, 0 } } },
		{ 0.30, { UpperTorso = { 12, -22, 0 }, LeftUpperArm = { 22, 0, 14 }, LeftLowerArm = { 28, 0, 0 }, LeftHand = { -8, 0, 0 },
			RightUpperArm = { 30, 0, 8 }, RightLowerArm = { 12, 0, 0 } } },
		{ 0.50, {} },
	} },
}
DEFS.SmokeThrowLeft = { loop = false, mirrorOf = "SmokeThrow" }

local function mirror(name: string): string
	if name:sub(1, 4) == "Left" then return "Right" .. name:sub(5) end
	if name:sub(1, 5) == "Right" then return "Left" .. name:sub(6) end
	return name
end

local function build(name: string, def): KeyframeSequence
	local src = def.mirrorOf and DEFS[def.mirrorOf] or def
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = def.loop
	ks.Priority = Enum.AnimationPriority.Action4
	for _, key in src.keys do
		local joints = {}
		for joint, e in key[2] do
			if def.mirrorOf then joints[mirror(joint)] = { e[1], -e[2], -e[3] } else joints[joint] = e end
		end
		local kf = Instance.new("Keyframe")
		kf.Time = key[1]
		local function pose(nameP, parent)
			local p = Instance.new("Pose")
			p.Name = nameP
			local e = joints[nameP]
			if e then p.CFrame = CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3])) end
			p.Parent = parent
			return p
		end
		local upper = pose("UpperTorso", pose("LowerTorso", pose("HumanoidRootPart", kf)))
		pose("Head", upper)
		for _, side in { "Left", "Right" } do pose(side .. "Hand", pose(side .. "LowerArm", pose(side .. "UpperArm", upper))) end
		kf.Parent = ks
	end
	return ks
end

local stash = SS:FindFirstChild("_ThrowAnimUndo")
local log = {}
for _, name in { "SmokeHold", "SmokeThrow", "SmokeThrowLeft" } do
	local cur = SRC:FindFirstChild(name)
	if UNDO then
		local old = stash and stash:FindFirstChild(name)
		if old then
			if cur then cur:Destroy() end
			old.Parent = SRC
			table.insert(log, "restored " .. name)
		end
	elseif cur and cur:GetAttribute("ThrowAnim") then
		table.insert(log, name .. " =")
	else
		if not stash then stash = Instance.new("Folder") stash.Name = "_ThrowAnimUndo" stash.Parent = SS end
		local keepId = cur and cur:GetAttribute("PublishedId")
		if cur then cur.Parent = stash end
		local ks = build(name, DEFS[name])
		ks:SetAttribute("ThrowAnim", true)
		if keepId then ks:SetAttribute("PublishedId", keepId) end
		ks.Parent = SRC
		table.insert(log, name .. (keepId and " (kept " .. keepId .. ")" or ""))
	end
end
if UNDO and stash and #stash:GetChildren() == 0 then stash:Destroy() end
return (UNDO and "UNDO " or "THROWANIM ") .. table.concat(log, ", ")
