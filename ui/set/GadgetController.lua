local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/GadgetController (ModuleScript)
-- Smoke grenade:
--   Hold G  -> off hand cocks back and the throw charges the longer you hold (full power after 1s).
--              Release G -> a quick flick throw. Hold it to MaxHoldTime (1.5s) and it throws by itself. In tutorials a streaming arrow shows the
--              exact flight and a ring marks where it lands (GadgetConfig.ArcPreview).
--   Tap G   -> crouched underhand roll along the floor.
-- The server spawns and simulates the grenade (same launch formula as the preview), so it can't be faked.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
ContextActionService = __TG.ContextActionService

local GadgetConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GadgetConfig"))
local Config = GadgetConfig.Smoke
local ThrowGadget = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat"):WaitForChild("ThrowGadget")

local localPlayer = Players.LocalPlayer

-- [SET] Settings > Hotkeys / Controls (UI session 2026-10-16): binds and settings arrive as player attributes
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))
local controller = {}

local SIM_STEP = 0.04

-- // State
local holdStart: number? = nil   -- os.clock() when G went down
local busyUntil = 0              -- throw / roll animation in progress
local tracks: { [string]: AnimationTrack }? = nil
local trackOwner: Humanoid? = nil
local arcFolder: Folder? = nil

-- // Helpers
-- The gadget in your kit ("Smoke" / "Flash")
local function kitGadget(): string
	local kit = localPlayer:GetAttribute("KitGadget")
	return (type(kit) == "string" and GadgetConfig[kit]) and kit or GadgetConfig.Default
end

local function charges(): number
	return localPlayer:GetAttribute(GadgetConfig[kitGadget()].ChargesAttribute) or 0
end

local function getParts()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if humanoid and head and humanoid.Health > 0 then return character, humanoid, head end
	return nil
end

local function loadTracks(humanoid: Humanoid)
	if trackOwner == humanoid and tracks then return tracks end
	tracks, trackOwner = {}, humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return tracks end
	local sources = ReplicatedStorage:FindFirstChild("Repository") and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
	for name, id in Config.Animations do
		-- (pass 40) published to the group: the source carries its asset id
		local pub = id == "" and sources and sources:FindFirstChild("Smoke" .. name)
		if pub and pub:GetAttribute("PublishedId") then id = pub:GetAttribute("PublishedId") end
		if id == "" and RunService:IsStudio() and sources and sources:FindFirstChild("Smoke" .. name) then
			local ok, temp = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(sources["Smoke" .. name])
			end)
			if ok then id = temp end
		end
		if id ~= "" then
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, a)
			if ok then
				track.Priority = Enum.AnimationPriority.Action4
				tracks[name] = track
			end
		end
	end
	return tracks
end

local function aimDirection(): Vector3
	return workspace.CurrentCamera.CFrame.LookVector
end

local function inTutorial(): boolean
	return localPlayer:GetAttribute("InTutorial") == true
end

local function power(): number
	if not holdStart then return 0 end
	local chargeTime = inTutorial() and GadgetConfig.Tutorial.ChargeTime or Config.ChargeTime
	return math.clamp((os.clock() - holdStart - Config.TapTime) / chargeTime, 0, 1)
end

-- Same launch formula as the server
local function launchVelocity(direction: Vector3, p: number): Vector3
	local speed = Config.MinThrowSpeed + (Config.MaxThrowSpeed - Config.MinThrowSpeed) * p
	local lift = Config.MinLift + (Config.MaxLift - Config.MinLift) * p
	return direction * speed + Vector3.new(0, lift, 0)
end

-- Which side the throw leaves from: 0 = straight (right hand), -1/1 = around the left/right corner of
-- whatever's in front of you (cover). Same offset as the server.
local sideParams = RaycastParams.new()
sideParams.FilterType = Enum.RaycastFilterType.Exclude
local function throwSide(head: BasePart, direction: Vector3): number
	local character = head.Parent
	sideParams.FilterDescendantsInstances = { character, arcFolder }
	local reach = direction * 4
	if not workspace:Raycast(head.Position, reach, sideParams) then return 0 end
	local right = direction:Cross(Vector3.yAxis)
	if right.Magnitude < 0.05 then return 0 end
	right = right.Unit
	local cam = workspace.CurrentCamera.CFrame
	-- try the side the camera is on first
	local first = (cam.Position - head.Position):Dot(right) >= 0 and 1 or -1
	for _, s in { first, -first } do
		local offset = right * s * (GadgetConfig.CornerThrowOffset or 1.7)
		if not workspace:Raycast(head.Position, offset, sideParams)
			and not workspace:Raycast(head.Position + offset, reach, sideParams) then
			return s
		end
	end
	return 0
