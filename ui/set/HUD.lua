-- StarterPlayer/StarterPlayerScripts/Client/GUIs/HUD (ModuleScript)
-- Drives the in-game HUD (StarterGui/HUD): crosshair, "blocked shot" marker,
-- hitmarker and ammo counter. Display only: it never decides anything about combat.
--
-- API:
--   HUD.SetWeapon(displayName?)              -- nil hides the ammo display
--   HUD.SetAmmo(current, max, reloading)
--   HUD.SetBlocked(screenPosition?)          -- Vector2 where cover blocks the shot, nil to hide
--   HUD.ShowHitmarker(zone, killed)        -- [SET] headshots: critical colour (Settings > Damage Numbers > Critical
--                                            Color), a bigger pop, a ring that snaps out and a two-layer "tink" (Edward:
--                                            "the crosshair should be different on critical headshots")
--   HUD.SetCrosshair(visible, aimed)        -- the centre dot: solid while aimed in, 75% see-through otherwise
--   HUD.SetCrosshairVisible(visible)        -- (old name: same as SetCrosshair(visible, true))
--   HUD.ShowDamageFrom(worldPosition)       -- red marker around the screen centre pointing at the shooter

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- // Constants
local HIT_COLORS = {
	Body = Color3.fromRGB(255, 255, 255),
	Limb = Color3.fromRGB(255, 255, 255),
	Head = Color3.fromRGB(255, 92, 124),
	Extremity = Color3.fromRGB(190, 196, 214),
}
-- (2026-10-17, Edward: head and body markers still looked the same) red belongs to crits only: a body kill is bone
-- white and a little bigger, a headshot is a big red X with a ring, a longer hold and its own sound
local KILL_COLOR = Color3.fromRGB(236, 232, 218)
local HITMARKER_TIME = 0.25
local CRIT_TIME = 0.45
local CRIT_SOUND = "rbxasset://sounds/electronicpingshort.wav" -- Roblox client sound, no upload

-- // Root
local hud = {}
local gui: ScreenGui?
local hitToken = 0

local function getGui(): ScreenGui
	if not gui then
		gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD") :: ScreenGui
	end
	return gui :: ScreenGui
end

-- (the ammo now shows on the gun's hotbar tile, bottom right: HotbarController reads hud.GetAmmo)
local lastAmmo = { current = 0, reserve = 0, reloading = false }
function hud.GetAmmo(): (number, number, boolean)
	return lastAmmo.current, lastAmmo.reserve, lastAmmo.reloading
end

function hud.SetWeapon(displayName: string?)
	local ammo = getGui().AmmoDisplay
	ammo.Visible = false
	if displayName then
		ammo.WeaponName.Text = displayName
	end
	if not displayName then
		hud.SetBlocked(nil)
	end
end

function hud.SetAmmo(current: number, reserve: number, reloading: boolean)
	lastAmmo.current, lastAmmo.reserve, lastAmmo.reloading = current, reserve, reloading
	local ammo = getGui().AmmoDisplay
	ammo.Count.Text = `{current} / {reserve}`
	ammo.Count.TextColor3 = current == 0 and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1)
	ammo.Status.Text = reloading and "RELOADING" or (current == 0 and (reserve > 0 and "PRESS R" or "NO AMMO") or "")
end

-- The dot is always there while you're alive (gun, melee or gadget in hand): faint when you're not aimed
-- in, solid the moment you aim.
local CROSSHAIR_IDLE = 0.75 -- transparency when not aimed in
local crosshairAimed = nil
function hud.SetCrosshair(visible: boolean, aimed: boolean)
	local crosshair = getGui().Crosshair
	if crosshair.Visible ~= visible then
		crosshair.Visible = visible
	end
	if crosshairAimed ~= aimed then
		crosshairAimed = aimed
		local info = TweenInfo.new(aimed and 0.08 or 0.18, Enum.EasingStyle.Quad)
		TweenService:Create(crosshair, info, { BackgroundTransparency = aimed and 0 or CROSSHAIR_IDLE }):Play()
		local stroke = crosshair:FindFirstChildOfClass("UIStroke")
		if stroke then
			-- the outline fades with it so the faint dot doesn't become a dark ring
			TweenService:Create(stroke, info, { Transparency = aimed and 0.3 or 1 - (1 - 0.3) * (1 - CROSSHAIR_IDLE) }):Play()
		end
	end
