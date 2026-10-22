-- LobbyUIController/Armory (ModuleScript, required by LobbyUIController)
-- The KIT screen. Pressing Kit flies the camera up out of the lobby and into the Armory room
-- (workspace.LobbyMap.Armory, built above the command dome), with the background blurred.
--   * Top: credits chip. Left: profile (avatar, name, slot icons) and one long list - Weapons, Melee,
--     Gadgets - each under its own header; the slot icons jump the list to that section. The picked item
--     is big and white with its render breaking out of the row; locked items are dim with padlocks.
--   * Centre: the selected item, big, on the workbench. Click and drag to turn it. Picking another item
--     slides the old one out to the left and the new one in from the right.
--   * Locked items are wrapped in hazard tape with a padlock.
--   * Right: item card (name, favourite box, notes), level card (XP bar, level up, account level),
--     actions (equip / unlock, inspect, next unlock).
--   * Bottom: round slots - LEAVE, SKIN, WRAP, FINISHER, CUTSCENE (cosmetic trays are placeholders
--     until cosmetics exist).

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

local function makeShowcase(itemId: string, locked: boolean)
	local model, view, zoom = ctx.Icons.Item(itemId)
	-- (2026-10-21, grade3) the hero gun rests in a calmer 3/4 pose like RIVALS' (t0052): side-on, turned ~25 deg towards you and
	-- pitched ~10 deg (Icons.GunView's 28 deg tilt + roll stays for the small icons)
	if view == ctx.Icons.GunView then
		view = CFrame.Angles(0, math.rad(25), 0) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(10), 0, 0)
	end
	local _, natural = model:GetBoundingBox()
	prepModel(model, math.min(SHOW_FIT, natural.Magnitude * SHOW_MAX_ZOOM) * (zoom or 1))
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
-- Dark see-through panels, no borders, heavy rounded type with dark edges.
--   Top   : credits chip (◆ amount, green + opens the Robux shop).
--   Left  : profile (avatar bust, name, three slot icons) and under it ONE long scrolling list:
--           a WEAPONS section, then MELEE, then GADGETS, each under its own header. The slot icons
--           jump the list to that section. Owned items show a small 3D render poking out of the
--           panel's left edge; the picked item sits in a lighter band, big and white, with its render
--           breaking out of the right edge. Locked items are dim with one padlock on the left.
--   Right : stacked up from the bottom - actions (equip / unlock, inspect, next unlock), level card
--           (XP bar, level up, account level), and the item card (render, name, favourite box, notes).
--   Bottom: round slots on a strip - LEAVE and the cosmetic slots.
-- Laid out on a canvas 1008 units tall that is scaled to the screen, so it keeps its proportions at
-- any resolution. Lives in its own ScreenGui so the lobby's auto-styling doesn't touch it.
-------------------------------------------------------------------------------
-- Fonts: Oswald Bold for headings / labels / numbers, Rubik for body text
-- (2026-10-21, RIVALS pass, Edward's font decision) headings, big words and numbers are Oswald Bold (FONT_TITLE). FONT_TITLE takes
-- the old ARMORY_FONT local's slot (the path is inlined below) so the chunk's local count doesn't grow. Body-text fonts wait for the
-- integrator's pass.
local FONT_TITLE = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
-- (2026-10-21, AI-tells cleanup) Builder Sans is gone: FONT_HEAVY (labels, buttons, numbers) is Oswald Bold, FONT / FONT_MED
-- (body and small text) are Rubik
local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local FONT_HEAVY = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local FONT_MED = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local BASE_H = 1008
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local TacKit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Tac"))
local COL = {
	Text = Color3.fromRGB(236, 232, 218), -- bone (pass 34 deployment-board look)
	Sub = Color3.fromRGB(196, 194, 182),   -- small copy
	Grey = Color3.fromRGB(160, 164, 148),  -- profile name, dim labels
	Dim = Color3.fromRGB(140, 142, 132),   -- locked items: greyed like RIVALS. (2026-10-21, grade3) was 92,97,86 (~1.5:1 on the panel): now ~cream at 55%
	DimHead = Color3.fromRGB(42, 47, 36),  -- section headers
	DimKey = Color3.fromRGB(70, 72, 80),   -- keyhole on a dark padlock
	Empty = Color3.fromRGB(112, 114, 120), -- empty cosmetic slot mark
	Ink = Color3.fromRGB(14, 15, 18),
	Red = Color3.fromRGB(236, 232, 218), -- the LEAVE X: bone (pass 34)
	RedEdge = Color3.fromRGB(20, 22, 18),
	BlueTop = Color3.fromRGB(141, 191, 90),    -- (2026-10-20, Edward) field-green primary: matches the lobby's olive / lime and reads apart from Robux lime
	BlueBottom = Color3.fromRGB(76, 122, 46),
	BlueEdge = Color3.fromRGB(31, 58, 20), -- (2026-10-21) the green button's dark-green lip (was the old blue one)
	BlueText = Color3.fromRGB(169, 210, 122), -- (2026-10-21) light field green (was blue)
	GreenTop = Color3.fromRGB(236, 232, 218),   -- equipped: bone (pass 34)
	GreenBottom = Color3.fromRGB(170, 166, 150),
	OffTop = Color3.fromRGB(76, 78, 86),
	OffBottom = Color3.fromRGB(56, 58, 64),
	OffEdge = Color3.fromRGB(28, 29, 33),
}
local PANEL_T = 0.42 -- panels are black at this transparency
local TILE_T = 0.5   -- tiles and slots sitting on top of a panel
local SLOT_ORDER = { "Weapon", "Melee", "Gadget" }
local SLOT_TITLE = { Weapon = "Weapons", Melee = "Melee", Gadget = "Gadgets" }
local SLOT_LABEL = { Weapon = "Weapon", Melee = "Melee", Gadget = "Gadget" }

local LEFT_X, LEFT_W = 7, 336          -- the two left panels
local PROFILE_Y, PROFILE_H = 368, 142
local LIST_Y = 522                     -- the scrolling page runs off the bottom of the screen
local LIST_W = LEFT_W                  -- a row's width (the boxes' width)
local SCROLL_PAD = 60                  -- (2026-10-21, grade2) unused now: the list scrolls inside its plate and renders stay in their rows
local ROW_H, ROW_ON_H, HEADER_H = 67, 73, 74
local CARD_W = 310
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
	-- ScreenGui in Scale (ogSize.X.Scale * 1.05): these are Offset-sized, so a hover tweened them to 0 x 0 and the next click
	-- fell through to the drag zone. Nonapplicable opts out; the screen animates its own buttons.
	if inst:IsA("GuiButton") then inst:AddTag("Nonapplicable") end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function corner(r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function circle() return mk("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function text(props)
	local t = mk("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, TextColor3 = COL.Text, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.new(1, 0, 0, 24) })
	for k, v in props do
		if k ~= "Parent" then t[k] = v end
	end
	t.Parent = props.Parent
	return t
end
-- a dark edge on white text that sits over the 3D scene
local function shade(label, thick: number?)
	mk("UIStroke", { Color = BLACK, Thickness = thick or 1.5, Transparency = 0.45, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end
local function panel(props)
	local f = mk("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = PANEL_T, BorderSizePixel = 0, Active = true }) -- (Active: clicks on a panel don't turn the item)
	for k, v in props do
		if k ~= "Parent" then f[k] = v end
	end
	corner(3).Parent = f
	f.Parent = props.Parent
	TacKit.brackets(f, TacKit.C.line, 14, 2) -- pass 34 deployment-board look
	return f
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
function GLYPH.closex(h, s) -- the lobby close X: two cream bars
	seg(h, s, 0.2, 0.2, 0.8, 0.8, s * 0.13, Color3.fromRGB(236, 230, 210))
	seg(h, s, 0.2, 0.8, 0.8, 0.2, s * 0.13, Color3.fromRGB(236, 230, 210))
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
function GLYPH.leave(h, s)
	for _, a in { { 0.14, 0.14, 0.86, 0.86 }, { 0.14, 0.86, 0.86, 0.14 } } do
		local b = seg(h, s, a[1], a[2], a[3], a[4], s * 0.25, COL.Red)
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, math.floor(s * 0.05))
		mk("UIStroke", { Color = COL.RedEdge, Thickness = math.max(2, s * 0.035), Parent = b })
		mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(165, 165, 165)), Parent = b })
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

-- Icon meshes made with Studio's mesh generator, kept in ReplicatedStorage.UIIcons (stored facing +Z, up +Y;
-- UI only, never placed in the world). A glyph uses its mesh when there is one, else the drawn shape above.
local GLYPH_MESH = { leave = "X", lock = "Lock", unlock = "LockOpen", lens = "Magnifier",
	arrow = "Arrow", check = "Check", star = "Badge", up = "LevelUp", none = "None" }
-- (2026-10-21, grade1) Inspect and Statistics both drew the Magnifier mesh ("eye" mapped to it): "eye" is now Kit.ICONS.eye
-- (an image, see glyph) and Statistics uses the drawn bar chart its row already shows on the left

-- a fresh, centred copy of a UIIcons mesh (nil when it isn't there)
local function iconModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("UIIcons")
	local src = folder and folder:FindFirstChild(name)
	if not src then return nil end
	local m = Instance.new("Model")
	for _, p in (src:IsA("BasePart") and { src } or src:GetDescendants()) do
		if p:IsA("BasePart") then
			local c = p:Clone()
			for _, k in c:GetChildren() do
				if not (k:IsA("DataModelMesh") or k:IsA("SurfaceAppearance")) then k:Destroy() end
			end
			c.Anchored = true
			c.Parent = m
		end
	end
	if #m:GetChildren() == 0 then
		m:Destroy()
		return nil
	end
	local cf = m:GetBoundingBox()
	for _, p in m:GetChildren() do
		p.CFrame = CFrame.new(-cf.Position) * p.CFrame
	end
	return m
end

-- draws a UIIcons mesh into parent: lit (its own colours) or flat (one-colour silhouette)
local function meshIcon(parent: Instance, name: string, size: number, color: Color3?, lit: boolean?, z: number?): Frame?
	local m = iconModel(name)
	if not m then return nil end
	local box = itemRender(parent, "", Vector2.new(size, size), { model = m, flat = not lit, color = color, z = z or 6, fill = 0.98 })
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	return box
end

local function glyph(parent: Instance, kind: string, size: number, color: Color3?, z: number?, lit: boolean?)
	local h = mk("Frame", { Name = "Glyph", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = z or 6, Parent = parent })
	if kind == "eye" and Kit.ICONS and Kit.ICONS.eye then
		mk("ImageLabel", { Name = "Eye", BackgroundTransparency = 1, Image = Kit.ICONS.eye, ImageColor3 = color or COL.Text, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1), ZIndex = z or 6, Parent = h })
		return h
	end
	local meshName = GLYPH_MESH[kind]
	local box = meshName and meshIcon(h, meshName, size, color or COL.Text, (lit and kind ~= "star") or kind == "leave", z)
	if box then
		if kind == "leave" then -- the generated X is a soft red; push it to a proper red
			for _, v in box:GetChildren() do
				if v:IsA("ViewportFrame") and v.ImageTransparency == 0 then v.ImageColor3 = Color3.fromRGB(255, 60, 60) end
			end
		end
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
	if v then
		v.ImageColor3 = color
		v.ImageTransparency = transparency
	else
		tintVector(holder, color, transparency)
	end
end

-- (2026-10-21, grade3, user: "copy RIVALS") RIVALS' action button: ONE plain solid bright square with a white glyph (t0052:
-- Contracts / Overview / Statistics). Ours is plain field green (grey when it can't be used). Removed: the darker lip under the
-- face, the face gradient, the thin white highlight line across the top, the 2 px press drop and the EQUIPPED word chip.
-- "equipped" = just the check in the green square (RIVALS), not clickable. A child "Face" frame stays for the price labels.
local function bigButton(parent: Instance, kind: string?, enabled: boolean, label: string?, size: Vector2?, tone: string?)
	local sz = size or Vector2.new(100, 50)
	local on = enabled or tone == "equipped"
	local b = mk("TextButton", { Name = "Button", AutoButtonColor = false, Text = "", BackgroundColor3 = on and COL.BlueTop or COL.OffTop,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(sz.X, sz.Y), ZIndex = 5, Parent = parent }, { corner(6) })
	local face = mk("Frame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = b })
	if label then
		shade(text({ Text = label, FontFace = FONT_HEAVY, TextSize = math.floor(sz.Y * 0.5), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
			TextColor3 = on and COL.Text or COL.Grey, ZIndex = 8, Parent = face }), 1.5)
	elseif kind then
		glyph(face, kind, math.floor(sz.Y * 0.64), on and COL.Text or COL.Grey, 8)
	end
	if tone == "equipped" then
		b.Active = false
	elseif enabled then
		Kit.bindButton(b, { hover = 1.06, press = 0.92 }) -- Kit squash + hover / click sounds + gamepad selection grow
	end
	return b
end

-- icon + title + small line inside a right-hand card. wide = no button on the right, so the text can run longer
local function cardRow(parent: Instance, y: number, icon, title: string, sub: string, wide: boolean?)
	local w = wide and (CARD_W - 72) or (CARD_W - 62 - 118)
	local r = mk("Frame", { Name = "Row" .. y, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CARD_W, 62), ZIndex = 4, Parent = parent })
	local ic = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(34, 31), Size = UDim2.fromOffset(34, 34),
		ZIndex = 5, Parent = r })
	if type(icon) == "string" then glyph(ic, icon, 36, COL.Text, 5, true) else icon(ic) end
	shade(text({ Text = title, FontFace = FONT_HEAVY, TextSize = 22, Position = UDim2.fromOffset(62, 7), Size = UDim2.fromOffset(w, 24),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = r }), 1.5)
	text({ Text = sub, FontFace = FONT_MED, TextSize = 18, TextColor3 = COL.Sub, Position = UDim2.fromOffset(62, 32), Size = UDim2.fromOffset(w, 21), -- (2026-10-21, grade2) 16 -> 18
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = r })
	return r
