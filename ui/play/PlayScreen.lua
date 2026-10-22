-- UIKit/PlayScreen (ModuleScript): the lobby PLAY screen, full screen like Missions / Settings (one menu at a time).
-- (2026-10-21, RIVALS 1:1) ported from the RIVALS replica (rivals_practice/ui/play/PlayController.client.lua) and the live
-- capture notes/ui_rivals/grade2/rivals_play.png: RIVALS' content column (x 258, y 139, 1406 wide, scrolls), a tall hero tile
-- (Training, 416 x 555) on the left, 1v1 / 2v2 / 3v3 (323 x 274) on top and Duel Pads + Ranked (488 x 274) below, 7 px gutter,
-- 6 px corners. Every tile IS the button: a full-bleed live 3D scene under RIVALS' black shade with ONE huge white Rubik
-- ExtraBold title centred (soft shadow stroke); hover = picture brightens + white 4 px outline + 0.97 shrink. The red X
-- (112 x 58) sits right of the column at RIVALS' 1704,136; the menu grows open with Rivals Kit.open (0.22 s).
-- While you search, RIVALS' dark searching pill sits over the column (mode, clock, red X cancels).
-- (2026-10-21, RIVALS normal theme) the grid above was the NEW-ACCOUNT Play (tall "Beginner 2v2" hero on the left). RIVALS'
-- normal Play (notes/ui_rivals/rivals_normal/play.png) is now copied instead: 1v1 / 2v2 / 3v3 (323 x 274) on top, Training +
-- Duel Pads (488 / 489 x 275) in the 4v4 / 5v5 spots below, and a TALL Ranked tile (415 x 556) on the RIGHT: "Ranked" + the
-- season at the top, your gun as a big render, the rank line at the bottom (shield glyph, rank name, "0 / 10"; locked =
-- padlock + "LV n / 50"). Grid 1403 x 556 at x 258, y 306; the red X outside its top-right corner.
-- (2026-10-21, port3) per two graders: 6 px gaps, titles +15 % with a soft drop shadow (no outline), the 3D tiles (Training,
-- Duel Pads, Ranked) in the cards' pink / purple grade, Ranked = action art + white shield + "Unranked" + "0 / 10" (locked:
-- "LV n / 50", no padlock), the X 12 px outside the grid's top-right.
-- Every colour / font comes from UIKit.Rivals.Theme. Design px at 1920x1080, converted to Scale (Rivals Kit.toScale).
--   PlayScreen.Init({ Config, getData, ask, onOpen, onClose, enterTraining, toPads, rankedOpen, level })
--   PlayScreen.Open() / Close() / IsOpen() / Refresh()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = script.Parent
local Rivals = UIKit:WaitForChild("Rivals")
-- (2026-10-21, RIVALS 1:1) the look comes from the Rivals kit; Tacticals' Kit stays only for whoops / crown / bar fills / shake
local Theme = require(Rivals:WaitForChild("Theme"))
local Kit = require(Rivals:WaitForChild("Kit"))
local Assets = require(Rivals:WaitForChild("Assets"))
local TK = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local C, F, new = Theme.color, Theme.font, Kit.new
local player = Players.LocalPlayer
local CENTER = Enum.TextXAlignment.Center

local Screen = {}
local ctx = {}
local gui, root, col, blur, scrim, pill
local isOpen = false
local chatWas
local tab = "Casual"
local strips = {} -- per-tile state (dim overlays), updated every tick without rebuilding

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

local function clockText(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
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
local frameOn, stageSet, partsOf -- (2026-10-21, grade2) defined under part() below; the Play tiles' squads use them
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

-- (2026-10-21, grade1: tiles read as dark silhouettes) a tile scene is lit like a picture: bright ambient and a warm key light
-- from the camera side (ViewIcons' default light comes from behind the scene: the camera sits at -Z looking +Z, its light
-- travels -Z). raise (0..1) moves the camera down so the scene sits higher and the big title below it leaves the figures visible.
-- (2026-10-21, RIVALS 1:1) punchy action-shot light: RIVALS' tile art is bright and sits under a 30 % black shade, so the
-- scenes get a cooler, brighter ambient and a full white key light from high on the camera side (hard, high-contrast shading)
local function lightScene(vp, raise)
	if not vp then return end
	local f = vp.Frame
	f.Ambient = Color3.fromRGB(176, 178, 196)
	f.LightColor = Color3.fromRGB(255, 255, 255)
	f.LightDirection = Vector3.new(-0.35, -0.9, 0.4)
	if raise and raise ~= 0 then
		local cam = f.CurrentCamera
		local d = cam.CFrame.Position.Magnitude
		cam.CFrame = cam.CFrame * CFrame.new(0, -d * math.tan(math.rad(cam.FieldOfView / 2)) * raise, 0)
	end
end

-- the scene for a mode card: you (+ mates) on the left facing right, the other team on the right facing left
-- shot (optional, the Play tiles) = { aspect, top, bottom, fit }: (2026-10-21, grade2: "flat colour cards with small figures")
-- the squad stands in a place (concrete floor, olive wall with tan pillars, crates; the tile's sky gradient shows above the
-- wall), packed tighter for 2v2 / 3v3, and the camera is aimed so the figures fill top..bottom of the tile. RankedScreen
-- passes no shot and keeps the old auto-framed look.
local SQUAD_X = { { 2.4, 0 }, { 1.9, 2.5 }, { 1.6, 2.1 } } -- (grade2) first offset, spacing per team size on the Play tiles
local function squadScene(parent, teamSize, ranked, shot)
	local scene = Instance.new("Model")
	scene.Name = "Squad"
	local weapon = (ctx.getData() and ctx.getData().Loadout and ctx.getData().Loadout.Weapon) or ctx.Config.DefaultLoadout.Weapon
	-- (2026-10-21, AI-tells cleanup) ranked = dark gold, was violet
	-- (2026-10-21, grade1: "1v1 drawn over dark silhouettes") the other team is a lit rust / gold mannequin, not near-black
	-- (2026-10-21, RIVALS 1:1) RIVALS' tiles show saturated red enemies: Theme red (ranked: Theme gold)
	local enemyTint = ranked and C.gold or C.red
	local mateTint = Color3.fromRGB(150, 156, 136)
	local first, gap = 2.6, 3.4
	if shot then first, gap = SQUAD_X[teamSize] and SQUAD_X[teamSize][1] or 1.6, SQUAD_X[teamSize] and SQUAD_X[teamSize][2] or 2.1 end
	-- the viewport camera looks from +Z towards -Z (screen right = -X), rigs face -Z by default:
	-- your team at +X (screen left) turned towards the other team and the camera, theirs mirrored
	for side = 0, 1 do
		for i = 1, teamSize do
			local tint
			if side == 1 then tint = enemyTint elseif i > 1 then tint = mateTint end
			local m = rig(tint)
			if not m then break end
			local x = (side == 0 and 1 or -1) * (first + (i - 1) * gap)
			local z = -(i - 1) * 2.2 -- mates stand a step back
			local yaw = side == 0 and math.rad(125) or math.rad(-125)
			m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0))
			if side == 0 and i == 1 then arm(m, weapon) end
			m.Name = side == 0 and ("Mate" .. i) or ("Enemy" .. i) -- (2026-10-21, round 3) named so the hover hop finds your team
			m.Parent = scene
		end
	end
	if #scene:GetChildren() == 0 then scene:Destroy(); return nil end
	if not shot then
		local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(math.rad(-6), 0, 0), zoom = ({ 1.1, 1.4, 1.45 })[teamSize] or 1.6, still = true })
		lightScene(vp)
		return vp, scene
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.identity, zoom = 1, still = true })
	lightScene(vp)
	local figures = partsOf(scene)
	stageSet(vp, scene, figures, ranked and "ranked" or "squad")
	frameOn(vp, figures, shot.aspect, shot.top, shot.bottom, -7, shot.fit)
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
	-- (2026-10-21, grade2) an aimed shot (frameOn) leans in on / turns about its subject, not the scene's centre
	local focus = vp.focus or Vector3.zero
	local dist = vp.focusDist or base.Position.Magnitude
	local around = function(a) return CFrame.new(focus) * CFrame.Angles(0, a, 0) * CFrame.new(-focus) end
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
		cam.CFrame = around(h * 0.07) * base * CFrame.new(0, 0, -h * dist * (push or 0.1))
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

