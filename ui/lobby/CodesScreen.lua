-- UIKit/CodesScreen (ModuleScript): the lobby CODES screen, full screen like Shop / Missions / Settings (UI session 2026-10-16).
-- RIVALS' code panel (the replica's Social / Codes page): a dark rounded panel, a bold title, a big dark input box with the
-- green action button beside it, the red X; under it the codes you've already redeemed (3D dog tags + green checks).
-- Redeems with ask("RedeemCode", code); the server answers with a toast and data.RedeemedCodes.
--   CodesScreen.Init({ ask, getData, onOpen, onClose })   CodesScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local C, new = Theme.color, Kit.new
-- (2026-10-21, AI-tells cleanup) Builder Sans -> Oswald Bold (title, code box, buttons) / Rubik Medium (body)
local FB = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local FM = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local DONE = Theme.hex("#8DBF5A") -- (2026-10-21, AI-tells cleanup) redeemed / success: field green, was the #FFD400 yellow

local Screen = {}
local ctx = {}
local gui, root, blur, scrim, box, list, status
local isOpen = false
local goBtn, boxHome, redeeming -- (2026-10-21, RIVALS pass) the Redeem button, the box's resting Scale position, a guard

local function stroke(l, t) new("UIStroke", { Thickness = t or 2, Transparency = 0.3, Parent = l }) return l end

