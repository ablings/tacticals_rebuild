-- ReplicatedStorage.Modules.Shared.InputActions [TOUCH] (2026-10-17, Edward: mobile UI the RIVALS way)
-- One input-agnostic layer between the touch HUD and the gameplay controllers. The touch buttons (UI session) call
-- Press/Release; each controller keeps its own ContextActionService binds for keyboard and gamepad and also listens here
-- with Bind, so one handler serves every input type.
--
--   InputActions.Press("Reload")             -- a touch button went down
--   InputActions.Release("Reload")           -- and up (Press/Release pairs are counted, so two fingers are safe)
--   InputActions.Tap("Equip1")               -- Press + Release in one call
--   local c = InputActions.Bind("Reload", function(down) ... end)   -- down = true on press, false on release
--   c:Disconnect()
--   InputActions.IsHeld("Fire")
--   InputActions.Touching()                  -- true while any action is held by touch (the camera uses it for sinking)
--
-- The handler gets the same arguments a ContextActionService callback gets: (actionName, Enum.UserInputState, fakeInput),
-- so a controller can pass its existing CAS handler straight to BindCAS.
--   InputActions.BindCAS("Reload", onInput)  -- onInput(actionName, state, input) with state Begin/End
local InputActions = {}

InputActions.Names = {
	"Fire", "Aim", "Reload", "Inspect", "Jump", "Crouch", "Slide", "Dash", "Cover", "Ability",
	"QuickMelee", "QuickUtility", "Equip1", "Equip2", "Equip3", "Equip4",
	"Emote", "Scoreboard", "CameraSwap",
}
local known = {}
for _, n in InputActions.Names do known[n] = true end

local handlers = {} -- action -> { fn = true }
local held = {}     -- action -> press count
local anyHeld = 0

local function fire(action, down)
	local list = handlers[action]
	if not list then return end
	for fn in list do
		task.spawn(fn, down)
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
	return InputActions.Bind(action, function(down)
		local state = down and Enum.UserInputState.Begin or Enum.UserInputState.End
		fn(casName or action, state, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, UserInputState = state, Position = Vector3.zero, Delta = Vector3.zero })
	end)
end

return InputActions
