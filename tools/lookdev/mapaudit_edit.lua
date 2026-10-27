-- MapAudit: the automated part of the vault's Map Proof Check (03 Map Building/Map Proof Check). Read-only scan of a map
-- that is in Workspace (run it in Play, where nothing you place persists). tools/run_checks.py --map runs it on every
-- ServerStorage.KitMaps map by placing a copy in the Play server.
--   MapAudit.run(root: Instance, opts?) -> report
--     opts = { indoor = bool (default: root attribute Indoor), grid = 4 (studs), maxCells = 6000 }
--   report = { fails = n, warns = n, findings = { {level, code, where, message} }, stats = {...} }
-- Checks:
--   ZFIGHT   two parts with parallel faces in the same plane (< 0.02 apart) that overlap: flicker ("glitchy overlapping")
--   ANCHOR   unanchored parts in a static map (they fall or get pushed)
--   SPAWN    a spawn (Spawns.A*/B*) with no floor within 6 studs below, or less than 6 studs of headroom
--   HOLE     a floor cell next to walkable floor where the drop is > 12 studs, or no floor at all inside the outline (a
--            pit / slot nobody planned): tag the floor part on either side of the drop (or a model it is in)
--            KitIntendedDrop, or give the map attribute AllowDrops, to accept them
--   SKY      indoor maps only: walkable cells with nothing above (a hole in the roof)
--   stats    parts, meshparts, lights, neon parts, open-sky share
local CollectionService = game:GetService("CollectionService")

local MapAudit = {}
local EPS = 0.02

local function add(r, level, code, where, msg)
	table.insert(r.findings, { level = level, code = code, where = where, message = msg })
	if level == "FAIL" then r.fails += 1 else r.warns += 1 end
end

-- axis-aligned faces of a block part (rotations in 90 degree steps only; other parts are skipped for ZFIGHT)
local function faces(p)
	if not p:IsA("Part") or p.Shape ~= Enum.PartType.Block then return nil end
	local cf = p.CFrame
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.999 then return nil end -- rotated off-axis: skip
	end
	-- axis-aligned box: its six faces are the slabs of its world bounding box
	local half = cf:VectorToWorldSpace(p.Size / 2)
	half = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
	local lo, hi = cf.Position - half, cf.Position + half
	local out = {}
	for _, k in { "X", "Y", "Z" } do
		table.insert(out, { axis = k, sign = -1, plane = lo[k], lo = lo, hi = hi })
		table.insert(out, { axis = k, sign = 1, plane = hi[k], lo = lo, hi = hi })
	end
	return out
end

local function overlapArea(a, b, k)
	local dims = k == "X" and { "Y", "Z" } or k == "Y" and { "X", "Z" } or { "X", "Y" }
	local area = 1
	for _, d in dims do
		local o = math.min(a.hi[d], b.hi[d]) - math.max(a.lo[d], b.lo[d])
		if o <= 0.01 then return 0 end
		area *= o
	end
	return area
end

