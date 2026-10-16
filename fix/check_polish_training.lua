-- check_polish_training.lua (read-only; restores what it toggles): logic checks for Polish.Training (fix/polish_training.lua).
-- 1. clip (rays): from each visible new part's centre to its 6 face centres and 8 corners (shrunk 0.05) against the old
--    visible Training geometry. Band pieces run into the perimeter Wall at their ends exactly like the original band did;
--    hits on Shell.Wall for band pieces count as support, not clips.
-- 2. support: ring edges wrap their old bastion / tower band; bands and letter plates have their wall within 0.05 behind them; floor plates, bin frames and stencils have the
--    floor / plaza / roof within 0.06 under them.
-- 3. read: every letter plate is fully visible (centre + 4 corners) from the plaza corner of its quadrant (B's east wall from
--    the east boulevard); every floor plate sits on its quadrant's side of the boulevard.
-- 4. gameplay untouched: no PolishTraining_Orig attribute stores a CFrame / Position / Size / Anchored / Parent key (except the
--    4 field DistSign boards, lowered 1.6 off the band), the only
--    hidden parts are the 5 old WallBands (already non-colliding), Training hooks and Extras counts, swap bins in place.
-- 5. budget: no Light / ParticleEmitter / Beam in Polish.Training; new parts collidable 0, queryable 0, touchable 0, all NotCover.
local LM = workspace.LobbyMap
local T = LM.Training
local R = T.Range2
local root = LM.Polish:FindFirstChild("Training")
assert(root, "run fix/polish_training.lua first")
local HttpService = game:GetService("HttpService")
local out = {}
local function say(s) table.insert(out, s) end

local newParts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(newParts, d) end end
local q = {}
for _, d in ipairs(T:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 then d.CanQuery = true; table.insert(q, d) end
end
local skip = {root}
for _, d in ipairs(T:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
for _, d in ipairs(T:GetDescendants()) do if d:IsA("Model") and (d.Name == "Dummy" or d:FindFirstChildOfClass("Humanoid")) then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip

-- 1. clips
local clips, seen, notes = {}, {}, {}
local nVis = 0
for _, p in ipairs(newParts) do
	if p.Transparency < 1 then
		nVis += 1
		local isBand = p.Name:find("^Band") ~= nil
		local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
		hs = Vector3.new(math.max(hs.X, 0), math.max(hs.Y, 0), math.max(hs.Z, 0))
		local targets = {}
		for _, v in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, v * hs) end
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z))
		end end end
		for _, t in ipairs(targets) do
			local a = p.Position; local b = p.CFrame * t
			local h = workspace:Raycast(a, b - a, rp)
			local inherited = p.Name:find("^BandEdge_Ring") and h and h.Instance.Name == "Truss"
			if inherited then
				local key = p.Name .. " x Truss (inherited: the old bastion band already runs 0.2 into this truss)"
				if not seen[key] then seen[key] = true; table.insert(notes, key) end
			elseif h and not (isBand and h.Instance.Name == "Wall") then
				local key = p.Name .. " x " .. h.Instance:GetFullName():gsub("Workspace.LobbyMap.", "")
				if not seen[key] then seen[key] = true; table.insert(clips, key) end
			end
		end
	end
