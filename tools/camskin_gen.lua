-- camskin_gen.lua (read only): measures where a map's VISUAL wall surfaces stand proud of its queryable collision walls
-- and returns the thin "camera skin" colliders that close the gap, as JSON (fix/data/<map>_camskin.json).
-- Why: the third-person camera's probe (Spherecast, CanQuery parts only) stops 0.45 studs before a collision wall; where the
-- visual wall mesh stands further out than that, the camera ends up behind the visible surface. Run in the match place
-- (the map at its native position): python tools/run_luau.py-style call with MAP = workspace.Warehouse.
-- Visual triangles come from EditableMesh:RaycastLocal (exact), not from the meshes' coarse collision hulls.
local AS = game:GetService("AssetService")
local HS = game:GetService("HttpService")
local MAP = workspace.Warehouse
local STEP, BIN = 0.5, 2          -- sample spacing along a wall, skin segment length
local Y0, Y1 = 0.5, 11.5          -- heights sampled (floor .. above the camera)
local MAXP = 2.5                  -- deeper than this = a separate object, not the wall skin
local OVERLAP = 0.2               -- skin reaches this far into the collision wall

local meshes, cache = {}, {}
for _, p in MAP.Visuals:GetDescendants() do
	if p:IsA("MeshPart") then
		local e = cache[p.MeshId]
		if e == nil then
			local ok, em = pcall(function() return AS:CreateEditableMeshAsync(Content.fromUri(p.MeshId)) end)
			if ok then
				local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
				for _, v in em:GetVertices() do local q = em:GetPosition(v); mn = mn:Min(q); mx = mx:Max(q) end
				e = { em = em, c = (mn + mx) / 2, size = mx - mn }
			else e = false end
			cache[p.MeshId] = e
		end
		if e then table.insert(meshes, { part = p, em = e.em, c = e.c, scale = e.size / p.Size }) end
	end
end
local function vhit(a, b)
	local best
	for _, m in meshes do
		local cf = m.part.CFrame
		local la = cf:PointToObjectSpace(a) * m.scale + m.c
		local d = cf:PointToObjectSpace(b) * m.scale + m.c - la
		local ok, _, pos = pcall(function() return m.em:RaycastLocal(la, d) end)
		if ok and typeof(pos) == "Vector3" and (pos - la).Magnitude <= d.Magnitude then
			local w = cf:PointToWorldSpace((pos - m.c) / m.scale)
			if not best or (w - a).Magnitude < (best - a).Magnitude then best = w end
		end
	end
	return best
end
local rp = RaycastParams.new()

-- each wall: the collision part, the inward normal, the axis along the wall and its sampled range
local walls = {}
for _, w in MAP.CollisionProxies:GetChildren() do
	if w:IsA("BasePart") and w.Name:match("^COLP_Wall") and not w.Name:match("Header") then
		local s = w.Size
		local alongX = s.X > s.Z
		local toCentre = (MAP:GetPivot().Position - w.Position) * Vector3.new(1, 0, 1)
		local n = alongX and Vector3.new(0, 0, math.sign(toCentre.Z)) or Vector3.new(math.sign(toCentre.X), 0, 0)
		local face = w.Position + n * ((alongX and s.Z or s.X) / 2)
		local axis = alongX and Vector3.xAxis or Vector3.zAxis
		local half = (alongX and s.X or s.Z) / 2
		table.insert(walls, { part = w, n = n, face = face, axis = axis, half = half })
	end
end
table.sort(walls, function(a, b) return a.part.Name < b.part.Name end)

local out = {}
for _, w in walls do
	local bins = {}
	for t = -w.half + STEP / 2, w.half - STEP / 2, STEP do
		task.wait()
		for y = Y0, Y1, 1 do
			local base = w.face + w.axis * t
			base = Vector3.new(base.X, y, base.Z)
			local o = base + w.n * 6
			local c = workspace:Raycast(o, -w.n * 8, rp)
			-- only where the first queryable thing is this wall (doors / props / pillars have their own colliders)
			if c and c.Instance == w.part then
				local v = vhit(o, c.Position)
				if v then
					local p = (v - c.Position):Dot(w.n)
					if p > 0.05 and p <= MAXP then
						local b = math.floor((t + w.half) / BIN)
						bins[b] = math.max(bins[b] or 0, p)
					end
				end
			end
		end
	end
	-- merge neighbouring bins of about the same depth into one skin part
	local keys = {}
	for b in bins do table.insert(keys, b) end
	table.sort(keys)
	local runs, cur = {}, nil
	for _, b in keys do
		local d = math.ceil(bins[b] * 20) / 20
		if cur and b == cur.last + 1 and math.abs(d - cur.d) <= 0.1 then
			cur.last = b; cur.d = math.max(cur.d, d)
		else
			cur = { first = b, last = b, d = d }
			table.insert(runs, cur)
		end
	end
	for i, r in runs do
		local t0 = -w.half + r.first * BIN
		local t1 = math.min(-w.half + (r.last + 1) * BIN, w.half)
		local depth = r.d + OVERLAP
		local centreAlong = (t0 + t1) / 2
		local c = w.face + w.axis * centreAlong + w.n * (r.d - depth / 2)
		local yMid = (Y0 - 0.5 + Y1 + 0.5) / 2
		local size = w.axis == Vector3.xAxis and Vector3.new(t1 - t0, Y1 - Y0 + 1, depth) or Vector3.new(depth, Y1 - Y0 + 1, t1 - t0)
		table.insert(out, { name = ("COLP_CamSkin_%s_%d"):format(w.part.Name:gsub("^COLP_", ""), i),
			pos = { c.X, yMid, c.Z }, size = { size.X, size.Y, size.Z }, proud = r.d })
	end
end
return HS:JSONEncode(out)
