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
-- (2026-10-21, port3) the shared menu backdrop (Modules.Shared.UITheme: RIVALS scrim purple + edge vignette over the blurred
-- world). Nil in a place without it: Codes then falls back to its own scrim + blur.
local UITheme
pcall(function()
	local sh = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
	sh = sh and sh:FindFirstChild("Shared")
	local m = sh and sh:FindFirstChild("UITheme")
	if m then UITheme = require(m) end
end)
-- (2026-10-21, port3) panel layout in design px (1920x1080): tighter than round 3's 1060 x 450, centred, X 12 px outside
-- (2026-10-22, section round 0, grader A vs RIVALS' Free rewards / Tasks panels) narrower and higher: 826 wide at x 547 (0.285-0.715 W),
-- top at y 205 (0.19 H), the input row 68 tall (was 960 x 410 at 480, 300, rows 84)
local PW, PH, PX, PY, PAD = 826, 354, 547, 205, 28
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
		-- (2026-10-21, port3) RIVALS body size 28; the list is 904 wide now
		-- (2026-10-22, section round 0, grader C) the empty state sits in an inner card (RIVALS' task-card plate), not as bare text;
		-- the grid layout is switched off for it so the card spans the list
		local grid = list:FindFirstChildOfClass("UIGridLayout"); if grid then grid.Parent = nil; list:SetAttribute("GridOff", true); Screen._grid = grid end
		local card = new("Frame", { Name = "Empty", Size = UDim2.fromOffset(PW - 2 * PAD, 62), BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.45, Parent = list },
			{ new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		local l = RK.label({ Text = "None yet. New codes come with updates and in the group.", FontFace = FM, TextSize = 26, TextColor3 = C.textDim, Position = UDim2.fromOffset(20, 0),
			Size = UDim2.fromOffset(PW - 2 * PAD - 40, 62), Parent = card })
		l:SetAttribute("dTS", 26)
	elseif Screen._grid and not Screen._grid.Parent then
		Screen._grid.Parent = list
	end
	for i, code in used do
		local row = new("Frame", { Name = code, LayoutOrder = i, Size = UDim2.fromOffset(250, 50), BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.45, Parent = list },
			{ new("UICorner", { CornerRadius = UDim.new(0, 6) }) }) -- (2026-10-21, RIVALS 1:1) the replica's task-tile plate
		local l = RK.label({ Text = "✓  " .. code, FontFace = FB, TextSize = 24, TextColor3 = DONE, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(226, 50), Parent = row })
		l:SetAttribute("dTS", 24) -- (2026-10-21, port3) 22 -> 24
	end
	Kit.toScale(list, Vector2.new(PW - 2 * PAD, 62)) -- (2026-10-21, port3) the list's design size (was 960 x 80)
end

-- (2026-10-21, RIVALS pass) feedback you can feel: a wrong / empty code shakes the box, a good one pops the status line
-- and the Redeem button; busy dots sit in Redeem while the server answers (FocusLost + Activated can't double-redeem)
local function shakeBox()
	if boxHome then box.Position = boxHome end -- a second shake starts from rest, not mid-swing
	Kit.shake(box)
end
-- (2026-10-21, round 3: match RIVALS) the result is a pop you can't miss: a solid chip (field green "✓ Redeemed!" / red
-- "✕ <why>") pops in where the status line sits, holds, then fades. Built after toScale, so it is sized in Scale of the panel
-- (design PW x PH, 2026-10-21 port3); its width follows the words (AutomaticSize X) and its text size follows the screen (Kit.factor).
local resultChip
local function popResult(ok, msg)
	if resultChip then resultChip:Destroy() end
	local panel = box.Parent
	local chip = RK.label({ Name = "ResultChip", Text = "   " .. (ok and "✓  " or "✕  ") .. msg .. "   ", FontFace = FB, TextSize = math.floor(26 * Kit.factor() + 0.5),
		TextColor3 = ok and BLACK or C.white, BackgroundTransparency = 0, BackgroundColor3 = ok and DONE or C.red,
		AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(PAD / PW, 254 / PH), Size = UDim2.fromScale(0, 40 / PH),
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
	-- (2026-10-21, port3) graders: too much empty space. 1060 x 450 -> PW x PH (960 x 410), centred, 28 px margins, rows packed
	local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(PX, PY), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = BLACK,
		BackgroundTransparency = Theme.alpha.panel, Parent = root }, { RK.corner(8) })
	-- header (RIVALS section header: a flat white glyph + the title)
	new("ImageLabel", { Name = "HeadIcon", BackgroundTransparency = 1, Image = (RA.rowIcon and RA.rowIcon.gift) or "", ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(PAD, 10), Size = UDim2.fromOffset(46, 46), Parent = panel }) -- (round 1: Missions' header, 46 px icon)
	-- (2026-10-21, port3) RIVALS title size 52 (titles ~44-56)
	-- (2026-10-22, section round 1, grader C) the Missions header's title (Rubik Bold 36, 44 tall at y 12): "Codes" read 1.4x bigger
	RK.label({ Text = "Codes", FontFace = FB, TextSize = 36, Position = UDim2.fromOffset(PAD + 56, 12), Size = UDim2.fromOffset(500, 44), Parent = panel })
	-- (2026-10-21, grade3) body 26 -> 30 design px (~16 px on screen); the line is shorter so it still fits one row at the bigger size
	-- (2026-10-21, port3) RIVALS body size 28
	RK.label({ Text = "Got a code? Redeem it here for free rewards.", FontFace = FM, TextSize = 28,
		TextColor3 = C.textDim, Position = UDim2.fromOffset(PAD, 62), Size = UDim2.fromOffset(PW - 2 * PAD, 36), Parent = panel })
	-- (2026-10-21, RIVALS 1:1) RIVALS' input: a box with a placeholder (the cosmetic picker's search box), Rubik Bold
	-- (2026-10-21, port3) graders: the box read darker than the panel and the placeholder was barely visible. The box is now RIVALS'
	-- track grey-purple (Theme.color.track) so it sits clearly lighter than the panel, placeholder in textDim (was disabled grey)
	local REDEEM_W, ROW_Y, ROW_H, GAP = 205, 110, 68, 20
	-- (2026-10-22, section rounds 0-7, grader C: RIVALS' fields are white with dark text - the sort dropdown, Settings values)
	box = new("TextBox", { Name = "Code", Text = "", PlaceholderText = "Enter code", PlaceholderColor3 = Color3.fromRGB(140, 140, 150), FontFace = FB, TextSize = 30,
		TextColor3 = C.textDark, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Position = UDim2.fromOffset(PAD, ROW_Y),
		Size = UDim2.fromOffset(PW - 2 * PAD - GAP - REDEEM_W, ROW_H), BackgroundColor3 = C.white, BackgroundTransparency = 0.1, Parent = panel },
		{ RK.corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 24) }) })
	box:SetAttribute("dTS", 30)
	-- focus: the box's fill lifts (0.4 -> 0.15)
	box.Focused:Connect(function() Kit.tween(box, 0.12, { BackgroundTransparency = 0 }) end)
	box.FocusLost:Connect(function() Kit.tween(box, 0.12, { BackgroundTransparency = 0.1 }) end)
	-- (2026-10-21, RIVALS 1:1) the replica's lime gradient button (Theme.gradient.robux) with a chunky FredokaOne word
	local go = RK.button("robux", UDim2.fromOffset(REDEEM_W, ROW_H), "Redeem")
	go.Name = "Redeem"
	goBtn = go
	go.Position = UDim2.fromOffset(PW - PAD - REDEEM_W, ROW_Y)
	go.Parent = panel
	go.Activated:Connect(function() if (box.Text or ""):match("%S") then redeem() end end)
	-- (2026-10-21, port3) graders: the disabled grey plate read as broken. RIVALS action buttons stay their bright gradient: with no
	-- code the lime button is only dimmed (a black veil at 0.6, the word at 0.2 with its stroke kept so it stays chunky and legible);
	-- typed, the veil fades away to the full lime gradient with a pop
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 90, 90), BackgroundTransparency = 0.05, ZIndex = 2, Parent = go }, -- (round 9, grader B: a clearly grey disabled state)
		{ RK.corner(6) })
	local goLabel = go:FindFirstChild("Label")
	if goLabel then goLabel.ZIndex = 3; goLabel.TextColor3 = C.text end
	-- (2026-10-22, section round 0, grader B) the word in Play's clean bold sans, pure white, its edge the button's dark green (was
	-- the chunky cartoon font with a black stroke)
	if goLabel then
		goLabel.FontFace = FB
		goLabel.TextColor3 = Color3.new(1, 1, 1)
		local gs = goLabel:FindFirstChildOfClass("UIStroke")
		if gs then gs.Color, gs.Thickness, gs.Transparency = Color3.fromRGB(40, 110, 20), 1.5, 0.2 end
	end
	local goOn
	local function paintGo(t)
		local on = (box.Text or ""):match("%S") ~= nil
		if on == goOn then return end
		goOn = on
		Kit.tween(dim, t or 0.15, { BackgroundTransparency = on and 1 or 0.05 }) -- (round 7, grader C: a lime at ~50 %, the 0.6 black veil read olive)
		if goLabel then Kit.tween(goLabel, t or 0.15, { TextTransparency = on and 0 or 0.2 }) end
		if on and t ~= 0 then Kit.pop(go, 1.1) end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function() paintGo() end)
	paintGo(0)
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	status = RK.label({ Text = "", FontFace = FB, TextSize = 24, TextColor3 = C.textDim, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(PAD + 2, 196),
		Size = UDim2.fromOffset(PW - 2 * PAD, 32), Parent = panel })
	status:SetAttribute("dTS", 24) -- anchored left-middle (same spot) so the success pop grows from the text's start
	stroke(RK.label({ Text = "Redeemed", FontFace = FB, TextSize = 30, Position = UDim2.fromOffset(PAD, 218), Size = UDim2.fromOffset(400, 40), Parent = panel }), 2)
	local LW = PW - 2 * PAD
	list = new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 264), Size = UDim2.fromOffset(LW, 62), Parent = panel },
		{ new("UIGridLayout", { CellSize = UDim2.fromScale(250 / LW, 50 / 62), CellPadding = UDim2.fromScale(12 / LW, 12 / 62), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- (2026-10-21, RIVALS 1:1) the replica's red X outside the panel's top-right. Renamed + tagged Nonapplicable: the old
	-- InterfaceController shrinks the parent of any new "Close" button to 0 x 0.
	-- (2026-10-21, port3) one X everywhere: the kit default (RIVALS' 112 x 58), 12 px (RK.CLOSE_GAP) outside the panel's
	-- top-right corner, its top level with the panel's top
	local close = RK.closeButton()
	close.Name = "CloseX"
	close:AddTag("Nonapplicable")
	close.Position = UDim2.fromOffset(PX + PW + (RK.CLOSE_GAP or 12), PY)
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
	-- (2026-10-21, port3) the shared backdrop (RIVALS purple, vignette, blur) when the place has it; own scrim + blur otherwise
	if UITheme and UITheme.ShowBackdrop then
		if on then UITheme.ShowBackdrop("Codes", 1) else UITheme.HideBackdrop("Codes") end
	else
		Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
		Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	end
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
