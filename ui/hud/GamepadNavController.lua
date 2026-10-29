-- Client/Controllers/GamepadNavController (ModuleScript, auto-loaded; lobby + match places). UI session 2026-10-17.
-- Controller menus the RIVALS way (Edward: "Xbox / PlayStation"): with a gamepad as the last input,
--   * a menu opening puts the controller selection on its first button (top-left first), the D-pad / left stick move it
--     (Roblox's own gamepad selection), A presses; the selected button grows like a mouse hover (Kit.bindButton);
--   * the selection box is Tacticals' own: a bone outline with olive corners (PlayerGui.SelectionImageObject);
--   * B closes the top menu (profile card, player menu, Your Party, Settings / Shop / Play / Codes / Missions / Ranked,
--     the match results "Continue");
--   * LB / RB switch tabs in tabbed menus: any GuiButton with attribute NavTab (number = order) is a tab, the one with
--     NavTabOn = true is the current one; switching sets the tab's NavPressed attribute (a button can't be clicked from
--     code), which the screen listens to (Settings, Your Party).
-- Menus are found by ScreenGui name (MENUS); the topmost enabled one with a visible GuiButton wins.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepadService = game:GetService("GamepadService")
-- (Edward 2026-10-20) menus that use the controller CURSOR like RIVALS, not button-to-button selection: the weapons picker.
-- And whenever the player has the cursor on, the selection is never forced on them (it used to flip to selection
-- after the picker rebuilt its buttons).
local CURSOR_MENUS = { MatchFlow = true }

local controller = {}
local player = Players.LocalPlayer

-- ScreenGui name -> how B closes it
local MENUS = {
	"PlayerCards", "PartyUI", "SettingsUI", "ShopUI2", "PlayUI", "CodesUI", "MissionsUI", "RankedUI", "MatchFlow", "DuelHUD", "LobbyUI", "WeaponBin",
}

local padOn = false
local function shown(g)
	while g and g:IsA("GuiObject") do
		if not g.Visible then return false end
		g = g.Parent
	end
	return true
end
local function buttonsIn(gui)
	local list = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.AbsoluteSize.X > 4 and d.AbsoluteSize.Y > 4 and shown(d) then
			-- skip full-screen click catchers / tints
			local vp = workspace.CurrentCamera.ViewportSize
			if not (d.AbsoluteSize.X > vp.X * 0.9 and d.AbsoluteSize.Y > vp.Y * 0.8) then table.insert(list, d) end
		end
	end
	return list
end
-- the menu that's up: highest DisplayOrder among the enabled MENUS that have something to press
local function topMenu()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	local best, bestOrder
	for _, name in MENUS do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			local ok = true
			if name == "DuelHUD" then -- only its results card counts as a menu
				local res = g:FindFirstChild("Results", true)
				ok = res ~= nil and res.Visible
			elseif name == "LobbyUI" then -- only its centre panel (the old Offset panels)
				local panel = g:FindFirstChild("Panel", true)
				ok = panel ~= nil and panel:IsA("GuiObject") and panel.Visible
			elseif name == "WeaponBin" then -- the Training picker; its Weapons button alone is not a menu
				local picker = g:FindFirstChild("Picker", true)
				ok = picker ~= nil and picker.Visible
			elseif name == "PlayerCards" then
				ok = g:FindFirstChild("ProfileTint") ~= nil or g:FindFirstChild("PlayerMenu", true) ~= nil
			end
			if ok and #buttonsIn(g) > 0 and (not bestOrder or g.DisplayOrder > bestOrder) then best, bestOrder = g, g.DisplayOrder end
		end
	end
	return best
end
local function firstButton(gui)
	local list = buttonsIn(gui)
	-- prefer the content over the close X: top-left first, but the X (CloseX) last
	table.sort(list, function(a, b)
		local ax, bx = a.Name == "CloseX", b.Name == "CloseX"
		if ax ~= bx then return bx end
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 8 then return pa.Y < pb.Y end
		return pa.X < pb.X
	end)
	-- a tab bar along the top: start on the current tab
	for _, b in list do if b:GetAttribute("NavTabOn") == true then return b end end
	return list[1]
end

-- the selection box: a bone outline ring
-- (2026-10-29, UI survey fix 4) Scale only: the corner is a share of the button (was 8 px), and the four 10 px corner ticks are gone
-- (they were Offset, and a 4-corner tick box is the bracket look UI Corrections 2026-10-16 retired)
local function selectionImage()
	local f = Instance.new("Frame")
	f.Name = "TacticalsSelection"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(236, 232, 218)
	st.Thickness = 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = f
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.12, 0)
	c.Parent = f
	return f
end

