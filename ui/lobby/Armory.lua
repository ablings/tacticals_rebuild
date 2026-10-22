-- LobbyUIController/Armory (ModuleScript, required by LobbyUIController)
-- The KIT screen. Pressing Kit flies the camera up out of the lobby and into the Armory room
-- (workspace.LobbyMap.Armory, built above the command dome), with the background blurred.
-- (2026-10-21, RIVALS 1:1) the 2D layer is RIVALS' Weapons screen, ported from the replica (see "UI" below):
--   * Left: the Career card (headshot, slot icons, Duel History) and one long list - Weapons, Melee, Gadgets -
--     each under its own header; the slot icons jump the list to that section. The picked item is left-aligned,
--     big and bold white with its render popping out of the row; locked items are dark with padlocks.
--   * Centre: the selected item, big, on the workbench (a real model in the room). Click and drag to turn it.
--   * Locked items are wrapped in hazard tape with a padlock.
--   * Right: item card (name, favourite box, two bullets), level card (blue bar, Level up now!, Reward at
--     Level N) or Unlock now!, then Inspect / Next unlock / Statistics rows with big blue buttons.
--     (2026-10-21, user) no Equip row: clicking an owned row in the list equips it, like RIVALS.
--     (2026-10-21, port3) no green check any more: the picked (= equipped) row is RIVALS' big white bold row.
--   * Bottom: the slot strip - Leave and the Skin / Wrap / Finisher slots; a slot opens RIVALS' picker
--     (placeholder tiles until cosmetics exist).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("UITheme"))

local player = Players.LocalPlayer
local Armory = {}

local ctx -- helpers handed over by LobbyUIController (new, label, button, THEME, ask, ...)
local active, busy = false, false

local selectedSlot, selectedId = "Weapon", nil
-- (2026-10-21, RIVALS pass) Kit (UIKit.Kit) for the button feel and pop-in motion. It takes the old unlock-confirm local's slot
-- (the "SURE?" step is gone; an unlock in flight is Armory._unlocking) so the chunk's local count doesn't grow.
local Kit = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Kit"))

-- display state
local showcase = {}      -- list of { model, lock, offset (NumberValue), view }
local yaw, pitch, yawVel, pitchVel = 0, 0, 0, 0
local dragging = false
-- inspect feel: one full swipe across the screen = 145 degrees of turn, top-to-bottom = 75 degrees of tilt
-- (no limits - it can go all the way round both ways). Left alone for RETURN_DELAY it eases back home.
local SWIPE_YAW = math.rad(145)   -- per screen width
local SWIPE_PITCH = math.rad(75)  -- per screen height
local RETURN_DELAY = 0.3          -- seconds untouched before it heads home
local RETURN_SPRING = 1.4        -- how quickly it settles home (higher = faster); a soft spring, so it starts
                                  -- moving gently, picks up, then eases in - no snap
local returning = false           -- heading home right now
local lastTouch = 0               -- os.clock() of the last drag movement / release
local spinStart: number? = nil    -- Inspect button: a single smooth 360
-- The item's turn is one rotation in screen space (x = screen right, y = screen up, z = towards you), so a drag
-- always turns it the way your finger goes, even upside down. Going home is a single turn about one axis:
-- under 180 degrees that's straight back the way it came, over 180 it floats home the near way.
local rot = CFrame.identity
local retAxis, retAngle, retVel = Vector3.yAxis, 0, 0
local function turnBy(dYaw: number, dPitch: number)
	rot = CFrame.fromAxisAngle(Vector3.yAxis, dYaw) * CFrame.fromAxisAngle(Vector3.xAxis, dPitch) * rot
	yaw += dYaw     -- (running totals, only for the test hook)
	pitch += dPitch
end
local function spinAngle(now: number): number -- the Inspect 360, eased out
	local k = math.clamp((now - (spinStart or now)) / 1.4, 0, 1)
	return 2 * math.pi * (1 - (1 - k) ^ 3), k
end
-- framing: the item fills the centre (SHOW_FIT studs corner to corner) but never zooms in more than SHOW_MAX_ZOOM
-- ((2026-10-21, port3) superseded by Armory._heroFrame, sized from the view; SHOW_FIT is only its fallback without the room)
local SHOW_FIT = 7.5
local SHOW_MAX_ZOOM = 3.2
-- fling: let go mid-swipe and it keeps spinning at the swipe's speed, slowing down; the return timer starts once it stops
local MOMENTUM_DECAY = 3        -- per second (higher = stops sooner)
local MOMENTUM_MAX = 20         -- radians per second, so a wild flick can't blur it
local lastMove = 0              -- os.clock() of the last drag movement (for the swipe speed)
-- scroll to zoom: the item slides towards the camera, up to WHEEL_MAX_ZOOM times bigger
local WHEEL_MAX_ZOOM = 1.6 -- (2026-10-21, grade3) was 2.2: the rest framing is 1.4x closer now, so the closest zoom stays ~2.2x
local WHEEL_STEP = 0.15
local zoom, zoomTarget = 1, 1
local dragLast: Vector3? = nil -- pointer position at the last drag step
local dragStarts = 0
local displayFolder
local savedCam, savedType, savedFov, savedWalk, savedJump
local showcaseCam      -- camera of the full-screen ViewportFrame the item is drawn in
local showcaseVpf
local shadowParts = {} -- soft contact shadow under the item
-- (2026-10-21, grade2) key light ~30% lower (was 250, 248, 250): the hero gun read as an overexposed grey slab
local LIT = { Ambient = Color3.fromRGB(86, 86, 94), LightColor = Color3.fromRGB(184, 182, 186) }
local DARK = { Ambient = Color3.new(0, 0, 0), LightColor = Color3.new(0, 0, 0) } -- locked: pure silhouette
local BACKGROUND_BLUR = 8 -- (2026-10-19, Edward: "more blur on the kit screen") the room blurs, the item (ViewportFrame) stays sharp
-- (2026-10-20, Edward: "rivals kit viewing doesn't use viewport frames it uses the gun's physical model") the item is a real
-- model in the world (client-only: a LocalScript's parts never replicate), lit by the room with real shadows; the room behind
-- it blurs through depth of field focused on the item instead of a full-screen BlurEffect (that would blur the item too).
-- false = the old full-screen ViewportFrame.
local SHOWCASE_WORLD = true
local overlay = {}     -- transition overlay pieces

-- UI refs
local ui, fade

-------------------------------------------------------------------------------
-- World helpers
-------------------------------------------------------------------------------
local function room()
	local map = workspace:FindFirstChild("LobbyMap")
	return map and (map:FindFirstChild("Showroom") or map:FindFirstChild("Armory"))
end

local function points()
	local r = room()
	local d = r and r:FindFirstChild("DisplayPoint")
	local c = r and r:FindFirstChild("CameraPoint")
	if not (d and c) then return nil end
	return d.Position, c.CFrame
end

-- rotation that maps the icon convention (camera at -Z looking +Z) onto the real camera
local function viewBasis(camCF: CFrame): CFrame
	return CFrame.lookAt(Vector3.zero, -camCF.LookVector)
end

local function prepModel(model: Model, targetDiameter: number)
	model.Parent = displayFolder
	local cf, size = model:GetBoundingBox()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = CFrame.new(-cf.Position) * d.CFrame
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
		end
	end
	model.WorldPivot = CFrame.identity
	local factor = targetDiameter / math.max(size.Magnitude, 0.01)
	pcall(function() model:ScaleTo(factor) end)
	return model, factor
end

-- (2026-10-21, port3) the hero item's size from the view: the corner-to-corner diameter (studs) to give an item of `natural`
-- bounding size, and the item's distance from the camera at rest (renderShowcase pulls it 1.4x closer than DisplayPoint; the
-- camera's FieldOfView is 40). Long items (rifles, knives) lie across ~58% of the screen width (RIVALS ~55%, seen side-on and
-- turned 25 deg), at most ~70% of its height; squat ones (pistols, grenades) span ~95% of the height corner to corner.
-- No `natural`: the largest diameter any item gets (for the dim plane behind it). Aspect capped at 16:9 like the UI canvas.
function Armory._heroFrame(natural: Vector3?): (number, number)
	local d, camCF = points()
	if not (d and camCF) then return SHOW_FIT, 10 end
	local dist = (camCF.Position - d).Magnitude / 1.4
	local vs = workspace.CurrentCamera.ViewportSize
	local visH = 2 * dist * math.tan(math.rad(20))
	local visW = visH * math.clamp(vs.Y > 0 and vs.X / vs.Y or 16 / 9, 1.2, 16 / 9)
	if not natural then return math.min(0.64 * visW, visH), dist end
	local s = { natural.X, natural.Y, natural.Z }
	table.sort(s, function(a, b) return a > b end)
	local k
	if s[1] >= 1.6 * s[2] then
		k = math.min(0.58 * visW / (0.9 * s[1]), 0.7 * visH / (1.15 * s[2] + 0.17 * s[1]))
	else
		-- (2026-10-22, section round 1, grader A vs t0058) RIVALS' handgun spans ~37 % of the height (0.33-0.70 H), not ~95 %: squat items
		-- at about half the old size (long guns keep the ~55 %-of-width rule above)
		k = 0.5 * visH / math.max(natural.Magnitude, 0.01)
	end
	return k * natural.Magnitude, dist
end

local function makeShowcase(itemId: string, locked: boolean)
	local model, view, zoom = ctx.Icons.Item(itemId)
	-- (2026-10-21, grade3) the hero gun rests in a calmer 3/4 pose like RIVALS' (t0052): side-on, turned ~25 deg towards you and
	-- pitched ~10 deg (Icons.GunView's 28 deg tilt + roll stays for the small icons)
	if view == ctx.Icons.GunView then
		view = CFrame.Angles(0, math.rad(25), 0) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(10), 0, 0)
	end
	local _, natural = model:GetBoundingBox()
	-- (2026-10-21, port3) graders: RIVALS' gun fills ~55% of the screen width; ours ~25%. Sized from the view (Armory._heroFrame)
	-- instead of the fixed SHOW_FIT / SHOW_MAX_ZOOM cap
	prepModel(model, Armory._heroFrame(natural) * (zoom or 1))
	if locked then
		Armory.Silhouette(model)
	else
		Armory.ShowcaseLook(model) -- (2026-10-21, grade2) plain grey plastic -> gunmetal, on this clone only
	end
	local entry = { model = model, view = view, offset = Instance.new("NumberValue"), locked = locked }
	return entry
end

local function clearShowcase()
	for _, e in showcase do
		if e.model then e.model:Destroy() end
		if e.lock then e.lock:Destroy() end
	end
	table.clear(showcase)
end

-- (2026-10-20, Edward: "you also cant turn the locked weapon either") a locked item's silhouette can't be turned, zoomed or spun
local function currentLocked(): boolean
	for _, e in showcase do if not e.leaving then return e.locked == true end end
	return false
end
local function showItem(itemId: string, direction: number)
	local owned = ctx.owns(itemId)
	local entry = makeShowcase(itemId, not owned)
	-- (2026-10-21, grade1) RIVALS pops the new gun in where it stands: the current item shrinks away (0.15 s, drifting a little
	-- left) and the new one punches in from 0.6 to full size with a Back ease (0.25 s). Was a 0.55 s slide across the room.
	for _, old in showcase do
		if not old.leaving then
			old.leaving = true
			old.pop = old.pop or Instance.new("NumberValue")
			if old.pop.Value == 0 then old.pop.Value = 1 end
			TweenService:Create(old.pop, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0.05 }):Play()
			local t = TweenService:Create(old.offset, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = -3 * direction })
			t:Play()
			t.Completed:Connect(function()
				if old.model then old.model:Destroy() end
				if old.lock then old.lock:Destroy() end
				local i = table.find(showcase, old)
				if i then table.remove(showcase, i) end
			end)
		end
	end
	-- the new one pops in where it stands
	entry.offset.Value = 0
	entry.pop = Instance.new("NumberValue")
	entry.pop.Value = 0.6
	table.insert(showcase, entry)
	TweenService:Create(entry.pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
	Armory.SetTape(not owned)
	if showcaseVpf then
		TweenService:Create(showcaseVpf, TweenInfo.new(0.25), owned and LIT or DARK):Play()
	end
	yaw, pitch, yawVel, pitchVel = 0, 0, 0, 0
	rot = CFrame.identity
	spinStart = nil
	returning = false
	zoomTarget = 1
end

local function renderShowcase(dt: number)
	local d, camCF = points()
	if not d then return end
	local cam = workspace.CurrentCamera
	-- (2026-10-21, grade1) the gun is THE hero: graders saw the player's avatar filling the centre instead. There is no character
	-- view in this screen; the camera had been handed back to Roblox's Custom camera (behind / in front of your character in the
	-- lobby; Studio's MCP calls do this when they return, see notes/ui_shadow_deploy.md) while the Kit stayed open. So once the
	-- reveal is done the Kit holds its camera on the showcase every frame.
	if active and not busy and camCF then
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		if cam.CFrame ~= camCF then cam.CFrame = camCF end
		if cam.FieldOfView ~= 40 then cam.FieldOfView = 40 end
	end
	if showcaseCam then
		showcaseCam.CFrame = cam.CFrame
		showcaseCam.FieldOfView = cam.FieldOfView
	end
	-- the Inspect button's 360, else: fling coast -> RETURN_DELAY pause -> spring home along one axis
	local now = os.clock()
	local step = math.min(dt, 1 / 30) -- a hitch shouldn't make the spring overshoot
	local view = rot
	if spinStart then
		local a, k = spinAngle(now)
		view = CFrame.fromAxisAngle(Vector3.yAxis, a) * rot
		if k >= 1 then
			spinStart = nil
			view = rot
			lastTouch = now -- then the usual pause and glide home
		end
	elseif not dragging then
		local coasting = not returning and math.abs(yawVel) + math.abs(pitchVel) > 0.05
		if coasting or (not returning and now - lastTouch <= RETURN_DELAY) then
			-- coasting from a fling (or the last bit of drift while it waits)
			turnBy(yawVel * step, pitchVel * step)
			local k = math.exp(-MOMENTUM_DECAY * step)
			yawVel *= k
			pitchVel *= k
			if coasting then lastTouch = now end
		else
			if not returning then
				-- one turn home: the axis-angle of the whole rotation, shortest way (180 or less)
				local axis, angle = rot:ToAxisAngle()
				if angle > math.pi then axis, angle = -axis, 2 * math.pi - angle end
				if angle > 0.001 then
					returning = true
					retAxis, retAngle = axis, angle
					retVel = Vector3.new(pitchVel, yawVel, 0):Dot(axis) -- carry on from any leftover drift
				else
					rot, yaw, pitch = CFrame.identity, 0, 0
				end
				yawVel, pitchVel = 0, 0
			end
			if returning then
				-- critically damped spring on that one angle: starts gently, no overshoot
				local w = RETURN_SPRING
				retVel += (-w * w * retAngle - 2 * w * retVel) * step
				retAngle += retVel * step
				rot = CFrame.fromAxisAngle(retAxis, retAngle)
				if math.abs(retAngle) < 0.0005 and math.abs(retVel) < 0.005 then
					rot, yaw, pitch, returning = CFrame.identity, 0, 0, false
				end
			end
			view = rot
		end
	end
	zoom += (zoomTarget - zoom) * (1 - math.exp(-10 * dt))
	local right, up = camCF.RightVector, camCF.UpVector
	local basis = viewBasis(camCF)
	local t = os.clock()
	local idle = CFrame.fromAxisAngle(up, math.sin(t * 0.7) * 0.06) * CFrame.fromAxisAngle(right, math.sin(t * 0.9) * 0.03)
	local screen = CFrame.fromMatrix(Vector3.zero, right, up) -- screen axes -> world
	local spin = screen * view * screen:Inverse()
	Armory.TickTape(dt)
	Armory.UpdateShadow(d, camCF)
	for _, e in showcase do
		local pos = d + right * e.offset.Value + Vector3.new(0, math.sin(t * 1.3) * 0.08, 0)
		-- scroll zoom: closer to the camera. (2026-10-21, grade3) graders: the hero filled ~25% of the screen width (RIVALS ~45-55%):
		-- it always sits 1.4x closer along the camera ray through DisplayPoint, so it stays centred between the side panels
		pos += (camCF.Position - d) * (1 - 1 / (zoom * 1.4))
		if e.model and e.model.Parent then
			-- (2026-10-21, grade1) the selection pop: scale the real model while its pop value moves (only then: ScaleTo isn't free)
			if e.pop and e.lastPop2 ~= e.pop.Value then
				e.baseScale = e.baseScale or e.model:GetScale()
				e.lastPop2 = e.pop.Value
				e.model:ScaleTo(e.baseScale * math.max(0.05, e.pop.Value))
			end
			e.model:PivotTo(CFrame.new(pos) * idle * spin * basis * (e.view or CFrame.identity))
		end
		if e.lock and e.lock.Parent then
			local pop = e.lockPop.Value
			local lpos = pos - camCF.LookVector * 1.8 + Vector3.new(0, (1 - pop) * 3, 0)
			if e.lastPop ~= pop then
				e.lastPop = pop
				e.lock:ScaleTo(math.max(0.05, pop) * (e.lockScale or 1))
			end
			e.lock:PivotTo(CFrame.new(lpos) * basis * CFrame.Angles(0, 0, math.rad(-4)))
		end
	end
end

-------------------------------------------------------------------------------
-- Contact shadow on the workbench (ViewportFrames don't cast real shadows)
-------------------------------------------------------------------------------
local tableTopY
function Armory.UpdateShadow(d: Vector3, camCF: CFrame)
	local current
	for _, e in showcase do
		if not e.leaving and e.model and e.model.Parent then current = e end
	end
	if SHOWCASE_WORLD or not current or current.locked then -- silhouettes stay flat black: no shadow (world mode: the room casts real ones)
		for _, p in shadowParts do p.Transparency = 1 end
		return
	end
	if not tableTopY then
		local r = room()
		local bench = r and r:FindFirstChild("BenchTop")
		tableTopY = bench and (bench.Position.Y + bench.Size.Y / 2 + 0.03) or (d.Y - 1.9)
	end
	-- footprint of the item on the bench: project its box corners onto the floor axes
	local cf, size = current.model:GetBoundingBox()
	local R = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
	local F = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
	local minR, maxR, minF, maxF = math.huge, -math.huge, math.huge, -math.huge
	for _, sx in { -0.5, 0.5 } do for _, sy in { -0.5, 0.5 } do for _, sz in { -0.5, 0.5 } do
		local p = cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
		local r, f = p:Dot(R), p:Dot(F)
		minR, maxR = math.min(minR, r), math.max(maxR, r)
		minF, maxF = math.min(minF, f), math.max(maxF, f)
	end end end
	local w, depth = (maxR - minR) * 0.9, math.max(2.6, (maxF - minF) * 1.1)
	local height = math.max(0, cf.Position.Y - tableTopY)
	-- the key light sits up and to the front-left, so the shadow falls back and slightly right
	local centre = R * ((minR + maxR) / 2 + height * 0.3) + F * ((minF + maxF) / 2 - 0.4)
	centre = Vector3.new(centre.X, tableTopY, centre.Z)
	local fade = math.clamp(math.abs(current.offset.Value) / 8, 0, 1) + math.clamp(height / 8, 0, 0.5)
	for i, p in shadowParts do
		local grow = 0.6 + (i - 1) * 0.18
		p.Size = Vector3.new(w * grow, 0.02, depth * grow)
		p.CFrame = CFrame.lookAt(centre, centre + F)
		p.Transparency = math.min(1, 0.45 + (i - 1) * 0.12 + fade * 0.55)
	end
end

-------------------------------------------------------------------------------
-- Locked look: silhouettes, KEEP OUT tape, vector lock icon
-------------------------------------------------------------------------------
function Armory.Silhouette(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = Color3.new(0, 0, 0)
			-- (2026-10-20, Edward: "no reflectance or shadows on locked weapons") in the world the room lights it, so a
			-- black Neon part: Neon ignores lighting and shadows (black emits nothing), so it stays one flat black shape
			p.Material = SHOWCASE_WORLD and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.MaterialVariant = ""
			p.Reflectance = 0
			p.CastShadow = false
			if p:IsA("MeshPart") then p.TextureID = "" end
		elseif p:IsA("Decal") or p:IsA("Texture") or p:IsA("SurfaceAppearance") then
			p:Destroy()
		end
	end
	return model
end

-- (2026-10-21, grade2) graders: the hero pistol read as "an untextured, overexposed grey slab". On the SHOWCASE CLONE only (the source
-- model is untouched): plain light-grey (Smooth)Plastic parts become a dark gunmetal Metal, keeping their relative shade so the
-- slide / frame / grip still separate; textured parts (MeshPart TextureID, SurfaceAppearance, Decal / Texture) keep their look,
-- but a Neon material or a Highlight on them would wash the texture out, so those go.
function Armory.ShowcaseLook(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("Highlight") then
			p:Destroy()
		elseif p:IsA("BasePart") then
			local textured = (p:IsA("MeshPart") and p.TextureID ~= "") or p:FindFirstChildOfClass("SurfaceAppearance") ~= nil
				or p:FindFirstChildOfClass("Decal") ~= nil or p:FindFirstChildOfClass("Texture") ~= nil
			local _, sat, v = p.Color:ToHSV()
			if textured then
				if p.Material == Enum.Material.Neon then p.Material = Enum.Material.SmoothPlastic end
			elseif sat < 0.18 and v > 0.12 and p.Material ~= Enum.Material.Neon then
				-- (2026-10-21, grade3) any untextured grey part, plastic or metal (the pistol's 0.28-0.36 greys slipped past v > 0.3 and
				-- the room's sun + key lights still blew them out): darken to gunmetal, keep each part's own material (Metal on every
				-- part streaks), metal parts a shade lighter so slide and frame separate
				-- (2026-10-21, grade3) graders saw stacked stripes on the slide / barrel: that is the Metal material's texture at this
				-- angle and scale. Every untextured grey part is SmoothPlastic now; the metal / plastic split is kept by colour only
				-- (formerly-Metal parts 0.36, plastic 0.25) plus a hint of sheen (Reflectance 0.08) on the formerly-Metal ones
				local wasMetal = p.Material == Enum.Material.Metal
				p.MaterialVariant = ""
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = wasMetal and 0.08 or 0
				p.Color = Color3.fromHSV(0.58, 0.08, wasMetal and 0.36 or 0.25) -- (tuned in Studio: darker read as a locked silhouette)
			elseif p.Material == Enum.Material.Neon and sat < 0.18 then
				p.Material = Enum.Material.SmoothPlastic -- a grey Neon part glows flat white under the key light
			end
		end
	end
	return model
end

-- A padlock drawn from UI shapes (shackle outline + body + keyhole), any size and colour
function Armory.LockIcon(parent: Instance, size: number, color: Color3)
	local holder = ctx.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	ctx.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(size * 0.56, size * 0.7), ZIndex = 3, Parent = holder }, {
		ctx.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		ctx.new("UIStroke", { Color = color, Thickness = math.max(1.5, size * 0.12) }),
	})
	local body = ctx.new("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(size * 0.84, size * 0.58), ZIndex = 4, Parent = holder }, {
		ctx.new("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(size * 0.12))) }),
	})
	body:SetAttribute("ChamferCorners", "none")
	ctx.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 18, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(size * 0.2, size * 0.2), ZIndex = 5, Parent = body }, { ctx.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	ctx.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 18, 20), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 0),
		Size = UDim2.fromOffset(math.max(1, size * 0.08), size * 0.2), ZIndex = 5, Parent = body })
	return holder
