-- ReplicatedStorage/Modules/Shared/SteamMask (ModuleScript)
-- Is a sound at this position drowned out by a hissing steam valve? Works on server and client
-- (valves carry a "SteamUntil" attribute in server time while they hiss).
-- [STEAMFILL] 2026-10-27 (fix/steam_fill.lua, notes/steam_fill.md): a valve on a map whose model carries the attribute
-- SteamFill = true "steams the room up". Its mask is the cloud's: it grows from Fill.MaskStartRadius to Fill.MaskRadius over
-- Fill.GrowTime (the cloud's billow), stops at the walls the cloud can't pass (the same reach fan the clients draw it with),
-- stays within Fill.MaskHeight above the floor, and lasts until the cloud has faded (Fill.FadeTime after the hiss). Valves on maps
-- without the attribute (the Warehouse, the tutorial) keep the classic jet mask: Steam.MaskRadius while it hisses.
-- Valve attributes: SteamAt (server time it started), SteamUntil (server time the hiss stops). Pure: reads tags, attributes
-- and the map's collision; the shared maths for ShootableManager / BotManager / CombatManager / FootstepController / SteamCloud.
-- Round 3 (fill maps only): the AI can't see through the cloud (SightBlocked), and footsteps / reloads are lost when either the
-- source or the listener is in it (Muffled; players hear them as a faint, muffled thump: SteamCloud.FootstepScale).
local CollectionService = game:GetService("CollectionService")
local Steam = require(script.Parent.Config.ShootableConfig).Steam
local FLAT = Vector3.new(1, 0, 1)
local TAU = math.pi * 2

local mask = {}

-- The Steam.Fill config when this valve steams the room up, else nil. The nearest SteamFill attribute up the tree decides
-- (the map model's, or the valve's own: SteamFill = false opts one valve out on a fill map).
function mask.FillOf(valve: Instance)
	local fill = Steam.Fill
	if type(fill) ~= "table" or fill.Enabled == false then return nil end
	local node: Instance? = valve
	while node and node ~= game do
		local v = node:GetAttribute("SteamFill")
		if v ~= nil then
			if v == true then return fill end
			return nil
		end
		node = node.Parent
	end
	return nil
end

-- Ease-out: the cloud billows fast, then slows as it reaches the walls (the clients use the same curve)
function mask.Ease(g: number): number
	g = math.clamp(g, 0, 1)
	return 1 - (1 - g) * (1 - g)
end

-- Where a fill valve is in its life at server time `now`:
--   grow (0..1, linear), strength (1 while it hisses, then down to 0 over FadeTime), startT, untilT. nil when it isn't steaming.
function mask.Phase(valve: Instance, now: number, fill)
	fill = fill or mask.FillOf(valve)
	local untilT = valve:GetAttribute("SteamUntil")
	if not fill or type(untilT) ~= "number" then return nil end
	local startT = valve:GetAttribute("SteamAt")
	if type(startT) ~= "number" then startT = untilT - (fill.Duration or Steam.Duration) end
	local t = now - startT
	if t < 0 then return nil end
	local grow = math.clamp(t / math.max(fill.GrowTime, 0.01), 0, 1)
	local strength = 1
	if now > untilT then strength = math.clamp(1 - (now - untilT) / math.max(fill.FadeTime, 0.01), 0, 1) end
	if strength <= 0 then return nil end
	return grow, strength, startT, untilT
end

-- // The reach fan: how far the steam spreads in each direction before a wall stops it -------------------------------------
-- Built once per activation (keyed on SteamAt) from the map's collision, so the server and every client get the same shape.
local fans = setmetatable({}, { __mode = "k" }) -- [valve] = fan

local function partsOf(valve: Instance): (BasePart?, BasePart?)
	local body = valve:FindFirstChild("ValveBody")
	if not (body and body:IsA("BasePart")) then body = valve:IsA("BasePart") and valve or valve:FindFirstChildWhichIsA("BasePart", true) end
	local wheel = valve:FindFirstChild("Wheel")
	return body, (wheel and wheel:IsA("BasePart")) and wheel or nil
end

-- the valve's map, found by its role (not by the SteamFill attribute: a valve may carry that itself): the nearest ancestor
-- with a CollisionProxies folder (what the server collides with), else the map model directly under Workspace
local function geometryOf(valve: Instance): Instance?
	local node: Instance? = valve.Parent
	local top: Instance? = nil
	while node and node ~= workspace and node ~= game do
		local col = node:FindFirstChild("CollisionProxies")
		if col then return col end
		top = node
		node = node.Parent
	end
	return if node == workspace then top else nil
end

-- world-space size of a part's box (a wall turned 90 degrees is still long)
local function worldExtents(part: BasePart): Vector3
	local cf, s = part.CFrame, part.Size
	local function axis(v: Vector3) return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) end
	return axis(cf.RightVector) * s.X + axis(cf.UpVector) * s.Y + axis(cf.LookVector) * s.Z
