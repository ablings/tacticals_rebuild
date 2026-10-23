-- Client/Controllers/TouchControlsController (ModuleScript, auto-loaded; lobby + every match place). UI session 2026-10-17.
-- Mobile controls the RIVALS way (Edward; refs notes/ref_mobile 4-16), with Tacticals' own actions:
--   * movement: Roblox's own thumbstick on the left half (its jump button is hidden: ours replaces it)
--   * buttons: Fire, Aim, Reload, Gun Bash, Throw Gadget, Jump, Crouch, Slide (off by default), Take Cover, Dash,
--     Equip Gun / Melee / Gadget (top right, ammo on the gun), Shoulder Swap + Scoreboard (top left)
--   * lobby: only Jump, Crouch, Scoreboard; Training / duels / match places: everything
-- Each button calls the shared input layer (ReplicatedStorage.Modules.Shared.InputActions, built by the Tacticals session):
-- InputActions.Press(action) on touch down, .Release(action) on up. Gameplay controllers listen there ([TOUCH] hooks).
-- Settings > Touch: Left Handed Mode (mirror), Opaque Buttons, Buttons Transparency, Show Weapon Ammo, per button Enabled /
-- Custom (+ its own Transparency), Touch Layout Slot 1-3 (each a JSON layout { [id] = { x, y, s } }, Scale of the screen).
-- Layout Editor: TouchControls.OpenEditor(): hatched overlay, drag a button to move it, drag its ↘ handle to resize;
-- The joystick ring is editable too (saved as "Joystick"; TouchStick reads StickX/StickY/StickSize off its ScreenGui).
-- top pill: X (save + close), reset, slots 1 2 3. Saving goes through TouchControls.OnSave(slot, json) (LobbyUIController).
-- Studio test: set the player attribute _ForceTouch = true to show the controls without a touch screen.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local controller = {}

-- id, action (InputActions), glyph, default { x, y, size } (x/y = Scale of the screen, size = share of the screen height),
-- lobby = shown outside combat too
-- (2026-10-23, Edward: "how jumbled up and disorganized our keybinds look compared to rivals", RIVALS' default mobile layout
-- screenshot) the defaults now copy RIVALS: Aim (crosshair) and Fire (claw) stacked bottom right with Jump under Aim, Crouch under
-- Fire, Reload left of them; the weapon slots in a row top right with Gun Bash / Throw Gadget under them; the eye top left. Our
-- extras sit around that cluster: Sprint (hold = the opposite of Auto Sprint) left of Crouch, Take Cover and Dash above Reload.
-- Slide is no button any more: Crouch slides while you run (its icon switches), like RIVALS.
local BUTTONS = {
	{ id = "Fire", action = "Fire", glyph = "◉", x = 0.832, y = 0.659, s = 0.158 },
	{ id = "Aim", action = "Aim", glyph = "◎", x = 0.906, y = 0.579, s = 0.158 },
	{ id = "Jump", action = "Jump", glyph = "⬆", x = 0.906, y = 0.80, s = 0.18, lobby = true },
	{ id = "Crouch", action = "Crouch", glyph = "⇩", x = 0.806, y = 0.83, s = 0.158, lobby = true },
	{ id = "Sprint", action = "Sprint", glyph = "»", x = 0.715, y = 0.86, s = 0.12, lobby = true },
	{ id = "Slide", action = "Slide", glyph = "↘", x = 0.715, y = 0.86, s = 0.12 }, -- (kept for old layouts; off by default)
	{ id = "Take Cover", action = "Cover", glyph = "▣", x = 0.70, y = 0.585, s = 0.105 },
	{ id = "Dash", action = "Dash", glyph = "»", x = 0.752, y = 0.515, s = 0.10 },
	{ id = "Reload", action = "Reload", glyph = "R", x = 0.7595, y = 0.704, s = 0.113 },
	{ id = "Gun Bash", action = "QuickMelee", glyph = "✊", x = 0.911, y = 0.228, s = 0.067 },
	{ id = "Throw Gadget", action = "QuickUtility", glyph = "●", x = 0.9575, y = 0.228, s = 0.067 },
	{ id = "Equip Gun", action = "Equip1", glyph = "1", x = 0.8635, y = 0.136, s = 0.092 },
	{ id = "Equip Melee", action = "Equip2", glyph = "2", x = 0.911, y = 0.136, s = 0.092 },
	{ id = "Equip Gadget", action = "Equip3", glyph = "3", x = 0.9575, y = 0.136, s = 0.092 },
	{ id = "Shoulder Swap", action = "CameraSwap", glyph = "⇄", x = 0.093, y = 0.181, s = 0.09 },
	{ id = "Open Scoreboard", action = "Scoreboard", glyph = "≡", x = 0.041, y = 0.181, s = 0.09, lobby = true },
}
local BY_ID = {}
for _, b in BUTTONS do BY_ID[b.id] = b end
-- (2026-10-17) Codex silhouette icons, uploaded by Edward under Gunsy Funsy (ui/art/touch; decal -> image ids). A button
-- with an icon draws it instead of its glyph; Equip Melee / Gadget reuse the fist / grenade, Equip Gun shows the gun in 3D.
local ICON = {
	["Fire"] = "rbxassetid://81909483490250", ["Aim"] = "rbxassetid://134198129338690", ["Reload"] = "rbxassetid://100573206538316",
	["Gun Bash"] = "rbxassetid://136244634400340", ["Throw Gadget"] = "rbxassetid://128775020926516", ["Jump"] = "rbxassetid://95980290317525",
	["Crouch"] = "rbxassetid://83130114120097", ["Slide"] = "rbxassetid://87783001534280", ["Take Cover"] = "rbxassetid://74308443713215",
	["Dash"] = "rbxassetid://73177336441528", ["Shoulder Swap"] = "rbxassetid://98639300079463", ["Open Scoreboard"] = "rbxassetid://79522862397381",
	["Equip Melee"] = "rbxassetid://136244634400340", ["Equip Gadget"] = "rbxassetid://128775020926516",
}
-- the joystick (the lead's TouchStick): where it sits when the layout moves it. Unset = its own default half-screen zone.
-- Stored like the buttons, in right-handed space (x mirrored for Left Handed Mode); s = ring diameter / screen height.
local STICK_DEFAULT = { x = 0.2, y = 0.72, s = 0.22 }
local function validStick(t)
	if type(t) ~= "table" or not (tonumber(t.x) and tonumber(t.y) and tonumber(t.s)) then return nil end
	return { x = math.clamp(t.x, 0.05, 0.95), y = math.clamp(t.y, 0.1, 0.95), s = math.clamp(t.s, 0.1, 0.5) }
end

local function setting(name, default)
	local v = player:GetAttribute("Setting_" .. name:gsub("[^%w_]", ""))
	if v == nil then return default end
	return v
end

local InputActions
local function actions()
	if InputActions then return InputActions end
	local m = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	m = m and m:FindFirstChild("InputActions")
	if m then pcall(function() InputActions = require(m) end) end
	return InputActions
end
local function combat()
	local ok, on = pcall(function() return require(ReplicatedStorage.Modules.Shared.TrainingGate).On() end)
	return ok and on == true
end
-- (2026-10-18) the hub's own movement (the Tacticals session's LobbyMovement): its slide is fired through SlideRequest
local function lobbySlide()
	local ps = player:FindFirstChild("PlayerScripts")
	local lm = ps and ps:FindFirstChild("LobbyMovement")
	return lm and lm:FindFirstChild("SlideRequest")
