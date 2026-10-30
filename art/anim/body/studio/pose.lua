-- pose.lua: anchored puppets of avatars posed by a clip at time t (exact FK from the KeyframeSequence, Linear keys as the
-- exporter writes them). Prepend: PUPPETS = { {avatar=, clip=, t=, at=CFrame (HRP), gun=?, hand="R"|"L", extra=?{clip,t}} }.
-- Joints a clip keys at Weight 0 are not applied (layers then keep the lower clip; list layers low -> high priority).
-- Works with Motor6D and AnimationConstraint joints. Puppets go in workspace._AnimStage._Puppets.
local SRC = game.ReplicatedStorage.Repository.AnimationSources
local store = game.ServerStorage._AnimAvatars
local stage = workspace._AnimStage
local old = stage:FindFirstChild("_Puppets"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "_Puppets"; folder.Parent = stage

local cache = {}
local function frames(ks)
	if cache[ks] then return cache[ks] end
	local list = {}
	for _, kf in ks:GetKeyframes() do
		local poses = {}
		for _, p in kf:GetDescendants() do if p:IsA("Pose") and p.Weight > 0 then poses[p.Name] = p.CFrame end end
		table.insert(list, { t = kf.Time, poses = poses })
	end
	table.sort(list, function(a, b) return a.t < b.t end)
	cache[ks] = list
	return list
end
local function sampleKS(ks, t)
	local fr = frames(ks)
	local len = fr[#fr].t
	if ks.Loop and len > 0 then t = t % len end
	if t <= fr[1].t then return fr[1].poses end
	if t >= len then return fr[#fr].poses end
	for i = 1, #fr - 1 do
		local a, b = fr[i], fr[i + 1]
		if t >= a.t and t <= b.t then
			local u = (t - a.t) / math.max(b.t - a.t, 1e-6)
			local out = {}
			for k, v in a.poses do out[k] = v:Lerp(b.poses[k] or v, u) end
			return out
		end
	end
	return fr[#fr].poses
end
local function joints(rig)
	local js = {}
	for _, j in rig:GetDescendants() do
		if j:IsA("Motor6D") and j.Part0 and j.Part1 then
			js[j.Part1.Name] = { p0 = j.Part0.Name, C0 = j.C0, C1 = j.C1 }
		elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
			js[j.Attachment1.Parent.Name] = { p0 = j.Attachment0.Parent.Name, C0 = j.Attachment0.CFrame, C1 = j.Attachment1.CFrame }
		end
	end
	return js
end
local ORDER = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

local report = {}
local HEAD = nil
for n, P in PUPPETS do
	local src = store[P.avatar]
	local js = joints(src)
	local poses = {}
	for _, layer in (P.layers or { { P.clip, P.t } }) do
		local ks = SRC:FindFirstChild(layer[1])
		if ks then
			for k, v in sampleKS(ks, layer[2]) do if k ~= "HumanoidRootPart" then poses[k] = v end end
		else
			table.insert(report, "missing clip " .. tostring(layer[1]))
		end
	end
	local hrp = src.HumanoidRootPart
	local world = { HumanoidRootPart = P.at }
	for _, name in ORDER do
		local j = js[name]
		if j and world[j.p0] then world[name] = world[j.p0] * j.C0 * (poses[name] or CFrame.identity) * j.C1:Inverse() end
	end
	local m = Instance.new("Model"); m.Name = "P" .. n
	local clone = src:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("AnimationConstraint") or d:IsA("WeldConstraint") then d:Destroy() end
	end
	for _, d in clone:GetChildren() do
		if d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false
			if d.Name == "HumanoidRootPart" then d.Transparency = 1; d.CFrame = P.at
			elseif world[d.Name] then d.CFrame = world[d.Name] end
		elseif d:IsA("Accessory") then
			local h = d:FindFirstChild("Handle")
			local a1 = h and h:FindFirstChildOfClass("Attachment")
			if a1 then
				local a0 = clone:FindFirstChild(a1.Name, true)
				local hostName = a0 and a0.Parent and a0.Parent.Name
				if hostName and world[hostName] and a0 ~= a1 then
					h.Anchored = true; h.CanCollide = false
					h.CFrame = world[hostName] * a0.CFrame * a1.CFrame:Inverse()
				end
			end
		end
	end
	for _, d in clone:GetChildren() do d.Parent = m end
	clone:Destroy()
	if P.gun then
		local tool = game.ReplicatedStorage.Repository:FindFirstChild(P.gun, true)
		local handName = (P.hand == "L") and "LeftHand" or "RightHand"
		local att = src[handName]:FindFirstChild(handName == "LeftHand" and "LeftGripAttachment" or "RightGripAttachment")
		local hcf = world[handName] * att.CFrame * tool.Grip:Inverse()
		local h0 = tool.Handle.CFrame
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone(); c:ClearAllChildren()
				for _, d in p:GetChildren() do if d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then d:Clone().Parent = c end end
				c.Anchored = true; c.CanCollide = false
				c.CFrame = hcf * h0:Inverse() * p.CFrame
				c.Parent = m
			end
		end
	end
	if n == 1 and world.Head then
		local e = world.Head * CFrame.new(0, 0.15, -0.65)
		local l = e.Position + e.LookVector * 6 - e.UpVector * 1.2
		HEAD = ("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f"):format(e.X, e.Y, e.Z, l.X, l.Y, l.Z)
	end
	m.Parent = folder
end
return "posed " .. #PUPPETS .. "|" .. tostring(HEAD) .. (#report > 0 and (" | " .. table.concat(report, "; ")) or "")
