-- UIKit/PlayScreen (ModuleScript): the lobby PLAY screen, full screen like Missions / Settings (one menu at a time).
-- RIVALS' play screen as a TACTICALS deployment board: no AI art, every card is a 3D scene.
--   * DEPLOY header with your operator level, CASUAL / RANKED tabs (ranked shows a 3D lock until Config.RankedLevel).
--   * Three mode cards (1V1 / 2V2 / 3V3): your avatar holding your one gun, squad mates beside you, the other team as
--     dark silhouettes opposite. Click = search online; while searching that card says SEARCHING m:ss and click cancels.
--   * TRAINING (your gun on the rack, ENTER) and LOBBY DUELS (TO PADS) below.
-- Design px at 1920x1080, converted to Scale (Kit.toScale).
--   PlayScreen.Init({ Config, getData, ask, onOpen, onClose, enterTraining, toPads, rankedOpen, level })
--   PlayScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local Tac = require(UIKit:WaitForChild("Tac"))
local C, new = Theme.color, Kit.new
local T = Tac.C
local player = Players.LocalPlayer

-- (2026-10-21, Edward's font decision: Gotham / Montserrat read as AI-made) headings Oswald Bold, body Rubik (Theme.font)
local OSWALD = Theme.font.display
local BODY = Theme.font.medium
local BOLD = Theme.font.bold

local Screen = {}
local ctx = {}
local gui, root, body, blur, scrim
local isOpen = false
local chatWas
local tab = "Casual"
local strips = {} -- live status lines, updated every tick without rebuilding

-- (2026-10-18, live RIVALS party checks with Edward) the party: PartyMembers (JSON, leader first) + PartyLeader from LobbyParty
local function partyList()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PartyMembers") or "")
	return (ok and type(list) == "table") and list or {}
end
local function partyLeader(list) return player:GetAttribute("PartyLeader") or list[1] or player.UserId end
-- why this party can't take a queue of `teamSize` (RIVALS' "Whoops!" reasons), or nil
local function partyBlock(teamSize)
	local list = partyList()
	if #list <= 1 then return nil end
	if partyLeader(list) ~= player.UserId then return "Only the party leader can join a queue!" end
	if teamSize and #list > teamSize then return "This party is too big for this queue!" end
	for _, uid in list do
		local p = Players:GetPlayerByUserId(uid)
		if p and (p:GetAttribute("InDuel") == true or p:GetAttribute("DuelMatch") ~= nil) then
			return "A party member (@" .. p.Name .. ") is currently in a duel!"
		end
	end
	return nil
end
local function openParty()
	local mod = UIKit:FindFirstChild("PartyScreen")
	local ok, PS = pcall(require, mod)
	if ok and PS and PS.Open then Screen.Close(); PS.Open() end
end

local function label(parent, text, font, size, x, y, w, h, color, align, z)
	return Kit.label({ Text = text, FontFace = font, TextSize = size, TextColor3 = color or T.bone, TextXAlignment = align or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3, Parent = parent })
end
local function clockText(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end
local function counts()
	local ok, t = pcall(function() return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("MM_Counts") or "{}") end)
	return (ok and type(t) == "table") and t or {}
end
local function search()
	local q, st = player:GetAttribute("MM_Queue"), player:GetAttribute("MM_Status")
	if not (q and st) then return nil end
	return ctx.Config.QueueById(q), st, player:GetAttribute("MM_Since") or workspace:GetServerTimeNow()
end
local function onPad()
	-- PadUI hides the lobby HUD while you're on a pad; the Deploying attribute covers the rest
	return player:GetAttribute("QueueMode") ~= nil or player:GetAttribute("Deploying") == true
end

---------------------------------------------------------------------------------------------------- 3D scenes
-- a stripped, anchored copy of your character; tint = nil keeps your look, else a flat mannequin of that colour
local function rig(tint)
	local char = player.Character
	if not char then return nil end
	local was = char.Archivable
	char.Archivable = true
	local m = char:Clone()
	char.Archivable = was
	if not m then return nil end
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt") or d:IsA("ForceField") or d:IsA("Tool") or d:IsA("Highlight") then
			d:Destroy()
		elseif tint and (d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal") or d:IsA("SurfaceAppearance")) then
			d:Destroy()
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false; d.CastShadow = false
			if d.Name == "HumanoidRootPart" then d.Transparency = 1 end
			if tint then
				d.Color = tint; d.Material = Enum.Material.SmoothPlastic
				if d:IsA("MeshPart") then d.TextureID = "" end
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return m
end
-- your one gun in the right hand, barrel forward (low ready)
local function arm(m, weaponId)
	local hand = m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm")
	if not hand or not weaponId then return end
	local gun = ViewIcons.Weapon(weaponId)
	if not gun or #gun:GetChildren() == 0 then return end
	local _, size = gun:GetBoundingBox()
	-- the longest axis is the barrel: turn it to the rig's forward (-Z)
	local turn = CFrame.identity
	if size.X >= size.Y and size.X >= size.Z then turn = CFrame.Angles(0, math.rad(90), 0)
	elseif size.Y >= size.X and size.Y >= size.Z then turn = CFrame.Angles(math.rad(90), 0, 0) end
	local base = CFrame.new(hand.Position) * (m:GetPivot().Rotation)
	gun:PivotTo(base * CFrame.new(0, -0.15, -math.max(size.X, size.Y, size.Z) * 0.32) * turn)
	gun.Parent = m
end

-- the scene for a mode card: you (+ mates) on the left facing right, the other team on the right facing left
local function squadScene(parent, teamSize, ranked)
	local scene = Instance.new("Model")
	scene.Name = "Squad"
	local weapon = (ctx.getData() and ctx.getData().Loadout and ctx.getData().Loadout.Weapon) or ctx.Config.DefaultLoadout.Weapon
	local enemyTint = ranked and Color3.fromRGB(60, 46, 20) or Color3.fromRGB(34, 38, 32) -- (2026-10-21, AI-tells cleanup) ranked = dark gold, was violet
	local mateTint = Color3.fromRGB(120, 126, 108)
	local gap = 3.4
	-- the viewport camera looks from +Z towards -Z (screen right = -X), rigs face -Z by default:
	-- your team at +X (screen left) turned towards the other team and the camera, theirs mirrored
	for side = 0, 1 do
		for i = 1, teamSize do
			local tint
			if side == 1 then tint = enemyTint elseif i > 1 then tint = mateTint end
			local m = rig(tint)
			if not m then break end
			local x = (side == 0 and 1 or -1) * (2.6 + (i - 1) * gap)
			local z = -(i - 1) * 2.2 -- mates stand a step back
			local yaw = side == 0 and math.rad(125) or math.rad(-125)
			m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0))
			if side == 0 and i == 1 then arm(m, weapon) end
			m.Name = side == 0 and ("Mate" .. i) or ("Enemy" .. i) -- (2026-10-21, round 3) named so the hover hop finds your team
			m.Parent = scene
		end
	end
	if #scene:GetChildren() == 0 then scene:Destroy(); return nil end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(math.rad(-6), 0, 0), zoom = ({ 1.1, 1.4, 1.45 })[teamSize] or 1.6, still = true })
	return vp, scene
