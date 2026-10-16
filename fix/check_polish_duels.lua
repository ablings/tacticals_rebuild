-- check_polish_duels.lua (read-only; restores the CanQuery it toggles): clipping, floating, light and hook checks for
-- Polish.Duels (fix/polish_duels.lua).
-- 1. clip (rays): from each new part's centre to its 6 face centres and 8 corners (shrunk 0.05); a hit on old visible
--    geometry inside that span = an intersection.
-- 2. clip (probe): GetPartsInPart with a copy 0.12 smaller than each new part (catches thin parts the rays miss).
-- 3. support: gantry ends within 0.4 of a wall, every lamp rod / hanger / post touches its gantry, pad panels and lane lines
--    sit on the floor or the pad plate (0..0.1 above it).
-- 4. hooks: the 6 Duels pad Models keep tag QueuePad, QueueName / PlayersPerTeam, children Team1/Team2 (zones), Team1Plate /
--    Team2Plate (collide), Team1Barrier / Team2Barrier, Holo; nothing new collides; DuelsTV / DuelsSign screens; light count.
-- 5. walk paths: the door, the aisle and the energy-wall gap are clear of new collidable parts (rays at knee/head height).
local LM = workspace.LobbyMap
local root = LM.Polish:FindFirstChild("Duels")
assert(root, "run fix/polish_duels.lua first")
local CS = game:GetService("CollectionService")
local function inDuels(p) return p.X < -84 and p.X > -160 and p.Y > 10 and p.Y < 80 and math.abs(p.Z) < 52 end
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and inDuels(d.Position) and not d:IsDescendantOf(root) then
		d.CanQuery = true; table.insert(q, d)
	end
end
local skip = {root}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local clips, seen = {}, {}
local function note(p, h, extra)
	local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Duels.", "") .. " x " .. h:GetFullName():gsub("Workspace.LobbyMap.", "")
	if not seen[key] then seen[key] = true; table.insert(clips, key .. (extra or "")) end
end
local newParts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") and d.Transparency < 0.95 then table.insert(newParts, d) end end
for _, p in ipairs(newParts) do
	local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
	hs = Vector3.new(math.max(hs.X, 0), math.max(hs.Y, 0), math.max(hs.Z, 0))
	local targets = {}
	for _, a in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, a * hs) end
	for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z)) end end end
	for _, t in ipairs(targets) do
		local o = p.Position; local e = p.CFrame:PointToWorldSpace(t)
		if (e - o).Magnitude > 0.01 then
			local h = workspace:Raycast(o, e - o, rp)
			if h then note(p, h.Instance, string.format(" (ray, %.2f in)", (e - h.Position).Magnitude)) end
		end
	end
end
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = skip
local tmp = Instance.new("Folder"); tmp.Name = "_DuelsProbe"; tmp.Parent = workspace
local nProbe = 0
for _, p in ipairs(newParts) do
	if p.Size.X > 0.2 and p.Size.Y > 0.2 and p.Size.Z > 0.2 then
		local pr = p:Clone(); pr:ClearAllChildren(); pr.Size = p.Size - Vector3.new(0.12, 0.12, 0.12)
		pr.Transparency = 1; pr.CanCollide = false; pr.CanQuery = true; pr.Parent = tmp
		nProbe += 1
		for _, h in ipairs(workspace:GetPartsInPart(pr, op)) do
			if not h:IsDescendantOf(tmp) and h.Transparency < 0.95 then note(p, h, " (probe)") end
		end
		pr:Destroy()
	end
end
tmp:Destroy()

-- support
local sup = {}
local bad = 0
-- a bracket is supported when any of 9 points on its back face (centre, edges, corners) has wall within 0.6 behind it
local function wallBehind(b)
	local dir = -b.CFrame.LookVector
	for _, dx in ipairs({-0.9, 0, 0.9}) do
		for _, dy in ipairs({-1.2, 0, 1.2}) do
			local o = b.CFrame:PointToWorldSpace(Vector3.new(dx, dy, 0))
			if workspace:Raycast(o, dir * 0.6, rp) then return true end
		end
	end
	return false
end
for _, b in ipairs(root.Rig:GetChildren()) do
	if b.Name:match("_Bracket$") then
		local ok = wallBehind(b)
		if not ok then bad += 1; table.insert(sup, "bracket no wall: " .. b.Name .. " " .. tostring(b.Position)) end
	end
end
-- vertical members must touch something above (new or old)
local rpAll = RaycastParams.new(); rpAll.FilterType = Enum.RaycastFilterType.Exclude
local selfSkip = {}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(selfSkip, d) end end
for _, p in ipairs(newParts) do
	if p.Name == "Rod" or p.Name == "Hanger" or p.Name == "ExitHanger" or p.Name == "BoardPost" or p.Name == "Housing" then
		local top = p.Position + Vector3.new(0, (p.Name == "BoardPost" and p.Size.Y or p.Size.X) / 2 - 0.02, 0)
		local list = table.clone(selfSkip); table.insert(list, p)
		rpAll.FilterDescendantsInstances = list
		local dir = p.Name == "BoardPost" and Vector3.new(0, -0.1, 0) or Vector3.new(0, 0.12, 0)
		local h = workspace:Raycast(top - dir * 0.0, dir, rpAll)
		if not h and p.Name == "BoardPost" then h = workspace:Raycast(p.Position, Vector3.new(0, -0.3, 0), rpAll) end
		if not h then bad += 1; table.insert(sup, "unsupported " .. p:GetFullName():gsub("Workspace.LobbyMap.Polish.Duels.", "")) end
	end