-- (2026-10-21, grade2: "tiles read as flat colour cards with small figures, not pictures") every Play tile is a place now:
-- partsOf = the visible parts of a model; frameOn aims the viewport camera so those parts span `top`..`bottom` of the tile
-- (fractions from the top) and at most `fit` of its width; stageSet builds floor / back wall / pillars / crates around them.
partsOf = function(model, skip)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and not (skip and d:IsDescendantOf(skip)) then table.insert(list, d) end
	end
	return list
end
local CORNERS = {}
for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do table.insert(CORNERS, Vector3.new(x, y, z)) end end end
local function cornersOf(parts)
	local pts = {}
	for _, p in parts do
		local cf, half = p.CFrame, p.Size / 2
		for _, c in CORNERS do table.insert(pts, cf * (half * c)) end
	end
	return pts
end
local function boxOf(pts)
	local lo, hi = pts[1], pts[1]
	for _, q in pts do lo, hi = lo:Min(q), hi:Max(q) end
	return lo, hi
end
local function flatLook(vp)
	local v = vp.Frame.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	return v.Magnitude > 1e-3 and v.Unit or Vector3.new(0, 0, 1)
end
-- a few rounds of: project every corner, move the camera back / forward so the span fits, then slide it so the top edge sits
-- on its mark and the subject is centred left-right (perspective makes one pass inexact; 30 rounds settle it)
frameOn = function(vp, parts, aspect, top, bottom, pitch, fit)
	if not vp then return end
	local pts = cornersOf(parts)
	if #pts == 0 then return end
	local cam = vp.Frame.CurrentCamera
	local tanV = math.tan(math.rad(cam.FieldOfView / 2))
	local tanH = tanV * (aspect or 1)
	local lo, hi = boxOf(pts)
	local centre = (lo + hi) / 2
	local rot = CFrame.lookAt(Vector3.zero, flatLook(vp)) * CFrame.Angles(math.rad(pitch or -8), 0, 0)
	local pos = centre - rot.LookVector * math.max((hi - lo).Magnitude, 1) * 2
	local yT, yB = 1 - 2 * top, 1 - 2 * bottom
	local wantH, wantW = yT - yB, 2 * (fit or 0.92)
	for _ = 1, 30 do
		local cf = rot + pos
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, q in pts do
			local c = cf:PointToObjectSpace(q)
			local z = math.max(-c.Z, 0.05)
			local sx, sy = c.X / (z * tanH), c.Y / (z * tanV)
			x0, x1, y0, y1 = math.min(x0, sx), math.max(x1, sx), math.min(y0, sy), math.max(y1, sy)
		end
		local depth = math.max(-cf:PointToObjectSpace(centre).Z, 0.5)
		local s = math.max((y1 - y0) / wantH, (x1 - x0) / wantW, 0.2)
		local nd = depth * s
		local midY = yT - (y1 - y0) / s / 2 -- a width-bound subject comes out shorter: its top still sits on the mark
		pos = pos - rot.LookVector * (nd - depth)
			+ rot.UpVector * (((y0 + y1) / 2 / s - midY) * nd * tanV)
			+ rot.RightVector * (((x0 + x1) / 2 / s) * nd * tanH)
	end
	cam.CFrame = rot + pos
	vp.focus, vp.focusDist = centre, (pos - centre).Magnitude
end
-- set dressing per tile: concrete floor under the subject's feet, a low back wall (the tile's sky gradient shows over it) with
-- pillars and a coping, crates either side; sizes follow the subject so 1v1 and 3v3 both get crates in frame
-- (2026-10-21, RIVALS 1:1) squad / pad sets in RIVALS' pale arena tones (light lavender-grey floor and walls, white pillars) so
-- the red enemies and your figure pop against them like the live tile shots; walls taller so they fill behind the larger figures
local SETS = {
	squad = { floor = Color3.fromRGB(206, 204, 216), wall = Color3.fromRGB(196, 192, 214), pillar = Color3.fromRGB(236, 234, 242),
		trim = Color3.fromRGB(170, 166, 188), crate = Color3.fromRGB(150, 112, 64), h = 9, crates = true, mat = Enum.Material.SmoothPlastic },
	-- (2026-10-21, port3) ranked / range were dark gold and sand / olive (graders: "flat olive and muddy"): the same pale arena
	-- as the cards now, so the pink / purple grade reads the same on every tile
	ranked = { floor = Color3.fromRGB(206, 204, 216), wall = Color3.fromRGB(196, 192, 214), pillar = Color3.fromRGB(236, 234, 242),
		trim = Color3.fromRGB(170, 166, 188), h = 9, mat = Enum.Material.SmoothPlastic },
	range = { floor = Color3.fromRGB(210, 206, 218), wall = Color3.fromRGB(196, 192, 214), pillar = Color3.fromRGB(236, 234, 242),
		trim = Color3.fromRGB(170, 166, 188), crate = Color3.fromRGB(150, 112, 64), h = 7, crates = true, mat = Enum.Material.SmoothPlastic },
	pads = { floor = Color3.fromRGB(190, 188, 202), wall = Color3.fromRGB(196, 192, 214), pillar = Color3.fromRGB(236, 234, 242),
		trim = Color3.fromRGB(170, 166, 188), crate = Color3.fromRGB(140, 104, 60), h = 9, crates = true, mat = Enum.Material.SmoothPlastic },
}
stageSet = function(vp, scene, parts, kind)
	if not vp then return end
	local pts = cornersOf(parts)
	if #pts == 0 then return end
	local st = SETS[kind] or SETS.squad
	local look = flatLook(vp)
	local lo, hi = boxOf(pts)
	local c = (lo + hi) / 2
	-- local frame on the floor under the subject: -Z = away from the camera, X = screen right
	local at = Vector3.new(c.X, lo.Y, c.Z)
	local back = CFrame.lookAt(at, at + look)
	local halfW, halfD = 0, 0
	for _, q in pts do
		local o = back:PointToObjectSpace(q)
		halfW, halfD = math.max(halfW, math.abs(o.X)), math.max(halfD, -o.Z)
	end
	local set = Instance.new("Model")
	set.Name = "Set"
	local wallZ = -(halfD + 7)
	part(set, Vector3.new(220, 1, 160), back * CFrame.new(0, -0.5, -20), st.floor, st.mat)
	part(set, Vector3.new(220, 0.06, 0.5), back * CFrame.new(0, 0.03, -(halfD + 1)), st.trim, Enum.Material.SmoothPlastic) -- a painted line behind them
	part(set, Vector3.new(220, st.h, 1.5), back * CFrame.new(0, st.h / 2, wallZ), st.wall, Enum.Material.Concrete)
	part(set, Vector3.new(220, 0.5, 2), back * CFrame.new(0, st.h + 0.25, wallZ), st.trim, Enum.Material.Concrete)
	for i = -10, 10 do
		part(set, Vector3.new(1.6, st.h + 0.7, 2.2), back * CFrame.new(i * 9, (st.h + 0.7) / 2, wallZ + 0.4), st.pillar, Enum.Material.Concrete)
	end
	if st.crates then
		local cx, cz = halfW + 1.6, -(halfD + 2.5)
		for _, k in { { cx, 1.5, cz, 3, 8 }, { cx - 0.2, 4.2, cz - 0.2, 2.4, -14 }, { -cx - 0.4, 1.4, cz - 0.6, 2.8, 6 } } do
			part(set, Vector3.new(k[4], k[4], k[4]), back * CFrame.new(k[1], k[2], k[3]) * CFrame.Angles(0, math.rad(k[5]), 0), st.crate, Enum.Material.WoodPlanks)
		end
	end
	set.Parent = scene
	return set