end

---------------------------------------------------------------------------------------------------- live scenes
-- (2026-10-21, round 3: match RIVALS) RIVALS' play tiles are moving art; ours are live 3D scenes that react. On hover (or a
-- controller's selection) the camera eases in and turns a touch, and the scene's step(t, h, since) runs every frame
-- (h = 0..1 hover ease, since = seconds since the hover began: hops / hit wobbles). Runs only while its ScreenGui is on.
local function liven(vp, target, push, step)
	if not vp then return end
	local cam = vp.Frame.CurrentCamera
	local base = cam.CFrame
	local dist = base.Position.Magnitude
	local hover, h, kick = false, 0, -100
	local function set(on) if on and not hover then kick = os.clock() end hover = on end
	-- (the target can outlive the scene, e.g. RankedScreen's cards: these go when the viewport does)
	local conns = {
		target.MouseEnter:Connect(function() set(true) end),
		target.MouseLeave:Connect(function() set(false) end),
		target.SelectionGained:Connect(function() set(true) end),
		target.SelectionLost:Connect(function() set(false) end),
	}
	local sg = vp.Frame:FindFirstAncestorOfClass("ScreenGui")
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Frame.Parent then
			conn:Disconnect()
			for _, c in conns do c:Disconnect() end
			return
		end
		if sg and not sg.Enabled then return end
		h += ((hover and 1 or 0) - h) * math.min(1, dt * 9)
		cam.CFrame = CFrame.Angles(0, h * 0.07, 0) * base * CFrame.new(0, 0, -h * dist * (push or 0.1))
		if step then step(os.clock(), h, os.clock() - kick) end
	end)
end
-- a one-shot hop: 0 -> up -> 0 over 0.32 s, starting `delay` s after the hover began
local function hop(since, delay, height)
	local u = (since - (delay or 0)) / 0.32
	if u <= 0 or u >= 1 then return 0 end
	return math.sin(u * math.pi) * (height or 0.9)
end
-- your team hops one after another when the tile is hovered (the other team stays put)
local function livenSquad(vp, scene, target)
	if not (vp and scene) then return end
	local mates = {}
	for _, m in scene:GetChildren() do
		local i = tonumber(m.Name:match("^Mate(%d+)$"))
		if i and m:IsA("Model") then table.insert(mates, { m = m, base = m:GetPivot(), d = (i - 1) * 0.08 }) end
	end
	liven(vp, target, 0.1, function(_, _, since)
		if since > 1.2 then return end
		for _, e in mates do e.m:PivotTo(e.base + Vector3.new(0, hop(since, e.d, 0.9), 0)) end
	end)
end

-- small anchored parts for the placeholder scenes (no collisions, no shadows)
local function part(m, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = m
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) -> vertical
local FACING = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) -> toward the camera
local SAND, OLIVE_D = Color3.fromRGB(176, 156, 112), Color3.fromRGB(98, 108, 62)
local RING_RED, RING_CREAM, WOOD = Color3.fromRGB(200, 60, 48), Color3.fromRGB(236, 230, 210), Color3.fromRGB(110, 84, 50)
-- a blocky stand-in figure (when there is no character to copy); pivot = the torso, feet 3 studs below it (like a rig's root)
local function blockFigure(cf, color)
	local m = Instance.new("Model")
	local torso = part(m, Vector3.new(2, 2, 1), cf, color)
	part(m, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 1.65, 0), color:Lerp(Color3.new(1, 1, 1), 0.15))
	for _, s in { -1, 1 } do
		part(m, Vector3.new(1, 2, 1), cf * CFrame.new(s * 1.5, 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.15))
		part(m, Vector3.new(1, 2, 1), cf * CFrame.new(s * 0.5, -2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3))
	end
	m.PrimaryPart = torso
	return m
