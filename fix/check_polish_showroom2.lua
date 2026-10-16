-- check_polish_showroom2.lua (read-only): hooks, light budget, flags, item clearance and frame coverage for polish_showroom2.
-- Run: python tools/run_luau.py fix/check_polish_showroom2.lua
local CS = game:GetService("CollectionService")
local LM = workspace.LobbyMap
local S = LM.Showroom
local R2 = LM.Polish:FindFirstChild("Showroom2")
local out = {}
local function say(s) table.insert(out, s) end
local function f(v) return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z) end
if not R2 then return "Showroom2 missing" end
-- 1. hooks
local d, c, b, k = S.DisplayPoint, S.CameraPoint, S.BenchTop, S.KeyLight
say("DisplayPoint " .. f(d.Position) .. " | CameraPoint " .. f(c.Position) .. " look " .. f(c.CFrame.LookVector) ..
	" | BenchTop " .. f(b.Position) .. " top " .. string.format("%.3f", b.Position.Y + b.Size.Y / 2) .. " | KeyLight " .. f(k.Position))
local ok = (d.Position - Vector3.new(0, 406.3, 8)).Magnitude < 1e-3 and (c.Position - Vector3.new(0, 407.4, -5)).Magnitude < 1e-3
	and (b.Position - Vector3.new(0, 404.1, 8.5)).Magnitude < 1e-3 and (k.Position - Vector3.new(-3, 413.8, -1)).Magnitude < 1e-3
say("hooks unchanged: " .. tostring(ok))
-- 2. lights
local n, en = 0, 0
for _, p in CS:GetTagged("RoomLight") do
	if p:GetAttribute("Room") == "Showroom" then
		n += 1
		for _, l in p:GetChildren() do if l:IsA("Light") then en += 1 end end
	end
end
say(("Showroom RoomLights: %d holders, %d child lights (round 1: 6; budget +3)"):format(n, en))
local stray = 0
for _, l in R2:GetDescendants() do
	if l:IsA("Light") and not CS:HasTag(l.Parent, "RoomLight") then stray += 1 end
end
say("untagged lights in Showroom2: " .. stray)
-- 3. flags
local bad, parts = 0, 0
for _, p in R2:GetDescendants() do
	if p:IsA("BasePart") then
		parts += 1
		if p.CanCollide or p.CanQuery or p.CanTouch then bad += 1 end
	end
end
say(("Showroom2 parts %d, collide/query/touch on: %d"):format(parts, bad))
-- 4. clearance: the largest item fits a sphere r = 7.5 * 1.05 / 2 = 3.94 around DisplayPoint (any rotation)
local Rr = 7.5 * 1.05 / 2
local inside = {}
for _, p in R2:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		local lp = p.CFrame:PointToObjectSpace(d.Position)
		local h = p.Size / 2
		local cl = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
		local dist = (lp - cl).Magnitude
		if dist < Rr then table.insert(inside, p.Name .. string.format(" %.2f", dist)) end
	end
end
say("new parts inside the item sphere (r 3.94): " .. (#inside == 0 and "none" or table.concat(inside, ", ")))
-- 5. frame coverage: rays from CameraPoint at FOV 40 over 16:9 and 21:9; what do they hit first past the item?
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
local vis = {}
for _, dd in ipairs(LM:GetDescendants()) do -- merged kit MeshParts (SR_Shell, SR_Signs, ...) have room-sized boxes: a box test can't use them, so the room kit counts
-- as "other" only through SR_Stage (the bench); anything not hitting the set or the bench is reported as a gap
	if dd:IsA("BasePart") and dd.Transparency < 1 and dd.Position.Y > 380 and dd.Position.Y < 450
		and (dd:IsDescendantOf(R2) or dd:IsDescendantOf(S.Rooms4.SR_Stage)) then table.insert(vis, dd) end end
rp.FilterDescendantsInstances = vis
local cnt = {}
local tanV = math.tan(math.rad(20))
for _, aspect in ipairs({16 / 9, 21 / 9}) do
	local tot, set, bench, other = 0, 0, 0, {}
	for iy = 0, 8 do for ix = 0, 12 do
		local sx, sy = (ix / 12 * 2 - 1) * tanV * aspect, (1 - iy / 8 * 2) * tanV
		local dir = (c.CFrame.LookVector + c.CFrame.RightVector * sx + c.CFrame.UpVector * sy).Unit
		-- query needs CanQuery: test geometrically by temporarily using a raycast against parts with CanQuery off is impossible,
		-- so cast against the visible list with a quick box test instead
		local best, bestT = nil, math.huge
		for _, p in ipairs(vis) do
			local o = p.CFrame:PointToObjectSpace(c.Position)
			local v = p.CFrame:VectorToObjectSpace(dir)
			local h = p.Size / 2
			local t0, t1 = -math.huge, math.huge
			local hit = true
			for _, ax in ipairs({"X", "Y", "Z"}) do
				local oa, va, ha = o[ax], v[ax], h[ax]
				if math.abs(va) < 1e-9 then
					if oa < -ha or oa > ha then hit = false break end
				else
					local a, bb = (-ha - oa) / va, (ha - oa) / va
					if a > bb then a, bb = bb, a end
					t0, t1 = math.max(t0, a), math.min(t1, bb)
					if t0 > t1 then hit = false break end
				end
			end
			if hit and t0 > 0.5 and t0 < bestT then bestT, best = t0, p end
		end
		tot += 1
		if best and best:IsDescendantOf(R2) then set += 1
		elseif best and best:IsDescendantOf(S.Rooms4.SR_Stage) then bench += 1
		else local nm = best and best:GetFullName() or "nothing"; other[nm] = (other[nm] or 0) + 1 end
	end end
	local os = {}
	for nm, k2 in pairs(other) do table.insert(os, nm .. " x" .. k2) end
	say(("aspect %.2f: %d rays -> set %d, bench %d, other: %s"):format(aspect, tot, set, bench, #os == 0 and "none" or table.concat(os, "; ")))
	task.wait()
end
return table.concat(out, "\n")