end
local function touchOn() return UserInputService.TouchEnabled or player:GetAttribute("_ForceTouch") == true end
-- moving at running speed (the Crouch button slides then, and shows the slide icon)
local function running()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 12
end
-- in a fight: the match places / training (TrainingGate) and the hub's pad duels
local function fighting() return combat() or player:GetAttribute("InDuel") == true or player:GetAttribute("DuelMatch") ~= nil end

-- the saved layout of the chosen slot, merged over the defaults
local function layout()
	local slot = setting("Touch Layout Slot", "1")
	local ok, saved = pcall(function() return HttpService:JSONDecode(setting("Touch Layout " .. slot, "") or "") end)
	local out = {}
	for _, b in BUTTONS do
		local s = ok and type(saved) == "table" and saved[b.id]
		out[b.id] = (type(s) == "table" and tonumber(s.x) and tonumber(s.y) and tonumber(s.s)) and { x = s.x, y = s.y, s = s.s } or { x = b.x, y = b.y, s = b.s }
	end
	out.Joystick = ok and type(saved) == "table" and validStick(saved.Joystick) or nil
	return out, slot
end

---------------------------------------------------------------------------------------------------- the buttons
local gui, holder
local made = {} -- id -> { btn, glyph, ammo, stroke }
local editing = false

-- (2026-10-17, Edward: "make the buttons like rivals", refs notes/ref_mobile) flat translucent dark-grey discs, no
-- outline, big light-grey icons; held = filled with the accent and the icon goes white. Tacticals olive is the accent.
-- (Edward: "the icons are transparent and when the button is pressed the button turns blue and then the icon turns full white")
local DISC, ICONC, ACCENT, ICON_ON = Color3.fromRGB(40, 42, 40), Color3.fromRGB(235, 235, 235), Color3.fromRGB(30, 180, 255), Color3.new(1, 1, 1)
local ICON_REST = 0.35 -- the icon's own see-through at rest (plus the button transparency setting)
local function styleButton(id, m)
	local opaque = setting("Opaque Buttons", true)
	local t = (setting(id .. " Custom", false) and setting(id .. " Transparency", 50) or setting("Buttons Transparency", 50)) / 100
	-- opaque: the disc (RIVALS ~0.35 at the default 50%); see-through: just a faint ring
	m.btn.BackgroundTransparency = m.held and 0.05 or (opaque and (0.1 + 0.5 * t) or 1)
	m.stroke.Transparency = opaque and 1 or (0.3 + 0.6 * t)
	m.glyph.TextTransparency = 0.05 + 0.6 * t
	if m.icon then m.icon.ImageTransparency = m.held and 0 or math.min(0.9, ICON_REST + 0.4 * t) end
	m.glyph.TextTransparency = m.held and 0 or math.min(0.9, ICON_REST + 0.4 * t)
	if m.gunView and m.gunView:IsA("ViewportFrame") then m.gunView.ImageTransparency = 0.05 + 0.6 * t end
	-- for the input layer's touch camera: may a drag that starts on this button also turn the camera?
	local sink
	if setting(id .. " Custom", false) then sink = setting(id .. " Camera Sinking", true) else sink = setting("Buttons Camera Sinking", true) end
	m.btn:SetAttribute("SinkCamera", sink == true)