end
local function loadoutWeapon()
	local d = ctx.getData and ctx.getData()
	return (d and d.Loadout and d.Loadout.Weapon) or (ctx.Config and ctx.Config.DefaultLoadout and ctx.Config.DefaultLoadout.Weapon)
end

-- (2026-10-21, round 3: match RIVALS) Training: RIVALS shows art here; ours is a live range scene. A straw target dummy on a
-- post with rings on its chest, a sandbag wall in front with your gun resting on it, a round target board behind. The dummy
-- sways, and rocks back as if hit when you hover.
local function trainingScene(parent, target)
	local scene = Instance.new("Model")
	scene.Name = "Range"
	part(scene, Vector3.new(14, 0.4, 9), CFrame.new(0, -0.2, 2), Color3.fromRGB(62, 66, 56), Enum.Material.Concrete) -- floor slab
	-- sandbag wall (screen left = +X, near the camera): three staggered rows of squashed spheres
	for r, xs in { { -1.8, -0.6, 0.6, 1.8 }, { -1.2, 0, 1.2 }, { -0.6, 0.6 } } do
		for k, x in xs do
			local bag = part(scene, Vector3.new(1.3, 0.75, 0.95), CFrame.new(2.6 + x, 0.35 + (r - 1) * 0.62, -1.6) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 3 or -3)),
				(r + k) % 2 == 0 and SAND or SAND:Lerp(OLIVE_D, 0.35), Enum.Material.Fabric)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = bag
		end
	end
	-- your gun resting on the wall, laid along X (towards the dummy)
	local weapon = loadoutWeapon()
	local gun = weapon and ViewIcons.Weapon(weapon)
	if gun and #gun:GetChildren() > 0 then
		local bb, size = gun:GetBoundingBox()
		gun.WorldPivot = CFrame.new(bb.Position)
		local turn = CFrame.identity -- the longest axis is the barrel
		if size.Z >= size.X and size.Z >= size.Y then turn = CFrame.Angles(0, math.rad(90), 0)
		elseif size.Y >= size.X and size.Y >= size.Z then turn = CFrame.Angles(0, 0, math.rad(90)) end
		pcall(function() gun:ScaleTo(math.clamp(3.2 / math.max(size.X, size.Y, size.Z, 0.1), 0.4, 2)) end)
		gun:PivotTo(CFrame.new(2.6, 2.1, -1.7) * turn)
		gun.Parent = scene
	elseif gun then
		gun:Destroy()
	end
	-- the target dummy on a post (screen right = -X, further back), rings facing the camera
	local dummy = Instance.new("Model")
	dummy.Name = "Dummy"
	local foot = CFrame.new(-2.4, 0, 2.6)
	local base = part(dummy, Vector3.new(0.5, 2.2, 2.2), foot * CFrame.new(0, 0.25, 0) * UPRIGHT, Color3.fromRGB(46, 50, 56), Enum.Material.Metal, Enum.PartType.Cylinder)
	base.Name = "Base"
	part(dummy, Vector3.new(1.6, 0.35, 0.35), foot * CFrame.new(0, 1.2, 0) * UPRIGHT, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	local straw = Color3.fromRGB(196, 170, 112)
	part(dummy, Vector3.new(2, 2.2, 1.1), foot * CFrame.new(0, 3, 0), straw, Enum.Material.Fabric)
	part(dummy, Vector3.new(1.25, 1.25, 1.25), foot * CFrame.new(0, 4.75, 0), straw:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Fabric, Enum.PartType.Ball)
	part(dummy, Vector3.new(3.6, 0.5, 0.5), foot * CFrame.new(0, 3.6, 0), straw:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric) -- arms out
	for i, ring in { { 1.7, RING_RED }, { 1.15, RING_CREAM }, { 0.6, RING_RED } } do
		part(dummy, Vector3.new(0.06, ring[1], ring[1]), foot * CFrame.new(0, 3.05, -0.57 - i * 0.02) * FACING, ring[2], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	dummy.Parent = scene
	-- a round target board on legs, back left (depth)
	local board = CFrame.new(4.6, 0, 5.2)
	for _, s in { -1, 1 } do
		part(scene, Vector3.new(0.25, 3.2, 0.25), board * CFrame.new(s * 0.9, 1.6, 0.3) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, Enum.Material.Wood)
	end
	for i, ring in { { 2.6, RING_CREAM }, { 1.8, RING_RED }, { 1.0, RING_CREAM }, { 0.45, RING_RED } } do
		part(scene, Vector3.new(0.08, ring[1], ring[1]), board * CFrame.new(0, 3.2, -i * 0.02) * FACING, ring[2], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(math.rad(-10), math.rad(-14), 0), zoom = 1.15, still = true })
	-- the dummy rocks about its foot (read back after the viewport re-centred and turned the scene)
	local home = base.CFrame * UPRIGHT:Inverse() * CFrame.new(0, -0.25, 0)
	dummy.WorldPivot = home
	liven(vp, target, 0.08, function(t, _, since)
		local hit = since < 1.6 and math.exp(-since * 3.5) * math.sin(since * 16) * 0.22 or 0
		dummy:PivotTo(home * CFrame.Angles(math.sin(t * 1.7) * 0.035 + hit, 0, math.sin(t * 1.1) * 0.02))
	end)
	return vp
end

-- (2026-10-21, round 3: match RIVALS) Lobby Duels: two fighters squaring up on a duel pad (you with your gun, the other a
-- dark mannequin) over a field-green glow ring that breathes; both hop when you hover.
local function duelsScene(parent, target)
	local scene = Instance.new("Model")
	scene.Name = "Pad"
	local FEET = -3 -- a rig's pivot is its root, about 3 studs above its feet
	part(scene, Vector3.new(0.6, 11, 11), CFrame.new(0, FEET - 0.3, 0) * UPRIGHT, Color3.fromRGB(46, 50, 56), Enum.Material.Metal, Enum.PartType.Cylinder)
	local ring = part(scene, Vector3.new(0.4, 12, 12), CFrame.new(0, FEET - 0.45, 0) * UPRIGHT, C.field, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(scene, Vector3.new(0.62, 3, 3), CFrame.new(0, FEET - 0.29, 0) * UPRIGHT, Color3.fromRGB(28, 30, 26), Enum.Material.Metal, Enum.PartType.Cylinder) -- centre mark
	local weapon = loadoutWeapon()
	local fighters = {}
	for side = 0, 1 do
		local tint = side == 1 and Color3.fromRGB(34, 38, 32) or nil
		local cf = CFrame.new(side == 0 and 2.8 or -2.8, 0, 0) * CFrame.Angles(0, side == 0 and math.rad(115) or math.rad(-115), 0)
		local m = rig(tint)
		if m then
			m:PivotTo(cf)
			if side == 0 then arm(m, weapon) end
		else
			m = blockFigure(cf, tint or Color3.fromRGB(150, 140, 110))
		end
		m.Parent = scene
		table.insert(fighters, m)
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(math.rad(-14), 0, 0), zoom = 1.12, still = true })
	local homes = {}
	for i, m in fighters do homes[i] = m:GetPivot() end
	liven(vp, target, 0.1, function(t, _, since)
		ring.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 2.6))
		if since > 1.2 then return end
		for i, m in fighters do m:PivotTo(homes[i] + Vector3.new(0, hop(since, (i - 1) * 0.1, 0.9), 0)) end
	end)
	return vp
