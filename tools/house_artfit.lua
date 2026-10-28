-- tools/house_artfit.lua: every placed furniture mesh's world box vs the union of its COLP boxes (plan footprint + height)
local map = workspace.House
local cp = map.CollisionProxies
local out, worst = {}, 0
for _, m in map.Visuals.Furniture:GetChildren() do
	local id = m.Name:gsub("_%d+$", "")
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local found = false
	for _, p in cp:GetChildren() do
		local pid = p:GetAttribute("PartId") or ""
		if pid == "F_" .. id or pid:match("^F_" .. id:gsub("%p", "%%%0") .. "_%d+$") then
			found = true
			local h = p.Size / 2
			mn = mn:Min(p.Position - h); mx = mx:Max(p.Position + h)
		end
	end
	if found and not m.Name:match("_%d+$") then
		local amn, amx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local cf, h = d.CFrame, d.Size / 2
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					local v = cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)); amn = amn:Min(v); amx = amx:Max(v)
				end end end
			end
		end
		local dx = math.max(math.abs(amn.X - mn.X), math.abs(amx.X - mx.X))
		local dz = math.max(math.abs(amn.Z - mn.Z), math.abs(amx.Z - mx.Z))
		local dy = math.abs(amn.Y - mn.Y)
		worst = math.max(worst, dx, dz, dy)
		if dx > 0.2 or dz > 0.2 or dy > 0.05 then table.insert(out, ("%s off x %.2f z %.2f bottom %.2f"):format(m.Name, dx, dz, dy)) end
	end
end
return ("art vs collision: worst %.3f; off > 0.2: %d\n%s"):format(worst, #out, table.concat(out, "\n"))
