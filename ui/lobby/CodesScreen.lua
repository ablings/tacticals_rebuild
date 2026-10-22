-- UIKit/CodesScreen (ModuleScript): the lobby CODES screen, full screen like Shop / Missions / Settings (UI session 2026-10-16).
-- RIVALS' code panel (the replica's Social / Codes page): a dark rounded panel, a bold title, a big dark input box with the
-- green action button beside it, the red X; under it the codes you've already redeemed (3D dog tags + green checks).
-- Redeems with ask("RedeemCode", code); the server answers with a toast and data.RedeemedCodes.
-- (2026-10-21, RIVALS 1:1) Codes has no RIVALS screen of its own, so it is dressed in the RIVALS kit: the replica's panel
-- (black at 0.45, 8 px corners), Rubik title / body / input (UIKit.Rivals.Theme), the replica's green gradient button with a
-- FredokaOne word, the replica's red X outside the panel, a flat white header glyph (no 3D dog tags: RIVALS has none).
--   CodesScreen.Init({ ask, getData, onOpen, onClose })   CodesScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Kit = require(UIKit:WaitForChild("Kit")) -- canvas / toScale / motion (shake, popIn, busy)
local Rivals = UIKit:WaitForChild("Rivals")
local Theme = require(Rivals:WaitForChild("Theme"))
local RK = require(Rivals:WaitForChild("Kit"))
local RA = require(Rivals:WaitForChild("Assets"))
local C, F, new = Theme.color, Theme.font, Kit.new
-- (2026-10-21, RIVALS 1:1) Rivals Theme faces: Rubik ExtraBold title, Rubik Bold code box / chips, Rubik Medium body
local FB = Font.new(F.heavy.Family, Enum.FontWeight.Bold)
local FM = F.medium
local DONE = C.green -- redeemed / success: RIVALS' #65FE32
local BLACK = C.textDark

local Screen = {}
local ctx = {}
local gui, root, blur, scrim, box, list, status
local isOpen = false
local goBtn, boxHome, redeeming -- (2026-10-21, RIVALS pass) the Redeem button, the box's resting Scale position, a guard

local function stroke(l, t) local st = RK.textStroke(t or 2); st.Parent = l return l end