end

local function place(id, m, l)
	local p = l[id]
	local x = setting("Left Handed Mode", false) and (1 - p.x) or p.x
	m.btn.Position = UDim2.fromScale(x, p.y)
	m.btn.Size = UDim2.fromScale(p.s, p.s)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	for _, b in BUTTONS do
		local btn = Instance.new("TextButton")
		btn:AddTag("Nonapplicable") -- (the old InterfaceController would hover-tween this Offset button to 0 x 0)
		btn.Name = b.id
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.SizeConstraint = Enum.SizeConstraint.RelativeYY -- size = share of the screen height, always round
		btn.BackgroundColor3 = DISC
		btn.Parent = holder
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = btn
		-- (2026-10-21, AI-tells cleanup) the see-through mode ring is the button's only outline (meaning): kept, thickened 2 -> 3;
		-- every glyph / zone / pill font is Oswald Bold now (was Builder Sans ExtraBold)
		local st = Instance.new("UIStroke"); st.Color = ICONC; st.Thickness = 3; st.Transparency = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = btn
		local g = Instance.new("TextLabel")
		g.BackgroundTransparency = 1
		g.Size = UDim2.fromScale(0.62, 0.62)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Text = b.glyph
		g.TextScaled = true
		g.FontFace = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Bold)
		g.TextColor3 = ICONC
		g.Parent = btn
		local img
		if ICON[b.id] then
			g.Text = ""
			img = Instance.new("ImageLabel")
			img.Name = "Icon"
			img.BackgroundTransparency = 1
			img.Image = ICON[b.id]
			img.ImageColor3 = ICONC
			img.ScaleType = Enum.ScaleType.Fit
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(0.68, 0.68) -- RIVALS' icons nearly fill the disc
			img.Parent = btn
		end
		local ammo
		if b.id == "Equip Gun" then
			ammo = Instance.new("TextLabel")
			ammo.BackgroundTransparency = 1
			ammo.AnchorPoint = Vector2.new(0.5, 0)
			ammo.Position = UDim2.fromScale(0.5, 0.62)
			ammo.Size = UDim2.fromScale(0.9, 0.34)
			ammo.Text = ""
			ammo.TextScaled = true
			ammo.FontFace = g.FontFace
			ammo.TextColor3 = Color3.new(1, 1, 1)
			ammo.Parent = btn
			local as = Instance.new("UIStroke"); as.Thickness = 1.5; as.Parent = ammo
		end
		made[b.id] = { btn = btn, glyph = g, icon = img, ammo = ammo, stroke = st }
		-- press / release -> the input layer (each touch on its own button: multi-touch works)
		btn.InputBegan:Connect(function(input)
			if editing then return end
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local ia = actions()
			-- (2026-10-23) Crouch while running = a slide (the hub's own slide outside combat; in combat MovementController's crouch key
			-- already slides when you sprint)
			local hubSlide = (b.id == "Slide" or (b.id == "Crouch" and running())) and not combat() and lobbySlide()
			if hubSlide then
				if ia and ia.Consume then ia.Consume(input, false) end
				hubSlide:Fire() -- the hub slide (LobbyMovement)
			elseif ia then
				-- this touch belongs to the button; with camera sinking a drag from it may still turn the camera
				if ia.Consume then ia.Consume(input, btn:GetAttribute("SinkCamera") == true) end
				ia.Press(b.action)
			end
			local m = made[b.id]
			if m then m.held = true end
			btn.BackgroundColor3 = ACCENT
			btn.BackgroundTransparency = 0.05
			if m and m.icon then m.icon.ImageColor3 = ICON_ON; m.icon.ImageTransparency = 0 end
			if m then m.glyph.TextColor3 = ICON_ON end
		end)
		btn.InputEnded:Connect(function(input)
			if editing then return end
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local ia = actions()
			if ia then ia.Release(b.action) end
			local m = made[b.id]
			if m then
				m.held = false
				btn.BackgroundColor3 = DISC
				if m.icon then m.icon.ImageColor3 = ICONC end
				m.glyph.TextColor3 = ICONC
				styleButton(b.id, m)
			end
		end)
	end