end

function hud.SetCrosshairVisible(visible: boolean)
	hud.SetCrosshair(visible, true)
end

function hud.SetBlocked(screenPosition: Vector2?)
	local marker = getGui().BlockedMarker
	marker.Visible = screenPosition ~= nil
	if screenPosition then
		marker.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	end
end

local function criticalColor(): Color3
	local v = Players.LocalPlayer:GetAttribute("Setting_CriticalColor")
	if typeof(v) == "Color3" then return v end
	local ok, c = pcall(Color3.fromHex, tostring(v or "#ff3232"))
	return ok and c or Color3.fromRGB(255, 50, 50)
end

-- the ring around a headshot hitmarker: snaps out from the marker and fades (Scale of the marker, so it follows its size)
local function headRing(marker: GuiObject, color: Color3)
	local ring = Instance.new("Frame")
	ring.Name = "HeadRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.9, 0.9)
	ring.BackgroundTransparency = 1
	ring.ZIndex = marker.ZIndex + 1
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0.5, 0) corner.Parent = ring
	local stroke = Instance.new("UIStroke") stroke.Color = color stroke.Thickness = 2.5 stroke.Parent = ring
	ring.Parent = marker
	local info = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromScale(2.1, 2.1) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.35, function() ring:Destroy() end)
end

function hud.ShowHitmarker(zone: string, killed: boolean, headshot: boolean?)
	local root = getGui()
	local marker = root.Hitmarker
	local head = headshot == true -- the server's flag: gun hits on the head only (backstabs send none)
	local color = head and criticalColor() or killed and KILL_COLOR or HIT_COLORS[zone] or HIT_COLORS.Body

	hitToken += 1
	local token = hitToken

	marker.Visible = true
	-- crit: starts at 2.5x and settles at 1.7x a body hit (a body kill sits between the two)
	-- sizes are 1080p px, scaled to the screen height (a phone got the PC size before)
	local f = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 1080, 0.35, 2)
	local from, to = head and 66 or (killed and 40 or 34), head and 44 or (killed and 30 or 26)
	marker.Size = UDim2.fromOffset(from * f, from * f)
	TweenService:Create(marker, TweenInfo.new(head and 0.16 or 0.08, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(to * f, to * f) }):Play()
	marker.Rotation = head and 12 or 0
	if head then TweenService:Create(marker, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Rotation = 0 }):Play() end
	local life = head and CRIT_TIME or HITMARKER_TIME

	for _, line in marker:GetChildren() do
		if line:IsA("Frame") and line.Name ~= "HeadRing" then -- (the ring got filled in here: a solid red disc)
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0
			TweenService:Create(line, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	if head then
		for _, old in marker:GetChildren() do if old.Name == "HeadRing" then old:Destroy() end end
		headRing(marker, color) -- after the line colouring, so it stays a ring
	end

	local sound = root:FindFirstChild("HitSound")
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = head and 1.15 or 1
		sound:Play()
		if head then
			-- the crit has its own sound on top: a bright ping (not a re-pitched hit)
			local ping = Instance.new("Sound")
			ping.SoundId = CRIT_SOUND
			ping.Volume = math.max(0.6, sound.Volume)
			ping.PlaybackSpeed = 1.1
			ping.Parent = root
			ping:Play()
			task.delay(1.5, function() ping:Destroy() end)
		end
	end

	task.delay(life, function()
		if hitToken == token then
			marker.Visible = false
		end
	end)
end

-- // Damage direction markers + red vignette (RIVALS, checked live 2026-10-18 with Edward): a hit pulses a red vignette in
-- from the screen edges and puts a red chevron around the crosshair pointing at the shooter; below half health the
-- vignette stays, deeper the lower you are. Own full-screen layer in the HUD gui, all Scale.
local DAMAGE_MARKER_TIME = 1.4
local DAMAGE_MARKER_RADIUS = 0.13 -- of the screen height, from the centre
local RED = Color3.fromRGB(235, 28, 18)
local activeMarkers = {} -- { frame, bars, source, born }
local markerLoop: RBXScriptConnection?
local flashAt = -10

local layer, edges
local function damageLayer()
	if layer and layer.Parent then return layer end
	layer = Instance.new("Frame")
	layer.Name = "RivalsDamage"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 20
	layer.Parent = getGui()
	edges = {}
	-- four edge strips, each a red fade from the edge inwards (UIGradient: Rotation 90 = top to bottom)
	for _, e in { { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.34), 90 }, { UDim2.fromScale(0, 0.66), UDim2.fromScale(1, 0.34), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.24, 1), 0 }, { UDim2.fromScale(0.76, 0), UDim2.fromScale(0.24, 1), 180 } } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = RED
		f.Position, f.Size = e[1], e[2]
		f.ZIndex = 20
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(1)
		g.Parent = f
		f.Parent = layer
		table.insert(edges, g)
	end
	return layer
