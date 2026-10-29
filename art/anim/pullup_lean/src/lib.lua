-- lib.lua: shared helpers for the PullUp / Lean set (prepended by run.sh to files that start with --@lib)
local L = {}
local RIG = workspace:FindFirstChild("AnimRig")
L.rig = RIG

local function cf(e)
	if not e then return CFrame.identity end
	return CFrame.new(e[4] or 0, e[5] or 0, e[6] or 0) * CFrame.Angles(math.rad(e[1] or 0), math.rad(e[2] or 0), math.rad(e[3] or 0))
end
L.cf = cf

-- joint tree (Part1 name -> motor) from the rig
L.motors = {}
for _, m in RIG:GetDescendants() do
	if m:IsA("Motor6D") then L.motors[m.Part1.Name] = m end
end

-- forward kinematics with pose CFrames (name -> CFrame), HRP at identity
function L.fk(poses)
	local world = { HumanoidRootPart = CFrame.identity }
	local order = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
		"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
	for _, n in order do
		local m = L.motors[n]
		world[n] = world[m.Part0.Name] * m.C0 * (poses[n] or CFrame.identity) * m.C1:Inverse()
	end
	return world
end

-- FK of a posed rig from its motors' current Transform (edit-mode parts can lag); HRP at identity
function L.fkRig(rig)
	local poses = {}
	for _, m in rig:GetDescendants() do
		if m:IsA("Motor6D") and m.Name ~= "RightGrip" then poses[m.Part1.Name] = m.Transform end
	end
	return L.fk(poses)
end

-- 2-bone solve: upper (rx, rz deltas) + lower (rx) so that endJoint's pivot reaches target (HRP space).
-- bendSign: +1 elbow (lower rx >= 0), -1 knee (lower rx <= 0)
function L.solve(poses, upper, lower, endPart, target, bendSign)
	local bu = poses[upper] or CFrame.identity
	local bl = poses[lower] or CFrame.identity
	local x = { 0, 0, 0 }
	local function apply(v)
		poses[upper] = CFrame.Angles(v[1], 0, v[2]) * bu
		local kx = bl:ToEulerAnglesXYZ()
		if (kx + v[3]) * bendSign < 0 then v[3] = -kx end
		poses[lower] = bl * CFrame.Angles(v[3], 0, 0)
	end
	local function err(v)
		apply(v)
		local w = L.fk(poses)
		return ((w[lower] * L.motors[endPart].C0).Position - target).Magnitude
	end
	local best, bestE
	for _, start in { { 0, 0, 0 }, { 0.5, 0, 1.0 * bendSign }, { -0.3, 0, 0.6 * bendSign } } do
		x = table.clone(start)
		local step, e = math.rad(6), err(x)
		for _ = 1, 600 do
			local improved = false
			for i = 1, 3 do
				for _, sg in { step, -step } do
					local y = table.clone(x); y[i] += sg
					local ey = err(y)
					if ey < e then x, e, improved = y, ey, true end
				end
			end
			if not improved then step *= 0.5 end
			if step < 1e-5 then break end
		end
		if not bestE or e < bestE - 1e-3 then best, bestE = x, e end
		if bestE < 0.02 then break end -- keep the first (closest to the seed) good answer
	end
	apply(best)
	return bestE
end
-- set an end part's world (HRP-space) rotation, keeping its joint position
function L.orient(poses, parentPart, part, rot)
	local w = L.fk(poses)
	local m = L.motors[part]
	local j = w[parentPart] * m.C0
	poses[part] = j.Rotation:Inverse() * rot -- joint frame takes rot (R15 C1 has no rotation)
end

-- build a KeyframeSequence. keys = { {t, poses = {Joint = {rx,ry,rz,px,py,pz} or CFrame}, ease = "Cubic", dir = "InOut", marker = "Name"} }
-- full = true: every joint gets a pose (overrides lower priorities everywhere); else only listed joints + parents
local TREE = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}
L.TREE = TREE
function L.build(name, keys, opts)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = opts.loop or false
	ks.Priority = opts.priority
	-- which joints appear (same set in every key so nothing pops)
	local used = {}
	for _, k in keys do for j in k.poses do used[j] = true end end
	if opts.full then for j in TREE do used[j] = true end end
	for j in pairs(table.clone(used)) do
		local p = TREE[j]
		while p and p ~= "HumanoidRootPart" do used[p] = true; p = TREE[p] end
	end
	for _, k in keys do
		local kf = Instance.new("Keyframe")
		kf.Time = k[1]
		kf.Name = k.marker or "Keyframe"
		local made = {}
		local function pose(j)
			if made[j] then return made[j] end
			local parent = (j == "HumanoidRootPart") and kf or pose(TREE[j])
			local p = Instance.new("Pose")
			p.Name = j
			local e = k.poses[j]
			if typeof(e) == "CFrame" then p.CFrame = e else p.CFrame = cf(e) end
			p.EasingStyle = Enum.PoseEasingStyle[k.ease or "Cubic"]
			p.EasingDirection = Enum.PoseEasingDirection[k.dir or "InOut"]
			p.Weight = 1
			p.Parent = parent
			made[j] = p
			return p
		end
		pose("HumanoidRootPart")
		for j in used do pose(j) end
		if k.marker then
			local m = Instance.new("KeyframeMarker")
			m.Name = k.marker
			m.Value = k.marker
			m.Parent = kf
		end
		kf.Parent = ks
	end
	return ks
