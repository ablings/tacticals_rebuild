-- touch_install.lua : the mobile input layer (notes/touch_mobile.md), 2026-10-17. Built by tools/touch_build.py from
-- scripts/touch/* (sources embedded below). Idempotent, works in the lobby and the match place:
--   lobby       python tools/touch_build.py --run lobby        (studio 829eb64d)
--   match place python tools/touch_build.py --run match        (studio 331cb3a0)
--   UNDO        add UNDO to either line
-- New (attribute TouchInstall = true): ReplicatedStorage.Modules.Shared.InputActions, StarterPlayerScripts.TouchFire + TouchStick (LocalScripts)
-- Changed: StarterPlayer.DevTouchMovementMode = Scriptable (our TouchStick replaces Roblox's thumbstick; the old value is kept
--   in StarterPlayer attribute TouchOrigMoveMode and restored by UNDO)
local UNDO = false --@UNDO

local RS = game:GetService("ReplicatedStorage")
local CHS = game:GetService("ChangeHistoryService")
local TAG = "TouchInstall"
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.InputActions = [=[-- ReplicatedStorage.Modules.Shared.InputActions [TOUCH] (2026-10-17, Edward: mobile UI the RIVALS way)
-- One input-agnostic layer between the touch HUD and the gameplay controllers. The touch buttons (UI session) call
-- Press/Release; each controller keeps its own ContextActionService binds for keyboard and gamepad and also listens here
-- with Bind, so one handler serves every input type.
--
--   InputActions.Press("Reload")             -- a touch button went down
--   InputActions.Release("Reload")           -- and up (Press/Release pairs are counted, so two fingers are safe)
--   InputActions.Tap("Equip1")               -- Press + Release in one call
--   local c = InputActions.Bind("Reload", function(state, action) ... end)   -- state = Enum.UserInputState.Begin / End
--   c:Disconnect()
--   InputActions.IsHeld("Fire")
--   InputActions.Touching()                  -- true while any action is held by touch
--
-- The handler gets the same arguments a ContextActionService callback gets: (actionName, Enum.UserInputState, fakeInput),
-- so a controller can pass its existing CAS handler straight to BindCAS.
--   InputActions.BindCAS("Reload", onInput)  -- onInput(actionName, state, input) with state Begin/End
local InputActions = {}

InputActions.Names = {
	"Fire", "Aim", "Reload", "Inspect", "Jump", "Crouch", "Slide", "Dash", "Cover",
	"QuickMelee", "QuickUtility", "ThrowGadget", "Equip1", "Equip2", "Equip3",
	"Scoreboard", "CameraSwap",
}
local known = {}
for _, n in InputActions.Names do known[n] = true end

local handlers = {} -- action -> { fn = true }
local held = {}     -- action -> press count
local anyHeld = 0

local function fire(action, down)
	local list = handlers[action]
	if not list then return end
	local state = down and Enum.UserInputState.Begin or Enum.UserInputState.End
	for fn in list do
		task.spawn(fn, state, action)
	end
end

local function check(action)
	if not known[action] then warn("[InputActions] unknown action " .. tostring(action)) end
end

function InputActions.Press(action)
	check(action)
	held[action] = (held[action] or 0) + 1
	anyHeld += 1
	if held[action] == 1 then fire(action, true) end
end

function InputActions.Release(action)
	local n = held[action]
	if not n or n <= 0 then return end
	held[action] = n - 1
	anyHeld = math.max(0, anyHeld - 1)
	if held[action] == 0 then fire(action, false) end
end

function InputActions.Tap(action)
	InputActions.Press(action)
	InputActions.Release(action)
end

-- Releases everything (the HUD calls it when it hides, a respawn, or the app losing focus) so nothing stays held.
function InputActions.ReleaseAll()
	for action, n in held do
		if n > 0 then
			held[action] = 0
			fire(action, false)
		end
	end
	anyHeld = 0
end

function InputActions.IsHeld(action)
	return (held[action] or 0) > 0
end

function InputActions.Touching()
	return anyHeld > 0
end

function InputActions.Bind(action, fn)
	check(action)
	handlers[action] = handlers[action] or {}
	handlers[action][fn] = true
	return {
		Disconnect = function()
			if handlers[action] then handlers[action][fn] = nil end
		end,
	}
end

-- Adapter for existing ContextActionService handlers: fn(actionName, state, inputObject).
-- The fake input carries UserInputType Touch and KeyCode Unknown, so handlers that check the key still run their default.
function InputActions.BindCAS(action, fn, casName)
	return InputActions.Bind(action, function(state)
		fn(casName or action, state, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, UserInputState = state, Position = Vector3.zero, Delta = Vector3.zero })
	end)
end

-- Touch ownership: which screen touches belong to the camera.
-- A button that takes a touch calls Consume(input) with the InputObject from its InputBegan. If the button allows camera
-- sinking (the global Buttons Camera Sinking setting, or its Custom override) it passes sink = true and the camera may still
-- turn with that finger. The touch is forgotten automatically when it ends.
--   InputActions.Consume(input, sink)
--   InputActions.CameraShouldUse(input)  -- CameraController asks this for every touch it would turn the camera with
local consumed = {} -- InputObject -> "sink" | "block"
function InputActions.Consume(input, sink)
	if consumed[input] then
		if sink == false then consumed[input] = "block" end
		return
	end
	consumed[input] = sink and "sink" or "block"
	local conn
	conn = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
		if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
			consumed[input] = nil
			conn:Disconnect()
		end
	end)
end

function InputActions.IsConsumed(input)
	return consumed[input] ~= nil
end

-- Settings the touch HUD writes, so the camera rules and the double-tap detector follow them (UI session keeps them in sync).
InputActions.Config = {
	LeftHanded = false,        -- the joystick zone moves to the right half
	DoubleTapAttack = true,    -- double tap on free screen fires
	DoubleTapWindow = 0.25,    -- seconds between the two taps
	JoystickZone = 0.5,        -- fraction of the screen width (from the joystick side) that belongs to the thumbstick
	-- Layout Editor placement (TouchStick copies them from its ScreenGui attributes). When StickX/StickY are set the zone is a
	-- square around that centre, 3 x StickSize screen heights wide, instead of the half screen. StickX is absolute (the editor
	-- mirrors it itself for left-handed layouts).
	StickX = nil,              -- zone centre, Scale 0-1 of the screen width
	StickY = nil,              -- zone centre, Scale 0-1 of the screen height
	StickSize = 0.22,          -- ring diameter, fraction of the screen height
}

local function inJoystickZone(pos)
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local cfg = InputActions.Config
	local vp = cam.ViewportSize
	if cfg.StickX and cfg.StickY then
		local half = 1.5 * cfg.StickSize * vp.Y
		return math.abs(pos.X - cfg.StickX * vp.X) <= half and math.abs(pos.Y - cfg.StickY * vp.Y) <= half
	end
	local zone = cfg.JoystickZone * vp.X
	if cfg.LeftHanded then return pos.X > vp.X - zone end
	return pos.X < zone
end
InputActions.InJoystickZone = inJoystickZone

-- Touches that started in the joystick zone, or on a button without sinking, never turn the camera.
local startPos = {} -- InputObject -> where the touch began
function InputActions.CameraShouldUse(input)
	if input.UserInputType ~= Enum.UserInputType.Touch then return true end
	local c = consumed[input]
	if c == "block" then return false end
	if c == "sink" then return true end
	local p = startPos[input]
	if p == nil then
		p = input.Position
		startPos[input] = p
		input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				startPos[input] = nil
			end
		end)
	end
	return not inJoystickZone(p)
end

return InputActions
]=]
SOURCES.TouchFire = [=[-- StarterPlayer.StarterPlayerScripts.TouchFire [TOUCH] (2026-10-17): RIVALS "Double Tap To Attack" + touch ownership.
-- 1. Keeps InputActions.Config in step with the Touch tab (player attributes Setting_DoubleTapToAttack,
--    Setting_DoubleTapWindow, Setting_LeftHandedMode; the UI session's SettingsConfig sets them).
-- 2. Every touch that lands on a TouchControls button is registered with InputActions.Consume(input, button.SinkCamera),
--    so CameraController's InputActions.CameraShouldUse(input) can ignore it (or let it turn the camera when sinking is on).
-- 3. A second tap on free screen (not a button, not the joystick zone) within DoubleTapWindow presses Fire, and holding
--    that second finger keeps firing until it lifts.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local InputActions = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function sync()
	local cfg = InputActions.Config
	local dt = player:GetAttribute("Setting_DoubleTapToAttack")
	cfg.DoubleTapAttack = dt ~= false
	local w = tonumber(player:GetAttribute("Setting_DoubleTapWindow"))
	cfg.DoubleTapWindow = w and math.clamp(w, 0.1, 0.6) or 0.25
	cfg.LeftHanded = player:GetAttribute("Setting_LeftHandedMode") == true
end
sync()
for _, a in { "Setting_DoubleTapToAttack", "Setting_DoubleTapWindow", "Setting_LeftHandedMode" } do
	player:GetAttributeChangedSignal(a):Connect(sync)
end

-- the touch HUD button under this touch, if any (buttons carry the SinkCamera attribute)
local function buttonAt(pos)
	local hud = playerGui:FindFirstChild("TouchControls")
	if not hud or not hud.Enabled then return nil end
	for _, g in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if g:IsDescendantOf(hud) and g.Visible then
			local b = g
			while b and b ~= hud and b:GetAttribute("SinkCamera") == nil do b = b.Parent end
			if b and b ~= hud then return b end
		end
	end
	return nil
end

local lastTapAt = -math.huge
local lastTapPos = nil
local firing = nil -- the InputObject holding Fire
local MAX_GAP_PX = 120 -- the two taps must land near each other (a distance, not a layout size)

UIS.TouchStarted:Connect(function(input, gameProcessed)
	local b = buttonAt(input.Position)
	if b then
		InputActions.Consume(input, b:GetAttribute("SinkCamera") == true)
		return
	end
	local cfg = InputActions.Config
	if gameProcessed or not cfg.DoubleTapAttack or firing then return end
	if InputActions.IsConsumed(input) or InputActions.InJoystickZone(input.Position) then return end
	local now = os.clock()
	local p = Vector2.new(input.Position.X, input.Position.Y)
	if now - lastTapAt <= cfg.DoubleTapWindow and lastTapPos and (p - lastTapPos).Magnitude <= MAX_GAP_PX then
		lastTapAt = -math.huge
		firing = input
		InputActions.Press("Fire")
	else
		lastTapAt = now
		lastTapPos = p
	end
end)

UIS.TouchEnded:Connect(function(input)
	if input == firing then
		firing = nil
		InputActions.Release("Fire")
	end
end)
]=]
SOURCES.TouchStick = [=[-- StarterPlayer.StarterPlayerScripts.TouchStick [TOUCH] (2026-10-17): our own dynamic thumbstick, so Left Handed Mode can
-- move it to the right half (Roblox's DynamicThumbstick is fixed to the left). The installer sets
-- StarterPlayer.DevTouchMovementMode = Scriptable, which removes Roblox's stick on touch devices; this script moves the
-- character instead. Keyboard / gamepad movement is untouched (DevComputerMovementMode is not changed).
-- A finger that starts in InputActions.InJoystickZone (left half, or right half when LeftHanded) on free screen
-- (not a button) becomes the stick: ring at the touch-down point, knob follows the finger, Move() camera-relative.
-- Visual: ScreenGui "TouchStick", all Scale (the UI session may restyle Ring / Knob; keep the names).
-- Layout Editor placement: ScreenGui attributes StickX, StickY (zone centre, Scale 0-1) and StickSize (ring diameter, fraction
-- of screen height), copied into InputActions.Config so the camera rule and TouchFire use the same zone. Unset = defaults.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local InputActions = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RADIUS = 0.11   -- stick travel, as a fraction of the screen height (StickSize / 2 when the editor sets it)
local DEAD = 0.12     -- inner dead zone, as a fraction of the travel

local gui = Instance.new("ScreenGui")
gui.Name = "TouchStick"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = playerGui

local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
ring.Size = UDim2.fromScale(RADIUS * 2, RADIUS * 2)
ring.BackgroundColor3 = Color3.new(0, 0, 0)
ring.BackgroundTransparency = 0.6
ring.Visible = false
ring.Parent = gui
Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
local stroke = Instance.new("UIStroke", ring)
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = 0.5
stroke.Thickness = 2

local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Size = UDim2.fromScale(0.45, 0.45)
knob.Position = UDim2.fromScale(0.5, 0.5)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.BackgroundTransparency = 0.25
knob.Parent = ring
Instance.new("UICorner", knob).CornerRadius = UDim.new(0.5, 0)

local function placement()
	local cfg = InputActions.Config
	local x, y, size = gui:GetAttribute("StickX"), gui:GetAttribute("StickY"), gui:GetAttribute("StickSize")
	cfg.StickX = type(x) == "number" and math.clamp(x, 0, 1) or nil
	cfg.StickY = type(y) == "number" and math.clamp(y, 0, 1) or nil
	cfg.StickSize = type(size) == "number" and math.clamp(size, 0.1, 0.5) or 0.22
	RADIUS = cfg.StickSize / 2
	ring.Size = UDim2.fromScale(cfg.StickSize, cfg.StickSize)
end
placement()
gui.AttributeChanged:Connect(placement)

local stickInput = nil -- the InputObject driving the stick
local center = Vector2.zero
local move = Vector2.zero -- -1..1, y down

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1, 1)
end

local function enabled()
	if player:GetAttribute("InCutscene") == true then return false end
	return UIS.TouchEnabled or player:GetAttribute("_ForceTouch") == true
end

local function release()
	stickInput = nil
	move = Vector2.zero
	ring.Visible = false
	player:Move(Vector3.zero, true)
end

UIS.TouchStarted:Connect(function(input, gameProcessed)
	if gameProcessed or stickInput or not enabled() then return end
	if InputActions.IsConsumed(input) or not InputActions.InJoystickZone(input.Position) then return end
	stickInput = input
	center = Vector2.new(input.Position.X, input.Position.Y)
	local vp = viewport()
	ring.Position = UDim2.fromScale(center.X / vp.X, center.Y / vp.Y)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	ring.Visible = true
end)

UIS.TouchMoved:Connect(function(input)
	if input ~= stickInput then return end
	local r = RADIUS * viewport().Y
	local d = Vector2.new(input.Position.X, input.Position.Y) - center
	if d.Magnitude > r then d = d.Unit * r end
	local v = d / r
	move = v.Magnitude < DEAD and Vector2.zero or v
	knob.Position = UDim2.fromScale(0.5 + v.X / 2, 0.5 + v.Y / 2)
end)

UIS.TouchEnded:Connect(function(input)
	if input == stickInput then release() end
end)

player:GetAttributeChangedSignal("InCutscene"):Connect(function()
	if stickInput and not enabled() then release() end
end)
player.CharacterAdded:Connect(function() if stickInput then release() end end)

-- after the ControlModule (it binds at Input priority), so a keyboard controller's zero vector can't overwrite the stick
RunService:BindToRenderStep("TouchStickMove", Enum.RenderPriority.Input.Value + 1, function()
	if stickInput then
		player:Move(Vector3.new(move.X, 0, move.Y), true)
	end
end)
]=]
--@@END SOURCES
local rec = CHS:TryBeginRecording("TOUCH install" .. (UNDO and " UNDO" or ""))
local log = {}
local shared = RS:WaitForChild("Modules"):WaitForChild("Shared")

local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local function module(parent, name, src, class)
	local m = parent:FindFirstChild(name)
	if m and not m:GetAttribute(TAG) then error(name .. " exists and is not ours") end
	if not m then
		m = Instance.new(class or "ModuleScript")
		m.Name = name
		m:SetAttribute(TAG, true)
		m.Parent = parent
		table.insert(log, "new " .. m:GetFullName())
	else
		table.insert(log, "updated " .. m:GetFullName())
	end
	m.Source = src
end

if UNDO then
	local m = shared:FindFirstChild("InputActions")
	if m and m:GetAttribute(TAG) then m:Destroy() table.insert(log, "removed InputActions") end
	local f = sps:FindFirstChild("TouchFire")
	if f and f:GetAttribute(TAG) then f:Destroy() table.insert(log, "removed TouchFire") end
	local st = sps:FindFirstChild("TouchStick")
	if st and st:GetAttribute(TAG) then st:Destroy() table.insert(log, "removed TouchStick") end
	local sp = game:GetService("StarterPlayer")
	local orig = sp:GetAttribute("TouchOrigMoveMode")
	if orig then
		sp.DevTouchMovementMode = Enum.DevTouchMovementMode[orig]
		sp:SetAttribute("TouchOrigMoveMode", nil)
		table.insert(log, "DevTouchMovementMode back to " .. orig)
	end
else
	module(shared, "InputActions", SOURCES.InputActions)
	local f = sps:FindFirstChild("TouchFire")
	if f and not f:IsA("LocalScript") then f:Destroy() end
	module(sps, "TouchFire", SOURCES.TouchFire, "LocalScript")
	module(sps, "TouchStick", SOURCES.TouchStick, "LocalScript")
	local sp = game:GetService("StarterPlayer")
	if sp:GetAttribute("TouchOrigMoveMode") == nil then sp:SetAttribute("TouchOrigMoveMode", sp.DevTouchMovementMode.Name) end
	sp.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
	table.insert(log, "DevTouchMovementMode = Scriptable (was " .. sp:GetAttribute("TouchOrigMoveMode") .. ")")
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
