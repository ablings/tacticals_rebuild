-- client-side ambience for the lobby: spins, bob, walkway pulses, breathing glows, sparks, flicker
local RS = game:GetService("RunService"); local CSvc = game:GetService("CollectionService"); local TS = game:GetService("TweenService")
local map = workspace:WaitForChild("LobbyMap"); local FX = map:WaitForChild("FX")
local PFX_AMBIENT = workspace:GetAttribute("PFX_AmbientFX") == true -- [PFX] RIVALS has no ambient FX: walkway pulses + spark bursts only if workspace.PFX_AmbientFX = true (fix/particles_fix.lua)
task.wait(1)
-- streaming-safe tag hook: existing + streamed-in later
local function onTag(tag, fn)
	for _, i in CSvc:GetTagged(tag) do task.spawn(fn, i) end
	CSvc:GetInstanceAddedSignal(tag):Connect(fn)
end
_G.LobbyOnTag = onTag
-- spinning hologram parts
local spinners = {}
onTag("LobbySpin", function(p) spinners[p] = p.CFrame end)
CSvc:GetInstanceRemovedSignal("LobbySpin"):Connect(function(p) spinners[p] = nil end)
-- walkway pulses: run from the spawn ring outward along the two lit seams
local pulses = {}
local function mkPulse()
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(121, 130, 103); p.Size = Vector3.new(3.2, 0.06, 0.22); p.Parent = FX
	return p
end
for _, z in (PFX_AMBIENT and {-6, 6} or {}) --[[ [PFX] no floor pulses unless PFX_AmbientFX ]] do for _, dir in {1, -1} do for k = 0, 2 do
	table.insert(pulses, {part = mkPulse(), z = z, dir = dir, t = k / 3})
end end end
-- breathing glows: pod nozzle cyan + wall-of-light panels
local breathe = {}; local flick = {}
local function consider(p)
	if not p:IsA("MeshPart") then return end
	if p.Name == "K_PodHead__emit_cyan" or p.Name == "K_PodHeadR__emit_cyan" or p.Name:match("^U_EnergyWall__emit") then
		table.insert(breathe, {p = p, c = p.Color, ph = math.random() * 6})
	elseif p.Name == "K_GShop__emit_amber" then table.insert(flick, p) end
end
for _, p in map:GetDescendants() do consider(p) end
map.DescendantAdded:Connect(consider)
local t0 = os.clock()
RS.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	for p, base in spinners do
		local spin = math.rad(p:GetAttribute("spin") or 20) * t
		local bob = p:GetAttribute("bob") and math.sin(t * 1.3) * 0.5 or 0
		p.CFrame = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0)
	end
	for _, s in pulses do
		s.t = (s.t + dt * 0.22) % 1
		local x = s.dir * (27 + s.t * 58)
		s.part.CFrame = CFrame.new(x, 0.08, s.z)
		s.part.Transparency = math.clamp(s.t * 1.2 - 0.1, 0, 1)
	end
	for _, b in breathe do
		local k = 0.8 + 0.2 * math.sin(t * 1.6 + b.ph)
		b.p.Color = Color3.new(b.c.R * k, b.c.G * k, b.c.B * k)
	end