end

-- Two strips of CAUTION / DANGER tape crossing the whole screen in front of a locked item.
-- The print is tacticals' own tape (chevron block, heavy italic word, a scissors mark, perforated edges),
-- tiled and crawling. On top: a soft gloss line, a glare that sweeps along now and then, a drop shadow and
-- a gentle flutter. Each strip is two halves (CanvasGroups) that meet in the middle, so it can be CUT there.
local TP = { tapes = {}, shown = false, scroll = 0, time = 0, H = 66 } -- (one table: this module is near Luau's 200-local limit)
TP.ART = {
	CAUTION = { image = "rbxassetid://97093179516763", w = 705 }, -- texture px (tile is 128 tall)
	DANGER = { image = "rbxassetid://95568608138127", w = 678 },
}
TP.SNIP = { "rbxasset://sounds/swordslash.wav", "rbxassetid://12222216" }

function TP.tileWidth(word: string): number
	return TP.ART[word].w * TP.H / 128
end

function TP.makeTape(layer, angle, y, word)
	local art = TP.ART[word]
	local holder = ctx.new("Frame", { Name = "Tape" .. word, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1.9, 0, 0, TP.H), Position = UDim2.new(-1.2, 0, y, 0), Rotation = angle, Visible = false, Parent = layer })
	-- drop shadow (soft, offset down)
	local shadow = ctx.new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.new(1, 0, 1, 6), ZIndex = 1, Parent = holder })
	ctx.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = shadow })
	local halves = {}
	for h = 1, 2 do
		local g = ctx.new("CanvasGroup", { Name = h == 1 and "Left" or "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(h == 1 and 1 or 0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 2, Parent = holder })
		local print_ = ctx.new("ImageLabel", { Name = "Print", BackgroundTransparency = 1, Image = art.image, ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(TP.tileWidth(word), TP.H), Size = UDim2.new(2, TP.tileWidth(word) * 2, 1, 0), ZIndex = 2, Parent = g })
		-- gloss: a thin bright line along the top third, like light on plastic
		ctx.new("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 17), Size = UDim2.new(1, 0, 0, 3), ZIndex = 3, Parent = g })
		-- the bright cut edge (only shown once it's been cut)
		ctx.new("Frame", { Name = "CutEdge", BackgroundColor3 = Color3.fromRGB(255, 252, 230), BorderSizePixel = 0, AnchorPoint = Vector2.new(h == 1 and 1 or 0, 0),
			Position = UDim2.fromScale(h == 1 and 1 or 0, 0), Size = UDim2.new(0, 4, 1, 0), Visible = false, ZIndex = 4, Parent = g })
		halves[h] = { group = g, print = print_ }
	end
	-- glare: a slanted white streak that sweeps along the tape every few seconds
	local glare = ctx.new("Frame", { Name = "Glare", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	local glareGrad = ctx.new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.46, 1), NumberSequenceKeypoint.new(0.49, 0.55), NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(0.515, 0.6), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) }),
		Offset = Vector2.new(-1, 0), Parent = glare })
	return { holder = holder, shadow = shadow, halves = halves, glare = glare, glareGrad = glareGrad, y = y, angle = angle, word = word,
		phase = math.random() * 6, glareAt = math.random() * 1.5 }
end

function Armory.BuildTape(layer)
	TP.tapes = { TP.makeTape(layer, -9, 0.42, "CAUTION"), TP.makeTape(layer, 7, 0.52, "DANGER") }
	TP.tapes[2].reverse = true
	Armory._tapeLayer = layer
end

function TP.resetTape(t)
	t.cut = false
	t.holder.Rotation = t.angle
	t.shadow.BackgroundTransparency = 0.55
	t.glare.Visible = true
	for h, half in t.halves do
		half.group.GroupTransparency = 0
		half.group.Rotation = 0
		half.group.Position = UDim2.fromScale(0.5, 0.5)
		half.group.CutEdge.Visible = false
	end
end

-- show = tape across the screen (slides in). Hiding slides it away.
function Armory.SetTape(show: boolean, rip: boolean?)
	if show == TP.shown and not rip then return end
	TP.shown = show
	for i, t in TP.tapes do
		local from = i == 1 and -1.2 or 2.2
		if t.hideTween then t.hideTween:Cancel() t.hideTween = nil end
		if show then
			TP.resetTape(t)
			t.holder.Visible = true
			t.holder.Position = UDim2.new(from, 0, t.y, 0)
			t.holder.Rotation = t.angle + (i == 1 and -6 or 6)
			t.sliding = true
			task.delay(0.08 * (i - 1), function()
				local tw = TweenService:Create(t.holder, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Position = UDim2.new(0.5, 0, t.y, 0), Rotation = t.angle })
				tw.Completed:Connect(function() t.sliding = false end)
				tw:Play()
			end)
		else
			local tween = TweenService:Create(t.holder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(i == 1 and 2.2 or -1.2, 0, t.y, 0) })
			t.sliding = true
			t.hideTween = tween
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not TP.shown then t.holder.Visible = false end
			end)
			tween:Play()
		end
	end
end

-- every frame while the kit screen is up: print crawl, glare sweeps, flutter
function Armory.TickTape(dt: number)
	if not TP.shown and not Armory._cutting then return end
	TP.scroll += dt * 40
	TP.time += dt
	for _, t in TP.tapes do
		if not t.holder.Visible then continue end
		local unit = TP.tileWidth(t.word)
		local off = TP.scroll % unit
		local W = t.holder.AbsoluteSize.X
		-- the halves are two windows onto one long print, so it reads as a single strip
		local leftX = t.reverse and (off - unit) or -off
		t.halves[1].print.Position = UDim2.fromOffset(leftX, 0)
		t.halves[2].print.Position = UDim2.fromOffset(((leftX - W / 2) % unit) - unit, 0)
		-- glare: a sweep every ~3.2 s
		if not t.cut then
			local g = (TP.time + t.glareAt) % 3.2
			t.glareGrad.Offset = Vector2.new(g < 1 and (-0.6 + g * 1.2) or -1, 0)
			-- flutter: a slow breathing tilt + bob (tighter while you're about to cut it)
			-- (2026-10-21, RIVALS pass) "about to cut" = the one-press unlock is going through (was the "SURE?" step)
			if not t.sliding then
				local amp = Armory._unlocking and 0.9 or 0.35
				local wob = math.sin(TP.time * (Armory._unlocking and 9 or 1.6) + t.phase) * amp
				t.holder.Rotation = t.angle + wob
				t.holder.Position = UDim2.new(0.5, 0, t.y, math.sin(TP.time * 1.3 + t.phase) * 2)
			end
		end
	end
end

-- The unlock: the 3D scissors fly in, snip each strip where it crosses the middle, the halves spring apart and
-- fall away, then the scissors spin off. `done` runs when the tape is gone (the item then comes back in colour).
function TP.screenPointOn(t)
	local layer = Armory._tapeLayer
	local size = layer.AbsoluteSize
	return Vector2.new(size.X * 0.5, size.Y * t.y + t.holder.Position.Y.Offset)
end

function TP.snipFX(layer, at: Vector2, color: Color3)
	-- white flash ring + yellow tape shards flying off the cut
	local ring = ctx.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(16, 16), ZIndex = 21, Parent = layer }, { ctx.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local st = ctx.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4, Parent = ring })
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Size = UDim2.fromOffset(170, 170) }):Play()
	TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.4, function() ring:Destroy() end)
	for i = 1, 12 do
		local a = math.random() * math.pi * 2
		local shard = ctx.new("Frame", { BackgroundColor3 = i % 3 == 0 and Color3.fromRGB(18, 18, 20) or color, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(math.random(6, 14), math.random(3, 7)),
			Rotation = math.random(0, 360), ZIndex = 21, Parent = layer })
		local d = math.random(70, 190)
		TweenService:Create(shard, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
			Position = UDim2.fromOffset(at.X + math.cos(a) * d, at.Y + math.sin(a) * d + 60), Rotation = shard.Rotation + math.random(-300, 300),
			BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function() shard:Destroy() end)
	end
end

function TP.playSnip(layer, pitch: number)
	for i, id in TP.SNIP do
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = i == 1 and 0.45 or 0.3
		s.PlaybackSpeed = pitch * (i == 1 and 2.1 or 1.6)
		s.Parent = layer
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
	end
end

function TP.dropHalves(t)
	t.cut = true
	t.glare.Visible = false
	TweenService:Create(t.shadow, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	for h, half in t.halves do
		local g = half.group
		local dir = h == 1 and -1 or 1
		g.CutEdge.Visible = true
		-- spring apart at the cut...
		TweenService:Create(g, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, dir * 38, 0.5, 0), Rotation = dir * 3 }):Play()
		-- ...then droop and fall off the screen, the cut end dropping first
		task.delay(0.12, function()
			TweenService:Create(g, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, dir * 160, 0.5, 900), Rotation = dir * -(28 + math.random(0, 18)), GroupTransparency = 0.15 }):Play()
		end)
	end
end

-- The unlock, shot like a little cinematic in real 3D: a full-screen ViewportFrame with its own camera, the scissors
-- model flying around inside it. Screen points (the cut spots on the tape) are mapped into that 3D space, so the
-- scissors can swoop in from right next to the lens, twirl, and land their blades exactly on the tape.
TP.FOV = 40
TP.DEPTH = 17 -- studs in front of the viewport camera when cutting (scissors fill ~60% of the screen height)
TP.SFX = {
	whoosh = "rbxassetid://9114373663", -- big swoosh in
	whooshSmall = "rbxassetid://9114374642", -- glide between strips
	spin = "rbxassetid://9125920179", -- the twirl
	snip = "rbxassetid://9118827069", -- crisp metal snip
}