end

-- (2026-10-21, round 3: match RIVALS) Training: RIVALS shows art here; ours is a live range scene. A straw target dummy on a
-- post with rings on its chest, a sandbag wall in front with your gun resting on it, a round target board behind. The dummy
-- sways, and rocks back as if hit when you hover.
-- (2026-10-21, grade2: "the scene sits in the top third and the slab edge cuts diagonally") no slab: the range stands on a
-- sand floor that runs past every edge, a tan backstop wall behind; packed narrower for the tall hero tile and aimed (frameOn)
-- so the targets / sandbags fill the top ~60 % and the title sits on the floor in the lower third.
local function trainingScene(parent, target, shot)
	local scene = Instance.new("Model")
	scene.Name = "Range"
	-- sandbag wall (screen left = +X, near the camera): three staggered rows of squashed spheres
	for r, xs in { { -1.8, -0.6, 0.6, 1.8 }, { -1.2, 0, 1.2 }, { -0.6, 0.6 } } do
		for k, x in xs do
			local bag = part(scene, Vector3.new(1.3, 0.75, 0.95), CFrame.new(1.8 + x, 0.35 + (r - 1) * 0.62, -1.6) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 3 or -3)),
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
		gun:PivotTo(CFrame.new(1.8, 2.1, -1.7) * turn)
		gun.Parent = scene
	elseif gun then
		gun:Destroy()
	end
	-- the target dummy on a post (screen right = -X, further back), rings facing the camera
	local dummy = Instance.new("Model")
	dummy.Name = "Dummy"
	local foot = CFrame.new(-1.8, 0, 1.4) -- (grade2) was (-2.4, 0, 2.6): narrower for the tall tile
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
	local board = CFrame.new(0.9, 0, 5.4) -- (grade2) was (4.6, 0, 5.2)
	for _, s in { -1, 1 } do
		part(scene, Vector3.new(0.25, 3.2, 0.25), board * CFrame.new(s * 0.9, 1.6, 0.3) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, Enum.Material.Wood)
	end
	for i, ring in { { 2.6, RING_CREAM }, { 1.8, RING_RED }, { 1.0, RING_CREAM }, { 0.45, RING_RED } } do
		part(scene, Vector3.new(0.08, ring[1], ring[1]), board * CFrame.new(0, 3.2, -i * 0.02) * FACING, ring[2], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.Angles(0, math.rad(-14), 0), zoom = 1, still = true })
	lightScene(vp)
	local props = partsOf(scene)
	stageSet(vp, scene, props, "range")
	frameOn(vp, props, shot.aspect, shot.top, shot.bottom, -16, shot.fit)
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
-- (2026-10-21, grade2) the pad sits on a concrete yard with a back wall and crates, aimed like the squads (frameOn)
local function duelsScene(parent, target, shot)
	local scene = Instance.new("Model")
	scene.Name = "Pad"
	local FEET = -3 -- a rig's pivot is its root, about 3 studs above its feet
	part(scene, Vector3.new(0.6, 11, 11), CFrame.new(0, FEET - 0.3, 0) * UPRIGHT, Color3.fromRGB(46, 50, 56), Enum.Material.Metal, Enum.PartType.Cylinder)
	local ring = part(scene, Vector3.new(0.4, 12, 12), CFrame.new(0, FEET - 0.45, 0) * UPRIGHT, C.green, Enum.Material.Neon, Enum.PartType.Cylinder) -- (2026-10-21, RIVALS 1:1) Theme green
	part(scene, Vector3.new(0.62, 3, 3), CFrame.new(0, FEET - 0.29, 0) * UPRIGHT, Color3.fromRGB(28, 30, 26), Enum.Material.Metal, Enum.PartType.Cylinder) -- centre mark
	local weapon = loadoutWeapon()
	local fighters = {}
	for side = 0, 1 do
		local tint = side == 1 and C.red or nil -- (2026-10-21, RIVALS 1:1) RIVALS' red enemy (was lit rust)
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
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.identity, zoom = 1, still = true })
	lightScene(vp)
	local props = partsOf(scene)
	stageSet(vp, scene, props, "pads")
	frameOn(vp, props, shot.aspect, shot.top, shot.bottom, -14, shot.fit)
	local homes = {}
	for i, m in fighters do homes[i] = m:GetPivot() end
	liven(vp, target, 0.1, function(t, _, since)
		ring.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 2.6))
		if since > 1.2 then return end
		for i, m in fighters do m:PivotTo(homes[i] + Vector3.new(0, hop(since, (i - 1) * 0.1, 0.9), 0)) end
	end)
	return vp
end

