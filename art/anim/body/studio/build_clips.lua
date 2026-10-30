-- build_clips.lua (anim-body copy of art/anim/weapons/studio/build_clips.lua; returns its log for MCP): builds R15 KeyframeSequences from the Blender exporter's JSON (art/anim/weapons/blender/rbxanim.py).
-- Prepend `local CLIPS_JSON = [==[ ...json... ]==]` (a JSON array of clips) and run in Studio (command bar or MCP
-- execute_luau, Edit mode). Each clip replaces ReplicatedStorage.Repository.AnimationSources.<name>; an existing
-- PublishedId is kept only if the clip's hash is unchanged (attribute SourceHash), else cleared (the new clip needs a new
-- upload). Prints one line per clip.
local HttpService = game:GetService("HttpService")
local SRC = game.ReplicatedStorage:WaitForChild("Repository"):WaitForChild("AnimationSources")

local function cf(a)
	return CFrame.new(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
end

local function build(clip)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = clip.name
	ks.Loop = clip.loop
	ks.Priority = Enum.AnimationPriority[clip.priority]
	-- clip.tree: { PartName = ParentName } (HumanoidRootPart is the root)
	local times = {}
	for _, k in clip.keys do times[k.t] = true end
	for _, m in clip.markers do times[m.t] = true end
	local sorted = {}
	for t in times do table.insert(sorted, t) end
	table.sort(sorted)
	local kfAt = {}
	for _, t in sorted do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		kf.Name = "Keyframe"
		kf.Parent = ks
		kfAt[t] = { kf = kf, poses = {} }
	end
	-- the exporter keys every joint's parent chain in every keyframe (no weight-0 placeholders); HumanoidRootPart is
	-- the identity root pose
	local function poseFor(entry, part)
		local p = entry.poses[part]
		if p then return p end
		p = Instance.new("Pose")
		p.Name = part
		p.Weight = 1
		p.CFrame = CFrame.identity
		local parentName = clip.tree[part]
		p.Parent = parentName and poseFor(entry, parentName) or entry.kf
		entry.poses[part] = p
		return p
	end
	for _, k in clip.keys do
		local entry = kfAt[k.t]
		local p = poseFor(entry, k.part)
		p.CFrame = cf(k.cf)
		p.Weight = 1
		p.EasingStyle = Enum.PoseEasingStyle[k.ease or "Linear"]
		p.EasingDirection = Enum.PoseEasingDirection.InOut
	end
	for _, m in clip.markers do
		local entry = kfAt[m.t]
		entry.kf.Name = m.name
		local mk = Instance.new("KeyframeMarker")
		mk.Name = m.name
		mk.Value = m.value or ""
		entry.kf:AddMarker(mk)
	end
	for k, v in clip.attrs or {} do ks:SetAttribute(k, v) end
	return ks
end

local LOG = {}
local clips = HttpService:JSONDecode(CLIPS_JSON)
for _, clip in clips do
	local old = SRC:FindFirstChild(clip.name)
	local keepId = nil
	if old and old:GetAttribute("SourceHash") == clip.attrs.SourceHash then keepId = old:GetAttribute("PublishedId") end
	local ks = build(clip)
	if keepId and keepId ~= "" then ks:SetAttribute("PublishedId", keepId) end
	if old then old:Destroy() end
	ks.Parent = SRC
	table.insert(LOG, ("[anim-body] %s len %.3f loop %s %s keys %d markers %d id %s"):format(clip.name, clip.length,
		tostring(clip.loop), clip.priority, #clip.keys, #clip.markers, tostring(ks:GetAttribute("PublishedId"))))
end
return table.concat(LOG, string.char(10))