end

-- a wall stops steam; cover boxes, pillars and props don't (the steam rolls round them)
local function isWall(hit: RaycastResult, fill): boolean
	if math.abs(hit.Normal.Y) > 0.6 then return false end -- a ramp / step face, not a wall
	local part = hit.Instance
	if not part:IsA("BasePart") then return true end
	local e = worldExtents(part)
	return math.max(e.X, e.Z) >= fill.WallMinLength
end

function mask.Fan(valve: Instance, fill)
	fill = fill or mask.FillOf(valve)
	if not fill then return nil end
	local key = valve:GetAttribute("SteamAt") or valve:GetAttribute("SteamUntil") or 0
	local cached = fans[valve]
	if cached and cached.key == key then return cached end
	local body, wheel = partsOf(valve)
	if not body then return nil end
	local out = wheel and (wheel.Position - body.Position) * FLAT or Vector3.zero
	out = out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)
	local params = RaycastParams.new()
	local geo = geometryOf(valve)
	if geo then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { geo }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { valve }
	end
	local nozzle = body.Position + out * 0.7
	local ground = nozzle + out * (fill.CentreOut or 3)
	local down = workspace:Raycast(ground + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	local floorY = down and down.Position.Y or (body.Position.Y - 3)
	local centre = Vector3.new(ground.X, floorY + fill.FanHeight, ground.Z)
	local n = fill.FanRays
	local reach = table.create(n, 0)
	local R = fill.Radius
	for i = 1, n do
		local a = (i - 1) / n * TAU
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from, left, r = centre, R, R
		for _ = 1, 10 do
			local hit = workspace:Raycast(from, dir * left, params)
			if not hit then break end
			local d = ((hit.Position - centre) * FLAT).Magnitude
			if isWall(hit, fill) then r = math.max(d - (fill.WallPad or 1), 0) break end
			-- past this piece of cover: a ray that starts inside a part doesn't hit it again
			from = hit.Position + dir * 0.05
			left = R - d - 0.05
			if left <= 0 then break end
		end
		reach[i] = r
	end
	local fan = { key = key, centre = centre, floorY = floorY, nozzle = nozzle, out = out, reach = reach, n = n, radius = R }
	fans[valve] = fan
	return fan
end

-- how far the steam reaches from the fan's centre toward `position` (linear between the two nearest rays)
function mask.ReachAt(fan, position: Vector3): number
	local off = (position - fan.centre) * FLAT
	local a = math.atan2(off.Z, off.X)
	if a < 0 then a += TAU end
	local f = a / TAU * fan.n
	local i0 = math.floor(f)
	local frac = f - i0
	local r0 = fan.reach[(i0 % fan.n) + 1]
	local r1 = fan.reach[((i0 + 1) % fan.n) + 1]
	return r0 + (r1 - r0) * frac
end

-- Masking radius of this valve right now (0 = not masking). Classic valves: Steam.MaskRadius while they hiss.
-- Fill valves: grows with the billow, then covers the whole cloud until the cloud is gone (the work order: "masking ends
-- with the fade"; the cloud thins evenly, it doesn't shrink, so neither does the mask). SteamCloud's screen wash uses this.
function mask.Radius(valve: Instance, now: number?): number
	now = now or workspace:GetServerTimeNow()
	local fill = mask.FillOf(valve)
	if not fill then
		local untilT = valve:GetAttribute("SteamUntil")
		return (untilT and untilT > now) and Steam.MaskRadius or 0
	end
	local grow = mask.Phase(valve, now, fill)
	if not grow then return 0 end
	return fill.MaskStartRadius + (fill.MaskRadius - fill.MaskStartRadius) * mask.Ease(grow)
end

-- Is this position inside the masking cloud of a fill valve? (same test IsMasked uses; SteamCloud's wash reads it too)
function mask.Inside(valve: Instance, fill, position: Vector3, now: number): boolean
	local r = mask.Radius(valve, now)
	if r <= 0 then return false end
	local fan = mask.Fan(valve, fill)
	if not fan then return false end
	local dy = position.Y - fan.floorY
	if dy < -4 or dy > fill.MaskHeight then return false end
	local d = ((position - fan.centre) * FLAT).Magnitude
	return d <= math.min(r, mask.ReachAt(fan, position) + (fill.MaskEdge or 0))
end

-- // Round 3 (Edward 2026-10-27: "it should be blinded by the steam; the steam should muddy up footstep sounds so they are very
-- faint and you can't hear people"). Fill clouds only: the classic jet (Warehouse, Tutorial 3) is unchanged.

-- How thick the fill steam is at this position: 0 = not in any fill cloud, else the cloud's strength (1 while it hisses, thinning
-- to 0 over the fade). Uses the same Inside test as the mask, so "in the steam" means the same thing everywhere.
function mask.InFill(position: Vector3, now: number?): number
	now = now or workspace:GetServerTimeNow()
	local best = 0
	for _, valve in CollectionService:GetTagged("SteamValve") do
		local fill = mask.FillOf(valve)
		if fill and mask.Inside(valve, fill, position, now) then
			local _, strength = mask.Phase(valve, now, fill)
			best = math.max(best, strength or 0)
		end
	end
	return best
end

-- How many studs of steam a line from `a` to `b` crosses, weighted: the thick core near the valve (Sight.CoreRadius) counts
-- Sight.CoreWeight times, and everything scales with the cloud's strength (it thins in the fade). Fill clouds only.
-- Cheap enough for the AI's sight test (it runs after CanSee's raycast is clear): every per-valve lookup is done once; the cloud's
-- circle and the core's circle are exact chords (flat), so only the wall fan and the height band are sampled (every Sight.Step).
-- A map without a Sight block still gets the depth (Footsteps.ThroughDepth uses it): DEFAULT_SIGHT.
local DEFAULT_SIGHT = { CoreRadius = 9, CoreWeight = 3, Step = 0.5 }

-- the part of the line (t in 0..1) whose flat projection lies inside a circle of radius r around the origin of (ox, oz); nil if none
local function chord(ox: number, oz: number, dx: number, dz: number, r: number): (number?, number?)
	local A = dx * dx + dz * dz
	local C = ox * ox + oz * oz - r * r
	if A < 1e-9 then
		if C <= 0 then return 0, 1 end
		return nil, nil
	end
	local B = 2 * (ox * dx + oz * dz)
	local disc = B * B - 4 * A * C
	if disc < 0 then return nil, nil end
	local sq = math.sqrt(disc)
	local t0, t1 = math.max(0, (-B - sq) / (2 * A)), math.min(1, (-B + sq) / (2 * A))
	if t1 <= t0 then return nil, nil end
	return t0, t1
end

function mask.SightDepth(a: Vector3, b: Vector3, now: number?): number
	now = now or workspace:GetServerTimeNow()
	local depth = 0
	local ab = b - a
	local len = ab.Magnitude
	if len < 0.01 then return 0 end
	for _, valve in CollectionService:GetTagged("SteamValve") do
		local fill = mask.FillOf(valve)
		local grow, strength
		if fill then grow, strength = mask.Phase(valve, now, fill) end
		local fan = grow and mask.Fan(valve, fill)
		if fan then
			local sight = fill.Sight or DEFAULT_SIGHT
			local r = fill.MaskStartRadius + (fill.MaskRadius - fill.MaskStartRadius) * mask.Ease(grow) -- = mask.Radius
			local cx, cz = fan.centre.X, fan.centre.Z
			local ox, oz = a.X - cx, a.Z - cz
			local t0, t1 = chord(ox, oz, ab.X, ab.Z, r)
			if t0 and t1 then
				-- split the cloud's chord at the core's chord: each piece has one weight
				local c0, c1 = chord(ox, oz, ab.X, ab.Z, math.min(sight.CoreRadius, r))
				local pieces = { { t0, t1, 1 } }
				if c0 and c1 then
					pieces = { { t0, c0, 1 }, { c0, c1, sight.CoreWeight }, { c1, t1, 1 } }
				end
				local lo, hi = fan.floorY - 4, fan.floorY + fill.MaskHeight
				local edge = fill.MaskEdge or 0
				local step = sight.Step or DEFAULT_SIGHT.Step
				local here = 0
				for _, piece in pieces do
					local p0, p1, w = piece[1], piece[2], piece[3]
					if p1 > p0 then
						local span = (p1 - p0) * len
						local n = math.max(1, math.ceil(span / step))
						local seg = span / n
						for i = 0, n - 1 do
							local p = a + ab * (p0 + (p1 - p0) * (i + 0.5) / n)
							if p.Y >= lo and p.Y <= hi then
								local fx, fz = p.X - cx, p.Z - cz
								if math.sqrt(fx * fx + fz * fz) <= mask.ReachAt(fan, p) + edge then here += seg * w end
							end
						end
					end
				end
				depth += here * strength
			end
		end
	end
	return depth
end

-- Does the steam block this sight line? The AI can't see through it (Edward: "it should be blinded by the steam"): it is blind
-- at Fill.Sight.BlindDepth studs of steam, which makes it blinder than a player, who still makes out a shape in the haze at
-- mid range. BlindDepth is the knob.
function mask.SightBlocked(a: Vector3, b: Vector3, now: number?): boolean
	local fill = Steam.Fill
	if type(fill) ~= "table" or fill.Enabled == false or type(fill.Sight) ~= "table" then return false end
	return mask.SightDepth(a, b, now) >= fill.Sight.BlindDepth
end

-- The fill steam's rule for quiet sounds (footsteps, reloads; Edward: "muddy up footstep sounds so they are very faint and you
-- can't hear people"): lost when the source is in the steam, when the listener is in it (Fill.Footsteps.ListenerInSteam: the
-- hiss around you drowns the room out), or when Fill.Footsteps.ThroughDepth studs of steam lie between them (the same weighted
-- depth as the AI's sight). One rule for players (SteamCloud.FootstepScale) and the AI (BotManager). Fill clouds only.
function mask.FillMuffled(source: Vector3, listener: Vector3?, now: number?): boolean
	local F = Steam.Fill
	local cfg = type(F) == "table" and F.Enabled ~= false and F.Footsteps
	if not cfg then return false end
	now = now or workspace:GetServerTimeNow()
	if mask.InFill(source, now) > 0 then return true end
	if listener == nil then return false end
	if cfg.ListenerInSteam ~= false and mask.InFill(listener, now) > 0 then return true end
	return (cfg.ThroughDepth or 0) > 0 and mask.SightDepth(source, listener, now) >= cfg.ThroughDepth
end

-- Is a quiet sound (a footstep, a reload) from `source` lost in the steam for a listener at `listener`? The classic jet's mask
-- (IsMasked: the source within its 22 studs while it hisses, as before) or the fill steam's rule (FillMuffled). Gunshots,
-- explosions and fire never ask this.
function mask.Muffled(source: Vector3, listener: Vector3?): boolean
	if mask.IsMasked(source) then return true end
	return mask.FillMuffled(source, listener)
end

function mask.IsMasked(position: Vector3): boolean
	local now = workspace:GetServerTimeNow()
	for _, valve in CollectionService:GetTagged("SteamValve") do
		local fill = mask.FillOf(valve)
		if fill then
			if mask.Inside(valve, fill, position, now) then return true end
		else
			local untilT = valve:GetAttribute("SteamUntil")
			if untilT and untilT > now then
				local at = valve:IsA("Model") and valve:GetPivot().Position or valve.Position
				if ((position - at) * FLAT).Magnitude <= Steam.MaskRadius then return true end
			end
		end
	end
	return false
end

return mask