-- (2026-10-21, grade2: "add a scene behind the padlock") Ranked: ViewIcons' gold trophy, scaled up, on a three-step podium of
-- dark plates with brass trims, in a dark gold hall. Locked = the same scene greyed down (the padlock sits over it).
-- (2026-10-21, port3) now only the fallback for the Ranked tile (no character); never greyed (locked shows a requirement line)
local function rankedScene(parent, target, shot)
	local scene = Instance.new("Model")
	scene.Name = "Podium"
	local plate, brass = Color3.fromRGB(40, 44, 36), Color3.fromRGB(196, 156, 70)
	for _, s in { { 0, 2.4, 3.6 }, { 3.6, 1.6, 3.2 }, { -3.6, 1.1, 3.2 } } do
		part(scene, Vector3.new(s[3], s[2], 3.2), CFrame.new(s[1], s[2] / 2, 0), s[1] == 0 and plate or plate:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Metal)
		part(scene, Vector3.new(s[3] + 0.04, 0.2, 3.24), CFrame.new(s[1], s[2] - 0.1, 0), brass, Enum.Material.Metal)
	end
	-- (2026-10-21, RIVALS normal theme) RIVALS' tall Ranked tile shows a big gun render: your loadout gun, scaled up and
	-- tilted diagonally (the tile is portrait) over the podium; the camera frames the gun alone (shot.top..bottom), so the
	-- title above and the rank line below stay clear. The trophy stays as the fallback when there is no gun model.
	local hero
	local weapon = loadoutWeapon()
	local gun = weapon and ViewIcons.Weapon(weapon)
	if gun and #gun:GetChildren() > 0 then
		local bb, size = gun:GetBoundingBox()
		gun.WorldPivot = CFrame.new(bb.Position)
		local turn = CFrame.identity -- the longest axis is the barrel: lay it along X
		if size.Z >= size.X and size.Z >= size.Y then turn = CFrame.Angles(0, math.rad(90), 0)
		elseif size.Y >= size.X and size.Y >= size.Z then turn = CFrame.Angles(0, 0, math.rad(90)) end
		pcall(function() gun:ScaleTo(math.clamp(7 / math.max(size.X, size.Y, size.Z, 0.1), 0.3, 4)) end)
		gun:PivotTo(CFrame.new(0, 2.4 + 3.4, 0) * CFrame.Angles(0, math.rad(-18), 0) * CFrame.Angles(0, 0, math.rad(-32)) * turn)
		gun.Parent = scene
		hero = gun
	else
		if gun then gun:Destroy() end
		local cup = ViewIcons.Build("Trophy")
		if cup then
			local cf = cup:GetBoundingBox()
			cup.WorldPivot = cf
			pcall(function() cup:ScaleTo(2.4) end)
			local _, size = cup:GetBoundingBox()
			cup:PivotTo(CFrame.new(0, 2.4 + size.Y / 2, 0) * CFrame.Angles(0, math.rad(-16), 0))
			cup.Parent = scene
			hero = cup
		end
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.identity, zoom = 1, still = true })
	if not vp then return nil end
	lightScene(vp)
	local props = partsOf(scene)
	stageSet(vp, scene, props, "ranked")
	frameOn(vp, hero and partsOf(hero) or props, shot.aspect, shot.top, shot.bottom, -6, shot.fit)
	liven(vp, target, 0.06)
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

-- (2026-10-21, RIVALS 1:1) layout from the live capture (grade2/rivals_play.png, 1:1 at 1920x1080) and the replica's column:
-- the column starts at x 258, y 139 (Screens map P1); hero 416 x 555, top tiles 323 x 274, bottom tiles 488 x 274, gutter 7.
-- (2026-10-21, RIVALS normal theme) measured on rivals_normal/play.png (1920 x 1002 viewport: the tiles are the same px as the
-- 1080 capture, so x / sizes carry over 1:1 and the grid's centre y 541.5 / 1002 maps to 584 / 1080 -> top 306):
--   top row x 258 / 587 / 916, 323 x 274 (6 px gaps); bottom row 488 x 275 at x 258 and 489 x 275 at x 751, y +281;
--   Ranked 415 x 556 at x 1246 (7 px gap), full grid height. Grid 1403 x 556.
local COL_X, COL_Y = 258, 306
local COL_W, COL_H = 1403, 1080 - 306 -- the column (still a ScrollingFrame) runs to the screen bottom
local MW, MH, MPITCH = 323, 274, 329 -- mode tile, top row
-- (2026-10-21, port3) graders: every gap 6 px like RIVALS (the bottom row / Ranked had 5-7). Top row 0..981, the bottom row
-- ends there too (488 + 6 + 487), Ranked 6 px right of it (987 + 416 = 1403).
local BY, BH = 280, 276 -- bottom row: y in the grid, height
local BW1, BX2, BW2 = 488, 494, 487 -- Training (4v4 spot) width; Duel Pads (5v5 spot) x and width
local RX, RW = 987, 416 -- the tall Ranked tile
local GRID_H = 556
local CORNER = 8 -- small rounded corners (live capture; 2026-10-22 round 0: RIVALS ~8, was 6)
local SHADE = 0.7 -- RIVALS: bright art under a 30 % black shade; hover lifts it to 0.95 (the picture brightens)
-- (2026-10-21, port3) titles ~15 % bigger (RIVALS' "1v1" box ~7.4 % of the screen height): 100 -> 115, 88 -> 101
local TITLE, WIDE_TITLE = 115, 81 -- (round 3, grader A vs t0016: bottom-row titles fill <= 50 % of the tile, was 101)
-- the gradient behind each 3D set shows as the sky over its back wall: Theme blue (ranked: Theme key gold)
-- (2026-10-21, port3) graders: Training / Duel Pads / Ranked must share the 1v1-3v3 cards' grade (pink highlights, purple
-- mids; sampled from gen.play_card_*: ~#FC96F8 / #AA64E6). Every 3D tile now uses that sky, its lighting and a wash (grade()).
local GRADE = { Theme.hex("#FC9AF6"), Theme.hex("#9A5CE6") }
-- (2026-10-22, Edward Q2 "Ranked = dark gold"; 16:9 grader: the live tiles read washed-out lavender) Ranked gets a dark-gold sky
-- and grade; the others keep the cards' pink / purple but lighter on the models (grade() below)
local DARK_GOLD = { Theme.hex("#9A7024"), Theme.hex("#3A2608") }
local SKY, DUSK = GRADE, DARK_GOLD
-- where each tile's subject sits (fractions of the tile height from the top; fit = most of the width it may take):
-- (2026-10-21, RIVALS 1:1) figures large, filling the tile behind the centred title like RIVALS' gameplay shots
local SQUAD_BOTTOM = { 0.98, 0.96, 0.94 }

-- one huge white title, RIVALS' soft shadow = a black stroke at 0.82 transparency (replica title())
-- (2026-10-21, port3) graders: the stroke read as a hard dark outline. RIVALS' titles carry a soft drop shadow instead: two
-- black copies under the word, nudged down-right (size-relative) at high transparency, so the edge blurs into the art. The
-- copies follow the label's Text (the lock card's count-up changes it).
local function title(parent, text, size, x, y, w, h, z, font, align)
	z = z or 5 -- (port3) 5, so the shadows (z - 1) still sit over the tile's Shade (3)
	local props = { Text = text, FontFace = font or F.display, TextSize = size, TextXAlignment = align or CENTER, Size = UDim2.fromOffset(w, h), Parent = parent }
	local shadows = {}
	for i, k in { { 0.035, 0.72 }, { 0.06, 0.84 } } do
		props.Name, props.TextColor3, props.TextTransparency, props.ZIndex = "TitleShadow" .. i, C.textDark, k[2], z - 1
		props.Position = UDim2.fromOffset(x + math.max(1, math.floor(size * k[1] * 0.6)), y + math.max(2, math.floor(size * k[1])))
		table.insert(shadows, Kit.label(props))
	end
	props.Name, props.TextColor3, props.TextTransparency, props.ZIndex, props.Position = "Title", C.text, 0, z, UDim2.fromOffset(x, y)
	local l = Kit.label(props)
	l:GetPropertyChangedSignal("Text"):Connect(function() for _, s in shadows do s.Text = l.Text end end)
	return l
end
-- (2026-10-21, RIVALS normal theme) the Ranked tile's season / rank lines are italic in RIVALS: the Theme font, italic style
local function italic(f) return Font.new(f.Family, f.Weight, Enum.FontStyle.Italic) end
-- (2026-10-21, port3) the cards' colour grade on a live 3D tile: pink key light, purple ambient (lit faces go pink, shaded ones
-- purple, like the art), and a soft pink -> purple wash over the picture under the tile's black shade.
local function grade(vp, holder, cols)
	cols = cols or GRADE
	if vp then
		local f = vp.Frame
		-- (2026-10-22) the pink / purple grade stays (it must match the 1v1-3v3 art); Ranked gets a warm dark-gold one
		f.Ambient = cols == GRADE and Theme.hex("#B47CEA") or Theme.hex("#A08A60")
		f.LightColor = cols == GRADE and Theme.hex("#FFC4F8") or Theme.hex("#FFF2D6")
		f.ImageColor3 = cols == GRADE and C.white or Theme.hex("#D8A447") -- Ranked: the render itself takes the dark-gold tint
	end
	new("Frame", { Name = "Grade", BackgroundColor3 = C.white, BackgroundTransparency = cols == GRADE and 0.8 or 0.32, BorderSizePixel = 0, -- Ranked: a strong dark-gold wash Size = UDim2.fromScale(1, 1), ZIndex = 2,
		Parent = holder }, { Kit.vgrad(cols) })