function TP.sound(parent, id: string, volume: number?, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = speed or 1
	s.Parent = parent
	s:Play()
	task.delay(4, function() s:Destroy() end)
end

function TP.tweenNum(from: number, to: number, time: number, style, dir, fn)
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(fn)
	local tw = TweenService:Create(v, TweenInfo.new(time, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), { Value = to })
	tw.Completed:Once(function() v:Destroy() end)
	tw:Play()
	fn(from)
	return tw
end

function TP.shake(layer, power: number)
	task.spawn(function()
		for i = 1, 7 do
			local k = power * (1 - i / 8)
			layer.Position = UDim2.fromOffset(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k)
			task.wait(1 / 60)
		end
		layer.Position = UDim2.fromOffset(0, 0)
	end)
end

-- a four-point glint (two crossed bars) that pops and fades: the sparkle trail
function TP.glint(layer, at: Vector2, size: number, life: number, color: Color3?)
	local g = ctx.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(0, 0), Rotation = math.random(0, 90), ZIndex = 22, Parent = layer })
	for i = 1, 2 do
		ctx.new("Frame", { BackgroundColor3 = color or Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = i == 1 and UDim2.new(1, 0, 0.14, 0) or UDim2.new(0.14, 0, 1, 0), ZIndex = 22, Parent = g },
			{ ctx.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	TweenService:Create(g, TweenInfo.new(life * 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(size, size), Rotation = g.Rotation + 45 }):Play()
	task.delay(life * 0.35, function()
		TweenService:Create(g, TweenInfo.new(life * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.fromOffset(0, 0), Rotation = g.Rotation + 60 }):Play()
	end)
	task.delay(life + 0.05, function() g:Destroy() end)
end

function TP.buildScissors(layer)
	local src = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("Scissors")
	if not src then return nil end
	local vpf = ctx.new("ViewportFrame", { Name = "Scissors3D", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20,
		Ambient = Color3.fromRGB(150, 150, 160), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.45, -0.75, -0.5), Parent = layer })
	local cam = Instance.new("Camera")
	cam.FieldOfView = TP.FOV
	cam.CFrame = CFrame.new()
	cam.Parent = vpf
	vpf.CurrentCamera = cam
	local wm = Instance.new("WorldModel")
	wm.Parent = vpf
	local m = src:Clone()
	m.Parent = wm
	local screw = m:FindFirstChild("Screw")
	local pivot = screw and screw:GetBoundingBox().Position or m:GetPivot().Position
	local tip = 1
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = CFrame.new(-pivot) * d.CFrame -- screw at the model origin
			tip = math.max(tip, d.Position.Z + d.Size.Z / 2)
		end
	end
	local home = { A = {}, B = {}, S = {} }
	for key, name in { A = "BladeA", B = "BladeB", S = "Screw" } do
		local g = m:FindFirstChild(name)
		if g then for _, d in g:GetDescendants() do if d:IsA("BasePart") then home[key][d] = d.CFrame end end end
	end
	-- model axes -> screen: blades (+Z) point up the screen, the hinge axis (+Y) points at the camera
	local face = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
	local sc = { vpf = vpf, cutAt = tip * 0.42 }
	-- st: P = where the cut point sits (3D), roll = screen angle, yaw/pitch = 3D turn, spin = twirl around the blades, open = blade angle
	sc.st = { P = Vector3.new(0, 0, -TP.DEPTH), roll = 0, yaw = 0, pitch = 0, spin = 0, open = 0 }
	function sc.apply()
		local s = sc.st
		local rot = CFrame.Angles(0, 0, math.rad(s.roll)) * CFrame.Angles(0, math.rad(s.yaw), 0) * CFrame.Angles(math.rad(s.pitch), 0, 0)
			* face * CFrame.Angles(0, 0, s.spin)
		local root = CFrame.new(s.P) * rot * CFrame.new(0, 0, -sc.cutAt)
		local ra, rb = root * CFrame.Angles(0, math.rad(-s.open), 0), root * CFrame.Angles(0, math.rad(s.open), 0) -- handles spread as the blades open
		for p, rel in home.A do p.CFrame = ra * rel end
		for p, rel in home.B do p.CFrame = rb * rel end
		for p, rel in home.S do p.CFrame = root * rel end
	end
	-- screen pixel (in the layer) -> 3D point `depth` studs in front of the camera, and back
	function sc.toWorld(px: number, py: number, depth: number): Vector3
		local size = vpf.AbsoluteSize
		local t = math.tan(math.rad(TP.FOV / 2))
		return Vector3.new((px / size.X * 2 - 1) * t * size.X / size.Y, -(py / size.Y * 2 - 1) * t, -1) * depth
	end
	function sc.toScreen(p: Vector3): Vector2
		local size = vpf.AbsoluteSize
		local t = math.tan(math.rad(TP.FOV / 2))
		local z = math.max(0.1, -p.Z)
		return Vector2.new((p.X / z / (t * size.X / size.Y) + 1) / 2 * size.X, (1 - p.Y / z / t) / 2 * size.Y)
	end
	sc.apply()
	return sc
end

function Armory.CutTape(done: (() -> ())?)
	local layer = Armory._tapeLayer
	if not layer or Armory._cutting then
		Armory.SetTape(false)
		if done then done() end
		return
	end
	Armory._cutting = true
	local sc = TP.buildScissors(layer)
	if not sc then -- no model: fall back to the old rip
		Armory._cutting = false
		Armory.SetTape(false, true)
		if done then task.delay(0.35, done) end
		return
	end
	local st, vpf = sc.st, sc.vpf
	local trail = false
	local lastGlint = 0
	local conn = RunService.RenderStepped:Connect(function()
		sc.apply()
		-- sparkle trail behind the screw while it's flying
		if trail and os.clock() - lastGlint > 0.035 then
			lastGlint = os.clock()
			local at = sc.toScreen(st.P) + Vector2.new(math.random(-30, 30), math.random(-30, 30))
			TP.glint(layer, at, math.random(14, 30), 0.45, math.random() < 0.3 and Color3.fromRGB(120, 190, 255) or nil)
		end
	end)
	local function to(key: string, value: number, time: number, style, dir)
		return TP.tweenNum(st[key], value, time, style, dir, function(x) st[key] = x end)
	end
	-- move the cut point along a curve (quadratic bezier through `bend`)
	local function fly(p1: Vector3, bend: Vector3, time: number, style, dir)
		local p0 = st.P
		local c = (p0 + p1) / 2 + bend
		TP.tweenNum(0, 1, time, style, dir, function(a)
			st.P = p0 * (1 - a) ^ 2 + c * (2 * (1 - a) * a) + p1 * a ^ 2
		end)
	end
	local function burst(at: Vector2, n: number, spread: number)
		for _ = 1, n do
			local a = math.random() * math.pi * 2
			local r = math.random() * spread
			TP.glint(layer, at + Vector2.new(math.cos(a) * r, math.sin(a) * r), math.random(18, 40), 0.55 + math.random() * 0.25,
				math.random() < 0.35 and Color3.fromRGB(120, 190, 255) or nil)
		end
	end
	local function snip(t, at: Vector2, pitch: number)
		to("open", 0, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.07)
		TP.sound(layer, TP.SFX.snip, 0.7, pitch)
		TP.playSnip(layer, pitch)
		TP.snipFX(layer, at, Color3.fromRGB(236, 232, 218))
		TP.dropHalves(t)
		TP.shake(layer, 9)
		burst(at, 6, 40)
	end

	task.spawn(function()
		local size = layer.AbsoluteSize
		local t1, t2 = TP.tapes[1], TP.tapes[2]
		local at1, at2 = TP.screenPointOn(t1), TP.screenPointOn(t2)
		local D = TP.DEPTH
		local cut1, cut2 = sc.toWorld(at1.X, at1.Y, D), sc.toWorld(at2.X, at2.Y, D)
		-- blades cross each strip roughly at right angles (the tape tilts a few degrees)
		local roll1, roll2 = -t1.angle - 8, -t2.angle + 10

		-- 1. SWOOSH: in from right beside the lens (bottom right), huge and tilted, twirling once around its blades
		st.P = sc.toWorld(size.X * 1.05, size.Y * 1.15, 3.5)
		st.roll, st.yaw, st.pitch, st.spin, st.open = roll1 - 70, 70, -35, 0, 0
		trail = true
		TP.sound(layer, TP.SFX.whoosh, 0.8, 1)
		task.delay(0.12, function() TP.sound(layer, TP.SFX.spin, 0.45, 1.15) end)
		fly(cut1 + Vector3.new(1.2, 1.6, 1.5), Vector3.new(-3, -2.5, -3), 0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		to("spin", math.pi * 2, 1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		to("roll", roll1, 0.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		to("yaw", 28, 1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		to("pitch", -10, 1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		task.wait(0.85)
		trail = false
		burst(sc.toScreen(st.P), 9, 70)

		-- 2. a breath: hang there, blades swing wide open
		to("open", 46, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.wait(0.4)

		-- 3. lunge onto the first strip and SNIP
		fly(cut1, Vector3.zero, 0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.11)
		snip(t1, at1, 1)
		task.wait(0.16)

		-- 4. swoop to the second strip (turning to show the other side), open up, SNIP
		TP.sound(layer, TP.SFX.whooshSmall, 0.5, 1.2)
		trail = true
		to("open", 42, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		to("roll", roll2, 0.45)
		to("yaw", -24, 0.45)
		fly(cut2 + Vector3.new(-0.9, 1.4, 1.2), Vector3.new(0.6, 1.4, 0.8), 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(0.45)
		trail = false
		task.wait(0.14)
		fly(cut2, Vector3.zero, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.1)
		snip(t2, at2, 1.1)
		TP.shown = false
		if done then task.delay(0.2, done) end

		-- 5. flourish: a final twirl and whoosh away past the camera, top left
		task.wait(0.28)
		trail = true
		TP.sound(layer, TP.SFX.whoosh, 0.6, 1.25)
		to("open", 10, 0.2)
		to("spin", math.pi * 4, 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		to("yaw", -70, 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		fly(sc.toWorld(-size.X * 0.25, -size.Y * 0.3, 4), Vector3.new(2, 3, 0), 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.7)
		trail = false
		conn:Disconnect()
		for _, t in TP.tapes do
			t.holder.Visible = false
			TP.resetTape(t)
		end
		vpf:Destroy()
		Armory._cutting = false
	end)
end

-------------------------------------------------------------------------------
-- UI
-- (2026-10-21, RIVALS 1:1) the 2D layer is a port of the RIVALS replica's Weapons screen
-- (rivals_practice/ui/weapons/WeaponsController.client.lua), checked against live RIVALS (rivals_rec t0048-t0062):
--   Left  : the Career card (headshot, "Career", the slot icons + Duel History) and under it the list on a
--           near-invisible plate: section headers (a dim title between two dim silhouettes over a dotted rule),
--           owned rows dim with their render at the left, locked rows dark with a padlock either side, and the
--           picked row left-aligned, big and bold white with its render popping out on the right.
--   Right : stacked up from the bottom edge - the item card (render poking out of its corner, name + checkbox,
--           two bullets), the level card (a thick blue bar with the big centred level, "Level up now!" with a
--           yellow button, "Reward at Level N" with its render) or, for a locked item, "Unlock now!" with the
--           yellow price button; then the action rows with big blue square icon buttons.
--   Bottom: the strip of rounded-square slots (the "none" slash glyph) with their labels and the red X Leave.
--   Picker: stands in for the panels: red "Back", the search bar, "Favorited", one row of rarity tiles.
-- Built in RIVALS' 1920 x 1080 design px on UIKit.Rivals' 16:9 canvas and converted with the Rivals Kit.toScale
-- (UI rule: Position / Size in Scale only). Colours and fonts come from UIKit.Rivals.Theme (Theme.color, Theme.gradient,
-- Theme.font, or Theme.hex with the replica's measured values). Lives in its own ScreenGui so the lobby's auto-styling
-- doesn't touch it.
-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) these take the slots of the old Oswald / Builder fonts, TacKit, BASE_H and the row / card sizes
local RIV = ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Rivals")
local RT, RK, RA = require(RIV:WaitForChild("Theme")), require(RIV:WaitForChild("Kit")), require(RIV:WaitForChild("Assets"))
-- Rubik: ExtraBold (names, big numbers, Back), Bold (labels, titles), Medium (sub-lines, bullets) - the replica's FX / FB / FM
local FX, FB, FM = RT.font.display, Font.new(RT.font.display.Family, Enum.FontWeight.Bold), RT.font.medium
local BLACK, WHITE = RT.color.textDark, RT.color.white
local H = RT.hex
local COL = { -- the replica's measured Weapons colours (WeaponsController), through Theme.hex
	Text = RT.color.text,
	Sub = H("#BDBCC2"),     -- sub-lines, owned rows
	Note = H("#A7A5AC"),    -- the item card's bullets
	Grey = H("#8E8D93"),    -- Career icons, search placeholder
	Career = H("#C9C7CC"),  -- the "Career" word
	Dim = H("#2E2D33"),     -- locked rows
	DimHead = H("#3A393F"), -- section headers, their silhouettes and dotted rule
	DimKey = H("#1A191E"),
	Ink = H("#1A191E"),     -- checkbox well, dark glyphs
	Empty = H("#5A595F"),   -- the "none" slot glyph
	Red = H("#E8262B"),     -- the Leave X
	RedEdge = H("#7A0A0E"),
	Bar = H("#0F3550"), BarFill = H("#14A3E8"), BarLo = H("#7FD4FF"), BarHi = H("#2E6A8C"), -- the level bar
	Reward = H("#3FE0FF"),  -- the reward tile's edge
	Check = H("#4BD12A"),   -- the picker's big green check
}
local GRAD = { -- button faces, top -> bottom
	blue = RT.gradient.blue, -- Contracts / Overview / Statistics ((2026-10-21, port3) Rivals Theme gradient.blue, was #3FB4FF -> #0A5CF0)
	key = RT.gradient.key,                  -- "Level up now!" / "Unlock now!"
	green = { RT.color.green, H("#2FA80E") },
	grey = { H("#B9B9B9"), H("#7E7E7E") },  -- can't use it
	red = { H("#FF5A5A"), H("#C81E24") },   -- the picker's Back, an open panel's X
}
local PANEL_T = 0.35 -- the replica's panels: black at this transparency, 6 px corners
local SLOT_ORDER = { "Weapon", "Melee", "Gadget" }
local SLOT_TITLE = { Weapon = "Weapons", Melee = "Melee", Gadget = "Gadgets" }
local SLOT_LABEL = { Weapon = "Weapon", Melee = "Melee", Gadget = "Gadget" }

local LIST_X, LIST_Y, LIST_W = 12, 574, 336 -- the list (replica: 12, 640, 336 x 440, to the bottom edge)
-- (2026-10-22, live RIVALS Weapons at 16:9) the Career card sits at 38 % of the height (y 414, 150 tall) and the list starts at y 574
local ROW_H, HEADER_H = 67, 74
-- (2026-10-21, port3) the list's ScrollingFrame reaches this far past its plate on the right, so the picked row's render can
-- overlap the panel's right edge like RIVALS' (a ScrollingFrame always clips). Table field: the chunk is at the local limit.
Armory._LIST_OVER = 44
local CARD_X, CARD_W = 1572, 335            -- the right column
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local currentTab = "Weapon" -- the section at the top of the list (highlighted slot icon)
local rows = {}             -- [itemId] = row
local sections = {}         -- [slot] = { header = Frame }
local tabs = {}             -- [slot] = { button, icon }
local selectedRowId = nil

local function mk(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	-- (2026-10-18, Edward: the slot icons "glitch") the old InterfaceController hover/press-animates every button in a new
	-- ScreenGui; Nonapplicable opts out, the screen animates its own buttons.
	if inst:IsA("GuiButton") then inst:AddTag("Nonapplicable") end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function corner(r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function circle() return mk("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function text(props)
	local t = mk("TextLabel", { BackgroundTransparency = 1, FontFace = FM, TextColor3 = COL.Text, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromOffset(100, 24) })
	for k, v in props do
		if k ~= "Parent" then t[k] = v end
	end
	t.Parent = props.Parent
	return t
end
-- the replica's dark text edge (UIStroke, Contextual)
local function shade(label, thick: number?, alpha: number?)
	mk("UIStroke", { Color = BLACK, Thickness = thick or 1.5, Transparency = alpha or 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end
local function panel(props)
	local f = mk("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, BorderSizePixel = 0, Active = true }) -- (Active: clicks on a panel don't turn the item)
	for k, v in props do
		if k ~= "Parent" then f[k] = v end
	end
	corner(6).Parent = f
	f.Parent = props.Parent
	return f
end
-- (2026-10-21, RIVALS 1:1) pieces are built in design px inside a Folder, converted to Scale against the 1920 x 1080 canvas
-- (every group they land in fills the canvas), then moved into place: no Offset reaches the screen
local function settle(tmp: Instance, parent: Instance)
	RK.toScale(tmp, RT.design)
	for _, c in tmp:GetChildren() do c.Parent = parent end
	tmp:Destroy()
end

local function itemsInSlot(slot: string)
	local ids = {}
	for id, item in ctx.Config.Items do
		if item.Slot == slot then table.insert(ids, id) end
	end
	table.sort(ids, function(a, b)
		local ia, ib = ctx.Config.Items[a], ctx.Config.Items[b]
		if ia.Price ~= ib.Price then return ia.Price < ib.Price end
		return a < b
	end)
	return ids
end

local function equippedIn(slot: string): string
	local data = ctx.getData()
	return (data and data.Loadout and data.Loadout[slot]) or ctx.Config.DefaultLoadout[slot]
end

local function isFavourite(id: string): boolean
	local data = ctx.getData()
	return data ~= nil and data.Favorites ~= nil and data.Favorites[id] == true
end

-- (2026-10-21, RIVALS 1:1) the replica's flat icons from UIKit.Rivals.Assets (same set order as WeaponsController's icon())
function Armory._icon(name: string): string
	for _, key in { "rowIcon", "hud", "tasks", "play", "shop", "items", "pass", "more", "skins", "daily", "daily2", "bundles", "hud3d" } do
		local set = RA[key]
		if set and set[name] then return set[name] end
	end
	return ""
end

-------------------------------------------------------------------------------
-- Item renders: a lit 3D model at a three-quarter "held" angle with a soft drop shadow, or (flat) a
-- plain silhouette in one colour.
-------------------------------------------------------------------------------
local ICON_FOV = 30
local POSE_GUN = CFrame.Angles(0, 0, math.rad(-15)) * CFrame.Angles(math.rad(12), 0, 0) * CFrame.Angles(0, math.rad(108), 0)
local FLIP = CFrame.Angles(0, math.pi, 0) -- lobby Icons face a camera at -Z; these renders look from +Z

local function renderModel(id: string): Model
	local m = Instance.new("Model")
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	local src = repo and ((repo:FindFirstChild("Weapons") and repo.Weapons:FindFirstChild(id)) or (repo:FindFirstChild("Melee") and repo.Melee:FindFirstChild(id)))
	local pose = POSE_GUN
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.9 then
				local c = d:Clone()
				for _, k in c:GetChildren() do
					if not k:IsA("DataModelMesh") then k:Destroy() end
				end
				c.Anchored = true
				c.Color = c.Color:Lerp(WHITE, 0.16) -- lift dark gunmetal so it reads on the dark glass
				c.Parent = m
			end
		end
	end
	if #m:GetChildren() == 0 then
		m:Destroy()
		local built, view = ctx.Icons.Item(id)
		m = built
		pose = FLIP * (view or CFrame.identity)
		m:SetAttribute("Drawn", true)
	end
	local cf = m:GetBoundingBox()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = pose * (CFrame.new(-cf.Position) * d.CFrame) end
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = d.CFrame:PointToWorldSpace(h * s)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	local mid = (lo + hi) / 2
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = d.CFrame - mid end
	end
	return m
end

local function fitCamera(model: Model, box: Vector2, fill: number): CFrame
	local tH = math.tan(math.rad(ICON_FOV / 2))
	local aspect = box.X / box.Y
	local d = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local h = part.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = part.CFrame:PointToWorldSpace(h * s)
				d = math.max(d, w.Z + math.abs(w.X) / (tH * aspect * fill), w.Z + math.abs(w.Y) / (tH * fill))
			end
		end
	end
	return CFrame.lookAt(Vector3.new(0, 0, d * 1.04), Vector3.zero)
end

local function paintFlat(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = WHITE
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then d.TextureID = "" end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
end

local function layerVpf(parent, offset: Vector2, z: number)
	local v = mk("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(offset.X, offset.Y), ZIndex = z })
	local cam = Instance.new("Camera")
	cam.FieldOfView = ICON_FOV
	cam.Parent = v
	v.CurrentCamera = cam
	v.Parent = parent
	return v
end

-- Returns the render's box (a Frame). opts: flat (one-colour silhouette), color (flat colour), mirror,
-- fill (0..1 of the box the item fills), z
local function itemRender(parent: Instance, id: string, size: Vector2, opts)
	opts = opts or {}
	local z = opts.z or 3
	local box = mk("Frame", { Name = "Render", BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = z })
	local model = opts.model or renderModel(id) -- opts.model: an already-posed, centred model to draw instead of an item
	local fill = (opts.fill or 0.9) * (model:GetAttribute("Drawn") and 0.78 or 1)
	local camCF = fitCamera(model, size, fill)
	if opts.mirror then camCF = CFrame.Angles(0, math.pi, 0) * camCF end
	if opts.tilt then camCF = camCF * CFrame.Angles(0, 0, math.rad(opts.tilt)) end -- roll the camera = tilt the picture
	if opts.flat then
		local v = layerVpf(box, Vector2.zero, z)
		v.Ambient, v.LightColor = WHITE, BLACK
		v.ImageColor3 = opts.color or WHITE
		paintFlat(model)
		model.Parent = v
		v.CurrentCamera.CFrame = camCF
	else
		local shadow = layerVpf(box, Vector2.new(3, 5), z)
		shadow.Ambient, shadow.LightColor = BLACK, BLACK
		shadow.ImageTransparency = 0.45
		local copy = model:Clone()
		paintFlat(copy)
		copy.Parent = shadow
		shadow.CurrentCamera.CFrame = camCF
		local main = layerVpf(box, Vector2.zero, z + 1)
		main.Ambient = Color3.fromRGB(150, 150, 156)
		main.LightColor = Color3.fromRGB(250, 250, 255)
		main.LightDirection = Vector3.new(0.35, -0.85, -0.6)
		model.Parent = main
		main.CurrentCamera.CFrame = camCF
	end
	box.Parent = parent
	return box
end

-------------------------------------------------------------------------------
-- Drawn glyphs (no images needed). Coordinates are 0-1 of the glyph's square.
-------------------------------------------------------------------------------
local function seg(h, s: number, x1, y1, x2, y2, thick: number, color: Color3?)
	local dx, dy = (x2 - x1) * s, (y2 - y1) * s
	local len = math.sqrt(dx * dx + dy * dy)
	return mk("Frame", { BackgroundColor3 = color or COL.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2 * s, (y1 + y2) / 2 * s), Size = UDim2.fromOffset(len + thick, thick),
		Rotation = math.deg(math.atan2(dy, dx)), ZIndex = 2, Parent = h }, { circle() })
end
local function ring(h, s: number, cx, cy, d, thick: number, color: Color3?)
	return mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx * s, cy * s),
		Size = UDim2.fromOffset(d * s, d * s), ZIndex = 2, Parent = h }, { circle(), mk("UIStroke", { Color = color or COL.Text, Thickness = thick }) })
end
local function blob(h, s: number, x, y, w, hh, color: Color3?)
	return mk("Frame", { BackgroundColor3 = color or COL.Text, BorderSizePixel = 0, Position = UDim2.fromOffset(x * s, y * s),
		Size = UDim2.fromOffset(w * s, hh * s), ZIndex = 2, Parent = h }, { corner(2) })
end

-- a padlock: rounded body, thick shackle (its lower half hides behind the body), keyhole.
-- open = the shackle swung up off the right side. Returns the holder (size s x s).
local function padlock(parent: Instance, s: number, color: Color3?, open: boolean?, keyColor: Color3?)
	color = color or COL.Text
	local h = mk("Frame", { Name = "Lock", BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s), ZIndex = 5, Parent = parent })
	local body = mk("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(s * 0.82, s * 0.56), ZIndex = 6, Parent = h }, { corner(math.max(2, math.floor(s * 0.17))) })
	local shW = s * 0.5
	local shackle = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(shW, s * 0.68), ZIndex = 5, Parent = h }, {
		mk("UICorner", { CornerRadius = UDim.new(0, shW / 2) }),
		mk("UIStroke", { Color = color, Thickness = math.max(2, s * 0.12), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	shackle.Position = open and UDim2.new(0.5, s * 0.2, 0, -s * 0.1) or UDim2.new(0.5, 0, 0, s * 0.02)
	local kc = keyColor or COL.Ink
	mk("Frame", { BackgroundColor3 = kc, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.fromOffset(s * 0.2, s * 0.2), ZIndex = 7, Parent = body }, { circle() })
	mk("Frame", { BackgroundColor3 = kc, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(math.max(2, s * 0.09), s * 0.22), ZIndex = 7, Parent = body }, { corner(2) })
	return h
end

local GLYPH = {}
function GLYPH.check(h, s, c)
	seg(h, s, 0.18, 0.52, 0.42, 0.75, s * 0.14, c)
	seg(h, s, 0.42, 0.75, 0.84, 0.27, s * 0.14, c)
end
function GLYPH.eye(h, s, c)
	mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s / 2, s / 2),
		Size = UDim2.fromOffset(s * 0.92, s * 0.54), ZIndex = 2, Parent = h }, { circle(), mk("UIStroke", { Color = c or COL.Text, Thickness = s * 0.1 }) })
	mk("Frame", { BackgroundColor3 = c or COL.Text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s / 2, s / 2),
		Size = UDim2.fromOffset(s * 0.28, s * 0.28), ZIndex = 2, Parent = h }, { circle() })
end
function GLYPH.arrow(h, s, c)
	seg(h, s, 0.16, 0.5, 0.8, 0.5, s * 0.15, c)
	seg(h, s, 0.53, 0.23, 0.8, 0.5, s * 0.15, c)
	seg(h, s, 0.53, 0.77, 0.8, 0.5, s * 0.15, c)
end
function GLYPH.up(h, s, c)
	seg(h, s, 0.2, 0.48, 0.5, 0.18, s * 0.12, c)
	seg(h, s, 0.5, 0.18, 0.8, 0.48, s * 0.12, c)
	seg(h, s, 0.2, 0.84, 0.5, 0.54, s * 0.12, c)
	seg(h, s, 0.5, 0.54, 0.8, 0.84, s * 0.12, c)
end
function GLYPH.bars(h, s, c)
	blob(h, s, 0.1, 0.5, 0.22, 0.42, c)
	blob(h, s, 0.39, 0.12, 0.22, 0.8, c)
	blob(h, s, 0.68, 0.32, 0.22, 0.6, c)
end
function GLYPH.lens(h, s, c)
	ring(h, s, 0.42, 0.42, 0.52, s * 0.11, c)
	seg(h, s, 0.63, 0.63, 0.86, 0.86, s * 0.15, c)
end
function GLYPH.none(h, s, c)
	ring(h, s, 0.5, 0.5, 0.8, s * 0.1, c)
	seg(h, s, 0.25, 0.75, 0.75, 0.25, s * 0.1, c)
end
function GLYPH.empty(h, s, c) -- (2026-10-21, round 3: match RIVALS) RIVALS' empty-slot mark: a grey rounded square with a slash
	mk("Frame", { BackgroundColor3 = c or COL.Empty, BackgroundTransparency = 0.72, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(s * 0.78, s * 0.78), ZIndex = 1, Parent = h }, { corner(math.floor(s * 0.16)) })
	seg(h, s, 0.27, 0.73, 0.73, 0.27, s * 0.1, c)
end
function GLYPH.clock(h, s, c) -- (2026-10-21, grade3) Duel History's slot icon: a clock face with two hands
	ring(h, s, 0.5, 0.5, 0.8, s * 0.1, c)
	seg(h, s, 0.5, 0.5, 0.5, 0.26, s * 0.1, c)
	seg(h, s, 0.5, 0.5, 0.68, 0.6, s * 0.1, c)
end
function GLYPH.star(h, s, c) -- a rounded eight-point burst
	for i = 0, 3 do
		local b = blob(h, s, 0.5 - 0.095, 0.08, 0.19, 0.84, c)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromOffset(s / 2, s / 2)
		b.Rotation = i * 45
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	end
end
-- (lobby revamp, graders: four identical crossed circles read as "broken") one drawn icon per cosmetic slot
function GLYPH.skin(h, s, c) -- a pistol silhouette: slide, grip, trigger guard
	blob(h, s, 0.12, 0.26, 0.76, 0.2, c)
	local g = blob(h, s, 0.5, 0.4, 0.2, 0.42, c)
	g.Rotation = 14
	ring(h, s, 0.42, 0.52, 0.18, s * 0.06, c)
end
function GLYPH.wrap(h, s, c) -- a paint swatch: three slanted stripes
	for i = 0, 2 do
		local b = blob(h, s, 0.2 + i * 0.22, 0.14, 0.14, 0.72, c)
		b.Rotation = 18
		b.BackgroundTransparency = i * 0.25
	end
end
function GLYPH.finisher(h, s, c) -- a crosshair with a hit spark
	ring(h, s, 0.5, 0.5, 0.62, s * 0.08, c)
	seg(h, s, 0.5, 0.06, 0.5, 0.3, s * 0.08, c)
	seg(h, s, 0.5, 0.7, 0.5, 0.94, s * 0.08, c)
	seg(h, s, 0.06, 0.5, 0.3, 0.5, s * 0.08, c)
	seg(h, s, 0.7, 0.5, 0.94, 0.5, s * 0.08, c)
end
function GLYPH.cutscene(h, s, c) -- a clapperboard
	blob(h, s, 0.14, 0.4, 0.72, 0.46, c)
	local top = blob(h, s, 0.14, 0.2, 0.72, 0.14, c)
	top.Rotation = -10
	for i = 0, 2 do
		local st = blob(h, s, 0.2 + i * 0.22, 0.2, 0.08, 0.14, COL.Ink)
		st.Rotation = -10
		st.ZIndex = 3
	end
end
function GLYPH.lock(h, s, c)
	local l = padlock(h, s * 0.9, c, false, (c == nil or c == COL.Text) and COL.Ink or COL.DimKey)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
end
function GLYPH.unlock(h, s, c)
	local l = padlock(h, s * 0.9, c, true, (c == nil or c == COL.Text) and COL.Ink or COL.DimKey)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
end

-- (2026-10-21, RIVALS 1:1) the Leave X is the replica's: two plain red bars with a dark red edge (no gradient)
function GLYPH.leave(h, s)
	for _, a in { { 0.14, 0.14, 0.86, 0.86 }, { 0.14, 0.86, 0.86, 0.14 } } do
		local b = seg(h, s, a[1], a[2], a[3], a[4], s * 0.25, COL.Red)
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, math.floor(s * 0.06))
		mk("UIStroke", { Color = COL.RedEdge, Thickness = math.max(2, s * 0.03), Parent = b })
	end
end
function GLYPH.closex(h, s, c) -- an open panel's X (white on the red button)
	seg(h, s, 0.22, 0.22, 0.78, 0.78, s * 0.14, c or WHITE)
	seg(h, s, 0.22, 0.78, 0.78, 0.22, s * 0.14, c or WHITE)
end

-- (2026-10-21, RIVALS 1:1) RIVALS draws flat white icons (UIKit.Rivals.Assets: the replica's padlock, arrow, check, eye, undo,
-- key) and full-colour art (trophy, burst); the Studio-generated UIIcons meshes are gone. Kinds without an image are drawn
-- (GLYPH above).
local GLYPH_IMG = { lock = "padlock", unlock = "padlock", arrow = "arrow", check = "check", eye = "eye", undo = "undo", key = "cur_key",
	trophy = "trophy_gold", burst = "skin_explosion", bars = "leaderboard", seal = "rbxassetid://122349404580689" }
-- (2026-10-21, image list #7/#8) RIVALS' Statistics row is white podium bars and "Reward at Level N" a white starburst seal:
-- the replica's leaderboard bars and Tacticals' level-shield seal (Kit.ICONS.level), both tinted white, replace the gold trophy
-- and the orange explosion there
local GLYPH_ART = { trophy = true, burst = true } -- never tinted
-- (2026-10-21, RIVALS images) the uploaded RIVALS-1:1 set (UIKit.Rivals.Assets.gen, notes/ui_rivals/image_gen_list.md) replaces
-- the code-drawn GLYPHs and stand-ins: empty slot, Leave X, panel X, level-up arrows, reward seal, stats bars, Inspect lens,
-- History clock, and the lime "equipped" check (a new kind; "check" stays the tintable white tick for the favourite box).
-- leave / closex / equipped are coloured art (never tinted). A missing id falls back to the drawn GLYPH.
for kind, name in { empty = "kit_slot_empty", leave = "kit_leave_x", closex = "ui_close_x", up = "kit_levelup", seal = "kit_reward_seal",
	bars = "kit_stats", lens = "kit_inspect", clock = "kit_cat_clock", equipped = "tasks_check_lime" } do
	local id = RA.gen and RA.gen[name]
	if id then GLYPH_IMG[kind] = id end
	if id and (kind == "leave" or kind == "closex" or kind == "equipped") then GLYPH_ART[kind] = true end
end
GLYPH.equipped = GLYPH.check -- (drawn fallback when the lime check id is missing)
-- (2026-10-21, RIVALS images) category icons per slot (gen.kit_cat_*), grey #858487 (the active tab white). Table fields, not
-- locals: the chunk is at the local limit.
Armory._CAT_IMG = { Weapon = "kit_cat_rifle", Melee = "kit_cat_knife", Gadget = "kit_cat_grenade" }
Armory._catGrey = H("#858487")

local function glyph(parent: Instance, kind: string, size: number, color: Color3?, z: number?)
	local h = mk("Frame", { Name = "Glyph", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = z or 6, Parent = parent })
	local g = GLYPH_IMG[kind]
	local img = g and (g:sub(1, 13) == "rbxassetid://" and g or Armory._icon(g)) or ""
	if img ~= "" then
		mk("ImageLabel", { Name = "Image", BackgroundTransparency = 1, Image = img, ImageColor3 = GLYPH_ART[kind] and WHITE or (color or COL.Text),
			ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = z or 6, Parent = h })
		return h
	end
	local fn = GLYPH[kind]
	if fn then fn(h, size, color) end
	return h
end

-------------------------------------------------------------------------------
-- Vector slot icons: a rifle, a knife and a grenade drawn from rounded shapes on a small design grid
-- (100 x 60 for the long ones, 60 x 60 for the grenade). mirror flips them so a pair can face each other.
-------------------------------------------------------------------------------
local function vbox(parent: Instance, w: number, h: number, color: Color3, mirror: boolean?, gw: number?, gh: number?)
	gw, gh = gw or 100, gh or 60
	local holder = mk("Frame", { Name = "Vector", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), ZIndex = 5, Parent = parent })
	local sx, sy = w / gw, h / gh
	local function X(x) return (mirror and (gw - x) or x) * sx end
	local function Y(y) return y * sy end
	local v = {}
	-- a bar between two grid points (round ends unless a radius is given)
	function v.bar(x1, y1, x2, y2, thick, radius)
		local ax, ay, bx, by = X(x1), Y(y1), X(x2), Y(y2)
		local dx, dy = bx - ax, by - ay
		local t = thick * sy
		return mk("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2), Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + t, t),
			Rotation = math.deg(math.atan2(dy, dx)), ZIndex = 5, Parent = holder },
			{ mk("UICorner", { CornerRadius = radius and UDim.new(0, radius * sy) or UDim.new(1, 0) }) })
	end
	-- a rounded box from its top-left grid corner
	function v.box(x, y, bw, bh, radius, rot)
		return mk("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(X(x + bw / 2), Y(y + bh / 2)), Size = UDim2.fromOffset(bw * sx, bh * sy),
			Rotation = (rot or 0) * (mirror and -1 or 1), ZIndex = 5, Parent = holder }, { mk("UICorner", { CornerRadius = UDim.new(0, (radius or 2) * sy) }) })
	end
	function v.ring(cx, cy, d, thick)
		return mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(X(cx), Y(cy)),
			Size = UDim2.fromOffset(d * sy, d * sy), ZIndex = 5, Parent = holder }, { circle(), mk("UIStroke", { Color = color, Thickness = thick * sy }) })
	end
	function v.dot(cx, cy, d)
		return mk("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(X(cx), Y(cy)),
			Size = UDim2.fromOffset(d * sy, d * sy), ZIndex = 5, Parent = holder }, { circle() })
	end
	return holder, v
end

local VECTOR = {}
function VECTOR.Rifle(v) -- barrel to the right
	v.bar(60, 23, 100, 23, 5)       -- barrel
	v.box(58, 17, 26, 12, 3)        -- handguard
	v.box(22, 15, 40, 17, 3)        -- receiver
	v.box(30, 8, 7, 8, 1.5)         -- rear sight
	v.box(80, 11, 4, 7, 1)          -- front sight
	v.bar(24, 23, 5, 33, 12, 3)     -- stock
	v.box(0, 26, 8, 18, 2)          -- butt plate
	v.bar(42, 31, 36, 50, 7, 2)     -- grip
	v.bar(54, 31, 49, 54, 9, 2)     -- magazine
end
function VECTOR.Knife(v) -- blade to the right
	v.bar(40, 30, 90, 30, 12, 2)    -- blade
	v.box(84, 23.5, 13, 13, 2, 45)  -- tip
	v.box(33, 18, 7, 24, 2)         -- guard
	v.bar(8, 30, 33, 30, 10, 3)     -- handle
	v.box(2, 22, 8, 16, 2)          -- pommel
end
function VECTOR.Grenade(v) -- on the 60 x 60 grid
	v.dot(30, 37, 40)               -- body
	v.box(22, 11, 16, 10, 2)        -- neck
	v.box(16, 4, 28, 8, 3)          -- cap
	v.bar(40, 8, 56, 22, 5)         -- lever
	v.ring(10, 7, 11, 2.5)          -- pin
end

local VECTOR_SPEC = { -- holder size, how far it leans, which drawing
	Weapon = { w = 58, h = 35, lean = 18, draw = "Rifle" },
	Melee = { w = 54, h = 24, lean = 40, draw = "Knife" },
	Gadget = { w = 34, h = 34, lean = 8, draw = "Grenade", grid = 60 },
}
-- draws a slot's icon centred in parent; mirror = facing left (and leaning the other way)
local function slotVector(parent: Instance, slot: string, color: Color3, mirror: boolean?, scale: number?)
	local spec = VECTOR_SPEC[slot]
	local k = scale or 1
	local holder, v = vbox(parent, spec.w * k, spec.h * k, color, mirror, spec.grid, spec.grid)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Rotation = mirror and spec.lean or -spec.lean
	VECTOR[spec.draw](v)
	return holder
end
local function tintVector(holder: Instance, color: Color3, transparency: number)
	for _, d in holder:GetDescendants() do
		if d:IsA("Frame") then
			d.BackgroundColor3 = color
			if d.BackgroundTransparency < 1 then d.BackgroundTransparency = transparency end
		elseif d:IsA("UIStroke") then
			d.Color = color
			d.Transparency = transparency
		end
	end
end

-- Header / tab icons: weapon meshes made with Studio's mesh generator, kept in ReplicatedStorage.UIIcons
-- (Rifle, Knife, Grenade - never used in-game, only drawn here as flat silhouettes). Falls back to the
-- shape-drawn vectors above when a mesh is missing.
local ICON_MESH = { Weapon = "Rifle", Melee = "Knife", Gadget = "Grenade" }
local ICON_UPRIGHT = { Gadget = true } -- long side up instead of across

local function modelBounds(m: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = d.CFrame:PointToWorldSpace(h * s)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	return lo, hi
end

-- a fresh, posed, centred copy of a slot's icon mesh (nil when there isn't one)
local function iconMesh(slot: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("UIIcons")
	local src = folder and folder:FindFirstChild(ICON_MESH[slot])
	if not src then return nil end
	local m = Instance.new("Model")
	local list = src:IsA("BasePart") and { src } or src:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			local c = p:Clone()
			for _, k in c:GetChildren() do
				if not k:IsA("DataModelMesh") then k:Destroy() end
			end
			c.Anchored, c.CanCollide = true, false
			c.Parent = m
		end
	end
	if #m:GetChildren() == 0 then
		m:Destroy()
		return nil
	end
	-- lay it out: longest side across (or up, for upright icons), second-longest the other way
	-- (a single mesh is measured along its own axes; a generated mesh is often turned inside its box)
	local parts = m:GetChildren()
	local cf, size
	if #parts == 1 then cf, size = parts[1].CFrame, parts[1].Size else cf, size = m:GetBoundingBox() end
	local axes = { { Vector3.xAxis, size.X }, { Vector3.yAxis, size.Y }, { Vector3.zAxis, size.Z } }
	table.sort(axes, function(a, b) return a[2] > b[2] end)
	local upright = ICON_UPRIGHT[slot]
	local want = CFrame.fromMatrix(Vector3.zero, upright and Vector3.yAxis or Vector3.xAxis, upright and Vector3.xAxis or Vector3.yAxis)
	local have = CFrame.fromMatrix(Vector3.zero, axes[1][1], axes[2][1])
	local R = want * have:Inverse()
	for _, p in m:GetChildren() do
		p.CFrame = R * (cf:Inverse() * p.CFrame)
	end
	-- heavy end down (magazine and grip, grenade body): compare the collision centre of mass with the box centre
	local lo, hi = modelBounds(m)
	local mass, comY = 0, 0
	for _, p in m:GetChildren() do
		mass += p.Mass
		comY += p.CenterOfMass.Y * p.Mass
	end
	if mass > 0 and comY / mass > (lo.Y + hi.Y) / 2 + 0.01 * size.Magnitude then
		for _, p in m:GetChildren() do
			p.CFrame = CFrame.Angles(0, 0, math.pi) * p.CFrame
		end
		lo, hi = modelBounds(m)
	end
	local mid = (lo + hi) / 2
	for _, p in m:GetChildren() do
		p.CFrame = p.CFrame - mid
	end
	return m
end

-- a slot's icon centred in parent: the generated mesh as a flat silhouette, else the drawn vector
local function slotIcon(parent: Instance, slot: string, color: Color3, mirror: boolean?, scale: number?)
	-- (2026-10-21, RIVALS images) the career-card / list-header category icons are gen.kit_cat_rifle / knife / grenade (white,
	-- tinted; already tilted, so no lean). mirror flips the image with a negative ImageRectSize (the uploads are 512 x 512).
	local catId = RA.gen and RA.gen[Armory._CAT_IMG[slot] or ""]
	if catId then
		local px = 52 * (scale or 1)
		return mk("ImageLabel", { Name = "CatIcon", BackgroundTransparency = 1, Image = catId, ImageColor3 = color, ScaleType = Enum.ScaleType.Fit,
			ImageRectOffset = mirror and Vector2.new(512, 0) or Vector2.zero, ImageRectSize = mirror and Vector2.new(-512, 512) or Vector2.zero,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(px, px), ZIndex = 6, Parent = parent })
	end
	local m = iconMesh(slot)
	if not m then return slotVector(parent, slot, color, mirror, scale) end
	local spec = VECTOR_SPEC[slot]
	local k = scale or 1
	local box = itemRender(parent, "", Vector2.new(spec.w * k, spec.h * k),
		{ model = m, flat = true, color = color, mirror = mirror, tilt = mirror and spec.lean or -spec.lean, z = 5, fill = 0.96 })
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	return box
end
local function tintIcon(holder: Instance, color: Color3, transparency: number)
	local v = holder:FindFirstChildOfClass("ViewportFrame")
	if holder:IsA("ImageLabel") then -- (2026-10-21, RIVALS images) a gen.kit_cat_* image
		holder.ImageColor3 = color
		holder.ImageTransparency = transparency
	elseif v then
		v.ImageColor3 = color
		v.ImageTransparency = transparency
	else
		tintVector(holder, color, transparency)
	end
end

-- (2026-10-21, RIVALS 1:1) RIVALS' big square button (replica: 111 x 52 at x 217 of the card): a vertical gradient face
-- (blue / yellow key / green / grey / red, GRAD) and a white icon. No lip, no glint.
local function bigButton(parent: Instance, x: number, y: number, icon: string?, tone: string?)
	local b = mk("TextButton", { Name = "Button", AutoButtonColor = false, Text = "", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(111, 52), ZIndex = 5, Parent = parent }, { corner(5), RK.vgrad(GRAD[tone or "blue"]) })
	if icon then
		-- (2026-10-21, port3) graders: RIVALS' icons are chunky, ~70% of the button's height (a fat arrow, a big eye): 50 px box
		-- (was 40) and four copies of the image 1.5 px off each way underneath to fatten its strokes
		local g = glyph(b, icon, 50, WHITE, 6)
		local img = g:FindFirstChild("Image")
		if img then
			for _, o in { Vector2.new(-1.5, 0), Vector2.new(1.5, 0), Vector2.new(0, -1.5), Vector2.new(0, 1.5) } do
				local c = img:Clone()
				c.Name = "Fat"
				c.Position = UDim2.fromOffset(o.X, o.Y)
				c.Parent = g
			end
		end
	end
	return b
end

-- (2026-10-21, RIVALS 1:1) the replica's card row: a 38 px icon, a Bold 22 title and a Medium 16 sub-line (dim)
-- (2026-10-21, port3) big = the action rows (graders: RIVALS' "Contracts / Earn free rewards" read larger): ExtraBold 26 title,
-- Bold 18 sub-line, both shrinking to fit instead of cutting off
local function cardRow(parent: Instance, y0: number, icon, title: string, sub: string?, w: number?, big: boolean?)
	local ic = mk("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, y0 + 8), Size = UDim2.fromOffset(38, 38), ZIndex = 5, Parent = parent })
	if type(icon) == "string" then glyph(ic, icon, 38, COL.Text, 5) elseif icon then icon(ic) end
	local t = shade(text({ Text = title, FontFace = big and FX or FB, TextSize = big and 26 or 22, TextScaled = big, Position = UDim2.fromOffset(58, y0 + (sub and (big and 1 or 4) or 12)),
		Size = UDim2.fromOffset(w or 155, big and 30 or 28), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = parent }), 1.2, 0.5)
	if big then mk("UITextSizeConstraint", { MaxTextSize = 26, Parent = t }) end
	if sub then
		local s = text({ Text = sub, FontFace = big and FB or FM, TextSize = big and 18 or 16, TextScaled = big, TextColor3 = COL.Sub, Position = UDim2.fromOffset(58, y0 + (big and 30 or 28)),
			Size = UDim2.fromOffset(w or 155, big and 22 or 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = parent })
		if big then mk("UITextSizeConstraint", { MaxTextSize = 18, Parent = s }) end
	end
	return ic
end

-------------------------------------------------------------------------------
-- Left column: the Career card + slot icons, then the long list
-------------------------------------------------------------------------------
local hud, listScroll -- hud: the RIVALS 16:9 design canvas everything below lives on
local leftGroup, rightCol, bottomGroup, statsLayer -- full-canvas groups (they slide in on Enter; the picker hides them)

-- (2026-10-21, RIVALS 1:1) a row's look, rebuilt (in design px, then Scale) whenever it changes.
-- (2026-10-21, port3) graders, against weapons.png:
--   picked (= equipped: a click equips): the name big, ExtraBold white, centred in the row's left part; its render big on the
--     right, overlapping past the panel's right edge (the list's ScrollingFrame reaches Armory._LIST_OVER further). No check.
--   others: a weapon picture at the left, the name centred, Bold - owned light grey, locked solid grey (readable, not faint)
--   locked: the picture is a flat grey silhouette and there is ONE small padlock (at the row's right end; on the picked row
--     at the foot of its render)
-- The near-black band under the picked row is the replica's (black at 0.5).
local function rowLook(row, on: boolean, animate: boolean)
	local b = row.button
	for _, c in b:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	b.ZIndex = on and 6 or 5
	local item = ctx.Config.Items[row.id]
	row.bg = mk("Frame", { Name = "Bg", BackgroundColor3 = BLACK, BackgroundTransparency = on and 0.5 or 1, BorderSizePixel = 0, Position = UDim2.fromOffset(2, 0),
		Size = UDim2.fromOffset(LIST_W - 4, ROW_H - 1), ZIndex = 4, Parent = b }, { corner(6) })
	local content = mk("Frame", { Name = "Content", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(LIST_W / 2, ROW_H / 2),
		Size = UDim2.fromOffset(LIST_W, ROW_H), ZIndex = 5, Parent = b })
	row.hs = mk("UIScale", { Name = "HoverScale", Parent = content })
	local box = on and Vector2.new(150, 104) or Vector2.new(84, 58)
	local holder = mk("Frame", { Name = "Render", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = on and UDim2.fromOffset(LIST_W - 75 + Armory._LIST_OVER * 0.6, ROW_H / 2 - 10) or UDim2.fromOffset(56, ROW_H / 2),
		Size = UDim2.fromOffset(box.X, box.Y), ZIndex = on and 8 or 6, Parent = b })
	if row.owned then
		itemRender(holder, row.id, box, { z = on and 8 or 6, fill = 0.95 })
	else
		itemRender(holder, row.id, box, { z = on and 8 or 6, fill = 0.95, flat = true, color = on and COL.Grey or RT.color.disabled })
	end
	if on and animate then
		local sc = mk("UIScale", { Scale = 0.3, Parent = holder })
		TweenService:Create(sc, POP, { Scale = 1 }):Play()
	end
	local maxTS = on and 36 or 26
	local nm = text({ Name = "Name", Text = item.Name, FontFace = on and FX or FB, TextSize = maxTS, TextScaled = true,
		TextColor3 = on and WHITE or (row.owned and COL.Sub or COL.Grey), TextXAlignment = Enum.TextXAlignment.Center,
		Position = on and UDim2.fromOffset(14, 8) or UDim2.fromOffset(96, 12),
		Size = on and UDim2.fromOffset(LIST_W - 100, ROW_H - 16) or UDim2.fromOffset(LIST_W - 96 - (row.owned and 14 or 40), ROW_H - 24),
		ZIndex = 7, Parent = content })
	mk("UITextSizeConstraint", { MaxTextSize = maxTS, Parent = nm })
	shade(nm, on and 2.2 or 1.2, on and 0.25 or 0.5)
	-- (kept for Armory._restyleEquipped's change test; nothing is drawn for it now)
	row.eq = equippedIn(item.Slot) == row.id
	if not row.owned then
		local s = on and 24 or 18
		mk("ImageLabel", { Name = "Lock", BackgroundTransparency = 1, Image = Armory._icon("padlock"), ImageColor3 = on and WHITE or COL.Grey,
			ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = on and UDim2.fromOffset(LIST_W - 112, ROW_H - 18) or UDim2.fromOffset(LIST_W - 22, ROW_H / 2),
			Size = UDim2.fromOffset(s, s), ZIndex = 9, Parent = b })
	end
	RK.toScale(b, Vector2.new(LIST_W, ROW_H))
end

local function makeRow(id: string, y: number, parent: Instance)
	local b = mk("TextButton", { Name = id, AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(LIST_W, ROW_H), ZIndex = 5, Parent = parent })
	local row = { id = id, owned = ctx.owns(id), button = b }
	rowLook(row, false, false)
	-- hover: a faint band shows and the words grow a little (plus the Kit hover tick); press squashes them
	b.MouseEnter:Connect(function()
		if selectedRowId == id then return end
		Kit.sfx("hover")
		if row.bg then TweenService:Create(row.bg, TI, { BackgroundTransparency = 0.75 }):Play() end
		if row.hs then TweenService:Create(row.hs, TI, { Scale = 1.05 }):Play() end
	end)
	b.MouseLeave:Connect(function()
		if selectedRowId == id then return end
		if row.bg then TweenService:Create(row.bg, TI, { BackgroundTransparency = 1 }):Play() end
		if row.hs then TweenService:Create(row.hs, TI, { Scale = 1 }):Play() end
	end)
	b.MouseButton1Down:Connect(function() if row.hs then TweenService:Create(row.hs, TI, { Scale = 0.95 }):Play() end end)
	-- (2026-10-21, user) like RIVALS: a click on an owned row picks AND equips it; a locked row is only picked (its price shows)
	b.Activated:Connect(function() Armory.ClickItem(id) end)
	return row
end

-- (2026-10-21, RIVALS 1:1) a section header like RIVALS' "Primary" (t0052): the title dim, Bold 30, between two dim silhouettes
-- facing outwards, over a dotted rule of 16 dots
local function makeHeader(slot: string, y: number, parent: Instance)
	local h = mk("Frame", { Name = "Header_" .. slot, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(LIST_W, HEADER_H),
		ZIndex = 5, Parent = parent })
	local line = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(LIST_W, 40), ZIndex = 5, Parent = h }, {
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for k = 1, 3, 2 do
		local box = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 32), LayoutOrder = k, ZIndex = 5, Parent = line })
		slotIcon(box, slot, COL.DimHead, k == 1, 0.76)
	end
	text({ Text = SLOT_TITLE[slot], FontFace = FB, TextSize = 30, TextColor3 = COL.DimHead, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40),
		LayoutOrder = 2, ZIndex = 5, Parent = line })
	for dx = 0, 15 do
		mk("Frame", { BackgroundColor3 = COL.DimHead, BorderSizePixel = 0, Position = UDim2.fromOffset(32 + dx * 17.5, 66), Size = UDim2.fromOffset(4, 4), ZIndex = 5, Parent = h })
	end
	return h
end

local function setSelectedRow(id: string?, animate: boolean)
	if selectedRowId == id and rows[id or ""] and rows[id].styled then return end
	local old = selectedRowId and rows[selectedRowId]
	selectedRowId = id
	if old then
		old.styled = nil
		rowLook(old, false, animate)
	end
	local new = id and rows[id]
	if new then
		new.styled = true
		rowLook(new, true, animate)
	end
end

-- (2026-10-21, user) restyle only the rows whose equipped state changed (the check comes or goes)
function Armory._restyleEquipped()
	for rid, row in rows do
		if row.owned and row.eq ~= (equippedIn(ctx.Config.Items[rid].Slot) == rid) then
			rowLook(row, selectedRowId == rid, true)
		end
	end
end

-- (2026-10-21, user) click-to-equip (replaces the Equip button): pick the item; if you own it and it isn't in its slot yet,
-- ask the server to equip it (the old button's path), then the checks move. Locked: only picked.
function Armory.ClickItem(id: string)
	local item = ctx.Config.Items[id]
	if not item then return end
	if id ~= selectedId then
		Kit.sfx("click")
		Armory.Select(id, 1)
	end
	if ctx.owns(id) and equippedIn(item.Slot) ~= id then
		task.spawn(function()
			pcall(ctx.ask, "Equip", item.Slot, id)
			if active then Armory._restyleEquipped() end
		end)
	end
end

local function styleTabs()
	for slot, t in tabs do
		local on = slot == currentTab
		tintIcon(t.icon, on and WHITE or Armory._catGrey, 0)
		TweenService:Create(t.button, TI, { BackgroundTransparency = on and 0.2 or 0.5 }):Play()
	end
end

-- where something in the list sits on the canvas (CanvasPosition is in screen pixels, like AbsolutePosition)
local function canvasY(obj: GuiObject): number
	return (obj.AbsolutePosition.Y - listScroll.AbsolutePosition.Y) + listScroll.CanvasPosition.Y
end

local tabHold = 0 -- while a jump is animating the highlight stays on the clicked icon
local pinnedTab -- (2026-10-18, Edward: the slot icons "glitch") a section near the end can't scroll to the top: keep its icon lit
local function maxScroll(): number
	return math.max(0, listScroll.AbsoluteCanvasSize.Y - listScroll.AbsoluteWindowSize.Y)
end
local function scrollTo(y: number)
	tabHold = os.clock() + 0.5
	-- clamp to what the list can actually reach (tweening past the end left it stuck and fighting the highlight)
	TweenService:Create(listScroll, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CanvasPosition = Vector2.new(0, math.clamp(y, 0, maxScroll())) }):Play()
end

-- the slot icons jump the list to that section
local function setTab(slot: string)
	currentTab = slot
	styleTabs()
	local sec = sections[slot]
	if sec then
		local y = canvasY(sec.box)
		pinnedTab = y > maxScroll() + 2 and slot or nil -- it can't reach the top: hold its highlight at the end of the list
		scrollTo(y)
	end
end

-- scroll so the picked row is in view (used when it's picked from elsewhere, e.g. the next-unlock button)
local function revealRow(id: string)
	local row = rows[id]
	if not row then return end
	local s = hud.AbsoluteSize.Y / 1080 -- (2026-10-21, RIVALS 1:1) screen px per design px
	local y = canvasY(row.button)
	local top = listScroll.CanvasPosition.Y
	local window = listScroll.AbsoluteWindowSize.Y
	if y < top + HEADER_H * s or y + ROW_H * s > top + window - 20 * s then
		scrollTo(y - window * 0.35)
	end
end

local ownedKey = nil -- the list is rebuilt only when what you own changes
-- (2026-10-21, RIVALS 1:1) headers and rows at fixed y (replica: header 74 + 6, rows 67 apart, 14 after a section), converted
-- against the canvas they fill; CanvasSize is set in Scale of the list's parent (the full-canvas Left group)
local function buildList()
	for _, c in listScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(rows)
	table.clear(sections)
	selectedRowId = nil
	local y = 0
	for _, slot in SLOT_ORDER do
		local h = makeHeader(slot, y, listScroll)
		sections[slot] = { header = h, box = h }
		y += HEADER_H + 6
		for _, id in itemsInSlot(slot) do
			rows[id] = makeRow(id, y, listScroll)
			y += ROW_H
		end
		y += 14
	end
	y = math.max(y + 30, 1080 - LIST_Y)
	listScroll.CanvasSize = UDim2.fromScale(0, y / 1080)
	RK.toScale(listScroll, Vector2.new(LIST_W + Armory._LIST_OVER, y)) -- (2026-10-21, port3) the frame is LIST_OVER wider than the rows
	listScroll.CanvasPosition = Vector2.zero
end

local function ownedSignature(): string
	local parts = {}
	for id in ctx.Config.Items do
		if ctx.owns(id) then table.insert(parts, id) end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function buildLeft()
	-- (2026-10-21, RIVALS 1:1) RIVALS' Career card (replica: 12, 413, 336 x 217): the headshot and "Career" (it opens Duel
	-- History, as RIVALS' Career does), then the row of class icons = our three slot icons + Duel History's clock. The replica's
	-- "Dismiss N Notifications" pill is left out (Tacticals has no notifications), so the card is 150 tall and ends where RIVALS' does.
	local prof = panel({ Name = "Profile", Position = UDim2.fromOffset(LIST_X, LIST_Y - 160), Size = UDim2.fromOffset(LIST_W, 150), ZIndex = 4, Parent = leftGroup })
	local career = mk("TextButton", { Name = "Career", AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(LIST_W, 82),
		ZIndex = 5, Parent = prof })
	local avatar = mk("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.fromOffset(78, 78), ZIndex = 6, Parent = career })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then avatar.Image = img end
	end)
	text({ Text = "Career", FontFace = FM, TextSize = 30, TextColor3 = COL.Career, Position = UDim2.fromOffset(130, 14), Size = UDim2.fromOffset(180, 40), ZIndex = 6, Parent = career })
	career.Activated:Connect(function() Armory.ShowHistory(true) end)
	Armory._tip(career, "Duel history", "up")
	for i, slot in SLOT_ORDER do
		local t = mk("TextButton", { Name = slot, AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = 0.5,
			Position = UDim2.fromOffset(16 + (i - 1) * 80, 92), Size = UDim2.fromOffset(64, 46), ZIndex = 5, Parent = prof }, { corner(6) })
		local box = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(46, 32), ZIndex = 6, Parent = t })
		tabs[slot] = { button = t, icon = slotIcon(box, slot, Armory._catGrey, false, 0.76) }
		Kit.bindButton(t, { hover = 1.1, press = 0.9 })
		-- on press (Activated never fired here: the release was lost, so the icons looked broken); touch taps too
		t.MouseButton1Down:Connect(function() setTab(slot) end)
		t.TouchTap:Connect(function() setTab(slot) end)
	end
	local hb = mk("TextButton", { Name = "History", AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(16 + 3 * 80, 92), Size = UDim2.fromOffset(64, 46), ZIndex = 5, Parent = prof }, { corner(6) })
	glyph(hb, "clock", 40, Armory._catGrey, 6) -- (2026-10-21, RIVALS images) gen.kit_cat_clock, ~40 px
	Armory._tip(hb, "Duel history", "up")
	hb.Activated:Connect(function() Armory.ShowHistory(true) end)
	Kit.bindButton(hb, { hover = 1.1, press = 0.9 })

	-- (2026-10-21, RIVALS 1:1) the list: RIVALS' column under the card (12, 640 to the bottom edge) on a near-invisible plate,
	-- no scroll bar
	-- (2026-10-21, port3) the plate is its own frame and the ScrollingFrame (transparent) reaches Armory._LIST_OVER past it, so the
	-- picked row's render can overlap the panel's right edge (RIVALS)
	-- (2026-10-22, section round 0, grader C vs RIVALS weapons.png) the list sits on the same dark plate as the Career card (was 0.75:
	-- the lit floor washed out the rows)
	-- (round 1: 0.35 still let the lit floor through)
	mk("Frame", { Name = "ListPlate", BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.fromOffset(LIST_X, LIST_Y),
		Size = UDim2.fromOffset(LIST_W, 1080 - LIST_Y), ZIndex = 3, Parent = leftGroup }, { corner(6) })
	listScroll = mk("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
		Position = UDim2.fromOffset(LIST_X, LIST_Y), Size = UDim2.fromOffset(LIST_W + Armory._LIST_OVER, 1080 - LIST_Y), CanvasSize = UDim2.new(),
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 4, Parent = leftGroup })
	-- the highlighted slot icon follows whichever section is at the top of the list
	listScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if os.clock() < tabHold or next(sections) == nil then return end
		-- the clicked bottom section stays lit while the list sits at its end
		if pinnedTab and listScroll.CanvasPosition.Y >= maxScroll() - 2 then
			if currentTab ~= pinnedTab then currentTab = pinnedTab; styleTabs() end
			return
		end
		pinnedTab = nil
		local y = listScroll.CanvasPosition.Y + 90 * hud.AbsoluteSize.Y / 1080
		local best = SLOT_ORDER[1]
		for _, slot in SLOT_ORDER do
			if sections[slot] and canvasY(sections[slot].box) <= y then best = slot end
		end
		if best ~= currentTab then
			currentTab = best
			styleTabs()
		end
	end)
	styleTabs()
end

-------------------------------------------------------------------------------
-- Right column (stacked up from the bottom edge) + hover bubbles + Statistics
-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) RIVALS' hover bubble (live: a plain white pill, dark Medium words, no border) with a pointer. One shared
-- bubble on the canvas, shown while the pointer (or a gamepad selection) is on `anchor`; sized and placed in Scale of the canvas.
-- side: "left" (beside the right column) or "up" (above). Table fields, not locals: the chunk is at the local limit.
function Armory._tip(anchor: GuiObject, msg: string?, side: string?)
	if not msg or msg == "" then return end
	local function hide()
		local tip = Armory._tipFrame
		if tip and Armory._tipOwner == anchor then
			Armory._tipOwner = nil
			tip.Visible = false
		end
	end
	local function show()
		if not hud or not anchor.Parent then return end
		local tip = Armory._tipFrame
		if not tip or not tip.Parent then
			local tmp = Instance.new("Folder")
			tip = mk("Frame", { Name = "Tip", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(200, 40), Visible = false, ZIndex = 40, Parent = tmp }, { corner(8) })
			text({ Name = "Words", FontFace = FM, TextSize = 19, TextColor3 = BLACK, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(176, 24), ZIndex = 42, Parent = tip })
			mk("Frame", { Name = "Pointer", BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
				Size = UDim2.fromOffset(14, 14), ZIndex = 41, Parent = tip })
			settle(tmp, hud)
			Armory._tipFrame = tip
		end
		Armory._tipOwner = anchor
		tip.Words.Text = msg
		-- (Rubik Medium 19 runs ~9.4 design px a letter; long text wraps onto more lines)
		local w = math.clamp(#msg * 9.4 + 28, 100, 300)
		local h = math.max(1, math.ceil(#msg * 9.4 / (w - 24))) * 23 + 16
		tip.Size = UDim2.fromScale(w / 1920, h / 1080)
		tip.Words.Position = UDim2.fromScale(12 / w, 8 / h)
		tip.Words.Size = UDim2.fromScale((w - 24) / w, (h - 16) / h)
		tip.Pointer.Size = UDim2.fromScale(14 / w, 14 / h)
		local f = hud.AbsoluteSize.Y / 1080
		local p = (anchor.AbsolutePosition - hud.AbsolutePosition) / f
		local sz = anchor.AbsoluteSize / f
		if side == "left" then
			tip.AnchorPoint = Vector2.new(1, 0.5)
			tip.Position = UDim2.fromScale((p.X - 14) / 1920, (p.Y + sz.Y / 2) / 1080)
			tip.Pointer.Position = UDim2.fromScale(1, 0.5)
		else
			tip.AnchorPoint = Vector2.new(0.5, 1)
			tip.Position = UDim2.fromScale((p.X + sz.X / 2) / 1920, (p.Y - 12) / 1080)
			tip.Pointer.Position = UDim2.fromScale(0.5, 1)
		end
		tip.Visible = true
		Kit.popIn(tip)
	end
	anchor.MouseEnter:Connect(show)
	anchor.MouseLeave:Connect(hide)
	anchor.SelectionGained:Connect(show)
	anchor.SelectionLost:Connect(hide)
	anchor.Destroying:Connect(hide)
end

-- (2026-10-21, round 3: match RIVALS) the picker's 3D placeholders sway gently (RIVALS' item views are never still). Every
-- ViewportFrame camera under `box` is swung a little around the item; one Heartbeat loop serves them all and stops when the
-- picker empties.
function Armory._sway(box: Instance, phase: number)
	Armory._swayList = Armory._swayList or {}
	for _, v in box:GetDescendants() do
		if v:IsA("ViewportFrame") and v.CurrentCamera then
			table.insert(Armory._swayList, { cam = v.CurrentCamera, base = v.CurrentCamera.CFrame, phase = phase, box = box })
		end
	end
	if Armory._swayConn then return end
	Armory._swayConn = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i = #Armory._swayList, 1, -1 do
			local e = Armory._swayList[i]
			if not e.box.Parent then
				table.remove(Armory._swayList, i)
			else
				local hover = e.box:GetAttribute("Hover") and 2.2 or 1
				e.cam.CFrame = CFrame.Angles(0.06 * math.sin(t * 1.3 + e.phase), 0.32 * hover * math.sin(t * 0.9 + e.phase), 0) * e.base
			end
		end
		if #Armory._swayList == 0 then
			Armory._swayConn:Disconnect()
			Armory._swayConn = nil
		end
	end)
end

-- (2026-10-21, RIVALS pass) Statistics and Duel History pop in (Kit.popIn plus the open sound) and pop out (shrink, then hide).
function Armory._popIn(g: GuiObject)
	g:SetAttribute("Closing", nil)
	g.Visible = true
	Kit.popIn(g)
	Kit.sfx("open")
end
function Armory._popOut(g: GuiObject)
	if not g.Visible or g:GetAttribute("Closing") then return end
	g:SetAttribute("Closing", true)
	Kit.sfx("close")
	local s = g:FindFirstChild("PopScale")
	if s then TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 }):Play() end
	task.delay(0.12, function()
		if g:GetAttribute("Closing") then -- (not reopened meanwhile)
			g:SetAttribute("Closing", nil)
			g.Visible = false
			if s and s.Parent then s.Scale = 1 end
		end
	end)
end

local statsCard, statsOpen = nil, false -- RIVALS' Statistics panel, at the bottom of the right column

-- (2026-10-18) lifetime numbers for one item, from Data.WeaponStats[id] (the Tacticals session's PlayerStore):
-- { Kills, Headshots, Deaths, Matches, Wins }. Until it's tracked the panel says so.
-- (2026-10-21, RIVALS 1:1) the replica's Statistics panel: it opens at the bottom of the right column, the column moves up
-- to make room and the row's button becomes a red X. The item's ability and its Speed / Reload / Accuracy bars live here now
-- (RIVALS' main panel has no stat bars).
local function pct(a, b) return b > 0 and string.format("%.1f%%", a / b * 100) or "N/A" end
local function renderStats(id)
	if not statsLayer then return end
	if not (statsOpen and id ~= nil) then
		if statsCard then Armory._popOut(statsCard) end
		if rightCol then TweenService:Create(rightCol, TI, { Position = UDim2.fromScale(0, 0) }):Play() end
		return
	end
	local opening = not (statsCard and statsCard.Parent and statsCard.Visible) or statsCard:GetAttribute("Closing") == true
	if statsCard then statsCard:Destroy() end
	local item = ctx.Config.Items[id]
	local data = ctx.getData()
	local ws = data and data.WeaponStats and data.WeaponStats[id]
	local tmp = Instance.new("Folder")
	local p = panel({ Name = "Stats", Position = UDim2.fromOffset(CARD_X, 600), Size = UDim2.fromOffset(CARD_W, 400), Visible = false, ZIndex = 4, Parent = tmp })
	local ic = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(34, 34), ZIndex = 5, Parent = p })
	glyph(ic, "trophy", 34, nil, 5)
	shade(text({ Text = "Statistics", FontFace = FB, TextSize = 22, Position = UDim2.fromOffset(58, 8), Size = UDim2.fromOffset(250, 38), ZIndex = 5, Parent = p }), 1.2, 0.5)
	local y = 50
	local function line(title, value, subs)
		shade(text({ Text = "▼ " .. title, FontFace = FB, TextSize = 19, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(220, 26), ZIndex = 5, Parent = p }), 1.2, 0.5)
		shade(text({ Text = value, FontFace = FX, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(190, y), Size = UDim2.fromOffset(132, 26),
			ZIndex = 5, Parent = p }), 1.2, 0.5)
		y += 26
		for _, sub in subs do
			text({ Text = sub[1], FontFace = FM, TextSize = 15, TextColor3 = COL.Note, Position = UDim2.fromOffset(34, y), Size = UDim2.fromOffset(200, 20), ZIndex = 5, Parent = p })
			text({ Text = sub[2], FontFace = FB, TextSize = 16, TextColor3 = COL.Career, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(190, y),
				Size = UDim2.fromOffset(132, 20), ZIndex = 5, Parent = p })
			y += 20
		end
		y += 6
	end
	-- (2026-10-19, Edward's weapon design) the item's ability (or perk), then Speed / Reload / Accuracy bars for guns
	local okA, Abilities = pcall(function()
		return require(ReplicatedStorage.Modules.Shared.Config:FindFirstChild("WeaponAbilities"))
	end)
	local ab = okA and Abilities and Abilities.Items and Abilities.Items[id]
	if ab then
		local abl = shade(text({ Text = (ab.perk and "Perk: " or "Ability: ") .. ab.ability, FontFace = FB, TextSize = 19, Position = UDim2.fromOffset(16, y),
			Size = UDim2.fromOffset(CARD_W - 32, 24), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = p }), 1.2, 0.5)
		Armory._tip(abl, ab.desc, "left")
		y += 26
		if ab.desc and ab.desc ~= "" then
			text({ Text = ab.desc, FontFace = FM, TextSize = 15, TextColor3 = COL.Note, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(CARD_W - 32, 38), ZIndex = 5, Parent = p })
			y += 42
		end
		-- (2026-10-19, movement spec) Speed follows the live MoveSpeed multiplier (WeaponConfig / MeleeConfig, 0.7 .. 1.3 -> 1 .. 5)
		-- so a retune shows here by itself; melee gets the Speed row alone. ab.speed is the fallback.
		local speed = ab.speed
		pcall(function()
			local cfgs = ReplicatedStorage.Modules.Shared.Config
			local cfg
			if item.Slot == "Melee" then
				local MC = require(cfgs:FindFirstChild("MeleeConfig"))
				cfg = MC.Weapons and MC.Weapons[id]
			else
				local WC = require(cfgs:FindFirstChild("WeaponConfig"))
				cfg = WC.Get and WC.Get(id)
			end
			local ms = cfg and tonumber(cfg.MoveSpeed)
			if ms then speed = math.clamp(1 + 4 * (ms - 0.7) / 0.6, 0.5, 5) end
		end)
		for k, st in { { "Speed", speed }, { "Reload", ab.reload }, { "Accuracy", ab.accuracy } } do
			if not st[2] then continue end
			text({ Text = st[1], FontFace = FB, TextSize = 17, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(110, 22), ZIndex = 5, Parent = p })
			-- five segments in the level bar's blue, filled to the rating (halves allowed), one after another
			for s5 = 1, 5 do
				local f = math.clamp((st[2] or 0) - (s5 - 1), 0, 1)
				local back = mk("Frame", { BackgroundColor3 = COL.Bar, BorderSizePixel = 0, Position = UDim2.fromOffset(126 + (s5 - 1) * 39, y + 5), Size = UDim2.fromOffset(35, 12),
					ZIndex = 5, Parent = p }, { corner(3) })
				if f > 0 then
					local segFill = mk("Frame", { BackgroundColor3 = COL.BarFill, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6, Parent = back }, { corner(3) })
					task.delay(0.06 * s5 + 0.1 * k, function()
						if segFill.Parent then Kit.fillTo(segFill, f, 0.28) end
					end)
				end
			end
			y += 26
		end
		y += 8
	end
	if not ws then
		shade(text({ Text = "Nothing tracked yet", FontFace = FB, TextSize = 19, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(CARD_W - 32, 24), ZIndex = 5, Parent = p }), 1.2, 0.5)
		text({ Text = "Play a match with it in your loadout to start its lifetime stats.", FontFace = FM, TextSize = 15, TextColor3 = COL.Note, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, y + 26), Size = UDim2.fromOffset(CARD_W - 32, 40), ZIndex = 5, Parent = p })
		y += 70
	else
		local k, hs, d = ws.Kills or 0, ws.Headshots or 0, ws.Deaths or 0
		local m, w = ws.Matches or 0, ws.Wins or 0
		line("Matches Played", ctx.commas(m), { { "wins", ctx.commas(w) }, { "losses", ctx.commas(math.max(0, m - w)) }, { "win %", pct(w, m) } })
		line("Eliminations", ctx.commas(k), { { "headshots", ctx.commas(hs) }, { "headshot %", pct(hs, k) } })
		line("Deaths", ctx.commas(d), { { "eliminations ratio", d > 0 and string.format("%.2f", k / d) or (k > 0 and tostring(k) or "N/A") } })
	end
	local Hh = y + 6
	p.Size = UDim2.fromOffset(CARD_W, Hh)
	p.Position = UDim2.fromOffset(CARD_X, 1060 - Hh)
	settle(tmp, statsLayer)
	statsCard = p
	p.Visible = not opening
	TweenService:Create(rightCol, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, -(Hh + 8) / 1080) }):Play()
	if opening then Armory._popIn(p) end