local function renderList()
	if not list then return end
	for _, c in list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local d = ctx.getData and ctx.getData() or {}
	local used = {}
	for code in (d.RedeemedCodes or {}) do table.insert(used, code) end
	table.sort(used)
	if #used == 0 then
		-- (2026-10-21, grade3) body text read ~12 px: 24 -> 30 design px (~16 px in the 1436 capture), cream-grey instead of lilac grey
		local l = RK.label({ Text = "None yet. New codes come with updates and in the group.", FontFace = FM, TextSize = 30, TextColor3 = C.textDim, Size = UDim2.fromOffset(900, 40), Parent = list })
		l:SetAttribute("dTS", 30)
	end
	for i, code in used do
		local row = new("Frame", { Name = code, LayoutOrder = i, Size = UDim2.fromOffset(250, 50), BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.45, Parent = list },
			{ new("UICorner", { CornerRadius = UDim.new(0, 6) }) }) -- (2026-10-21, RIVALS 1:1) the replica's task-tile plate
		local l = RK.label({ Text = "✓  " .. code, FontFace = FB, TextSize = 22, TextColor3 = DONE, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(226, 50), Parent = row })
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
	local chip = RK.label({ Name = "ResultChip", Text = "   " .. (ok and "✓  " or "✕  ") .. msg .. "   ", FontFace = FB, TextSize = math.floor(26 * Kit.factor() + 0.5),
		TextColor3 = ok and BLACK or C.white, BackgroundTransparency = 0, BackgroundColor3 = ok and DONE or C.red,
		AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(32 / 1060, 266 / 450), Size = UDim2.fromScale(0, 44 / 450),
		ZIndex = 5, Parent = panel })
	new("UICorner", { CornerRadius = UDim.new(0.18, 0), Parent = chip })
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
	status.Text = "Checking..."; status.TextColor3 = C.textDim
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
	-- (2026-10-21, RIVALS 1:1) the replica's panel: black at 0.45 (Theme.alpha.panel), 8 px corners
	local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(430, 250), Size = UDim2.fromOffset(1060, 450), BackgroundColor3 = BLACK,
		BackgroundTransparency = Theme.alpha.panel, Parent = root }, { RK.corner(8) })
	-- header (RIVALS section header: a flat white glyph + the title)
	new("ImageLabel", { Name = "HeadIcon", BackgroundTransparency = 1, Image = (RA.rowIcon and RA.rowIcon.gift) or "", ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(32, 22), Size = UDim2.fromOffset(60, 60), Parent = panel })
	RK.label({ Text = "Codes", FontFace = F.display, TextSize = 56, Position = UDim2.fromOffset(108, 18), Size = UDim2.fromOffset(500, 68), Parent = panel })
	-- (2026-10-21, grade3) body 26 -> 30 design px (~16 px on screen); the line is shorter so it still fits one row at the bigger size
	RK.label({ Text = "Got a code from an update or the group? Redeem it here for free rewards.", FontFace = FM, TextSize = 30,
		TextColor3 = C.textDim, Position = UDim2.fromOffset(32, 102), Size = UDim2.fromOffset(990, 38), Parent = panel })
	-- (2026-10-21, RIVALS 1:1) RIVALS' input: a dark box with a grey placeholder (the cosmetic picker's search box), Rubik Bold
	box = new("TextBox", { Name = "Code", Text = "", PlaceholderText = "Enter code", PlaceholderColor3 = C.disabled, FontFace = FB, TextSize = 36,
		TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Position = UDim2.fromOffset(32, 156),
		Size = UDim2.fromOffset(740, 84), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Parent = panel },
		{ RK.corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 24) }) })
	box:SetAttribute("dTS", 36)
	-- focus: the box's dark fill lifts (0.35 -> 0.12)
	box.Focused:Connect(function() Kit.tween(box, 0.12, { BackgroundTransparency = 0.12 }) end)
	box.FocusLost:Connect(function() Kit.tween(box, 0.12, { BackgroundTransparency = 0.35 }) end)
	-- (2026-10-21, RIVALS 1:1) the replica's green gradient button ("robux" = RIVALS' green) with a FredokaOne word
	local go = RK.button("robux", UDim2.fromOffset(222, 84), "Redeem")
	go.Name = "Redeem"
	goBtn = go
	go.Position = UDim2.fromOffset(806, 156)
	go.Parent = panel
	go.Activated:Connect(function() if (box.Text or ""):match("%S") then redeem() end end)
	-- dimmed and inert until there's a code in the box: off = RIVALS' disabled grey plate over the button with the word faded and
	-- no stroke; typed = the plate fades away to the full green button, the word white with its stroke, and a pop
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.disabled, BackgroundTransparency = 0, ZIndex = 2, Parent = go },
		{ RK.corner(6) })
	local goLabel = go:FindFirstChild("Label")
	if goLabel then goLabel.ZIndex = 3 end
	local goStroke = goLabel and goLabel:FindFirstChildOfClass("UIStroke")
	local goOn
	local function paintGo(t)
		local on = (box.Text or ""):match("%S") ~= nil
		if on == goOn then return end
		goOn = on
		Kit.tween(dim, t or 0.15, { BackgroundTransparency = on and 1 or 0 })
		if goLabel then Kit.tween(goLabel, t or 0.15, { TextTransparency = on and 0 or 0.45 }) end
		if goStroke then goStroke.Enabled = on end
		if on and t ~= 0 then Kit.pop(go, 1.1) end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function() paintGo() end)
	paintGo(0)
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	status = RK.label({ Text = "", FontFace = FB, TextSize = 24, TextColor3 = C.textDim, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(34, 266), Size = UDim2.fromOffset(990, 32), Parent = panel })
	status:SetAttribute("dTS", 24) -- anchored left-middle (same spot) so the success pop grows from the text's start
	stroke(RK.label({ Text = "Redeemed", FontFace = FB, TextSize = 32, Position = UDim2.fromOffset(32, 300), Size = UDim2.fromOffset(400, 40), Parent = panel }), 2)
	list = new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 350), Size = UDim2.fromOffset(960, 80), Parent = panel },
		{ new("UIGridLayout", { CellSize = UDim2.fromScale(250 / 960, 50 / 80), CellPadding = UDim2.fromScale(12 / 960, 12 / 80), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- (2026-10-21, RIVALS 1:1) the replica's red X (94x48) outside the panel's top-right, its top level with the panel's top (the
	-- Tasks screen's spacing: 42 px off the panel). Renamed + tagged Nonapplicable: the old InterfaceController shrinks the parent
	-- of any new "Close" button to 0 x 0.
	local close = RK.closeButton(UDim2.fromOffset(94, 48))
	close.Name = "CloseX"
	close:AddTag("Nonapplicable")
	close.Position = UDim2.fromOffset(430 + 1060 + 42, 250)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	Kit.toScale(root)
	boxHome = box.Position -- (2026-10-21, RIVALS pass) Scale home for the error shake
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
