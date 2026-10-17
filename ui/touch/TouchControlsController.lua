-- Client/Controllers/TouchControlsController (ModuleScript, auto-loaded; lobby + every match place). UI session 2026-10-17.
-- Mobile controls the RIVALS way (Edward; refs notes/ref_mobile 4-16), with Tacticals' own actions:
--   * movement: Roblox's own thumbstick on the left half (its jump button is hidden: ours replaces it)
--   * buttons: Fire, Aim, Reload, Gun Bash, Throw Gadget, Jump, Crouch, Slide (off by default), Take Cover, Dash,
--     Equip Gun / Melee / Gadget (top right, ammo on the gun), Shoulder Swap + Scoreboard (top left)
--   * lobby: only Jump, Crouch, Scoreboard; Training / duels / match places: everything
-- Each button calls the shared input layer (ReplicatedStorage.Modules.Shared.InputActions, built by the Tacticals session):
-- InputActions.Press(action) on touch down, .Release(action) on up. Gameplay controllers listen there ([TOUCH] hooks).
-- Settings > Touch: Left Handed Mode (mirror), Opaque Buttons, Buttons Transparency, Show Weapon Ammo, per button Enabled /
-- Custom (+ its own Transparency), Touch Layout Slot 1-3 (each a JSON layout { [id] = { x, y, s } }, Scale of the screen).
-- Layout Editor: TouchControls.OpenEditor(): hatched overlay, drag a button to move it, drag its ↘ handle to resize;
-- The joystick ring is editable too (saved as "Joystick"; TouchStick reads StickX/StickY/StickSize off its ScreenGui).
-- top pill: X (save + close), reset, slots 1 2 3. Saving goes through TouchControls.OnSave(slot, json) (LobbyUIController).
-- Studio test: set the player attribute _ForceTouch = true to show the controls without a touch screen.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local controller = {}