end

-- evaluate tracks on a rig at time t (edit mode). list = { {ks, time, weight} }
local KSP = game:GetService("KeyframeSequenceProvider")
L.cache = {}
function L.track(rig, ks)
	local key = rig:GetDebugId() .. ks:GetDebugId()
	if L.cache[key] then return L.cache[key] end
	local animator = rig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(ks)
	local tr = animator:LoadAnimation(a)
	local t0 = os.clock()
	while tr.Length == 0 and os.clock() - t0 < 5 do task.wait() end
	L.cache[key] = tr
	return tr
end
function L.pose(rig, list)
	local animator = rig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0) end
	animator:StepAnimations(0)
	for _, m in rig:GetDescendants() do if m:IsA("Motor6D") then m.Transform = CFrame.identity end end
	local trs = {}
	for _, it in list do
		local tr = L.track(rig, it[1])
		tr:Play(0, it[3] or 1, 0)
		trs[tr] = it[2] or 0
	end
	-- edit mode: a zero fade still blends in over a step, so step well past it at speed 0, then pin the times again
	animator:StepAnimations(1)
	for tr, t in trs do tr.TimePosition = t end
	animator:StepAnimations(0)
end

-- attach a weapon model (Tool) to a rig's RightHand like Roblox's RightGrip
function L.gun(rig, toolName)
	local old = rig:FindFirstChild("_Gun")
	if old then old:Destroy() end
	if not toolName then return end
	local src = game.ReplicatedStorage.Repository:FindFirstChild(toolName, true)
	local tool = src:Clone()
	local m = Instance.new("Model")
	m.Name = "_Gun"
	for _, c in tool:GetChildren() do c.Parent = m end
	local handle = m:FindFirstChild("Handle")
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = false end
	end
	handle.Anchored = false
	local w = Instance.new("Motor6D")
	w.Name = "RightGrip"
	w.Part0 = rig.RightHand
	w.Part1 = handle
	w.C0 = rig.RightHand.RightGripAttachment.CFrame
	w.C1 = tool.Grip
	w.Parent = rig.RightHand
	m.Parent = rig
	return m, w
end

-- anchored copy of the posed rig (+ gun) placed by FK: exact, no edit-mode lag. rootCF = where the HRP goes
function L.puppet(rig, gunName, rootCF, extraWorld)
	local stage = rig.Parent
	local old = stage:FindFirstChild("_Puppet"); if old then old:Destroy() end
	local pm = Instance.new("Model"); pm.Name = "_Puppet"
	local w = L.fkRig(rig)
	rootCF = rootCF or rig.HumanoidRootPart.CFrame
	for name, cfw in w do
		local src = rig:FindFirstChild(name)
		if src and src:IsA("BasePart") and name ~= "HumanoidRootPart" then
			local c = src:Clone()
			for _, d in c:GetChildren() do if not (d:IsA("Decal") or d:IsA("SpecialMesh")) then d:Destroy() end end
			c.Anchored = true; c.CanCollide = false; c.Transparency = 0
			c.CFrame = rootCF * cfw
			c.Parent = pm
		end
	end
	if gunName then
		local tool = game.ReplicatedStorage.Repository:FindFirstChild(gunName, true)
		local h = tool.Handle.CFrame
		local hand = rootCF * w.RightHand * rig.RightHand.RightGripAttachment.CFrame * tool.Grip:Inverse()
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone(); c:ClearAllChildren()
				for _, d in p:GetChildren() do if d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then d:Clone().Parent = c end end
				c.Anchored = true; c.CanCollide = false
				c.CFrame = hand * h:Inverse() * p.CFrame
				c.Parent = pm
			end
		end
	end
	pm.Parent = stage
	for _, d in rig:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = 1; d.Transparency = 1 end end
	local g = rig:FindFirstChild("_Gun"); if g then g:Destroy() end
	return w
end

return L
