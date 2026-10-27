-- tools/arena_v2_lap_lib.lua: client-side helpers for the Arena v2 Play lap (prepended to each lap step by tools/arena_v2_lap.py).
-- Plan coordinates: x east, y north, z up from the floor top; world = ORIGIN + (x, FLOOR_TOP + z, -y).
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local char = lp.Character
local hum = char:FindFirstChildOfClass("Humanoid")
local root = char:FindFirstChild("HumanoidRootPart")
local ORIGIN, FT = Vector3.new(-600, 0, 0), 0.6
local ROOT_OFF = hum.HipHeight + root.Size.Y / 2
local hook = lp:WaitForChild("PlayerScripts"):FindFirstChild("CoverTestHook")
local LOG = {}
local function log(...) local t = {} for _, v in { ... } do table.insert(t, tostring(v)) end table.insert(LOG, table.concat(t, " ")) end
local function W(x, y, z) return ORIGIN + Vector3.new(x, FT + (z or 0), -y) end
local function plan(v) local p = v - ORIGIN return Vector3.new(p.X, -p.Z, p.Y - FT) end
local function where() local p = plan(root.Position) return string.format("(%.2f, %.2f) feet z %.2f", p.X, p.Y, p.Z - ROOT_OFF) end
local function feetZ() return plan(root.Position).Z - ROOT_OFF end
-- stand at plan (x, y) on a surface at height z, facing plan direction (fx, fy)
local function place(x, y, z, fx, fy)
	hook:Invoke("none") -- (no action: just clears the override)
	local at = W(x, y, (z or 0) + ROOT_OFF)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(at, at + Vector3.new(fx or 1, 0, -(fy or 0)))
	task.wait(0.6)
end
-- walk to plan (x, y); returns seconds taken and whether it arrived
local function walkTo(x, y, timeout)
	local target = W(x, y, 0)
	local t0 = os.clock()
	local done = false
	local c = hum.MoveToFinished:Connect(function() done = true end)
	hum:MoveTo(Vector3.new(target.X, root.Position.Y, target.Z))
	while not done and os.clock() - t0 < (timeout or 8) do task.wait(0.05) end
	c:Disconnect()
	local d = ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude
	return os.clock() - t0, d < 1.5
end
-- the cover hook with an aim ray from the head toward plan (x, y, z)
local function act(action, ax, ay, az)
	local head = char.Head.Position
	local look = ax and (W(ax, ay, az or 2) - head) or root.CFrame.LookVector
	return hook:Invoke(action, head, look)
end
local function fmt(r)
	if type(r) ~= "table" then return tostring(r) end
	return string.format("inCover=%s part=%s crouched=%s vaulting=%s moving=%s state=%s", tostring(r.inCover), tostring(r.coverPart),
		tostring(r.crouched), tostring(r.vaulting), tostring(r.moving), tostring(r.state))
end
local function waitIdle(maxT)
	local t0 = os.clock()
	task.wait(0.2)
	while os.clock() - t0 < (maxT or 3) do
		local r = hook:Invoke("none")
		if type(r) == "table" and not r.vaulting and not r.moving then break end
		task.wait(0.1)
	end
	task.wait(0.3)
end
local function headTop() return plan(char.Head.Position).Z + char.Head.Size.Y / 2 - feetZ() end
