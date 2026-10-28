-- tools/house_lap_lib.lua: client helpers for the House Play lap (prepended by tools/house_play.py client).
-- Plan coords: x east = world +X, y north = world -Z, h above the ground floor top; world = ORIGIN + (x, h, -y).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local char = lp.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and char:FindFirstChild("HumanoidRootPart")
local ORIGIN = Vector3.new(-650, 1.2, -450)
local ROOT_OFF = hum and root and (hum.HipHeight + root.Size.Y / 2) or 3
local LOG = {}
local function log(...) local t = {} for _, v in { ... } do table.insert(t, tostring(v)) end table.insert(LOG, table.concat(t, " ")) end
local function W(e, n, h) return ORIGIN + Vector3.new(e, h or 0, -n) end
local function plan(v) local p = v - ORIGIN return Vector3.new(p.X, -p.Z, p.Y) end -- (x, y, h)
local function feet() local p = plan(root.Position) return p.Z - ROOT_OFF end
local function where() local p = plan(root.Position) return string.format("(%.1f, %.1f) feet %.2f", p.X, p.Y, p.Z - ROOT_OFF) end
local function walkFeet() return feet() end
local function hook() return lp:WaitForChild("PlayerScripts"):FindFirstChild("CoverTestHook") end
local function place(e, n, h, fe, fn)
	local at = W(e, n, (h or 0) + ROOT_OFF)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(at, at + Vector3.new(fe or 0, 0, -(fn or 1)))
	task.wait(0.6)
end
local function walkTo(e, n, timeout)
	local target = W(e, n, 0)
	local t0 = os.clock()
	local done = false
	local c = hum.MoveToFinished:Connect(function() done = true end)
	hum:MoveTo(Vector3.new(target.X, root.Position.Y, target.Z))
	while not done and os.clock() - t0 < (timeout or 10) do task.wait(0.05) end
	c:Disconnect()
	local d = ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude
	return os.clock() - t0, d < 1.5, d
end
local function act(action, ae, an, ah)
	local h = hook()
	if not h then return "no CoverTestHook" end
	local head = char.Head.Position
	local look = ae and (W(ae, an, ah or 2) - head) or root.CFrame.LookVector
	return h:Invoke(action, head, look)
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
		local r = act("none")
		if type(r) == "table" and not r.vaulting and not r.moving then break end
		task.wait(0.1)
	end
	task.wait(0.3)
end