end

-- (2026-10-21, RIVALS normal theme) the Ranked tile's data, shown the RIVALS way ("Season 3"; shield + "Unranked" + "0 / 10"):
-- the season from RankedCore.Config.Season, the rank from RankArt.Of (the attributes RankedScreen reads). Locked = the padlock,
-- your rank name and the level requirement "LV n / 50"; in placements = "played / needed"; placed = "ELO / next floor".
local function season()
	local mod = ReplicatedStorage:FindFirstChild("Modules")
	mod = mod and mod:FindFirstChild("Shared")
	mod = mod and mod:FindFirstChild("RankedCore")
	local ok, RC = pcall(function() return mod and require(mod) end)
	local n = ok and RC and RC.Config and RC.Config.Season
	return "Season " .. tostring(n or 1)
end
local function rankLine(open)
	local okA, RankArt = pcall(require, UIKit:FindFirstChild("RankArt"))
	local info = (okA and RankArt and RankArt.Of) and RankArt.Of(player) or { placed = false, name = "Unranked" }
	local shield = (Assets.play and Assets.play.shield_badge) or ""
	if not open then
		local lv = math.max(0, (ctx.level and ctx.level()) or 0)
		local need = math.max(1, ctx.Config.RankedLevel or 1)
		-- (2026-10-21, port3) graders: no padlock-on-flat look. RIVALS keeps the white shield and "Unranked"; the requirement
		-- is the line under it
		return shield, "Unranked", "LV " .. math.min(lv, need) .. " / " .. need
	end
	if not info.placed then
		local placed, need = player:GetAttribute("RankPlaced") or 0, player:GetAttribute("RankPlacements") or 10
		return shield, "Unranked", math.min(placed, need) .. " / " .. need
	end
	local nextFloor = player:GetAttribute("RankNextFloor")
	local elo = math.floor((info.elo or 0) + 0.5)
	return info.image or shield, info.name or "Ranked", nextFloor and (elo .. " / " .. nextFloor) or (elo .. " ELO")
end