end

local function throwOrigin(head: BasePart, direction: Vector3, side: number): Vector3
	local origin = head.Position
	if side ~= 0 then
		origin += direction:Cross(Vector3.yAxis).Unit * side * (GadgetConfig.CornerThrowOffset or 1.7)
	end
	return origin + direction * 1.5
end

-- How G behaves right now (player attribute "GadgetMode", set by the tutorial per step):
--   "Full"  : tap OR hold - it charges to full by itself and throws the moment it's full (view locked)
--   "Roll"  : tap OR hold - always the quick roll at your feet
--   "Light" : tap OR hold - a short, soft toss
--   nil     : normal (tap = roll, hold = aim + charge, release = throw). Tutorials default to "Full".
local function gadgetMode(): string?
	local m = localPlayer:GetAttribute("GadgetMode")
	if type(m) == "string" then return m end
	if inTutorial() and GadgetConfig.Tutorial.FullChargeOnly then return "Full" end
	return nil
end

-- Tutorial marker (player attribute "GadgetZone", set by TutorialController): work out the throw that
-- lands there. Elevation is fixed at a comfortable lob; the speed is solved for the range (same physics
-- as the server: direction * speed + lift straight up, under workspace.Gravity).
local function zoneThrow(head: BasePart): (Vector3?, number?)
	local zone = localPlayer:GetAttribute("GadgetZone")
	if typeof(zone) ~= "Vector3" then return nil end
	local from = head.Position
	local flat = (zone - from) * Vector3.new(1, 0, 1)
	local range = flat.Magnitude
	if range < 1 then return nil end
	local drop = from.Y - zone.Y -- how far below the hand the marker is (positive = below)
	local g = workspace.Gravity
	local character = head.Parent
	sideParams.FilterDescendantsInstances = { character, arcFolder }
	-- Try a comfortable lob first; if cover right in front would catch it (you're throwing from behind a
	-- crate), lob higher and higher until the first few studs are clear and it still fits under the roof.
	local best = nil
	for _, deg in { GadgetConfig.Tutorial.ZoneElevation or 32, 46, 58, 68, 76 } do
		local elev = math.rad(deg)
		local dir = (flat.Unit * math.cos(elev) + Vector3.new(0, math.sin(elev), 0))
		local function rangeFor(p)
			local v = launchVelocity(dir, p)
			local vy, vh = v.Y, Vector3.new(v.X, 0, v.Z).Magnitude
			local disc = vy * vy + 2 * g * drop -- vy*t - g/2 t^2 = -drop
			if disc < 0 then return 0 end
			return vh * (vy + math.sqrt(disc)) / g
		end
		local p
		if rangeFor(1) <= range then p = 1
		elseif rangeFor(0) >= range then p = 0
		else
			local lo, hi = 0, 1
			for _ = 1, 18 do
				local mid = (lo + hi) / 2
				if rangeFor(mid) < range then lo = mid else hi = mid end
			end
			p = (lo + hi) / 2
		end
		best = best or { dir, p } -- fall back to the lowest lob if nothing is clear
		-- clear of what's right in front, and under the roof at the apex?
		local v = launchVelocity(dir, p)
		local apex = from.Y + v.Y * v.Y / (2 * g)
		local blocked = workspace:Raycast(from, dir * 7, sideParams)
		local roof = workspace:Raycast(from, Vector3.new(0, 30, 0), sideParams)
		local roofY = roof and roof.Position.Y or math.huge
		if not blocked and apex < roofY - 1 then return dir, p end
	end
	return best[1], best[2]
end

