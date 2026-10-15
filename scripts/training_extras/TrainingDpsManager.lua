-- Managers/TrainingDpsManager (server, lobby place): infinite-HP damage-test dummies with a rolling DPS readout
-- (notes/training_extras_done.md). One dummy per LobbyMap.Training.Extras.DpsDummies.DpsSpot (built by fix/place_training.lua).
-- Not counted in TrainingManager's alive dummies and not on EnemySpots. Hits arrive through the same BindableEvent "OnHit"
-- CombatManager already fires for range dummies (no CombatManager change). Readout: damage of the last `Window` seconds of
-- the current burst up to the last hit / that span (min `MinSpan`), 5 Hz; after `Idle` s without hits it holds greyed for
-- `Hold` s, then resets to 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local manager = {}

local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
local BODY = Color3.fromRGB(107, 122, 58)      -- dark olive (Tacticals accent): differs from the red enemies
local LIMB = Color3.fromRGB(40, 44, 36)
local CREAM, SAGE, DIM = Color3.fromRGB(236, 232, 218), Color3.fromRGB(167, 173, 152), Color3.fromRGB(120, 120, 114)
local FONT_H = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_B = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local ZONE = { Head = Color3.fromRGB(255, 92, 124), Body = Color3.fromRGB(255, 255, 255), Limb = Color3.fromRGB(200, 200, 205), Extremity = Color3.fromRGB(140, 140, 148) }
local HP = 1e6
local dummies = {}

local function label(parent, name, pos, size, color, font)
	local l = Instance.new("TextLabel"); l.Name = name; l.BackgroundTransparency = 1; l.Position = pos; l.Size = size
	l.TextScaled = true; l.TextColor3 = color; l.TextStrokeTransparency = 0.5; l.FontFace = font; l.Text = ""; l.Parent = parent
	return l
end
local function popup(gui, text, color)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.4, 0.95); l.Size = UDim2.fromScale(0.5, 0.3); l.Text = text
	l.TextColor3 = color; l.TextStrokeTransparency = 0.4; l.TextScaled = true; l.FontFace = FONT_B; l.Parent = gui
	TweenService:Create(l, TweenInfo.new(1, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromScale(0, 0.5), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.1, function() l:Destroy() end)
end
local function fmt(n) local s = tostring(math.floor(n + 0.5)); return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end

local function spawnAt(spot: BasePart, parent: Instance)
	local template = ServerStorage:FindFirstChild("RangeAssets") and ServerStorage.RangeAssets:FindFirstChild("Dummy")
	if not template then return end
	local d = template:Clone(); d.Name = "DpsDummy"
	for _, x in d:GetDescendants() do
		if x:IsA("Decal") and x.Parent and x.Parent.Name == "Head" then x:Destroy()
		elseif x:IsA("Shirt") or x:IsA("Pants") or x:IsA("ShirtGraphic") or x:IsA("BodyColors") or x:IsA("Accessory") then x:Destroy()
		elseif x:IsA("BasePart") and x.Name ~= "HumanoidRootPart" then
			x.Color = (x.Name:find("Torso") or x.Name == "Head") and BODY or LIMB; x.Material = Enum.Material.SmoothPlastic
			if x:IsA("MeshPart") then x.TextureID = "" end
		end
	end
	local hum = d:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = HP; hum.Health = HP; hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local _, size = d:GetBoundingBox()
	d:PivotTo(CFrame.new(spot.Position.X, spot.Position.Y - 3 + size.Y / 2 + 0.05, spot.Position.Z) * spot.CFrame.Rotation)
	for _, p in d:GetDescendants() do if p:IsA("BasePart") then p.Anchored = p.Name == "HumanoidRootPart" end end
	-- readout (BillboardGui Scale = studs: Scale-only UI)
	local gui = Instance.new("BillboardGui"); gui.Name = "DpsReadout"; gui.Size = UDim2.fromScale(7, 3.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0); gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.MaxDistance = 300
	gui.Parent = d:FindFirstChild("Head")
	local plate = Instance.new("Frame"); plate.Name = "Plate"; plate.BackgroundColor3 = Color3.fromRGB(10, 12, 10); plate.BackgroundTransparency = 0.35
	plate.Position = UDim2.fromScale(0.1, 0.36); plate.Size = UDim2.fromScale(0.8, 0.64); plate.Parent = gui
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0.18, 0); uc.Parent = plate
	local big = label(plate, "Dps", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.6), CREAM, FONT_H)
	local small = label(plate, "Detail", UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.3), SAGE, FONT_B)
	local tag = label(gui, "Tag", UDim2.fromScale(0.2, 0.02), UDim2.fromScale(0.6, 0.3), SAGE, FONT_B); tag.Text = "DPS TEST"
	big.Text = "0 DPS"; small.Text = "LAST 0 · TOTAL 0"
	local st = { samples = {}, burstStart = 0, lastHit = -math.huge, last = 0, total = 0, big = big, small = small , gui = gui }
	local onHit = Instance.new("BindableEvent"); onHit.Name = "OnHit"    -- fired by CombatManager on every confirmed hit
	onHit.Event:Connect(function(_, zone, damage)
		local now = os.clock()
		if now - st.lastHit > TX.DpsDummies.Idle then st.samples = {}; st.burstStart = now; st.total = 0 end
		st.lastHit = now; st.last = damage; st.total += damage
		table.insert(st.samples, { t = now, d = damage })
		hum.Health = hum.MaxHealth
		popup(gui, tostring(damage), ZONE[zone] or ZONE.Body)
	end)
	onHit.Parent = d
	hum.HealthChanged:Connect(function(h) if h < HP * 0.5 then hum.Health = HP end end)
	d.Parent = parent
	dummies[d] = st
end

local function tick()
	local now = os.clock()
	local W, MIN, IDLE, HOLD = TX.DpsDummies.Window, TX.DpsDummies.MinSpan, TX.DpsDummies.Idle, TX.DpsDummies.Hold
	for d, st in dummies do
		if not d.Parent then dummies[d] = nil; continue end
		local idle = now - st.lastHit
		local text, detail, colour
		if idle > IDLE + HOLD then
			text, detail, colour = "0 DPS", "LAST 0 · TOTAL 0", DIM
		else
			-- rolling window ending at the last hit: steady while you fire, frozen (greyed) once you stop
			while st.samples[1] and st.samples[1].t < st.lastHit - W do table.remove(st.samples, 1) end
			local span = math.clamp(st.lastHit - st.burstStart, MIN, W)
			local sum = 0
			for _, s in st.samples do if s.t >= st.lastHit - span then sum += s.d end end
			text = fmt(sum / span) .. " DPS"
			detail = "LAST " .. fmt(st.last) .. " · TOTAL " .. fmt(st.total)
			colour = idle > IDLE and DIM or CREAM
		end
		if st.big.Text ~= text then st.big.Text = text end
		if st.small.Text ~= detail then st.small.Text = detail end
		if st.big.TextColor3 ~= colour then st.big.TextColor3 = colour end
	end
end

function manager.Start()
	if not (ok and TX.On("DpsDummies")) then return end
	local map = workspace:WaitForChild("LobbyMap", 30)
	local t = map and map:WaitForChild("Training", 30)
	local ex = t and t:WaitForChild("Extras", 10)
	local folder = ex and ex:WaitForChild("DpsDummies", 5)
	if not folder then return end
	for _, s in folder:GetChildren() do if s:IsA("BasePart") then spawnAt(s, folder) end end
	task.spawn(function() while true do task.wait(0.2); tick() end end)
end

return manager
