local SRC = game.ReplicatedStorage.Repository.AnimationSources
local L = {}
local function n(x) return string.format("%.5g", x) end
local function cfs(c) local t = { c:GetComponents() }; for i, v in t do t[i] = n(v) end; return "{" .. table.concat(t, ",") .. "}" end
local function pose(p, ind)
	local kids = {}
	for _, c in p:GetChildren() do if c:IsA("Pose") then table.insert(kids, pose(c, ind .. "\t")) end end
	return string.format('%s{ "%s", %s, "%s", "%s", {\n%s%s} },\n', ind, p.Name, cfs(p.CFrame), p.EasingStyle.Name, p.EasingDirection.Name, table.concat(kids), ind)
end
table.insert(L, "-- install_sources.lua (generated from out/anim_pullup_lean/anim_pullup_lean.rbxl by the animator, 2026-10-29)")
table.insert(L, "-- Run in Studio (command bar / MCP execute_luau) in a place copy: (re)creates the five KeyframeSequences in")
table.insert(L, "-- ReplicatedStorage.Repository.AnimationSources with their PublishedId, RootKeys and markers. Idempotent.")
table.insert(L, "local SRC = game.ReplicatedStorage.Repository.AnimationSources")
table.insert(L, "local function cf(t) return CFrame.new(table.unpack(t)) end")
table.insert(L, "local function mk(parent, d) local p = Instance.new('Pose'); p.Name = d[1]; p.CFrame = cf(d[2]); p.EasingStyle = Enum.PoseEasingStyle[d[3]]; p.EasingDirection = Enum.PoseEasingDirection[d[4]]; p.Weight = 1; for _, k in d[5] do mk(p, k) end; p.Parent = parent end")
table.insert(L, "local CLIPS = {")
for _, name in { "CoverPullUp", "CoverLeanLeft", "CoverLeanRight", "CoverLeanLeftCrouch", "CoverLeanRightCrouch" } do
	local ks = SRC[name]
	local attrs = {}
	for k, v in ks:GetAttributes() do table.insert(attrs, string.format("%s = %q", k, tostring(v))) end
	table.insert(L, string.format('{ name = "%s", loop = %s, priority = "%s", attrs = { %s }, keys = {', name, tostring(ks.Loop), ks.Priority.Name, table.concat(attrs, ", ")))
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	for _, kf in kfs do
		local marks = {}
		for _, m in kf:GetMarkers() do table.insert(marks, string.format("%q", m.Name)) end
		local root = kf:FindFirstChildOfClass("Pose")
		table.insert(L, string.format("\t{ t = %s, name = %q, markers = { %s }, root = %s},", n(kf.Time), kf.Name, table.concat(marks, ", "), pose(root, "\t\t")))
	end
	table.insert(L, "} },")
end
table.insert(L, "}")
table.insert(L, [[
local out = {}
for _, c in CLIPS do
	local old = SRC:FindFirstChild(c.name); if old then old:Destroy() end
	local ks = Instance.new("KeyframeSequence"); ks.Name = c.name; ks.Loop = c.loop; ks.Priority = Enum.AnimationPriority[c.priority]
	for k, v in c.attrs do ks:SetAttribute(k, v) end
	for _, k in c.keys do
		local kf = Instance.new("Keyframe"); kf.Time = k.t; kf.Name = k.name
		mk(kf, k.root)
		for _, m in k.markers do local km = Instance.new("KeyframeMarker"); km.Name = m; km.Value = m; km.Parent = kf end
		kf.Parent = ks
	end
	ks.Parent = SRC
	table.insert(out, c.name .. " " .. tostring(ks:GetAttribute("PublishedId")))
end
return "installed: " .. table.concat(out, ", ")]])
return table.concat(L, "\n")