end)
-- random spark bursts with a flash
task.spawn(function()
	while true do
		task.wait(3 + math.random() * 7)
		local list = PFX_AMBIENT and CSvc:GetTagged("LobbySpark") or {} --[[ [PFX] no spark bursts unless PFX_AmbientFX ]]
		if #list > 0 then -- GetTagged at call time: streamed-in parts included
			local h = list[math.random(#list)]
			local e = h:FindFirstChild("Sparks"); local l = h:FindFirstChild("Flash")
			if e then e:Emit(math.random(10, 22)) end
			if l then l.Brightness = 3; TS:Create(l, TweenInfo.new(0.35), {Brightness = 0}):Play() end
		end
	end
end)
-- occasional sign flicker
task.spawn(function()
	while true do
		task.wait(6 + math.random() * 10)
		if #flick > 0 then
			local p = flick[math.random(#flick)]; if not p.Parent then continue end; local c = p.Color
			for i = 1, math.random(2, 5) do p.Color = c:Lerp(Color3.new(0, 0, 0), 0.7); task.wait(0.05 + math.random() * 0.08); p.Color = c; task.wait(0.04 + math.random() * 0.1) end
		end
	end
end)
-- PASS5: wayfinding scroll, spawn ripple, mobile/low-end quality scaler
do
	local CSvc = game:GetService("CollectionService"); local TS = game:GetService("TweenService"); local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService"); local Lighting = game:GetService("Lighting")
	local texs = {}
	_G.LobbyOnTag("LobbyScroll", function(p) for _, t in p:GetChildren() do if t:IsA("Texture") then table.insert(texs, t) end end end)
	RS.RenderStepped:Connect(function(dt) for _, t in texs do t.OffsetStudsU = (t.OffsetStudsU - dt * 4) % 4.2 end end)
	_G.LobbyOnTag("LobbyRipple", function(rp)
		local d = rp:FindFirstChildOfClass("Decal")
		task.spawn(function()
			while rp.Parent do
				rp.Size = Vector3.new(8, 0.05, 8); if d then d.Transparency = 0.25 end
				TS:Create(rp, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(46, 0.05, 46)}):Play()
				if d then TS:Create(d, TweenInfo.new(2.4), {Transparency = 1}):Play() end
				task.wait(3)
			end
		end)
	end)
	-- quality scaler: touch devices, low saved quality, or measured FPS < 45 -> lighter FX
	task.wait(4)
	local n, t = 0, 0
	local c = RS.RenderStepped:Connect(function(dt) n += 1; t += dt end); task.wait(3); c:Disconnect()
	local fps = n / math.max(t, 0.001)
	local q = UserSettings().GameSettings.SavedQualityLevel.Value
	local low = UIS.TouchEnabled or fps < 45 or (q > 0 and q <= 4)
	if low then
		local FX = workspace.LobbyMap.FX
		for _, e in FX:GetDescendants() do
			if e:IsA("ParticleEmitter") then e.Rate = e.Rate * 0.3 -- (parts streamed in later keep full rate; emitters are few)
			elseif e:IsA("Beam") and e.Name == "Arc" and math.random() < 0.5 then e.Enabled = false end
		end
		for _, l in workspace.LobbyMap:GetDescendants() do if l:IsA("Light") then l.Shadows = false end end
		-- [STREAM] lights / emitters streamed in later get the same treatment
		workspace.LobbyMap.DescendantAdded:Connect(function(d)
			if d:IsA("Light") then d.Shadows = false
			elseif d:IsA("ParticleEmitter") and d:IsDescendantOf(FX) and not d:GetAttribute("_LowRate") then d:SetAttribute("_LowRate", true) d.Rate = d.Rate * 0.3 end
		end)
		local dof = Lighting:FindFirstChild("Lobby_DOF"); if dof then dof.Enabled = false end
		local bl = Lighting:FindFirstChild("Lobby_Bloom"); if bl then bl.Size = 18 end
	end
	workspace:SetAttribute("LobbyFXLow", low); workspace:SetAttribute("LobbyFXfps", math.floor(fps))
end
-- PASS10: gate turbine rotors
do
	local RS = game:GetService("RunService"); local rotors = {}
	_G.LobbyOnTag("LobbyRotor", function(m) table.insert(rotors, m) end)
	local t0 = os.clock()
	RS.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, m in rotors do
			local b = m:GetAttribute("base"); if b and m.Parent then m:PivotTo(b * CFrame.Angles(t * (m:GetAttribute("speed") or 1), 0, 0)) end
		end
	end)
end
-- PASS6: sky windows, flight HUDs, tickers, beacons, props (drone + crane)
do
	local RS = game:GetService("RunService"); local CSvc = game:GetService("CollectionService")
	local skies, huds, ticks, beacons = {}, {}, {}, {}
	_G.LobbyOnTag("LobbySky", function(p) local im = p:FindFirstChild("Sky", true); if im then table.insert(skies, {im = im, dir = p:GetAttribute("dir") or 1, s = 0.018 + math.random() * 0.006}) end end)
	_G.LobbyOnTag("LobbyHUD", function(p) table.insert(huds, {p = p, ph = math.random() * 10}) end)
	_G.LobbyOnTag("LobbyTicker", function(p) table.insert(ticks, p) end)
	_G.LobbyOnTag("LobbyBeacon", function(p) table.insert(beacons, {p = p, ph = math.random() * 0.4}) end)
	local t0 = os.clock()
	RS.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		for _, s in skies do
			local x = s.im.Position.X.Scale - s.dir * s.s * dt
			if x <= -1 then x += 1 elseif x >= 0 then x -= 1 end
			s.im.Position = UDim2.fromScale(x, 0)
		end
		for _, p in ticks do
			local off = (t * 0.025) % 1
			for k = 0, 1 do local l = p:FindFirstChild("T" .. k, true); if l then l.Position = UDim2.fromScale(k - off, 0.08) end end
		end
		for _, b in beacons do
			if b.p:GetAttribute("kind") == "strobe" then
				local ph = (t + b.ph) % 1.6; b.p.Transparency = (ph < 0.06 or (ph > 0.18 and ph < 0.24)) and 0 or 0.92
			else
				b.p.Transparency = ((t + b.ph) % 1.2 < 0.7) and 0 or 0.7
			end
		end
		for _, h in huds do
			local r = h.p:FindFirstChild("Radar", true); if r then r.Rotation = (t * 90 + h.ph * 36) % 360 end
		end
	end)
	task.spawn(function()
		while true do
			local t = os.clock() - t0
			for _, h in huds do
				local function set(n, v) local l = h.p:FindFirstChild(n, true); if l then l.Text = v end end
				set("Alt", string.format("%d FT", 34200 + math.floor(math.sin(t * 0.1 + h.ph) * 40)))
				set("Spd", string.format("%d KT", 540 + math.floor(math.sin(t * 0.37 + h.ph) * 3)))
				set("Hdg", string.format("%03d°", (272 + math.floor(math.sin(t * 0.05) * 2)) % 360))
				set("Oat", string.format("%d°C", -52 + math.floor(math.sin(t * 0.02) * 1.5)))
				for b = 1, 6 do local f = h.p:FindFirstChild("Bar" .. b, true); if f then f.Size = UDim2.fromScale(0.1, 0.05 + 0.1 * (0.5 + 0.5 * math.sin(t * (1 + b * 0.3) + b + h.ph))) end end
			end
			task.wait(0.25)
		end
	end)
	-- props (only if imported): crane trolley shuttles a container along gantry 4, drone loops the hall
	local props = workspace.LobbyMap:WaitForChild("Props", 15)
	if props then
		local tr = props:FindFirstChild("Crane"); local dr = props:FindFirstChild("Drone")
		RS.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if tr and tr.PrimaryPart then
				local z = math.sin(t * 0.09) * 34
				tr:PivotTo(CFrame.new(tr:GetAttribute("x") or 21.25, 57, z))
			end
			if dr and dr.PrimaryPart then
				local a = t * 0.12
				local pos = Vector3.new(math.sin(a) * 62, 20 + math.sin(a * 2.3) * 3, math.sin(a * 2) * 26)
				local nxt = Vector3.new(math.sin(a + 0.05) * 62, 20 + math.sin((a + 0.05) * 2.3) * 3, math.sin((a + 0.05) * 2) * 26)
				dr:PivotTo(CFrame.lookAt(pos, nxt) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.sin(t * 3) * 0.04, 0, -0.12))
			end
		end)
	end
