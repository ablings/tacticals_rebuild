local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/HealthBarController (ModuleScript)
-- Health bar, bottom left (RIVALS; bottom right with a controller). 100 HP. When you're hit, the bar drops straight away and a pale "damage"
-- chunk drains after it; it turns red when you're low. Display only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local controller = {}

local WIDTH, HEIGHT = 380, 36 -- the bar (design px)
local COLOR_OK = Color3.fromRGB(236, 228, 206) -- bone
local COLOR_MID = Color3.fromRGB(222, 168, 72) -- amber (RIVALS goes green -> yellow -> orange; ours bone -> amber -> red)
local COLOR_LOW = Color3.fromRGB(205, 72, 58)
local LOW_AT = 0.3 -- fraction of max health
-- [UI] restyle (UI session 2026-10-16, Edward: RIVALS' aesthetics, classy, no olive / brackets on gameplay UI):
-- no plate, just the big white number with a cross and a rounded quartered bar on dark glass, like RIVALS.
-- Built in 1920x1080 design px on a UIKit canvas, then Kit.toScale (Scale only).
local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
local STENCIL = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold) -- (2026-10-21, AI-tells cleanup) Oswald Bold, was Montserrat Heavy
local FIELD = Color3.fromRGB(200, 200, 206)

local gui, fill, trail, number, frame
local crossArms = {} -- the cross inside the bar (recoloured with the number)
local shown, trailValue = 1, 1
local lastHitAt = 0