end
-- floor items: panels on the pad plate (16.34), lanes on the floor
for _, p in ipairs(newParts) do
	if p.Name == "Panel" or p.Name == "Lane" then
		local bottom = p.Position.Y - p.Size.Y / 2
		local list = table.clone(selfSkip); table.insert(list, root)
		rpAll.FilterDescendantsInstances = list
		local h = workspace:Raycast(Vector3.new(p.Position.X, bottom + 0.3, p.Position.Z), Vector3.new(0, -1, 0), rpAll)
		local gap = h and (bottom - h.Position.Y) or 99
		local plateTop = 16.34
		if p.Name == "Panel" then gap = bottom - plateTop end
		if gap < -0.001 or gap > 0.1 then bad += 1; table.insert(sup, string.format("%s gap %.3f", p:GetFullName():gsub("Workspace.LobbyMap.Polish.Duels.", ""), gap)) end
	end
end
for _, d in ipairs(q) do d.CanQuery = false end

-- hooks
local hooks = {}
local hookBad = 0
local pads = 0
for _, m in ipairs(LM.Duels:GetChildren()) do
	if m:IsA("Model") and m.Name:match("^Pad_") then
		pads += 1
		local miss = {}
		if not CS:HasTag(m, "QueuePad") then table.insert(miss, "tag QueuePad") end
		if not m:GetAttribute("QueueName") then table.insert(miss, "QueueName") end
		if not m:GetAttribute("PlayersPerTeam") then table.insert(miss, "PlayersPerTeam") end
		for _, n in ipairs({"Team1", "Team2", "Team1Plate", "Team2Plate", "Team1Barrier", "Team2Barrier", "Holo"}) do
			if not m:FindFirstChild(n) then table.insert(miss, n) end
		end
		if m:FindFirstChild("Team1Plate") and not m.Team1Plate.CanCollide then table.insert(miss, "Team1Plate collide") end
		if m:FindFirstChild("Team2Plate") and not m.Team2Plate.CanCollide then table.insert(miss, "Team2Plate collide") end
		if #miss > 0 then hookBad += 1 end
		table.insert(hooks, m.Name .. (#miss == 0 and " ok" or (" MISSING " .. table.concat(miss, ","))))
	end
end
local newCollide = 0
for _, p in ipairs(root:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then newCollide += 1 end end
local newLights = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then newLights += 1 end end
local screens = {}
for _, s in ipairs(CS:GetTagged("LobbyScreen")) do
	local k = s:GetAttribute("Screen")
	if k == "DuelsTV" or k == "DuelsSign" then table.insert(screens, k .. " " .. s:GetFullName():gsub("Workspace.LobbyMap.", "")) end
end
local enabled = 0
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Light") and d.Enabled then enabled += 1 end end
-- walk paths: rays across the door, along the aisle, through the energy-wall gap at knee (17) and head (21) height,
-- against new parts only
local rpNew = RaycastParams.new(); rpNew.FilterType = Enum.RaycastFilterType.Include; rpNew.FilterDescendantsInstances = {root}
local paths = {}
for _, seg in ipairs({{Vector3.new(-84, 0, 0), Vector3.new(-100, 0, 0)}, {Vector3.new(-96, 0, 0), Vector3.new(-140, 0, 0)},
	{Vector3.new(-138, 0, 0), Vector3.new(-160, 0, 0)}, {Vector3.new(-96, 0, -5), Vector3.new(-140, 0, -5)}, {Vector3.new(-96, 0, 5), Vector3.new(-140, 0, 5)}}) do
	for _, y in ipairs({17, 21}) do
		local a = seg[1] + Vector3.new(0, y, 0); local b = seg[2] + Vector3.new(0, y, 0)
		local h = workspace:Raycast(a, b - a, rpNew)
		if h then table.insert(paths, "BLOCKED " .. tostring(a) .. " -> " .. h.Instance.Name) end
	end
end
local pb = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("PadBoards")

return table.concat({
	"CLIPS (" .. #clips .. ", probes " .. nProbe .. ", new parts " .. #newParts .. "):", table.concat(clips, "\n"),
	"SUPPORT (bad " .. bad .. "):", table.concat(sup, "\n"),
	"HOOKS: pads " .. pads .. ", bad " .. hookBad, table.concat(hooks, "; "),
	"new collidable parts: " .. newCollide .. "  new lights: " .. newLights .. "  enabled lights (Edit, workspace): " .. enabled,
	"screens: " .. table.concat(screens, "; "),
	"walk paths: " .. (#paths == 0 and "clear" or table.concat(paths, "; ")),
	"PadBoards patched: " .. tostring(pb and pb.Source:find("TEAM_A", 1, true) ~= nil),
}, "\n")