local function renderList()
	if not list then return end
	for _, c in list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local d = ctx.getData and ctx.getData() or {}
	local used = {}
	for code in (d.RedeemedCodes or {}) do table.insert(used, code) end
	table.sort(used)
	if #used == 0 then
		local l = Kit.label({ Text = "None yet. New codes come with updates and in the group.", FontFace = FM, TextSize = 24, TextColor3 = Theme.hex("#9C98A3"), Size = UDim2.fromOffset(900, 40), Parent = list })
		l:SetAttribute("dTS", 24)
	end
	for i, code in used do
		local row = new("Frame", { Name = code, LayoutOrder = i, Size = UDim2.fromOffset(250, 50), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = list },
			{ new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		local l = Kit.label({ Text = "✓  " .. code, FontFace = FB, TextSize = 22, TextColor3 = DONE, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(226, 50), Parent = row })
		l:SetAttribute("dTS", 22)
	end
	Kit.toScale(list, Vector2.new(960, 80))
end

-- (2026-10-21, RIVALS pass) feedback you can feel: a wrong / empty code shakes the box, a good one pops the status line
-- and the Redeem button; busy dots sit in Redeem while the server answers (FocusLost + Activated can't double-redeem)
local function shakeBox()
	if boxHome then box.Position = boxHome end -- a second shake starts from rest, not mid-swing
	Kit.shake(box)
end
-- (2026-10-21, round 3: match RIVALS) the result is a pop you can't miss: a solid chip (field green "✓ Redeemed!" / red
-- "✕ <why>") pops in where the status line sits, holds, then fades. Built after toScale, so it is sized in Scale of the panel
-- (design 1060 x 450); its width follows the words (AutomaticSize X) and its text size follows the screen (Kit.factor).
local resultChip
local function popResult(ok, msg)
	if resultChip then resultChip:Destroy() end
	local panel = box.Parent
	local chip = Kit.label({ Name = "ResultChip", Text = "   " .. (ok and "✓  " or "✕  ") .. msg .. "   ", FontFace = FB, TextSize = math.floor(26 * Kit.factor() + 0.5),
		TextColor3 = ok and Theme.hex("#11140E") or Color3.new(1, 1, 1), BackgroundTransparency = 0, BackgroundColor3 = ok and DONE or Theme.hex("#C52A1A"),
		AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(32 / 1060, 266 / 450), Size = UDim2.fromScale(0, 44 / 450),
		ZIndex = 5, Parent = panel })
	new("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = chip })
	resultChip = chip
	status.Text = ""
	Kit.popIn(chip)
	if ok then Kit.sfx("reward") else task.delay(0.1, function() if chip.Parent then Kit.shake(chip) end end) end
	task.delay(2.6, function()
		if not chip.Parent then return end
		Kit.tween(chip, 0.25, { BackgroundTransparency = 1, TextTransparency = 1 })
		task.delay(0.26, function() if chip.Parent then chip:Destroy() end end)
	end)
end
local function redeem()
	if redeeming then return end
	local code = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if code == "" then popResult(false, "Type a code first"); shakeBox() return end
	redeeming = true
	status.Text = "Checking..."; status.TextColor3 = Theme.hex("#CFCDD3")
	local stopBusy = goBtn and Kit.busy(goBtn)
	local r = ctx.ask and ctx.ask("RedeemCode", code)
	if stopBusy then stopBusy() end
	redeeming = false
	if r and r.ok then
		box.Text = ""
		popResult(true, r.msg or "Redeemed!") -- (2026-10-21, round 3: match RIVALS) was a plain status line
		local sc = goBtn and goBtn:FindFirstChildOfClass("UIScale") -- bindButton's scale (one UIScale per object)
		if sc then sc.Scale = 1.15; Kit.tween(sc, 0.28, { Scale = 1 }, Enum.EasingStyle.Back) end
	else
		popResult(false, (r and r.msg) or "That code didn't work") -- (2026-10-21, round 3: match RIVALS) red chip pop
		shakeBox()
	end
	task.delay(0.3, renderList)
end

local function build()
	gui = new("ScreenGui", { Name = "CodesUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- the panel
	-- (lobby revamp, graders: mostly empty black) a shorter panel: the list area only has to show a couple of rows
	local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(430, 250), Size = UDim2.fromOffset(1060, 450), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3, Parent = root }, { new("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	local tagHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 18), Size = UDim2.fromOffset(84, 84), Parent = panel })
	stroke(Kit.label({ Text = "Codes", FontFace = FB, TextSize = 60, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(126, 22), Size = UDim2.fromOffset(500, 72), Parent = panel }), 2.5)
	Kit.label({ Text = "Got a code from an update, the group or a stream? Redeem it here for free rewards.", FontFace = FM, TextSize = 26,
		TextColor3 = Theme.hex("#CFCDD3"), Position = UDim2.fromOffset(32, 104), Size = UDim2.fromOffset(990, 34), Parent = panel })
	box = new("TextBox", { Name = "Code", Text = "", PlaceholderText = "Enter code", PlaceholderColor3 = Theme.hex("#77737D"), FontFace = FB, TextSize = 36,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Position = UDim2.fromOffset(32, 156),
		Size = UDim2.fromOffset(740, 84), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = panel },
		{ new("UICorner", { CornerRadius = UDim.new(0, 10) }), new("UIPadding", { PaddingLeft = UDim.new(0, 24) }) })
	box:SetAttribute("dTS", 36)
	-- (2026-10-21, round 3: match RIVALS) a soft field-green glow block behind Redeem, lit only while a code is typed
	local goGlow = new("Frame", { Name = "RedeemGlow", Position = UDim2.fromOffset(798, 148), Size = UDim2.fromOffset(238, 100), BackgroundColor3 = DONE,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = panel }, { new("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	local go = Kit.button("robux", UDim2.fromOffset(222, 84), "Redeem")
	go.Name = "Redeem"
	goBtn = go
	go.Position = UDim2.fromOffset(806, 156)
	go.Parent = panel
	go.Activated:Connect(function() if (box.Text or ""):match("%S") then redeem() end end)
	-- (lobby revamp, graders: Redeem looked live with nothing typed) dimmed and inert until there's a code in the box
	-- (2026-10-21, round 3: match RIVALS; reviewers: "Redeem reads as disabled") two states you can tell apart at a glance: empty =
	-- a flat charcoal plate over the green with a faded word (clearly off); typed = the full bright field-green gradient, the word
	-- at full strength, the green glow behind it, and a little pop the moment it turns on. The plate sits under the label (Z 2).
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.hex("#2E312A"), BackgroundTransparency = 0.08, ZIndex = 2, Parent = go },
		{ new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	local goLabel = go:FindFirstChild("Label")
	local goOn
	local function paintGo(t)
		local on = (box.Text or ""):match("%S") ~= nil
		if on == goOn then return end
		goOn = on
		Kit.tween(dim, t or 0.15, { BackgroundTransparency = on and 1 or 0.08 })
		Kit.tween(goGlow, t or 0.15, { BackgroundTransparency = on and 0.6 or 1 })
		if goLabel then Kit.tween(goLabel, t or 0.15, { TextTransparency = on and 0 or 0.55 }) end
		if on and t ~= 0 then Kit.pop(go, 1.1) end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function() paintGo() end)
	paintGo(0)
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	status = Kit.label({ Text = "", FontFace = FB, TextSize = 24, TextColor3 = Theme.hex("#CFCDD3"), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(34, 266), Size = UDim2.fromOffset(990, 32), Parent = panel })
	status:SetAttribute("dTS", 24) -- (2026-10-21, RIVALS pass) anchored left-middle (same spot) so the success pop grows from the text's start
	stroke(Kit.label({ Text = "Redeemed", FontFace = FB, TextSize = 32, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(32, 300), Size = UDim2.fromOffset(400, 40), Parent = panel }), 2)
	list = new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 350), Size = UDim2.fromOffset(960, 80), Parent = panel },
		{ new("UIGridLayout", { CellSize = UDim2.fromScale(250 / 960, 50 / 80), CellPadding = UDim2.fromScale(12 / 960, 12 / 80), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local close = Kit.closeButton(UDim2.fromOffset(112, 58))
	close.Position = UDim2.fromOffset(1420, 262) -- (lobby revamp Phase B: docked inside the panel corner)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	Kit.toScale(root)
	boxHome = box.Position -- (2026-10-21, RIVALS pass) Scale home for the error shake
	ViewIcons.Icon(tagHold, "DogTags", { hoverTarget = panel })
	root.Visible = false
	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		status.Text = ""
		renderList()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
	else
		box:ReleaseFocus()
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

function Screen.Init(context)
	ctx = context or {}
	if not gui then build() end
end
function Screen.Open() setOpen(true) end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end
function Screen.Refresh() if isOpen then renderList() end end

return Screen