end

-- Roblox's own touch jump button: ours replaces it (the thumbstick stays)
local function hideRobloxJump()
	local tg = player.PlayerGui:FindFirstChild("TouchGui")
	local jb = tg and tg:FindFirstChild("JumpButton", true)
	if jb and jb.Visible then jb.Visible = false end
end

-- the layout's joystick -> TouchStick's ScreenGui attributes (StickX/StickY absolute, so mirrored here)
local function applyStick(j)
	local sg = player.PlayerGui:FindFirstChild("TouchStick")
	if not sg then return end
	local x = j and (setting("Left Handed Mode", false) and (1 - j.x) or j.x)
	local want = { StickX = x or false, StickY = j and j.y or false, StickSize = j and j.s or false }
	for k, v in want do
		if v == false then v = nil end
		if sg:GetAttribute(k) ~= v then sg:SetAttribute(k, v) end
	end
end

local wasShown = false
local function refresh()
	if not gui then return end
	-- a lobby menu (Settings, Shop, Play...) or the profile card covers the screen: the buttons go, like RIVALS
	-- (2026-10-23, Edward: no buttons in the lobby until you die, none on the duel pads, gone after Play Again) the old rule read the
	-- legacy LobbyUI ScreenGui (off = "a menu is open"), but the new lobby HUD leaves it off, and pad duels / the after-match lobby
	-- switch it too. A menu is open when the lobby HUD is pushed aside (LobbyHud Root PushedAway, set while any screen is open) or
	-- the Kit room is up (InKit); never while you're fighting.
	local menuUp = false
	local hudGui = player.PlayerGui:FindFirstChild("LobbyHud")
	local hudRoot = hudGui and hudGui.Enabled and hudGui:FindFirstChild("Root", true)
	if hudRoot and hudRoot:GetAttribute("PushedAway") == true then menuUp = true end
	if player:GetAttribute("InKit") == true then menuUp = true end -- the Kit room (ArmoryUI itself stays Enabled)
	if fighting() and not (player:GetAttribute("Alive") == false) then menuUp = false end
	local cards = player.PlayerGui:FindFirstChild("PlayerCards")
	if cards and cards:FindFirstChild("ProfileTint") then menuUp = true end
	local partyUI = player.PlayerGui:FindFirstChild("PartyUI")
	if partyUI and partyUI.Enabled then menuUp = true end
	-- match screens: the results card, and the map vote / loadout (MatchFlow) cover the screen too
	local duel = player.PlayerGui:FindFirstChild("DuelHUD")
	local res = duel and duel:FindFirstChild("Results", true)
	if res and res.Visible and duel.Enabled then menuUp = true end
	local flow = player.PlayerGui:FindFirstChild("MatchFlow")
	if flow and flow:IsA("ScreenGui") and flow.Enabled then menuUp = true end
	local on = touchOn() and not menuUp and player:GetAttribute("Setting_HideHUD") ~= true and player:GetAttribute("InCutscene") ~= true
	gui.Enabled = on or editing
	local ia = actions()
	if ia and ia.Config then
		-- the input layer's touch rules follow Settings > Touch
		ia.Config.LeftHanded = setting("Left Handed Mode", false)
		ia.Config.DoubleTapAttack = setting("Double Tap To Attack", true) and setting("Fire Enabled", true)
		ia.Config.DoubleTapWindow = setting("Double Tap Window", 0.25)
	end
	-- hidden (HUD off, cutscene, editor): nothing may stay held
	local shown = gui.Enabled and not editing
	if wasShown and not shown and ia and ia.ReleaseAll then ia.ReleaseAll() end
	wasShown = shown
	if not gui.Enabled then return end
	local l = layout()
	applyStick(l.Joystick)
	local inCombat = fighting()
	for id, m in made do
		local b = BY_ID[id]
		place(id, m, l)
		styleButton(id, m)
		-- (the hub has its own slide: the Slide button always shows there; in combat it stays opt-in via Settings > Touch)
		m.btn.Visible = editing or ((inCombat or b.lobby) and setting(id .. " Enabled", b.id ~= "Slide"))
	end
	-- (2026-10-23) Crouch shows the slide icon while you run (pressing it slides then); Sprint says what holding it does: with Auto
	-- Sprint (Settings > Touch, on by default) you run on your own and holding it walks, without it holding it runs
	local cm = made["Crouch"]
	if cm and cm.icon then cm.icon.Image = (running() and ICON["Slide"]) or ICON["Crouch"] end
	local sm = made["Sprint"]
	if sm then
		local auto = setting("Mobile Auto Sprint", true)
		sm.glyph.Text = auto and "Walk" or "Run"
		sm.glyph.Size = UDim2.fromScale(0.78, 0.4)
	end
	-- ammo on the gun button (Show Weapon Ammo)
	local gun = made["Equip Gun"]
	if gun and gun.ammo then
		local tool
		local char = player.Character
		for _, src in { char, player:FindFirstChildOfClass("Backpack") } do
			if src then for _, t in src:GetChildren() do if t:IsA("Tool") and t:GetAttribute("WeaponId") then tool = t end end end
		end
		local a = tool and tool:GetAttribute("Ammo")
		gun.ammo.Visible = setting("Show Weapon Ammo", true) and a ~= nil
		gun.ammo.Text = a and tostring(a) or ""
		-- the gun itself, in 3D (UIKit.ViewIcons where it exists; else the "1" stays)
		local wid = tool and tool:GetAttribute("WeaponId") or player:GetAttribute("Loadout")
		if wid ~= gun.gunId then
			gun.gunId = wid
			if gun.gunHolder then gun.gunHolder:Destroy(); gun.gunHolder, gun.gunView = nil, nil end
			local function ownView()
				-- a clone of the gun tool's parts in a ViewportFrame, framed on its bounding box
				if not tool then return false end
				local vf = Instance.new("ViewportFrame")
				vf.Name = "GunView"
				vf.BackgroundTransparency = 1
				vf.AnchorPoint = Vector2.new(0.5, 0.5)
				vf.Position = UDim2.fromScale(0.5, 0.42)
				vf.Size = UDim2.fromScale(0.86, 0.6)
				vf.Ambient = Color3.fromRGB(235, 235, 235)
				vf.LightDirection = Vector3.new(-1, -1, -1)
				vf.LightColor = Color3.new(1, 1, 1)
				local model = Instance.new("Model")
				for _, d in tool:GetDescendants() do
					if d:IsA("BasePart") and d.Transparency < 1 then
						local c = d:Clone()
						for _, k in c:GetChildren() do if not (k:IsA("SpecialMesh") or k:IsA("Decal") or k:IsA("Texture") or k:IsA("SurfaceAppearance")) then k:Destroy() end end
						c.Anchored = true
						-- a light silhouette like the button icons (the guns are near-black and vanished on the dark disc)
						c.Color = ICONC
						c.Material = Enum.Material.SmoothPlastic
						if c:IsA("MeshPart") then c.TextureID = "" end
						for _, k in c:GetChildren() do if k:IsA("SpecialMesh") then k.TextureId = "" end if k:IsA("Decal") or k:IsA("Texture") or k:IsA("SurfaceAppearance") then k:Destroy() end end
						c.Parent = model
					end
				end
				if #model:GetChildren() == 0 then return false end
				model.Parent = vf
				local cf, size = model:GetBoundingBox()
				local cam = Instance.new("Camera")
				cam.FieldOfView = 30
				local dist = math.max(size.X, size.Y, size.Z) * 2.2
				-- side view: look along the gun's thinnest axis (its width), so the profile fills the circle
				local axes = { { size.X, cf.RightVector }, { size.Y, cf.UpVector }, { size.Z, cf.LookVector } }
				table.sort(axes, function(a, b) return a[1] < b[1] end)
				local side = axes[1][2]
				local up = math.abs(side:Dot(Vector3.yAxis)) > 0.9 and cf.LookVector or Vector3.yAxis
				cam.CFrame = CFrame.lookAt(cf.Position + side * dist, cf.Position, up)
				dist = math.max(axes[2][1], axes[3][1]) * 2.4
				cam.CFrame = CFrame.lookAt(cf.Position + side * dist, cf.Position, up)
				cam.Parent = vf
				vf.CurrentCamera = cam
				vf.Parent = gun.btn
				gun.gunHolder, gun.gunView = vf, vf
				return true
			end
			local ok = pcall(function()
				local VI = require(ReplicatedStorage:FindFirstChild("UIKit"):FindFirstChild("ViewIcons"))
				local model = wid and VI.Weapon(wid)
				if model then
					local holder = Instance.new("Frame")
					holder.Name = "GunView"
					holder.BackgroundTransparency = 1
					holder.AnchorPoint = Vector2.new(0.5, 0.5)
					holder.Position = UDim2.fromScale(0.5, 0.42)
					holder.Size = UDim2.fromScale(0.86, 0.6)
					holder.Parent = gun.btn
					VI.Viewport(holder, model, { view = VI.GunView, zoom = 0.95, still = true })
					gun.gunHolder = holder
					gun.gunView = holder:FindFirstChildWhichIsA("ViewportFrame", true) or holder
				end
			end)
			if not (ok and gun.gunView) then pcall(ownView) end
			gun.glyph.Text = gun.gunView and "" or "1"
			if not gun.gunView then gun.gunId = nil end -- no gun in hand yet: try again next refresh
		end
	end
	hideRobloxJump()
