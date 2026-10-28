-- tools/house_dump.lua: read back Workspace.House's gameplay layer (proxies, door leaves, spawns, windows, registry) as JSON
local FROM, TO = 1, 100000 --@CHUNK
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("House")
if not map then return "no House" end
local O = map:GetAttribute("PlanOrigin")
local out = { origin = { O.X, O.Y, O.Z }, parts = {}, doors = {}, spawns = {}, windows = {}, art = { n = 0, colliding = 0 } }
local function rec(p, extra)
	local cf = p.CFrame
	local rx, ry, rz = cf:ToOrientation()
	local r = { name = p.Name, class = p.ClassName, pos = { cf.X, cf.Y, cf.Z }, size = { p.Size.X, p.Size.Y, p.Size.Z },
		rot = { math.deg(rx), math.deg(ry), math.deg(rz) }, look = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
		collide = p.CanCollide, query = p.CanQuery, touch = p.CanTouch, transp = p.Transparency, anchored = p.Anchored,
		attrs = p:GetAttributes(), tags = CS:GetTags(p) }
	for k, v in extra or {} do r[k] = v end
	for k, v in r.attrs do if typeof(v) ~= "string" and typeof(v) ~= "number" and typeof(v) ~= "boolean" then r.attrs[k] = tostring(v) end end
	return r
end
local all = map.CollisionProxies:GetChildren()
table.sort(all, function(a, b) return a.Name < b.Name end)
out.nparts = #all
for i = FROM, math.min(TO, #all) do table.insert(out.parts, rec(all[i])) end
for _, d in map.Doors:GetChildren() do
	local a = d:GetAttributes()
	for k, v in a do if typeof(v) == "CFrame" then a[k] = { v:GetComponents() } end end
	table.insert(out.doors, { name = d.Name, attrs = a, leaf = rec(d.Leaf), hinge = rec(d.Hinge), tags = CS:GetTags(d) })
end
for _, s in map.MatchSpawns:GetChildren() do table.insert(out.spawns, rec(s)) end
for _, w in map.Shootables:GetChildren() do table.insert(out.windows, { name = w.Name, shootable = w:GetAttribute("Shootable"), glass = w:FindFirstChild("Glass") ~= nil, broken = w:FindFirstChild("BrokenGlass") ~= nil }) end
for _, d in map.Visuals:GetDescendants() do
	if d:IsA("BasePart") then out.art.n += 1 if d.CanCollide or d.CanQuery or d.CanTouch then out.art.colliding += 1 end end
end
local e = game.ReplicatedStorage.DuelMaps:FindFirstChild("House")
out.registry = e and { attrs = e:GetAttributes(), info = e:FindFirstChild("MapInfo") and e.MapInfo.Source:sub(1, 4000) } or nil
out.indoor = map:GetAttribute("Indoor")
return HS:JSONEncode(out)
