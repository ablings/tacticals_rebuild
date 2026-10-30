-- tools/move_feel/lib.lua: prepended to every client step of tools/move_feel_play.py (Studio Play, client VM)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HS = game:GetService("HttpService")
local lp = Players.LocalPlayer
local FLAT = Vector3.new(1, 0, 1)
local function char() return lp.Character end
local function hum() return char() and char():FindFirstChildOfClass("Humanoid") end
local function root() return char() and char():FindFirstChild("HumanoidRootPart") end
local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
local function r3(x) return math.floor(x * 1000 + 0.5) / 1000 end
local function ctl(name)
	local C = lp.PlayerScripts:FindFirstChild("Client") and lp.PlayerScripts.Client:FindFirstChild("Controllers")
	local m = C and C:FindFirstChild(name, true)
	return m and require(m)
end
local LIMBS = { "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
local function hook(action, arg)
	local hk = lp:FindFirstChild("MoveFeelTestHook")
	return hk and hk:Invoke(action, arg)
end
local function moves() return hook("moves") or {} end
local function setFeel(block, key, value) return hook("set", { block, key, value }) end
local function setAF(block, key, value) return hook("setAF", { block, key, value }) end
-- drive the move input like a stick (after Roblox's control script, before the feel layer's momentum)
local driveDir = nil
local function drive(dir) -- world flat direction, or nil to let go
	driveDir = dir
end
pcall(function() RunService:UnbindFromRenderStep("MFTestDrive") end)
RunService:BindToRenderStep("MFTestDrive", Enum.RenderPriority.Input.Value + 1, function()
	local h = hum()
	if h and driveDir then h:Move(driveDir, false) end
end)
-- sampler: per frame (Heartbeat) foot contact drift, the biggest limb rotation change vs the root, speed and states
local function sample(seconds, label)
	local out = { label = label, frames = 0, maxPop = 0, popAt = nil, pops = {}, drift = {}, speeds = {}, states = {} }
	local prev = {}
	local contact = { LeftFoot = nil, RightFoot = nil }
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local c, h, r = char(), hum(), root()
		if not (c and h and r) then return end
		out.frames += 1
		local now = os.clock() - t0
		local m = moves()
		local st = (m.vault and "vault") or (m.dive and "dive") or (m.moving and ("move:" .. tostring(m.style))) or (m.cover and "cover")
			or (m.slide and "slide") or (m.sprint and "sprint") or (m.crouch and "crouch") or (h.FloorMaterial == Enum.Material.Air and "air") or "walk"
		if out.states[#out.states] == nil or out.states[#out.states][2] ~= st then table.insert(out.states, { r2(now), st }) end
		local sp = (r.AssemblyLinearVelocity * FLAT).Magnitude
		table.insert(out.speeds, r2(sp))
		-- pops: rotation change of each limb in root space, scaled to a 60 fps frame
		local scale = (1 / 60) / math.max(dt, 1 / 240)
		local worst, worstName = 0, nil
		for _, n in LIMBS do
			local p = c:FindFirstChild(n)
			if p then
				local rel = r.CFrame:ToObjectSpace(p.CFrame)
				local q = prev[n]
				if q then
					local d = q:ToObjectSpace(rel)
					local _, ang = d:ToAxisAngle()
					local deg = math.deg(math.abs(ang)) * scale
					if deg > worst then worst, worstName = deg, n end
				end
				prev[n] = rel
			end
		end
		table.insert(out.pops, r2(worst))
		out.byState = out.byState or {}
		if worst > (out.byState[st] or 0) then out.byState[st] = r2(worst) end
		-- a state change: the biggest jump within 6 frames of it counts for the pair
		out.lastSt = out.lastSt or st
		if st ~= out.lastSt then out.pair = out.lastSt .. ">" .. st out.pairLeft = 6 out.lastSt = st end
		if out.pairLeft and out.pairLeft > 0 then
			out.pairLeft -= 1
			out.pairs = out.pairs or {}
			if worst > (out.pairs[out.pair] or 0) then out.pairs[out.pair] = r2(worst) end
		end
		if worst > out.maxPop then out.maxPop, out.popAt = r2(worst), { r2(now), worstName, st } end
		if sp > 2 and h.FloorMaterial ~= Enum.Material.Air then
			local lf, rf = c:FindFirstChild("LeftFoot"), c:FindFirstChild("RightFoot")
			if lf and rf then
				local low = lf.Position.Y < rf.Position.Y and lf or rf
				local pp = out._lowPrev and out._lowPrev[low.Name]
				if pp then
					out.slipSum = (out.slipSum or 0) + ((low.Position - pp) * FLAT).Magnitude / math.max(dt, 1e-3)
					out.slipBody = (out.slipBody or 0) + sp
				end
			end
			out._lowPrev = { LeftFoot = lf and lf.Position, RightFoot = rf and rf.Position }
		else
			out._lowPrev = nil
		end
		-- foot drift: a foot whose sole is within 0.2 of the floor counts as planted; sum its flat world travel
		local floor = r.Position.Y - h.HipHeight - r.Size.Y * 0.5
		for _, n in { "LeftFoot", "RightFoot" } do
			local f = c:FindFirstChild(n)
			if f then
				local sole = f.Position.Y - f.Size.Y * 0.5
				local planted = sole - floor < 0.2 and h.FloorMaterial ~= Enum.Material.Air
				local k = contact[n]
				if planted then
					if not k then contact[n] = { pos = f.Position, travel = 0, t = now } else
						k.travel += ((f.Position - k.pos) * FLAT).Magnitude
						k.pos = f.Position
					end
				elseif k then
					if now - k.t > 0.08 then table.insert(out.drift, { r3(k.travel), r2(now - k.t), st }) end
					contact[n] = nil
				end
			end
		end
	end)
	task.wait(seconds)
	conn:Disconnect()
	for n, k in contact do if k and k.travel > 0 then table.insert(out.drift, { r3(k.travel), r2(os.clock() - t0 - k.t), "open" }) end end
	return out
end
local function summary(out)
	local d, n, worstD = 0, 0, 0
	for _, e in out.drift do d += e[1] n += 1 worstD = math.max(worstD, e[1]) end
	local s = {}
	for _, v in out.pops do table.insert(s, v) end
	table.sort(s)
	local p99 = #s > 0 and s[math.max(1, math.floor(#s * 0.99))] or 0
	local sp, m = 0, 0
	for _, v in out.speeds do sp += v m += 1 end
	return { label = out.label, slip = out.slipBody and r3(out.slipSum / out.slipBody) or nil, frames = out.frames, contacts = n, meanDrift = n > 0 and r3(d / n) or 0, worstDrift = worstD,
		maxPop = out.maxPop, popAt = out.popAt, byState = out.byState, pairs = out.pairs, p99Pop = p99, meanSpeed = m > 0 and r2(sp / m) or 0, states = out.states }
end
-- foot drift per step, signed along the travel direction: { label, steps, drift (studs, + = carried forward = clip too slow),
-- stance (studs the foot travels back in root space during the step), ratio = drift / stance }
local function footDrift(seconds, label)
	local steps = {}
	local k = {}
	local minC = { LeftFoot = math.huge, RightFoot = math.huge }
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local c, h, r = char(), hum(), root()
		if not (c and h and r) then return end
		local v = r.AssemblyLinearVelocity * FLAT
		if v.Magnitude < 1 or h.FloorMaterial == Enum.Material.Air then k = {} return end
		local dir = v.Unit
		local floor = r.Position.Y - h.HipHeight - r.Size.Y * 0.5
		for _, n in { "LeftFoot", "RightFoot" } do
			local f = c:FindFirstChild(n)
			if f then
				local hgt = f.Position.Y - floor
				minC[n] = math.min(minC[n], hgt)
				local planted = hgt < minC[n] + 0.04
				local rel = r.CFrame:PointToObjectSpace(f.Position)
				if planted then
					if not k[n] then k[n] = { p0 = f.Position, r0 = r.CFrame:VectorToWorldSpace(rel), n = 0, dir = dir, rel0 = rel } end
					k[n].n += 1
					k[n].p1, k[n].rel1 = f.Position, rel
				elseif k[n] then
					local e = k[n]
					if e.n >= 4 and e.p1 then
						local drift = (e.p1 - e.p0):Dot(e.dir)
						local stance = ((e.rel0 - e.rel1) * FLAT).Magnitude
						table.insert(steps, { drift, stance })
					end
					k[n] = nil
				end
			end
		end
	end)
	task.wait(seconds)
	conn:Disconnect()
	local d, s = 0, 0
	for _, e in steps do d += e[1] s += e[2] end
	return { label = label, steps = #steps, drift = #steps > 0 and r3(d / #steps) or 0, stance = #steps > 0 and r3(s / #steps) or 0,
		ratio = s > 0 and r3(d / s) or 0 }
