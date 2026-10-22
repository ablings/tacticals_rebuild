-- UIKit/PlayScreen (ModuleScript): the lobby PLAY screen, full screen like Missions / Settings (one menu at a time).
-- RIVALS' real Play screen (2026-10-21, grade1): a tall hero tile on the left (TRAINING) beside a 3 + 2 grid (1V1 / 2V2 / 3V3,
-- then DUEL PADS + RANKED), centred, the red X just outside its top-right corner. Every tile IS the button: a lit, full-bleed live
-- 3D scene with ONE huge title; no action strips. Click a mode = search online (Searching m:ss chip, click again cancels).
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
local function lightScene(vp, raise)
	if not vp then return end
	local f = vp.Frame
	f.Ambient = Color3.fromRGB(196, 192, 182)
	f.LightColor = Color3.fromRGB(255, 244, 222)
	f.LightDirection = Vector3.new(-0.45, -0.8, 0.55)
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
	local enemyTint = ranked and Color3.fromRGB(150, 114, 52) or Color3.fromRGB(150, 78, 58)
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
local SETS = {
	squad = { floor = Color3.fromRGB(150, 144, 128), wall = Color3.fromRGB(106, 114, 74), pillar = Color3.fromRGB(176, 158, 114),
		trim = Color3.fromRGB(198, 180, 134), crate = Color3.fromRGB(150, 112, 64), h = 6, crates = true, mat = Enum.Material.Concrete },
	ranked = { floor = Color3.fromRGB(92, 86, 72), wall = Color3.fromRGB(72, 56, 28), pillar = Color3.fromRGB(150, 114, 52),
		trim = Color3.fromRGB(196, 156, 70), h = 7, mat = Enum.Material.Concrete },
	range = { floor = Color3.fromRGB(172, 156, 118), wall = Color3.fromRGB(150, 130, 92), pillar = Color3.fromRGB(98, 108, 62),
		trim = Color3.fromRGB(120, 104, 70), crate = Color3.fromRGB(150, 112, 64), h = 6, crates = true, mat = Enum.Material.Sand },
	pads = { floor = Color3.fromRGB(96, 100, 90), wall = Color3.fromRGB(88, 96, 70), pillar = Color3.fromRGB(150, 136, 98),
		trim = Color3.fromRGB(176, 158, 114), crate = Color3.fromRGB(140, 104, 60), h = 6, crates = true, mat = Enum.Material.Concrete },
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
	local ring = part(scene, Vector3.new(0.4, 12, 12), CFrame.new(0, FEET - 0.45, 0) * UPRIGHT, C.field, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(scene, Vector3.new(0.62, 3, 3), CFrame.new(0, FEET - 0.29, 0) * UPRIGHT, Color3.fromRGB(28, 30, 26), Enum.Material.Metal, Enum.PartType.Cylinder) -- centre mark
	local weapon = loadoutWeapon()
	local fighters = {}
	for side = 0, 1 do
		local tint = side == 1 and Color3.fromRGB(150, 78, 58) or nil -- (grade1) lit rust, was near-black
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
local function rankedScene(parent, target, shot, locked)
	local scene = Instance.new("Model")
	scene.Name = "Podium"
	local plate, brass = Color3.fromRGB(40, 44, 36), Color3.fromRGB(196, 156, 70)
	for _, s in { { 0, 2.4, 3.6 }, { 3.6, 1.6, 3.2 }, { -3.6, 1.1, 3.2 } } do
		part(scene, Vector3.new(s[3], s[2], 3.2), CFrame.new(s[1], s[2] / 2, 0), s[1] == 0 and plate or plate:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Metal)
		part(scene, Vector3.new(s[3] + 0.04, 0.2, 3.24), CFrame.new(s[1], s[2] - 0.1, 0), brass, Enum.Material.Metal)
	end
	local cup = ViewIcons.Build("Trophy")
	if cup then
		local cf = cup:GetBoundingBox()
		cup.WorldPivot = cf
		pcall(function() cup:ScaleTo(locked and 2.4 * 1.3 or 2.4) end) -- (2026-10-21, grade3) locked: 1.3x so the cup shows around the padlock
		local _, size = cup:GetBoundingBox()
		cup:PivotTo(CFrame.new(0, 2.4 + size.Y / 2, 0) * CFrame.Angles(0, math.rad(-16), 0))
		cup.Parent = scene
	end
	local vp = ViewIcons.Viewport(parent, scene, { view = CFrame.identity, zoom = 1, still = true })
	if not vp then return nil end
	lightScene(vp)
	local props = partsOf(scene)
	stageSet(vp, scene, props, "ranked")
	frameOn(vp, props, shot.aspect, shot.top, shot.bottom, -6, shot.fit)
	-- (2026-10-21, grade3) the greyed scene read as an empty brown box: 150 -> ~205 so the podium and cup still show
	if locked then vp.Frame.ImageColor3 = Color3.fromRGB(205, 201, 192) end
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
	-- (2026-10-21, grade1) a chunkier, solid stroke: the huge tile titles sit straight on the lit 3D scenes
	new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = math.max(2, math.floor(size / 22)), Transparency = 0, Parent = l })
	return l