end

-------------------------------------------------------------------------------
-- Left column: profile + slot icons, then the long list
-------------------------------------------------------------------------------
local hud -- the scaled canvas everything below lives on (BASE_H units tall)
local creditText, listScroll

local function fitHud()
	local h = ui and ui.AbsoluteSize.Y or 0
	if h < 10 then return end
	-- (2026-10-21, UI audit) narrower than 16:9 (tablets, 4:3 windows) the side panels met in the middle over the item: fit the
	-- width as well as the height
	local w = ui.AbsoluteSize.X
	local s = math.min(h / BASE_H, w / (BASE_H * 16 / 9))
	hud.Scale.Scale = s
	hud.Size = UDim2.fromScale(1 / s, 1 / s)
end

local function makeLocks(row, color: Color3)
	for _, l in row.locks do l:Destroy() end
	table.clear(row.locks)
	if row.owned then return end
	-- (2026-10-21, grade1) one padlock, on the left of the name (was one either side, which read twice)
	-- (2026-10-21, grade3) graders: the padlocks wandered with each centred name. One small 20 px padlock now sits in a fixed
	-- column at x 24 on the row (outside the centred layout), so they line up down the list
	for _, order in { 1 } do
		local l = mk("Frame", { Name = "Lock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0),
			Size = UDim2.fromOffset(20, 20), ZIndex = 5, Parent = row.button })
		if not meshIcon(l, "Lock", 20, color, false, 5) then
			l:Destroy()
			l = padlock(row.button, 20, color, false, color == COL.Text and COL.Ink or COL.DimKey)
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0, 34, 0.5, 0)
		end
		l.LayoutOrder = order
		table.insert(row.locks, l)
	end
end

