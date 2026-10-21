-- StarterPlayerScripts.DeviceReport (LocalScript, hub + match places) 2026-10-20: tells the server what this player is playing on
-- (ServerScriptService.DeviceBridge -> player attribute Device), and again when the input changes (a pad picked up on PC):
--   Console  a 10-foot interface (Xbox / PlayStation)
--   Phone / Tablet  touch only (Tablet when the shorter screen side is 600 px or more)
--   Controller  last input was a gamepad (on PC)
--   PC  keyboard / mouse
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local remote = ReplicatedStorage:WaitForChild("ReportDevice", 30)
if not remote then return end

local function detect(): string
	if GuiService:IsTenFootInterface() then return "Console" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(0, 0)
		return math.min(size.X, size.Y) >= 600 and "Tablet" or "Phone"
	end
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then return "Controller" end
	return "PC"
end

local sent
local function report()
	local d = detect()
	if d ~= sent then
		sent = d
		remote:FireServer(d)
	end
end
report()
UserInputService.LastInputTypeChanged:Connect(function() task.defer(report) end)
