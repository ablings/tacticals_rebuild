-- Client/Controllers/CombatFeedbackController (ModuleScript, auto-loaded): the hit feedback rows of Settings.
--   Video > Damage Flashing (Enabled / Outline / Disabled) + Base Color / Flash Color
--       anyone who loses health (players, duel bots, dummies; never you) flashes: a Highlight in the base colour
--       that fades through the flash colour to nothing
--   Game > Damage Numbers + Color / Critical Color
--       your hits pop a number over the target (headshots in the critical colour). Hits on the same target in quick
--       succession add up in one number, RIVALS-style. Firing-range dummies draw their own numbers, so they are skipped.
-- Sources: HitConfirm(zone, damage, killed) (shooter only) for the amount, the WeaponFired echo
-- (shooter, origin, endPos, hit: boolean), sent just before it, for where. (UI session 2026-10-16)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local controller = {}
local player = Players.LocalPlayer

local function setting(name, default)
	local v = player:GetAttribute("Setting_" .. name)
	if v == nil then return default end
	return v
end
local function color(name, default)
	local v = setting(name, default)
	if typeof(v) == "Color3" then return v end
	local ok, c = pcall(Color3.fromHex, tostring(v))
	return ok and c or Color3.fromHex(default)
end

---------------------------------------------------------------------------------------------------- damage flashing
local flashes = {} -- [Model] = Highlight
local function flash(model: Model)
	local mode = setting("DamageFlashing", "Enabled")
	if mode == "Disabled" then return end
	local base, fade = color("BaseColor", "#ff3232"), color("FlashColor", "#ffffff")
	local h = flashes[model]
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.Name = "DamageFlash"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = model
		h.Parent = model
		flashes[model] = h
	end
	local outlineOnly = mode == "Outline"
	h.FillColor, h.OutlineColor = base, base
	h.FillTransparency = outlineOnly and 1 or 0.3
	h.OutlineTransparency = 0
	h.Enabled = true
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(h, info, { FillColor = fade, OutlineColor = fade, FillTransparency = 1, OutlineTransparency = 1 }):Play()
end

local watched = setmetatable({}, { __mode = "k" })
local function watch(hum: Instance)
	if not hum:IsA("Humanoid") or watched[hum] then return end
	watched[hum] = true
	local last = hum.Health
	hum.HealthChanged:Connect(function(hp)
		local model = hum.Parent
		if hp < last - 0.5 and model and model:IsA("Model") and model ~= player.Character then flash(model) end
		last = hp
	end)
end

---------------------------------------------------------------------------------------------------- damage numbers
local lastShot -- { t, pos, char }
local popups = {} -- [Model] = { gui, label, total, t }

local function headOf(model: Model?): Vector3?
	if not model then return nil end
	local head = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	return head and head.Position
end

-- melee / blasts have no shot line: the nearest other character just in front of you
local function nearestTarget(): Model?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bestD
	for hum in watched do
		local m = hum.Parent
		local p = m and m ~= player.Character and hum.Health < hum.MaxHealth and headOf(m)
		if p then
			local d = (p - root.Position).Magnitude
			if d < 14 and (not bestD or d < bestD) then best, bestD = m, d end
		end
	end
	return best
end

local function popNumber(target: Model?, at: Vector3, damage: number, crit: boolean, killed: boolean)
	if setting("DamageNumbers", true) == false then return end
	local c = crit and color("CriticalColor", "#ff3232") or color("DamageColor", "#ffffff")
	local key = target or at
	local p = popups[key]
	if p and p.gui.Parent and os.clock() - p.t < 0.8 then
		p.total += damage
	else
		local anchor = Instance.new("Part")
		anchor.Name = "DamageNumber"
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.1
		anchor.Position = at + Vector3.new((math.random() - 0.5) * 1.2, 1.2, 0)
		anchor.Parent = workspace.CurrentCamera
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(3.2, 1.5) -- studs: shrinks with distance like a world object
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Adornee = anchor
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		p = { gui = gui, label = label, stroke = stroke, anchor = anchor, total = damage }
		popups[key] = p
	end
	p.t = os.clock()
	p.label.Text = tostring(math.floor(p.total + 0.5))
	p.label.TextColor3 = c
	p.label.TextTransparency, p.stroke.Transparency = 0, 0
	p.gui.Size = UDim2.fromScale(killed and 4.2 or 3.2, killed and 2 or 1.5)
	local mine = p
	task.delay(0.55, function()
		if mine.t > os.clock() - 0.5 then return end -- topped up since: the newer hit restarts the fade
		local info = TweenInfo.new(0.35)
		TweenService:Create(mine.label, info, { TextTransparency = 1 }):Play()
		TweenService:Create(mine.stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(mine.anchor, info, { Position = mine.anchor.Position + Vector3.new(0, 1, 0) }):Play()
		task.delay(0.4, function()
			if os.clock() - mine.t >= 0.85 then
				mine.anchor:Destroy()
				if popups[key] == mine then popups[key] = nil end
			end
		end)
	end)
end

function controller.Start()
	-- every humanoid that can take damage: players' characters, duel bots in the arenas, training dummies
	for _, d in workspace:GetDescendants() do if d:IsA("Humanoid") then watch(d) end end
	workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then watch(d) end end)

	local Combat = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat")
	local near = OverlapParams.new()
	near.FilterType = Enum.RaycastFilterType.Exclude
	Combat:WaitForChild("WeaponFired").OnClientEvent:Connect(function(shooter, _origin, endPos)
		if shooter ~= player or typeof(endPos) ~= "Vector3" then return end
		-- the character the shot ended in: the humanoid model owning a part at the end point
		local char
		near.FilterDescendantsInstances = { player.Character }
		for _, part in workspace:GetPartBoundsInRadius(endPos, 1.5, near) do
			local m = part:FindFirstAncestorOfClass("Model")
			while m and not m:FindFirstChildOfClass("Humanoid") do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
			if m then char = m break end
		end
		lastShot = { t = os.clock(), pos = endPos, char = char }
	end)
	Combat:WaitForChild("HitConfirm").OnClientEvent:Connect(function(zone, damage, killed)
		if type(damage) ~= "number" or damage <= 0 then return end
		local target, at
		if lastShot and os.clock() - lastShot.t < 0.75 then
			target, at = lastShot.char, lastShot.pos
		else
			target = nearestTarget()
			at = headOf(target)
		end
		if not at then return end
		local onHit = target and target:FindFirstChild("OnHit")
		if onHit and onHit:IsA("BindableEvent") then return end -- firing-range dummies show their own numbers
		popNumber(target, at, damage, zone == "Head", killed == true)
	end)
end

return controller