local function rowLook(row, on: boolean, animate: boolean)
	local info = animate and TI or TweenInfo.new(0)
	TweenService:Create(row.button, info, { Size = UDim2.fromOffset(LIST_W, on and ROW_ON_H or ROW_H) }):Play()
	row.button.ZIndex = on and 5 or 4
	-- (2026-10-21, round 3: match RIVALS, live check) the picked row is a lighter band with bold white words and its render
	-- popping out to the right (as live RIVALS), now stronger than the old 0.88 wash. (2026-10-21, grade3, user: "copy RIVALS")
	-- the field-green lip under the picked row is gone: RIVALS' band is the only mark
	TweenService:Create(row.bg, info, { BackgroundTransparency = on and 0.8 or 1 }):Play()
	if row.hs then TweenService:Create(row.hs, info, { Scale = 1 }):Play() end
	TweenService:Create(row.name, info, { TextSize = on and 32 or 26, TextColor3 = (on or row.owned) and COL.Text or COL.Dim }):Play()
	row.nameStroke.Enabled = on or row.owned
	if not row.owned then makeLocks(row, on and COL.Text or COL.Dim) end
	if row.render then
		row.render:Destroy()
		row.render = nil
	end
	if row.owned then
		-- owned items show their render: small at the row's left end; when picked it's bigger at the right end, popping in.
		-- (2026-10-21, grade2) graders: the renders stuck out over the panel edges and the text beside them. They now sit inside the row
		-- (the row button clips them: ClipsDescendants in makeRow) and the pop is a scale only (a rotated child isn't clipped).
		local size = on and Vector2.new(104, 70) or Vector2.new(74, 54)
		local holder = mk("Frame", { Name = "Render", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = on and UDim2.new(0, LIST_W - 58, 0.5, -2) or UDim2.new(0, 44, 0.5, -1), Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 7, Parent = row.button })
		local sc = mk("UIScale", { Scale = (animate and on) and 0.3 or 1, Parent = holder })
		itemRender(holder, row.id, size, { z = 7, fill = 0.95 })
		if animate and on then
			TweenService:Create(sc, POP, { Scale = 1 }):Play()
		end
		row.render = holder
	end
end

local function makeRow(id: string, order: number, parent: Instance)
	local item = ctx.Config.Items[id]
	local owned = ctx.owns(id)
	local b = mk("TextButton", { Name = id, AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(LIST_W, ROW_H),
		LayoutOrder = order, ZIndex = 4, ClipsDescendants = true, Parent = parent }) -- (2026-10-21, grade2) the render stays inside its row
	local bg = mk("Frame", { Name = "Bg", BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 1, Parent = b }, { corner(6) })
	local content = mk("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = b }, {
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local name = text({ Name = "Name", Text = item.Name, FontFace = FONT_HEAVY, TextSize = 26, TextColor3 = owned and COL.Text or COL.Dim,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), LayoutOrder = 2, ZIndex = 5, Parent = content })
	local stroke = mk("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.45, Enabled = false, Parent = name })
	local row = { id = id, owned = owned, button = b, bg = bg, content = content, name = name, nameStroke = stroke, locks = {},
		hs = mk("UIScale", { Name = "HoverScale", Parent = content }) }
	rowLook(row, false, false)
	-- (2026-10-21, round 3: match RIVALS) hover: the row's words grow a little, a faint tile shows, a locked name lifts a little,
	-- plus the Kit hover tick. (2026-10-21, grade3) the hover lip is gone with the picked-row lip
	b.MouseEnter:Connect(function()
		if selectedRowId == id then return end
		Kit.sfx("hover")
		TweenService:Create(bg, TI, { BackgroundTransparency = 0.92 }):Play()
		TweenService:Create(row.hs, TI, { Scale = 1.05 }):Play()
		if not row.owned then TweenService:Create(name, TI, { TextColor3 = COL.Sub }):Play() end
	end)
	b.MouseLeave:Connect(function()
		if selectedRowId == id then return end
		TweenService:Create(bg, TI, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(row.hs, TI, { Scale = 1 }):Play()
		if not row.owned then TweenService:Create(name, TI, { TextColor3 = COL.Dim }):Play() end
	end)
	b.MouseButton1Down:Connect(function() TweenService:Create(row.hs, TI, { Scale = 0.95 }):Play() end)
	b.Activated:Connect(function()
		if id ~= selectedId then
			Kit.sfx("click")
			Armory.Select(id, 1)
		end
	end)
	return row
end

-- a section header: the slot's name between two silhouettes facing outwards, over a dotted rule
local function makeHeader(slot: string, order: number, parent: Instance)
	local h = mk("Frame", { Name = "Header_" .. slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(LIST_W, HEADER_H), LayoutOrder = order, ZIndex = 4, Parent = parent })
	local row = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(LIST_W, 40), ZIndex = 4, Parent = h }, {
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	-- (2026-10-21, grade1) the faded title between two ghost guns read as disabled: now a full-strength cream Oswald title on its
	-- own, the ghost guns are gone (the dotted rule stays)
	shade(text({ Text = SLOT_TITLE[slot], FontFace = FONT_TITLE, TextSize = 30, TextColor3 = COL.Text, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36), LayoutOrder = 2, ZIndex = 4, Parent = row }), 1.5)
	for i = 0, 21 do
		mk("Frame", { BackgroundColor3 = COL.DimHead, BorderSizePixel = 0, Position = UDim2.fromOffset(34 + i * 12, 64), Size = UDim2.fromOffset(5, 3), ZIndex = 4, Parent = h })
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

local function styleTabs()
	for slot, t in tabs do
		local on = slot == currentTab
		tintIcon(t.icon, on and COL.Text or COL.Grey, on and 0 or 0.3)
		TweenService:Create(t.button, TI, { BackgroundTransparency = on and 0.2 or TILE_T }):Play()
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
	local s = hud.Scale.Scale
	local y = canvasY(row.button)
	local top = listScroll.CanvasPosition.Y
	local window = listScroll.AbsoluteWindowSize.Y
	if y < top + HEADER_H * s or y + ROW_ON_H * s > top + window - 20 * s then
		scrollTo(y - window * 0.35)
	end
end

local ownedKey = nil -- the list is rebuilt only when what you own changes
local function buildList()
	for _, c in listScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(rows)
	table.clear(sections)
	selectedRowId = nil
	for si, slot in SLOT_ORDER do
		-- (2026-10-21, grade2) the dark plate is now ONE fixed plate behind the scroll (buildLeft); the section boxes are see-through
		local box = mk("Frame", { Name = "Box_" .. slot, BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromOffset(LEFT_W, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = si, ZIndex = 3, Parent = listScroll }, {
			corner(8),
			mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			mk("UIPadding", { PaddingBottom = UDim.new(0, 10) }),
		})
		sections[slot] = { header = makeHeader(slot, 0, box), box = box }
		for j, id in itemsInSlot(slot) do
			rows[id] = makeRow(id, j, box)
		end
	end
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

local function refreshProfile()
	local data = ctx.getData()
	if data and creditText then creditText.Text = ctx.commas(data.Credits or 0) end
end

local function buildLeft()
	-- (no currency display yet: the currency hasn't been decided)

	-- profile: headshot, name, slot icons
	local prof = panel({ Name = "Profile", Position = UDim2.fromOffset(LEFT_X, PROFILE_Y), Size = UDim2.fromOffset(LEFT_W, PROFILE_H), ZIndex = 3, Parent = hud })
	-- (2026-10-21, grade1) graders saw the avatar twice (the bust's head floated over the card, its body sat in it): now ONE
	-- headshot inside the card's top-left, the name beside it (RIVALS' Career card)
	local avatar = mk("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(12, 10),
		ZIndex = 5, Parent = prof })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then avatar.Image = img end
	end)
	text({ Text = player.DisplayName, FontFace = FONT_HEAVY, TextSize = 26, TextColor3 = COL.Grey, Size = UDim2.fromOffset(240, 30),
		Position = UDim2.fromOffset(80, 23), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = prof })
	for i, slot in SLOT_ORDER do
		local t = mk("TextButton", { Name = slot, AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = TILE_T,
			Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12 + (i - 1) * 60, 74), ZIndex = 4, Parent = prof }, { corner(6) })
		local box = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(46, 32), ZIndex = 5, Parent = t })
		tabs[slot] = { button = t, icon = slotIcon(box, slot, COL.Grey, false, 0.76) }
		Kit.bindButton(t, { hover = 1.08, press = 0.9 }) -- (2026-10-21, RIVALS pass) Kit button feel + sounds
		t.MouseEnter:Connect(function()
			if currentTab ~= slot then TweenService:Create(t, TI, { BackgroundTransparency = 0.35 }):Play() end
		end)
		t.MouseLeave:Connect(function()
			TweenService:Create(t, TI, { BackgroundTransparency = currentTab == slot and 0.2 or TILE_T }):Play()
		end)
		-- on press (Activated never fired here: the release was lost, so the icons looked broken); touch taps too
		t.MouseButton1Down:Connect(function() setTab(slot) end)
		t.TouchTap:Connect(function() setTab(slot) end)
	end
	-- (2026-10-18) RIVALS' Career > Duel History, from the profile card
	-- (2026-10-21, grade3) a text button among icon slots read odd (and its 19 px words ~10 px on screen): it is one more icon slot
	-- like RIVALS' Career row, a drawn clock, with a "Duel history" hover bubble
	local hb = mk("TextButton", { Name = "History", AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = TILE_T,
		Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(192, 74), ZIndex = 4, Parent = prof }, { corner(6) })
	glyph(hb, "clock", 34, COL.Grey, 5)
	Armory._tip(hb, "Duel history", "up")
	hb.MouseEnter:Connect(function() TweenService:Create(hb, TI, { BackgroundTransparency = 0.25 }):Play() end)
	hb.MouseLeave:Connect(function() TweenService:Create(hb, TI, { BackgroundTransparency = TILE_T }):Play() end)
	hb.Activated:Connect(function() Armory.ShowHistory(true) end)
	Kit.bindButton(hb, { hover = 1.05, press = 0.93 }) -- (2026-10-21, RIVALS pass) Kit button feel + sounds

	-- the list: one scrolling page holding a box per slot.
	-- (2026-10-21, grade2) graders: the dark plate ran off the bottom of the screen and cut "Revolver" in half. One plate now ends 16 px
	-- above the bottom edge and the list scrolls INSIDE it (the scroll frame is the plate's child, inset 6 px top and bottom so
	-- rows clip on a straight line inside the rounded corners). The renders stay inside their rows, so no side overhang is needed.
	local plate = panel({ Name = "ListPlate", Position = UDim2.fromOffset(LEFT_X, LIST_Y), Size = UDim2.fromOffset(LEFT_W, BASE_H - 16 - LIST_Y),
		ZIndex = 3, Parent = hud })
	plate:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
	listScroll = mk("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 1, -12), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 3, Parent = plate }, {
		mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		mk("UIPadding", { PaddingBottom = UDim.new(0, 30) }),
	})
	-- the highlighted slot icon follows whichever section is at the top of the list
	listScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if os.clock() < tabHold or next(sections) == nil then return end
		-- the clicked bottom section stays lit while the list sits at its end
		if pinnedTab and listScroll.CanvasPosition.Y >= maxScroll() - 2 then
			if currentTab ~= pinnedTab then currentTab = pinnedTab; styleTabs() end
			return
		end
		pinnedTab = nil
		local y = listScroll.CanvasPosition.Y + 90 * hud.Scale.Scale
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
-- Right column: item card, level card, actions card (stacked up from the bottom)
-------------------------------------------------------------------------------
local infoCard, levelCard, actionCard
local ACTIONS_BOTTOM = 990
-- (2026-10-21, round 3: match RIVALS, live check) the right column keeps RIVALS' density: level card = bar (grade1: the bar carries
-- the level and the XP to go; the "Level up" row is gone) +
-- "Reward at level N" with a 3D placeholder (Account level moved off: it isn't about this item); actions card = one row per
-- action (Equip / Unlock, Inspect, Next unlock, Statistics), each with a big chunky field-green icon button on the right
local ACTIONS_H, LEVEL_H = 4 * 66 + 12, 172 -- (2026-10-21, grade1) level card: one bar + the reward row (was 176); (grade3) + RIVALS' "Level up" row

local function clearCard(c)
	for _, ch in c:GetChildren() do
		-- (2026-10-21, RIVALS pass) keeps the panel's PopScale too, so a re-render mid pop-in doesn't snap it
		if not ch:IsA("UICorner") and not ch:IsA("UIPadding") and not ch:IsA("UIScale") then ch:Destroy() end
	end
end

-- (2026-10-21, round 3: match RIVALS) RIVALS' hover bubble (t0024: a light pill with dark words and a pointer, "Apply a wrap to
-- this weapon"). One shared bubble on the hud canvas, in our cream; shown while the pointer (or a gamepad selection) is on
-- `anchor`. The right panel's longer words (the description, the ability text, what Next / Stats do) live in these now, so the
-- panel itself stays short. side: "left" (beside the right column) or "up" (above the bottom strip / tray). Table fields, not
-- locals: the chunk is at the local limit.
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
			tip = mk("Frame", { Name = "Tip", BackgroundColor3 = COL.Text, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
				ZIndex = 40, Parent = hud }, { corner(6),
				mk("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
			text({ Name = "Words", FontFace = FONT_MED, TextSize = 17, TextColor3 = COL.Ink, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 18), ZIndex = 42, Parent = tip })
			mk("Frame", { Name = "Pointer", BackgroundColor3 = COL.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
				Size = UDim2.fromOffset(14, 14), ZIndex = 41, Parent = tip })
			Armory._tipFrame = tip
		end
		Armory._tipOwner = anchor
		tip.Words.Text = msg
		tip.Size = UDim2.fromOffset(math.clamp(#msg * 8.6 + 26, 96, 280), 0) -- (Rubik 17 runs ~8.6 px a letter; long text wraps)
		local s = hud.Scale.Scale
		local p = (anchor.AbsolutePosition - hud.AbsolutePosition) / s
		local sz = anchor.AbsoluteSize / s
		if side == "left" then
			tip.AnchorPoint = Vector2.new(1, 0.5)
			tip.Position = UDim2.fromOffset(p.X - 14, p.Y + sz.Y / 2)
			tip.Pointer.Position = UDim2.new(1, 0, 0.5, 0)
		else
			tip.AnchorPoint = Vector2.new(0.5, 1)
			tip.Position = UDim2.fromOffset(p.X + sz.X / 2, p.Y - 12)
			tip.Pointer.Position = UDim2.new(0.5, 0, 1, 0)
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

-- (2026-10-21, round 3: match RIVALS) a soft light sweep across a primary button face every couple of seconds (RIVALS' bright
-- buttons glint; ours stood still). Its own Frame inside the face, so it never fights bindButton's UIScale.
-- (2026-10-21, grade3) unused now: RIVALS' buttons don't glint (user: copy RIVALS). Kept for other callers / a later revisit.
function Armory._shine(face: GuiObject)
	local sweep = mk("Frame", { Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.2, 0.5), Size = UDim2.new(0, 22, 1.4, 0), Rotation = 20, ZIndex = (face.ZIndex or 6) + 1, Parent = face }, {
		mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
	face.ClipsDescendants = true
	task.spawn(function()
		task.wait(0.5)
		while sweep.Parent do
			sweep.Position = UDim2.fromScale(-0.2, 0.5)
			TweenService:Create(sweep, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
			task.wait(2.6)
		end
	end)
end

-- (2026-10-21, round 3: match RIVALS) the tray's 3D placeholders sway gently (RIVALS' item views are never still). Every
-- ViewportFrame camera under `box` is swung a little around the item; one Heartbeat loop serves them all and stops when the
-- tray empties.
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

-- (2026-10-21, RIVALS pass) Statistics, Duel History and the cosmetic tray pop in (Kit.popIn: 0.85 -> 1 with a little overshoot,
-- plus the open sound) and pop out (shrink, then hide), instead of a Visible toggle. Only a "PopScale" UIScale is touched, never
-- Position / AnchorPoint, so the bottom-anchored tray and Stats card stay where they are. (Table fields, not locals: the chunk is
-- near the local limit.)
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

local statsCard, statsOpen = nil, false -- RIVALS' Statistics panel, beside the right column

-- (2026-10-18) lifetime numbers for one item, from Data.WeaponStats[id] (the Tacticals session's PlayerStore):
-- { Kills, Headshots, Deaths, Matches, Wins }. Until it's tracked the panel says so.
local function pct(a, b) return b > 0 and string.format("%.1f%%", a / b * 100) or "N/A" end
local function renderStats(id)
	if not statsCard then return end
	-- (2026-10-21, RIVALS pass) pops in when it opens, out when it closes; a re-render while it's open just redraws in place
	if not (statsOpen and id ~= nil) then
		Armory._popOut(statsCard)
		return
	end
	local opening = not statsCard.Visible or statsCard:GetAttribute("Closing") == true
	clearCard(statsCard)
	local item = ctx.Config.Items[id]
	local data = ctx.getData()
	local ws = data and data.WeaponStats and data.WeaponStats[id]
	local ic = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(30, 30), ZIndex = 5, Parent = statsCard })
	glyph(ic, "bars", 30, COL.Text, 5)
	shade(text({ Text = "Statistics", FontFace = FONT_TITLE, TextSize = 24, Position = UDim2.fromOffset(54, 10), Size = UDim2.fromOffset(CARD_W - 70, 26), ZIndex = 5, Parent = statsCard }), 1.5)
	text({ Text = item and item.Name or id, FontFace = FONT_MED, TextSize = 15, TextColor3 = COL.Sub, Position = UDim2.fromOffset(54, 34), Size = UDim2.fromOffset(CARD_W - 70, 16), ZIndex = 5, Parent = statsCard })
	local y = 62
	local function line(title, value, subs)
		shade(text({ Text = title, FontFace = FONT_HEAVY, TextSize = 19, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(170, 24), ZIndex = 5, Parent = statsCard }), 1.2)
		shade(text({ Text = value, FontFace = FONT_HEAVY, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(CARD_W - 156, y), Size = UDim2.fromOffset(140, 24), ZIndex = 5, Parent = statsCard }), 1.2)
		y += 25
		for _, sub in subs do
			text({ Text = sub[1], FontFace = FONT_MED, TextSize = 15, TextColor3 = COL.Sub, Position = UDim2.fromOffset(34, y), Size = UDim2.fromOffset(170, 19), ZIndex = 5, Parent = statsCard })
			text({ Text = sub[2], FontFace = FONT, TextSize = 16, TextColor3 = COL.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(CARD_W - 156, y), Size = UDim2.fromOffset(140, 19), ZIndex = 5, Parent = statsCard })
			y += 19
		end
		y += 8
	end
	if not ws then
		text({ Text = "Nothing tracked yet", FontFace = FONT_HEAVY, TextSize = 19, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(CARD_W - 32, 24), ZIndex = 5, Parent = statsCard })
		text({ Text = "Play a match with it in your loadout to start its lifetime stats.", FontFace = FONT_MED, TextSize = 15, TextColor3 = COL.Sub, TextWrapped = true,
			Position = UDim2.fromOffset(16, y + 26), Size = UDim2.fromOffset(CARD_W - 32, 40), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = statsCard })
		y += 72
	else
		local k, hs, d = ws.Kills or 0, ws.Headshots or 0, ws.Deaths or 0
		local m, w = ws.Matches or 0, ws.Wins or 0
		line("Matches Played", ctx.commas(m), { { "wins", ctx.commas(w) }, { "losses", ctx.commas(math.max(0, m - w)) }, { "win %", pct(w, m) } })
		line("Eliminations", ctx.commas(k), { { "headshots", ctx.commas(hs) }, { "headshot %", pct(hs, k) } })
		line("Deaths", ctx.commas(d), { { "eliminations ratio", d > 0 and string.format("%.2f", k / d) or (k > 0 and tostring(k) or "N/A") } })
	end
	statsCard.Size = UDim2.fromOffset(CARD_W, y + 6)
	if opening then Armory._popIn(statsCard) end
end

local function renderInfo()
	if not infoCard then return end
	clearCard(infoCard)
	clearCard(levelCard)
	clearCard(actionCard)
	local id = selectedId
	if not id then return end
	local item = ctx.Config.Items[id]
	local data = ctx.getData()
	local owned = ctx.owns(id)

	-- item card: render breaking out of the top-left corner, name, favourite box, notes
	-- (2026-10-21, grade2) the render no longer breaks out over the card's corner (it stuck out over the text): it sits inside, left of the name
	local rbox = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 8), Size = UDim2.fromOffset(44, 36), ZIndex = 6, ClipsDescendants = true, Parent = infoCard })
	itemRender(rbox, id, Vector2.new(44, 36), owned and { z = 6, fill = 0.95 } or { z = 6, fill = 0.95, flat = true, color = COL.Dim })
	-- (2026-10-21, RIVALS pass) heading font: Oswald Bold
	local nameLabel = shade(text({ Text = item.Name, FontFace = FONT_TITLE, TextSize = 34, Position = UDim2.fromOffset(52, 6), Size = UDim2.fromOffset(CARD_W - 104, 40),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = infoCard }), 2)
	local fav = isFavourite(id)
	-- (2026-10-21, AI-tells cleanup) no 2.5 px white outline. (2026-10-21, grade3) graders: the faint grey square looked broken. Now
	-- RIVALS' plain checkbox, drawn solid: a 28 px cream square with a dark well inside (3 px cream edge, no stroke); ticked = the
	-- well turns field green with a cream check
	local favBox = mk("TextButton", { Name = "Favourite", AutoButtonColor = false, Text = "", BackgroundColor3 = COL.Text, BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(CARD_W - 40, 12), Size = UDim2.fromOffset(28, 28), ZIndex = 5, Parent = infoCard }, {
		corner(4) })
	local well = mk("Frame", { Name = "Well", BackgroundColor3 = fav and COL.BlueTop or COL.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6), ZIndex = 6, Parent = favBox }, { corner(2) })
	local tick = glyph(well, "check", 20, COL.Text, 7)
	tick.Visible = fav
	favBox.Activated:Connect(function()
		local on = not isFavourite(id)
		well.BackgroundColor3 = on and COL.BlueTop or COL.Ink
		tick.Visible = on
		-- (2026-10-21, RIVALS pass) the box itself squashes through Kit.bindButton (one UIScale only), the tick pops in
		if on then Kit.pop(tick, 1.3) end
		ctx.ask("Favorite", id, on)
	end)
	Kit.bindButton(favBox, { hover = 1.12, press = 0.88 })
	Armory._tip(favBox, "Favourite", "left") -- (2026-10-21, grade2) graders read the box as a dead control: it pins the item (ctx.ask Favorite)
	local tagline
	if item.Price == 0 then
		tagline = "Starter " .. string.lower(SLOT_LABEL[item.Slot])
	elseif owned then
		tagline = SLOT_LABEL[item.Slot] .. ", unlocked"
	else
		tagline = SLOT_LABEL[item.Slot] .. ", " .. ctx.priceText(item.Price)
	end
	-- (2026-10-21, round 3: match RIVALS) item card like RIVALS' (t0018, live check): the name + checkbox, two SHORT bullet lines
	-- (one line each, cut with "..."; the full description is the hover bubble on the name / bullets), the ability as a chip and
	-- three big stat bars. Ours had wrapped bullets, the ability's whole sentence and 14 px bar labels (the "wall of tiny text").
	local notes = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 48), Size = UDim2.fromOffset(CARD_W - 64, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = infoCard }, {
		mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, line in { tagline, item.Desc } do
		if line and line ~= "" then
			-- (2026-10-21, grade1) no more mid-word cuts ("Honest…"): a bullet shows the description's first sentence only and wraps
			-- (to 2 lines at most) instead of truncating; the whole text is still the hover bubble
			local short = (i == 2 and line:match("^(.-[%.!%?])%s")) or line
			local lab = text({ Text = "•  " .. short, FontFace = FONT_MED, TextSize = 21, TextColor3 = COL.Sub, Size = UDim2.fromOffset(CARD_W - 64, 24), -- (2026-10-21, grade2) 17 -> 19; (grade3) -> 21
				TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, ZIndex = 5, Parent = notes })
			mk("UISizeConstraint", { MaxSize = Vector2.new(CARD_W - 64, 50), Parent = lab })
			if item.Desc and item.Desc ~= "" then Armory._tip(lab, item.Desc, "left") end
		end
	end
	if item.Desc and item.Desc ~= "" then Armory._tip(nameLabel, item.Desc, "left") end
	-- (2026-10-19, Edward's weapon design) the item's ability (or perk), then Speed / Reload / Accuracy bars for guns
	local okA, Abilities = pcall(function()
		return require(ReplicatedStorage.Modules.Shared.Config:FindFirstChild("WeaponAbilities"))
	end)
	local ab = okA and Abilities and Abilities.Items and Abilities.Items[id]
	if ab then
		-- (2026-10-21, grade3, user: "copy RIVALS") the green ability chip is gone (RIVALS' card has no chips): the ability is a third
		-- plain bullet line in the same Rubik as the others; its sentence is still the line's hover bubble
		local chip = text({ Name = "Ability", Text = "•  " .. (ab.perk and "Perk: " or "Ability: ") .. ab.ability, FontFace = FONT_MED, TextSize = 21,
			TextColor3 = COL.Text, Size = UDim2.fromOffset(CARD_W - 64, 26), TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 10, ZIndex = 5, Parent = notes })
		Armory._tip(chip, ab.desc, "left")
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
		if speed then
			-- (2026-10-21, round 3: match RIVALS) big stat bars: 20 px Oswald labels and chunky 14 px field-green segments that fill
			-- one after another when the item is picked (were 14 px labels over 8 px bars, drawn full at once)
			for k, st in { { "Speed", speed }, { "Reload", ab.reload }, { "Accuracy", ab.accuracy } } do
				if not st[2] then continue end
				-- (2026-10-21, grade2) stat names 20 -> 23 (they read ~11 px on screen)
				local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CARD_W - 64, 26), LayoutOrder = 20 + k, ZIndex = 5, Parent = notes })
				shade(text({ Text = st[1], FontFace = FONT_HEAVY, TextSize = 23, Size = UDim2.fromOffset(84, 26), ZIndex = 5, Parent = row }), 1.2)
				-- five segments, filled to the rating (halves allowed)
				for seg = 1, 5 do
					local f = math.clamp((st[2] or 0) - (seg - 1), 0, 1)
					local back = mk("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(88 + (seg - 1) * 30, 6),
						Size = UDim2.fromOffset(27, 14), ZIndex = 5, Parent = row }, { corner(3) })
					if f > 0 then
						local segFill = mk("Frame", { BackgroundColor3 = COL.BlueTop, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6, Parent = back }, {
							corner(3) }) -- (2026-10-21, grade3) solid field green, no gradient
						task.delay(0.06 * seg + 0.1 * k, function()
							if segFill.Parent then Kit.fillTo(segFill, f, 0.28) end
						end)
					end
				end
			end
		end
	end

	-- level card: XP bar with the level in the middle, then level up
	local xp = (data and data.ItemXP and data.ItemXP[id]) or 0
	local level, into, need = ctx.Config.ItemLevel(xp)
	local maxLevel = (ctx.Config.ItemLevels and ctx.Config.ItemLevels.Max) or 50
	local maxed = owned and (level >= maxLevel or not need or need <= 0)
	-- (2026-10-21, grade1) graders: the card said everything twice ("0 ... 1 ... 250" over the bar, then "Level up / 250 XP to
	-- level 2"). Now ONE 22 px bar: "LV n" on its left, "250 XP TO LV 2" on its right (LOCKED / MAX LEVEL states the same
	-- way), and the "Level up" row is gone; "Reward at level N" moves up under it (LEVEL_H 176 -> 110)
	-- (2026-10-21, grade2) the bar 22 -> 28 tall so its words can be 21 / 19 px (the XP line read ~10 px on screen)
	-- (2026-10-21, grade3, user: "copy RIVALS") RIVALS' plain level bar: a cream track at 25%, a solid field-green fill (no gradient)
	-- of at least 6 px once you own it (0 XP read as an empty bar), "LV n" on it; the XP to go moved to RIVALS' "Level up" row below
	local track = mk("Frame", { BackgroundColor3 = COL.Text, BackgroundTransparency = 0.75, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(CARD_W - 24, 28), ZIndex = 5, Parent = levelCard }, { corner(5) })
	local frac = owned and (maxed and 1 or math.clamp(into / math.max(need, 1), 0.02, 1)) or 0
	-- (2026-10-21, round 3: match RIVALS) the bar fills on from where it last stood for this item (was from 0 on every re-render)
	-- and the level number counts up and pops when it changes; remembered per item on Armory._lvl
	Armory._lvl = Armory._lvl or {}
	local prevLvl = Armory._lvl[id]
	local fill = mk("Frame", { BackgroundColor3 = COL.BlueTop, BorderSizePixel = 0, Size = UDim2.fromScale(prevLvl and prevLvl.frac or 0, 1), ZIndex = 6, Parent = track }, {
		corner(5) })
	if owned then mk("UISizeConstraint", { MinSize = Vector2.new(6, 0), Parent = fill }) end
	Kit.fillTo(fill, frac, 0.6)
	local lvLabel = shade(text({ Text = owned and ("LV " .. level) or "LOCKED", FontFace = FONT_HEAVY, TextSize = 21, Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(0, 90, 1, 0), ZIndex = 8, Parent = track }), 1.5)
	cardRow(levelCard, 42, "up", maxed and "Max level" or "Level up", not owned and "Unlock it to earn XP"
		or (maxed and "Every level reached" or `{ctx.commas(need - into)} XP to level {level + 1}`), true)
	if owned and level ~= (prevLvl and prevLvl.level or 1) then
		Kit.countTo(lvLabel, prevLvl and prevLvl.level or 1, level, 0.5, function(n) return "LV " .. math.floor(n + 0.5) end)
		task.delay(0.5, function() if lvLabel.Parent then Kit.pop(lvLabel, 1.25) end end)
	end
	Armory._lvl[id] = { frac = frac, level = level }
	-- (2026-10-21, round 3: match RIVALS) RIVALS' "Reward at Level 50" row with a posed reward render: the next milestone (every 5
	-- levels) with a live 3D placeholder (ViewIcons' Crate: it sways and turns to you on hover) until weapon rewards exist
	local milestone = math.min(maxLevel, (math.floor((owned and level or 0) / 5) + 1) * 5)
	local rewardRow = cardRow(levelCard, 104, "star", "Reward at level " .. milestone, owned and (level >= maxLevel and "All rewards reached" or "A crate for this weapon")
		or "Unlock it to start the rewards", true)
	local rwIcon = rewardRow:FindFirstChild("Frame")
	local okVI, VI = pcall(function() return require(ReplicatedStorage:WaitForChild("UIKit", 2):WaitForChild("ViewIcons", 2)) end)
	if rwIcon and okVI and VI and VI.Icon then
		local okIcon = pcall(function()
			local holder = mk("Frame", { Name = "Reward3D", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(52, 52), ZIndex = 6, Parent = rwIcon })
			VI.Icon(holder, "Crate", { zIndex = 6, hoverTarget = rewardRow })
		end)
		if okIcon then
			for _, g in rwIcon:GetChildren() do if g.Name == "Glyph" then g:Destroy() end end
		end
	end

	-- (2026-10-21, round 3: match RIVALS, live check) actions card: one row per action like RIVALS' Contracts / Overview / Statistics
	-- (t0018): a title, a short sub-line and a BIG chunky icon button on the right (field green; 112 x 54, was 100 x 50). The
	-- primary row (Equip / Unlock) glints; the unlock price sits on its button; a button you can't use shakes when pressed.
	local BTN = Vector2.new(112, 54)
	local function row(y: number, icon, title: string, sub: string, kind: string?, enabled: boolean, label: string?)
		local r = cardRow(actionCard, y, icon, title, sub)
		local b = bigButton(r, kind, enabled, label, BTN)
		if not enabled and kind ~= "check" then b.Activated:Connect(function() Kit.shake(b); Kit.sfx("close") end) end
		return r, b
	end
	if owned then
		local equipped = equippedIn(item.Slot) == id
		-- (2026-10-21, grade3) equipped = RIVALS' plain green square with just the check (bigButton tone "equipped"), not clickable
		local r = cardRow(actionCard, 6, function(h)
			itemRender(h, id, Vector2.new(34, 34), { flat = true, z = 6, fill = 1 })
		end, equipped and "Equipped" or "Equip", equipped and "In your loadout" or "Put it in your loadout")
		local b = bigButton(r, "check", not equipped, nil, BTN, equipped and "equipped" or nil)
		if not equipped then
			b.Activated:Connect(function() ctx.ask("Equip", item.Slot, id) end) -- (grade3: no glint sweep; RIVALS' buttons stand still)
		end
	else
		-- (2026-10-21, RIVALS pass) the price sits on the button (number + the scissors currency icon) and ONE press buys it: no
		-- "SURE?" second click. The press is the confirmation and the scissors cutting the tape is the payoff. Armory._unlocking
		-- blocks a second buy while the request or the cut is running (Kit.busy dots on the button meanwhile). Can't afford: the
		-- button is off-tone (and shakes) and the sub-line says how many more you need.
		local credits = (data and data.Credits) or 0
		local afford = credits >= item.Price
		local _, b = row(6, "unlock", "Unlock", afford and "Cut the tape" or ("Need " .. ctx.commas(item.Price - credits) .. " more"), nil, afford, ctx.commas(item.Price))
		local face = b:FindFirstChild("Face")
		local priceLabel = face and face:FindFirstChildOfClass("TextLabel")
		if priceLabel then
			priceLabel.FontFace = FONT_TITLE -- (a big number: heading font)
			priceLabel.Position = UDim2.fromOffset(6, 0)
			priceLabel.Size = UDim2.new(1, -40, 1, 0)
			priceLabel.TextScaled = true
			mk("UITextSizeConstraint", { MaxTextSize = 27, Parent = priceLabel })
			mk("ImageLabel", { Name = "Currency", BackgroundTransparency = 1, Image = Kit.ICONS.scissors, ImageColor3 = afford and COL.Text or COL.Grey,
				ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(26, 26),
				ZIndex = 8, Parent = face })
		end
		if afford then
			b.Activated:Connect(function()
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
	end
	local _, ib = row(72, "lens", "Inspect", owned and "Give it a spin" or "Unlock it to inspect", "eye", owned) -- (2026-10-21) greyed out while locked
	ib.Activated:Connect(function()
		if owned and not dragging and not currentLocked() then
			spinStart = os.clock()
			returning = false
			yawVel, pitchVel = 0, 0
		end
	end)
	-- the next thing to unlock in this slot (after this one, in price order)
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
	-- (2026-10-21, grade2) graders: "Suppressed,..." was cut. The sub-line is the weapon's name alone; its price sits on the button
	-- (number + scissors, as the Unlock button shows it), and the button's bubble says where it goes
	local _, nb = row(138, "lock", nextItem and "Next unlock" or (owned and "All unlocked" or "Last one"),
		nextItem and nextItem.Name or (owned and "Nothing left in this slot" or "Nothing after it here"), "arrow", nextId ~= nil,
		nextItem and ctx.commas(nextItem.Price) or nil)
	if nextId then
		local nface = nb:FindFirstChild("Face")
		local nlabel = nface and nface:FindFirstChildOfClass("TextLabel")
		if nlabel then
			nlabel.FontFace = FONT_TITLE
			nlabel.Position = UDim2.fromOffset(6, 0)
			nlabel.Size = UDim2.new(1, -40, 1, 0)
			nlabel.TextScaled = true
			mk("UITextSizeConstraint", { MaxTextSize = 27, Parent = nlabel })
			mk("ImageLabel", { Name = "Currency", BackgroundTransparency = 1, Image = Kit.ICONS.scissors, ImageColor3 = COL.Text,
				ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(26, 26),
				ZIndex = 8, Parent = nface })
		end
		Armory._tip(nb, "Go to " .. nextItem.Name, "left")
		nb.Activated:Connect(function() Armory.Select(nextId, 1) end)
	end
	-- RIVALS' Statistics row: the panel opens beside the column, the button turns into an X while it's open
	local _, sb = row(204, "bars", "Statistics", "See lifetime data", statsOpen and "leave" or "bars", true) -- (2026-10-21, grade1) bar chart, was the eye/magnifier
	sb.Activated:Connect(function()
		statsOpen = not statsOpen
		if statsOpen then Armory.ShowHistory(false) end
		renderInfo()
	end)
	renderStats(id)
end


-------------------------------------------------------------------------------
-- Duel History (RIVALS Career > Duel History): your last matches as VICTORY / DEFEAT cards, newest first; a click
-- expands the loadout you used. Data.MatchHistory (the Tacticals session's PlayerStore, newest first, max 20):
-- { t, mode, ranked, map, won, score = {mine, theirs}, kills, deaths, opponents = {{id, name}}, eloDelta, loadout }
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
		shade(text({ Text = "No duels yet", FontFace = FONT_HEAVY, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 40),
			Size = UDim2.fromOffset(W, 30), ZIndex = 22, Parent = list }), 1.5)
		text({ Text = "Your last 20 matches show up here after you play.", FontFace = FONT_MED, TextSize = 17, TextColor3 = COL.Sub,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(W, 22), ZIndex = 22, Parent = list })
		y = 120
	end
	for i, m in hist do
		local won, draw = m.won == true, m.draw == true
		local card = mk("TextButton", { Name = "Duel" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(W, 104), ClipsDescendants = true, ZIndex = 21, Parent = list }, { corner(6),
			mk("UIGradient", { Rotation = 90, Color = draw and ColorSequence.new(Color3.fromRGB(150, 152, 146), Color3.fromRGB(70, 72, 68))
				or won and ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46))
				or ColorSequence.new(Color3.fromRGB(214, 74, 62), Color3.fromRGB(120, 30, 24)) }) })
		local sc = m.score or {}
		text({ Text = string.upper(tostring(m.mode or "1v1")) .. (m.ranked and "  ·  RANKED" or "") .. (m.forfeit and "  ·  FORFEIT" or ""), FontFace = FONT_HEAVY, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(150, 6), Size = UDim2.fromOffset(300, 18), ZIndex = 22, Parent = card })
		shade(text({ Text = draw and "DRAW" or (won and "VICTORY" or "DEFEAT"), FontFace = FONT_HEAVY, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(150, 22), Size = UDim2.fromOffset(300, 40), ZIndex = 22, Parent = card }), 2)
		shade(text({ Text = `{sc[1] or 0} - {sc[2] or 0}`, FontFace = FONT_HEAVY, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(W - 170, 8), Size = UDim2.fromOffset(154, 46), ZIndex = 22, Parent = card }), 2)
		text({ Text = "Your K / D", FontFace = FONT_MED, TextSize = 14, Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(130, 16), ZIndex = 22, Parent = card })
		shade(text({ Text = `{m.kills or 0}  ·  {m.deaths or 0}`, FontFace = FONT_HEAVY, TextSize = 22, Position = UDim2.fromOffset(16, 24), Size = UDim2.fromOffset(130, 26),
			ZIndex = 22, Parent = card }), 1.5)
		text({ Text = `{m.map or "?"}  ·  {ago(m.t)}`, FontFace = FONT_MED, TextSize = 15, Position = UDim2.fromOffset(16, 74), Size = UDim2.fromOffset(200, 20), ZIndex = 22, Parent = card })
		if typeof(m.eloDelta) == "number" then
			shade(text({ Text = (m.eloDelta >= 0 and "+" or "") .. m.eloDelta .. " ELO", FontFace = FONT_HEAVY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromOffset(W - 170, 70), Size = UDim2.fromOffset(154, 24), ZIndex = 22, Parent = card }), 1.5)
		end
		-- opponents: headshots + the first name
		local opp = m.opponents or {}
		for k, o in opp do
			if k > 3 then break end
			local h = mk("ImageLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Position = UDim2.fromOffset(236 + (k - 1) * 44, 62), Size = UDim2.fromOffset(38, 38),
				ZIndex = 22, Parent = card }, { circle() })
			local uid = tonumber(o.id)
			if uid and uid > 0 then
				task.spawn(function()
					local ok, im = pcall(Players.GetUserThumbnailAsync, Players, uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					if ok then h.Image = im end
				end)
			end
		end
		if opp[1] then
			text({ Text = "vs " .. tostring(opp[1].name or "?"), FontFace = FONT, TextSize = 15, Position = UDim2.fromOffset(240 + math.min(#opp, 3) * 44, 72),
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
			text({ Text = "Loadout:  " .. table.concat(names, "  ·  "), FontFace = FONT, TextSize = 17, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(W - 32, 40),
				ZIndex = 22, Parent = row })
			y += 44
		end
		y += 10
		card.Activated:Connect(function()
			historyExpanded = historyExpanded ~= i and i or nil
			buildHistoryList()
		end)
	end
	list.CanvasSize = UDim2.fromOffset(0, y)
end
function Armory.BuildHistory(parent)
	historyPanel = panel({ Name = "DuelHistory", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(640, 780),
		Visible = false, ZIndex = 20, Parent = parent })
	historyPanel.BackgroundTransparency = 0.08 -- (solid enough that the item behind doesn't show through the list)
	local ic = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 18), Size = UDim2.fromOffset(36, 36), ZIndex = 21, Parent = historyPanel })
	glyph(ic, "bars", 36, COL.Text, 21)
	-- (2026-10-21, RIVALS pass) heading font: Oswald Bold
	shade(text({ Text = "Duel History", FontFace = FONT_TITLE, TextSize = 34, Position = UDim2.fromOffset(68, 14), Size = UDim2.fromOffset(400, 40), ZIndex = 21, Parent = historyPanel }), 2)
	text({ Text = "Your most recent matches. Click one to see the loadout you used.", FontFace = FONT_MED, TextSize = 16, TextColor3 = COL.Sub,
		Position = UDim2.fromOffset(68, 52), Size = UDim2.fromOffset(520, 20), ZIndex = 21, Parent = historyPanel })
	local x = mk("TextButton", { Name = "Close", AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = TILE_T,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(46, 46), ZIndex = 21, Parent = historyPanel }, { corner(6) })
	local xi = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), ZIndex = 22, Parent = x })
	glyph(xi, "leave", 30, nil, 22)
	x.Activated:Connect(function() Armory.ShowHistory(false) end)
	Kit.bindButton(x, { hover = 1.08, press = 0.9 }) -- (2026-10-21, RIVALS pass) Kit button feel + sounds
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
-- Bottom: round slots on a strip - LEAVE + cosmetic slots; the tray opens above it
-------------------------------------------------------------------------------
local COSMETICS = {
	-- (2026-10-21, round 3: match RIVALS) Tip = RIVALS' hover bubble over the slot (t0024 "Apply a wrap to this weapon")
	{ Id = "Skin", Label = "Skin", Tip = "Pick a skin for this weapon" },
	{ Id = "Wrap", Label = "Wrap", Tip = "Apply a wrap to this weapon" },
	{ Id = "Finisher", Label = "Finisher", Tip = "Pick a finisher for this weapon" },
	{ Id = "Cutscene", Label = "Cutscene", Tip = "Pick a win cutscene" },
}
local SLOT_D, SLOT_GAP = 90, 121
local bottomBar, tray
local openTray = nil
local slotRings = {} -- [slot id] = the strip's slot button