end
-- (2026-10-21, RIVALS pass) tiles pop in one after another when the screen opens (setOpen sets popStep = 0; nil = no pop,
-- so a tab switch / party change re-render stays still). popIn runs before bindButton, which then reuses its UIScale.
local popStep
-- (2026-10-21, grade1: Play screen like RIVALS) the tile IS the button: a full-bleed 3D scene over a palette gradient, a soft
-- dark shade along the bottom under the title, a white sheen that fades in on hover (~15 % brighter) and a chunky 4 px cream
-- outline that shows only on hover / a controller's selection (no resting border). Pop-in is fast (6 tiles in <= 0.3 s).
local CREAM = Color3.fromRGB(236, 230, 210)
local function tile(x, y, w, h, top, bottom)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top or Color3.fromRGB(58, 64, 54), bottom or Color3.fromRGB(14, 16, 13)), Parent = f })
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = f })
	new("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Position = UDim2.fromOffset(0, math.floor(h * 0.45)),
		Size = UDim2.fromOffset(w, h - math.floor(h * 0.45)), ZIndex = 2, Parent = f },
		{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.45) }) })
	local sheen = new("Frame", { Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h),
		ZIndex = 3, Parent = f })
	-- (2026-10-21, grade2: "hover spills over the neighbours") the 4 px cream outline is drawn INSIDE the tile: a stroke on a
	-- frame inset 4 px (it grows outward to the tile's edge, never into the gutter); the hovered tile is lifted (ZIndex 2) so
	-- its scale-up draws above the others, and hover is 1.02 (was 1.03: 7.5 of the 10 px gutter on a 500 px tile)
	local ring = new("Frame", { Name = "HoverRing", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(w - 8, h - 8),
		ZIndex = 5, Parent = f }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	local st = new("UIStroke", { Color = CREAM, Transparency = 1, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
	local hov, sel = false, false
	local function show()
		local on = hov or sel
		f.ZIndex = on and 2 or 1
		Kit.tween(sheen, 0.1, { BackgroundTransparency = on and 0.85 or 1 })
		Kit.tween(st, 0.1, { Transparency = on and 0 or 1 })
	end
	f.MouseEnter:Connect(function() hov = true; show() end)
	f.MouseLeave:Connect(function() hov = false; show() end)
	f.SelectionGained:Connect(function() sel = true; show() end)
	f.SelectionLost:Connect(function() sel = false; show() end)
	if popStep then
		-- (Kit.popIn's 0.24 s Back tween x 0.04 s steps took ~0.44 s for six tiles) own pop: 0.16 s, 0.028 s apart; the
		-- UIScale is created first so bindButton reuses it for hover 1.03 / press 0.96
		local s = new("UIScale", { Name = "PopScale", Scale = 0.85, Parent = f })
		local d = popStep * 0.028
		popStep += 1
		task.delay(d, function() if f.Parent then Kit.tween(s, 0.16, { Scale = 1 }, Enum.EasingStyle.Back) end end)
	end
	Kit.bindButton(f, { hover = 1.02, press = 0.96 })
	return f
end
-- a dark overlay (unavailable while you queue / stand on a pad) and a status chip at the tile's top centre
local function dimmer(f, w, h)
	return new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h),
		ZIndex = 6, Parent = f })
end
local function chip(f, w)
	return new("TextLabel", { Name = "Chip", Text = "", FontFace = BOLD, TextSize = 20, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 14, 10), BackgroundTransparency = 0.12, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(w / 2, 14),
		Size = UDim2.fromOffset(math.min(w - 32, 300), 46), Visible = false, ZIndex = 7, Parent = f }, { new("UICorner", { CornerRadius = UDim.new(0, 12) }) })
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
	-- the greyed PLAY under the card (RIVALS' grey button): a chunky grey gradient; it shakes when pressed
	-- (2026-10-21, grade3) (user: lips look AI-made) the darker offset block under it is gone: RIVALS buttons are plain solid rounded buttons
	local playBtn = new("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((W - PW) / 2, CH + 22), Size = UDim2.fromOffset(PW, PH),
		BackgroundColor3 = white, BorderSizePixel = 0, ZIndex = 22, Parent = group }, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.gradient.grey[1], Theme.gradient.grey[2]) }),
	})
	big(playBtn, "PLAY", 46, 0, 0, PW, PH, white, nil, 23, Theme.font.display)
	-- (2026-10-21, grade3) the one X placement: 72x52, 12 px outside the card's top-right, top level with the card's top, no lip
	local x = Kit.closeButton(UDim2.fromOffset(72, 52))
	x.Position = UDim2.fromOffset(W + 12, 0)
	local xl = x:FindFirstChild("Lip")
	if xl then xl:Destroy() end
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

