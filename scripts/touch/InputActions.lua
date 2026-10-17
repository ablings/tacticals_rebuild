-- ReplicatedStorage.Modules.Shared.InputActions [TOUCH] (2026-10-17, Edward: mobile UI the RIVALS way)
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