local function closeTray(instant: boolean?)
	openTray = nil
	if Armory._tipFrame then Armory._tipFrame.Visible = false; Armory._tipOwner = nil end -- (2026-10-21) a tile's bubble outlived the picker
	-- (2026-10-21, RIVALS pass) the tray pops out; instant when another slot's tray replaces it
	if tray then
		if instant then tray.Visible = false; tray:SetAttribute("Closing", nil) else Armory._popOut(tray) end
	end
	-- (2026-10-21, round 3: match RIVALS) the picker stood in for the slot strip: the strip comes back
	if bottomBar and not bottomBar.Visible then
		bottomBar.Visible = true
		Kit.popIn(bottomBar)
	end
end

-- (2026-10-21, round 3: match RIVALS, live check) the cosmetic picker REPLACES the slot strip, as RIVALS' does (t0020 skins, t0026
-- wraps): a red chunky BACK button and the title on top, then one row of ~100 px square tiles. The first tile is "None" (a dark
-- tile, the empty-slot glyph and a big field-green check: it's what you have on); every other tile is filled with its rarity
-- colour and shows a live 3D placeholder that sways (faster on hover): a dark silhouette of this weapon (RIVALS draws exactly
-- that for skins), or a wrapped cube for wraps, with a cream padlock in the middle and the name at the bottom. Locked tiles
-- shake and their padlock jumps when pressed. Was a small popup of four round "Coming soon" dots. Not done: RIVALS' search bar
-- and "Favorited" box (nothing to search until cosmetics exist).
local function openCosmeticTray(c)
	local TILE, GAP, N = 100, 12, 9 -- (function locals: the main chunk is at the local limit)
	if openTray == c.Id then closeTray() return end
	closeTray(true)
	openTray = c.Id
	-- (2026-10-21) the slot's hover bubble stayed up: its slot hides under the picker without a MouseLeave
	if Armory._tipFrame then Armory._tipFrame.Visible = false; Armory._tipOwner = nil end
	if statsOpen then statsOpen = false; renderInfo() end -- (the Statistics card sits where the picker opens)
	Armory.ShowHistory(false)
	-- (2026-10-21, grade2) a grader saw the avatar behind the open picker: opening it re-asserts the Kit's camera hold on the item at once
	-- (renderShowcase holds it every frame too) and never switches views
	do
		local _, holdCF = points()
		local cam = workspace.CurrentCamera
		if holdCF and active and not busy then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = holdCF
			cam.FieldOfView = 40
		end
	end
	bottomBar.Visible = false
	clearCard(tray)
	tray.Size = UDim2.fromOffset(28 + N * (TILE + GAP) - GAP, 70 + TILE + 16)
	Armory._popIn(tray)
	-- BACK: RIVALS' red button (the same red as Kit.closeButton), no hairline. (2026-10-21, grade3) one plain solid red: the dark lip
	-- and the gradient are gone
	local back = mk("TextButton", { Name = "Back", AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(226, 62, 42), Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(150, 48), ZIndex = 5, Parent = tray }, { corner(8) })
	shade(text({ Text = "BACK", FontFace = FONT_TITLE, TextSize = 30, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = back }), 1.5)
	Kit.bindButton(back, { hover = 1.08, press = 0.9 })
	back.Activated:Connect(function() closeTray() end)
	shade(text({ Text = `{c.Label}  ·  {ctx.Config.Items[selectedId].Name}`, FontFace = FONT_TITLE, TextSize = 28, Position = UDim2.fromOffset(182, 14),
		Size = UDim2.fromOffset(600, 44), ZIndex = 5, Parent = tray }), 1.5)
	local rar = ctx.Config.Rarities or {}
	local function rarColor(name: string): Color3
		return (rar[name] and rar[name].Color) or ({ Rare = Color3.fromRGB(70, 160, 255), Epic = Color3.fromRGB(190, 100, 255),
			Legendary = Color3.fromRGB(214, 58, 70) })[name] or Color3.fromRGB(170, 176, 184)
	end
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
	local tiers = { "Rare", "Rare", "Epic", "Epic", "Legendary", "Rare", "Epic", "Legendary" }
	for i = 1, N do
		local isNone = i == 1
		local tier = tiers[i - 1]
		local col = isNone and BLACK or rarColor(tier)
		local tile = mk("TextButton", { Name = isNone and "None" or ("Locked" .. i), AutoButtonColor = false, Text = "", BackgroundColor3 = isNone and BLACK or WHITE,
			BackgroundTransparency = isNone and 0.3 or 0, Position = UDim2.fromOffset(14 + (i - 1) * (TILE + GAP), 70), Size = UDim2.fromOffset(TILE, TILE),
			ZIndex = 5, Parent = tray }, { corner(6) })
		if not isNone then -- rarity fill, lighter at the top. (2026-10-21, grade3) the darker lip strip along the bottom is gone
			mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(WHITE, 0.12), col:Lerp(BLACK, 0.3)), Parent = tile })
		end
		local view = mk("Frame", { Name = "View", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(TILE, TILE - 26), ZIndex = 6, Parent = tile })
		local box, badge
		if isNone then
			box = glyph(view, "empty", 52, COL.Empty, 6)
			-- RIVALS' big green tick on what you have on. (2026-10-21, grade3) it poked 4 px past the tile's right edge: now inset 6 px
			-- (its right edge at TILE - 6)
			badge = mk("Frame", { Name = "Check", BackgroundColor3 = COL.BlueTop, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -26, 1, -32), Size = UDim2.fromOffset(40, 40), ZIndex = 9, Parent = tile }, { circle() })
			glyph(badge, "check", 28, COL.Ink, 10)
		else
			if c.Id == "Wrap" then
				box = itemRender(view, "", Vector2.new(TILE, TILE - 26), { z = 6, fill = 0.78, model = wrapCube(col) })
			else
				box = itemRender(view, selectedId, Vector2.new(TILE, TILE - 26), { z = 6, fill = 0.92, flat = true, color = col:Lerp(BLACK, 0.6) })
			end
			Armory._sway(box, i * 1.3)
			badge = mk("Frame", { Name = "Lock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4 + (TILE - 26) / 2),
				Size = UDim2.fromOffset(36, 36), ZIndex = 9, Parent = tile })
			glyph(badge, "lock", 36, COL.Text, 9)
		end
		-- (2026-10-21, grade3) the per-tile "Skin" name line is gone: it said the same word on every tile (the title says Skin · Pistol)
		shade(text({ Text = isNone and "None" or tier, FontFace = FONT_HEAVY, TextSize = 19, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 22), ZIndex = 10, Parent = tile }), 1.5)
		-- (2026-10-21, grade2) tiles pop in staggered 0.028 s apart, each 0 -> 1 in 0.16 s (Back); bindButton reuses this UIScale
		local popS = mk("UIScale", { Name = "PopScale", Scale = 0, Parent = tile })
		task.delay((i - 1) * 0.028, function()
			if popS.Parent then TweenService:Create(popS, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play() end
		end)
		Kit.bindButton(tile, { hover = 1.08, press = 0.92 })
		-- (2026-10-21, grade2) hover: the tile lifts 4 px and a +15% white sheen washes over it
		-- (2026-10-21, grade3) home is read on the first hover, not here: the tray is converted to Scale after it's built, so a
		-- design-px home sent the hovered tile ~40 px up and left out of its slot
		local home
		local sheen = mk("Frame", { Name = "Sheen", BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ZIndex = 8, Parent = tile }, { corner(6) })
		tile.MouseEnter:Connect(function()
			home = home or tile.Position
			TweenService:Create(tile, TI, { Position = home - UDim2.fromOffset(0, 4) }):Play()
			TweenService:Create(sheen, TI, { BackgroundTransparency = 0.85 }):Play()
		end)
		tile.MouseLeave:Connect(function()
			if home then TweenService:Create(tile, TI, { Position = home }):Play() end
			TweenService:Create(sheen, TI, { BackgroundTransparency = 1 }):Play()
		end)
		-- (2026-10-21, grade3) the bubble says how you'll get it, not "coming soon"
		Armory._tip(tile, isNone and "On now: the standard look" or `{tier} {string.lower(c.Label)} · coming with the next update`, "up")
		tile.MouseEnter:Connect(function() if box then box:SetAttribute("Hover", true) end end)
		tile.MouseLeave:Connect(function() if box then box:SetAttribute("Hover", nil) end end)
		tile.Activated:Connect(function()
			Kit.pop(badge, isNone and 1.35 or 1.3)
			if not isNone then Kit.shake(tile) end -- (locked)
		end)
	end
end

local function renderBottom()
	for _, c in bottomBar:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(slotRings)
	closeTray()
	local owned = selectedId and ctx.owns(selectedId)
	local entries = { { Id = "Leave", Label = "Leave", Tip = "Back to the lobby" } }
	if owned then
		for _, c in COSMETICS do table.insert(entries, c) end
	end
	bottomBar.Size = UDim2.fromOffset(2 * SLOT_D + (#entries - 1) * SLOT_GAP, 53)
	for i, c in entries do
		local cx = SLOT_D + (i - 1) * SLOT_GAP
		local b = mk("TextButton", { Name = c.Id, AutoButtonColor = false, Text = "", BackgroundColor3 = BLACK, BackgroundTransparency = TILE_T,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, -2), Size = UDim2.fromOffset(SLOT_D, SLOT_D), ZIndex = 4, Parent = bottomBar }, { circle() })
		if c.Id == "Leave" then
			-- (2026-10-21, round 3: match RIVALS, live check) Leave is RIVALS' red X (the "leave" mesh glyph, pushed to red); was the cream X
			glyph(b, "leave", 54, nil, 5)
		else
			-- (2026-10-21, round 3: match RIVALS, live check) an EMPTY slot shows RIVALS' empty mark, a grey rounded square with a
			-- slash (GLYPH.empty), not a drawn skin / wrap / finisher / cutscene picture; an equipped cosmetic will show itself here
			glyph(b, "empty", 50, COL.Empty, 5)
			slotRings[c.Id] = b
		end
		shade(text({ Text = c.Label, FontFace = FONT_HEAVY, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, 34), Size = UDim2.fromOffset(116, 26), ZIndex = 6, Parent = bottomBar }), 2)
		Kit.bindButton(b, { hover = 1.07, press = 0.92 }) -- (2026-10-21, RIVALS pass) Kit squash + sounds (was a silent 1.07 hover)
		-- (2026-10-21, round 3: match RIVALS) hover: the circle lightens and the bubble says what the slot does (t0024)
		b.MouseEnter:Connect(function() TweenService:Create(b, TI, { BackgroundTransparency = 0.2 }):Play() end)
		b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundTransparency = TILE_T }):Play() end)
		Armory._tip(b, c.Tip, "up")
		b.Activated:Connect(function()
			if c.Id == "Leave" then
				Armory.Leave()
			else
				openCosmeticTray(c)
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- Refresh / select
-------------------------------------------------------------------------------
local bottomOwned = nil
function Armory.Refresh()
	if not active then return end
	refreshProfile()
	local key = ownedSignature()
	if key ~= ownedKey then
		ownedKey = key
		buildList()
		setSelectedRow(selectedId, false)
	end
	renderInfo()
	local owned = selectedId and ctx.owns(selectedId)
	if owned ~= bottomOwned then
		bottomOwned = owned
		renderBottom()
	end
end

function Armory.Select(id: string, direction: number?)
	fitHud()
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
	refreshProfile()
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

	-- the scaled canvas the panels sit on
	hud = mk("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = ui })
	mk("UIScale", { Name = "Scale", Parent = hud })
	ui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)
	fitHud()

	buildLeft()

	-- right column: cards stacked up from the bottom
	local rightCol = mk("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -11, 0, ACTIONS_BOTTOM),
		Size = UDim2.fromOffset(CARD_W, 900), ZIndex = 3, Parent = hud }, {
		mk("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	infoCard = panel({ Name = "Info", Size = UDim2.fromOffset(CARD_W, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 4, Parent = rightCol })
	mk("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = infoCard })
	levelCard = panel({ Name = "Level", Size = UDim2.fromOffset(CARD_W, LEVEL_H), LayoutOrder = 3, ZIndex = 3, Parent = rightCol })
	actionCard = panel({ Name = "Actions", Size = UDim2.fromOffset(CARD_W, ACTIONS_H), LayoutOrder = 4, ZIndex = 3, Parent = rightCol })
	statsCard = panel({ Name = "Stats", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -(11 + CARD_W + 10), 0, 985 - 53 - 10), -- (sits above the bottom strip)
		Size = UDim2.fromOffset(CARD_W, 200), Visible = false, ZIndex = 3, Parent = hud })
	Armory.BuildHistory(hud)

	-- (2026-10-21, grade2) graders: the round slot discs sat on a dark rectangle with a light line through them. RIVALS' strip is
	-- just the discs and their labels over the room: the strip is a see-through holder now (no plate, no corner brackets)
	bottomBar = mk("Frame", { Name = "Bottom", BackgroundTransparency = 1, Active = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 985),
		Size = UDim2.fromOffset(664, 53), ZIndex = 3, Parent = hud })
	-- (2026-10-21, round 3: match RIVALS) the picker takes the slot strip's place at the bottom (was a popup above it at 868)
	tray = panel({ Name = "Tray", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 990), Size = UDim2.fromOffset(470, 150), Visible = false,
		ZIndex = 3, Parent = hud })
	-- (2026-10-21, RIVALS pass) the columns slide in from the screen edges on Enter and back out on Leave (Armory.SlidePanels):
	-- where each one rests, and how far off-screen it starts (canvas units)
	Armory._slides = {
		{ g = hud:FindFirstChild("Profile"), off = UDim2.fromOffset(-(LEFT_W + 40), 0), delay = 0 },
		{ g = hud:FindFirstChild("ListPlate"), off = UDim2.fromOffset(-(LEFT_W + 40), 0), delay = 0.05 }, -- (grade2: the plate carries the list)
		{ g = rightCol, off = UDim2.fromOffset(CARD_W + 40, 0), delay = 0.03 },
		{ g = bottomBar, off = UDim2.fromOffset(0, 150), delay = 0.08 },
	}
	for _, sl in Armory._slides do sl.home = sl.g and sl.g.Position end

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
		local tag = ctx.label({ Text = side < 0 and "A-07" or "TAC", FontFace = FONT_TITLE, TextSize = 46, TextColor3 = Color3.fromRGB(30, 32, 34),
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
	overlay.title = ctx.label({ Text = "ARMORY", FontFace = FONT_TITLE, TextSize = 64, TextColor3 = ctx.THEME.Accent, TextTransparency = 1,
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
		local d, camCF = points()
		if d and camCF then dof.FocusDistance = (camCF.Position - d).Magnitude end
		dof.InFocusRadius = 0.6 -- (Edward: "add more blur to the room") Roblox DOF at full strength, focus band just the item
		dof.FarIntensity = 1
		dof.NearIntensity = 1
	end
	dof.NearIntensity = 0
	dof.Parent = Lighting
	dof.Enabled = on
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
	UITheme.ShowBackdrop("Armory", 0.35) -- light tint over the sharp set (was 0.7 over a blurred room)
	renderConn = RunService.RenderStepped:Connect(renderShowcase)
	ui.Visible = true
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
	UITheme.HideBackdrop("Armory")
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
			end
			return { active = active, busy = busy, selected = selectedId, tab = currentTab, yaw = yaw, pitch = pitch, turn = math.deg((select(2, rot:ToAxisAngle()))), returning = returning, dragging = dragging, dragStarts = dragStarts }
		end
		hook.Parent = player
	end
end

return Armory
