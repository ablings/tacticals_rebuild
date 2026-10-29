-- [MOVE1029] unit cases for ReplicatedStorage.Modules.Shared.MoveRules. Each case is decided by the rule it names.
-- Used by fix/move_rework_1029_tests.lua (generated): SPEC(MoveRules, cfg) -> passed, failed, lines
local function SPEC(M, cfg)
	local passed, failed, lines = 0, 0, {}
	local function ok(name, cond, info)
		if cond then passed += 1 else failed += 1 table.insert(lines, "FAIL " .. name .. (info and (" (" .. tostring(info) .. ")") or "")) end
	end
	local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-3) end

	-- LEAN
	ok("LeanWaist(0) is identity", M.LeanWaist(0, cfg) == CFrame.identity)
	local r = M.LeanWaist(1, cfg)
	ok("LeanWaist(1) shifts out LeanShift", near(r.Position.X, cfg.LeanShift), r.Position.X)
	ok("LeanWaist(1) tips the top to the right", r.UpVector.X > 0, r.UpVector.X)
	ok("LeanWaist(1) rolls LeanRoll degrees", near(math.deg(math.acos(r.UpVector.Y)), cfg.LeanRoll, 0.01), math.deg(math.acos(r.UpVector.Y)))
	local l = M.LeanWaist(-1, cfg)
	ok("LeanWaist(-1) mirrors", near(l.Position.X, -cfg.LeanShift) and l.UpVector.X < 0)
	ok("LeanWaist clamps past 1", M.LeanWaist(3, cfg) == M.LeanWaist(1, cfg))
	local root = CFrame.new(10, 3, 5)
	local head = root * CFrame.new(0, 1.5, 0)
	local leaned = M.LeanPart(root, head, "Head", 1, cfg)
	local dx = (root:PointToObjectSpace(leaned.Position)).X
	local arm = (1.5 - M.WAIST_PIVOT.Y)
	local want = cfg.LeanShift + arm * math.sin(math.rad(cfg.LeanRoll))
	ok("LeanPart moves the head out shift + arm*sin(roll)", near(dx, want, 0.02), ("%.3f vs %.3f"):format(dx, want))
	ok("LeanPart: the head ~1 stud out (0.9-1.1)", dx > 0.9 and dx < 1.1, dx)
	local shoulder = M.LeanPart(root, root * CFrame.new(1, 0.6, 0), "RightUpperArm", 1, cfg)
	local sx = root:PointToObjectSpace(shoulder.Position).X - 1
	ok("LeanPart: the shoulder 0.6-0.9 out", sx > 0.6 and sx < 0.9, sx)
	ok("LeanPart leaves the legs", M.LeanPart(root, root * CFrame.new(0, -2, 0), "LeftFoot", 1, cfg) == root * CFrame.new(0, -2, 0))
	ok("LeanPart leaves the lower torso", M.LeanPart(root, root, "LowerTorso", 1, cfg) == root)
	ok("LeanPart with lean 0 changes nothing", M.LeanPart(root, head, "Head", 0, cfg) == head)
	ok("Ease: half way after half LeanTime", near(M.Ease(0, 1, cfg.LeanTime / 2, cfg), 0.5))
	ok("Ease never overshoots", M.Ease(0.9, 1, 1, cfg) == 1 and M.Ease(-0.9, -1, 1, cfg) == -1)
	ok("Ease back to 0", M.Ease(1, 0, cfg.LeanTime, cfg) == 0)

	-- FACING (server gate)
	ok("FlatAngle 90", near(M.FlatAngle(Vector3.xAxis, Vector3.zAxis), 90))
	ok("FlatAngle ignores pitch", near(M.FlatAngle(Vector3.new(1, 0.5, 0), Vector3.xAxis), 0, 0.01))
	ok("FlatAngle nil when straight down", M.FlatAngle(Vector3.new(0.1, -1, 0), Vector3.xAxis) == nil)
	local function dirAt(deg) return Vector3.new(math.sin(math.rad(deg)), 0, math.cos(math.rad(deg))) end
	local okA = M.FacingOk(dirAt(20), { dirAt(0) }, 22)
	local okB, bestB = M.FacingOk(dirAt(25), { dirAt(0) }, 22)
	ok("FacingOk 20 deg within 22", okA)
	ok("FacingOk 25 deg refused at 22", not okB and near(bestB, 25, 0.01), bestB)
	ok("FacingOk: any facing of the window counts", (M.FacingOk(dirAt(90), { dirAt(0), dirAt(45), dirAt(80) }, 22)))
	ok("FacingOk: a 120 deg turn not reached refused", not (M.FacingOk(dirAt(120), { dirAt(0), dirAt(40), dirAt(70) }, 22)))
	ok("FacingOk: no history = allowed", (M.FacingOk(dirAt(120), {}, 22)))
	ok("FacingTolerance peek/turn/none 22", M.FacingTolerance("Peek", cfg) == 22 and M.FacingTolerance("Turn", cfg) == 22 and M.FacingTolerance(nil, cfg) == 22)
	ok("FacingTolerance blind/move 115", M.FacingTolerance("Blind", cfg) == 115 and M.FacingTolerance("Move", cfg) == 115)

	-- PEEK GATE (client)
	ok("PeekReady: not before the full pose", not M.PeekReady(0.9, 0, 0, cfg))
	ok("PeekReady: full pose, 9 deg", M.PeekReady(1, 9, 0, cfg))
	ok("PeekReady: full pose, 11 deg refused", not M.PeekReady(1, 11, 0, cfg))
	ok("PeekReady wraps at 180", M.PeekReady(1, 179, -179, cfg))

	-- PULL-UP reach
	ok("PullUp: 1.0 is a step", not (M.PullUpHeightOk(0, 1.0, cfg)))
	ok("PullUp: low cover 3.4 ok", (M.PullUpHeightOk(0, 3.4, cfg)))
	ok("PullUp: head top 5.1 ok", (M.PullUpHeightOk(0, 5.1, cfg)))
	ok("PullUp: a 5-high deck is reachable (needs NoClimb)", (M.PullUpHeightOk(0.6, 5.6, cfg)))
	ok("PullUp: 5.3 refused", not (M.PullUpHeightOk(0, 5.3, cfg)))
	ok("PullUp: measured from the floor you're on, not the root", not (M.PullUpHeightOk(10, 16, cfg)) and (M.PullUpHeightOk(10, 14, cfg)))

	-- NOCLIMB + WALL COVER (on throwaway instances)
	local map = Instance.new("Model")
	local folder = Instance.new("Folder") folder.Parent = map
	local wall = Instance.new("Part") wall.Parent = folder
	local plain = Instance.new("Part") plain.Parent = folder
	ok("NoClimb: none", not M.IsNoClimb(wall))
	plain:SetAttribute("NoClimb", true)
	ok("NoClimb on the part", M.IsNoClimb(plain))
	folder:SetAttribute("NoClimb", true)
	ok("NoClimb on an ancestor", M.IsNoClimb(wall))
	folder:SetAttribute("NoClimb", nil)
	wall:SetAttribute("NotCover", true)
	wall:SetAttribute("WallProxy", true)
	ok("WallCover off (no attribute): a wall proxy is no cover", not M.IsWallCover(wall) and not M.CoverPart(wall))
	map:SetAttribute("WallCover", true)
	ok("WallCover on: the wall proxy is cover", M.IsWallCover(wall) and M.CoverPart(wall))
	local window = Instance.new("Part") window.Parent = folder window:SetAttribute("NotCover", true)
	ok("WallCover on: a NotCover window (no WallProxy) stays no cover", not M.CoverPart(window))
	ok("plain part is cover", M.CoverPart(Instance.new("Part")))
	local ghost = Instance.new("Part") ghost.CanCollide = false
	ok("a part that doesn't collide is no cover", not M.CoverPart(ghost))
	folder:SetAttribute("WallCover", false)
	ok("the nearest WallCover attribute wins", not M.IsWallCover(wall))
	map:Destroy()
	return passed, failed, lines
end