end

-- (2026-10-21, round 3) for RankedScreen's mode cards: the same live squad as the Play tiles (nil until Play is set up)
function Screen.SquadScene(parent, teamSize, ranked, hoverTarget)
	if not (ctx.Config and ctx.getData) then return nil end
	local vp, scene = squadScene(parent, teamSize, ranked)
	if hoverTarget then livenSquad(vp, scene, hoverTarget) end
	return vp
end

---------------------------------------------------------------------------------------------------- building
local tickNow -- set below (status refresh)

-- (Edward 2026-10-16: no "4 corners box" look) RIVALS-style cards: rounded dark glass
-- (2026-10-21, AI-tells cleanup) the faint 2 px edge stroke is gone; the dark gradient fill separates the card (returns no stroke)
local function edge(f, accent, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = f })
	return nil
end
local function plate(parent, x, y, w, h, accent)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.gunDeep, BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = parent })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(38, 42, 34), Color3.fromRGB(10, 12, 9)), Parent = f })
	return f, edge(f, accent)
end

-- (UI session 2026-10-16, remade on RIVALS' play screen, ref_04): a tight grid of big mode tiles (the mode name huge
-- and centred over its 3D squad scene), a tall Ranked tile on the right (locked: padlock + "Unlocked at Level N"; open:
-- click to switch the modes to ranked), Training and Lobby Duels under the modes, the red X top right. No header.
-- (2026-10-21, AI-tells cleanup) was Builder Sans: big words / numbers in Oswald Bold, the small lines in Rubik SemiBold
local HEAVY = OSWALD
local SEMI = BOLD
local function big(parent, text, size, x, y, w, h, color, align, z, font)
	local l = Kit.label({ Text = text, FontFace = font or HEAVY, TextSize = size, TextColor3 = color or Color3.new(1, 1, 1), TextXAlignment = align or Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 4, Parent = parent })
	new("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = math.max(2, math.floor(size / 28)), Transparency = 0.15, Parent = l })
	return l
end
-- (2026-10-21, RIVALS pass) tiles pop in one after another when the screen opens (setOpen sets popStep = 0; nil = no pop,
-- so a tab switch / party change re-render stays still). popIn runs before bindButton, which then reuses its UIScale.
local popStep
local function tile(x, y, w, h, top, bottom)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top or Color3.fromRGB(58, 64, 54), bottom or Color3.fromRGB(14, 16, 13)), Parent = f })
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	local st = new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	f.MouseEnter:Connect(function() Kit.tween(st, 0.1, { Transparency = 0.15 }) end)
	f.MouseLeave:Connect(function() Kit.tween(st, 0.1, { Transparency = 1 }) end)
	if popStep then Kit.popIn(f, popStep * 0.04); popStep += 1 end
	return f
end

-- (2026-10-21, RIVALS pass) locked Ranked: a centred requirement card instead of a toast.
-- (2026-10-21, round 3: match RIVALS t0285.4-t0289) remade on RIVALS' card: a dark card with the big title, one line per
-- requirement (the words left, an "n / N" count right that counts up, a full-width bar under it; a met line turns into a
-- field-green bar with a green tick), a short "how" hint, the greyed PLAY BELOW the card and the red X beside its top right
-- corner. Card, X and PLAY pop in together (one group). Solid fills, no outlines; Oswald / Rubik. Built in design px inside a
-- full-screen shade, converted with Kit.toScale before it shows.
local lockShade
local function drawTick(parent, x, y, z)
	local hold = new("Frame", { Name = "Tick", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(40, 40), ZIndex = z, Parent = parent })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 25), Size = UDim2.fromOffset(9, 20), Rotation = -45, BackgroundColor3 = C.field,
		BorderSizePixel = 0, ZIndex = z, Parent = hold })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(25, 19), Size = UDim2.fromOffset(9, 36), Rotation = 40, BackgroundColor3 = C.field,
		BorderSizePixel = 0, ZIndex = z, Parent = hold })
	return hold