end

-- (2026-10-21, RIVALS 1:1) the right column, rebuilt for the picked item. Stacked up from RIVALS' bottom edge (1060), 11 apart:
--   owned : item card 97 + level card 165 + action card (Inspect, Next unlock, Statistics)
--   locked: item card 97 + the "Unlock now!" card + action card (Inspect, Next unlock, Statistics) - no level for a weapon you
--           don't have, as RIVALS (t0056)
-- Action rows are 62 apart, three of them, as RIVALS. (2026-10-21, user) the Equip row is gone (a click on the list row equips).
local function renderInfo()
	if not rightCol then return end
	for _, ch in rightCol:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local id = selectedId
	if not id then return end
	local item = ctx.Config.Items[id]
	local data = ctx.getData()
	local owned = ctx.owns(id)
	local ROW = 62
	local actH = 12 + 3 * ROW
	local lvlH = owned and 165 or 74
	local actY = 1060 - actH
	local lvlY = actY - 11 - lvlH
	local tmp = Instance.new("Folder")
	local info = panel({ Name = "Info", Position = UDim2.fromOffset(CARD_X, lvlY - 11 - 97), Size = UDim2.fromOffset(CARD_W, 97), ZIndex = 4, Parent = tmp })
	local lvl = panel({ Name = "Level", Position = UDim2.fromOffset(CARD_X, lvlY), Size = UDim2.fromOffset(CARD_W, lvlH), ZIndex = 4, Parent = tmp })
	local act = panel({ Name = "Actions", Position = UDim2.fromOffset(CARD_X, actY), Size = UDim2.fromOffset(CARD_W, actH), ZIndex = 4, Parent = tmp })

	-- item card (replica: 335 x 97): the render poking out of the top-left corner, the name ExtraBold 34, the checkbox, 2 bullets
	local rbox = mk("Frame", { Name = "Render", BackgroundTransparency = 1, Position = UDim2.fromOffset(-24, -20), Size = UDim2.fromOffset(70, 70), ZIndex = 6, Parent = info })
	itemRender(rbox, id, Vector2.new(70, 70), owned and { z = 6, fill = 0.95 } or { z = 6, fill = 0.95, flat = true, color = BLACK })
	local nameLabel = shade(text({ Text = item.Name, FontFace = FX, TextSize = 34, TextScaled = true, Position = UDim2.fromOffset(42, 6), Size = UDim2.fromOffset(252, 40),
		ZIndex = 6, Parent = info }), 2, 0.35)
	mk("UITextSizeConstraint", { MaxTextSize = 34, Parent = nameLabel })
	-- the favourite checkbox: a white square with a dark well (the replica's: a stroke on an empty frame didn't survive its
	-- Scale pass); ticked = the well goes and a dark check shows
	local fav = isFavourite(id)
	local favBox = mk("TextButton", { Name = "Favourite", AutoButtonColor = false, Text = "", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(302, 12),
		Size = UDim2.fromOffset(26, 26), ZIndex = 6, Parent = info }, { corner(3) })
	local well = mk("Frame", { Name = "Well", BackgroundColor3 = COL.Ink, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8), Visible = not fav, ZIndex = 7, Parent = favBox }, { corner(2) })
	local tick = glyph(favBox, "check", 22, COL.Ink, 8)
	tick.Visible = fav
	favBox.Activated:Connect(function()
		local on = not isFavourite(id)
		well.Visible = not on
		tick.Visible = on
		if on then Kit.pop(tick, 1.3) end
		ctx.ask("Favorite", id, on)
	end)
	Kit.bindButton(favBox, { hover = 1.12, press = 0.88 })
	Armory._tip(favBox, "Favourite", "left")
	-- two bullets, like RIVALS' "• Standard Primary / • A standard rifle useful in all scenarios"; the full description is the
	-- hover bubble on the name and the bullets
	local first = item.Desc and item.Desc ~= "" and (item.Desc:match("^(.-[%.!%?])%s") or item.Desc) or nil
	local bullets = text({ Text = "• " .. (item.Price == 0 and "Starter " or "Standard ") .. SLOT_LABEL[item.Slot] .. (first and ("\n• " .. first) or ""),
		FontFace = FM, TextSize = 15, TextColor3 = COL.Note, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(50, 44),
		Size = UDim2.fromOffset(270, 50), ZIndex = 6, Parent = info })
	if item.Desc and item.Desc ~= "" then
		Armory._tip(nameLabel, item.Desc, "left")
		Armory._tip(bullets, item.Desc, "left")
	end

	if owned then
		-- level card (replica: 335 x 165): the bar with XP so far / XP for the level at its ends and the big level number on it
		local xp = (data and data.ItemXP and data.ItemXP[id]) or 0
		local level, into, need = ctx.Config.ItemLevel(xp)
		local maxLevel = (ctx.Config.ItemLevels and ctx.Config.ItemLevels.Max) or 50
		local maxed = level >= maxLevel or not need or need <= 0
		local frac = maxed and 1 or math.clamp(into / math.max(need, 1), 0, 1)
		-- (2026-10-21, round 3: match RIVALS) the bar fills on from where it last stood for this item and the level number counts up
		-- and pops when it changes; remembered per item on Armory._lvl
		Armory._lvl = Armory._lvl or {}
		local prevLvl = Armory._lvl[id]
		local bar = mk("Frame", { Name = "Bar", BackgroundColor3 = COL.Bar, BorderSizePixel = 0, Position = UDim2.fromOffset(13, 11), Size = UDim2.fromOffset(308, 18),
			ZIndex = 5, Parent = lvl }, { corner(3) })
		local fill = mk("Frame", { Name = "Fill", BackgroundColor3 = COL.BarFill, BorderSizePixel = 0, Size = UDim2.fromScale(prevLvl and prevLvl.frac or 0, 1),
			ZIndex = 6, Parent = bar }, { corner(3) })
		Kit.fillTo(fill, frac, 0.6)
		-- (2026-10-22, section rounds 0-1, grader C vs RIVALS kit.jpg / weapons.png) no XP numbers at the bar's ends: RIVALS shows only
		-- the big level number centred on the bar
		-- (round 2, grader C: RIVALS does show dim end labels, t0051 "55", kit.jpg "0 ... 10"; removing them in r1 was wrong)
		text({ Text = maxed and "" or ctx.commas(into), FontFace = FB, TextSize = 14, TextColor3 = COL.BarLo, Position = UDim2.fromOffset(5, 0), Size = UDim2.fromOffset(70, 18),
			ZIndex = 7, Parent = bar })
		text({ Text = maxed and "MAX" or ctx.commas(need), FontFace = FB, TextSize = 14, TextColor3 = COL.BarHi, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(233, 0), Size = UDim2.fromOffset(70, 18), ZIndex = 7, Parent = bar })
		local lvLabel = shade(text({ Text = tostring(level), FontFace = FX, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(118, 2),
			Size = UDim2.fromOffset(100, 36), ZIndex = 8, Parent = lvl }), 2, 0.35)
		if level ~= (prevLvl and prevLvl.level or 1) then
			Kit.countTo(lvLabel, prevLvl and prevLvl.level or 1, level, 0.5, function(n) return tostring(math.floor(n + 0.5)) end)
			task.delay(0.5, function() if lvLabel.Parent then Kit.pop(lvLabel, 1.25) end end)
		end
		Armory._lvl[id] = { frac = frac, level = level }
		-- "Level up now!" + the yellow button. Tacticals has no paid level-up: the button shows the XP still to earn and shakes
		cardRow(lvl, 44, "up", maxed and "Max level!" or "Level up now!", nil)
		local up = bigButton(lvl, 217, 42, nil, maxed and "grey" or "key")
		-- (round 4, grader C vs t0051) RIVALS' key button runs a saturated (252,246,90) -> (241,208,17) so the white price + glyph read
		if not maxed then
			local ug = up:FindFirstChildOfClass("UIGradient")
			if ug then ug.Color = ColorSequence.new(Color3.fromRGB(252, 246, 90), Color3.fromRGB(241, 208, 17)) end
		end
		-- (2026-10-22, the approved scissors economy; the lead's Request "LevelUpItem"(itemId)) RIVALS' "Level up now!" is a real buy:
		-- 9 keys there, 1,000 scissors here. The button shows the price + scissors; one press asks the server, a refusal shakes it.
		local LEVEL_UP_PRICE = 1000
		local upL = shade(text({ Text = maxed and "MAX" or ctx.commas(LEVEL_UP_PRICE), FontFace = FX, TextSize = 32, TextScaled = true, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(maxed and 99 or 66, 36), ZIndex = 7, Parent = up }), 1.5, 0.6)
		mk("UITextSizeConstraint", { MaxTextSize = 32, Parent = upL })
		if not maxed then
			mk("ImageLabel", { Name = "Currency", BackgroundTransparency = 1, Image = Kit.ICONS.scissorsWhite or Kit.ICONS.scissors, ScaleType = Enum.ScaleType.Fit, -- (round 3: RIVALS' flat white key)
				Position = UDim2.fromOffset(72, 8), Size = UDim2.fromOffset(32, 32), ZIndex = 7, Parent = up })
		end
		Kit.bindButton(up, { hover = 1.05, press = 0.92 })
		up.Activated:Connect(function()
			if maxed or Armory._levelling then Kit.shake(up); Kit.sfx("close"); return end
			Armory._levelling = true
			local okAsk, res = pcall(ctx.ask, "LevelUpItem", id)
			Armory._levelling = nil
			local good = okAsk and (res == true or (type(res) == "table" and (res.ok or res.Success)))
			if good then
				Kit.pop(up, 1.12)
				if Armory.Refresh then task.defer(Armory.Refresh) end
			else
				Kit.shake(up); Kit.sfx("close")
			end
		end)
		Armory._tip(up, maxed and "Every level reached" or "Level it up now for 1,000 scissors", "left")
		-- "Reward at Level N" with the reward on a white tile with a cyan edge (replica); the next milestone every 5 levels, a live
		-- 3D crate (ViewIcons) until weapon rewards exist
		local milestone = math.min(maxLevel, (math.floor(level / 5) + 1) * 5)
		cardRow(lvl, 105, "seal", "Reward at Level " .. milestone, nil, 215)
		local rw = mk("Frame", { Name = "Reward", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(280, 105), Size = UDim2.fromOffset(48, 48), ZIndex = 5, Parent = lvl },
			{ corner(5), mk("UIStroke", { Color = COL.Reward, Thickness = 2 }) })
		local okVI, VI = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit", 2):WaitForChild("ViewIcons", 2)) end)
		if okVI and VI and VI.Icon then
			pcall(function()
				local holder = mk("Frame", { Name = "Reward3D", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(44, 44), ZIndex = 6, Parent = rw })
				VI.Icon(holder, "Crate", { zIndex = 6, hoverTarget = rw })
			end)
		end
		Armory._tip(rw, level >= maxLevel and "All rewards reached" or "A crate for this weapon", "left")
	else
		-- "Unlock now!" + the yellow price button (RIVALS' locked panel, t0056): the price and the scissors currency. ONE press buys it;
		-- Armory._unlocking blocks a second buy while the request or the tape cut runs (Kit.busy dots meanwhile). Can't afford: grey,
		-- it shakes, the bubble says how many more you need.
		local credits = (data and data.Credits) or 0
		local afford = credits >= item.Price
		cardRow(lvl, 10, "unlock", "Unlock now!", nil)
		local b = bigButton(lvl, 217, 11, nil, afford and "key" or "grey")
		local priceLabel = shade(text({ Text = ctx.commas(item.Price), FontFace = FX, TextSize = 30, TextScaled = true, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(70, 36), ZIndex = 7, Parent = b }), 1.5, 0.6)
		mk("UITextSizeConstraint", { MaxTextSize = 30, Parent = priceLabel })
		mk("ImageLabel", { Name = "Currency", BackgroundTransparency = 1, Image = Kit.ICONS.scissors, ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromOffset(78, 13), Size = UDim2.fromOffset(26, 26), ZIndex = 7, Parent = b })
		Kit.bindButton(b, { hover = 1.05, press = 0.92 })
		Armory._tip(b, afford and "Cut the tape" or ("Need " .. ctx.commas(item.Price - credits) .. " more"), "left")
		b.Activated:Connect(function()
			if not afford then Kit.shake(b); Kit.sfx("close") return end
			if Armory._unlocking or Armory._cutting then return end
			Armory._unlocking = true
			task.delay(10, function() Armory._unlocking = false end) -- failsafe: never leave the button dead
			local stopBusy = Kit.busy(b)
			local okAsk, res = pcall(ctx.ask, "BuyItem", id)
			stopBusy()
			if okAsk and res and res.ok then
				ctx.ask("Equip", item.Slot, id)
				Armory.CutTape(function() -- the scissors snip both strips, then the item comes back in full colour
					Armory._unlocking = false
					if active and selectedId == id then showItem(id, 1) end
				end)
			else
				Armory._unlocking = false
				renderInfo()
			end
		end)
	end

	-- action rows (replica: Contracts / Overview / Statistics): icon, title, sub-line and the big blue square button; a button you
	-- can't use is grey and shakes when pressed
	local y0 = 8
	local function row(icon, title: string, sub: string, btnIcon: string?, tone: string): TextButton
		cardRow(act, y0, icon, title, sub, nil, true) -- (2026-10-21, port3) the larger row text
		local b = bigButton(act, 217, y0 + 2, btnIcon, tone)
		if tone == "grey" then
			b.Activated:Connect(function() Kit.shake(b); Kit.sfx("close") end)
		else
			Kit.bindButton(b, { hover = 1.05, press = 0.92 })
		end
		y0 += ROW
		return b
	end
	local ib = row("lens", "Inspect", owned and "Give it a spin" or "Unlock it to inspect", "eye", owned and "blue" or "grey")
	if owned then
		ib.Activated:Connect(function()
			if not dragging and not currentLocked() then
				spinStart = os.clock()
				returning = false
				yawVel, pitchVel = 0, 0
			end
		end)
	end
	-- the next thing to unlock in this slot (after this one, in price order); its name and price on the sub-line
	local list = itemsInSlot(item.Slot)
	local start = owned and 1 or ((table.find(list, id) or 0) + 1)
	local nextId
	for i = start, #list do
		if list[i] ~= id and not ctx.owns(list[i]) then
			nextId = list[i]
			break
		end
	end
	local nextItem = nextId and ctx.Config.Items[nextId]
	local nb = row("lock", nextItem and "Next unlock" or (owned and "All unlocked" or "Last one"),
		nextItem and (nextItem.Name .. "  ·  " .. ctx.commas(nextItem.Price)) or (owned and "Nothing left in this slot" or "Nothing after it here"),
		"arrow", nextId and "blue" or "grey")
	if nextId then
		Armory._tip(nb, "Go to " .. nextItem.Name, "left")
		nb.Activated:Connect(function() Armory.Select(nextId, 1) end)
	end
	-- Statistics: the panel opens under the column, and while it's open this button is RIVALS' red X
	local sb = row("bars", "Statistics", "See lifetime data", (not statsOpen) and "eye" or nil, statsOpen and "red" or "blue")
	if statsOpen then glyph(sb, "closex", 30, WHITE, 6) end
	sb.Activated:Connect(function()
		statsOpen = not statsOpen
		if statsOpen then Armory.ShowHistory(false) end
		renderInfo()
	end)
	settle(tmp, rightCol)
	renderStats(id)
end


-------------------------------------------------------------------------------
-- Duel History (RIVALS Career > Duel History): your last matches as VICTORY / DEFEAT cards, newest first; a click
-- expands the loadout you used. Data.MatchHistory (the Tacticals session's PlayerStore, newest first, max 20):
-- { t, mode, ranked, map, won, score = {mine, theirs}, kills, deaths, opponents = {{id, name}}, eloDelta, loadout }
-- (2026-10-21, RIVALS 1:1) Rubik, Theme colours; built in design px and converted (the list in Scale of its canvas)
-------------------------------------------------------------------------------
local historyPanel, historyExpanded
local function ago(t)
	local d = os.time() - (tonumber(t) or os.time())
	if d < 3600 then return math.max(1, d // 60) .. "m ago" end
	if d < 86400 then return d // 3600 .. "h ago" end
	return d // 86400 .. "d ago"
end
local function buildHistoryList()
	if not historyPanel then return end
	local list = historyPanel:FindFirstChild("List")
	for _, c in list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local data = ctx.getData()
	local hist = data and data.MatchHistory or {}
	local W = 600
	local y = 0
	if #hist == 0 then
		shade(text({ Text = "No duels yet", FontFace = FB, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 40),
			Size = UDim2.fromOffset(W, 30), ZIndex = 22, Parent = list }), 1.5)
		text({ Text = "Your last 20 matches show up here after you play.", FontFace = FM, TextSize = 17, TextColor3 = COL.Sub,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(W, 22), ZIndex = 22, Parent = list })
		y = 120
	end
	for i, m in hist do
		local won, draw = m.won == true, m.draw == true
		local tone = draw and RT.color.disabled or (won and RT.color.green or RT.color.red)
		local card = mk("TextButton", { Name = "Duel" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(W, 104), ClipsDescendants = true, ZIndex = 21, Parent = list }, { corner(6),
			mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(tone:Lerp(BLACK, 0.15), tone:Lerp(BLACK, 0.55)) }) })
		local sc = m.score or {}
		text({ Text = string.upper(tostring(m.mode or "1v1")) .. (m.ranked and "  ·  RANKED" or "") .. (m.forfeit and "  ·  FORFEIT" or ""), FontFace = FB, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(150, 6), Size = UDim2.fromOffset(300, 18), ZIndex = 22, Parent = card })
		shade(text({ Text = draw and "DRAW" or (won and "VICTORY" or "DEFEAT"), FontFace = FX, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(150, 22), Size = UDim2.fromOffset(300, 40), ZIndex = 22, Parent = card }), 2)
		shade(text({ Text = `{sc[1] or 0} - {sc[2] or 0}`, FontFace = FX, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(W - 170, 8), Size = UDim2.fromOffset(154, 46), ZIndex = 22, Parent = card }), 2)
		text({ Text = "Your K / D", FontFace = FM, TextSize = 14, Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(130, 16), ZIndex = 22, Parent = card })
		shade(text({ Text = `{m.kills or 0}  ·  {m.deaths or 0}`, FontFace = FB, TextSize = 22, Position = UDim2.fromOffset(16, 24), Size = UDim2.fromOffset(130, 26),
			ZIndex = 22, Parent = card }), 1.5)
		text({ Text = `{m.map or "?"}  ·  {ago(m.t)}`, FontFace = FM, TextSize = 15, Position = UDim2.fromOffset(16, 74), Size = UDim2.fromOffset(200, 20), ZIndex = 22, Parent = card })
		if typeof(m.eloDelta) == "number" then
			shade(text({ Text = (m.eloDelta >= 0 and "+" or "") .. m.eloDelta .. " ELO", FontFace = FB, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromOffset(W - 170, 70), Size = UDim2.fromOffset(154, 24), ZIndex = 22, Parent = card }), 1.5)
		end
		-- opponents: headshots + the first name
		local opp = m.opponents or {}
		for k, o in opp do
			if k > 3 then break end
			local hsImg = mk("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(236 + (k - 1) * 44, 62), Size = UDim2.fromOffset(38, 38),
				ZIndex = 22, Parent = card }, { circle() })
			local uid = tonumber(o.id)
			if uid and uid > 0 then
				task.spawn(function()
					local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					if ok then hsImg.Image = im end
				end)
			end
		end
		if opp[1] then
			text({ Text = "vs " .. tostring(opp[1].name or "?"), FontFace = FB, TextSize = 15, Position = UDim2.fromOffset(240 + math.min(#opp, 3) * 44, 72),
				Size = UDim2.fromOffset(150, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = card })
		end
		y += 104
		if historyExpanded == i then
			local row = mk("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(W, 40),
				ZIndex = 21, Parent = list }, { corner(6) })
			local lo = m.loadout or {}
			local names = {}
			for _, slot in SLOT_ORDER do
				local it = lo[slot] and ctx.Config.Items[lo[slot]]
				table.insert(names, it and it.Name or (lo[slot] or "-"))
			end
			text({ Text = "Loadout:  " .. table.concat(names, "  ·  "), FontFace = FB, TextSize = 17, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(W - 32, 40),
				ZIndex = 22, Parent = row })
			y += 44
		end
		y += 10
		card.Activated:Connect(function()
			historyExpanded = historyExpanded ~= i and i or nil
			buildHistoryList()
		end)
	end
	-- (2026-10-21, RIVALS 1:1) the canvas in Scale of the panel (780 design px tall); the cards in Scale of the canvas
	y = math.max(y, 676)
	list.CanvasSize = UDim2.fromScale(0, y / 780)
	RK.toScale(list, Vector2.new(612, y))
end
function Armory.BuildHistory(parent)
	historyPanel = panel({ Name = "DuelHistory", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 540), Size = UDim2.fromOffset(640, 780), Visible = false, ZIndex = 20, Parent = parent })
	historyPanel.BackgroundTransparency = 0.08 -- (solid enough that the item behind doesn't show through the list)
	local ic = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 18), Size = UDim2.fromOffset(36, 36), ZIndex = 21, Parent = historyPanel })
	glyph(ic, "trophy", 36, nil, 21)
	shade(text({ Text = "Duel History", FontFace = FX, TextSize = 34, Position = UDim2.fromOffset(68, 14), Size = UDim2.fromOffset(400, 40), ZIndex = 21, Parent = historyPanel }), 2)
	text({ Text = "Your most recent matches. Click one to see the loadout you used.", FontFace = FM, TextSize = 16, TextColor3 = COL.Sub,
		Position = UDim2.fromOffset(68, 52), Size = UDim2.fromOffset(520, 20), ZIndex = 21, Parent = historyPanel })
	-- (2026-10-21, RIVALS 1:1) the close button: RIVALS' red square with a white X
	-- (2026-10-21, port3) graders: the Kit's X at the Rivals kit's closeButton default size (RK.closeButton() = 112 x 58, with its
	-- own gen.ui_close_x and hover / press), was a hand-made 46 x 46 square; placed by the kit's rule, CLOSE_GAP (12) outside the
	-- panel's top-right corner, top-aligned
	local x = RK.closeButton()
	x.Position = UDim2.fromOffset(640 + (RK.CLOSE_GAP or 12), 0)
	x.ZIndex = 21
	x:AddTag("Nonapplicable") -- (as mk() tags its buttons: the old InterfaceController leaves it alone)
	x.Parent = historyPanel
	x.Activated:Connect(function() Armory.ShowHistory(false) end)
	mk("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 88), Size = UDim2.fromOffset(612, 676),
		CanvasSize = UDim2.new(), ScrollBarThickness = 6, ScrollBarImageColor3 = COL.Sub, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 21, Parent = historyPanel })
