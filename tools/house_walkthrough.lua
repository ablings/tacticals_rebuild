-- tools/house_walkthrough.lua: every visible art part (furniture + dressing + shell pieces <= 24 studs) sampled at body height
-- (1.5 / 2.5 / 3.2 above its storey's floor) inside its box; a sample in walkable space (no collider there) = walk-through art
local map = workspace.House
local O = map:GetAttribute("PlanOrigin")
local ov = OverlapParams.new()
ov.FilterType = Enum.RaycastFilterType.Include
ov.FilterDescendantsInstances = { map.CollisionProxies, map.Doors }
ov.RespectCanCollide = false
local hits = {}
local function check(p, label)
	if p.Transparency >= 1 then return end
	local cf, size = p.CFrame, p.Size
	if math.max(size.X, size.Z) > 24 then return end
	local bottom = p.Position.Y - size.Y / 2 - O.Y
	local floor = bottom >= 13 and 14 or 0
	local bad = 0
	for _, h in { 1.5, 2.5, 3.2 } do
		local y = O.Y + floor + h
		if y > p.Position.Y - size.Y / 2 + 0.05 and y < p.Position.Y + size.Y / 2 - 0.05 then
			local at = Vector3.new(p.Position.X, y, p.Position.Z)
			-- the whole column from just above the floor to the sample: a collider anywhere under it (a seat, a table, a nightstand)
			-- means no body stands there
			local col = workspace:GetPartBoundsInBox(CFrame.new(at.X, O.Y + floor + (h + 0.2) / 2, at.Z), Vector3.new(0.3, h - 0.2, 0.3), ov)
			local inside = col
			local solid = false
			for _, q in inside do if q.CanCollide then solid = true end end
			if not solid then bad += 1 end
		end
	end
	if bad > 0 then table.insert(hits, label .. "/" .. p.Name) end
end
for _, f in { map.Visuals.Furniture, map.Visuals.Dressing } do
	for _, m in f:GetChildren() do
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then check(d, m.Name) end end
	end
end
return #hits .. " walk-through samples: " .. table.concat(hits, ", ")