end

local function vignetteLevel(): number
	local flash = math.clamp(1 - (os.clock() - flashAt) / 0.7, 0, 1)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local low = 0
	if hum and hum.Health > 0 and hum.MaxHealth > 0 then low = math.clamp((0.5 - hum.Health / hum.MaxHealth) / 0.5, 0, 1) * 0.7 end
	return math.max(flash * 0.85, low)
end

local function updateMarkers()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	local vp = camera.ViewportSize
	local aspect = vp.Y / math.max(vp.X, 1)
	for i = #activeMarkers, 1, -1 do
		local m = activeMarkers[i]
		local age = now - m.born
		if age >= DAMAGE_MARKER_TIME then
			m.frame:Destroy()
			table.remove(activeMarkers, i)
		else
			-- Direction to the shooter relative to where the camera faces (flattened)
			local relative = camera.CFrame:VectorToObjectSpace(m.source - camera.CFrame.Position)
			local angle = math.atan2(relative.X, -relative.Z)
			m.frame.Position = UDim2.fromScale(0.5 + math.sin(angle) * DAMAGE_MARKER_RADIUS * aspect, 0.5 - math.cos(angle) * DAMAGE_MARKER_RADIUS)
			m.frame.Rotation = math.deg(angle)
			local t = math.clamp((age / DAMAGE_MARKER_TIME) ^ 2, 0, 1)
			for _, b in m.bars do b.BackgroundTransparency = t end
		end
	end
	-- the vignette
	local v = vignetteLevel()
	if edges then
		local seqT = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - v * 0.8), NumberSequenceKeypoint.new(1, 1) })
		for _, g in edges do g.Transparency = seqT end
	end
	if #activeMarkers == 0 and v <= 0 and markerLoop then
		markerLoop:Disconnect()
		markerLoop = nil
	end
end

local function ensureLoop()
	if not markerLoop then markerLoop = game:GetService("RunService").RenderStepped:Connect(updateMarkers) end
end
-- low health keeps the vignette up between hits (healing fades it)
task.spawn(function()
	local function watch(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then hum.HealthChanged:Connect(function() damageLayer(); ensureLoop() end) end
	end
	local plr = Players.LocalPlayer
	if plr.Character then task.spawn(watch, plr.Character) end
	plr.CharacterAdded:Connect(watch)
end)

function hud.ShowDamageFrom(source: Vector3)
	local l = damageLayer()
	flashAt = os.clock()
	-- a red chevron pointing out at the shooter (^ at angle 0 = straight ahead)
	local frame = Instance.new("Frame")
	frame.Name = "Marker"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	frame.Size = UDim2.fromScale(0.07, 0.07)
	frame.ZIndex = 21
	local bars = {}
	for _, side in { -1, 1 } do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = RED
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5 + side * 0.2, 0.42)
		b.Size = UDim2.fromScale(0.55, 0.13)
		b.Rotation = side * 38
		b.ZIndex = 21
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		b.Parent = frame
		table.insert(bars, b)
	end
	frame.Parent = l
	table.insert(activeMarkers, { frame = frame, bars = bars, source = source, born = os.clock() })
	ensureLoop()
	updateMarkers()
end