-- // Throw preview
-- Only in tutorials (GadgetConfig.ArcPreview "Tutorial" / "Always" / "Never"): in a real match you
-- judge a throw yourself. Local only - it lives under the camera, so nobody else ever sees it.
--   the arrow : a thin glowing shaft that draws itself out of your hand along the exact flight, with
--               chevrons streaming down it and an arrowhead riding the front. The chevrons stream
--               faster and burn whiter as the throw charges.
--   landing   : once the arrow arrives, a dashed ring pops in on the spot and slowly turns, with four
--               chevrons breathing in on it.
local PREVIEW = {
	Chevrons = 32,                  -- pooled chevrons along the shaft
	Spacing = 2.2,                  -- studs between them (stretches on long throws so they reach the end)
	Flow = 5,                       -- studs / s they stream at (up to 1.8x at full charge)
	ArmLength = 0.5, ArmWidth = 0.09, ArmAngle = math.rad(44),
	NearScale = 0.8, FarScale = 1.8, ScaleDistance = 16, -- far chevrons grow so they stay readable
	Samples = 40,                   -- points along the flight used to place things
	RingDashes = 24, RingRadius = 1.8, RingSpin = 0.8,
	Reveal = 0.32,                  -- seconds for the arrow to draw out from the hand
	Pop = 0.26,                     -- seconds for the landing ring to pop in
	Cold = Color3.fromRGB(70, 150, 255),   -- soft throw (the UI's blue)
	Hot = Color3.fromRGB(185, 222, 255),   -- full power
}

local preview = nil             -- the pooled parts (built on first use)
local shownAt: number? = nil    -- when the arrow started drawing out
local landAt: number? = nil     -- when the landing ring started popping in
local phase = 0                 -- 0..1: how far the chevrons have streamed along one gap
local lastTint = -1

local function previewAllowed(): boolean
	local mode = GadgetConfig.ArcPreview or "Tutorial"
	if mode == "Always" then return true end
	if mode == "Never" then return false end
	return inTutorial()
end

local function previewPart(size: Vector3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	if shape then p.Shape = shape end
	p.Size = size
	p.Material = Enum.Material.Neon
	p.Color = PREVIEW.Cold
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = arcFolder
	return p
end

local function buildArc()
	if arcFolder then return end
	arcFolder = Instance.new("Folder")
	arcFolder.Name = "ThrowPreview"
	local P = PREVIEW
	local arm = Vector3.new(P.ArmWidth, 0.03, P.ArmLength)
	local chevrons = {}
	for i = 1, P.Chevrons do chevrons[i] = { previewPart(arm), previewPart(arm) } end
	local headArm = Vector3.new(P.ArmWidth * 1.8, 0.03, P.ArmLength * 1.7)
	local head = { previewPart(headArm), previewPart(headArm) }
	-- the shaft: one beam bent to the exact flight (a thrown arc is a Bezier curve)
	local anchor = previewPart(Vector3.one * 0.05)
	anchor.CFrame = CFrame.identity
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = anchor, anchor
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 0.08, 0.17
	beam.FaceCamera = true
	beam.Segments = 40
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(P.Cold)
	beam.Transparency = NumberSequence.new(1)
	beam.Parent = anchor
	-- landing beacon: a soft column of light standing on the spot
	local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
	b0.Parent, b1.Parent = anchor, anchor
	local beacon = Instance.new("Beam")
	beacon.Attachment0, beacon.Attachment1 = b0, b1
	beacon.Width0, beacon.Width1 = 0.9, 0.2
	beacon.FaceCamera = true
	beacon.LightEmission = 1
	beacon.LightInfluence = 0
	beacon.Color = ColorSequence.new(P.Cold)
	beacon.Transparency = NumberSequence.new(1)
	beacon.Parent = anchor
	-- landing
	local dashes = {}
	local dashLength = 2 * math.pi * P.RingRadius / P.RingDashes * 0.55
	for i = 1, P.RingDashes do dashes[i] = previewPart(Vector3.new(dashLength, 0.03, 0.16)) end
	local pointerArm = Vector3.new(P.ArmWidth * 1.4, 0.03, P.ArmLength * 1.25)
	local pointers = {}
	for i = 1, 4 do pointers[i] = { previewPart(pointerArm), previewPart(pointerArm) } end
	local dot = previewPart(Vector3.new(0.03, 0.34, 0.34), Enum.PartType.Cylinder)
	local glow = previewPart(Vector3.new(0.02, P.RingRadius * 2, P.RingRadius * 2), Enum.PartType.Cylinder)
	preview = {
		chevrons = chevrons, head = head, a0 = a0, a1 = a1, beam = beam, b0 = b0, b1 = b1, beacon = beacon,
		dashes = dashes, pointers = pointers, dot = dot, glow = glow,
	}
end

local function hideArc()
	if arcFolder then arcFolder.Parent = nil end
	shownAt, landAt = nil, nil
end

local function easeOutCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

local function backOut(x: number): number
	local c = 1.70158
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

-- A chevron's two arms: tip at `tip`, pointing along `dir`, lying in the plane through `dir` that is as
-- square-on to `facing` as it can be (the camera for the arrow, the ground's normal for the landing).
local function placeChevron(arms, tip: Vector3, dir: Vector3, facing: Vector3, transparency: number, parts, cframes, scale: number?)
	if scale then
		-- resize (only when it has really changed) so far-off chevrons stay readable
		local base = arms.base
		if not base then base = arms[1].Size arms.base = base end
		if math.abs((arms.scale or 1) - scale) > 0.03 then
			arms.scale = scale
			local size = Vector3.new(base.X * scale, base.Y, base.Z * scale)
			arms[1].Size, arms[2].Size = size, size
		end
	end
	local side = dir:Cross(facing)
	if side.Magnitude < 1e-3 then side = dir:Cross(Vector3.yAxis) end
	if side.Magnitude < 1e-3 then side = dir:Cross(Vector3.xAxis) end
	side = side.Unit
	local normal = side:Cross(dir).Unit
	local size = arms[1].Size
	local back = -dir * math.cos(PREVIEW.ArmAngle)
	local out = side * math.sin(PREVIEW.ArmAngle)
	for k = 1, 2 do
		local arm = arms[k]
		local d = back + (k == 1 and out or -out)
		local centre = tip + d * (size.Z * 0.5 - size.X * 0.4) -- the arms overlap into a clean point
		table.insert(parts, arm)
		table.insert(cframes, CFrame.lookAt(centre, centre + d, normal))
		arm.Transparency = transparency
	end
end

local function hideChevron(arms)
	arms[1].Transparency, arms[2].Transparency = 1, 1
end

-- The shaft: fades in leaving the hand, drawn out to `reveal` (0..1 of the flight), fades at the end
local function shaftTransparency(reveal: number, base: number): NumberSequence
	local K = NumberSequenceKeypoint.new
	if reveal >= 0.999 then
		return NumberSequence.new({ K(0, 1), K(0.06, base), K(0.9, base), K(1, 0.85) })
	end
	local r = math.clamp(reveal, 0.1, 0.99)
	return NumberSequence.new({ K(0, 1), K(math.min(0.06, r * 0.5), base), K(r, base), K(r + 0.005, 1), K(1, 1) })
end

local arcParams = RaycastParams.new()
arcParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateArc(dt: number)
	local character, _, head = getParts()
	if not character or not holdStart or not previewAllowed() then hideArc() return end
	if os.clock() - holdStart < Config.TapTime then hideArc() return end -- still might be a tap
	buildArc()
	local P, pv = PREVIEW, preview
	arcParams.FilterDescendantsInstances = { character, arcFolder }

	local direction = aimDirection()
	local pw = power()
	if gadgetMode() == "Full" then
		local zDir, zPow = zoneThrow(head)
		if zDir then direction, pw = zDir, zPow end
	end

	-- Fly it: the same physics as the server's grenade, up to the first thing it hits
	local start = throwOrigin(head, direction, throwSide(head, direction))
	local v0 = launchVelocity(direction, pw)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local position, velocity = start, v0
	local flight, hitAt, hitNormal = 0, nil, nil
	for _ = 1, 90 do
		local nextVelocity = velocity + gravity * SIM_STEP
		local step = (velocity + nextVelocity) * 0.5 * SIM_STEP
		local hit = workspace:Raycast(position, step, arcParams)
		if hit then
			hitAt, hitNormal = hit.Position, hit.Normal
			flight += SIM_STEP * math.clamp(hit.Distance / math.max(step.Magnitude, 1e-3), 0, 1)
			break
		end
		position += step
		velocity = nextVelocity
		flight += SIM_STEP
	end
	local function at(t: number): Vector3
		return start + v0 * t + gravity * (0.5 * t * t)
	end
	local finish = hitAt or at(flight)

	-- Points along the flight (evenly in time) and the distance travelled to each
	local n = P.Samples
	local pts, lens = table.create(n + 1), table.create(n + 1)
	local total = 0
	for i = 0, n do
		local p = (i == n) and finish or at(flight * i / n)
		if i > 0 then total += (p - pts[i]).Magnitude end
		pts[i + 1], lens[i + 1] = p, total
	end
	local function sample(s: number): (Vector3, Vector3)
		local i = 1
		while i < n and lens[i + 1] < s do i += 1 end
		local segLength = lens[i + 1] - lens[i]
		local f = segLength > 1e-4 and math.clamp((s - lens[i]) / segLength, 0, 1) or 0
		local tangent = v0 + gravity * (flight * (i - 1 + f) / n)
		return pts[i]:Lerp(pts[i + 1], f), (tangent.Magnitude > 1e-3 and tangent.Unit or direction)
	end

	local now = os.clock()
	if not shownAt then shownAt = now end
	local revealT = math.clamp((now - shownAt) / P.Reveal, 0, 1)
	local reveal = easeOutCubic(revealT)
	local shown = total * reveal

	-- Tint: cool blue for a soft throw, burning white at full power
	if math.abs(pw - lastTint) > 0.02 then
		lastTint = pw
		local tint = P.Cold:Lerp(P.Hot, pw)
		for _, part in arcFolder:GetChildren() do
			if part:IsA("BasePart") then part.Color = tint end
		end
		pv.beam.Color = ColorSequence.new(tint)
		pv.beacon.Color = ColorSequence.new(tint)
	end

	local parts, cframes = {}, {}
	local camPos = workspace.CurrentCamera.CFrame.Position

	-- Shaft
	local vEnd = v0 + gravity * flight
	local d0 = v0.Magnitude > 1e-3 and v0.Unit or direction
	local d1 = vEnd.Magnitude > 1e-3 and vEnd.Unit or d0
	pv.a0.WorldCFrame = CFrame.lookAt(start, start + d0) * CFrame.Angles(0, math.pi / 2, 0) -- axis along the throw
	pv.a1.WorldCFrame = CFrame.lookAt(finish, finish + d1) * CFrame.Angles(0, math.pi / 2, 0)
	pv.beam.CurveSize0 = flight / 3 * v0.Magnitude
	pv.beam.CurveSize1 = flight / 3 * vEnd.Magnitude
	pv.beam.Transparency = shaftTransparency(reveal, 0.4 - 0.15 * pw)

	-- Chevrons face the camera and point the way the path runs ON SCREEN, so they read as arrows even
	-- when the throw heads straight away from you (lying along the path they'd be seen edge-on)
	local function screenArrow(tip: Vector3, tangent: Vector3): (Vector3, Vector3, number)
		local toTip = tip - camPos
		local distance = toTip.Magnitude
		local view = distance > 1e-3 and toTip / distance or Vector3.zAxis
		local flat = tangent - view * tangent:Dot(view)
		local dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.yAxis
		local scale = math.clamp(distance / P.ScaleDistance, P.NearScale, P.FarScale)
		return dir, view, scale
	end

	-- Chevrons streaming down it (the gap stretches on long throws so they always reach the end)
	local spacing = math.max(P.Spacing, total / (P.Chevrons - 1))
	phase = (phase + dt * P.Flow * (1 + 0.8 * pw) / spacing) % 1
	local headAt = math.max(shown - 0.45 - 0.18 * (0.5 + 0.5 * math.sin(now * 6)), 0)
	for i, arms in pv.chevrons do
		local s = (phase + i - 1) * spacing
		if s > headAt - 0.5 then
			hideChevron(arms)
		else
			local tip, tangent = sample(s)
			-- fade in leaving the hand, and out as they reach the arrowhead
			local fade = math.clamp(s / 1.5, 0, 1) * math.clamp((headAt - s) / 1.6, 0, 1)
			local dir, view, scale = screenArrow(tip, tangent)
			placeChevron(arms, tip, dir, view, 1 - fade * 0.9, parts, cframes, scale)
		end
	end

	-- Arrowhead riding the front (and resting just above the landing spot once it's drawn)
	if total > 0.5 then
		local tip, tangent = sample(headAt)
		local dir, view, scale = screenArrow(tip, tangent)
		placeChevron(pv.head, tip, dir, view, 1 - math.clamp(headAt / 1.2, 0, 1) * 0.95, parts, cframes, scale)
	else
		hideChevron(pv.head)
	end

	-- Landing ring: pops in when the arrow arrives
	local pop = 0
	if hitAt and revealT >= 1 then
		landAt = landAt or now
		pop = math.clamp((now - landAt) / P.Pop, 0, 1)
	else
		landAt = nil
	end
	if pop <= 0 then
		pv.beacon.Transparency = NumberSequence.new(1)
		for _, dash in pv.dashes do dash.Transparency = 1 end
		for _, arms in pv.pointers do hideChevron(arms) end
		pv.dot.Transparency, pv.glow.Transparency = 1, 1
	else
		local up = (hitNormal :: Vector3)
		local ref = math.abs(up.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
		local right = ref:Cross(up).Unit
		local fwd = up:Cross(right).Unit
		local radius = P.RingRadius * backOut(pop) * (1 + 0.045 * math.sin(now * 4))
		local spin = now * P.RingSpin
		local centre = (hitAt :: Vector3) + up * 0.05
		local count = #pv.dashes
		for i, dash in pv.dashes do
			local a = spin + (i - 1) / count * 2 * math.pi
			local out = right * math.cos(a) + fwd * math.sin(a)
			table.insert(parts, dash)
			table.insert(cframes, CFrame.fromMatrix(centre + out * radius, up:Cross(out), up))
			dash.Transparency = 1 - pop * 0.85
		end
		local breathe = 0.5 + 0.5 * math.sin(now * 5.5)
		for i, arms in pv.pointers do
			local a = -spin * 0.6 + (i - 0.5) * math.pi / 2
			local out = right * math.cos(a) + fwd * math.sin(a)
			local tip = centre + up * 0.01 + out * radius * (1.38 + 0.16 * breathe)
			placeChevron(arms, tip, -out, up, 1 - pop * 0.9, parts, cframes)
		end
		table.insert(parts, pv.glow)
		table.insert(cframes, CFrame.fromMatrix(centre - up * 0.02, up, right))
		pv.glow.Transparency = 1 - pop * 0.12
		table.insert(parts, pv.dot)
		table.insert(cframes, CFrame.fromMatrix(centre + up * 0.01, up, right))
		pv.dot.Transparency = 1 - pop * (0.55 + 0.35 * breathe)
		-- the beacon: rises out of the ring as it pops in, breathing with it
		pv.b0.WorldCFrame = CFrame.new(centre)
		pv.b1.WorldCFrame = CFrame.new(centre + up * (3.4 * easeOutCubic(pop)))
		local glowT = 1 - pop * (0.4 + 0.15 * breathe)
		pv.beacon.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, glowT), NumberSequenceKeypoint.new(0.35, 1 - (1 - glowT) * 0.6), NumberSequenceKeypoint.new(1, 1),
		})
	end

	if #parts > 0 then workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged) end
	arcFolder.Parent = workspace.CurrentCamera
end

local pendingRelease = false
local function release()
	if not holdStart then return end
	local heldFor = os.clock() - holdStart
	local p = power()
	local gm = gadgetMode()
	if gm == "Full" and p < 1 then
		pendingRelease = true -- keeps charging; throws itself when full
		return
	end
	pendingRelease = false
	holdStart = nil
	hideArc()
	local _, humanoid = getParts()
	if not humanoid or charges() <= 0 then return end
	local t = loadTracks(humanoid)
	if t.Hold then t.Hold:Stop(0.05) end
	local direction = aimDirection() -- aim is locked in when you let go
	local _, _, headPart = getParts()

	local mode = heldFor < Config.TapTime and "Roll" or "Throw"
	if gm == "Full" then
		mode, p = "Throw", 1
		-- a tutorial marker: throw exactly onto it (direction and power solved), whatever you tap or hold
		if headPart then
			local zDir, zPow = zoneThrow(headPart)
			if zDir and zPow then direction, p = zDir, zPow end
		end
	elseif gm == "Roll" then mode = "Roll"
	elseif gm == "Light" then mode, p = "Throw", (GadgetConfig.Tutorial.LightPower or 0.15) end
	local delay = mode == "Roll" and Config.RollReleaseDelay or Config.ThrowReleaseDelay
	local side = (mode == "Throw" and headPart) and throwSide(headPart, direction) or 0
	local anim = (side < 0 and t.ThrowLeft) or t[mode]
	if anim then
		anim:Play(0.05)
		anim:AdjustSpeed(Config.AnimSpeed or 1)
	end
	busyUntil = os.clock() + delay + 0.25
	task.delay(delay, function()
		local _, h = getParts()
		if h and charges() > 0 then
			ThrowGadget:FireServer(kitGadget(), direction, p, mode, side)
		end
	end)
end

local function refreshHUD()
	-- (the hotbar's slot 2 shows the gadget; nothing extra to draw here)
end

-- Press / release a throw. Used by G, and by left click while the smoke slot (2) is selected.
function controller.Press(): boolean
	if charges() <= 0 or os.clock() < busyUntil or holdStart then return false end
	local _, humanoid = getParts()
	if not humanoid then return false end
	-- [ABILITY2] Landmine (Use = "Place") / Medkit (Use = "Channel"): pressed, not thrown; the server does the rest
	local useCfg = GadgetConfig[kitGadget()]
	if useCfg and useCfg.Use then
		busyUntil = os.clock() + (useCfg.Cooldown or 1)
		ThrowGadget:FireServer(kitGadget(), aimDirection(), 1, "Use", 0)
		return true
	end
	holdStart = os.clock()
	local t = loadTracks(humanoid)
	local gm = gadgetMode()
	if gm == "Roll" or gm == "Light" then
		task.defer(release) -- same thing whether you tap or hold
		return true
	elseif gm == "Full" then
		-- lock the view while it winds up: the throw goes exactly where you aimed when you pressed
		local Camera = shared.Get and shared.Get("CameraController")
		if Camera and Camera.Guide then
			local cam = workspace.CurrentCamera.CFrame
			local chargeTime = inTutorial() and GadgetConfig.Tutorial.ChargeTime or Config.ChargeTime
			local lookAt = cam.Position + cam.LookVector * 80
			-- with a marker: swing the view onto the throw line so you see where it's going
			local _, _, head = getParts()
			if head then
				local zDir = zoneThrow(head)
				if zDir then lookAt = head.Position + zDir * 40 end
			end
			Camera.Guide(lookAt, 0.3, chargeTime + Config.TapTime + 0.35)
		end
	end
	-- cock the arm once it's clearly a hold, not a tap
	task.delay(Config.TapTime, function()
		if holdStart and t.Hold then t.Hold:Play(0.1) end
	end)
	return true
end

function controller.Release()
	release()
end

-- Studio test hook
function controller._Debug()
	return { holdStart = holdStart, pending = pendingRelease, power = power(), mode = gadgetMode(), charges = charges(), busy = os.clock() < busyUntil }
end

function controller.GetCharges(): number
	if GadgetConfig.InfiniteCharges then return math.huge end
	return charges()
end

function controller.GetGadgetName(): string
	return GadgetConfig[kitGadget()].DisplayName
end

function controller.Start()
	local function throwHandler(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			return controller.Press() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
		elseif inputState == Enum.UserInputState.End then
			release()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction("ThrowSmoke", throwHandler, false, Binds.Key(localPlayer, "ThrowGadget", GadgetConfig.Keybinds.Smoke), Enum.KeyCode.ButtonY) -- [SET] Throw Gadget bind, [PAD] Y (RIVALS Quick Utility)
	-- [TOUCH] mobile: the Throw Gadget button (Quick Utility) holds to aim and throws on release, like the key
	task.spawn(function()
		local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		IA.BindCAS("QuickUtility", throwHandler, "ThrowSmoke")
		IA.BindCAS("ThrowGadget", throwHandler, "ThrowSmoke")
	end)

	RunService.RenderStepped:Connect(updateArc)
	RunService.Heartbeat:Connect(function()
		if not holdStart then return end
		-- you can't cook a throw forever: at MaxHoldTime it's fully charged and leaves your hand by itself
		if os.clock() - holdStart >= (Config.MaxHoldTime or 1.5)
			or (power() >= 1 and (pendingRelease or gadgetMode() == "Full")) then
			release()
		end
	end)
	__TG.CharacterAdded:Connect(function()
		holdStart = nil
		hideArc()
	end)
	localPlayer:GetAttributeChangedSignal("SmokeCharges"):Connect(refreshHUD)
	localPlayer:GetAttributeChangedSignal("FlashCharges"):Connect(refreshHUD)
	localPlayer:GetAttributeChangedSignal("KitGadget"):Connect(refreshHUD)
	task.defer(refreshHUD)
	-- Studio test hook (the live instance of this module, not a fresh require)
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "GadgetTestHook"
		hook.OnInvoke = function(action: string)
			if action == "Press" then return controller.Press()
			elseif action == "Release" then release() return true
			else return controller._Debug() end
		end
		hook.Parent = localPlayer:WaitForChild("PlayerScripts")
	end
end

-- Studio test helper: simulate holding G for `seconds` then releasing
function controller._TestThrow(seconds: number)
	holdStart = os.clock() - seconds
	release()
end

return controller
