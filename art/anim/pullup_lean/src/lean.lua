--@lib
-- Builds CoverLeanLeft/Right (+Crouch). Hips roll over the root joint (which sits at hip height), legs solved so feet stay planted.
local ROLL = 7       -- degrees of roll at the hips (root joint)
local WAIST = 9      -- degrees of roll at the waist: total torso roll 16 deg out over the hip
local CHEST = Vector3.new(0.12, 0.08, 0) -- chest slides out (x, mirrored) and lifts at the waist so the gun arm doesn't dive
local SHIFT = 0.12   -- studs, hips slide out
local DROP = 0.04    -- studs, small sink into the lean
local BREATH = 0.8   -- degrees of extra roll at the middle of the loop (moving hold)
local LEN = 1.2      -- loop length

local SRC = game.ReplicatedStorage.Repository.AnimationSources
local function poseOf(ksName, joint)
	local kf = SRC[ksName]:GetKeyframes()[1]
	local p = kf:FindFirstChild(joint, true)
	return p and p.CFrame or CFrame.identity
end
local BASES = {
	-- ready stance: hips sink 0.16 with soft knees, so both legs have room to bend/extend under the roll
	Stand = { LowerTorso = CFrame.new(0, -0.10, 0), LeftUpperLeg = CFrame.Angles(math.rad(12), 0, 0), LeftLowerLeg = CFrame.Angles(math.rad(-24), 0, 0),
		RightUpperLeg = CFrame.Angles(math.rad(12), 0, 0), RightLowerLeg = CFrame.Angles(math.rad(-24), 0, 0) },
	Crouch = {},
}
for _, j in { "LowerTorso", "UpperTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } do
	BASES.Crouch[j] = poseOf("CoverCrouchPeek", j)
end

-- solve one leg: find UpperLeg (x,z) + LowerLeg x so the ankle lands at target; foot matches target orientation
local function solveLeg(side, poses, targetFoot)
	local UL, LL, F = side .. "UpperLeg", side .. "LowerLeg", side .. "Foot"
	local base = poses[UL] or CFrame.identity
	local baseLL = poses[LL] or CFrame.identity
	local x = { 0, 0, 0 } -- deltas: UL rx, UL rz, LL rx (radians)
	local function apply(v)
		poses[UL] = CFrame.Angles(v[1], 0, v[2]) * base
		local kx = baseLL:ToEulerAnglesXYZ()
		if kx + v[3] > 0 then v[3] = -kx end -- knee never hyperextends
		poses[LL] = baseLL * CFrame.Angles(v[3], 0, 0)
	end
	local function err(v)
		apply(v)
		local w = L.fk(poses)
		local ankle = w[LL] * L.motors[F].C0
		local tAnkle = targetFoot * L.motors[F].C1
		return (ankle.Position - tAnkle.Position).Magnitude
	end
	local step = math.rad(4)
	local e = err(x)
	for _ = 1, 400 do
		local improved = false
		for i = 1, 3 do
			for _, s in { step, -step } do
				local y = table.clone(x); y[i] += s
				local ey = err(y)
				if ey < e then x, e, improved = y, ey, true end
			end
		end
		if not improved then step *= 0.5 end
		if step < 1e-5 then break end
	end
	apply(x)
	-- foot orientation: keep world foot equal to target
	local w = L.fk(poses)
	local m = L.motors[F]
	poses[F] = (w[LL] * m.C0):Inverse() * targetFoot * m.C1
	return e
end

local function leanPoses(baseName, dirSign, roll)
	-- dirSign +1 = left (character -X), -1 = right
	local base = BASES[baseName]
	local w0 = L.fk(baseName == "Stand" and {} or base) -- feet stay where the un-leaned pose has them
	local poses = {}
	local lt0 = base.LowerTorso or CFrame.identity
	poses.LowerTorso = CFrame.new(-SHIFT * dirSign, -DROP, 0) * lt0 * CFrame.Angles(0, 0, math.rad(roll * dirSign))
	for _, j in { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" } do poses[j] = base[j] or CFrame.identity end
	-- counter-roll the thighs first so the solver starts near the answer
	for _, side in { "Left", "Right" } do
		poses[side .. "UpperLeg"] = CFrame.Angles(0, 0, -math.rad(roll * dirSign)) * poses[side .. "UpperLeg"]
	end
	poses.UpperTorso = CFrame.new(-CHEST.X * dirSign, CHEST.Y, 0) * CFrame.Angles(0, 0, math.rad((roll / ROLL) * WAIST * dirSign))
	local eL = solveLeg("Left", poses, w0.LeftFoot)
	local eR = solveLeg("Right", poses, w0.RightFoot)
	return poses, w0, math.max(eL, eR)
end

local out = {}
for _, spec in { { "CoverLeanLeft", "Stand", 1 }, { "CoverLeanRight", "Stand", -1 }, { "CoverLeanLeftCrouch", "Crouch", 1 }, { "CoverLeanRightCrouch", "Crouch", -1 } } do
	local name, baseName, d = spec[1], spec[2], spec[3]
	local pA, w0, eA = leanPoses(baseName, d, ROLL)
	local pB, _, eB = leanPoses(baseName, d, ROLL + BREATH)
	pB.LowerTorso = CFrame.new(0, -0.02, 0) * pB.LowerTorso
	local keys = {
		{ 0, poses = pA, ease = "Cubic", dir = "InOut" },
		{ LEN / 2, poses = pB, ease = "Cubic", dir = "InOut" },
		{ LEN, poses = pA, ease = "Cubic", dir = "InOut" },
	}
	local ks = L.build(name, keys, { loop = true, priority = Enum.AnimationPriority.Action4 })
	local old = SRC:FindFirstChild(name)
	if old then
		if old:GetAttribute("PublishedId") then ks:SetAttribute("PublishedId", old:GetAttribute("PublishedId")) end
		old:Destroy()
	end
	ks:SetAttribute("Source", "out/anim_pullup_lean/lua/lean.lua")
	ks.Parent = SRC
	local w = L.fk(pA)
	-- right hand after the hold pose (arm straight forward from PistolHold): measure shoulder + head; hand measured in play test
	table.insert(out, string.format("%s: head dx=%.2f dy=%.2f | Rshoulder dx=%.2f | Lshoulder dx=%.2f | foot err %.3f / %.3f",
		name, w.Head.Position.X - w0.Head.Position.X, w.Head.Position.Y - w0.Head.Position.Y,
		w.RightUpperArm.Position.X - w0.RightUpperArm.Position.X, w.LeftUpperArm.Position.X - w0.LeftUpperArm.Position.X, eA, eB))
	for _, j in { "LowerTorso", "UpperTorso", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" } do
		local rx, ry, rz = pA[j]:ToEulerAnglesXYZ()
		table.insert(out, string.format("   %s rot(%.1f,%.1f,%.1f) pos%s", j, math.deg(rx), math.deg(ry), math.deg(rz), tostring(pA[j].Position)))
	end
end
return table.concat(out, "\n")
