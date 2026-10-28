-- client step 2: walk every room at player height (PathfindingService, radius 1.2, height 5, no jumping), both floors and both
-- stairs; then push + jump into windows, locked doors, the gallery railing and the main stair's open side (nothing gets out)
char = lp.Character; hum = char:FindFirstChildOfClass("Humanoid"); root = char:FindFirstChild("HumanoidRootPart")
local PFS = game:GetService("PathfindingService")
local function pathTo(x, y, h, t)
	local path = PFS:CreatePath({ AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false })
	local t0 = os.clock()
	local ok = pcall(function() path:ComputeAsync(root.Position, W(x, y, h or 0)) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return os.clock() - t0, false, -1 end
	for _, wp in path:GetWaypoints() do
		local p = plan(wp.Position)
		local target = W(p.X, p.Y, p.Z)
		local done = false
		local c = hum.MoveToFinished:Connect(function() done = true end)
		hum:MoveTo(target)
		local t1 = os.clock()
		while not done and os.clock() - t1 < 4 do task.wait(0.05) end
		c:Disconnect()
		if os.clock() - t0 > (t or 40) then break end
	end
	local p = plan(root.Position)
	local d = Vector2.new(p.X - x, p.Y - y).Magnitude
	return os.clock() - t0, d < 1.6 and math.abs(feet() - (h or 0)) < 1.6, d
end
local function leg(name, x, y, h)
	local dt, ok, d = pathTo(x, y, h)
	log(string.format("walk %-24s %s %.1fs %s", name, ok and "ARRIVED" or ("STOPPED d=" .. string.format("%.1f", d)), dt, where()))
end
local function push(name, x0, y0, h0, x1, y1, box)
	place(x0, y0, h0, x1 - x0, y1 - y0)
	local top, out = -1e9, false
	hum:MoveTo(W(x1, y1, h0))
	local t0 = os.clock()
	local ext = { x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9 }
	while os.clock() - t0 < 4.5 do
		local p = plan(root.Position)
		ext.x0, ext.x1, ext.y0, ext.y1 = math.min(ext.x0, p.X), math.max(ext.x1, p.X), math.min(ext.y0, p.Y), math.max(ext.y1, p.Y)
		top = math.max(top, feet())
		if p.X < box[1] or p.X > box[2] or p.Y < box[3] or p.Y > box[4] then out = true end
		if os.clock() - t0 > 1 then hum.Jump = true end
		hum:MoveTo(W(x1, y1, h0))
		task.wait(0.05)
	end
	log(string.format("push %-22s %s  x %.2f..%.2f y %.2f..%.2f top feet %.2f %s", name, where(), ext.x0, ext.x1, ext.y0, ext.y1, top, out and "OUT!" or "stayed in"))
end
local PART = (PARTX or "legs") --@PART
if PART == "legs" then
	leg("LR (spawn A side)", -30, 0)
	leg("foyer", 0, -20)
	leg("landing via main stair", 0, 0, 14)
	leg("master bedroom", -28, -8, 14)
	leg("bedroom 2", 26, -14, 14)
	leg("upper hall", -3, 10, 14)
	leg("bedroom 3", -25, 18, 14)
	leg("upper bathroom", -5, 22, 14)
	leg("back hall via back stair", 0, 26, 0)
	leg("mudroom", -16, 20, 0)
	leg("ground bathroom", -32, 20, 0)
	leg("kitchen", 30, 0, 0)
	leg("dining room", 25, -26, 0)
	leg("cross hall", -5, 0, 0)
	leg("living room spawn", -35, -19, 0)
elseif PART == "legs2" then
	leg("kitchen", 30, 0, 0)
	leg("dining room", 25, -26, 0)
	leg("cross hall", -5, 0, 0)
	leg("upstairs via back stair", 0, 8, 14)
	leg("down the main stair", 0, -24, 0)
	leg("living room spawn", -35, -19, 0)
elseif PART == "push" then
	local IN = { -40.2, 40.2, -30.2, 30.2 }
	push("LR west window", -37, -2, 0, -47, -2, IN)
	push("LR south window", -18, -27, 0, -18, -37, IN)
	push("DR east window", 37, -22, 0, 47, -22, IN)
	push("KT north window", 18, 26, 0, 18, 36, { -40.2, 40.2, -30.2, 26 + 4 })
	push("front door", 3, -27, 0, 3, -37, IN)
	push("back door", -3, 27, 0, -3, 37, IN)
	push("BR3 west window", -36, 14, 14, -47, 14, IN)
	push("MB south window", -19, -27, 14, -19, -37, IN)
	push("BR2 north window", 25, 0, 14, 25, 10, { -40.2, 40.2, -30.2, 4.2 })
	push("front wall under the feature window (ground)", 2, -24, 0, 2, -40, { -40.2, 40.2, -30.2, 30.2 })
	push("gallery railing", 3, -2, 14, 3, -12, { -40, 40, -4.6, 30 })
	push("main stair side", -6, -14, 6.6, 4, -14, { -9, -3.0, -30, 30 })
	push("back stair side", 6.25, 14, 6.6, -4, 14, { 3.0, 9, -30, 30 })
	push("MB->foyer window", -12, -16, 14, -2, -16, { -40, -9.2, -30, 30 })
	push("ensuite door", -33, -16, 14, -33, -26, { -40, 40, -18.8, 30 })
end
return table.concat(LOG, "\n")