-- // Weapon ability HUD (2026-10-19, Edward's weapon design: notes/weapon_abilities.md). All Scale, around the crosshair.
--   Semi-Auto "Precision Rhythm": three pips under the crosshair, filled by the player attribute RhythmStacks (0..3).
--   Revolver "Knockback Shot": a ring around the crosshair that tightens and turns gold while RevolverReady is true.
--   Fists "Vault Takedown": hud.ShowTakedown() - a big TAKEDOWN that pops in and out (the Tacticals session's hit event calls it).
local abilityLayer, pips, ring, ringStroke, takedown
local function abilityHud()
	if abilityLayer and abilityLayer.Parent then return end
	abilityLayer = Instance.new("Frame")
	abilityLayer.Name = "AbilityHUD"
	abilityLayer.BackgroundTransparency = 1
	abilityLayer.Size = UDim2.fromScale(1, 1)
	abilityLayer.ZIndex = 15
	abilityLayer.Parent = getGui()
	-- the pips: a row of three small rounded bars under the centre
	local row = Instance.new("Frame")
	row.Name = "RhythmPips"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0.535)
	row.Size = UDim2.fromScale(0.05, 0.012)
	row.Visible = false
	row.Parent = abilityLayer
	local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 6; ar.Parent = row
	pips = {}
	for i = 1, 3 do
		local p = Instance.new("Frame")
		p.BorderSizePixel = 0
		p.BackgroundColor3 = Color3.new(1, 1, 1)
		p.BackgroundTransparency = 0.7
		p.Position = UDim2.fromScale((i - 1) * 0.36, 0)
		p.Size = UDim2.fromScale(0.28, 1)
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = p
		local s = Instance.new("UIStroke"); s.Thickness = 1; s.Transparency = 0.5; s.Parent = p
		local sc = Instance.new("UIScale"); sc.Parent = p
		p.Parent = row
		pips[i] = { f = p, sc = sc, on = false }
	end
	pips.row = row
	-- the revolver ring
	ring = Instance.new("Frame")
	ring.Name = "RevolverRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.Size = UDim2.fromScale(0.07, 0.07)
	ring.Visible = false
	ring.Parent = abilityLayer
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.5, 0); rc.Parent = ring
	ringStroke = Instance.new("UIStroke"); ringStroke.Thickness = 2; ringStroke.Color = Color3.new(1, 1, 1); ringStroke.Transparency = 0.6; ringStroke.Parent = ring
	-- the TAKEDOWN marker
	takedown = Instance.new("TextLabel")
	takedown.Name = "Takedown"
	takedown.BackgroundTransparency = 1
	takedown.AnchorPoint = Vector2.new(0.5, 0.5)
	takedown.Position = UDim2.fromScale(0.5, 0.4)
	takedown.Size = UDim2.fromScale(0.4, 0.09)
	takedown.TextScaled = true
	takedown.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	takedown.Text = "TAKEDOWN"
	takedown.TextColor3 = Color3.fromRGB(255, 205, 60)
	takedown.Visible = false
	takedown.ZIndex = 16
	local ts = Instance.new("UIStroke"); ts.Thickness = 3; ts.Transparency = 0.1; ts.Parent = takedown
	local tsc = Instance.new("UIScale"); tsc.Parent = takedown
	takedown.Parent = abilityLayer
end

local function equippedName(): string?
	local char = Players.LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool and (tool:GetAttribute("ItemId") or tool.Name) or nil
end

local lastStacks, lastReady = -1, nil
game:GetService("RunService").RenderStepped:Connect(function()
	local g = gui or Players.LocalPlayer:FindFirstChild("PlayerGui") and Players.LocalPlayer.PlayerGui:FindFirstChild("HUD")
	if not g then return end
	gui = g
	abilityHud()
	local cross = g:FindFirstChild("Crosshair")
	local showing = cross ~= nil and cross.Visible
	local name = equippedName()
	-- Precision Rhythm pips
	local stacks = tonumber(Players.LocalPlayer:GetAttribute("RhythmStacks")) or 0
	local semi = name == "SemiAuto" or name == "Semi-Auto"
	pips.row.Visible = showing and semi
	if stacks ~= lastStacks then
		for i, p in ipairs(pips) do
			local on = i <= stacks
			if on and not p.on then -- a new stack pops in gold
				p.sc.Scale = 1.6
				TweenService:Create(p.sc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			p.on = on
			p.f.BackgroundColor3 = on and Color3.fromRGB(255, 205, 60) or Color3.new(1, 1, 1)
			p.f.BackgroundTransparency = on and 0 or 0.7
		end
		lastStacks = stacks
	end
	-- Knockback Shot ring
	local ready = Players.LocalPlayer:GetAttribute("RevolverReady") == true
	ring.Visible = showing and name == "Revolver"
	if ready ~= lastReady then
		lastReady = ready
		TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ready and 0.045 or 0.07, ready and 0.045 or 0.07) }):Play()
		TweenService:Create(ringStroke, TweenInfo.new(0.18), { Color = ready and Color3.fromRGB(255, 205, 60) or Color3.new(1, 1, 1), Transparency = ready and 0 or 0.6,
			Thickness = ready and 3 or 2 }):Play()
	end