end

---------------------------------------------------------------------------------------------------- layout editor
controller.OnSave = nil -- function(slot, json): set by LobbyUIController (writes Settings > Touch > Touch Layout <slot>)
local overlay

local function hatch(parent, color)
	-- diagonal stripes (RIVALS' editor): thin rotated bars over a tinted wash
	for i = -12, 24 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.BackgroundTransparency = 0.82
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Rotation = 45
		bar.Position = UDim2.fromScale(i / 12, 0.5)
		bar.Size = UDim2.fromScale(0.004, 3)
		bar.Parent = parent
	end
end

function controller.OpenEditor()
	if not gui then build() end
	local ia = actions()
	if ia and ia.ReleaseAll then ia.ReleaseAll() end
	if overlay then overlay:Destroy() end
	editing = true
	local work, slot = layout()
	overlay = Instance.new("Frame")
	overlay.Name = "LayoutEditor"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(30, 95, 210)
	overlay.BackgroundTransparency = 0.55
	overlay.ClipsDescendants = true
	overlay.ZIndex = 0
	overlay.Parent = gui
	hatch(overlay, Color3.fromRGB(20, 40, 10))
	holder.ZIndex = 2
	local function zone(text, x, y)
		local z = Instance.new("TextLabel")
		z.BackgroundTransparency = 1
		z.Text = text
		z.TextScaled = true
		z.FontFace = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Bold)
		z.TextColor3 = Color3.new(0, 0, 0)
		z.TextTransparency = 0.6
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z.Position = UDim2.fromScale(x, y)
		z.Size = UDim2.fromScale(0.3, 0.07)
		z.Parent = overlay
	end
	local left = setting("Left Handed Mode", false)
	if setting("Double Tap To Attack", true) then zone("Double Tap To Attack", left and 0.25 or 0.75, 0.48) end

	-- the joystick: a ring you drag / resize like a button; the faint square around it is where a thumb starts the stick
	local stickZone = Instance.new("Frame")
	stickZone.Name = "JoystickZone"
	stickZone.AnchorPoint = Vector2.new(0.5, 0.5)
	stickZone.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stickZone.BackgroundColor3 = Color3.new(0, 0, 0)
	stickZone.BackgroundTransparency = 0.75
	stickZone.Parent = holder
	local zc = Instance.new("UICorner"); zc.CornerRadius = UDim.new(0.08, 0); zc.Parent = stickZone
	local stick = Instance.new("TextButton")
	stick:AddTag("Nonapplicable") -- (the old InterfaceController would hover-tween this Offset button to 0 x 0)
	stick.Name = "Joystick"
	stick.Text = ""
	stick.AutoButtonColor = false
	stick.AnchorPoint = Vector2.new(0.5, 0.5)
	stick.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stick.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
	stick.BackgroundTransparency = 0.5
	stick.ZIndex = 3
	stick.Parent = holder
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0.5, 0); sc.Parent = stick
	-- (2026-10-21, AI-tells cleanup) the joystick's edit-mode outline marks where it is: kept, thickened 2 -> 3
	local ss = Instance.new("UIStroke"); ss.Color = Color3.fromRGB(236, 232, 218); ss.Thickness = 3; ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ss.Parent = stick
	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.AnchorPoint = Vector2.new(0.5, 0.5)
	sl.Position = UDim2.fromScale(0.5, 0.5)
	sl.Size = UDim2.fromScale(0.8, 0.22)
	sl.Text = "Joystick"
	sl.TextScaled = true
	sl.FontFace = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Bold)
	sl.TextColor3 = Color3.fromRGB(236, 232, 218)
	sl.ZIndex = 3
	sl.Parent = stick
	local function placeStick()
		local j = work.Joystick or STICK_DEFAULT
		local x = left and (1 - j.x) or j.x
		stick.Position, stick.Size = UDim2.fromScale(x, j.y), UDim2.fromScale(j.s, j.s)
		stickZone.Position, stickZone.Size = stick.Position, UDim2.fromScale(j.s * 3, j.s * 3)
		ss.Transparency = work.Joystick and 0.2 or 0.55 -- dimmer while it is still the default zone
	end
	placeStick()

	-- drag + resize handles
	local conns = {}
	local editables = {}
	for id, m in made do editables[id] = m end
	editables.Joystick = { btn = stick }
	-- (Edward, RIVALS: "they allow you to tap on each of these individually and change their size") a tap selects a button:
	-- a blue ring on it and the size bar at the bottom (its name, - / slider / +); dragging still moves it
	local selected
	local sizeBar = Instance.new("Frame")
	sizeBar.Name = "SizeBar"
	sizeBar.AnchorPoint = Vector2.new(0.5, 1)
	sizeBar.Position = UDim2.fromScale(0.5, 0.97)
	sizeBar.Size = UDim2.fromScale(0.46, 0.11)
	sizeBar.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
	sizeBar.BackgroundTransparency = 0.1
	sizeBar.Visible = false
	sizeBar.ZIndex = 10
	sizeBar.Parent = overlay
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.3, 0); c.Parent = sizeBar end
	local sizeName = Instance.new("TextLabel")
	sizeName.BackgroundTransparency = 1
	sizeName.TextScaled = true
	sizeName.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold) -- (2026-10-21, AI-tells cleanup) Rubik (was Builder Sans)
	sizeName.TextColor3 = Color3.new(1, 1, 1)
	sizeName.TextXAlignment = Enum.TextXAlignment.Left
	sizeName.Position = UDim2.fromScale(0.04, 0.22)
	sizeName.Size = UDim2.fromScale(0.26, 0.56)
	sizeName.ZIndex = 11
	sizeName.Parent = sizeBar
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Color3.fromRGB(70, 72, 68)
	track.Position = UDim2.fromScale(0.42, 0.44)
	track.Size = UDim2.fromScale(0.42, 0.12)
	track.ZIndex = 11
	track.Parent = sizeBar
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = track end
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = ACCENT
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.ZIndex = 12
	fill.Parent = track
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = fill end
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromScale(0.7, 0.7)
	knob.SizeConstraint = Enum.SizeConstraint.RelativeYY
	knob.ZIndex = 13
	knob.Parent = sizeBar
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = knob end
	local function limits(id) if id == "Joystick" then return 0.1, 0.5 end return 0.05, 0.3 end
	local function showSize()
		if not selected then sizeBar.Visible = false return end
		sizeBar.Visible = true
		sizeName.Text = selected
		local lo, hi = limits(selected)
		local v = (work[selected] or STICK_DEFAULT).s
		local f = math.clamp((v - lo) / (hi - lo), 0, 1)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(0.42 + 0.42 * f, 0.5)
	end
	local function setSize(id, v)
		if not work[id] then work[id] = table.clone(STICK_DEFAULT) end
		local lo, hi = limits(id)
		work[id].s = math.clamp(v, lo, hi)
		if id == "Joystick" then placeStick() else place(id, made[id], work) end
		showSize()
	end
	local function pmButton(text, x, step)
		local b = Instance.new("TextButton")
		b:AddTag("Nonapplicable") -- (the old InterfaceController would hover-tween this Offset button to 0 x 0)
		b.Name = step > 0 and "SizePlus" or "SizeMinus"
		b.Text = text
		b.TextScaled = true
		b.FontFace = sizeName.FontFace
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.fromRGB(40, 42, 40)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(x, 0.5)
		b.Size = UDim2.fromScale(0.7, 0.7)
		b.SizeConstraint = Enum.SizeConstraint.RelativeYY
		b.ZIndex = 12
		b.Parent = sizeBar
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
		b.Activated:Connect(function() if selected then setSize(selected, (work[selected] or STICK_DEFAULT).s + step) end end)
	end
	pmButton("-", 0.35, -0.01)
	pmButton("+", 0.92, 0.01)
	-- dragging along the track sets the size
	table.insert(conns, track.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local function at(pos)
			if not selected then return end
			local f = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local lo, hi = limits(selected)
			setSize(selected, lo + (hi - lo) * f)
		end
		at(input.Position)
		local mv, en
		mv = UserInputService.InputChanged:Connect(function(i2)
			if i2.UserInputType == Enum.UserInputType.Touch or i2.UserInputType == Enum.UserInputType.MouseMovement then at(i2.Position) end
		end)
		en = UserInputService.InputEnded:Connect(function(i3) if i3.UserInputType == input.UserInputType then mv:Disconnect(); en:Disconnect() end end)
	end))
	local rings = {}
	local function selectBtn(id)
		selected = id
		for rid, ring in rings do ring.Visible = rid == id end
		showSize()
	end
	for id, m in editables do
		m.btn.Visible = true
		-- the selection ring (blue)
		local ring = Instance.new("Frame")
		ring.Name = "SelectRing"
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1.14, 1.14)
		ring.Visible = false
		ring.ZIndex = 6
		do
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = ring
			local st2 = Instance.new("UIStroke"); st2.Color = ACCENT; st2.Thickness = 3; st2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st2.Parent = ring
		end
		ring.Parent = m.btn
		rings[id] = ring
		local function bindDrag(target, mode)
			table.insert(conns, target.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				local start = input.Position
				if not work[id] then work[id] = table.clone(STICK_DEFAULT) end -- the joystick, first move
				local p0 = table.clone(work[id])
				local vs = workspace.CurrentCamera.ViewportSize
				local moveConn, endConn
				moveConn = UserInputService.InputChanged:Connect(function(i2)
					if i2.UserInputType ~= Enum.UserInputType.Touch and i2.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					local d = i2.Position - start
					local isStick = id == "Joystick"
					if mode == "move" then
						local dx = d.X / vs.X
						work[id].x = math.clamp(p0.x + (left and -dx or dx), isStick and 0.05 or 0.03, isStick and 0.95 or 0.97)
						work[id].y = math.clamp(p0.y + d.Y / vs.Y, isStick and 0.1 or 0.04, isStick and 0.95 or 0.96)
					else
						work[id].s = math.clamp(p0.s - d.Y / vs.Y, isStick and 0.1 or 0.05, isStick and 0.5 or 0.3)
					end
					if isStick then placeStick() else place(id, m, work) end
				end)
				endConn = UserInputService.InputEnded:Connect(function(i3)
					if i3.UserInputType == input.UserInputType then
						moveConn:Disconnect(); endConn:Disconnect()
						-- a tap (barely moved) selects the button for the size bar; a drag also selects what you moved
						selectBtn(id)
					end
				end)
			end))
		end
		bindDrag(m.btn, "move")
		if id ~= "Joystick" then place(id, m, work) end
	end

	-- top pill: X (save + close) · reset · slots 1 2 3
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.025)
	pill.Size = UDim2.fromScale(0.36, 0.085)
	pill.BackgroundColor3 = Color3.fromRGB(14, 15, 13)
	pill.ZIndex = 10
	pill.Parent = overlay
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.5, 0); pc.Parent = pill
	local slotBtns = {}
	local function pillButton(text, i, fn)
		local b = Instance.new("TextButton")
		b:AddTag("Nonapplicable") -- (the old InterfaceController would hover-tween this Offset button to 0 x 0)
		b.Text = text
		b.TextScaled = true
		b.FontFace = Font.new("rbxasset://fonts/families/Rubik.json", Enum.FontWeight.Bold)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 1
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale((i - 0.5) / 5, 0.5)
		b.Size = UDim2.fromScale(0.16, 0.78)
		b.ZIndex = 11
		b.Parent = pill
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
		b.Activated:Connect(fn)
		return b
	end
	local function json()
		local out = {}
		for id, p in work do out[id] = { x = math.floor(p.x * 1000 + 0.5) / 1000, y = math.floor(p.y * 1000 + 0.5) / 1000, s = math.floor(p.s * 1000 + 0.5) / 1000 } end
		return HttpService:JSONEncode(out)
	end
	local function close()
		if controller.OnSave then controller.OnSave(slot, json()) end
		for _, c in conns do c:Disconnect() end
		for _, m in made do local h = m.btn:FindFirstChild("SelectRing") if h then h:Destroy() end end
		stick:Destroy(); stickZone:Destroy()
		editing = false
		overlay:Destroy(); overlay = nil
		refresh()
	end
	pillButton("×", 1, close)
	pillButton("Reset", 2, function()
		for _, b in BUTTONS do work[b.id] = { x = b.x, y = b.y, s = b.s } end
		work.Joystick = nil -- back to TouchStick's own default zone
		for id, m in made do place(id, m, work) end
		placeStick()
		showSize()
	end)
	for n = 1, 3 do
		slotBtns[n] = pillButton(tostring(n), 2 + n, function()
			if controller.OnSave then controller.OnSave(slot, json()) end -- keep the slot you were on
			slot = tostring(n)
			if controller.OnSlot then controller.OnSlot(slot) end
			-- the new slot's saved layout (or the defaults)
			local ok, saved = pcall(function() return HttpService:JSONDecode(setting("Touch Layout " .. slot, "") or "") end)
			for _, b in BUTTONS do
				local s = ok and type(saved) == "table" and saved[b.id]
				work[b.id] = type(s) == "table" and { x = s.x, y = s.y, s = s.s } or { x = b.x, y = b.y, s = b.s }
			end
			work.Joystick = ok and type(saved) == "table" and validStick(saved.Joystick) or nil
			for id, m in made do place(id, m, work) end
			placeStick()
			for k, sb in slotBtns do sb.BackgroundTransparency = k == n and 0 or 1; sb.TextColor3 = k == n and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end
		end)
	end
	for k, sb in slotBtns do sb.BackgroundTransparency = tostring(k) == slot and 0 or 1; sb.TextColor3 = tostring(k) == slot and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end
	gui.Enabled = true
end

function controller.IsEditing() return editing end

function controller.Start()
	build()
	-- respawn / focus lost: let go of everything
	player.CharacterAdded:Connect(function() local ia = actions() if ia and ia.ReleaseAll then ia.ReleaseAll() end end)
	UserInputService.WindowFocusReleased:Connect(function() local ia = actions() if ia and ia.ReleaseAll then ia.ReleaseAll() end end)
	-- refresh a few times a second (settings, combat state, ammo, Roblox's touch gui appearing late)
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if t < 0.2 then return end
		t = 0
		if not editing then refresh() end
	end)
	refresh()
	-- Studio only: PlayerScripts.TouchTest:Invoke(action, seconds) presses an action through the real input layer
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "TouchTest"
		hook.OnInvoke = function(action, seconds)
			local ia = actions()
			if not ia then return "no InputActions" end
			ia.Press(action)
			task.wait(seconds or 0.1)
			ia.Release(action)
			return "pressed " .. tostring(action)
		end
		hook.Parent = player:WaitForChild("PlayerScripts")
	end
end

return controller