-- (2026-10-21, RIVALS 1:1) the replica's card(): a full-bleed picture (here the sky gradient + the live 3D scene added after
-- toScale) under a black shade, a white 4 px border stroke hidden until hover; no lip, bar, band or subtitle
local tiles = {}
local function tile(name, x, y, w, h, sky)
	local f = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white, ClipsDescendants = true, Parent = col }, { Kit.corner(CORNER), Kit.vgrad(sky) })
	new("Frame", { Name = "Scene", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = f })
	new("Frame", { Name = "Shade", BackgroundColor3 = C.textDark, BackgroundTransparency = SHADE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = f })
	new("UIStroke", { Name = "HoverRing", Color = C.white, Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	-- unavailable while you queue / stand on a pad (Tacticals behaviour): a dark overlay, nothing written on it
	new("Frame", { Name = "Dim", BackgroundColor3 = C.textDark, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = f })
	-- (2026-10-22, section round 1, grader C) ClipsDescendants ignores the tile's UICorner, so the full-bleed layers (picture, 3D scene,
	-- shade, wash, dim) drew square corners over it: each full-size layer gets the same corner (now and when the scene is added)
	local function round(o)
		if o:IsA("GuiObject") and not o:IsA("TextLabel") and o.Size.X.Scale >= 0.99 and o.Size.Y.Scale >= 0.99 and not o:FindFirstChildOfClass("UICorner") then
			Kit.corner(CORNER).Parent = o
		end
	end
	for _, o in f:GetDescendants() do round(o) end
	f.DescendantAdded:Connect(function(o) task.defer(round, o) end)
	table.insert(tiles, f)
	return f
end
-- replica hover / press: the card shrinks inward to 0.97, the white border shows, the shade lifts (picture brightens);
-- a controller's selection does the same
local function bindTile(b)
	local s = new("UIScale", { Name = "HoverScale", Parent = b })
	local ring, shade = b:FindFirstChild("HoverRing"), b:FindFirstChild("Shade")
	local rest = shade.BackgroundTransparency
	local hov, sel = false, false
	-- (2026-10-22, live RIVALS feel study) hovered, RIVALS' tile washes out toward white under a thin white outline and its
	-- big label fades back: a white wash (0.6), the ring at 2 px, the title + shadows to 0.35
	ring.Thickness = 2
	local wash = new("Frame", { Name = "HoverWash", BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 4, Parent = b })
	local function show()
		local on = hov or sel
		Kit.tween(s, on and 0.1 or 0.12, { Scale = on and 0.97 or 1 })
		Kit.tween(ring, on and 0.1 or 0.12, { Transparency = on and 0 or 1 })
		Kit.tween(shade, on and 0.1 or 0.12, { BackgroundTransparency = on and 0.95 or rest })
		Kit.tween(wash, on and 0.1 or 0.15, { BackgroundTransparency = on and 0.6 or 1 })
		for _, d in b:GetDescendants() do
			if d:IsA("TextLabel") and (d.Name == "Title" or string.sub(d.Name, 1, 11) == "TitleShadow") then
				if d:GetAttribute("RestT") == nil then d:SetAttribute("RestT", d.TextTransparency) end
				Kit.tween(d, on and 0.1 or 0.15, { TextTransparency = on and math.max(d:GetAttribute("RestT"), 0.35) or d:GetAttribute("RestT") })
			end
		end
	end
	b.MouseEnter:Connect(function() hov = true; show() end)
	b.MouseLeave:Connect(function() hov = false; show() end)
	b.SelectionGained:Connect(function() sel = true; show() end)
	b.SelectionLost:Connect(function() sel = false; show() end)
	b.Activated:Connect(function()
		if b:GetAttribute("Locked") then return end
		s.Scale = 0.93
		Kit.tween(s, 0.15, { Scale = (hov or sel) and 0.97 or 1 }, Enum.EasingStyle.Back)
	end)
end

-- (2026-10-21, RIVALS pass) locked Ranked: a centred requirement card instead of a toast.
-- (2026-10-21, round 3: match RIVALS t0285.4-t0289) RIVALS' card: a dark card with the big title, one line per requirement (the
-- words left, an "n / N" count right that counts up, a full-width bar under it; a met line turns green with a tick), a short
-- "how" hint, the greyed PLAY below the card and the red X beside its top-right corner. Card, X and PLAY pop in together.
-- (2026-10-21, RIVALS 1:1) colours / fonts from Rivals Theme (panel, text, green, grey gradient, FredokaOne button word)
local lockShade
local function drawTick(parent, x, y, z)
	local hold = new("Frame", { Name = "Tick", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(40, 40), ZIndex = z, Parent = parent })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(12, 25), Size = UDim2.fromOffset(9, 20), Rotation = -45, BackgroundColor3 = C.green,
		BorderSizePixel = 0, ZIndex = z, Parent = hold })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(25, 19), Size = UDim2.fromOffset(9, 36), Rotation = 40, BackgroundColor3 = C.green,
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
	local shade = new("TextButton", { Name = "RankedLock", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.textDark,
		BackgroundTransparency = 0.45, ZIndex = 20, Parent = root })
	lockShade = shade
	local group = new("Frame", { Name = "Group", BackgroundTransparency = 1, Position = UDim2.fromOffset((1920 - W) / 2, (1080 - GH) / 2), Size = UDim2.fromOffset(W + 140, GH),
		ZIndex = 21, Parent = shade })
	local card = new("Frame", { Name = "Card", Active = true, Size = UDim2.fromOffset(W, CH), BackgroundColor3 = C.panel, BackgroundTransparency = 0.08,
		BorderSizePixel = 0, ZIndex = 21, Parent = group }, { Kit.corner(Theme.corner) })
	title(card, "Ranked", 76, 0, 14, W, 90, 22)
	local anims = {}
	for i, r in reqs do
		local y = 112 + (i - 1) * ROW
		local met = r.cur >= r.goal
		Kit.label({ Text = r.text, FontFace = F.bold, TextSize = 30, TextColor3 = C.text, Position = UDim2.fromOffset(48, y), Size = UDim2.fromOffset(440, 40),
			ZIndex = 22, Parent = card })
		local count
		if met then
			drawTick(card, W - 88, y, 23)
		else
			count = title(card, "0 / " .. r.goal, 32, W - 268, y, 220, 40, 22, F.display, Enum.TextXAlignment.Right)
		end
		local track = new("Frame", { Position = UDim2.fromOffset(48, y + 46), Size = UDim2.fromOffset(W - 96, 9), BackgroundColor3 = C.track,
			BorderSizePixel = 0, ZIndex = 22, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = met and C.green or C.white, BorderSizePixel = 0, ZIndex = 23, Parent = track },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		table.insert(anims, { fill = fill, frac = met and 1 or math.clamp(r.cur / r.goal, 0.03, 1), count = count, cur = math.min(r.cur, r.goal), goal = r.goal })
	end
	-- what to do next (kids: the card says how, not only what)
	Kit.label({ Text = "Play matches and finish missions to level up!", FontFace = F.medium, TextSize = 23, TextColor3 = C.textDim,
		TextXAlignment = CENTER, Position = UDim2.fromOffset(0, CH - 52), Size = UDim2.fromOffset(W, 32), ZIndex = 22, Parent = card })
	-- the greyed PLAY under the card (RIVALS' grey button, FredokaOne word); it shakes when pressed
	local playBtn = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((W - PW) / 2, CH + 22), Size = UDim2.fromOffset(PW, PH),
		BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 22, Parent = group }, { Kit.corner(6), Kit.vgrad(Theme.gradient.grey) })
	local pl = Kit.label({ Text = "Play", FontFace = F.chunky, TextSize = 44, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = playBtn })
	Kit.textStroke(2).Parent = pl
	-- the red X: replica's closeButton, beside the card's top-right corner, level with its top
	local x = Kit.closeButton(UDim2.fromOffset(112, 58))
	x.Position = UDim2.fromOffset(W + 20, 0)
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
		TK.shake(playBtn)
		task.delay(0.25, function() shaking = false end)
	end)
	Kit.open(group)
	for _, a in anims do
		TK.fillTo(a.fill, a.frac, 0.6)
		if a.count then TK.countTo(a.count, 0, a.cur, 0.6, function(n) return math.floor(n + 0.5) .. " / " .. a.goal end) end
	end
end

local function modeCard(mode, ranked, x)
	local q = ctx.Config.QueueFor(mode.Id, ranked)
	local card = tile(mode.Id, x, 0, MW, MH, ranked and DUSK or SKY)
	-- (2026-10-21, RIVALS images) RIVALS' mode tiles are pictures: gen.play_card_1v1 / 2v2 / 3v3 full-bleed (Crop) in the Scene
	-- holder instead of the live 3D squad. The cards are bright lavender, so the replica's 30 % black shade stays (the white
	-- title would wash out without it) and hover still lifts it. render() skips the squad scene for a tile with art.
	local n = mode.TeamSize
	local art = Assets.gen and Assets.gen[("play_card_%dv%d"):format(n or 0, n or 0)]
	if art then
		new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = art, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1),
			ZIndex = 1, Parent = card.Scene })
	end
	-- (2026-10-21, RIVALS 1:1) ONE huge title, centred on the tile (replica: 100, full tile height); no tag, no subtitle
	title(card, mode.Id, TITLE, 0, 0, MW, MH)
	local entry = { q = q, card = card, dim = card.Dim }
	table.insert(strips, entry)
	card.Activated:Connect(function()
		local myQ, st = search()
		if myQ and q and myQ.Id == q.Id and st == "Searching" then ctx.ask("CancelMatch"); return end
		if myQ or onPad() or not q then return end
		local why = partyBlock(mode.TeamSize)
		if why then TK.whoops(why) return end
		local r = ctx.ask("FindMatch", q.Id)
		if r and r.ok then Screen.Close(); return end
		-- (2026-10-21, RIVALS 1:1) RIVALS says why in its Whoops popup (was a red chip on the tile)
		local msg = r and r.msg or "No answer from the server"
		if msg == "Unknown action" then msg = "Online matchmaking is offline here" end
		TK.whoops(msg)
		tickNow()
	end)
	return card.Scene, mode.TeamSize, card, art ~= nil