end)

local takedownToken = 0
function hud.ShowTakedown()
	abilityHud()
	takedownToken += 1
	local my = takedownToken
	local sc = takedown:FindFirstChildOfClass("UIScale")
	takedown.Visible = true
	takedown.TextTransparency = 0
	sc.Scale = 1.8
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.2, function()
		if takedownToken ~= my then return end
		TweenService:Create(takedown, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.32, function() if takedownToken == my then takedown.Visible = false end end)
	end)
end

-- // Item HUD (2026-10-19, lead's hooks): Medkit channel bar, Bat charge ring, Riot Shield health, Katana parry flash. All Scale.
--   MedkitUntil (player, server time; channel 2.5 s), MeleeChargeStart (player, os.clock; Bat full at 0.8 s),
--   ShieldHealth / ShieldBroken (held tool; of 400), ParryUntil (character, server time; window 0.35 s).
do
	-- tunables come from the configs (Edward tunes them there); the numbers here are only fallbacks
	local MEDKIT_TIME, BAT_TIME, SHIELD_MAX = 2.5, 0.8, 400
	pcall(function()
		local Cfg = game:GetService("ReplicatedStorage").Modules.Shared.Config
		local G, M = require(Cfg.GadgetConfig), require(Cfg.MeleeConfig)
		MEDKIT_TIME = G.Medkit.ChannelTime or MEDKIT_TIME
		BAT_TIME = M.Weapons.Bat.Charge.Time or BAT_TIME
		SHIELD_MAX = M.Weapons.RiotShield.Shield.Health or SHIELD_MAX
	end)
	local GOLD, GREEN, RED, CYAN = Color3.fromRGB(255, 205, 60), Color3.fromRGB(90, 190, 255), Color3.fromRGB(235, 70, 60), Color3.fromRGB(120, 220, 255)
	local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	local items -- built lazily inside the ability layer
	local function corner(o) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = o end
	-- a rounded labelled bar: { box, fill, label }
	local function bar(name, y, label, color)
		local box = Instance.new("Frame")
		box.Name = name
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.fromScale(0.5, y)
		box.Size = UDim2.fromScale(0.12, 0.011)
		box.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
		box.BackgroundTransparency = 0.35
		box.BorderSizePixel = 0
		box.Visible = false
		box.ZIndex = 15
		corner(box)
		local st = Instance.new("UIStroke"); st.Thickness = 1; st.Transparency = 0.6; st.Parent = box
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.ZIndex = 16
		corner(fill)
		local gr = Instance.new("UIGradient")
		gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) })
		gr.Parent = fill
		fill.Parent = box
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 1)
		t.Position = UDim2.fromScale(0.5, -0.4)
		t.Size = UDim2.fromScale(1, 1.6)
		t.TextScaled = true
		t.FontFace = FONT
		t.Text = label
		t.TextColor3 = Color3.new(1, 1, 1)
		t.ZIndex = 16
		local ts = Instance.new("UIStroke"); ts.Thickness = 1.5; ts.Transparency = 0.3; ts.Parent = t
		t.Parent = box
		box.Parent = abilityLayer
		return { box = box, fill = fill, label = t }
	end
	-- a ring around the crosshair with a disc growing inside it
	local function ringWithDisc(name, color)
		local r = Instance.new("Frame")
		r.Name = name
		r.BackgroundTransparency = 1
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.SizeConstraint = Enum.SizeConstraint.RelativeYY
		r.Size = UDim2.fromScale(0.08, 0.08)
		r.Visible = false
		r.ZIndex = 15
		corner(r)
		local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = color; st.Transparency = 0.3; st.Parent = r
		local d = Instance.new("Frame")
		d.Name = "Disc"
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(0.5, 0.5)
		d.Size = UDim2.fromScale(0, 0)
		d.BackgroundColor3 = color
		d.BackgroundTransparency = 0.75
		d.BorderSizePixel = 0
		d.ZIndex = 15
		corner(d)
		d.Parent = r
		r.Parent = abilityLayer
		return { ring = r, stroke = st, disc = d }
	end
	local function build()
		if items and items.medkit.box.Parent == abilityLayer then return end
		items = {
			medkit = bar("MedkitBar", 0.6, "HEALING", GREEN),
			shield = bar("ShieldBar", 0.64, "SHIELD", Color3.fromRGB(150, 190, 230)),
			bat = ringWithDisc("BatCharge", Color3.new(1, 1, 1)),
			parry = ringWithDisc("ParryFlash", CYAN),
		}
	end

	local wasFull, lastParry, shieldWasBroken = false, nil, false
	game:GetService("RunService").RenderStepped:Connect(function()
		if not abilityLayer or not abilityLayer.Parent then return end
		build()
		local lp = Players.LocalPlayer
		local char = lp.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		local now = workspace:GetServerTimeNow()
		-- Medkit: fills over the channel, hidden once done or cancelled
		local untilT = tonumber(lp:GetAttribute("MedkitUntil"))
		local left = untilT and (untilT - now) or 0
		items.medkit.box.Visible = left > 0
		if left > 0 then
			items.medkit.fill.Size = UDim2.fromScale(math.clamp(1 - left / MEDKIT_TIME, 0, 1), 1)
		end
		-- Bat: the disc grows to fill the ring; full = gold + a pop
		local start = tonumber(lp:GetAttribute("MeleeChargeStart"))
		local charging = start ~= nil and tool ~= nil and (tool:GetAttribute("MeleeId") or tool.Name) == "Bat"
		items.bat.ring.Visible = charging
		if charging then
			local k = math.clamp((os.clock() - start) / BAT_TIME, 0, 1)
			items.bat.disc.Size = UDim2.fromScale(k, k)
			local full = k >= 1
			if full and not wasFull then
				items.bat.ring.Size = UDim2.fromScale(0.1, 0.1)
				TweenService:Create(items.bat.ring, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.08, 0.08) }):Play()
			end
			items.bat.stroke.Color = full and GOLD or Color3.new(1, 1, 1)
			items.bat.disc.BackgroundColor3 = full and GOLD or Color3.new(1, 1, 1)
			items.bat.disc.BackgroundTransparency = full and 0.55 or 0.75
			wasFull = full
		else
			wasFull = false
		end
		-- Riot Shield: health bar while held; BROKEN in red
		local hp = tool and tonumber(tool:GetAttribute("ShieldHealth"))
		items.shield.box.Visible = hp ~= nil
		if hp then
			local broken = tool:GetAttribute("ShieldBroken") == true
			items.shield.fill.Size = UDim2.fromScale(broken and 0 or math.clamp(hp / SHIELD_MAX, 0, 1), 1)
			items.shield.fill.BackgroundColor3 = hp / SHIELD_MAX < 0.3 and RED or Color3.fromRGB(150, 190, 230)
			items.shield.label.Text = broken and "SHIELD BROKEN" or "SHIELD"
			items.shield.label.TextColor3 = broken and RED or Color3.new(1, 1, 1)
			if broken and not shieldWasBroken then
				items.shield.box.Position = UDim2.fromScale(0.508, 0.64)
				TweenService:Create(items.shield.box, TweenInfo.new(0.25, Enum.EasingStyle.Elastic), { Position = UDim2.fromScale(0.5, 0.64) }):Play()
			end
			shieldWasBroken = broken
		else
			shieldWasBroken = false
		end
		-- Katana parry: a cyan ring snaps out and fades over the window
		local pu = char and tonumber(char:GetAttribute("ParryUntil"))
		if pu ~= lastParry then
			lastParry = pu
			if pu and pu > now then
				local r = items.parry
				r.ring.Visible = true
				r.ring.Size = UDim2.fromScale(0.05, 0.05)
				r.stroke.Transparency = 0
				r.stroke.Thickness = 3
				r.disc.Size = UDim2.fromScale(1, 1)
				r.disc.BackgroundTransparency = 0.7
				local ti = TweenInfo.new(math.max(pu - now, 0.15), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				TweenService:Create(r.ring, ti, { Size = UDim2.fromScale(0.13, 0.13) }):Play()
				TweenService:Create(r.stroke, ti, { Transparency = 1, Thickness = 1 }):Play()
				TweenService:Create(r.disc, ti, { BackgroundTransparency = 1 }):Play()
			end
		end
		if items.parry.ring.Visible and not (pu and pu > now) then items.parry.ring.Visible = false end
	end)