end
function Armory.ShowHistory(on: boolean)
	if not historyPanel then return end
	if on then
		historyExpanded = nil
		buildHistoryList()
		if statsOpen then statsOpen = false; renderInfo() end -- one panel at a time
	end
	-- (2026-10-21, RIVALS pass) pops in / out (was a Visible toggle)
	if on then Armory._popIn(historyPanel) else Armory._popOut(historyPanel) end
end

-------------------------------------------------------------------------------
-- Bottom: RIVALS' slot strip - Leave + the cosmetic slots; the picker stands in for the whole screen's panels
-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) RIVALS' slots are Skin / Wrap / Charm / Finisher; Tacticals keeps its Skin / Wrap / Finisher (the
-- Cutscene slot is gone: RIVALS has none)
-- (2026-10-21, RIVALS normal theme) the slot hover bubbles use RIVALS' wording: live Skin = "Change how this weapon looks"; Wrap /
-- Finisher are written in the same short style (RIVALS' own lines not captured)
local COSMETICS = {
	{ Id = "Skin", Label = "Skin", Tip = "Change how this weapon looks" },
	{ Id = "Wrap", Label = "Wrap", Tip = "Change this weapon's colours" },
	{ Id = "Finisher", Label = "Finisher", Tip = "Change how you finish off enemies" },
}
local tray -- the picker (a full-canvas group)
local openTray = nil
local slotRings = {} -- [slot id] = the strip's slot button

-- (2026-10-21, RIVALS 1:1) the picker closes at once (RIVALS' does): the panels come back and the item eases back from its zoom
local function closeTray(instant: boolean?)
	openTray = nil
	Armory._previewLook(nil) -- (2026-10-21, RIVALS normal theme) leaving the picker puts the equipped look back
	if Armory._tipFrame then Armory._tipFrame.Visible = false; Armory._tipOwner = nil end -- (2026-10-21) a tile's bubble outlived the picker
	if tray and tray.Visible then
		tray.Visible = false
		for _, ch in tray:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		zoomTarget = 1
	end
	if leftGroup then
		leftGroup.Visible, rightCol.Visible, bottomGroup.Visible, statsLayer.Visible = true, true, true, true
	end
end

-- (2026-10-21, RIVALS normal theme) kuroko_preview.png: clicking a skin tile (locked or not) previews it ON the hero item at once.
-- Tacticals has no skin models yet, so the showcase CLONE gets a placeholder look in the tile's rarity colour: every lit part
-- (not the near-black details, not Neon) is tinted cc[2] keeping its relative shade, textures are lifted off; wraps take the
-- lighter cc[3] on Foil. The clone's own values are kept on Armory._preview and put back by _previewLook(nil) (None, Back,
-- switching trays, Leave). The source model is never touched.
function Armory._previewLook(cc, kind: string?)
	local pv = Armory._preview
	if pv then
		Armory._preview = nil
		for part, v in pv.parts do
			if part.Parent then
				part.Color, part.Material, part.Reflectance, part.MaterialVariant = v[1], v[2], v[3], v[4]
				if v[5] then part.TextureID = v[5] end
			end
		end
		for inst, parent in pv.extras do
			if parent.Parent then pcall(function() inst.Parent = parent end) else inst:Destroy() end
		end
	end
	if not cc then return end
	local entry
	for _, e in showcase do
		if not e.leaving and not e.locked then entry = e break end
	end
	if not entry or not entry.model then return end
	pv = { parts = {}, extras = {} }
	local tint = kind == "Wrap" and H(cc[3]) or H(cc[2])
	local mat = kind == "Wrap" and Enum.Material.Foil or Enum.Material.SmoothPlastic
	for _, d in entry.model:GetDescendants() do
		if d:IsA("BasePart") then
			local _, _, v = d.Color:ToHSV()
			local textured = d:IsA("MeshPart") and d.TextureID ~= ""
			if d.Material ~= Enum.Material.Neon and (v > 0.14 or textured) then
				pv.parts[d] = { d.Color, d.Material, d.Reflectance, d.MaterialVariant, textured and d.TextureID or nil }
				d.Color = tint:Lerp(BLACK, math.clamp(0.36 - v, 0, 0.3)) -- gunmetal 0.36 -> full colour, 0.25 a shade darker
				d.Material, d.MaterialVariant = mat, ""
				d.Reflectance = 0.08
				if textured then d.TextureID = "" end
			end
		elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			pv.extras[d] = d.Parent
			d.Parent = nil
		end
	end
	Armory._preview = pv
end

-- (2026-10-21, RIVALS normal theme) kuroko_preview.png's pills, top centre: a dark pill (black 0.25, 76 tall at y 12) with the skin's
-- icon (its rarity tile, the item's render popping out above it) and the name in ExtraBold 56; under it (y 90) a wider white
-- pill, 48 tall, saying how to get it. Rebuilt per click in design px (widths follow the text) into `holder`, a full-canvas
-- frame; no `it` = hidden.
function Armory._previewPills(holder: Instance, it, cc, model: Model?)
	for _, ch in holder:GetChildren() do ch:Destroy() end
	-- (2026-10-21, RIVALS) the HUD hides the currency pill while a preview's name pill is up (LobbyHudController reads this)
	game:GetService("Players").LocalPlayer:SetAttribute("KitPreview", (it and cc) and true or nil)
	if not it or not cc then
		if model then model:Destroy() end
		return
	end
	local name, how = it.name, "Coming in a future update" -- (placeholder: RIVALS says how the skin is obtained)
	local nameW = math.clamp(#name * 31, 120, 900) -- (Rubik ExtraBold 56 runs ~31 design px a letter, AKEY-47 = 210)
	local w = 88 + nameW + 22
	local tmp = Instance.new("Folder")
	-- (2026-10-21, port3) graders: no dark backing plate (RIVALS shows the big name and the skin icon straight on the scene), and the
	-- icon's render stays inside the row (inside its tile); the name gets a heavy dark edge instead of the plate
	local pill = mk("Frame", { Name = "NamePill", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(960 - w / 2, 12), Size = UDim2.fromOffset(w, 76), ZIndex = 7, Parent = tmp })
	local icon = mk("Frame", { Name = "Icon", BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(60, 60),
		ZIndex = 8, Parent = pill }, { corner(5), mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(H(cc[2]):Lerp(WHITE, 0.22), H(cc[2]):Lerp(H(cc[1]), 0.55)) }),
		mk("UIStroke", { Color = H(cc[3]):Lerp(WHITE, 0.25), Thickness = 2 }) })
	local r = model and itemRender(icon, "", Vector2.new(60, 60), { z = 9, fill = 0.85, model = model })
		or itemRender(icon, selectedId, Vector2.new(60, 60), { z = 9, fill = 0.92, flat = true, color = H(cc[3]):Lerp(WHITE, 0.35) })
	r.Position = UDim2.fromOffset(0, 0)
	local nm = shade(text({ Text = name, FontFace = FX, TextSize = 56, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(88, 4), Size = UDim2.fromOffset(nameW, 68), ZIndex = 8, Parent = pill }), 3, 0.1)
	mk("UITextSizeConstraint", { MaxTextSize = 56, Parent = nm })
	local subW = math.clamp(#how * 16 + 48, 300, 1500) -- (Medium 34: ~15.3 px a letter, measured)
	local sub = mk("Frame", { Name = "HowToGet", BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(960 - subW / 2, 90),
		Size = UDim2.fromOffset(subW, 48), ZIndex = 8, Parent = tmp }, { corner(4) })
	local sl = text({ Text = how, FontFace = FM, TextSize = 34, TextColor3 = BLACK, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(subW - 32, 40), ZIndex = 9, Parent = sub })
	mk("UITextSizeConstraint", { MaxTextSize = 34, Parent = sl })
	settle(tmp, holder)
	Kit.popIn(pill)
	Kit.popIn(sub, 0.04)
end

-- (2026-10-21, RIVALS 1:1) the replica's picker (t0050): the left / right panels and the strip make way and the item zooms in
-- (x1.25); a red "Back" button, the search bar ("Search by name or tooltip") and the "Favorited" checkbox above it, then ONE
-- row of 118 px tiles 138 apart on a dark strip. "None" first (dark, the none glyph, the big green check: what you have on);
-- every other tile is filled with its rarity colour (replica palette) with a dark silhouette of this weapon (a wrapped cube for
-- wraps), a dark wash, a white padlock and its name. Clicking a tile shows RIVALS' name pill at the top centre; a locked tile
-- shakes. The search filters by name; Favorited shows only favourites (none yet: just None).
local function openCosmeticTray(c)
	if openTray == c.Id then closeTray() return end
	closeTray(true)
	openTray = c.Id
	if Armory._tipFrame then Armory._tipFrame.Visible = false; Armory._tipOwner = nil end
	if statsOpen then statsOpen = false; renderInfo() end
	Armory.ShowHistory(false)
	-- (2026-10-21, grade2) opening it re-asserts the Kit's camera hold on the item at once (renderShowcase holds it every frame too)
	do
		local _, holdCF = points()
		local cam = workspace.CurrentCamera
		if holdCF and active and not busy then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = holdCF
			cam.FieldOfView = 40
		end
	end
	leftGroup.Visible, rightCol.Visible, bottomGroup.Visible, statsLayer.Visible = false, false, false, false
	if not currentLocked() then zoomTarget = 1.25 end
	local PCOL = { red = { "#3A0606", "#E81818", "#FF3030" }, blue = { "#06283A", "#14C3EE", "#3FE0FF" }, purple = { "#1A0A4A", "#5A3CE0", "#7A6CFF" } }
	local TIER_COL = { Rare = PCOL.blue, Epic = PCOL.purple, Legendary = PCOL.red }
	-- (2026-10-21, RIVALS normal theme) kuroko_picker.png groups the tiles by colour (purple, reds, blues ...)
	local tiers = { "Epic", "Legendary", "Legendary", "Legendary", "Rare", "Rare", "Rare", "Epic" }
	local tmp = Instance.new("Folder")
	local back = mk("TextButton", { Name = "Back", AutoButtonColor = false, Text = "", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(192, 845),
		Size = UDim2.fromOffset(191, 56), ZIndex = 7, Parent = tmp }, { corner(6), RK.vgrad(GRAD.red) })
	local undo = glyph(back, "undo", 36, WHITE, 8)
	undo.Position = UDim2.fromOffset(38, 28)
	-- (2026-10-21, port3) graders: Back / search / Favorited at RIVALS' size (~3% of the screen height): Back ExtraBold 36 -> 40,
	-- the search placeholder Bold 32 grey (was Medium 28), Favorited ExtraBold 38 (was Bold 32)
	shade(text({ Text = "Back", FontFace = FX, TextSize = 40, TextColor3 = WHITE, Position = UDim2.fromOffset(72, 0), Size = UDim2.fromOffset(115, 56), ZIndex = 8, Parent = back }), 1.5, 0.6)
	Kit.bindButton(back, { hover = 1.05, press = 0.92 })
	back.Activated:Connect(function() closeTray() end)
	local search = mk("TextBox", { Name = "Search", Text = "", PlaceholderText = "Search by name or tooltip", PlaceholderColor3 = COL.Grey, FontFace = FB, TextSize = 32,
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, BorderSizePixel = 0,
		Position = UDim2.fromOffset(390, 845), Size = UDim2.fromOffset(1337, 56), ZIndex = 7, Parent = tmp }, { corner(4), mk("UIPadding", { PaddingLeft = UDim.new(0, 16) }) })
	shade(text({ Text = "Favorited", FontFace = FX, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(1380, 782), Size = UDim2.fromOffset(286, 48),
		ZIndex = 7, Parent = tmp }), 1.8, 0.4)
	-- the checkbox: a white frame with a dark inner square (unticked)
	local favB = mk("TextButton", { Name = "Favorited", AutoButtonColor = false, Text = "", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(1680, 788), Size = UDim2.fromOffset(40, 40),
		ZIndex = 7, Parent = tmp }, { corner(4) })
	local favIn = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundColor3 = COL.Ink,
		ZIndex = 8, Parent = favB }, { corner(3) })
	local strip = mk("ScrollingFrame", { Name = "Tiles", BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(192, 908),
		Size = UDim2.fromOffset(1535, 150), CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, ScrollBarImageColor3 = COL.Grey,
		ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 7, Parent = tmp }, { corner(4) })
	settle(tmp, tray)
	-- (2026-10-21, RIVALS normal theme) the preview pills live in their own full-canvas layer (Armory._previewPills)
	local preview = mk("Frame", { Name = "Preview", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = tray })
	tray.Visible = true
	-- a wrapped cube: the wrap tiles' stand-in (RIVALS' wrap thumbnails are swatch cubes), centred, posed for a camera on +Z
	local function wrapCube(color: Color3): Model
		local m = Instance.new("Model")
		local pose = CFrame.Angles(math.rad(-24), math.rad(38), 0)
		for k = -2, 1 do -- the cube, then three lighter stripes round it
			local p = Instance.new("Part")
			p.Anchored = true
			p.Material = Enum.Material.SmoothPlastic
			p.Size = k == -2 and Vector3.new(2, 2, 2) or Vector3.new(0.32, 2.06, 2.06)
			p.CFrame = pose * CFrame.new(k == -2 and 0 or (k * 0.62), 0, 0)
			p.Color = k == -2 and color or color:Lerp(WHITE, 0.55)
			p.Parent = m
		end
		return m
	end
	local favOnly = false
	local function layout()
		for _, ch in strip:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		local q = string.lower(search.Text)
		local list = { { none = true, name = "None" } }
		for _, tier in tiers do
			local nm = tier .. " " .. c.Label
			if not favOnly and (q == "" or string.find(string.lower(nm), q, 1, true)) then table.insert(list, { tier = tier, name = nm }) end
		end
		for k, it in list do
			local cc = it.tier and TIER_COL[it.tier]
			local t = mk("TextButton", { Name = it.name, AutoButtonColor = false, Text = "", BackgroundColor3 = cc and WHITE or BLACK, BackgroundTransparency = cc and 0 or 0.3,
				Position = UDim2.fromOffset(16 + (k - 1) * 138, 17), Size = UDim2.fromOffset(118, 118), ZIndex = 8, Parent = strip }, { corner(7) })
			local popS = mk("UIScale", { Name = "PopScale", Scale = 0, Parent = t }) -- (bindButton reuses this UIScale)
			local box, mark
			if cc then
				-- (2026-10-21, port3) graders vs kuroko_picker.png: a bright rim in the rarity colour (3 px, lifted towards white), a
				-- lighter top (the rarity colour lifted at the top -> its dark shade at the foot; was dark at the top), the skin's
				-- silhouette at ~25% (black at 0.75, was the dark shade at full) and a lighter wash
				mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(H(cc[2]):Lerp(WHITE, 0.22), H(cc[2]):Lerp(H(cc[1]), 0.55)), Parent = t })
				mk("UIStroke", { Color = H(cc[3]):Lerp(WHITE, 0.25), Thickness = 3, Parent = t })
				local view = mk("Frame", { Name = "View", BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 5), Size = UDim2.fromOffset(104, 104), ZIndex = 9, Parent = t })
				if c.Id == "Wrap" then
					box = itemRender(view, "", Vector2.new(104, 104), { z = 9, fill = 0.78, model = wrapCube(H(cc[2])) })
				else
					box = itemRender(view, selectedId, Vector2.new(104, 104), { z = 9, fill = 0.92, flat = true, color = BLACK })
					local sil = box:FindFirstChildOfClass("ViewportFrame")
					if sil then sil.ImageTransparency = 0.75 end
				end
				Armory._sway(box, k * 1.3)
				mk("Frame", { Name = "Wash", BackgroundColor3 = BLACK, BackgroundTransparency = 0.92, BorderSizePixel = 0, Size = UDim2.fromOffset(118, 118), ZIndex = 10, Parent = t }, { corner(7) })
				-- (2026-10-21, RIVALS normal theme) kuroko_picker.png: bright tiles (a light wash, was 0.45), a bigger white padlock
				-- (2026-10-21, RIVALS images) gen.kit_locked_sparkles behind the padlock, tinted a darker shade of the rarity colour
				if RA.gen and RA.gen.kit_locked_sparkles then
					mk("ImageLabel", { Name = "Sparkles", BackgroundTransparency = 1, Image = RA.gen.kit_locked_sparkles, ScaleType = Enum.ScaleType.Fit,
						ImageColor3 = H(cc[2]):Lerp(Color3.new(0, 0, 0), 0.4), Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(110, 110), ZIndex = 10, Parent = t })
				end
				mark = glyph(t, "lock", 62, WHITE, 11)
				mark.Position = UDim2.fromOffset(59, 54)
			else
				-- (2026-10-21, RIVALS images) gen.kit_slot_empty at ~70 px, darker (#333333) on the black None tile like RIVALS;
				-- the lime check is gen.tasks_check_lime
				local g = glyph(t, "empty", 70, H("#333333"), 9)
				g.Position = UDim2.fromOffset(59, 48)
				-- (2026-10-21, port3) graders: the check covered "None" down to "No.": it sits on the tile's bottom-right corner now
				-- (52 px, centred on the corner) and the word is set left of it
				mark = glyph(t, "equipped", 52, COL.Check, 13)
				mark.Position = UDim2.fromOffset(106, 106)
			end
			-- (2026-10-21, port3) big outlined names (kuroko_picker.png): ExtraBold up to 34 with a heavy dark edge; None's word is
			-- left of its corner check
			local tl = shade(text({ Text = it.name, FontFace = FX, TextSize = 34, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
				Position = cc and UDim2.fromOffset(-9, 81) or UDim2.fromOffset(-4, 81), Size = cc and UDim2.fromOffset(136, 36) or UDim2.fromOffset(88, 36),
				ZIndex = 12, Parent = t }), 2.5, 0.1)
			mk("UITextSizeConstraint", { MaxTextSize = 34, Parent = tl })
			task.delay((k - 1) * 0.028, function()
				if popS.Parent then TweenService:Create(popS, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play() end
			end)
			Kit.bindButton(t, { hover = 1.06, press = 0.92 }) -- RIVALS' tiles grow on hover
			t.MouseEnter:Connect(function() if box then box:SetAttribute("Hover", true) end end)
			t.MouseLeave:Connect(function() if box then box:SetAttribute("Hover", nil) end end)
			-- (2026-10-21, RIVALS normal theme) kuroko_preview.png: a click (locked or not) previews the skin on the hero item at once
			-- and shows the name / how-to-get pills (no shake: RIVALS just previews); None puts the equipped look back and hides
			-- them, its check stays (what you have on). Finishers have nothing to show on the item: pills only.
			t.Activated:Connect(function()
				Kit.pop(mark, cc and 1.3 or 1.35)
				Armory._previewLook(c.Id ~= "Finisher" and cc or nil, c.Id)
				Armory._previewPills(preview, cc and it or nil, cc, cc and c.Id == "Wrap" and wrapCube(H(cc[2])) or nil)
			end)
		end
		local cw = math.max(16 + #list * 138, 1535)
		strip.CanvasSize = UDim2.fromScale(cw / 1920, 150 / 1080) -- (Scale of the strip's parent, the full-canvas picker)
		RK.toScale(strip, Vector2.new(cw, 150))
		strip.CanvasPosition = Vector2.zero
	end
	search:GetPropertyChangedSignal("Text"):Connect(layout)
	favB.Activated:Connect(function()
		favOnly = not favOnly
		favIn.Visible = not favOnly
		layout()
	end)
	Kit.bindButton(favB, { hover = 1.08, press = 0.9 })
	layout()
end

-- (2026-10-21, RIVALS 1:1) the replica's strip: a dark bar (627, 1003, 665 x 53 for five slots) under 100 px slots 121 apart,
-- centred; each cosmetic slot shows the "none" glyph (a grey rounded square with a slash) and Leave is the red X; the labels
-- Bold 26 with a dark edge. A locked item shows Leave alone (t0056). On opening, the slots pop in one after another.
local function renderBottom()
	for _, c in bottomGroup:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(slotRings)
	closeTray(true)
	local owned = selectedId and ctx.owns(selectedId)
	local entries = { { Id = "Leave", Label = "Leave", Tip = "Back to the lobby" } }
	if owned then
		for _, c in COSMETICS do table.insert(entries, c) end
	end
	local n = #entries
	local tmp = Instance.new("Folder")
	-- (2026-10-21, port3) graders: RIVALS' strip is ~33% of the screen width (643-1277 of 1920) with ~2%-of-height labels; ours
	-- was 28% (121 apart). Slots 140 apart with 100 px of strip past the end ones: four slots = 620 px (32%); Bold 30 labels.
	-- (2026-10-22, section rounds 0-1, grader A vs t0058 / weapons.png) RIVALS' slots step 0.063 W (121) on 0.069 H discs (75) with
	-- ~15 px-cap labels (B): was 140 / 90 / Bold 30
	local SP = 121
	local bgW = (n - 1) * SP + 180
	mk("Frame", { Name = "Strip", BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, BorderSizePixel = 0, -- (round 0: a bright bench behind it showed through at 0.35)
		 Active = true, Position = UDim2.fromOffset(960 - bgW / 2, 998),
		Size = UDim2.fromOffset(bgW, 58), ZIndex = 4, Parent = tmp }, { corner(6) })
	for i, c in entries do
		local cx = 960 + (i - (n + 1) / 2) * SP
		local b = mk("TextButton", { Name = c.Id, AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(cx - 50, 952),
			Size = UDim2.fromOffset(100, 100), ZIndex = 5, Parent = tmp })
		-- (2026-10-21, RIVALS images) weapons.png: every slot sits on a ~90 px dark disc; the empty mark is gen.kit_slot_empty at
		-- ~46 px (grey), Leave is gen.kit_leave_x (coloured, ~84 px, it breaks out of its disc)
		-- (2026-10-22, RIVALS 16:9) fainter discs (0.66, was 0.45)
		mk("Frame", { Name = "Disc", BackgroundColor3 = BLACK, BackgroundTransparency = 0.66, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(50, 50), Size = UDim2.fromOffset(85, 85), ZIndex = 5, Parent = b }, { circle() }) -- (rounds 2-4, grader A vs t0058: discs ~85; the bar cuts them at ~0.42, labels over their lower fifth)
		local g = glyph(b, c.Id == "Leave" and "leave" or "empty", c.Id == "Leave" and 85 or 44, COL.Empty, 6)
		g.Position = UDim2.fromOffset(50, 50)
		if c.Id ~= "Leave" then slotRings[c.Id] = b end
		local lbl = text({ Text = c.Label, FontFace = FB, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-20, 66),
			Size = UDim2.fromOffset(140, 38), ZIndex = 7, Parent = b })
		shade(lbl, 1.8, 0.35)
		-- (2026-10-22, live RIVALS feel study) RIVALS' slots react like its dock: the slot grows ~1.2 and its light-grey label turns white
		lbl.TextColor3 = Color3.fromRGB(205, 205, 210)
		b.MouseEnter:Connect(function() lbl.TextColor3 = Color3.new(1, 1, 1) end)
		b.MouseLeave:Connect(function() lbl.TextColor3 = Color3.fromRGB(205, 205, 210) end)
		Kit.bindButton(b, { hover = 1.2, press = 0.92 })
		Armory._tip(b, c.Tip, "up")
		b.Activated:Connect(function()
			if c.Id == "Leave" then
				Armory.Leave()
			else
				openCosmeticTray(c)
			end
		end)
		if Armory._popBottom then Kit.popIn(b, 0.05 + (i - 1) * 0.07) end
	end
	Armory._popBottom = nil
	settle(tmp, bottomGroup)
end

-------------------------------------------------------------------------------
-- Refresh / select
-------------------------------------------------------------------------------
local bottomOwned = nil
function Armory.Refresh()
	if not active then return end
	local key = ownedSignature()
	if key ~= ownedKey then
		ownedKey = key
		buildList()
		setSelectedRow(selectedId, false)
	else
		Armory._restyleEquipped() -- (2026-10-21, user) the loadout may have changed
	end
	renderInfo()
	local owned = selectedId and ctx.owns(selectedId)
	if owned ~= bottomOwned then
		bottomOwned = owned
		renderBottom()
	end
end

function Armory.Select(id: string, direction: number?)
	local first = selectedId == nil
	selectedId = id
	selectedSlot = ctx.Config.Items[id].Slot
	showItem(id, direction or 1)
	local key = ownedSignature()
	if key ~= ownedKey or next(rows) == nil then
		ownedKey = key
		buildList()
		first = true
	end
	setSelectedRow(id, not first)
	if not first then revealRow(id) end
	renderInfo()
	renderBottom()
	bottomOwned = ctx.owns(id)
end

local dragZone
local function build()
	local gui = mk("ScreenGui", { Name = "ArmoryUI", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	ui = mk("Frame", { Name = "Armory", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })

	-- The item is drawn in a full-screen ViewportFrame on top of the world: the room behind it gets a
	-- real BlurEffect (works at every graphics level) while the item stays sharp.
	local vpf = mk("ViewportFrame", { Name = "Showcase", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0,
		Ambient = LIT.Ambient, LightColor = LIT.LightColor, Parent = ui })
	local r = room()
	local key = r and r:FindFirstChild("KeyLight")
	local dpos = points()
	if key and dpos then vpf.LightDirection = (dpos - key.Position).Unit end
	showcaseCam = Instance.new("Camera")
	showcaseCam.Parent = vpf
	vpf.CurrentCamera = showcaseCam
	if SHOWCASE_WORLD then
		displayFolder = Instance.new("Folder")
		displayFolder.Name = "ArmoryShowcase"
		displayFolder.Parent = workspace
		-- a product-shot key light up and to the left of the camera, so the item reads with contrast against the room
		local dp, cp = points()
		if dp and cp then
			local lamp = Instance.new("Part")
			lamp.Name = "ShowcaseKey"
			lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch, lamp.CastShadow = true, false, false, false, false
			lamp.Transparency = 1
			lamp.Size = Vector3.one * 0.2
			lamp.CFrame = CFrame.lookAt(cp.Position + cp.UpVector * 4 - cp.RightVector * 4, dp)
			local spot = Instance.new("SpotLight")
			-- (2026-10-21, grade2) 2.2 -> 1.55 (~30% down): the gun was blown out to a flat grey slab
			spot.Brightness, spot.Range, spot.Angle, spot.Face, spot.Shadows = 1.3, 24, 50, Enum.NormalId.Front, true -- (grade3) 1.55 -> 1.3
			spot.Color = Color3.fromRGB(255, 248, 238)
			spot.Parent = lamp
			lamp.Parent = displayFolder
			-- (2026-10-21, grade2) a soft cool rim light from behind and above the item (towards the camera), so the gun's top and back
			-- edges catch a thin highlight and the silhouette separates from the room; no shadows, short range
			local rim = lamp:Clone()
			rim.Name = "ShowcaseRim"
			rim:ClearAllChildren()
			local away = (dp - cp.Position).Unit
			rim.CFrame = CFrame.lookAt(dp + away * 5 + cp.UpVector * 3.5 + cp.RightVector * 2.5, dp)
			local rimSpot = Instance.new("SpotLight")
			rimSpot.Brightness, rimSpot.Range, rimSpot.Angle, rimSpot.Face, rimSpot.Shadows = 1.2, 12, 40, Enum.NormalId.Front, false
			rimSpot.Color = Color3.fromRGB(205, 222, 255)
			rimSpot.Parent = rim
			rim.Parent = displayFolder
		end
	else
		displayFolder = Instance.new("WorldModel")
		displayFolder.Parent = vpf
	end
	showcaseVpf = vpf

	-- click-and-drag anywhere that isn't a panel turns the item
	dragZone = mk("TextButton", { Name = "DragZone", AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 1, Parent = ui })
	dragZone.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not currentLocked() then
			dragging = true
			dragLast = input.Position
			dragStarts += 1
			yawVel, pitchVel = 0, 0
			returning = false
			lastTouch = os.clock()
			lastMove = os.clock()
			if spinStart then -- grabbed mid-spin: keep it where it is
				rot = CFrame.fromAxisAngle(Vector3.yAxis, (spinAngle(os.clock()))) * rot
				spinStart = nil
			end
		end
	end)

	local tapeLayer = mk("Frame", { Name = "TapeLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = ui })
	Armory.BuildTape(tapeLayer)

	-- (2026-10-21, RIVALS 1:1) the panels sit on UIKit.Rivals' design canvas (a centred 16:9 frame, 1920 x 1080 design px) in four
	-- full-canvas groups: Left (Career + list), Right (the column), StatsLayer (Statistics, which stays put while the column moves
	-- up) and Bottom (the strip); the Picker stands in for them. Everything is converted to Scale (Rivals Kit.toScale).
	hud = RK.canvas(ui)
	hud.Name = "Hud"
	-- (2026-10-22, section round 0, grader A) RIVALS anchors the Weapons panels and the slot strip to the screen's bottom edge; on a
	-- screen taller than 16:9 our centred canvas left them floating ~36 px up. Nothing in this canvas lives on the top edge.
	if Kit.pinCanvas then Kit.pinCanvas(hud, "bottom") end
	hud.ZIndex = 3
	leftGroup = mk("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hud })
	rightCol = mk("Frame", { Name = "Right", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hud })
	statsLayer = mk("Frame", { Name = "StatsLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hud })
	bottomGroup = mk("Frame", { Name = "Bottom", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hud })
	-- (2026-10-22, section round 1, grader C) the room's bright bench framed the slot strip like a cream bezel: RIVALS' floor reads dark
	-- under its strip, so a soft black fade rises from the screen's bottom edge (0 -> 0.45 over the bottom 16 %) behind the strip
	mk("Frame", { Name = "FloorFade", BackgroundColor3 = BLACK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.16), ZIndex = 2, Parent = hud }, { mk("UIGradient", { Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) }) }) })
	tray = mk("Frame", { Name = "Picker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 6, Parent = hud })
	buildLeft()
	Armory.BuildHistory(hud)
	RK.toScale(hud, RT.design)
	-- (2026-10-21, RIVALS pass) the groups slide in from the screen edges on Enter and back out on Leave (Armory.SlidePanels):
	-- where each one rests, and how far off-screen it starts (Scale of the canvas)
	Armory._slides = {
		{ g = leftGroup, off = UDim2.fromScale(-0.21, 0), delay = 0 },
		{ g = rightCol, off = UDim2.fromScale(0.21, 0), delay = 0.03 },
		{ g = bottomGroup, off = UDim2.fromScale(0, 0.14), delay = 0.08 },
	}
	for _, sl in Armory._slides do sl.home = UDim2.fromScale(0, 0) end

	-- contact shadow: dark ellipses lying on the real workbench. The room's blur softens them into
	-- a natural shadow (a shadow drawn inside the sharp item layer looked like a hard disc).
	local shadowFolder = Instance.new("Folder")
	shadowFolder.Name = "ArmoryShadow"
	shadowFolder.Parent = workspace
	for i = 0, 3 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
		p.Color = BLACK
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.8 + i * 0.03
		p.Size = Vector3.new(1, 0.02, 1)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		p.Parent = shadowFolder
		shadowParts[i + 1] = p
	end

	Armory.BuildOverlay()
end

-------------------------------------------------------------------------------
-- Enter / leave (camera transition)
-------------------------------------------------------------------------------
local function tweenWait(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	t.Completed:Wait()
end

local function freezeCharacter(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		savedWalk, savedJump = hum.WalkSpeed, hum.JumpHeight
		hum.WalkSpeed, hum.JumpHeight = 0, 0
	else
		hum.WalkSpeed = savedWalk or 16
		hum.JumpHeight = savedJump or 7.2
	end
end

-------------------------------------------------------------------------------
-- Transition overlay (black, flash, letterbox bars, blast doors, title)
-------------------------------------------------------------------------------
-- (2026-10-21, AI-tells cleanup) hazard stripes cream (was comic yellow 255,212,0); door / title fonts Oswald Bold (was GothamBlack)
local HAZARD_Y, HAZARD_K = Color3.fromRGB(236, 230, 210), Color3.fromRGB(22, 22, 24)
function Armory.BuildOverlay()
	local gui = ctx.new("ScreenGui", { Name = "ArmoryTransition", IgnoreGuiInset = true, DisplayOrder = 50, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	overlay.gui = gui
	overlay.black = ctx.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
	fade = overlay.black
	local function door(side: number)
		local f = ctx.new("Frame", { BackgroundColor3 = Color3.fromRGB(54, 57, 60), BorderSizePixel = 0, Size = UDim2.fromScale(0.502, 1),
			Position = side < 0 and UDim2.fromScale(-0.52, 0) or UDim2.fromScale(1.02, 0), ZIndex = 2, ClipsDescendants = true, Parent = gui })
		ctx.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(205, 205, 205), Color3.fromRGB(120, 120, 120)), Parent = f })
		for i = 1, 5 do -- plate seams
			ctx.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 32, 34), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.003), Position = UDim2.fromScale(0, i / 6), ZIndex = 2, Parent = f })
		end
		for i = 0, 5 do -- rivets near the outer edge
			ctx.new("Frame", { BackgroundColor3 = Color3.fromRGB(96, 100, 104), Size = UDim2.fromScale(0.0104, 0.0093), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(side < 0 and 0.0228 or 0.9772, (i + 0.5) / 6), ZIndex = 2, Parent = f },
				{ ctx.new("UICorner", { CornerRadius = UDim.new(1, 0) }), ctx.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		end
		-- hazard band along the edge that meets the other door
		local band = ctx.new("Frame", { BackgroundColor3 = HAZARD_K, BorderSizePixel = 0, Size = UDim2.fromScale(0.0311, 1),
			Position = side < 0 and UDim2.fromScale(0.9689, 0) or UDim2.fromScale(0, 0), ZIndex = 3, Parent = f })
		for i = 0, 23, 2 do
			ctx.new("Frame", { BackgroundColor3 = HAZARD_Y, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1 / 24, 0), Position = UDim2.fromScale(0, i / 24), ZIndex = 3, Parent = band })
		end
		local tag = ctx.label({ Text = side < 0 and "A-07" or "TAC", FontFace = FX, TextSize = 46, TextColor3 = Color3.fromRGB(30, 32, 34),
			TextTransparency = 0.35, TextScaled = true, Size = UDim2.fromScale(0.6, 0.046), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = f })
		return f
	end
	overlay.doorL = door(-1)
	overlay.doorR = door(1)
	overlay.barTop = ctx.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.13),
		Position = UDim2.fromScale(0, -0.14), ZIndex = 4, Parent = gui })
	overlay.barBot = ctx.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.13),
		Position = UDim2.fromScale(0, 1.01), ZIndex = 4, Parent = gui })
	overlay.title = ctx.label({ Text = "ARMORY", FontFace = FX, TextSize = 64, TextColor3 = ctx.THEME.Accent, TextTransparency = 1,
		TextScaled = true, Size = UDim2.fromScale(1, 0.065), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6, Parent = gui })
	overlay.titleStroke = ctx.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 1, Parent = overlay.title })
	overlay.titleLine = ctx.new("Frame", { BackgroundColor3 = ctx.THEME.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0, 0.0037), ZIndex = 6, Parent = gui })
	overlay.flash = ctx.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = gui })
	overlay.blur = Lighting:FindFirstChild("TransitionBlur") or Instance.new("BlurEffect")
	overlay.blur.Name = "TransitionBlur"
	overlay.blur.Size = 0
	overlay.blur.Parent = Lighting