end
-- slip: the planted foot's world speed along the travel direction / body speed (0 = planted, 1 = carried along, < 0 = clip too fast)
local function slip(seconds, label)
	local prev, minH = {}, { LeftFoot = math.huge, RightFoot = math.huge }
	local sum, body, n = 0, 0, 0
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function(dt)
		local c, h, r = char(), hum(), root()
		if not (c and h and r) then return end
		local v = r.AssemblyLinearVelocity * FLAT
		local floor = r.Position.Y - h.HipHeight - r.Size.Y * 0.5
		for _, nm in { "LeftFoot", "RightFoot" } do
			local f = c:FindFirstChild(nm)
			local hgt = f.Position.Y - floor
			minH[nm] = math.min(minH[nm], hgt)
			if os.clock() - t0 > 0.3 and v.Magnitude > 1 and hgt < minH[nm] + 0.025 and prev[nm] then
				sum += (f.Position - prev[nm]):Dot(v.Unit) / math.max(dt, 1e-3)
				body += v.Magnitude
				n += 1
			end
			prev[nm] = f.Position
		end
	end)
	task.wait(seconds)
	conn:Disconnect()
	return { label = label, frames = n, slip = body > 0 and r3(sum / body) or 0 }
end
-- raw per-frame record for offline analysis (tools/move_feel/analyse.py): t, root xyz, vel xz, floor, LF xyz, RF xyz, state
local function record(seconds, label)
	local rows = {}
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local c, h, r = char(), hum(), root()
		if not (c and h and r) then return end
		local v = r.AssemblyLinearVelocity
		local floor = r.Position.Y - h.HipHeight - r.Size.Y * 0.5
		local lf, rf = c.LeftFoot.Position, c.RightFoot.Position
		table.insert(rows, { r3(os.clock() - t0), r3(r.Position.X), r3(r.Position.Y), r3(r.Position.Z), r3(v.X), r3(v.Z), r3(floor),
			r3(lf.X), r3(lf.Y), r3(lf.Z), r3(rf.X), r3(rf.Y), r3(rf.Z), h.FloorMaterial == Enum.Material.Air and 1 or 0 })
	end)
	task.wait(seconds)
	conn:Disconnect()
	return { label = label, rows = rows }
end