local function closeTop(menu)
	local name = menu and menu.Name
	local UIKit = ReplicatedStorage:FindFirstChild("UIKit")
	local function mod(n) local ok, m = pcall(function() return require(UIKit:FindFirstChild(n)) end) return ok and m or nil end
	if name == "PlayerCards" then
		local PC = mod("PlayerCards")
		if PC then if PC.ProfileOpen() then PC.CloseProfile() else PC.CloseMenu() end end
	elseif name == "PartyUI" then
		local P = mod("PartyScreen"); if P then P.Close() end
	elseif name == "WeaponBin" then
		local TB = shared.Get and shared.Get("TrainingBinsController"); if TB and TB.Close then TB.Close() end
	elseif name == "MatchFlow" then
		-- Switch Weapons (between rounds, or still up in the round) closes; map vote / loadout: no backing out
		if player:GetAttribute("SwitchingWeapons") then
			local sw = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("SwitchWeapons")
			if sw then sw:Invoke("Close") end
		end
		return
	elseif name == "DuelHUD" then
		-- results: B puts the selection on Continue (A presses it)
		local res = menu:FindFirstChild("Results", true)
		for _, d in res and res:GetDescendants() or {} do
			if d:IsA("GuiButton") and shown(d) then GuiService.SelectedObject = d break end
		end
	else
		local LobbyUI = shared.Get and shared.Get("LobbyUIController")
		if LobbyUI then
			if LobbyUI.CloseScreens then LobbyUI.CloseScreens() end
			if LobbyUI.Close then LobbyUI.Close() end
		end
	end
end

-- LB / RB: the tab before / after the current one (NavTab order)
local function switchTab(menu, step)
	local tabs = {}
	for _, d in menu:GetDescendants() do
		if d:IsA("GuiButton") and typeof(d:GetAttribute("NavTab")) == "number" and shown(d) then table.insert(tabs, d) end
	end
	if #tabs < 2 then return end
	table.sort(tabs, function(a, b) return a:GetAttribute("NavTab") < b:GetAttribute("NavTab") end)
	local cur = 1
	for i, t in tabs do if t:GetAttribute("NavTabOn") == true then cur = i end end
	local nextTab = tabs[(cur - 1 + step) % #tabs + 1]
	nextTab:SetAttribute("NavPressed", os.clock()) -- the screen opens that tab
	task.defer(function() if padOn then GuiService.SelectedObject = nextTab end end)
end

function controller.Start()
	local pg = player:WaitForChild("PlayerGui")
	pg.SelectionImageObject = selectionImage()
	local function onType(t)
		if t == Enum.UserInputType.MouseMovement then return end -- (2026-10-20) mouse MOVEMENT never flips back to keyboard + mouse: a resting mouse / locked cursor sends it, and hid every controller icon
		local pad = t.Name:find("Gamepad") ~= nil
		if pad then padOn = true
		elseif t == Enum.UserInputType.Keyboard or t.Name:find("Mouse") or t == Enum.UserInputType.Touch then
			if padOn then padOn = false; GuiService.SelectedObject = nil end
		end
	end
	UserInputService.LastInputTypeChanged:Connect(onType)
	onType(UserInputService:GetLastInputType())

	local lastMenu
	local cursorOurs = false
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if t < 0.15 then return end
		t = 0
		local menu = topMenu()
		if RunService:IsStudio() and player:GetAttribute("_ForcePad") == true then padOn = true end -- Studio test switch
		if not padOn then lastMenu = menu return end
		-- cursor menus: the controller cursor on while it's up, off after; nothing is selected for the player
		if menu and CURSOR_MENUS[menu.Name] then
			if menu ~= lastMenu then
				GuiService.SelectedObject = nil
				pcall(function() GamepadService:EnableGamepadCursor(firstButton(menu)) end)
				cursorOurs = true
			end
			lastMenu = menu
			return
		end
		if cursorOurs and (not menu or not CURSOR_MENUS[menu.Name]) then
			cursorOurs = false
			pcall(function() GamepadService:DisableGamepadCursor() end)
		end
		-- the player switched the cursor on themselves: leave them in it
		if GamepadService.GamepadCursorEnabled then lastMenu = menu return end
		local sel = GuiService.SelectedObject
		local selOk = sel ~= nil and menu ~= nil and sel:IsDescendantOf(menu) and shown(sel)
		if menu and (menu ~= lastMenu or not selOk) then
			local b = firstButton(menu)
			if b then GuiService.SelectedObject = b end
		elseif not menu and lastMenu then
			GuiService.SelectedObject = nil -- back in the world: the controller plays again
		end
		lastMenu = menu
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not padOn then return end
		local menu = topMenu()
		if not menu then return end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			closeTop(menu)
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			switchTab(menu, -1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			switchTab(menu, 1)
		end
	end)
end

return controller