end

-- // Crosshair countdown (2026-10-19, lead's API ed4f0db; RIVALS' ring that fills around the crosshair). All Scale.
--   LocalPlayer attributes in os.clock() time: Xhair<Kind>End / Xhair<Kind>Time for Draw (gun coming out), Reload (the Pump
--   resets per shell), Fire (next shot, slow guns only). Shown while End > os.clock(); one arc, priority Draw > Reload > Fire.
--   The arc: two clipped half-rings, each a UIStroke with a hard-stop UIGradient turned to the progress angle (no images).
do
	local KINDS = { "Draw", "Reload", "Fire" }
	local LOOK = { Draw = { 0.35, 2.5 }, Reload = { 0, 3 }, Fire = { 0.2, 2 } }   -- stroke transparency, thickness
	local arc -- { root, track, halves = { right = gradient, left = gradient }, strokes }
	local STEP = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
	local function ringFrame(parent, size, pos)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = size
		f.Position = pos
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f
		f.Parent = parent
		return f
	end
	local function build()
		if arc and arc.root.Parent == abilityLayer then return end
		local root = Instance.new("Frame")
		root.Name = "XhairCountdown"
		root.BackgroundTransparency = 1
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.SizeConstraint = Enum.SizeConstraint.RelativeYY
		root.Size = UDim2.fromScale(0.046, 0.046)
		root.Visible = false
		root.ZIndex = 15
		root.Parent = abilityLayer
		local track = ringFrame(root, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
		local ts = Instance.new("UIStroke"); ts.Thickness = 3; ts.Color = Color3.new(0, 0, 0); ts.Transparency = 0.7; ts.Parent = track
		arc = { root = root, halves = {}, strokes = {} }
		for _, side in { "right", "left" } do
			local clip = Instance.new("Frame")
			clip.Name = "Half_" .. side
			clip.BackgroundTransparency = 1
			clip.ClipsDescendants = true
			clip.Size = UDim2.fromScale(0.5, 1)
			clip.Position = UDim2.fromScale(side == "right" and 0.5 or 0, 0)
			clip.Parent = root
			-- the full ring, twice the clip's width, shifted so its centre sits on the clip's inner edge
			local ring = ringFrame(clip, UDim2.fromScale(2, 1), UDim2.fromScale(side == "right" and -1 or 0, 0))
			local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.new(1, 1, 1); st.Parent = ring
			local g = Instance.new("UIGradient"); g.Transparency = STEP; g.Parent = st
			arc.halves[side] = g
			table.insert(arc.strokes, st)
		end
	end
	-- progress 0..1 clockwise from the top: right half shows 0..180 degrees, left half 180..360
	local function setProgress(p)
		local a = math.clamp(p, 0, 1) * 360
		arc.halves.right.Rotation = math.min(a, 180)
		arc.halves.left.Rotation = math.max(a, 180)
	end

	game:GetService("RunService").RenderStepped:Connect(function()
		if not abilityLayer or not abilityLayer.Parent then return end
		build()
		local lp = Players.LocalPlayer
		local now = os.clock()
		local kind, p
		for _, k in KINDS do
			local e, t = tonumber(lp:GetAttribute("Xhair" .. k .. "End")), tonumber(lp:GetAttribute("Xhair" .. k .. "Time"))
			if e and t and t > 0 and e > now then
				kind, p = k, 1 - (e - now) / t
				break
			end
		end
		arc.root.Visible = kind ~= nil
		if kind then
			setProgress(p)
			for _, st in arc.strokes do st.Transparency, st.Thickness = LOOK[kind][1], LOOK[kind][2] end
		end
	end)
end

return hud