end

-- (2026-10-22, live RIVALS) the party column (the leader at the bottom with the crown, the others above, a + on top; any
-- of them opens Your Party) is ONE shared column at RIVALS' spot, bottom left (avatar centre 7 % of the width, 86 % of the
-- height), shown over Play, Missions, Codes and the profile card (RIVALS shows it on every such menu). Built in design px.
local function buildPartyColumn(parent, x, bottomY)
	local colF = new("Frame", { Name = "PartyColumn", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, bottomY - 500),
		Size = UDim2.fromOffset(110, 500), Parent = parent })
	local list = partyList()
	if #list == 0 then list = { player.UserId } end
	local leader = partyLeader(list)
	local order = { leader }
	for _, uid in list do if uid ~= leader then table.insert(order, uid) end end
	local y = 500 + 8
	for i, uid in order do
		local d = i == 1 and 108 or 80
		y -= d + 8
		local h = new("ImageButton", { Name = "Head" .. i, AutoButtonColor = false, BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.2,
			Position = UDim2.fromOffset((110 - d) / 2, y), Size = UDim2.fromOffset(d, d), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		h:AddTag("Nonapplicable")
		task.spawn(function()
			local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok then h.Image = im end
		end)
		if i == 1 and #list > 1 then TK.crown(h, UDim2.fromScale(0.78, 0.12), UDim2.fromScale(0.55, 0.42), 6) end
		Kit.bindButton(h, { hover = 1.06 })
		h.Activated:Connect(openParty)
	end
	if #list < 5 then
		y -= 81 + 8
		local plus = new("TextButton", { Name = "Invite", Text = "", AutoButtonColor = false, BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.3,
			Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(81, 81), ZIndex = 4, Parent = colF }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		plus:AddTag("Nonapplicable")
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 8), BackgroundColor3 = C.textDim, BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 30), BackgroundColor3 = C.textDim, BorderSizePixel = 0, ZIndex = 5, Parent = plus })
		Kit.bindButton(plus, { hover = 1.08 })
		plus.Activated:Connect(openParty)
	end
end
local partyGui
local function refreshPartyColumn()
	if not partyGui then
		partyGui = new("ScreenGui", { Name = "MenuParty", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 40, Enabled = false,
			Parent = player:WaitForChild("PlayerGui") })
		local canvas = Kit.canvas(partyGui)
		partyGui:SetAttribute("Built", true)
		new("Frame", { Name = "Holder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas }):SetAttribute("DesignCanvas", true)
	end
	local holder = partyGui:FindFirstChild("Holder", true)
	for _, c in holder:GetChildren() do c:Destroy() end
	local tmp = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Parent = holder })
	buildPartyColumn(tmp, 134 - 55, 983)
	Kit.toScale(tmp)
end
local function menuWithParty()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return false end
	for _, n in { "PlayUI", "MissionsUI", "CodesUI" } do
		local g = pg:FindFirstChild(n)
		if g and g.Enabled then return true end
	end
	local pc = pg:FindFirstChild("PlayerCards")
	return pc ~= nil and pc:FindFirstChild("Profile", true) ~= nil
end
task.defer(function()
	refreshPartyColumn()
	for _, a in { "PartyMembers", "PartyLeader" } do player:GetAttributeChangedSignal(a):Connect(refreshPartyColumn) end
	game:GetService("RunService").Heartbeat:Connect(function()
		local on = menuWithParty()
		if partyGui and partyGui.Enabled ~= on then partyGui.Enabled = on end
	end)
end)