end
local function showLockCard()
	local Config = ctx.Config
	local lv = math.max(0, (ctx.level and ctx.level()) or 0)
	local need = math.max(1, Config.RankedLevel)
	if lockShade then lockShade:Destroy() end
	-- the server's only ranked gate is the account level (LobbyConfig.CanRanked), so that is the one line we list
	local reqs = { { text = "Reach Level " .. need, cur = lv, goal = need } }
	local W, ROW = 700, 76
	local CH = 112 + #reqs * ROW + 58
	local PW, PH = 300, 80
	local GH = CH + 22 + PH + 8
	local shade = new("TextButton", { Name = "RankedLock", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, ZIndex = 20, Parent = root })
	lockShade = shade
	local group = new("Frame", { Name = "Group", BackgroundTransparency = 1, Position = UDim2.fromOffset((1920 - W) / 2, (1080 - GH) / 2), Size = UDim2.fromOffset(W + 120, GH),
		ZIndex = 21, Parent = shade })
	local card = new("Frame", { Name = "Card", Active = true, Size = UDim2.fromOffset(W, CH), BackgroundColor3 = Color3.fromRGB(8, 9, 7), BackgroundTransparency = 0.08,
		BorderSizePixel = 0, ZIndex = 21, Parent = group }, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local white = Color3.new(1, 1, 1)
	big(card, "RANKED", 76, 0, 14, W, 90, white, nil, 22, Theme.font.display)
	local anims = {}
	for i, r in reqs do
		local y = 112 + (i - 1) * ROW
		local met = r.cur >= r.goal
		Kit.label({ Text = r.text, FontFace = BOLD, TextSize = 30, TextColor3 = Color3.fromRGB(228, 228, 232), Position = UDim2.fromOffset(48, y), Size = UDim2.fromOffset(440, 40),
			ZIndex = 22, Parent = card })
		local count
		if met then
			drawTick(card, W - 88, y, 23)
		else
			count = big(card, "0 / " .. r.goal, 32, W - 268, y, 220, 40, white, Enum.TextXAlignment.Right, 22, Theme.font.display)
		end
		local track = new("Frame", { Position = UDim2.fromOffset(48, y + 46), Size = UDim2.fromOffset(W - 96, 9), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
			BorderSizePixel = 0, ZIndex = 22, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = met and C.field or white, BorderSizePixel = 0, ZIndex = 23, Parent = track },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		table.insert(anims, { fill = fill, frac = met and 1 or math.clamp(r.cur / r.goal, 0.03, 1), count = count, cur = math.min(r.cur, r.goal), goal = r.goal })
	end
	-- what to do next (kids: the card says how, not only what)
	Kit.label({ Text = "Play matches and finish missions to level up!", FontFace = BODY, TextSize = 23, TextColor3 = Color3.fromRGB(190, 190, 196),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, CH - 52), Size = UDim2.fromOffset(W, 32), ZIndex = 22, Parent = card })
	-- the greyed PLAY under the card (RIVALS' grey button): a chunky grey gradient on a darker offset block; it shakes when pressed
	new("Frame", { Name = "PlayLip", Position = UDim2.fromOffset((W - PW) / 2, CH + 30), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = Color3.fromRGB(70, 72, 78),
		BorderSizePixel = 0, ZIndex = 21, Parent = group }, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local playBtn = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((W - PW) / 2, CH + 22), Size = UDim2.fromOffset(PW, PH),
		BackgroundColor3 = white, BorderSizePixel = 0, ZIndex = 22, Parent = group }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.gradient.grey[1], Theme.gradient.grey[2]) }),
	})
	big(playBtn, "PLAY", 46, 0, 0, PW, PH, white, nil, 23, Theme.font.display)
	local x = Kit.closeButton(UDim2.fromOffset(96, 50))
	x.Position = UDim2.fromOffset(W + 16, 0)
	x.ZIndex = 23
	x.Parent = group
	Kit.toScale(shade, Vector2.new(1920, 1080))
	local function hide()
		if lockShade == shade then lockShade = nil end
		Kit.close(group, function() shade:Destroy() end)
	end
	x.Activated:Connect(hide)
	shade.Activated:Connect(hide)
	Kit.bindButton(playBtn, { hover = 1.03, press = 0.95 })
	local shaking = false
	playBtn.Activated:Connect(function()
		if shaking then return end -- (a second shake mid-way would start from a moved spot)
		shaking = true
		Kit.shake(playBtn)
		task.delay(0.25, function() shaking = false end)
	end)
	Kit.open(group)
	for _, a in anims do
		Kit.fillTo(a.fill, a.frac, 0.6)
		if a.count then Kit.countTo(a.count, 0, a.cur, 0.6, function(n) return math.floor(n + 0.5) .. " / " .. a.goal end) end
	end
end

