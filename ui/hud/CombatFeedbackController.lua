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

-- (2026-10-21, Edward + live RIVALS captures) ONE live number per target with a running total. "As long as the damage
-- indicator hasn't disappeared, the new damage replaces the old one ... and adds the damage on top": a hit while it is alive
-- (even mid-exit) adds to the total, re-plays the pop and restarts its life; only once it has fully gone does the next hit
-- start a fresh one from 0. Life of one number:
--   spawn : a little up-right of the hit point, tilted -20 deg and small; it springs onto the hit point at once
--   hit   : flashes the hit colour (red fill, white outline) with a scale punch and a tilt, then settles to the resting look
--           (white fill, dark outline) while it waits
--   exit  : after LIFE s without a hit it turns ~90 deg, drifts up-right, shrinks and fades
-- Numbers keep one decimal ("11.2", "15"). Sizes are studs (a BillboardGui): it shrinks with distance like the target does.
local LIFE, EXIT = 0.7, 0.45
local FONT_NUM = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local function numberText(n: number): string
	local r = math.floor(n * 10 + 0.5) / 10
	if math.abs(r - math.floor(r + 0.5)) < 0.05 then return tostring(math.floor(r + 0.5)) end
	return string.format("%.1f", r)
end

local function step(p, dt: number)
	local now = os.clock()
	local age = now - p.t
	p.punch *= math.exp(-dt * 11)
	p.flash *= math.exp(-dt * 7)
	p.tilt *= math.exp(-dt * 13)
	p.off *= math.exp(-dt * 22)
	local e = age > LIFE and math.clamp((age - LIFE) / EXIT, 0, 1) or 0
	if e >= 1 then return false end
	local ee = e * e
	local rest, hit = p.rest, p.hitColor
	p.label.TextColor3 = rest:Lerp(hit, math.clamp(p.flash, 0, 1))
	p.stroke.Color = Color3.fromRGB(24, 18, 18):Lerp(Color3.new(1, 1, 1), math.clamp(p.flash, 0, 1))
	p.label.Rotation = p.tilt + 90 * ee
	p.scale.Scale = (1 + 0.45 * p.punch) * (1 - 0.45 * ee)
	p.label.TextTransparency = ee
	p.stroke.Transparency = ee
	p.gui.StudsOffset = Vector3.new(0.5 * p.off + 1.4 * ee, 0.5 * p.off + 1.8 * ee, 0)
	return true
end

local alive = false
local function run()
	if alive then return end
	alive = true
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		local any = false
		for key, p in popups do
			if p.anchor.Parent and step(p, dt) then
				any = true
			else
				p.anchor:Destroy()
				popups[key] = nil
			end
		end
		if not any then alive = false; conn:Disconnect() end
	end)
end

local function popNumber(target: Model?, at: Vector3, damage: number, crit: boolean, killed: boolean)
	if setting("DamageNumbers", true) == false then return end
	local key = target or at
	local p = popups[key]
	local fresh = not (p and p.anchor.Parent)
	if not fresh then
		p.total += damage -- still alive (waiting or mid-exit): add on top, same label
	else
		local anchor = Instance.new("Part")
		anchor.Name = "DamageNumber"
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.1
		anchor.Position = at
		anchor.Parent = workspace.CurrentCamera
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(3.2, 1.5) -- studs: shrinks with distance like a world object
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Adornee = anchor
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = FONT_NUM
		label.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Parent = label
		-- spawn: up-right of the point, tilted and small; the springs pull it onto the point
		p = { gui = gui, label = label, stroke = stroke, scale = scale, anchor = anchor, total = damage,
			punch = -0.6, flash = 1, tilt = -20, off = 1 }
		popups[key] = p
	end
	p.t = os.clock()
	p.anchor.Position = at -- sits on the latest hit point
	p.rest = color("DamageColor", "#ffffff")
	p.hitColor = crit and color("CriticalColor", "#ff3232") or Color3.fromRGB(255, 52, 52)
	p.label.Text = numberText(p.total)
	p.gui.Size = UDim2.fromScale(killed and 4.2 or 3.2, killed and 2 or 1.5)
	-- the hit pop: punch, red flash, a tilt (a headshot punches harder)
	p.punch = crit and 1.4 or 1
	p.flash = 1
	p.tilt = fresh and -20 or (math.random() < 0.5 and -1 or 1) * (crit and 14 or 9)
	run()
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
	Combat:WaitForChild("HitConfirm").OnClientEvent:Connect(function(zone, damage, killed, headshot, _kind, info)
		-- (2026-10-21, lead's [HITINFO]) info = { pos, victim, dealt, source, weapon, pellet, backstab }: the number shows the
		-- health actually removed, at the real hit point, on the real victim (each shotgun pellet adds to the same number)
		if type(info) == "table" then
			local dealt = tonumber(info.dealt) or damage
			if type(dealt) ~= "number" or dealt <= 0 then return end
			local victim = typeof(info.victim) == "Instance" and info.victim or nil
			local at = typeof(info.pos) == "Vector3" and info.pos or headOf(victim)
			if not at then return end
			local onHit = victim and victim:FindFirstChild("OnHit")
			if onHit and onHit:IsA("BindableEvent") then return end -- firing-range dummies show their own numbers
			popNumber(victim, at, dealt, headshot == true, killed == true)
			return
		end
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
		local crit = headshot == true -- gun headshots only (backstabs send no flag)
		popNumber(target, at, damage, crit, killed == true)
	end)
end

return controller