function MapAudit.run(root, opts)
	opts = opts or {}
	local indoor = opts.indoor
	if indoor == nil then indoor = root:GetAttribute("Indoor") == true end
	local r = { fails = 0, warns = 0, findings = {}, stats = {} }
	local parts, nParts, nMesh, nLights, nNeon = {}, 0, 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			nParts += 1
			if d:IsA("MeshPart") then nMesh += 1 end
			if d.Material == Enum.Material.Neon then nNeon += 1 end
			if d.Transparency < 1 then table.insert(parts, d) end
			local model = d:FindFirstAncestorWhichIsA("Model")
			local inCharacter = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
			if not d.Anchored and not d:FindFirstAncestorOfClass("Tool") and not inCharacter then
				add(r, "FAIL", "ANCHOR", d:GetFullName(), "unanchored part in a static map")
			end
		elseif d:IsA("Light") then
			nLights += 1
		end
	end
	r.stats = { parts = nParts, meshparts = nMesh, lights = nLights, neon = nNeon }

	-- ZFIGHT: bucket faces by axis + plane (0.5 stud slots); compare within a slot and with the next slot, so two planes
	-- 0.01 apart on either side of a slot edge are still compared
	local buckets = {}
	for _, p in parts do
		local fs = faces(p)
		if fs then
			for _, f in fs do
				f.part = p
				local slot = math.floor(f.plane / 0.5)
				buckets[f.axis] = buckets[f.axis] or {}
				buckets[f.axis][slot] = buckets[f.axis][slot] or {}
				table.insert(buckets[f.axis][slot], f)
			end
		end
	end
	local zf = 0
	local function compare(a, b)
		if a.part == b.part or a.sign ~= b.sign or math.abs(a.plane - b.plane) >= EPS then return end
		local area = overlapArea(a, b, a.axis)
		if area <= 0.05 then return end
		zf += 1
		if zf <= 25 then
			add(r, "FAIL", "ZFIGHT", a.part:GetFullName() .. " + " .. b.part.Name,
				string.format("faces in the same plane overlap %.1f sq studs (move one 0.12+ off, or overlap solidly)", area))
		end
	end
	for _, slots in buckets do
		for slot, list in slots do
			local nextSlot = slots[slot + 1] or {}
			for i = 1, #list do
				for j = i + 1, #list do compare(list[i], list[j]) end
				for _, f in nextSlot do compare(list[i], f) end
			end
		end
	end
	if zf > 25 then add(r, "FAIL", "ZFIGHT", root.Name, (zf - 25) .. " more z-fighting pairs") end

	-- walk grid: floors, holes, sky
	local cf, size = root:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { root }
	local grid = opts.grid or 4
	local nx, nz = math.floor(size.X / grid), math.floor(size.Z / grid)
	while nx * nz > (opts.maxCells or 6000) do grid *= 1.5; nx, nz = math.floor(size.X / grid), math.floor(size.Z / grid) end
	local top = cf.Position.Y + size.Y / 2 + 5
	local floorY, floorPart = {}, {}
	for ix = 0, nx do
		for iz = 0, nz do
			local p = cf.Position + Vector3.new(-size.X / 2 + ix * grid, 0, -size.Z / 2 + iz * grid)
			local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, -(size.Y + 20), 0), params)
			floorY[ix .. "," .. iz] = hit and hit.Position.Y or false
			floorPart[ix .. "," .. iz] = hit and hit.Instance or nil
		end
	end
	-- a drop is planned when the floor part on either side (or a model it is in) is tagged KitIntendedDrop
	local function intended(inst)
		while inst and inst ~= root do
			if CollectionService:HasTag(inst, "KitIntendedDrop") then return true end
			inst = inst.Parent
		end
		return false
	end
	local holes, sky, walk = 0, 0, 0
	local allowDrops = root:GetAttribute("AllowDrops") == true
	for ix = 0, nx do
		for iz = 0, nz do
			local y = floorY[ix .. "," .. iz]
			if y then
				walk += 1
				local p = cf.Position + Vector3.new(-size.X / 2 + ix * grid, 0, -size.Z / 2 + iz * grid)
				local up = workspace:Raycast(Vector3.new(p.X, y + 3, p.Z), Vector3.new(0, size.Y + 50, 0), params)
				if not up then sky += 1 end
				local planned = allowDrops or intended(floorPart[ix .. "," .. iz])
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nk = (ix + d[1]) .. "," .. (iz + d[2])
					local ny = floorY[nk]
					if planned or (ny and intended(floorPart[nk])) then
						continue
					elseif ny == false then
						-- a missing floor right next to floor, inside the map's outline: a hole (outer edge excluded)
						if ix + d[1] > 0 and ix + d[1] < nx and iz + d[2] > 0 and iz + d[2] < nz then holes += 1 end
					elseif ny and y - ny > 12 then
						holes += 1
					end
				end
			end
		end
	end
	r.stats.walkCells, r.stats.openSkyShare = walk, walk > 0 and math.floor(sky / walk * 100 + 0.5) or 0
	if holes > 0 then add(r, "WARN", "HOLE", root.Name, holes .. " floor-edge cells with a drop > 12 studs or no floor (check them; tag intended drops)") end
	if indoor and sky > 0 then add(r, "FAIL", "SKY", root.Name, sky .. " walkable cells see the sky in an indoor map (roof hole)") end

	-- spawns
	local spawns = root:FindFirstChild("Spawns")
	for _, s in (spawns and spawns:GetChildren() or {}) do
		if s:IsA("BasePart") then
			local ex = RaycastParams.new()
			ex.FilterType = Enum.RaycastFilterType.Exclude
			ex.FilterDescendantsInstances = { spawns }
			local down = workspace:Raycast(s.Position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), ex)
			local up = workspace:Raycast(s.Position + Vector3.new(0, 1, 0), Vector3.new(0, 6, 0), ex)
			if not down then add(r, "FAIL", "SPAWN", s:GetFullName(), "no floor within 6 studs below") end
			if up then add(r, "FAIL", "SPAWN", s:GetFullName(), "less than 6 studs of headroom (" .. up.Instance.Name .. ")") end
		end
	end
	return r
end


local out = {}
for _, k in { "A", "B", "C", "D", "E" } do
  local bay = workspace.Lookdev:FindFirstChild("Bay_" .. k)
  local r = MapAudit.run(bay)
  table.insert(out, ("Bay_%s fails=%d warns=%d stats=%s"):format(k, r.fails, r.warns, game:GetService("HttpService"):JSONEncode(r.stats)))
  for _, f in r.findings do table.insert(out, ("  %s %s %s: %s"):format(f.level, f.code, f.where, f.message)) end
end
return table.concat(out, "\n")
