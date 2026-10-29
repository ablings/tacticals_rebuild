-- Tacticals copy of roblox_kits/checks/audit/UIAudit.lua that audits EVERY PlayerGui LayerCollector (the kit one only
-- checks "Kit*" ScreenGuis). Used by the UI survey round 2 (notes/ui_survey_r2.md). Read-only.
-- UIAudit: the automated part of the UI Proof Check (vault: 04 UI Design/UI Proof Check, section A). Run on the CLIENT
-- during Play (tools/run_checks.py does it, once at join and again with every registered menu open). Read-only.
-- Only the kit's ScreenGuis (names starting "Kit") are checked.
--   UIAudit.run(playerGui, opts?) -> { offsets, modifierOffsets, hardStrokes, clipped, tiny, offscreen, smallButtons,
--        resetOnSpawn, theme, counts = {} }
--   opts.theme = theme name (default: the deployed ReplicatedStorage.Kit.UI.Theme's name). Tests pass a Folder as playerGui.
--   offsets          a GuiObject whose Position or Size has an Offset (UI rule: Scale only)
--   modifierOffsets  UIPadding / UICorner / UIListLayout / UIGridLayout with an Offset (padding, corner radius,
--                    list Padding, grid CellPadding / CellSize). Scale-only corners such as UDim.new(1, 0) pills are fine.
--   hardStrokes      a glyph stroke (UIStroke in Contextual mode on a TextLabel / TextButton / TextBox) thicker than
--                    2 design px or more opaque than 0.55 transparency (UI Corrections: text strokes are soft).
--                    Skipped for the ComicInk theme, and for a stroke that has (or sits under) tag/attribute KeepStroke.
--   UIAudit.menus(playerGui) -> the screen registry (menus opened by a button), see the bottom of this file
local CollectionService = game:GetService("CollectionService")

local UIAudit = {}

UIAudit.STROKE_MAX_THICKNESS = 2 -- design px (Kit.toScale keeps the design value in attribute dTh)
UIAudit.STROKE_MIN_TRANSPARENCY = 0.55
UIAudit.HEAVY_STROKE_THEMES = { ComicInk = true } -- styles whose look IS the heavy outline

local function activeTheme()
	local ok, name = pcall(function()
		return require(game:GetService("ReplicatedStorage").Kit.UI.Theme).name
	end)
	return ok and name or nil
end

local function keepStroke(o)
	local x = o
	while x and x ~= game do
		if x:GetAttribute("KeepStroke") or CollectionService:HasTag(x, "KeepStroke") then return true end
		x = x.Parent
	end
	return false
end

local function isText(o) return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") end

-- true when this UIStroke is a hard text stroke (the theme / KeepStroke exemptions are applied by run)
function UIAudit.isHardTextStroke(s)
	if not s:IsA("UIStroke") or not s.Parent or not isText(s.Parent) then return false end
	if s.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Contextual then return false end -- Border = the box edge, not the glyphs
	if not s.Enabled then return false end
	local th = s:GetAttribute("dTh") or s.Thickness
	return th > UIAudit.STROKE_MAX_THICKNESS or s.Transparency < UIAudit.STROKE_MIN_TRANSPARENCY
end

local function udimOff(u) return u.Offset ~= 0 end
local function udim2Off(u) return u.X.Offset ~= 0 or u.Y.Offset ~= 0 end

-- the names of a UI modifier's properties that carry an Offset ("PaddingLeft,PaddingTop"), or nil
function UIAudit.modifierOffset(m)
	local bad = {}
	if m:IsA("UIPadding") then
		for _, p in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
			if udimOff(m[p]) then table.insert(bad, p) end
		end
	elseif m:IsA("UICorner") then
		if udimOff(m.CornerRadius) then table.insert(bad, "CornerRadius") end
	elseif m:IsA("UIListLayout") then
		if udimOff(m.Padding) then table.insert(bad, "Padding") end
	elseif m:IsA("UIGridLayout") then
		if udim2Off(m.CellPadding) then table.insert(bad, "CellPadding") end
		if udim2Off(m.CellSize) then table.insert(bad, "CellSize") end
	end
	return #bad > 0 and table.concat(bad, ",") or nil
end

function UIAudit.run(pg, opts)
	opts = opts or {}
	local theme = opts.theme or activeTheme()
	local strokesAllowed = theme ~= nil and UIAudit.HEAVY_STROKE_THEMES[theme] == true
	local vp = workspace.CurrentCamera.ViewportSize
	local r = { offsets = {}, modifierOffsets = {}, hardStrokes = {}, clipped = {}, tiny = {}, offscreen = {}, smallButtons = {},
		resetOnSpawn = {}, theme = theme }
	-- kit GUIs must survive a respawn (a duel respawns every round)
	for _, g in pg:GetChildren() do
		if g:IsA("LayerCollector") and g.ResetOnSpawn then table.insert(r.resetOnSpawn, g.Name) end
	end
	for _, sg in pg:GetChildren() do
		if sg:IsA("LayerCollector") and not (opts.skip and opts.skip[sg.Name]) then
			for _, g in sg:GetDescendants() do
				if g:IsA("UIStroke") then
					if not strokesAllowed and UIAudit.isHardTextStroke(g) and not keepStroke(g) then
						table.insert(r.hardStrokes, string.format("%s (thickness %.2f, transparency %.2f)", g:GetFullName(),
							g:GetAttribute("dTh") or g.Thickness, g.Transparency))
					end
				elseif g:IsA("UIPadding") or g:IsA("UICorner") or g:IsA("UIListLayout") or g:IsA("UIGridLayout") then
					local bad = UIAudit.modifierOffset(g)
					if bad then table.insert(r.modifierOffsets, g:GetFullName() .. " " .. bad) end
				elseif g:IsA("GuiObject") then
					local p, s = g.Position, g.Size
					if p.X.Offset ~= 0 or p.Y.Offset ~= 0 or s.X.Offset ~= 0 or s.Y.Offset ~= 0 then
						table.insert(r.offsets, g:GetFullName())
					end
					if sg.Enabled and g.Visible and g.AbsoluteSize.X > 0 then
						if g:IsA("TextLabel") or g:IsA("TextButton") then
							if not g.TextScaled and not g.TextFits then table.insert(r.clipped, g:GetFullName()) end
							if g.Text ~= "" and g.TextBounds.Y > 0 and g.TextBounds.Y < 9 then table.insert(r.tiny, g:GetFullName()) end
						end
						local ap, as = g.AbsolutePosition, g.AbsoluteSize
						if ap.X + as.X < 0 or ap.Y + as.Y < -60 or ap.X > vp.X or ap.Y > vp.Y then
							local clipped = false
							local x = g.Parent
							while x and x:IsA("GuiObject") do
								if x.ClipsDescendants then clipped = true break end
								x = x.Parent
							end
							if not clipped then table.insert(r.offscreen, g:GetFullName()) end
						end
						if g:IsA("GuiButton") and (as.X < 30 or as.Y < 30) and g.BackgroundTransparency < 1 then
							table.insert(r.smallButtons, g:GetFullName())
						end
					end
				end
			end
		end
	end
	r.counts = { offsets = #r.offsets, modifierOffsets = #r.modifierOffsets, hardStrokes = #r.hardStrokes, clipped = #r.clipped,
		tiny = #r.tiny, offscreen = #r.offscreen, smallButtons = #r.smallButtons, resetOnSpawn = #r.resetOnSpawn }
	return r
end

-- Screen registry: menus opened by a button. run_checks.py presses every registered open button with real mouse input,
-- runs the audit with the menu open (so Offsets set at runtime are caught), then closes it with its close button (or the
-- open button again). UIBits.registerMenu writes these: attribute KitMenu = <menu name> on the open button (tag
-- KitMenuOpen), the panel (tag KitMenu) and the close button (tag KitMenuClose).
UIAudit.MENU_OPEN_TAG, UIAudit.MENU_CLOSE_TAG, UIAudit.MENU_TAG = "KitMenuOpen", "KitMenuClose", "KitMenu"

-- { { name, open = path, close = path?, panel = path?, visible = bool } }; paths start at LocalPlayer (for mouse input)
function UIAudit.menus(pg)
	local function rel(o)
		local full = o:GetFullName()
		local i = full:find(".PlayerGui.", 1, true)
		return i and ("LocalPlayer" .. full:sub(i)) or full
	end
	local byName, out, panels = {}, {}, {}
	for _, o in pg:GetDescendants() do
		local name = o:GetAttribute("KitMenu")
		if type(name) == "string" then
			local m = byName[name]
			if not m then m = { name = name }; byName[name] = m; table.insert(out, m) end
			if CollectionService:HasTag(o, UIAudit.MENU_OPEN_TAG) then m.open = rel(o)
			elseif CollectionService:HasTag(o, UIAudit.MENU_CLOSE_TAG) then m.close = rel(o)
			elseif CollectionService:HasTag(o, UIAudit.MENU_TAG) then m.panel = rel(o); panels[m] = o end
		end
	end
	for _, m in out do
		local p = panels[m]
		local shown = false
		if p and p:IsA("GuiObject") then
			shown = p.Visible
			local sg = p:FindFirstAncestorWhichIsA("LayerCollector")
			if sg and not sg.Enabled then shown = false end
		end
		m.visible = shown
	end
	return out
end

return UIAudit