-- (2026-10-21, grade1: Play screen like RIVALS) RIVALS' real Play screen: a tall hero tile on the left beside a 3 + 2 grid, every
-- tile a full-bleed picture with ONE huge title, no buttons. Ours: Training is the hero (our beginner mode), 1v1 / 2v2 / 3v3 on
-- the top row, Duel Pads + Ranked below. The block is centred on the 1920 x 1080 design canvas; the red X sits just outside
-- its top-right corner, level with its top edge. Design px, converted with Kit.toScale.
local GAP = 10
local HW = 420 -- hero (Training) width
local MW, MH = 330, 290 -- mode tile
local GRID_W = HW + GAP + 3 * MW + 2 * GAP -- 1440
local GRID_H = 2 * MH + GAP -- 590
local GRID_X, GRID_Y = (1920 - GRID_W) / 2, (1080 - GRID_H) / 2
local BW = (3 * MW + 2 * GAP - GAP) / 2 -- bottom-row tile (Duel Pads, Ranked): 500
-- (2026-10-21, grade2) the tile gradient is now the SKY over each scene's back wall (the floor / wall cover the rest)
local SKY_TOP, SKY_BOTTOM = Color3.fromRGB(176, 202, 208), Color3.fromRGB(224, 220, 198)
-- (2026-10-21, grade3) the gold hall ~15 % lighter (was 214,180,112 -> 120,90,40): the locked tile read as a dark brown box
local DUSK_TOP, DUSK_BOTTOM = Color3.fromRGB(221, 191, 133), Color3.fromRGB(140, 115, 72) -- ranked: a gold dusk
-- (2026-10-21, grade3) one title size class: small / wide tiles 64 design px, the hero 72; every subtitle Rubik 20
local TITLE, HERO_TITLE, SUB = 64, 72, 20
-- where each tile's subject sits (fractions of the tile height from the top; fit = most of the width it may take). Squads: the
-- middle ~60 % with 12 % headroom (3v3 packed tighter, >= 40 %); titles moved down so they cover <= ~10 % of the figures
local SQUAD_BOTTOM = { 0.72, 0.66, 0.58 }
local WHITE = Color3.new(1, 1, 1)