local function render()
	strips, tiles = {}, {}
	for _, ch in col:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	local Config = ctx.Config
	local open = ctx.rankedOpen and ctx.rankedOpen()
	if not open then tab = "Casual" end
	local ranked = tab == "Ranked"
	-- (2026-10-21, RIVALS normal theme) no hero: Training takes RIVALS' 4v4 spot (bottom left)
	local tb = tile("Training", 0, BY, BW1, BH, SKY)
	title(tb, "Training", WIDE_TITLE, 0, 0, BW1, BH)
	table.insert(strips, { training = true, dim = tb.Dim })
	tb.Activated:Connect(function()
		local myQ = search()
		if myQ or onPad() then
			TK.whoops(myQ and "You can't train while searching for a match!" or "You can't train while on a duel pad!")
			return
		end
		Screen.Close()
		if ctx.enterTraining then ctx.enterTraining() end
	end)
	-- top row: the queues
	local stages = {}
	for i, mode in Config.Modes do
		if i > 3 then break end -- (2026-10-21, RIVALS normal theme) the top row has three spots
		local stage, n, card, hasArt = modeCard(mode, ranked, (i - 1) * MPITCH)
		if not hasArt then table.insert(stages, { stage, n, card }) end -- (2026-10-21, RIVALS images) art tiles get no 3D squad
	end
	-- (2026-10-21, RIVALS normal theme) Duel Pads in RIVALS' 5v5 spot (bottom middle)
	local db = tile("DuelPads", BX2, BY, BW2, BH, SKY)
	title(db, "Duel Pads", WIDE_TITLE, 0, 0, BW2, BH)
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
	-- (2026-10-21, RIVALS normal theme) the TALL Ranked tile on the right (play.png, tile-local px): "Ranked" (cap 44..93),
	-- the season under it, the gun render between, the rank line at the bottom: a 53 x 61 glyph at 20, 474 (shield; padlock
	-- when locked; your emblem once placed), the rank name (italic, cap 444..471) and the progress (italic, 478..496) centred
	local rt = tile("Ranked", RX, 0, RW, GRID_H, DUSK)
	title(rt, "Ranked", WIDE_TITLE, 0, 18, RW, 104)
	title(rt, season(), 36, 0, 116, RW, 42, 5, italic(F.bold))
	local glyph, rankName, progress = rankLine(open)
	-- (2026-10-21, port3) RIVALS' rank line (rivals_normal/play.png, tile-local): a big white shield-and-flame badge ~6 % of the
	-- screen height (59 x 70 at 19, 466), a big italic "Unranked" (cap ~444..474) and "0 / 10" under it; locked shows the
	-- same shield + "Unranked" with "LV n / 50" as the second line (no padlock, no darker shade)
	new("ImageLabel", { Name = "RankGlyph", BackgroundTransparency = 1, Image = glyph, ImageColor3 = C.white, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(19, 466), Size = UDim2.fromOffset(59, 70), ZIndex = 5, Parent = rt })
	title(rt, rankName, 56, 0, 426, RW, 60, 5, italic(F.display))
	title(rt, progress, 34, 0, 476, RW, 38, 5, italic(F.display))
	if not open then rt:SetAttribute("Locked", true) end
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
	for _, b in tiles do bindTile(b) end
	-- the column scrolls (RIVALS): a little end padding under the grid
	new("Frame", { Name = "EndPad", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, GRID_H), Size = UDim2.fromOffset(10, 60), Parent = col })
	Kit.toScale(root)
	for _, b in tiles do Kit.centreAnchor(b) end -- hover shrinks toward the centre (replica)
	-- 3D after the conversion (viewports fill their holders); the squads react: your team hops and the camera leans in on hover
	for _, sc in stages do
		local vp, scene = squadScene(sc[1], sc[2], ranked, { aspect = MW / MH, top = 0.06, bottom = SQUAD_BOTTOM[sc[2]] or 0.94, fit = 0.98 })
		livenSquad(vp, scene, sc[3])
	end
	-- (2026-10-21, RIVALS normal theme) Training is a wide bottom tile now (was the tall hero); the Ranked gun fills the band
	-- between the season line and the rank line
	-- (2026-10-21, port3) all three get the cards' pink / purple grade (grade()); Ranked is action art like RIVALS' tile: you
	-- with your gun squaring up to a red enemy, filling the tile behind the title and rank line (the gun-on-podium scene
	-- stays as the fallback when there is no character to copy)
	grade(trainingScene(tb.Scene, tb, { aspect = BW1 / BH, top = 0.06, bottom = 0.96, fit = 0.9 }), tb.Scene)
	grade(duelsScene(db.Scene, db, { aspect = BW2 / BH, top = 0.04, bottom = 0.98, fit = 0.96 }), db.Scene)
	local rvp, rscene = squadScene(rt.Scene, 1, false, { aspect = RW / GRID_H, top = 0.2, bottom = 0.97, fit = 0.98 })
	if rvp then livenSquad(rvp, rscene, rt) else rvp = rankedScene(rt.Scene, rt, { aspect = RW / GRID_H, top = 0.27, bottom = 0.74, fit = 0.94 }) end
	grade(rvp, rt.Scene, DARK_GOLD)
end

-- (2026-10-21, RIVALS 1:1) status every half second while open: busy tiles dim (no chips: RIVALS writes nothing on a tile),
-- and RIVALS' searching pill (replica: dark rounded pill, sparkle, "Searching for players..." + the mode, the clock, red X)
-- shows over the column while you search
local function tick()
	local myQ, st, since = search()
	local pad = onPad()
	for _, s in strips do
		if s.training then
			s.dim.BackgroundTransparency = (myQ or pad) and 0.45 or 1
		else
			local mine = myQ and s.q and myQ.Id == s.q.Id
			s.dim.BackgroundTransparency = ((myQ or pad) and not mine) and 0.45 or 1
		end
	end
	pill.Visible = myQ ~= nil
	if myQ then
		local e = workspace:GetServerTimeNow() - since
		local searching = st == "Searching"
		pill.Status.Text = searching and ("Searching for players" .. string.rep(".", 1 + math.floor(e) % 3)) or "Match found!"
		pill.Status.TextColor3 = searching and C.text or C.green
		pill.Mode.Text = (myQ.Ranked and "Ranked " or "") .. tostring(myQ.Mode or myQ.Id or "")
		pill.Clock.Text = clockText(e)
		pill.Close.Visible = searching
	end
end

tickNow = function() if isOpen then tick() end end

local function build()
	gui = new("ScreenGui", { Name = "PlayUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	-- (2026-10-21, RIVALS 1:1) the replica's red X: 112 x 58, right of the column, level with its top
	-- (2026-10-21, RIVALS normal theme) outside the grid's top-right corner: 16 px right of x 1661, 3 px above y 306 (was 1704,136)
	-- (2026-10-21, port3) graders: the kit's standard X (112 x 58), 12 px outside the grid's top-right, its top on the grid's top
	-- (round 2, grader A vs t0016) RIVALS' Play X is bigger than its Tasks X: 112 x 60
	local close = Kit.closeButton(UDim2.fromOffset(112, 60))
	close.Position = UDim2.fromOffset(COL_X + COL_W + (Kit.CLOSE_GAP or 12), COL_Y)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	-- the scroll column (replica): thin dark scrollbar, grows with its content
	col = new("ScrollingFrame", { Name = "Column", Position = UDim2.fromOffset(COL_X, COL_Y), Size = UDim2.fromOffset(COL_W, COL_H), BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = false, ScrollBarThickness = 10, ScrollBarImageColor3 = C.textDark, ScrollBarImageTransparency = 0.45,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root })
	-- the searching pill (replica 540 x 80, centred; here above the column so it never covers a tile)
	-- (2026-10-21, RIVALS normal theme) the grid starts lower (y 306): the pill follows it, 20 px above (was y 44)
	pill = new("Frame", { Name = "Searching", Position = UDim2.fromOffset(692, COL_Y - 100), Size = UDim2.fromOffset(540, 80), BackgroundColor3 = C.textDark,
		BackgroundTransparency = 0.25, Visible = false, ZIndex = 10, Parent = root }, { Kit.corner(8) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = (Assets.tasks and Assets.tasks.star6) or "", Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(44, 44), ZIndex = 11, Parent = pill })
	Kit.label({ Name = "Status", Text = "Searching for players.", FontFace = F.medium, TextSize = 21, Position = UDim2.fromOffset(74, 10), Size = UDim2.fromOffset(300, 28), ZIndex = 11, Parent = pill })
	Kit.label({ Name = "Mode", Text = "", FontFace = F.bold, TextSize = 27, Position = UDim2.fromOffset(74, 38), Size = UDim2.fromOffset(320, 32), ZIndex = 11, Parent = pill })
	Kit.label({ Name = "Clock", Text = "0:00", FontFace = F.bold, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(100, 80), ZIndex = 11, Parent = pill })
	local px = Kit.closeButton(UDim2.fromOffset(76, 52))
	px.Position = UDim2.fromOffset(448, 14)
	px.ZIndex = 11
	px.Parent = pill
	px.Activated:Connect(function() ctx.ask("CancelMatch"); tickNow() end)
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
		render()
		col.CanvasPosition = Vector2.zero
		tick()
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root) -- (2026-10-21, RIVALS 1:1) the replica's open: grows from the centre, 0.22 s (no per-tile pop-in)
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
function Screen.Refresh() if isOpen then tick() end end

return Screen
