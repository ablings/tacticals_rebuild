-- tools/wh2_dump.lua: read-only dump of Workspace.Warehouse2's gameplay layer in the format of notes/warehouse_study/t2.lua
-- (proxies, camskin, spawns, shootables), for tools/wh2_metrics.py and tools/wh2_readback.py.
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local w = workspace.Warehouse2
local res = { proxies = {}, spawns = {}, shootables = {}, camskin = {}, bounds = {}, props = {}, art = {} }
local function rec(p)
	local cf = p.CFrame
	local rx, ry, rz = cf:ToOrientation()
	return { name = p.Name, class = p.ClassName, pos = { cf.X, cf.Y, cf.Z }, size = { p.Size.X, p.Size.Y, p.Size.Z },
		rot = { math.deg(rx), math.deg(ry), math.deg(rz) }, collide = p.CanCollide, query = p.CanQuery, touch = p.CanTouch,
		transp = p.Transparency, shadow = p.CastShadow, anchored = p.Anchored, mat = tostring(p.Material), attrs = p:GetAttributes(),
		tags = CS:GetTags(p), parent = p.Parent and p.Parent.Name }
end
for _, p in w.CollisionProxies:GetChildren() do if p:IsA("BasePart") then table.insert(res.proxies, rec(p)) end end
for _, p in w.CamSkin:GetChildren() do if p:IsA("BasePart") then table.insert(res.camskin, rec(p)) end end
for _, p in w.Bounds:GetChildren() do if p:IsA("BasePart") then table.insert(res.bounds, rec(p)) end end
for _, p in w.MatchSpawns:GetChildren() do if p:IsA("BasePart") then table.insert(res.spawns, rec(p)) end end
for _, p in w.Shootables:GetDescendants() do if p:IsA("BasePart") then table.insert(res.shootables, rec(p)) end end
for _, p in w.Props:GetChildren() do if p:IsA("BasePart") then table.insert(res.props, rec(p)) end end
-- art: count + any that collide / query / touch (must be none)
local n, bad = 0, {}
for _, root in { w.Visuals, w.Cover, w.Props } do
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not d.Name:match("^PCOL_") then
			n += 1
			if d.CanCollide or d.CanQuery or d.CanTouch then table.insert(bad, d:GetFullName()) end
		end
	end
end
res.art = { count = n, colliding = bad }
local sh = {}
for _, m in w.Shootables:GetChildren() do
	local a = m:GetAttributes()
	sh[m.Name] = { tags = CS:GetTags(m), attrs = a }
end
res.shootableModels = sh
res.mapAttrs = w:GetAttributes()
local entry = game.ReplicatedStorage.DuelMaps:FindFirstChild("Warehouse2")
res.registry = entry and { attrs = entry:GetAttributes(), hasInfo = entry:FindFirstChild("MapInfo") ~= nil } or false
res.warehouseIntact = workspace:FindFirstChild("Warehouse") ~= nil and #workspace.Warehouse:GetDescendants()
return HS:JSONEncode(res)
