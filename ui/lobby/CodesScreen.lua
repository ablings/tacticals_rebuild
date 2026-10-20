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
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local Screen = {}
local ctx = {}
local gui, root, blur, scrim, box, list, status
local isOpen = false

local function stroke(l, t) new("UIStroke", { Thickness = t or 2, Transparency = 0.3, Parent = l }) return l end

local function renderList()
	if not list then return end
	for _, c in list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local d = ctx.getData and ctx.getData() or {}
	local used = {}
	for code in (d.RedeemedCodes or {}) do table.insert(used, code) end
	table.sort(used)
	if #used == 0 then
		local l = Kit.label({ Text = "No codes redeemed yet", FontFace = FM, TextSize = 24, TextColor3 = Theme.hex("#9C98A3"), Size = UDim2.fromOffset(600, 40), Parent = list })
		l:SetAttribute("dTS", 24)
	end
	for i, code in used do
		local row = new("Frame", { Name = code, LayoutOrder = i, Size = UDim2.fromOffset(250, 50), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = list },
			{ new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		local l = Kit.label({ Text = "✓  " .. code, FontFace = FB, TextSize = 22, TextColor3 = Theme.hex("#FFD400"), Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(226, 50), Parent = row })
		l:SetAttribute("dTS", 22)
	end
	Kit.toScale(list, Vector2.new(960, 200))
end

local function redeem()
	local code = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if code == "" then status.Text = "Type a code first"; status.TextColor3 = Theme.hex("#FF6A5E") return end
	status.Text = "Checking..."; status.TextColor3 = Theme.hex("#CFCDD3")
	local r = ctx.ask and ctx.ask("RedeemCode", code)
	if r and r.ok then
		box.Text = ""
		status.Text = r.msg or "Redeemed!"; status.TextColor3 = Theme.hex("#FFD400")
	else
		status.Text = (r and r.msg) or "That code didn't work"; status.TextColor3 = Theme.hex("#FF6A5E")
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
	local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(430, 250), Size = UDim2.fromOffset(1060, 560), BackgroundColor3 = Color3.new(0, 0, 0),
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
	local go = Kit.button("robux", UDim2.fromOffset(222, 84), "Redeem")
	go.Name = "Redeem"
	go.Position = UDim2.fromOffset(806, 156)
	go.Parent = panel
	go.Activated:Connect(redeem)
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	status = Kit.label({ Text = "", FontFace = FB, TextSize = 24, TextColor3 = Theme.hex("#CFCDD3"), Position = UDim2.fromOffset(34, 250), Size = UDim2.fromOffset(990, 32), Parent = panel })
	status:SetAttribute("dTS", 24)
	stroke(Kit.label({ Text = "Redeemed", FontFace = FB, TextSize = 32, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(32, 300), Size = UDim2.fromOffset(400, 40), Parent = panel }), 2)
	list = new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 350), Size = UDim2.fromOffset(960, 200), Parent = panel },
		{ new("UIGridLayout", { CellSize = UDim2.fromScale(250 / 960, 50 / 200), CellPadding = UDim2.fromScale(12 / 960, 12 / 200), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local close = Kit.closeButton(UDim2.fromOffset(112, 58))
	close.Position = UDim2.fromOffset(1520, 250)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	Kit.toScale(root)
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