end
say("CLIPS (" .. #clips .. "; visible new parts " .. nVis .. " of " .. #newParts .. ")")
for _, c in ipairs(clips) do say("  " .. c) end
for _, c in ipairs(notes) do say("  note: " .. c) end

-- 2. support
local bad = {}
local function behind(p, dist)
	local back = -p.CFrame.LookVector
	local a = p.Position
	local h = workspace:Raycast(a, back * (p.Size.Z / 2 + dist), rp)
	return h ~= nil
end
local function under(p, dist)
	local h = workspace:Raycast(p.Position, Vector3.new(0, -(p.Size.Y / 2 + dist), 0), rp)
	return h ~= nil
end
local nSup = 0
for _, p in ipairs(newParts) do
	local n = p.Name
	local ok = true
	if n:find("^Letter_") then ok = behind(p, 0.05)
	elseif n:find("^BandEdge_Ring") then
		-- ring edges wrap an old bastion / tower band: that band must sit inside the edge box's footprint
		ok = false
		for _, f in ipairs({R.Blocks, R.Towers}) do for _, b in ipairs(f:GetChildren()) do
			if b.Name == "Band" and math.abs(b.Position.X - p.Position.X) < 0.1 and math.abs(b.Position.Z - p.Position.Z) < 0.1
				and math.abs(b.Position.Y - p.Position.Y) < b.Size.Y / 2 then ok = true end
		end end
	elseif n:find("^Band") then
		-- band normal: from the band centre toward the nearest perimeter wall
		local pos = p.Position
		local dir
		if math.abs(pos.Z) > 127 then dir = Vector3.new(0, 0, math.sign(pos.Z)) else dir = Vector3.new(math.sign(pos.X), 0, 0) end
		local h = workspace:Raycast(pos, dir * 1.0, rp)
		ok = h ~= nil and h.Instance.Name == "Wall"
	elseif n:find("^Floor_") or n:find("^Bin") then ok = under(p, 0.06)
	end
	nSup += 1
	if not ok then table.insert(bad, n .. " at " .. tostring(p.Position)) end
end
say("SUPPORT bad " .. #bad .. " of " .. nSup)
for _, b in ipairs(bad) do say("  " .. b) end

-- 3. read
local EYE = {A = Vector3.new(-14, 605.5, 14), B = Vector3.new(14, 605.5, 14), C = Vector3.new(14, 605.5, -14), D = Vector3.new(-14, 605.5, -14)}
local nRead, blocked = 0, {}
for _, p in ipairs(root.Letters:GetChildren()) do
	local qd = p:GetAttribute("Quadrant")
	local eye = EYE[qd]
	if math.abs(p.Position.X - 127.88) < 0.5 and qd == "B" then eye = Vector3.new(20, 605.5, 0) end
	local all = true
	for _, o in ipairs({Vector3.zero, Vector3.new(7.5, 8.5, 0), Vector3.new(-7.5, 8.5, 0), Vector3.new(7.5, -8.5, 0), Vector3.new(-7.5, -8.5, 0)}) do
		local tgt = (p.CFrame * CFrame.new(o)).Position + p.CFrame.LookVector * 0.2
		local h = workspace:Raycast(eye, tgt - eye, rp)
		if h then all = false end
	end
	nRead += 1
	if not all then table.insert(blocked, p.Name) end
end
say("READ letter plates fully visible from their plaza corner: " .. (nRead - #blocked) .. "/" .. nRead .. (#blocked > 0 and (" blocked: " .. table.concat(blocked, ", ")) or ""))
local wrongSide = 0
local SIGN = {A = {-1, 1}, B = {1, 1}, C = {1, -1}, D = {-1, -1}}
for _, p in ipairs(root.FloorMarks:GetChildren()) do
	local s = SIGN[p:GetAttribute("Quadrant")]
	if math.sign(p.Position.X) ~= s[1] or math.sign(p.Position.Z) ~= s[2] then wrongSide += 1 end
end
say("floor plates " .. #root.FloorMarks:GetChildren() .. ", on the wrong quadrant side " .. wrongSide)

-- 4. gameplay untouched
local BADKEYS = {CFrame = true, Position = true, Size = true, Anchored = true, Parent = true, PivotOffset = true}
local nOrig, nBadKey, hidden = 0, 0, {}
for _, d in ipairs(LM:GetDescendants()) do
	local s = d:GetAttribute("PolishTraining_Orig")
	if s then
		nOrig += 1
		local o = HttpService:JSONDecode(s)
		for k in pairs(o) do if BADKEYS[k] and d.Name ~= "DistSign" then nBadKey += 1 end end
		if o.Transparency and d.Transparency >= 0.99 then
			table.insert(hidden, d.Name .. (o.CanCollide and o.CanCollide.v and " (WAS COLLIDING)" or ""))
		end
	end
end
say(string.format("touched %d instances, position/size keys %d, hidden %d: %s", nOrig, nBadKey, #hidden, table.concat(hidden, ", ")))
local gal = 0
for _, s in ipairs(T.EnemySpots:GetChildren()) do if s:GetAttribute("Gallery") then gal += 1 end end
local E = T.Extras
say(string.format("HOOKS: EnemySpots %d (gallery %d), Arrivals %d, TrainingArrive %s, Dummy template %s",
	#T.EnemySpots:GetChildren(), gal, #T.Arrivals:GetChildren(), tostring(T.TrainingArrive.Position),
	tostring(game.ServerStorage:FindFirstChild("RangeAssets") and game.ServerStorage.RangeAssets:FindFirstChild("Dummy") ~= nil)))
say(string.format("  Extras: JumpPads %d, Tightropes %d, SwapBins %d, DpsDummies %d, Bullseyes %d",
	#E.JumpPads:GetChildren(), #E.Tightropes:GetChildren(), #E.SwapBins:GetChildren(), #E.DpsDummies:GetChildren(), #E.Bullseyes:GetChildren()))
local binPos = {}
for _, b in ipairs(E.SwapBins:GetChildren()) do local p = b:GetPivot().Position; table.insert(binPos, string.format("%.0f,%.1f,%.0f", p.X, p.Y, p.Z)) end
say("  bins at " .. table.concat(binPos, " "))
local nR2, nCol = 0, 0
for _, d in ipairs(R:GetDescendants()) do if d:IsA("BasePart") then nR2 += 1; if d.CanCollide then nCol += 1 end end end
say(string.format("  Range2 parts %d (collidable %d)", nR2, nCol))

-- 5. budget
local nL, nE, nC, nQ, nT, nNC = 0, 0, 0, 0, 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Light") then nL += 1 end
	if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then nE += 1 end
	if d:IsA("BasePart") then
		if d.CanCollide then nC += 1 end
		if d.CanQuery then nQ += 1 end
		if d.CanTouch then nT += 1 end
		if not d:GetAttribute("NotCover") then nNC += 1 end
	end
end
say(string.format("BUDGET: lights %d, emitters/beams %d, collidable %d, queryable %d, touchable %d, without NotCover %d", nL, nE, nC, nQ, nT, nNC))

for _, d in ipairs(q) do d.CanQuery = false end
return table.concat(out, "\n")