local MW, MH, GAP = 322, 272, 8
local STRIP = 58 -- (lobby revamp) the bottom action bar of every tile
local function modeCard(i, mode, ranked, x)
	local q = ctx.Config.QueueFor(mode.Id, ranked)
	local accent = ranked and T.violet or Color3.fromRGB(236, 232, 218)
	-- (2026-10-21, AI-tells cleanup) the ranked tile gradient is dark gold, was violet
	local card = ranked and tile(x, 0, MW, MH, Color3.fromRGB(110, 84, 38), Color3.fromRGB(38, 28, 12)) or tile(x, 0, MW, MH)
	local stage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(MW, 210), ZIndex = 2, Parent = card })
	-- the mode name, huge and centred (RIVALS)
	big(card, mode.Id, 96, 0, 70, MW, 110, Color3.new(1, 1, 1), nil, 4)
	if ranked then
		local chip = new("TextLabel", { Text = "RANKED", FontFace = HEAVY, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = T.violet,
			Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(94, 26), ZIndex = 5, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	end
	-- status strip along the bottom. (lobby revamp, graders: "Play >" in 22 px read as a small link, not the button) idle = a
	-- full-width field-green PLAY bar, so the whole card reads as one big button; the queue count is a pill top right
	local strip = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(MW, STRIP), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ZIndex = 3, Parent = card })
	local green = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)), Enabled = false, Parent = strip })
	local left = Kit.label({ Text = "", FontFace = HEAVY, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(MW - 28, STRIP), ZIndex = 4, Parent = strip })
	new("UIStroke", { Color = Color3.fromRGB(28, 44, 16), Thickness = 2, Transparency = 0.3, Parent = left })
	local right = Kit.label({ Text = "", FontFace = SEMI, TextSize = 20, TextColor3 = Color3.fromRGB(225, 225, 228), TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(MW - 214, 0), Size = UDim2.fromOffset(200, STRIP), ZIndex = 4, Parent = strip })
	local pill = new("TextLabel", { Text = "", FontFace = HEAVY, TextSize = 19, TextColor3 = Color3.fromRGB(225, 225, 228), BackgroundColor3 = Color3.fromRGB(10, 12, 9),
		BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(MW - 12, 12), Size = UDim2.fromOffset(150, 30), ZIndex = 5, Parent = card },
		{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	table.insert(strips, { q = q, left = left, right = right, strip = strip, green = green, pill = pill, card = card, ranked = ranked, mode = mode, accent = accent })
	Kit.bindButton(card, { hover = 1.03, press = 0.985 })
	card.Activated:Connect(function()
		local myQ, st = search()
		if myQ and q and myQ.Id == q.Id and st == "Searching" then ctx.ask("CancelMatch"); return end
		if myQ or onPad() or not q then return end
		local why = partyBlock(mode.TeamSize)
		if why then Kit.whoops(why) return end
		local r = ctx.ask("FindMatch", q.Id)
		if r and r.ok then Screen.Close(); return end
		-- say why on the tile itself (the lobby toasts sit under this menu)
		local msg = r and r.msg or "No answer from the server"
		if msg == "Unknown action" then msg = "Online matchmaking is offline here" end
		local entry
		for _, e in strips do if e.card == card then entry = e end end
		if entry then entry.flash = { text = msg, untilT = os.clock() + 5 } end
		tickNow()
	end)
	return stage, mode.TeamSize, card
end

local function render()
	strips = {}
	for _, ch in body:GetChildren() do ch:Destroy() end
	local Config = ctx.Config
	local open = ctx.rankedOpen and ctx.rankedOpen()
	if not open then tab = "Casual" end
	local ranked = tab == "Ranked"
	local stages = {}
	for i, mode in Config.Modes do
		local stage, n, card = modeCard(i, mode, ranked, (i - 1) * (MW + GAP))
		table.insert(stages, { stage, n, card })
	end
	-- Ranked: the tall tile on the right
	local RX = 3 * (MW + GAP)
	local RW, RH = 1404 - RX, MH * 2 + GAP
	-- (2026-10-21, AI-tells cleanup) the open Ranked tile gradient is dark gold, was violet
	-- (2026-10-21, round 3: match RIVALS) locked = a dimmer dark gold (was purple-grey 40,36,48 -> 10,9,13): Ranked keeps its
	-- colour while locked, like RIVALS' Ranked tile keeps its art behind the padlock (t0291)
	local rt = tile(RX, 0, RW, RH, open and Color3.fromRGB(110, 84, 38) or Color3.fromRGB(84, 64, 30), open and Color3.fromRGB(38, 28, 12) or Color3.fromRGB(24, 18, 8))
	big(rt, "Ranked", 72, 0, 36, RW, 84)
	local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(RW / 2, 150), Size = UDim2.fromOffset(230, 230), ZIndex = 3, Parent = rt })
	local rankedSub
	if not open then
		big(rt, "UNLOCKS AT LEVEL " .. Config.RankedLevel, 30, 20, 392, RW - 40, 40, Color3.fromRGB(225, 225, 230))
		-- (lobby revamp, graders: a bare lock gives no sense of distance) how far you are: LV n / 50 on a bar
		local lv = math.max(1, (ctx.level and ctx.level()) or 1)
		local need = math.max(1, Config.RankedLevel)
		local track = new("Frame", { Position = UDim2.fromOffset(30, 446), Size = UDim2.fromOffset(RW - 60, 18), BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 4, Parent = rt }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("Frame", { Size = UDim2.fromScale(math.clamp(lv / need, 0.04, 1), 1), BackgroundColor3 = Color3.fromRGB(232, 212, 168), BorderSizePixel = 0, ZIndex = 5, Parent = track },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		big(rt, "LV " .. lv .. " / " .. need, 24, 20, 470, RW - 40, 30, Color3.fromRGB(232, 212, 168))
	else
		rankedSub = big(rt, ranked and "Ranked queues: ON" or "Ranked queues: OFF", 34, 20, 392, RW - 40, 44, ranked and T.violet:Lerp(Color3.new(1, 1, 1), 0.4) or Color3.new(1, 1, 1))
		Kit.label({ Text = ranked and "Click to go back to casual" or "Click to play rated duels", FontFace = SEMI, TextSize = 20, TextColor3 = Color3.fromRGB(205, 205, 212),
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 440), Size = UDim2.fromOffset(RW - 40, 28), ZIndex = 4, Parent = rt })
	end
	Kit.bindButton(rt, { hover = 1.02, press = 0.985 })
	rt.Activated:Connect(function()
		if not open then
			showLockCard() -- (2026-10-21, RIVALS pass) was a toast
			return
		end
		-- (2026-10-17) ranked has its own page now (UIKit.RankedScreen); the old in-place switch stays as the fallback
		if ctx.openRanked then ctx.openRanked() return end
		tab = ranked and "Casual" or "Ranked"
		render()
	end)
	-- row 2: Training (wide) + Lobby Duels
	local Y2 = MH + GAP
	local TW = 2 * MW + GAP
	local tb = tile(0, Y2, TW, MH)
	big(tb, "Training", 64, 28, 26, 420, 76, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	-- (2026-10-21, round 3) shorter lines, bigger type (kids; RIVALS keeps a card to one short line)
	Kit.label({ Text = "Cover, vaults, targets.\nTry any gun for free!", FontFace = SEMI, TextSize = 24, TextColor3 = Color3.fromRGB(215, 215, 220),
		Position = UDim2.fromOffset(32, 104), Size = UDim2.fromOffset(330, 60), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4, Parent = tb })
	-- (lobby revamp) the same green bottom bar as the mode tiles
	local tBar = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(TW, STRIP), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = tb },
		{ new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)) }) })
	local tStatus = big(tBar, "ENTER", 30, 0, 0, TW, STRIP, Color3.new(1, 1, 1))
	local gunHold = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(330, 20), Size = UDim2.fromOffset(320, 232), ZIndex = 2, Parent = tb })
	Kit.bindButton(tb, { hover = 1.02, press = 0.985 })
	tb.Activated:Connect(function()
		if search() or onPad() then return end
		Screen.Close()
		if ctx.enterTraining then ctx.enterTraining() end
	end)
	table.insert(strips, { training = tStatus })
	local db = tile(TW + GAP, Y2, MW, MH)
	-- (2026-10-21, round 3: match RIVALS) a live duel-pad scene behind the words, where RIVALS shows art
	local padHold = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(MW, MH - STRIP), ZIndex = 2, Parent = db })
	big(db, "Lobby Duels", 52, 0, 8, MW, 66) -- (round 3) one line along the top, so the fighters show under it
	Kit.label({ Text = "Fight people in this server", FontFace = SEMI, TextSize = 19, TextColor3 = Color3.fromRGB(215, 215, 220), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 172), Size = UDim2.fromOffset(MW, 26), ZIndex = 4, Parent = db })
	-- secondary action: a dark bar (PLAY-green is for the queues)
	local dBar = new("Frame", { Position = UDim2.fromOffset(0, MH - STRIP), Size = UDim2.fromOffset(MW, STRIP), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ZIndex = 3, Parent = db })
	big(dBar, "TO PADS", 28, 0, 0, MW, STRIP)
	Kit.bindButton(db, { hover = 1.03, press = 0.985 })
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
	-- the party column, bottom left (RIVALS): the leader at the bottom with the crown, the others stacked above, a + on top;
	-- any of them opens Your Party
	local old = root:FindFirstChild("PartyColumn")
	if old then old:Destroy() end
	local colF = new("Frame", { Name = "PartyColumn", BackgroundTransparency = 1, Position = UDim2.fromOffset(84, 560), Size = UDim2.fromOffset(110, 500), Parent = root })
	local list = partyList()
	if #list == 0 then list = { player.UserId } end
	local leader = partyLeader(list)
	local order = { leader }
	for _, uid in list do if uid ~= leader then table.insert(order, uid) end end
	local y = 500
	for i, uid in order do
		local d = i == 1 and 100 or 80
		y -= d + 8
		local h = new("ImageButton", { Name = "Head" .. i, AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(26, 28, 24), BackgroundTransparency = 0.2,
			Position = UDim2.fromOffset((110 - d) / 2, y), Size = UDim2.fromOffset(d, d), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		h:AddTag("Nonapplicable")
		task.spawn(function()
			local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok then h.Image = im end
		end)
		if i == 1 and #list > 1 then Kit.crown(h, UDim2.fromScale(0.78, 0.12), UDim2.fromScale(0.55, 0.42), 6) end
		Kit.bindButton(h, { hover = 1.06 })
		h.Activated:Connect(openParty)
	end
	if #list < 5 then
		y -= 72
		local plus = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(26, 28, 24), BackgroundTransparency = 0.3,
			Position = UDim2.fromOffset(19, y), Size = UDim2.fromOffset(72, 72), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		plus:AddTag("Nonapplicable")
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 8), BackgroundColor3 = Color3.fromRGB(200, 200, 205), BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 30), BackgroundColor3 = Color3.fromRGB(200, 200, 205), BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		Kit.bindButton(plus, { hover = 1.08 })
		plus.Activated:Connect(openParty)
	end
	Kit.toScale(root)
	-- 3D after the conversion (viewports fill their holders)
	-- (2026-10-21, round 3: match RIVALS) the squads react: your team hops and the camera leans in on hover
	for _, sc in stages do
		local vp, scene = squadScene(sc[1], sc[2], ranked)
		livenSquad(vp, scene, sc[3])
	end
	-- (2026-10-21, round 3: match RIVALS) Training / Lobby Duels: live placeholder scenes where RIVALS shows art (was your gun alone)
	trainingScene(gunHold, tb)
	duelsScene(padHold, db)
	local icons = ReplicatedStorage:FindFirstChild("UIIcons")
	if not open then
		local mesh = icons and icons:FindFirstChild("Lock")
		-- (2026-10-21, round 3) the padlock sways and turns to you on hover (it only swayed)
		local lockVp = mesh and ViewIcons.Viewport(art, mesh:Clone(), { view = CFrame.Angles(math.rad(8), math.rad(-20), 0), zoom = 1.05 })
		if lockVp then
			rt.MouseEnter:Connect(function() lockVp.SetHover(true) end)
			rt.MouseLeave:Connect(function() lockVp.SetHover(false) end)
		end
	else
		ViewIcons.Icon(art, "Trophy", { hoverTarget = rt })
	end