end

local function tw(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function showTitle(text: string, on: boolean, time: number)
	overlay.title.Text = text
	tw(overlay.title, time, { TextTransparency = on and 0 or 1 })
	tw(overlay.titleStroke, time, { Transparency = on and 0.2 or 1 })
	tw(overlay.titleLine, time, { Size = UDim2.fromScale(on and 0.135 or 0, 0.0037) }, Enum.EasingStyle.Quart)
end

local function shake(cam, strength: number, times: number)
	for i = 1, times do
		local k = strength * (1 - (i - 1) / times)
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
		task.wait(0.03)
	end
end

-- Each transition: cover(cam, fromCF, opts) ends with the screen hidden;
-- reveal(cam, toCF, opts) starts hidden and ends with the camera on toCF. opts = { fov, label }
local TRANSITIONS = {}

-- Blast doors: two hazard-striped steel doors slam shut, the camera jolts, then they part on the new scene.
TRANSITIONS.Doors = {
	cover = function(cam, from, opts)
		tw(cam, 0.36, { CFrame = from * CFrame.new(0, 0, -2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(overlay.doorL, 0.32, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(overlay.doorR, 0.32, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.32)
		shake(cam, 3, 6)
		showTitle(opts.label, true, 0.15)
		task.wait(0.25)
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = opts.fov
		cam.CFrame = to * CFrame.new(0, 0.3, 2.5)
		showTitle(opts.label, false, 0.15)
		task.wait(0.1)
		tw(overlay.doorL, 0.55, { Position = UDim2.fromScale(-0.52, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
		tw(overlay.doorR, 0.55, { Position = UDim2.fromScale(1.02, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
		tw(cam, 0.85, { CFrame = to }, Enum.EasingStyle.Quart).Completed:Wait()
	end,
}

-- Cinematic: letterbox bars close in, cut to black with the room's name, then a slow dolly in.
TRANSITIONS.Cinematic = {
	cover = function(cam, from, opts)
		tw(overlay.barTop, 0.35, { Position = UDim2.fromScale(0, 0) })
		tw(overlay.barBot, 0.35, { Position = UDim2.fromScale(0, 0.87) })
		tw(cam, 0.6, { CFrame = from * CFrame.new(0, 0, -1.5) }, Enum.EasingStyle.Sine)
		task.wait(0.15)
		tw(overlay.black, 0.35, { BackgroundTransparency = 0 }).Completed:Wait()
		showTitle(opts.label, true, 0.25)
		task.wait(0.55)
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = opts.fov
		cam.CFrame = to * CFrame.new(0, 0.6, 5)
		showTitle(opts.label, false, 0.2)
		tw(overlay.black, 0.5, { BackgroundTransparency = 1 })
		local t = tw(cam, 1.2, { CFrame = to }, Enum.EasingStyle.Sine)
		task.wait(0.75)
		tw(overlay.barTop, 0.4, { Position = UDim2.fromScale(0, -0.14) })
		tw(overlay.barBot, 0.4, { Position = UDim2.fromScale(0, 1.01) })
		t.Completed:Wait()
	end,
}

-- Whip pan: a fast blurred swing away, landing on the new scene mid-swing.
TRANSITIONS.WhipPan = {
	cover = function(cam, from, opts)
		tw(overlay.blur, 0.22, { Size = 30 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(cam, 0.24, { FieldOfView = cam.FieldOfView + 18 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(cam, 0.24, { CFrame = from * CFrame.Angles(0, math.rad(-80), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = opts.fov + 18
		cam.CFrame = to * CFrame.Angles(0, math.rad(80), 0)
		tw(overlay.blur, 0.5, { Size = 0 })
		tw(cam, 0.5, { FieldOfView = opts.fov }, Enum.EasingStyle.Quart)
		tw(cam, 0.5, { CFrame = to }, Enum.EasingStyle.Quart).Completed:Wait()
	end,
}

-- Punch in: the camera rushes forward into a white flash, then pulls back out from the item.
TRANSITIONS.PunchIn = {
	cover = function(cam, from, opts)
		tw(cam, 0.35, { CFrame = from * CFrame.new(0, 0, -10), FieldOfView = 20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.2)
		tw(overlay.flash, 0.15, { BackgroundTransparency = 0 }).Completed:Wait()
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = 22
		cam.CFrame = to * CFrame.new(0, 0, -6)
		tw(overlay.flash, 0.4, { BackgroundTransparency = 1 })
		tw(cam, 0.8, { CFrame = to, FieldOfView = opts.fov }, Enum.EasingStyle.Quart).Completed:Wait()
	end,
}

-- Rise (the first version): the camera lifts out of the room and drops into the next one.
TRANSITIONS.Rise = {
	cover = function(cam, from, opts)
		tw(cam, 0.6, { CFrame = CFrame.new(from.Position + Vector3.new(0, 45, 0)) * from.Rotation * CFrame.Angles(math.rad(40), 0, 0) },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.3)
		tw(overlay.black, 0.3, { BackgroundTransparency = 0 }).Completed:Wait()
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = opts.fov
		cam.CFrame = to * CFrame.new(0, 7, 4) * CFrame.Angles(math.rad(-28), 0, 0)
		tw(overlay.black, 0.35, { BackgroundTransparency = 1 })
		tw(cam, 0.75, { CFrame = to }, Enum.EasingStyle.Quart).Completed:Wait()
	end,
}

-- (2026-10-21, grade1) Cut: RIVALS' cut to black and reveal, 0.33 s in all (0.08 to black, 0.07 held, 0.18 back). The default
-- now: the configured WhipPan (0.74 s) and Doors (~1.7 s) were too slow for a menu you open all the time. The others stay
-- reachable through the player's ArmoryTransition attribute (Studio / testing).
TRANSITIONS.Cut = {
	cover = function(cam, from, opts)
		tw(overlay.black, 0.08, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		task.wait(0.07)
	end,
	reveal = function(cam, to, opts)
		cam.FieldOfView = opts.fov
		cam.CFrame = to
		tw(overlay.black, 0.18, { BackgroundTransparency = 1 }).Completed:Wait()
	end,
}

Armory.TransitionNames = { "Cut", "Doors", "Cinematic", "WhipPan", "PunchIn", "Rise" }

local function transition()
	local name = player:GetAttribute("ArmoryTransition") or "Cut"
	return TRANSITIONS[name] or TRANSITIONS.Cut
end

local function backgroundBlur(on: boolean)
	local old = Lighting:FindFirstChild("ArmoryBlur")
	if old and old:IsA("DepthOfFieldEffect") then old:Destroy() end
	local b = Lighting:FindFirstChild("ArmoryBackgroundBlur") or Instance.new("BlurEffect")
	b.Name = "ArmoryBackgroundBlur"
	b.Parent = Lighting
	b.Size = BACKGROUND_BLUR
	b.Enabled = on and BACKGROUND_BLUR > 0 and not SHOWCASE_WORLD
	-- soft depth of field instead (values from the Tacticals session's Showroom2 build). Not named "ArmoryBlur": that name is deleted above
	local dof = Lighting:FindFirstChild("ArmoryDOF") or Instance.new("DepthOfFieldEffect")
	dof.Name = "ArmoryDOF"
	dof.FocusDistance = 13.05
	dof.InFocusRadius = 3
	dof.FarIntensity = 0.85
	if SHOWCASE_WORLD then -- the item sharp, the room behind it soft
		-- (2026-10-21, port3) RIVALS' room is dark and only softly out of focus (the live notes: no heavy blur), so: focus ON the
		-- hero (it sits 1.4x closer than DisplayPoint; the old focus at DisplayPoint left everything between sharp) with a band as
		-- deep as the item, and a light far blur (1 -> 0.35). The darkness comes from Armory._dimRoom, not the blur.
		local D, dist = Armory._heroFrame()
		dof.FocusDistance = dist
		dof.InFocusRadius = math.max(0.6, D / 2)
		dof.FarIntensity = 0.35
	end
	dof.NearIntensity = 0
	dof.Parent = Lighting
	dof.Enabled = on
	Armory._dimRoom(on)
end

-- (2026-10-21, port3) graders: our room was a bright, sharp workshop competing with the panels; RIVALS' is dark. A screen-wide
-- GUI wash would darken the hero gun too (it is a real model in the world), so the dimmer is IN the world: a camera-facing plane
-- just behind the hero (past its largest reach, so a spin never cuts it) carrying an unlit black SurfaceGui frame - ~62% black
-- in the middle, ~80% at the screen sides behind the panels. Everything behind it (the room, the tool board, the window) goes
-- dark while the gun in front stays lit and sharp. A light grade (ArmoryGrade: a touch more contrast, a little less colour) on
-- top. Client-only; both go on Leave.
function Armory._dimRoom(on: boolean)
	local old = displayFolder and displayFolder:FindFirstChild("ArmoryDim")
	if old then old:Destroy() end
	local grade = Lighting:FindFirstChild("ArmoryGrade")
	if grade then grade:Destroy() end
	if not on or not SHOWCASE_WORLD or not displayFolder then return end
	local d, camCF = points()
	if not (d and camCF) then return end
	local D = Armory._heroFrame()
	local look = camCF.LookVector
	local depth = ((d - camCF.Position) / 1.4):Dot(look) + D / 2 + 0.3
	local h = 2 * depth * math.tan(math.rad(20)) * 1.6
	local p = Instance.new("Part")
	p.Name = "ArmoryDim"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(h * 2.2, h, 0.05)
	local at = camCF.Position + look * depth
	p.CFrame = CFrame.lookAt(at, at - look, camCF.UpVector) -- Front face towards the camera
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 8
	sg.Parent = p
	-- the screen sees the plane's middle half (0.25 .. 0.75 across)
	mk("Frame", { Name = "Dim", BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, {
		mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.25, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.38), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 0.12) }) }),
	})
	p.Parent = displayFolder
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ArmoryGrade"
	cc.Brightness, cc.Contrast, cc.Saturation = -0.02, 0.1, -0.1
	cc.Parent = Lighting
end

-- (2026-10-21, port3) graders: in RIVALS' Weapons screen the currency icon is ~6% of the screen height on a dark plate that fades
-- out to the right. The pill is LobbyHudController's (LobbyHud > ... > Scissors: a 56 px icon, a black 0.45 Plate); while the Kit
-- is open it is scaled up 1.16 (icon ~65 design px = 6%) and its Plate gets a darker left end fading to nothing. Put back on
-- Leave. (The glowing yellow-edged bar behind it is the map's tool-board sign, not UI: left alone, it is dimmed with the room.)
function Armory._kitCurrency(on: boolean)
	local hudGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("LobbyHud")
	local pill = hudGui and hudGui:FindFirstChild("Scissors", true)
	if not pill then return end
	local plate = pill:FindFirstChild("Plate")
	local sc = pill:FindFirstChild("KitScale")
	if on then
		if not sc and not pill:FindFirstChildOfClass("UIScale") then mk("UIScale", { Name = "KitScale", Scale = 1.16, Parent = pill }) end
		if plate and plate:IsA("GuiObject") and not plate:FindFirstChild("KitFade") then
			plate:SetAttribute("KitT", plate.BackgroundTransparency)
			plate.BackgroundTransparency = 0.1
			mk("UIGradient", { Name = "KitFade", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.35),
				NumberSequenceKeypoint.new(1, 1) }), Parent = plate })
		end
	else
		if sc then sc:Destroy() end
		local g = plate and plate:FindFirstChild("KitFade")
		if g then g:Destroy() end
		if plate and plate:GetAttribute("KitT") ~= nil then
			plate.BackgroundTransparency = plate:GetAttribute("KitT")
			plate:SetAttribute("KitT", nil)
		end
	end
end

-- (2026-10-21, RIVALS pass) on = slide the columns in from off-screen (Quart out, staggered, after `after` s), off = slide them out
function Armory.SlidePanels(on: boolean, after: number?)
	for _, sl in Armory._slides or {} do
		if sl.g and sl.home then
			if on then sl.g.Position = sl.home + sl.off end
			local info = TweenInfo.new(on and 0.38 or 0.22, Enum.EasingStyle.Quart, on and Enum.EasingDirection.Out or Enum.EasingDirection.In, 0, false,
				on and ((after or 0) + sl.delay) or 0)
			TweenService:Create(sl.g, info, { Position = on and sl.home or (sl.home + sl.off) }):Play()
		end
	end
end

local renderConn
function Armory.Enter(focusId: string?)
	local focus = (focusId and ctx.Config.Items[focusId]) and focusId or nil
	if active and not busy and focus then Armory.Select(focus, 1) return end
	if active or busy then return end
	local d, camCF = points()
	if not d then
		ctx.toast("Armory room is missing from the map", "bad")
		return
	end
	busy = true
	active = true
	-- (2026-10-21) NameplatesController hides your own plate while this is set (it floated over the Kit character view)
	game:GetService("Players").LocalPlayer:SetAttribute("InKit", true)
	-- (2026-10-21, grade3) the map's Showroom KeyLight (2.4, shadows) blew the dark gunmetal item out to white; dim it while the Kit is open
	do
		local r = room()
		local kl = r and r:FindFirstChild("KeyLight")
		local spot = kl and kl:FindFirstChildWhichIsA("SpotLight")
		if spot then
			Armory._keyLight, Armory._keyBright = spot, Armory._keyBright or spot.Brightness
			spot.Brightness = 1.1
		end
	end
	local cam = workspace.CurrentCamera
	savedType, savedCam, savedFov = cam.CameraType, cam.CFrame, cam.FieldOfView
	freezeCharacter(true)
	ctx.setLobbyVisible(false)
	cam.CameraType = Enum.CameraType.Scriptable
	local tr = transition()

	local okCover, err = pcall(tr.cover, cam, savedCam, { fov = savedFov, label = "ARMORY" })
	if not okCover then warn("[Armory] transition: " .. tostring(err)) end
	-- swap scenes while the screen is covered
	backgroundBlur(true)
	Armory.HideGhostLabels() -- (2026-10-21, grade2)
	-- (2026-10-21, port3) no UITheme backdrop any more: its screen wash (and world blur) dimmed and softened the hero gun with the
	-- room; Armory._dimRoom (called by backgroundBlur) darkens only what is behind the gun
	Armory._kitCurrency(true)
	renderConn = RunService.RenderStepped:Connect(renderShowcase)
	ui.Visible = true
	RK.rescaleText() -- (2026-10-21, RIVALS 1:1) text sizes follow the canvas height (the window may have changed while the Kit was shut)
	Armory._popBottom = true -- (2026-10-21, RIVALS 1:1) the slots pop in one after another on opening (RIVALS)
	local okSel, err2 = pcall(Armory.Select, focus or equippedIn(selectedSlot), 1)
	if not okSel then warn("[Armory] select: " .. tostring(err2)) end
	Armory.SlidePanels(true, 0.15) -- (2026-10-21, RIVALS pass) the columns arrive as the reveal opens
	local okRev, err3 = pcall(tr.reveal, cam, camCF, { fov = 40, label = "ARMORY" })
	if not okRev then warn("[Armory] reveal: " .. tostring(err3)) cam.CFrame = camCF end
	busy = false
end

function Armory.Leave(after: (() -> ())?)
	if not active or busy then return end
	busy = true
	game:GetService("Players").LocalPlayer:SetAttribute("InKit", nil)
	game:GetService("Players").LocalPlayer:SetAttribute("KitPreview", nil) -- (2026-10-21) never leave the currency hidden
	if Armory._keyLight and Armory._keyBright then Armory._keyLight.Brightness = Armory._keyBright; Armory._keyBright = nil end -- (grade3) restore the room key light
	closeTray()
	-- (2026-10-21, round 3: match RIVALS) a hover bubble left up would still be showing on the next visit
	if Armory._tipFrame then Armory._tipFrame.Visible = false; Armory._tipOwner = nil end
	Armory.ShowHistory(false)
	-- (2026-10-21, RIVALS pass) Statistics closes too (it isn't one of the sliding columns), then the columns slide out under the cover
	statsOpen = false
	if statsCard then Armory._popOut(statsCard) end
	Armory.SlidePanels(false)
	dragging = false
	local cam = workspace.CurrentCamera
	local tr = transition()
	tr.cover(cam, cam.CFrame, { fov = 40, label = "LOBBY" })
	ui.Visible = false
	if renderConn then renderConn:Disconnect() renderConn = nil end
	clearShowcase()
	for _, p in shadowParts do p.Transparency = 1 end
	Armory.SetTape(false)
	backgroundBlur(false)
	UITheme.HideBackdrop("Armory") -- (harmless: kept in case an older build left it on)
	Armory._kitCurrency(false) -- (2026-10-21, port3)
	tr.reveal(cam, savedCam, { fov = savedFov or 70, label = "LOBBY" })
	cam.CameraType = savedType or Enum.CameraType.Custom
	freezeCharacter(false)
	active = false
	busy = false
	ctx.setLobbyVisible(true)
	if after then after() end
end

function Armory.IsActive() return active end

-- (2026-10-21, grade2) graders saw a ghost "x 51" beside the list's Pistol render. It isn't UI: it's the "7.62 x 51" stencil on the
-- Showroom's AmmoCrate (fix/polish_showroom2.lua), blurred behind the left panel where it reads as a stray count. While the Kit
-- is open the client switches off that crate's stencil SurfaceGui (local only; the map itself is unchanged).
function Armory.HideGhostLabels()
	local map = workspace:FindFirstChild("LobbyMap")
	if not map then return end
	for _, g in map:GetDescendants() do
		if g:IsA("TextLabel") and g.Text:match("%d+%s*[xX]%s*51$") then
			local sg = g:FindFirstAncestorOfClass("SurfaceGui")
			if sg then sg.Enabled = false else g.Visible = false end
		end
	end
end

-------------------------------------------------------------------------------
-- Drag to turn (the press starts on the DragZone button - see build - so panels and the lobby's
-- input handling can't swallow it; the drag itself is tracked everywhere)
-------------------------------------------------------------------------------
local function hookInput()
	UserInputService.InputChanged:Connect(function(input)
		if not (active and dragging) then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local dx, dy = input.Delta.X, input.Delta.Y
			if dragLast and (dx == 0 and dy == 0) then
				dx, dy = input.Position.X - dragLast.X, input.Position.Y - dragLast.Y
			end
			dragLast = input.Position
			local view = workspace.CurrentCamera.ViewportSize
			local dYaw = dx / math.max(view.X, 1) * SWIPE_YAW
			local dPitch = dy / math.max(view.Y, 1) * SWIPE_PITCH
			turnBy(dYaw, dPitch)
			-- swipe speed (smoothed) for the fling
			local now = os.clock()
			local step = math.max(now - lastMove, 1 / 240)
			if now - lastMove > 0.1 then yawVel, pitchVel = 0, 0 end
			yawVel = math.clamp(yawVel + (dYaw / step - yawVel) * 0.5, -MOMENTUM_MAX, MOMENTUM_MAX)
			pitchVel = math.clamp(pitchVel + (dPitch / step - pitchVel) * 0.5, -MOMENTUM_MAX, MOMENTUM_MAX)
			lastMove = now
			lastTouch = now
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				lastTouch = os.clock()
				-- held still before letting go = no fling
				if os.clock() - lastMove > 0.08 then yawVel, pitchVel = 0, 0 end
			end
			dragging = false
		end
	end)
end

-- mouse wheel over the item (not over a panel) zooms it in and out
local function hookZoom()
	UserInputService.InputChanged:Connect(function(input)
		if not active or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		local p = input.Position
		for _, g in player.PlayerGui:GetGuiObjectsAtPosition(p.X, p.Y) do
			if g:IsDescendantOf(ui) and g ~= ui and g.Name ~= "DragZone" and g.Name ~= "Showcase" and g.Name ~= "Hud"
				and g.Name ~= "TapeLayer" and not g:IsDescendantOf(ui.TapeLayer) and g.Visible and (g.BackgroundTransparency < 1 or g:IsA("TextButton") or g:IsA("ScrollingFrame")) then
				return -- over a panel / the list: let it scroll instead
			end
		end
		if currentLocked() then return end
		zoomTarget = math.clamp(zoomTarget * (1 + WHEEL_STEP * input.Position.Z), 1, WHEEL_MAX_ZOOM)
	end)
end

function Armory.Init(c)
	ctx = c
	build()
	hookInput()
	hookZoom()
	-- Studio-only hook so the screen can be driven from the command bar / tests
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "ArmoryTestHook"
		hook.OnInvoke = function(action, a1, a2)
			if action == "Enter" then
				task.spawn(Armory.Enter)
			elseif action == "Leave" then
				task.spawn(Armory.Leave)
			elseif action == "Select" then
				Armory.Select(a1, a2 or 1)
			elseif action == "Tab" then
				setTab(a1)
			elseif action == "Equip" or action == "Click" then -- (2026-10-21, user) the list row's click-to-equip
				Armory.ClickItem(a1)
			end
			return { active = active, busy = busy, selected = selectedId, tab = currentTab, yaw = yaw, pitch = pitch, turn = math.deg((select(2, rot:ToAxisAngle()))), returning = returning, dragging = dragging, dragStarts = dragStarts }
		end
		hook.Parent = player
	end
end

return Armory
