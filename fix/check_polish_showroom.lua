-- check_polish_showroom.lua (read-only; restores what it toggles): logic checks for Polish.Showroom (fix/polish_showroom.lua).
-- 1. hooks: Showroom.DisplayPoint / CameraPoint / BenchTop / KeyLight exist with the CFrames LobbyUIController.Armory reads
--    (values from notes/training_build.md + the 2026-10-16 survey); KeyLight keeps one SpotLight; Lights.* keep the RoomLight
--    tag and Room = Showroom; the Showroom light count is unchanged (6 RoomLight lights + KeyLight).
-- 2. sight: CameraPoint -> DisplayPoint and KeyLight -> DisplayPoint are clear; the cyclorama sits behind DisplayPoint and
--    fills the FOV-40 frame (every frame ray past the plinth ends on a Cyc part).
-- 3. clip (rays, centre to face centres + corners shrunk 0.05) against the visible Showroom geometry; support: every cyc
--    part touches its neighbour, lamp cans sit on the floor.
-- 4. budget: no Light / emitter in Polish.Showroom; new parts collidable 0, queryable 0.
local LM = workspace.LobbyMap
local S = LM.Showroom
local root = LM.Polish:FindFirstChild("Showroom")
assert(root, "run fix/polish_showroom.lua first")
local CS = game:GetService("CollectionService")
local out = {}
local function say(s) table.insert(out, s) end
local function near(a, b) return (a - b).Magnitude < 0.01 end

-- 1. hooks
local want = {DisplayPoint = Vector3.new(0, 406.3, 8), CameraPoint = Vector3.new(0, 407.4, -5), BenchTop = Vector3.new(0, 404.1, 8.5),
	KeyLight = Vector3.new(-3, 413.8, -1)}
for n, v in pairs(want) do
	local p = S:FindFirstChild(n)
	say(string.format("hook %s: %s", n, p and (near(p.Position, v) and "ok " .. tostring(p.Position) or "MOVED " .. tostring(p.Position)) or "MISSING"))
end
local spot = S.KeyLight:FindFirstChildWhichIsA("SpotLight")
say("KeyLight SpotLight: " .. (spot and string.format("ok br %.1f angle %d enabled %s", spot.Brightness, spot.Angle, tostring(spot.Enabled)) or "MISSING"))
local nRL = 0
for _, p in ipairs(CS:GetTagged("RoomLight")) do
	if p:GetAttribute("Room") == "Showroom" then for _, l in ipairs(p:GetDescendants()) do if l:IsA("Light") then nRL += 1 end end end
end
say("Showroom RoomLight lights: " .. nRL .. " (was 6)")
local bt = S.BenchTop
say(string.format("BenchTop top %.2f (kit bench top %.2f)", bt.Position.Y + bt.Size.Y / 2,
	(function() local b = S.Rooms4.SR_Stage.SR_Stage__bench_top; return b.Position.Y + b.Size.Y / 2 end)()))

-- 2. sight
local q = {}
for _, d in ipairs(S:GetDescendants()) do if d:IsA("BasePart") and d.Transparency < 0.95 and not d.CanQuery then d.CanQuery = true; table.insert(q, d) end end
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") and not d.CanQuery then d.CanQuery = true; table.insert(q, d) end end
local skip = {}
for _, d in ipairs(S:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local dp = S.DisplayPoint.Position
for _, n in ipairs({"CameraPoint", "KeyLight"}) do
	local a = S[n].Position
	local h = workspace:Raycast(a, dp - a, rp)
	say(n .. " -> DisplayPoint: " .. (h and ("BLOCKED by " .. h.Instance:GetFullName()) or "clear"))
end
local c = S.CameraPoint.CFrame
local tanV = math.tan(math.rad(20)); local tanH = tanV * 16 / 9
local nRay, nCyc, other = 0, 0, {}
for i = -4, 4 do for j = -4, 4 do
	local dir = (c.LookVector + c.RightVector * (i / 4) * tanH + c.UpVector * (j / 4) * tanV).Unit
	local h = workspace:Raycast(c.Position, dir * 120, rp)
	if h and not h.Instance:IsDescendantOf(S.Rooms4.SR_Stage) and not h.Instance:IsDescendantOf(S.Rooms4.SR_Signs) then
		nRay += 1
		if h.Instance:IsDescendantOf(root) then nCyc += 1 else other[h.Instance.Name] = (other[h.Instance.Name] or 0) + 1 end
	end
end end
local ot = {}
for k, v in pairs(other) do table.insert(ot, k .. " x" .. v) end
say(string.format("frame rays past the plinth: %d, on the cyclorama %d%s", nRay, nCyc, #ot > 0 and (" (else: " .. table.concat(ot, ", ") .. ")") or ""))

-- 3. clips + support
local clipSkip = {root}
for _, d in ipairs(skip) do table.insert(clipSkip, d) end
local rp2 = RaycastParams.new(); rp2.FilterType = Enum.RaycastFilterType.Exclude; rp2.FilterDescendantsInstances = clipSkip
local clips, seen = {}, {}
local nVis = 0
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and p.Transparency < 1 then
		nVis += 1
		local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
		hs = Vector3.new(math.max(hs.X, 0), math.max(hs.Y, 0), math.max(hs.Z, 0))
		local targets = {}
		for _, v in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, v * hs) end
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z))
		end end end
		for _, t in ipairs(targets) do
			local a = p.Position; local b = p.CFrame * t
			local h = workspace:Raycast(a, b - a, rp2)
			if h then
				local key = p.Name .. " x " .. h.Instance:GetFullName():gsub("Workspace.LobbyMap.Showroom.", "")
				if not seen[key] then seen[key] = true; table.insert(clips, key) end
			end
		end
	end
end
say("CLIPS (" .. #clips .. "; visible new parts " .. nVis .. ")")
for _, k in ipairs(clips) do say("  " .. k) end
local bad = {}
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and p.Name == "LampCan" then
		local h = workspace:Raycast(p.Position, Vector3.new(0, -(p.Size.Y / 2 + 0.2), 0), rp2)
		if not h then table.insert(bad, p.Name) end
	end
end
say("SUPPORT bad " .. #bad .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))

-- 4. budget
local nL, nE, nC, nQ = 0, 0, 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Light") then nL += 1 end
	if d:IsA("ParticleEmitter") or d:IsA("Beam") then nE += 1 end
	if d:IsA("BasePart") then
		local o = table.find(q, d) ~= nil
		if d.CanCollide then nC += 1 end
		if d.CanQuery and not o then nQ += 1 end
	end
end
say(string.format("BUDGET: lights %d, emitters %d, collidable %d, queryable %d", nL, nE, nC, nQ))
for _, d in ipairs(q) do d.CanQuery = false end
return table.concat(out, "\n")
