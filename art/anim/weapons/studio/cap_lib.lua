-- cap_lib.lua (prepended by tools/run.sh): evaluate KeyframeSequences on an R15 rig in Edit mode and build anchored
-- "puppets" (exact FK copies, with the real gun tool) for frame strips. Stage at y = 800.
local C = {}
local KSP = game:GetService("KeyframeSequenceProvider")
local SRC = game.ReplicatedStorage.Repository.AnimationSources
local O = Vector3.new(0, 800, 0)
C.O = O

function C.stage()
	local f = workspace:FindFirstChild("_AnimStage")
	if f and f:FindFirstChild("AnimRig") then return f end
	if f then f:Destroy() end
	f = Instance.new("Folder"); f.Name = "_AnimStage"; f.Parent = workspace
	local function part(name, size, cfr, color, mat)
		local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cfr
		p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.Parent = f; return p
	end
	part("Floor", Vector3.new(200, 1, 80), CFrame.new(O + Vector3.new(0, -0.5, 0)), Color3.fromRGB(150, 152, 158), Enum.Material.Concrete)
	part("BackSide", Vector3.new(1, 40, 200), CFrame.new(O + Vector3.new(-12, 20, 0)), Color3.fromRGB(120, 128, 110))
	part("BackGame", Vector3.new(200, 40, 1), CFrame.new(O + Vector3.new(0, 20, -16)), Color3.fromRGB(120, 128, 110))
	local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "AnimRig"
	rig:PivotTo(CFrame.new(O + Vector3.new(0, 3, -200)))
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = f
	return f
end

function C.rig() return C.stage().AnimRig end

local cache = {}
function C.track(ks)
	local rig = C.rig()
	local key = ks:GetDebugId() .. (ks:GetAttribute("SourceHash") or "")
	if cache[key] then return cache[key] end
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", rig.Humanoid)
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(ks)
	local tr = animator:LoadAnimation(a)
	local t0 = os.clock()
	while tr.Length == 0 and os.clock() - t0 < 5 do task.wait() end
	cache[key] = tr
	return tr
end

-- pose the rig: list = { {name, time, weight} }; returns joint Transforms (Part1 name -> CFrame)
function C.pose(list)
	local rig = C.rig()
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator")
	for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0) end
	animator:StepAnimations(0)
	local trs = {}
	for _, it in list do
		local tr = C.track(SRC[it[1]])
		tr:Play(0, it[3] or 1, 0)
		trs[tr] = it[2] or 0
	end
	animator:StepAnimations(1)
	for tr, t in trs do tr.TimePosition = t end
	animator:StepAnimations(0)
	local out = {}
	for n, j in C.joints() do out[n] = j.obj.Transform end
	return out
end

-- R15 joints of the capture rig: Part1 name -> {part0, C0, C1, obj} (Motor6D or AnimationConstraint)
function C.joints()
	local rig = C.rig()
	local js = {}
	for _, m in rig:GetDescendants() do
		if m:IsA("Motor6D") and m.Part1 then
			js[m.Part1.Name] = { Part0 = m.Part0, C0 = m.C0, C1 = m.C1, obj = m }
		elseif m:IsA("AnimationConstraint") and m.Attachment1 then
			js[m.Attachment1.Parent.Name] = { Part0 = m.Attachment0.Parent, C0 = m.Attachment0.CFrame, C1 = m.Attachment1.CFrame, obj = m }
		end
	end
	return js
end

function C.fk(poses)
	local motors = C.joints()
	local world = { HumanoidRootPart = CFrame.identity }
	for _, n in { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
		"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } do
		local m = motors[n]
		world[n] = world[m.Part0.Name] * m.C0 * (poses[n] or CFrame.identity) * m.C1:Inverse()
	end
	return world
end

function C.findTool(name)
	return game.ReplicatedStorage.Repository:FindFirstChild(name, true)
end

-- an anchored copy of the posed body (+ gun in the gun hand, gun parts posed by `poses` if jointed), HRP at rootCF
function C.puppet(name, poses, rootCF, gunName, opts)
	opts = opts or {}
	local rig = C.rig()
	local pm = Instance.new("Model"); pm.Name = name
	local w = C.fk(poses)
	for n, cfw in w do
		local src = rig:FindFirstChild(n)
		if src and src:IsA("BasePart") and n ~= "HumanoidRootPart" then
			local c = src:Clone()
			for _, d in c:GetChildren() do if not (d:IsA("Decal") or d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance")) then d:Destroy() end end
			c.Anchored = true; c.CanCollide = false
			c.Color = (n == "Head") and Color3.fromRGB(226, 222, 210) or Color3.fromRGB(196, 192, 182)
			c.Material = Enum.Material.SmoothPlastic
			c.TextureID = ""
			c.Transparency = (opts.hideHead and (n == "Head")) and 1 or 0
			c.CFrame = rootCF * cfw
			c.Parent = pm
		end
	end
	if gunName then
		local tool = C.findTool(gunName)
		local handName = opts.left and "LeftHand" or "RightHand"
		local att = rig.RightHand.RightGripAttachment.CFrame
		if opts.left then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = att:GetComponents()
			att = CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
		end
		local handle = rootCF * w[handName] * att * tool.Grip:Inverse()
		-- moving gun parts: Motor6D Handle -> part posed by the clip (poses[part]); everything else rigid
		local motorOf = {}
		for _, j in tool:GetDescendants() do
			if j:IsA("Motor6D") and j.Part0 and j.Part1 then motorOf[j.Part1] = j end
		end
		local h0 = tool.Handle.CFrame
		local function worldOf(p)
			local m = motorOf[p]
			if m and m.Part0 then
				return worldOf(m.Part0) * m.C0 * (poses[p.Name] or CFrame.identity) * m.C1:Inverse()
			end
			return handle * h0:Inverse() * p.CFrame
		end
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone(); c:ClearAllChildren()
				for _, d in p:GetChildren() do if d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then d:Clone().Parent = c end end
				c.Anchored = true; c.CanCollide = false
				c.CFrame = worldOf(p)
				c.Parent = pm
			end
		end
	end
	pm.Parent = C.stage()
	return pm, w
end

function C.clear()
	for _, c in C.stage():GetChildren() do
		if c:IsA("Model") and c.Name ~= "AnimRig" then c:Destroy() end
	end
end

return C
