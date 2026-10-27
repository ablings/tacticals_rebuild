-- client step 2 (round 6): walk the hall at player height and push into both shut doors (they must stop the player at the
-- curtain), Space at a shutter (NotCover: no climb), cover on a few pieces
char = lp.Character; hum = char:FindFirstChildOfClass("Humanoid"); root = char:FindFirstChild("HumanoidRootPart")
-- walk along a PathfindingService path (radius 1.2, height 5, no jumping), waypoint by waypoint
local PFS = game:GetService("PathfindingService")
local function pathTo(e, n, t)
	local path = PFS:CreatePath({ AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false })
	local t0 = os.clock()
	local ok = pcall(function() path:ComputeAsync(root.Position, W(e, n, 0)) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return os.clock() - t0, false, -1 end
	for _, wp in path:GetWaypoints() do
		local p = plan(wp.Position)
		walkTo(p.X, p.Y, 4)
		if os.clock() - t0 > (t or 30) then break end
	end
	local d = ((root.Position - W(e, n, 0)) * Vector3.new(1, 0, 1)).Magnitude
	return os.clock() - t0, d < 1.5, d
end
local function leg(name, e, n, t)
	local dt, ok, d = pathTo(e, n, t or 30)
	log(string.format("walk %-22s %s %.1fs %s", name, ok and "ARRIVED" or ("STOPPED d=" .. string.format("%.1f", d)), dt, where()))
end
local function push(name, e0, n0, e1, n1)
	place(e0, n0, 0, e1 - e0, n1 - n0)
	local top = -1e9
	local maxN, minN = -1e9, 1e9
	hum:MoveTo(W(e1, n1, 0))
	local t0 = os.clock()
	while os.clock() - t0 < 5 do
		local p = plan(root.Position)
		maxN, minN = math.max(maxN, p.Y), math.min(minN, p.Y)
		top = math.max(top, feet())
		if os.clock() - t0 > 1.5 and os.clock() - t0 < 3.5 then hum.Jump = true end
		task.wait(0.05)
	end
	log(string.format("push %-18s ended %s  n reached %.2f..%.2f  top feet %.2f", name, where(), minN, maxN, top))
	return maxN, minN
end
local PART = "push" --@PART
if PART == "legs" then
leg("south door (inside)", 0, -54)
leg("west lane", -35, 19)
leg("north door (inside)", 0, 54)
leg("east lane", 34, -19.5)
leg("centre", 0.5, -0.5)
elseif PART == "push" then
local _, minS = push("S door", 0, -50, 0, -75)
local maxN = push("N door", 0, 50, 0, 75)
push("S door left", -8, -50, -8, -75)
push("N door right", 8, 50, 8, 75)
log(string.format("DOORS STOP: south min n %.2f (curtain at -57.45), north max n %.2f (curtain at 57.45)", minS, maxN))
place(0, -55.5, 0, 0, -1)
log("Space (cover vault/climb) at S shutter", fmt(act("Jump", 0, -57.5, 2)), where())
task.wait(1)
log("   after", where())
else
for _, c in { { "L03 jersey", -12, -21.5, -12, -19 }, { "C01 crate", -5, -11, -5, -8 }, { "P01 pallet stack", -29, -48, -29, -44 }, { "W01 block wall", -16, 3, -16, 6 } } do
	place(c[2], c[3], 0, c[4] - c[2], c[5] - c[3])
	walkTo(c[4], c[5] - (c[5] > c[3] and 2.2 or -2.2), 3)
	log(string.format("cover %-16s %s", c[1], fmt(act("Cover", c[4], c[5], 2))))
	if c[1]:find("L03") then act("Jump", c[4], c[5], 2) waitIdle(2) log("   vault over L03 ->", where()) end
	act("Cover")
	waitIdle(2)
end
end
return table.concat(LOG, "\n")
