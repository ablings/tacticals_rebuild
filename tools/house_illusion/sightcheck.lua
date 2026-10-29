-- House illusion sight check (Edit or Play server): from every clear window's standing and crouched eye, rays over the window's
-- outward fan (azimuth -50..50 deg, elevation -4..+6 deg) report WHAT EACH RAY HITS FIRST, by owner (top-level Workspace child).
-- Art has CanQuery off, so every visible part (House, HouseExterior, HouseFarField, other maps, Baseplate) is made queryable for
-- the check and put back after; window glass and invisible parts stay out. A hit on a foreign owner (another map, the place's
-- Baseplate, dev rigs) or a miss (sky below +0.5 deg) is a leak. Grader r1 lesson: report first hits by owner, not only misses.
-- WINDOWS is filled by the runner: { name, ex, ey, ez, ox, oz } in world coordinates
local WINDOWS = {} --@WINDOWS
local AZR, AZS, ELS = 50, 2, 1 --@STEP (the runner may set 70, 0.5, 0.5: a 2-degree grid missed a 1-2 degree gap, grade r3)
local OWN = { House = true, HouseExterior = true, HouseFarField = true }
local changed = {}
local function prep(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and d.Material ~= Enum.Material.Glass then
			table.insert(changed, d); d.CanQuery = true
		end
	end
end
for _, c in workspace:GetChildren() do
	if c:IsA("Model") or c:IsA("Folder") then prep(c) elseif c:IsA("BasePart") and c.Transparency < 0.95 and not c.CanQuery then table.insert(changed, c); c.CanQuery = true end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local skip = {}
for _, p in game:GetService("Players"):GetPlayers() do if p.Character then table.insert(skip, p.Character) end end
-- invisible parts (e.g. a look hidden while the map is loaded: MapInfo.Hide) are not seen, so rays pass them
for _, d in workspace:GetDescendants() do if d:IsA("BasePart") and d.Transparency >= 0.95 and d.CanQuery then table.insert(skip, d) end end
params.FilterDescendantsInstances = skip
local leaks, total, byOwner, examples = 0, 0, {}, {}
local ok, err = pcall(function()
	for _, w in WINDOWS do
		local name, ex, ey, ez, ox, oz = w[1], w[2], w[3], w[4], w[5], w[6]
		local base = math.atan2(ox, -oz)
		for azd = -AZR, AZR, AZS do
			for eld = -4, 8, ELS do
				local az, el = base + math.rad(azd), math.rad(eld)
				local dir = Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el))
				local o = Vector3.new(ex, ey, ez)
				-- start just outside the wall plane (the eye stands 3.5 inside it) so the frame and sill don't stop every ray
				local r = workspace:Raycast(o, dir * 6000, params)
				total += 1
				local owner
				if r then
					local inst = r.Instance
					while inst.Parent and inst.Parent ~= workspace do inst = inst.Parent end
					owner = inst.Name
				else
					owner = (eld >= 1) and "sky" or "MISS(sky below horizon)"
				end
				if owner ~= "sky" and not OWN[owner] then
					leaks += 1
					byOwner[owner] = (byOwner[owner] or 0) + 1
					local k = owner .. "@" .. name
					if not examples[k] then examples[k] = ("%s az%+.1f el%+.1f d%.0f"):format(name, azd, eld, r and r.Distance or -1) end
				end
			end
		end
	end
end)
for _, d in changed do d.CanQuery = false end
assert(ok, err)
local t = {} for o, n in byOwner do table.insert(t, o .. " " .. n) end
local e = {} for _, v in examples do table.insert(e, v) end table.sort(e)
return ("rays %d, foreign/miss %d | %s\n%s"):format(total, leaks, table.concat(t, ", "), table.concat(e, "\n"))