-- id, action (InputActions), glyph, default { x, y, size } (x/y = Scale of the screen, size = share of the screen height),
-- lobby = shown outside combat too
local BUTTONS = {
	{ id = "Fire", action = "Fire", glyph = "◉", x = 0.905, y = 0.58, s = 0.17 },
	{ id = "Aim", action = "Aim", glyph = "◎", x = 0.815, y = 0.64, s = 0.14 },
	{ id = "Jump", action = "Jump", glyph = "⬆", x = 0.905, y = 0.82, s = 0.17, lobby = true },
	{ id = "Crouch", action = "Crouch", glyph = "⇩", x = 0.80, y = 0.85, s = 0.14, lobby = true },
	{ id = "Slide", action = "Slide", glyph = "↘", x = 0.715, y = 0.85, s = 0.13 },
	{ id = "Take Cover", action = "Cover", glyph = "▣", x = 0.735, y = 0.71, s = 0.11 },
	{ id = "Dash", action = "Dash", glyph = "»", x = 0.70, y = 0.58, s = 0.10 },
	{ id = "Reload", action = "Reload", glyph = "R", x = 0.765, y = 0.535, s = 0.09 },
	{ id = "Gun Bash", action = "QuickMelee", glyph = "✊", x = 0.905, y = 0.235, s = 0.075 },
	{ id = "Throw Gadget", action = "QuickUtility", glyph = "●", x = 0.955, y = 0.235, s = 0.075 },
	{ id = "Equip Gun", action = "Equip1", glyph = "1", x = 0.855, y = 0.115, s = 0.095 },
	{ id = "Equip Melee", action = "Equip2", glyph = "2", x = 0.905, y = 0.115, s = 0.095 },
	{ id = "Equip Gadget", action = "Equip3", glyph = "3", x = 0.955, y = 0.115, s = 0.095 },
	{ id = "Shoulder Swap", action = "CameraSwap", glyph = "⇄", x = 0.04, y = 0.19, s = 0.085 },
	{ id = "Open Scoreboard", action = "Scoreboard", glyph = "≡", x = 0.095, y = 0.19, s = 0.085, lobby = true },
}
local BY_ID = {}
for _, b in BUTTONS do BY_ID[b.id] = b end
-- the joystick (the lead's TouchStick): where it sits when the layout moves it. Unset = its own default half-screen zone.
-- Stored like the buttons, in right-handed space (x mirrored for Left Handed Mode); s = ring diameter / screen height.
local STICK_DEFAULT = { x = 0.2, y = 0.72, s = 0.22 }
local function validStick(t)
	if type(t) ~= "table" or not (tonumber(t.x) and tonumber(t.y) and tonumber(t.s)) then return nil end
	return { x = math.clamp(t.x, 0.05, 0.95), y = math.clamp(t.y, 0.1, 0.95), s = math.clamp(t.s, 0.1, 0.5) }
end

local function setting(name, default)
	local v = player:GetAttribute("Setting_" .. name:gsub("[^%w_]", ""))
	if v == nil then return default end
	return v
end

local InputActions
local function actions()
	if InputActions then return InputActions end
	local m = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	m = m and m:FindFirstChild("InputActions")
	if m then pcall(function() InputActions = require(m) end) end
	return InputActions
end
local function combat()
	local ok, on = pcall(function() return require(ReplicatedStorage.Modules.Shared.TrainingGate).On() end)
	return ok and on == true
end
local function touchOn() return UserInputService.TouchEnabled or player:GetAttribute("_ForceTouch") == true end

-- the saved layout of the chosen slot, merged over the defaults
local function layout()
	local slot = setting("Touch Layout Slot", "1")
	local ok, saved = pcall(function() return HttpService:JSONDecode(setting("Touch Layout " .. slot, "") or "") end)
	local out = {}
	for _, b in BUTTONS do
		local s = ok and type(saved) == "table" and saved[b.id]
		out[b.id] = (type(s) == "table" and tonumber(s.x) and tonumber(s.y) and tonumber(s.s)) and { x = s.x, y = s.y, s = s.s } or { x = b.x, y = b.y, s = b.s }
	end
	out.Joystick = ok and type(saved) == "table" and validStick(saved.Joystick) or nil
	return out, slot
end

---------------------------------------------------------------------------------------------------- the buttons
local gui, holder
local made = {} -- id -> { btn, glyph, ammo, stroke }
local editing = false

local function styleButton(id, m)
	local opaque = setting("Opaque Buttons", true)
	local t = (setting(id .. " Custom", false) and setting(id .. " Transparency", 50) or setting("Buttons Transparency", 50)) / 100
	m.btn.BackgroundTransparency = opaque and (0.15 + 0.7 * t) or 1
	m.stroke.Transparency = 0.2 + 0.6 * t
	m.glyph.TextTransparency = 0.05 + 0.6 * t
	-- for the input layer's touch camera: may a drag that starts on this button also turn the camera?
	local sink
	if setting(id .. " Custom", false) then sink = setting(id .. " Camera Sinking", true) else sink = setting("Buttons Camera Sinking", true) end
	m.btn:SetAttribute("SinkCamera", sink == true)
end

local function place(id, m, l)
	local p = l[id]
	local x = setting("Left Handed Mode", false) and (1 - p.x) or p.x
	m.btn.Position = UDim2.fromScale(x, p.y)
	m.btn.Size = UDim2.fromScale(p.s, p.s)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	for _, b in BUTTONS do
		local btn = Instance.new("TextButton")
		btn.Name = b.id
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.SizeConstraint = Enum.SizeConstraint.RelativeYY -- size = share of the screen height, always round
		btn.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
		btn.Parent = holder
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = btn
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(236, 232, 218); st.Thickness = 2; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = btn
		local g = Instance.new("TextLabel")
		g.BackgroundTransparency = 1
		g.Size = UDim2.fromScale(0.62, 0.62)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Text = b.glyph
		g.TextScaled = true
		g.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
		g.TextColor3 = Color3.fromRGB(236, 232, 218)
		g.Parent = btn
		local ammo
		if b.id == "Equip Gun" then
			ammo = Instance.new("TextLabel")
			ammo.BackgroundTransparency = 1
			ammo.AnchorPoint = Vector2.new(0.5, 0)
			ammo.Position = UDim2.fromScale(0.5, 0.62)
			ammo.Size = UDim2.fromScale(0.9, 0.34)
			ammo.Text = ""
			ammo.TextScaled = true
			ammo.FontFace = g.FontFace
			ammo.TextColor3 = Color3.new(1, 1, 1)
			ammo.Parent = btn
			local as = Instance.new("UIStroke"); as.Thickness = 1.5; as.Parent = ammo
		end
		made[b.id] = { btn = btn, glyph = g, ammo = ammo, stroke = st }
		-- press / release -> the input layer (each touch on its own button: multi-touch works)
		btn.InputBegan:Connect(function(input)
			if editing then return end
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local ia = actions()
			if ia then
				-- this touch belongs to the button; with camera sinking a drag from it may still turn the camera
				if ia.Consume then ia.Consume(input, btn:GetAttribute("SinkCamera") == true) end
				ia.Press(b.action)
			end
			btn.BackgroundColor3 = Color3.fromRGB(70, 74, 60)
		end)
		btn.InputEnded:Connect(function(input)
			if editing then return end
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local ia = actions()
			if ia then ia.Release(b.action) end
			btn.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
		end)
	end
end

-- Roblox's own touch jump button: ours replaces it (the thumbstick stays)
local function hideRobloxJump()
	local tg = player.PlayerGui:FindFirstChild("TouchGui")
	local jb = tg and tg:FindFirstChild("JumpButton", true)
	if jb and jb.Visible then jb.Visible = false end
end

-- the layout's joystick -> TouchStick's ScreenGui attributes (StickX/StickY absolute, so mirrored here)
local function applyStick(j)
	local sg = player.PlayerGui:FindFirstChild("TouchStick")
	if not sg then return end
	local x = j and (setting("Left Handed Mode", false) and (1 - j.x) or j.x)
	local want = { StickX = x or false, StickY = j and j.y or false, StickSize = j and j.s or false }
	for k, v in want do
		if v == false then v = nil end
		if sg:GetAttribute(k) ~= v then sg:SetAttribute(k, v) end
	end
end

local wasShown = false
local function refresh()
	if not gui then return end
	local on = touchOn() and player:GetAttribute("Setting_HideHUD") ~= true and player:GetAttribute("InCutscene") ~= true
	gui.Enabled = on or editing
	local ia = actions()
	if ia and ia.Config then
		-- the input layer's touch rules follow Settings > Touch
		ia.Config.LeftHanded = setting("Left Handed Mode", false)
		ia.Config.DoubleTapAttack = setting("Double Tap To Attack", true) and setting("Fire Enabled", true)
		ia.Config.DoubleTapWindow = setting("Double Tap Window", 0.25)
	end
	-- hidden (HUD off, cutscene, editor): nothing may stay held
	local shown = gui.Enabled and not editing
	if wasShown and not shown and ia and ia.ReleaseAll then ia.ReleaseAll() end
	wasShown = shown
	if not gui.Enabled then return end
	local l = layout()
	applyStick(l.Joystick)
	local inCombat = combat()
	for id, m in made do
		local b = BY_ID[id]
		place(id, m, l)
		styleButton(id, m)
		m.btn.Visible = editing or ((inCombat or b.lobby) and setting(id .. " Enabled", b.id ~= "Slide"))
	end
	-- ammo on the gun button (Show Weapon Ammo)
	local gun = made["Equip Gun"]
	if gun and gun.ammo then
		local tool
		local char = player.Character
		for _, src in { char, player:FindFirstChildOfClass("Backpack") } do
			if src then for _, t in src:GetChildren() do if t:IsA("Tool") and t:GetAttribute("WeaponId") then tool = t end end end
		end
		local a = tool and tool:GetAttribute("Ammo")
		gun.ammo.Visible = setting("Show Weapon Ammo", true) and a ~= nil
		gun.ammo.Text = a and tostring(a) or ""
	end
	hideRobloxJump()
end

---------------------------------------------------------------------------------------------------- layout editor
controller.OnSave = nil -- function(slot, json): set by LobbyUIController (writes Settings > Touch > Touch Layout <slot>)
local overlay

local function hatch(parent, color)
	-- diagonal stripes (RIVALS' editor): thin rotated bars over a tinted wash
	for i = -12, 24 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.BackgroundTransparency = 0.82
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Rotation = 45
		bar.Position = UDim2.fromScale(i / 12, 0.5)
		bar.Size = UDim2.fromScale(0.004, 3)
		bar.Parent = parent
	end
end

function controller.OpenEditor()
	if not gui then build() end
	local ia = actions()
	if ia and ia.ReleaseAll then ia.ReleaseAll() end
	if overlay then overlay:Destroy() end
	editing = true
	local work, slot = layout()
	overlay = Instance.new("Frame")
	overlay.Name = "LayoutEditor"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(70, 110, 40)
	overlay.BackgroundTransparency = 0.55
	overlay.ClipsDescendants = true
	overlay.ZIndex = 0
	overlay.Parent = gui
	hatch(overlay, Color3.fromRGB(20, 40, 10))
	holder.ZIndex = 2
	local function zone(text, x, y)
		local z = Instance.new("TextLabel")
		z.BackgroundTransparency = 1
		z.Text = text
		z.TextScaled = true
		z.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
		z.TextColor3 = Color3.new(0, 0, 0)
		z.TextTransparency = 0.6
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z.Position = UDim2.fromScale(x, y)
		z.Size = UDim2.fromScale(0.3, 0.07)
		z.Parent = overlay
	end
	local left = setting("Left Handed Mode", false)
	if setting("Double Tap To Attack", true) then zone("Double Tap To Attack", left and 0.25 or 0.75, 0.48) end

	-- the joystick: a ring you drag / resize like a button; the faint square around it is where a thumb starts the stick
	local stickZone = Instance.new("Frame")
	stickZone.Name = "JoystickZone"
	stickZone.AnchorPoint = Vector2.new(0.5, 0.5)
	stickZone.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stickZone.BackgroundColor3 = Color3.new(0, 0, 0)
	stickZone.BackgroundTransparency = 0.75
	stickZone.Parent = holder
	local zc = Instance.new("UICorner"); zc.CornerRadius = UDim.new(0.08, 0); zc.Parent = stickZone
	local stick = Instance.new("TextButton")
	stick.Name = "Joystick"
	stick.Text = ""
	stick.AutoButtonColor = false
	stick.AnchorPoint = Vector2.new(0.5, 0.5)
	stick.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stick.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
	stick.BackgroundTransparency = 0.5
	stick.ZIndex = 3
	stick.Parent = holder
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0.5, 0); sc.Parent = stick
	local ss = Instance.new("UIStroke"); ss.Color = Color3.fromRGB(236, 232, 218); ss.Thickness = 2; ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ss.Parent = stick
	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.AnchorPoint = Vector2.new(0.5, 0.5)
	sl.Position = UDim2.fromScale(0.5, 0.5)
	sl.Size = UDim2.fromScale(0.8, 0.22)
	sl.Text = "Joystick"
	sl.TextScaled = true
	sl.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	sl.TextColor3 = Color3.fromRGB(236, 232, 218)
	sl.ZIndex = 3
	sl.Parent = stick
	local function placeStick()
		local j = work.Joystick or STICK_DEFAULT
		local x = left and (1 - j.x) or j.x
		stick.Position, stick.Size = UDim2.fromScale(x, j.y), UDim2.fromScale(j.s, j.s)
		stickZone.Position, stickZone.Size = stick.Position, UDim2.fromScale(j.s * 3, j.s * 3)
		ss.Transparency = work.Joystick and 0.2 or 0.55 -- dimmer while it is still the default zone
	end
	placeStick()

	-- drag + resize handles
	local conns = {}
	local editables = {}
	for id, m in made do editables[id] = m end
	editables.Joystick = { btn = stick }
	for id, m in editables do
		m.btn.Visible = true
		local handle = Instance.new("TextButton")
		handle.Name = "Resize"
		handle.Text = "↘"
		handle.TextScaled = true
		handle.BackgroundTransparency = 1
		handle.TextColor3 = Color3.new(1, 1, 1)
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
		handle.Position = UDim2.fromScale(0.08, 0.08)
		handle.Size = UDim2.fromScale(0.42, 0.42)
		handle.ZIndex = 5
		handle.Parent = m.btn
		local function bindDrag(target, mode)
			table.insert(conns, target.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				local start = input.Position
				if not work[id] then work[id] = table.clone(STICK_DEFAULT) end -- the joystick, first move
				local p0 = table.clone(work[id])
				local vs = workspace.CurrentCamera.ViewportSize
				local moveConn, endConn
				moveConn = UserInputService.InputChanged:Connect(function(i2)
					if i2.UserInputType ~= Enum.UserInputType.Touch and i2.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					local d = i2.Position - start
					local isStick = id == "Joystick"
					if mode == "move" then
						local dx = d.X / vs.X
						work[id].x = math.clamp(p0.x + (left and -dx or dx), isStick and 0.05 or 0.03, isStick and 0.95 or 0.97)
						work[id].y = math.clamp(p0.y + d.Y / vs.Y, isStick and 0.1 or 0.04, isStick and 0.95 or 0.96)
					else
						work[id].s = math.clamp(p0.s - d.Y / vs.Y, isStick and 0.1 or 0.05, isStick and 0.5 or 0.3)
					end
					if isStick then placeStick() else place(id, m, work) end
				end)
				endConn = UserInputService.InputEnded:Connect(function(i3)
					if i3.UserInputType == input.UserInputType then moveConn:Disconnect(); endConn:Disconnect() end
				end)
			end))
		end
		bindDrag(m.btn, "move")
		bindDrag(handle, "resize")
		if id ~= "Joystick" then place(id, m, work) end
	end

	-- top pill: X (save + close) · reset · slots 1 2 3
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.025)
	pill.Size = UDim2.fromScale(0.36, 0.085)
	pill.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
	pill.ZIndex = 10
	pill.Parent = overlay
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.5, 0); pc.Parent = pill
	local slotBtns = {}
	local function pillButton(text, i, fn)
		local b = Instance.new("TextButton")
		b.Text = text
		b.TextScaled = true
		b.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 1
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale((i - 0.5) / 5, 0.5)
		b.Size = UDim2.fromScale(0.16, 0.78)
		b.ZIndex = 11
		b.Parent = pill
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
		b.Activated:Connect(fn)
		return b
	end
	local function json()
		local out = {}
		for id, p in work do out[id] = { x = math.floor(p.x * 1000 + 0.5) / 1000, y = math.floor(p.y * 1000 + 0.5) / 1000, s = math.floor(p.s * 1000 + 0.5) / 1000 } end
		return HttpService:JSONEncode(out)
	end
	local function close()
		if controller.OnSave then controller.OnSave(slot, json()) end
		for _, c in conns do c:Disconnect() end
		for _, m in made do local h = m.btn:FindFirstChild("Resize") if h then h:Destroy() end end
		stick:Destroy(); stickZone:Destroy()
		editing = false
		overlay:Destroy(); overlay = nil
		refresh()
	end
	pillButton("×", 1, close)
	pillButton("Reset", 2, function()
		for _, b in BUTTONS do work[b.id] = { x = b.x, y = b.y, s = b.s } end
		work.Joystick = nil -- back to TouchStick's own default zone
		for id, m in made do place(id, m, work) end
		placeStick()
	end)
	for n = 1, 3 do
		slotBtns[n] = pillButton(tostring(n), 2 + n, function()
			if controller.OnSave then controller.OnSave(slot, json()) end -- keep the slot you were on
			slot = tostring(n)
			if controller.OnSlot then controller.OnSlot(slot) end
			-- the new slot's saved layout (or the defaults)
			local ok, saved = pcall(function() return HttpService:JSONDecode(setting("Touch Layout " .. slot, "") or "") end)
			for _, b in BUTTONS do
				local s = ok and type(saved) == "table" and saved[b.id]
				work[b.id] = type(s) == "table" and { x = s.x, y = s.y, s = s.s } or { x = b.x, y = b.y, s = b.s }
			end
			work.Joystick = ok and type(saved) == "table" and validStick(saved.Joystick) or nil
			for id, m in made do place(id, m, work) end
			placeStick()
			for k, sb in slotBtns do sb.BackgroundTransparency = k == n and 0 or 1; sb.TextColor3 = k == n and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end
		end)
	end
	for k, sb in slotBtns do sb.BackgroundTransparency = tostring(k) == slot and 0 or 1; sb.TextColor3 = tostring(k) == slot and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end
	gui.Enabled = true
end

function controller.IsEditing() return editing end

function controller.Start()
	build()
	-- respawn / focus lost: let go of everything
	player.CharacterAdded:Connect(function() local ia = actions() if ia and ia.ReleaseAll then ia.ReleaseAll() end end)
	UserInputService.WindowFocusReleased:Connect(function() local ia = actions() if ia and ia.ReleaseAll then ia.ReleaseAll() end end)
	-- refresh a few times a second (settings, combat state, ammo, Roblox's touch gui appearing late)
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if t < 0.2 then return end
		t = 0
		if not editing then refresh() end
	end)
	refresh()
	-- Studio only: PlayerScripts.TouchTest:Invoke(action, seconds) presses an action through the real input layer
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "TouchTest"
		hook.OnInvoke = function(action, seconds)
			local ia = actions()
			if not ia then return "no InputActions" end
			ia.Press(action)
			task.wait(seconds or 0.1)
			ia.Release(action)
			return "pressed " .. tostring(action)
		end
		hook.Parent = player:WaitForChild("PlayerScripts")
	end
end

return controller