local function modeCard(mode, ranked, x)
	local q = ctx.Config.QueueFor(mode.Id, ranked)
	local card = ranked and tile(x, 0, MW, MH, DUSK_TOP, DUSK_BOTTOM) or tile(x, 0, MW, MH, SKY_TOP, SKY_BOTTOM) -- (grade2) sky over the set, was field green
	-- the live squad fills the tile (the viewport is added after Kit.toScale)
	local stage = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Size = UDim2.fromOffset(MW, MH), ZIndex = 1, Parent = card })
	-- ONE huge title, lower centre so the squad stays visible above it ((grade2) 100 px on the floor, was 128 px across the legs)
	big(card, mode.Id, TITLE, 0, MH - 84, MW, 70, CREAM, nil, 4) -- (grade3) 100 -> TITLE
	if ranked then
		new("TextLabel", { Text = "RANKED", FontFace = HEAVY, TextSize = 18, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(150, 114, 52),
			Position = UDim2.fromOffset(12, MH - 40), Size = UDim2.fromOffset(94, 26), ZIndex = 5, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	end
	local entry = { q = q, card = card, chip = chip(card, MW), dim = dimmer(card, MW, MH) }
	table.insert(strips, entry)
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
		entry.flash = { text = msg, untilT = os.clock() + 5 }
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
	local GX = HW + GAP -- the grid right of the hero
	-- the hero: Training, tall on the left (pops first)
	local tb = tile(0, 0, HW, GRID_H, SKY_TOP, SKY_BOTTOM) -- (grade2) sky over the range's backstop
	local trainHold = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Size = UDim2.fromOffset(HW, GRID_H), ZIndex = 1, Parent = tb })
	big(tb, "TRAINING", HERO_TITLE, 0, GRID_H - 170, HW, 80, CREAM, nil, 4) -- (grade3) 92 -> HERO_TITLE
	-- (kids: one short line, RIVALS keeps a tile to its title)
	local tSub = Kit.label({ Text = "Try any gun for free!", FontFace = BOLD, TextSize = SUB, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, GRID_H - 86), Size = UDim2.fromOffset(HW, 30), ZIndex = 4, Parent = tb }) -- (grade3) 28 -> SUB
	new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = 2, Parent = tSub })
	table.insert(strips, { training = true, chip = chip(tb, HW), dim = dimmer(tb, HW, GRID_H) })
	tb.Activated:Connect(function()
		if search() or onPad() then return end
		Screen.Close()
		if ctx.enterTraining then ctx.enterTraining() end
	end)
	-- top row: the queues
	local stages = {}
	for i, mode in Config.Modes do
		local stage, n, card = modeCard(mode, ranked, GX + (i - 1) * (MW + GAP))
		table.insert(stages, { stage, n, card })
	end
	-- bottom row: Duel Pads, then Ranked
	local Y2 = MH + GAP
	local db = tile(GX, Y2, BW, MH, SKY_TOP, SKY_BOTTOM)
	local padHold = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Size = UDim2.fromOffset(BW, MH), ZIndex = 1, Parent = db })
	big(db, "DUEL PADS", TITLE, 0, MH - 116, BW, 70, CREAM, nil, 4) -- (grade2) 84 px lower down; (grade3) 84 -> TITLE
	-- (2026-10-21, grade3) subtitle Rubik 20, and says who you fight: anyone in the lobby
	local dSub = Kit.label({ Text = "1v1 anyone in the lobby", FontFace = BOLD, TextSize = SUB, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, MH - 44), Size = UDim2.fromOffset(BW, 28), ZIndex = 4, Parent = db })
	new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = 2, Parent = dSub })
	db.Activated:Connect(function()
		Screen.Close()
		if ctx.toPads then ctx.toPads() end
	end)
	-- Ranked keeps its dark gold (dimmer while locked, like RIVALS' Ranked art behind the padlock)
	local RX = GX + BW + GAP
	local rt = tile(RX, Y2, BW, MH, DUSK_TOP, DUSK_BOTTOM)
	-- (2026-10-21, grade2) locked or not, the trophy-on-a-podium scene fills the tile (greyed down while locked)
	local rankHold = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Size = UDim2.fromOffset(BW, MH), ZIndex = 1, Parent = rt })
	local art
	if not open then
		-- locked: a 56 px padlock over the trophy, RANKED, ONE caption "LEVEL 50", then a 22 px bar (60 % of the tile, no
		-- outline) with "LV n / 50" in Oswald 20 on it ((grade2) was a 70 px lock, a 16 px bar and a 15 px count)
		art = new("Frame", { Name = "Lock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(BW / 2, 30),
			Size = UDim2.fromOffset(56, 56), ZIndex = 4, Parent = rt })
		big(rt, "RANKED", TITLE, 0, 108, BW, 70, CREAM, nil, 4) -- (grade3) 80 -> TITLE
		local lv = math.max(1, (ctx.level and ctx.level()) or 1)
		local need = math.max(1, Config.RankedLevel)
		-- (2026-10-21, grade3) the caption says what the bar is for: "UNLOCKS AT LV 50", Rubik 20 like every subtitle
		local cap = Kit.label({ Text = "UNLOCKS AT LV " .. need, FontFace = BOLD, TextSize = SUB, TextColor3 = Color3.fromRGB(240, 222, 182),
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 188), Size = UDim2.fromOffset(BW, 28), ZIndex = 4, Parent = rt })
		new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = 2, Parent = cap })
		local BAR = math.floor(BW * 0.6)
		local track = new("Frame", { Name = "LevelBar", Position = UDim2.fromOffset((BW - BAR) / 2, 230), Size = UDim2.fromOffset(BAR, 22), BackgroundColor3 = Color3.fromRGB(14, 12, 8),
			BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 4, Parent = rt }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		new("Frame", { Size = UDim2.fromScale(math.clamp(lv / need, 0.05, 1), 1), BackgroundColor3 = Color3.fromRGB(176, 136, 54), BorderSizePixel = 0, ZIndex = 5,
			Parent = track }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local cnt = Kit.label({ Text = "LV " .. lv .. " / " .. need, FontFace = HEAVY, TextSize = 20, TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = track })
		new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = 1.5, Parent = cnt }) -- (on the text, not the bar)
	else
		-- open: a normal tile (the trophy scene fills it, one title)
		big(rt, "RANKED", TITLE, 0, MH - 116, BW, 70, CREAM, nil, 4) -- (grade3) 88 -> TITLE
		if ranked then
			local on = Kit.label({ Text = "Ranked queues ON", FontFace = BOLD, TextSize = SUB, TextColor3 = Color3.fromRGB(240, 222, 182), TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, MH - 44), Size = UDim2.fromOffset(BW, 28), ZIndex = 4, Parent = rt }) -- (grade3) Rubik SUB
			new("UIStroke", { Color = Color3.fromRGB(14, 16, 12), Thickness = 2, Parent = on })
		end
	end
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
	-- the party column, bottom left (RIVALS): the leader at the bottom with the crown, the others stacked above, a + on top;
	-- any of them opens Your Party
	local old = root:FindFirstChild("PartyColumn")
	if old then old:Destroy() end
	-- (2026-10-21, grade3) the column floated in an empty band under the grid: pinned to the grid's bottom-left, 24 px left of it, its
	-- bottom (the leader) level with the grid's bottom; members stack up beside the hero tile
	local colF = new("Frame", { Name = "PartyColumn", BackgroundTransparency = 1, Position = UDim2.fromOffset(GRID_X - 24 - 110, GRID_Y + GRID_H - 500),
		Size = UDim2.fromOffset(110, 500), Parent = root })
	local list = partyList()
	if #list == 0 then list = { player.UserId } end
	local leader = partyLeader(list)
	local order = { leader }
	for _, uid in list do if uid ~= leader then table.insert(order, uid) end end
	local y = 500 + 8 -- (grade3) + 8: the leader's bottom sits on the grid's bottom line
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
	-- 3D after the conversion (viewports fill their holders), lit and raised so the titles sit under the figures
	-- (2026-10-21, round 3: match RIVALS) the squads react: your team hops and the camera leans in on hover
	for _, sc in stages do
		-- (2026-10-21, grade2) each squad stands in a set and is aimed to fill the tile (squadScene's shot)
		local vp, scene = squadScene(sc[1], sc[2], ranked, { aspect = MW / MH, top = 0.12, bottom = SQUAD_BOTTOM[sc[2]] or 0.58, fit = 0.94 })
		livenSquad(vp, scene, sc[3])
	end
	-- (2026-10-21, round 3: match RIVALS) Training / Duel Pads: live placeholder scenes where RIVALS shows art
	trainingScene(trainHold, tb, { aspect = HW / GRID_H, top = 0.05, bottom = 0.62, fit = 0.9 })
	duelsScene(padHold, db, { aspect = BW / MH, top = 0.08, bottom = 0.56, fit = 0.9 })
	rankedScene(rankHold, rt, { aspect = BW / MH, top = open and 0.06 or 0.04, bottom = open and 0.52 or 0.5, fit = 0.9 }, not open)
	local icons = ReplicatedStorage:FindFirstChild("UIIcons")
	if not open then
		local mesh = icons and icons:FindFirstChild("Lock")
		-- (2026-10-21, round 3) the padlock sways and turns to you on hover
		local lockVp = mesh and ViewIcons.Viewport(art, mesh:Clone(), { view = CFrame.Angles(math.rad(8), math.rad(-20), 0), zoom = 1.05 })
		if lockVp then
			lightScene(lockVp)
			rt.MouseEnter:Connect(function() lockVp.SetHover(true) end)
			rt.MouseLeave:Connect(function() lockVp.SetHover(false) end)
		end
	end -- (grade2) open: the podium scene above replaces the lone trophy icon
end

-- status chips only (every half second while open). (2026-10-21, grade1: "0 SEARCHING" x3 was dead noise) a mode tile shows a
-- chip only while it has something to say: your search (Searching m:ss, tap to cancel), a match found, a failed-queue flash,
-- or N > 0 people searching. While you queue / stand on a pad, the tiles you can't use dim.
local CHIP_DARK, CHIP_RED, CHIP_GREEN = Color3.fromRGB(12, 14, 10), Color3.fromRGB(196, 52, 40), Color3.fromRGB(76, 122, 46)
local function setChip(c, text, color)
	c.Visible = text ~= nil
	if text then c.Text = text; c.BackgroundColor3 = color or CHIP_DARK end
end
local function tick()
	local cnt = counts()
	local myQ, st, since = search()
	local pad = onPad()
	for _, s in strips do
		if s.training then
			local busy = myQ or pad
			s.dim.BackgroundTransparency = busy and 0.45 or 1
			setChip(s.chip, busy and (myQ and "Not while searching" or "Not while on a pad") or nil)
		else
			local n = s.q and cnt[s.q.Id] or 0
			local mine = myQ and s.q and myQ.Id == s.q.Id
			s.dim.BackgroundTransparency = ((myQ and not mine) or (pad and not mine)) and 0.45 or 1
			if s.flash and os.clock() < s.flash.untilT then
				setChip(s.chip, s.flash.text, CHIP_RED)
			elseif mine and st == "Searching" then
				setChip(s.chip, "Searching " .. clockText(workspace:GetServerTimeNow() - since) .. " - tap to cancel")
			elseif mine then
				setChip(s.chip, "Match found!", CHIP_GREEN)
			elseif not (myQ or pad) and n > 0 then
				setChip(s.chip, n .. " searching")
			else
				setChip(s.chip, nil)
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
	-- (2026-10-21, grade3) the one X placement on every screen: 72x52 (was 112x58), 12 px outside the grid's top-right, top level with it, no lip
	local close = Kit.closeButton(UDim2.fromOffset(72, 52))
	close.Position = UDim2.fromOffset(GRID_X + GRID_W + 12, GRID_Y) -- (grade1) just outside the grid's top-right corner, level with its top
	local cl = close:FindFirstChild("Lip")
	if cl then cl:Destroy() end
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)
	body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(GRID_X, GRID_Y), Size = UDim2.fromOffset(GRID_W, GRID_H), Parent = root }) -- (grade1) centred
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