end
-- PASS12b: running lights + cart UI along the pod cradles
do
	local RS = game:GetService("RunService"); local runs = {}
	_G.LobbyOnTag("LobbyRun", function(p) table.insert(runs, p) end)
	local t0 = os.clock()
	RS.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, p in runs do
			local A, B = p:GetAttribute("A"), p:GetAttribute("B")
			if A and p.Parent then
				local u = (t * p:GetAttribute("spd") + p:GetAttribute("ph")) % 1
				local pos = A:Lerp(B, u)
				p.CFrame = CFrame.lookAt(pos, B) * CFrame.Angles(0, math.pi / 2, 0)
				p.Transparency = (u < 0.06 or u > 0.94) and 0.8 or 0
			end
		end
	end)
	local carts = {}
	_G.LobbyOnTag("LobbyCartUI", function(p) table.insert(carts, p) end)
	task.spawn(function()
		while true do
			for i, p in carts do local b = p:FindFirstChild("Bar", true); if b then b.Size = UDim2.fromScale(0.1 + 0.8 * ((os.clock() * 0.2 + i * 0.37) % 1), 0.05) end end
			task.wait(0.2)
		end
	end)
end
-- PASSOPT: phones / low-end -> cull decorative screens harder
task.spawn(function()
	task.wait(9)
	if not workspace:GetAttribute("LobbyFXLow") then return end
	local function cull(sg)
		if sg:IsA("SurfaceGui") then
			local host = sg.Parent and sg.Parent.Name or ""
			if host == "HullMark" then sg.Enabled = false
			elseif host == "SkyWindow" then sg.PixelsPerStud = 6; sg.MaxDistance = 90
			else sg.MaxDistance = math.min(sg.MaxDistance, 60) end
		end
	end
	for _, sg in workspace.LobbyMap:GetDescendants() do cull(sg) end
	workspace.LobbyMap.DescendantAdded:Connect(cull) -- [STREAM] screens streamed in later
end)