end

-- status lines only (every half second while open)
local function tick()
	local cnt = counts()
	local myQ, st, since = search()
	local pad = onPad()
	for _, s in strips do
		if s.training then
			s.training.Text = (myQ or pad) and "UNAVAILABLE WHILE QUEUED" or "ENTER"
		else
			local n = s.q and cnt[s.q.Id] or 0
			local mine = myQ and s.q and myQ.Id == s.q.Id
			s.green.Enabled = false
			s.left.TextXAlignment = Enum.TextXAlignment.Left
			s.pill.Visible = false
			if s.flash and os.clock() < s.flash.untilT then
				s.left.Text = s.flash.text
				s.right.Text = ""
				s.strip.BackgroundColor3 = T.red
				s.strip.BackgroundTransparency = 0.1
			elseif mine and st == "Searching" then
				s.left.Text = "Searching  " .. clockText(workspace:GetServerTimeNow() - since)
				s.right.Text = "Click to cancel"
				s.strip.BackgroundColor3 = Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = 0.1
			elseif mine then
				s.left.Text = "Match found!"
				s.right.Text = ""
				s.strip.BackgroundColor3 = Color3.fromRGB(141, 191, 90)
				s.strip.BackgroundTransparency = 0.1
			elseif myQ or pad then
				s.left.Text = myQ and ("Searching " .. myQ.Mode) or "On a lobby pad"
				s.right.Text = ""
				s.strip.BackgroundColor3 = Color3.new(0, 0, 0)
				s.strip.BackgroundTransparency = 0.35
			else
				s.left.Text = "PLAY"
				s.left.TextXAlignment = Enum.TextXAlignment.Center
				s.green.Enabled = not s.ranked
				s.pill.Visible = true
				s.pill.Text = n .. " SEARCHING"
				s.pill.TextColor3 = n > 0 and Color3.fromRGB(170, 220, 120) or Color3.fromRGB(225, 225, 228)
				local extra = ""
				if s.ranked then
					local player = game:GetService("Players").LocalPlayer
					extra = "  ·  " .. (function()
				local placed, need = player:GetAttribute("RankPlaced") or 0, player:GetAttribute("RankPlacements") or 0
				if need > 0 and placed < need then return "Placements " .. placed .. "/" .. need end
				return (player:GetAttribute("RankName") or "Bronze 1") .. "  " .. tostring(player:GetAttribute("RankElo") or 100) .. " ELO"
			end)()
				end
				s.right.Text = s.ranked and (extra:gsub("^  ·  ", "")) or ""
				if s.ranked then s.left.TextXAlignment = Enum.TextXAlignment.Left end
				s.strip.BackgroundColor3 = s.ranked and T.violet or Color3.new(1, 1, 1)
				s.strip.BackgroundTransparency = s.ranked and 0.25 or 0
			end
		end
	end