local function box(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Vitals"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local canvas = Kit.canvas(gui)
	if Kit.pinCanvas then Kit.pinCanvas(canvas, "bottom") end -- (2026-10-22) 4:3 tablets: the health bar sits on the bottom edge
	local root = box(canvas, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	-- (2026-10-20, Edward: "a mix" of RIVALS + Sniper / Murder Duels) back to RIVALS' bar: bottom left, one thick rounded bar
	-- with the number and a cross inside its right end; the fill runs bone -> amber -> red as health drops (RIVALS: green ->
	-- yellow -> orange). With a controller it mirrors to the bottom right (the hotbar column takes the left).
	local W, H = WIDTH, HEIGHT
	frame = box(root, { Name = "Health", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(12, 1080 - 14), Size = UDim2.fromOffset(W, H), -- (m9, RIVALS t0054: x 0.6 %, bottom 98.7 %; was 40 / 34)
		
		BackgroundTransparency = 1 })
	local back = box(frame, { Name = "Bar", Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3 })
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0.5, 0) rc.Parent = back
	local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(14, 14, 16) bs.Thickness = 3 bs.Transparency = 0.15 bs.Parent = back
	trail = box(back, { Name = "Damage", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 150, 120), BackgroundTransparency = 0.25, ZIndex = 3 })
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0.5, 0) tc.Parent = trail
	fill = box(back, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLOR_OK, ZIndex = 4 })
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0.5, 0) fc.Parent = fill
	number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.AnchorPoint = Vector2.new(1, 0.5)
	number.Position = UDim2.new(0, W - 40, 0.5, 0)
	number.Size = UDim2.fromOffset(110, H - 6)
	number.FontFace = STENCIL
	number.TextSize = 24
	number.TextColor3 = Color3.new(1, 1, 1)
	number.TextXAlignment = Enum.TextXAlignment.Right
	number.Text = "100"
	number.ZIndex = 6
	number.Parent = back
	local ns = Instance.new("UIStroke") ns.Thickness = 1.5 ns.Transparency = 0.35 ns.Parent = number
	local cross = box(back, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W - 22, H / 2), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ZIndex = 6 })
	for _, sz in { Vector2.new(18, 6), Vector2.new(6, 18) } do
		local arm = box(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(sz.X, sz.Y), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
		local st = Instance.new("UIStroke") st.Thickness = 1.5 st.Transparency = 0.35 st.Parent = arm
		table.insert(crossArms, arm)
	end
	Kit.toScale(root)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- (2026-10-22, Edward's live RIVALS games: "yes") while you're dead and the camera follows your killer, the bar shows THEIR
-- health (RIVALS: 118, then 93 as the killer took damage); a bot is found by its SpectateId attribute
local specCache = {}
local function spectatedHumanoid()
	if localPlayer:GetAttribute("Alive") ~= false then return nil end
	local uid = localPlayer:GetAttribute("SpectateTarget")
	if type(uid) ~= "number" then return nil end
	local m
	if uid > 0 then
		local p = game:GetService("Players"):GetPlayerByUserId(uid)
		m = p and p.Character
	elseif specCache.uid == uid and specCache.model and specCache.model.Parent then
		m = specCache.model
	elseif os.clock() - (specCache.at or 0) > 0.5 then -- (the bot search walks the workspace: cached, retried twice a second)
		specCache.at = os.clock()
		for _, d in workspace:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("SpectateId") == uid then m = d; break end
		end
		specCache.uid, specCache.model = uid, m
	end
	return m and m:FindFirstChildOfClass("Humanoid")
end

local deadAt: number? = nil
local function current(): (number, number)
	-- (2026-10-23, matchmaking round m12, RIVALS t0206 -> t0208) your own bar reads 0 for the death moment, then the kill-cam
	-- shows your killer's health
	if localPlayer:GetAttribute("Alive") == false then
		deadAt = deadAt or os.clock()
		if os.clock() - deadAt < 1.5 then return 0, 100 end
	else
		deadAt = nil
	end
	local spec = spectatedHumanoid()
	if spec then return math.max(spec.Health, 0), math.max(spec.MaxHealth, 1) end
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then return 0, 100 end
	return math.max(hum.Health, 0), math.max(hum.MaxHealth, 1)
end

local function update(dt)
	local health, max = current()
	local target = health / max
	if target < shown - 0.001 then
		-- took damage: snap down, the pale chunk waits a moment then drains
		if localPlayer.Character and shown > 0 and health > 0 then
			lastHitAt = os.clock()
			-- (2026-10-21, RIVALS pass) the bar itself reacts to a hit: a quick 1.06 -> 1 punch (from its bottom-left corner,
			-- so it never drifts off the screen edge); the bone -> amber -> red ramp is untouched
			Kit.pop(frame, 1.06)
		end
	end
	shown = target
	if os.clock() - lastHitAt > 0.45 then
		trailValue += (shown - trailValue) * math.clamp(dt * 4, 0, 1)
	end
	if trailValue < shown then trailValue = shown end -- healing: no chunk
	fill.Size = UDim2.fromScale(shown, 1)
	trail.Size = UDim2.fromScale(trailValue, 1)
	number.Text = tostring(math.ceil(health))
	local low = shown <= LOW_AT
	-- the number flashes red for a moment when you're hit, and stays red when low
	local flash = math.clamp(1 - (os.clock() - lastHitAt) / 0.6, 0, 1)
	-- (RIVALS) dark text while the fill sits behind the number (the bar's right end), white once it has drained past it
	local onFill = shown > 0.86
	local base = onFill and Color3.fromRGB(46, 42, 36) or Color3.new(1, 1, 1)
	number.TextColor3 = base:Lerp(COLOR_LOW, low and 0 or flash)
	local nstroke = number:FindFirstChildOfClass("UIStroke")
	if nstroke then nstroke.Transparency = onFill and 1 or 0.35 end
	for _, arm in crossArms do
		arm.BackgroundColor3 = base
		local ast = arm:FindFirstChildOfClass("UIStroke")
		if ast then ast.Transparency = onFill and 1 or 0.35 end
	end
	-- bone above 60%, then into amber, then red at the low mark
	fill.BackgroundColor3 = shown > 0.6 and COLOR_OK or (shown > LOW_AT and COLOR_MID:Lerp(COLOR_OK, (shown - LOW_AT) / (0.6 - LOW_AT)) or COLOR_LOW:Lerp(COLOR_MID, shown / LOW_AT))
	-- low health: the bar pulses
	fill.BackgroundTransparency = low and (0.15 + 0.15 * math.sin(os.clock() * 8)) or 0
end

-- (2026-10-20, Edward: "remove the noise indicator we don't need people to know how loud they are") the NOISE meter
-- (StealthUI, built by the stealth gameplay script) is hidden here: its contents stay invisible whatever turns the ScreenGui
-- on or off (the match HUD toggles it with the rest). Noise itself still works; only the meter is gone.
local function hideNoiseMeter()
	local function hide(gui)
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = false
				c:GetPropertyChangedSignal("Visible"):Connect(function() if c.Visible then c.Visible = false end end)
			end
		end
		gui.ChildAdded:Connect(function(c) if c:IsA("GuiObject") then task.defer(function() c.Visible = false end) end end)
	end
	local pg = localPlayer:WaitForChild("PlayerGui")
	local st = pg:FindFirstChild("StealthUI")
	if st then hide(st) end
	pg.ChildAdded:Connect(function(c) if c.Name == "StealthUI" then hide(c) end end)
end

-- [PAD] with a controller the hotbar column takes the bottom left, so the health bar mirrors to the bottom right
local function padLayout()
	local UIS = game:GetService("UserInputService")
	local orig, origA = frame.Position, frame.AnchorPoint
	local on = nil
	local function apply(pad: boolean)
		frame.AnchorPoint = pad and Vector2.new(1 - origA.X, origA.Y) or origA
		frame.Position = pad and UDim2.fromScale(1 - orig.X.Scale, orig.Y.Scale) or orig
	end
	local function check(t)
		if t == Enum.UserInputType.MouseMovement then return end -- a resting mouse sends it; never flips back to keyboard + mouse
		local pad = t.Name:find("Gamepad") ~= nil
		if not pad and not (t == Enum.UserInputType.Keyboard or t.Name:find("Mouse")) then return end
		if pad ~= on then on = pad; apply(pad) end
	end
	UIS.LastInputTypeChanged:Connect(check)
	check(UIS:GetLastInputType())
	localPlayer:GetAttributeChangedSignal("_ForcePad"):Connect(function() -- Studio test switch
		if RunService:IsStudio() then on = localPlayer:GetAttribute("_ForcePad") == true; apply(on) end
	end)
end

function controller.Start()
	build()
	hideNoiseMeter()
	padLayout()
	RunService.RenderStepped:Connect(update)
end

return controller