end

tickNow = function() if isOpen then tick() end end

local function header() end -- (no header row since the RIVALS remake)

local function build()
	gui = new("ScreenGui", { Name = "PlayUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local close = Kit.closeButton(UDim2.fromOffset(112, 58))
	close.Position = UDim2.fromOffset(1672, 140) -- (lobby revamp Phase B: docked against the grid corner)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(258, 140), Size = UDim2.fromOffset(1404, 560), Parent = root })
	root.Visible = false
	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
	task.spawn(function()
		while gui.Parent do
			if isOpen then tick() end
			task.wait(0.5)
		end
	end)
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	-- the chat window steps aside while the menu is open (it covers the top left and eats clicks)
	pcall(function()
		local cw = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
		if not cw then return end
		if on then chatWas = cw.Enabled; cw.Enabled = false elseif chatWas ~= nil then cw.Enabled = chatWas; chatWas = nil end
	end)
	if on then
		gui.Enabled = true
		header()
		popStep = 0 -- (2026-10-21, RIVALS pass) tiles pop in on open only
		render()
		popStep = nil
		tick()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
	else
		if lockShade then lockShade:Destroy(); lockShade = nil end
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

function Screen.Init(context)
	ctx = context or {}
	if not gui then build() end
	for _, a in { "PartyMembers", "PartyLeader" } do
		player:GetAttributeChangedSignal(a):Connect(function() if isOpen then render() end end)
	end
end
function Screen.Open() setOpen(true) end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end
function Screen.Refresh() if isOpen then header(); tick() end end

return Screen
