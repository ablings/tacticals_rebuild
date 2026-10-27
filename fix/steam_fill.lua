-- fix/steam_fill.lua [STEAMFILL] 2026-10-27, round 3 (Edward's review of round 2: "yes it should be blinded by the steam, the steam
-- should muddy up footstep sounds so they are very faint and you can't hear people"; rounds 1-2 never left a test copy). Work order: "make the steam valve steam the room up for Warehouse 2, while
-- it keeps masking noise the way Tutorial 3 teaches" (Lead plan, approved by Edward). Notes: notes/steam_fill.md.
-- MATCH PLACES ONLY (Matchmaking / Ranked / Tutorial and the combined match place), Edit mode. Refuses the hub.
-- Built by tools/steam_fill_build.py (embeds fix/steam_fill/*.lua below). Idempotent (second run: every line "="); checks EVERY
-- anchor in every target before writing anything; stamps the round on ShootableManager (SteamFillRound) and refuses any other
-- round; UNDO (set UNDO = true, or tools/steam_fill_build.py --run <id> UNDO) puts every edit back and removes the new modules.
-- Prints a state hash before / after: UNDO returns to the "before" hash.
--   replaces  ReplicatedStorage.Modules.Shared.SteamMask   (classic path: same maths; fill path: growing, wall-clipped, fading)
--   adds      ReplicatedStorage.Modules.Shared.SteamCloud  (client: the cloud), Client.Controllers.SteamCloudController
--   edits     ShootableConfig (Steam.Fill block), BotConfig (CoverFolders + Warehouse2/CollisionProxies),
--             ShootableManager (every placed map's shootables / props / walls; SteamAt; the hiss line fixed; ResetAll clears
--             SteamAt; Studio-only test hook ServerStorage.SteamFillTestHook)
-- Two old valve bugs fixed on every map (the classic jet is otherwise unchanged): the hiss line errored ("v.SoundTrim.Play(hiss)":
-- no hiss, the jet never stopped, OnValve never fired) and the jet's attachment was placed before it had a parent (the jet drew at
-- twice the valve's position: mid-room 45 studs away, or outside the map).
-- Turning it on for a map: the map model in Workspace carries the attribute SteamFill = true (and is in the MapRegistry).
-- Round 3 (fill maps only; the classic jet is unchanged): the AI can't see through the cloud (BotManager's sight test asks
-- SteamMask.SightBlocked), a bot standing in the steam doesn't hear footsteps or reloads (Muffled / HearNoise quiet), and players
-- hear footsteps in or through the steam muffled and very faint (FootstepController -> SteamCloud.FootstepScale).
--   also edits FootstepController, BotManager, CombatManager (one line: the reload noise is "quiet")
local UNDO = false --@UNDO
local ROUND = 3
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.SteamMask = [=[
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

-- Is a quiet sound (a footstep, a reload) from `source` lost in the steam for a listener at `listener`? True when the source is
-- masked (classic jet or fill cloud, as IsMasked) or, on a fill map, when the LISTENER stands in the cloud (the hiss around you
-- drowns the room out). Gunshots, explosions and fire never ask this.
function mask.Muffled(source: Vector3, listener: Vector3?): boolean
	if mask.IsMasked(source) then return true end
	return listener ~= nil and mask.InFill(listener) > 0
end

-- How many studs of steam a sight line from `a` to `b` crosses, weighted: the thick core near the valve (Sight.CoreRadius) counts
-- Sight.CoreWeight times, and everything scales with the cloud's strength (it thins in the fade). Fill clouds only.
function mask.SightDepth(a: Vector3, b: Vector3, now: number?): number
	now = now or workspace:GetServerTimeNow()
	local depth = 0
	local ab = b - a
	local len = ab.Magnitude
	if len < 0.01 then return 0 end
	for _, valve in CollectionService:GetTagged("SteamValve") do
		local fill = mask.FillOf(valve)
		local sight = fill and fill.Sight
		local r = sight and mask.Radius(valve, now) or 0
		if r > 0 then
			local fan = mask.Fan(valve, fill)
			local _, strength = mask.Phase(valve, now, fill)
			if fan and strength then
				-- quick reject: the line never comes within the cloud's radius (flat)
				local fa, fab = a * FLAT, ab * FLAT
				local c = fan.centre * FLAT
				local t = fab:Dot(fab) > 1e-6 and math.clamp((c - fa):Dot(fab) / fab:Dot(fab), 0, 1) or 0
				if (fa + fab * t - c).Magnitude <= r + 1 then
					local step = sight.Step or 1
					local n = math.max(1, math.ceil(len / step))
					local seg = len / n
					for i = 0, n - 1 do
						local p = a + ab * ((i + 0.5) / n)
						if mask.Inside(valve, fill, p, now) then
							local core = ((p - fan.centre) * FLAT).Magnitude <= sight.CoreRadius
							depth += seg * (core and sight.CoreWeight or 1) * strength
						end
					end
				end
			end
		end
	end
	return depth
end

-- Does the steam block this sight line? (the AI is as blind in it as players are: Fill.Sight.BlindDepth)
function mask.SightBlocked(a: Vector3, b: Vector3, now: number?): boolean
	local fill = Steam.Fill
	if type(fill) ~= "table" or fill.Enabled == false or type(fill.Sight) ~= "table" then return false end
	return mask.SightDepth(a, b, now) >= fill.Sight.BlindDepth
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
]=]
SOURCES.SteamCloud = [=[
-- ReplicatedStorage/Modules/Shared/SteamCloud (ModuleScript, client only) [STEAMFILL] 2026-10-27 (notes/steam_fill.md)
-- The steam cloud of a valve on a map with SteamFill = true, drawn locally from the valve's replicated attributes:
--   SteamAt (server time it was shot) and SteamUntil (server time the hiss stops). Every client of the match (players and
--   spectators, late joiners too) derives the same cloud from the same numbers; nothing is sent per frame.
--   0 .. GrowTime        billows out of the valve: the thick core first, then the haze rolls out ring by ring to the walls
--   .. SteamUntil        holds: thick at the valve, a light haze across the room
--   .. + FadeTime        thins away; then everything is destroyed
-- The haze follows SteamMask's reach fan (it stops at walls, rolls round cover) and lasts exactly as long as the mask; the
-- screen wash shows while you yourself are masked (SteamMask.Inside, the same test the server and the AI use).
-- Mobile-safe: particles capped per quality level (Fill.Quality.High / Low; Low on touch-only devices, saved graphics
-- quality <= Fill.LowQualityAt, or below ~40 fps); Low uses fewer, bigger, denser puffs so the valve corner hides just as well.
-- Studio test override: LocalPlayer attribute SteamFillQuality = "High" / "Low".
-- API: SteamCloud.FootstepScale(sound, source, own) -> volume scale (round 3: footsteps muffled in the steam).
-- API: SteamCloud.Bind(valve) -> handle (:Destroy()). The valve is the replicated model that carries the attributes and its
--   ValveBody / Wheel (the cloud's shape comes from SteamMask.Fan of that model). Binding a classic valve is harmless: it
--   only draws when SteamMask.FillOf(valve) says the map steams up.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SteamMask = require(script.Parent.SteamMask)
local Steam = require(script.Parent.Config.ShootableConfig).Steam

local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FLAT = Vector3.new(1, 0, 1)
local TICK = 0.1 -- seconds between rate / fade updates

local SteamCloud = {}
local live = {} -- [handle] = true (clouds currently drawn; the screen wash reads them)

-- // Quality --------------------------------------------------------------------------------------------------------------------
local fps = 60
RunService.Heartbeat:Connect(function(dt)
	if dt > 0 then fps += (1 / dt - fps) * 0.02 end
end)

function SteamCloud.Quality(): string
	local me = Players.LocalPlayer
	local forced = me and me:GetAttribute("SteamFillQuality")
	if forced == "High" or forced == "Low" then return forced end
	if (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or (me and me:GetAttribute("_ForceTouch") == true) then return "Low" end
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if ok and type(q) == "number" and q > 0 and q <= (Steam.Fill.LowQualityAt or 4) then return "Low" end
	if fps < 40 then return "Low" end
	return "High"
end

-- // Helpers -----------------------------------------------------------------------------------------------------------------------
local function seq(points)
	local kp = {}
	for _, p in points do table.insert(kp, NumberSequenceKeypoint.new(p[1], math.clamp(p[2], 0, 1))) end
	return NumberSequence.new(kp)
end
local function sizeSeq(a: number, b: number, c: number)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.35, b), NumberSequenceKeypoint.new(1, c) })
end
-- transparency curve of a puff that is `base` opaque at its thickest, pushed toward invisible by fade (0..1)
local function puffAlpha(base: number, fade: number)
	local function f(t) return t + (1 - t) * fade end
	return seq({ { 0, f(1) }, { 0.15, f(base) }, { 0.7, f(base + (1 - base) * 0.35) }, { 1, f(1) } })
end

local function camera() return workspace.CurrentCamera end

-- // The cloud ---------------------------------------------------------------------------------------------------------------------
local Handle = {}
Handle.__index = Handle

function SteamCloud.Bind(valve: Instance)
	local self = setmetatable({ valve = valve, conns = {}, cloud = nil }, Handle)
	live[self] = true
	local function changed() self:_sync() end
	table.insert(self.conns, valve:GetAttributeChangedSignal("SteamUntil"):Connect(changed))
	table.insert(self.conns, valve:GetAttributeChangedSignal("SteamAt"):Connect(changed))
	table.insert(self.conns, valve.AncestryChanged:Connect(function()
		if not valve:IsDescendantOf(game) then self:Destroy() end
	end))
	self:_sync()
	return self
end

-- (re)start / stop the cloud from the attributes
function Handle:_sync()
	if self.dead then return end
	local fill = SteamMask.FillOf(self.valve)
	local now = workspace:GetServerTimeNow()
	local grow, _, startT = nil, nil, nil
	if fill then grow, _, startT = SteamMask.Phase(self.valve, now, fill) end
	if not grow then self:_drop() return end
	if self.cloud and self.cloud.startT == startT then return end -- same activation
	self:_drop()
	self:_build(fill, startT)
end

function Handle:_drop()
	local c = self.cloud
	if not c then return end
	self.cloud = nil
	if c.loop then c.loop:Disconnect() end
	for _, e in c.emitters do e.inst.Enabled = false; e.inst:Clear() end
	if c.root then c.root:Destroy() end
end

function Handle:_build(fill, startT: number)
	local fan = SteamMask.Fan(self.valve, fill)
	if not fan then return end
	local q = SteamCloud.Quality()
	local style = fill.Quality[q] or fill.Quality.High
	local cam = camera()
	if not cam then return end

	local root = Instance.new("Part")
	root.Name = "SteamCloud"
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch, root.CastShadow = true, false, false, false, false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(fan.centre)
	root:SetAttribute("Quality", q)
	local c = { startT = startT, fill = fill, style = style, fan = fan, root = root, emitters = {}, quality = q }

	local function add(name: string, worldCF: CFrame, delay: number, share: number, life: NumberRange, props)
		local att = Instance.new("Attachment")
		att.Name = name
		att.Parent = root -- parent first: WorldCFrame set on a loose attachment is taken as relative to the part (doubled)
		att.WorldCFrame = worldCF
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Texture = SMOKE_TEX
		e.Color = ColorSequence.new(fill.Color)
		e.LightInfluence = fill.LightInfluence
		e.LightEmission = 0
		e.Lifetime = life
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-14, 14)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Front
		for k, v in props do
			if string.sub(k, 1, 1) ~= "_" then (e :: any)[k] = v end
		end
		e.Transparency = puffAlpha(props._alpha, 0)
		e.Parent = att
		-- particles alive on average = rate x lifetime: the share of the budget sets the rate
		local avgLife = (life.Min + life.Max) / 2
		local rate = share / math.max(avgLife, 0.1)
		table.insert(c.emitters, { inst = e, delay = delay, rate = rate, base = props._alpha, life = avgLife, fadeKey = 0 })
		return e
	end

	local R = fan.radius
	local budget = style.Particles
	local core = style.Core
	-- 1. the billow out of the valve: thick, fast at first, slowing (drag) a few studs out
	local nozzleCF = CFrame.lookAt(fan.nozzle, fan.nozzle + fan.out + Vector3.new(0, 0.15, 0))
	add("Billow", nozzleCF, 0, budget * core.BillowShare, NumberRange.new(2.2, 3.2), {
		Size = sizeSeq(core.Size[1] * 0.5, core.Size[1], core.Size[2]),
		Speed = NumberRange.new(8, 13), Drag = 1.7, SpreadAngle = Vector2.new(38, 26),
		Acceleration = Vector3.new(0, 0.7, 0), _alpha = core.Alpha,
	})
	-- 2. the pool in front of the valve: the corner you can't see through
	local poolAt = Vector3.new(fan.centre.X, fan.floorY + 3, fan.centre.Z)
	add("Pool", CFrame.lookAt(poolAt, poolAt + fan.out), 0.25, budget * core.PoolShare, NumberRange.new(3.5, 4.6), {
		Size = sizeSeq(core.Size[1], core.Size[2], core.Size[2] * 1.15),
		Speed = NumberRange.new(0.6, 2.2), Drag = 0.6, SpreadAngle = Vector2.new(180, 60),
		Acceleration = Vector3.new(0, 0.35, 0), _alpha = core.Alpha + 0.05,
	})
	-- 3. the haze: anchors along the reach fan, ring by ring; each starts when the billow front gets there
	local haze = style.Haze
	local anchors = {}
	local step = math.max(1, math.floor(fan.n / haze.Directions + 0.5))
	for i = 1, fan.n, step do
		local a = (i - 1) / fan.n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		for ri, ring in haze.Rings do
			local d = fan.reach[i] * ring
			if d >= haze.MinDistance then
				local h = fan.floorY + haze.Heights[((i + ri) % #haze.Heights) + 1]
				local p = Vector3.new(fan.centre.X, h, fan.centre.Z) + dir * d
				table.insert(anchors, { pos = p, dir = dir, d = d, ring = ri })
			end
		end
	end
	local hazeBudget = budget * (1 - core.BillowShare - core.PoolShare)
	for k, an in anchors do
		-- when the front reaches it: the inverse of the eased growth (front = R x Ease(t / GrowTime))
		local frac = math.clamp(an.d / R, 0, 1)
		local delay = fill.GrowTime * (1 - math.sqrt(1 - frac))
		add("Haze" .. k, CFrame.lookAt(an.pos, an.pos + an.dir), delay, hazeBudget / #anchors, NumberRange.new(5, 7), {
			Size = sizeSeq(haze.Size[1] * 0.7, haze.Size[1], haze.Size[2]),
			Speed = NumberRange.new(0.4, 1.6), Drag = 0.25, SpreadAngle = Vector2.new(70, 25),
			Acceleration = Vector3.new(0, 0.2, 0), _alpha = haze.Alpha[math.min(an.ring, #haze.Alpha)],
		})
	end
	root.Parent = cam
	root:SetAttribute("Emitters", #c.emitters)
	root:SetAttribute("Budget", budget)
	self.cloud = c

	-- late join / spectator: fill in what the cloud already holds instead of growing it from nothing
	local now = workspace:GetServerTimeNow()
	for _, e in c.emitters do
		local on = now - startT - e.delay
		if on > 0.5 then e.inst:Emit(math.floor(e.rate * math.min(on, e.life) * 0.8 + 0.5)) end
	end

	local acc = TICK
	c.loop = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then return end
		acc = 0
		self:_step()
	end)
	self:_step()
end

-- rates ramp in as the front arrives; after the hiss: no new puffs, the live ones thin to nothing over FadeTime
function Handle:_step()
	local c = self.cloud
	if not c then return end
	local now = workspace:GetServerTimeNow()
	local grow, strength, startT, untilT = SteamMask.Phase(self.valve, now, c.fill)
	if not grow or startT ~= c.startT then self:_sync() return end
	local hissing = now <= untilT
	local fade = 1 - strength
	for _, e in c.emitters do
		local on = now - startT - e.delay
		local ramp = math.clamp(on / 0.6, 0, 1)
		e.inst.Rate = hissing and e.rate * ramp or 0
		e.inst.Enabled = on > 0
		local key = math.floor(fade * 20 + 0.5)
		if e.fadeKey ~= key then
			e.fadeKey = key
			e.inst.Transparency = puffAlpha(e.base, key / 20)
		end
	end
	c.strength, c.grow = strength, grow
end

function Handle:Destroy()
	if self.dead then return end
	self.dead = true
	live[self] = nil
	self:_drop()
	for _, cn in self.conns do cn:Disconnect() end
end

-- // Screen wash: standing inside the cloud greys the picture a little (never shows MORE than normal) ---------------------------
local wash
local function washStep()
	local cam = camera()
	if not cam then return end
	local k = 0
	-- the wash shows exactly when YOU are masked (SteamMask.Inside, the rule the server and the AI use), at your head
	-- (dead: the camera, never the body's head)
	local me = Players.LocalPlayer
	local char = me and me.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	local alive = hum ~= nil and hum.Health > 0
	local pos = if alive and head and head:IsA("BasePart") then head.Position else cam.CFrame.Position
	local now = workspace:GetServerTimeNow()
	for h in live do
		local c = h.cloud
		if c and c.strength and c.fill.ScreenWash > 0 and SteamMask.Inside(h.valve, c.fill, pos, now) then
			local d = ((pos - c.fan.centre) * FLAT).Magnitude
			local core = 1 - math.clamp(d / math.max(c.fan.radius, 1), 0, 1)
			-- fade in over the last few studs of the edge: it reads as steam, not as a "you're hidden" light
			local limit = math.min(SteamMask.Radius(h.valve, now), SteamMask.ReachAt(c.fan, pos) + (c.fill.MaskEdge or 0))
			local edge = math.clamp((limit - d) / 4, 0, 1)
			k = math.max(k, math.max(c.strength, 0.15) * c.fill.ScreenWash * (0.35 + 0.65 * core) * edge)
		end
	end
	if k <= 0.01 then
		if wash then wash.Enabled = false end
		return
	end
	if not wash or not wash.Parent then
		wash = Instance.new("ColorCorrectionEffect")
		wash.Name = "SteamWash"
	end
	wash.Parent = cam
	wash.Enabled = true
	wash.Brightness = 0.05 * k
	wash.Contrast = -0.3 * k
	wash.Saturation = -0.35 * k
	wash.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(232, 238, 244), k)
end
local washAcc = 0
RunService.RenderStepped:Connect(function(dt)
	washAcc += dt
	if washAcc < 0.05 then return end
	washAcc = 0
	if next(live) == nil and not (wash and wash.Enabled) then return end
	washStep()
end)

-- // Footsteps in the steam (round 3, Edward 2026-10-27: "muddy up footstep sounds so they are very faint and you can't hear
-- people"). FootstepController asks this for every step it plays. Fill clouds: when the walker OR you stand in the steam the step
-- is muffled (an EqualizerSoundEffect on that Sound cuts the crisp highs) and very faint (Fill.Footsteps.Volume; your own:
-- OwnVolume). Classic jet (Warehouse, Tutorial 3): exactly as before, x0.04 for other people's steps inside its 22-stud mask.
-- Returns the volume scale; switches the sound's muffle on / off.
local function ear(): Vector3?
	local me = Players.LocalPlayer
	local char = me and me.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root and root:IsA("BasePart") then return root.Position end
	local cam = camera()
	return cam and cam.CFrame.Position -- dead / spectating: where you are looking from
end

function SteamCloud.FootstepScale(sound: Sound, source: Vector3, own: boolean): number
	local F = Steam.Fill
	local cfg = type(F) == "table" and F.Footsteps
	local inSteam = false
	if cfg then
		local listener = ear()
		inSteam = SteamMask.InFill(source) > 0 or (listener ~= nil and SteamMask.InFill(listener) > 0)
	end
	local eq = sound:FindFirstChild("SteamMuffle")
	if inSteam then
		if not eq then
			eq = Instance.new("EqualizerSoundEffect")
			eq.Name = "SteamMuffle"
			eq.HighGain, eq.MidGain, eq.LowGain = cfg.HighGain, cfg.MidGain, cfg.LowGain
			eq.Parent = sound
		end
		eq.Enabled = true
		return own and cfg.OwnVolume or cfg.Volume
	end
	if eq then eq.Enabled = false end
	if not own and SteamMask.IsMasked(source) then return 0.04 end -- the classic jet, unchanged
	return 1
end

-- test / debug: what this client is drawing
function SteamCloud.Debug()
	local out = {}
	for h in live do
		local c = h.cloud
		table.insert(out, { valve = h.valve:GetFullName(), drawing = c ~= nil, quality = c and c.quality, emitters = c and #c.emitters or 0,
			strength = c and c.strength or 0, grow = c and c.grow or 0 })
	end
	return out
end

return SteamCloud
]=]
SOURCES.SteamCloudController = [=[
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/SteamCloudController (ModuleScript) [STEAMFILL] 2026-10-27
-- Match places: every steam valve (CollectionService tag "SteamValve", set by ShootableManager) gets a SteamCloud binding.
-- Valves on maps without SteamFill = true never draw anything (the classic jet is the server's). Lobby pad-duel arenas
-- (Workspace.DuelArenas) are skipped: their look is per match (ArenaLoader), so a cloud there must come from ArenaLoader.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [valve] = handle

function controller.Start()
	local SteamCloud = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SteamCloud"))
	local function bind(valve: Instance)
		if bound[valve] or valve:FindFirstAncestor("DuelArenas") then return end
		bound[valve] = SteamCloud.Bind(valve)
	end
	for _, v in CollectionService:GetTagged("SteamValve") do bind(v) end
	CollectionService:GetInstanceAddedSignal("SteamValve"):Connect(bind)
	CollectionService:GetInstanceRemovedSignal("SteamValve"):Connect(function(valve)
		local h = bound[valve]
		bound[valve] = nil
		if h then h:Destroy() end
	end)
end

return controller
]=]
SOURCES.FillBlock = [=[
		-- [STEAMFILL] 2026-10-27 maps whose model carries the attribute SteamFill = true (Warehouse 2): the valve STEAMS THE ROOM UP.
		-- Same hiss + jet, then a cloud billows out of the valve and fills the room (drawn on each client of the match from the
		-- valve's SteamAt / SteamUntil), thick at the valve, a light haze across the room. The noise mask grows with it and
		-- ends when it has faded. Maps without the attribute (the Warehouse, the tutorial) keep the classic jet above.
		Fill = {
			Enabled = true,          -- false: every map plays the classic jet
			Duration = 7,            -- seconds of hissing on a fill map (the cloud holds this long)
			GrowTime = 3,            -- seconds for the cloud to billow out to the walls
			FadeTime = 3,            -- seconds for it to thin away after the hiss stops (the mask ends with it)
			Radius = 30,             -- studs: how far the haze spreads from the valve (walls stop it sooner)
			MaskStartRadius = 8,     -- studs masked the moment it's shot (the jet's own cloud)
			MaskRadius = 30,         -- studs masked once the cloud is full (footsteps + reloads; players and AI)
			MaskHeight = 14,         -- only up to this far above the valve's floor (a floor above stays audible)
			MaskEdge = 2,            -- studs of slack past the cloud's edge at a wall (someone hugging the wall is covered)
			-- the cloud's shape: rays from just in front of the valve; a hit on a long part stops the steam, cover doesn't
			CentreOut = 3,           -- studs out from the valve to the cloud's centre
			FanHeight = 6,           -- the rays run this high above the floor (over low cover)
			FanRays = 24,
			WallMinLength = 16,      -- a part at least this long (flat) is a wall; shorter (crates, pillars) the steam rolls round
			WallPad = 1,
			-- look
			Color = Color3.fromRGB(205, 210, 215),
			LightInfluence = 1,       -- lit by the room only (no glow of its own in a dark warehouse)
			ScreenWash = 0.45,       -- standing inside it greys the picture a little (0 = off)
			-- round 3 (Edward 2026-10-27): the AI is blinded by the steam, and footsteps in or through it are muddied to very faint
			Sight = {
				BlindDepth = 6,      -- studs of steam a bot's sight line may cross before it can't see (a player 6+ studs into the haze is hidden)
				CoreRadius = 9,      -- studs around the cloud's centre that count as the thick core
				CoreWeight = 3,      -- a stud of core counts this much (the valve corner blinds after 2 studs)
				Step = 1,            -- studs between samples along the sight line
			},
			Footsteps = {
				Volume = 0.06,       -- other people's steps in the steam (theirs or yours): x this, muffled (very faint; can't place them)
				OwnVolume = 0.5,     -- your own steps in the steam: x this, muffled
				HighGain = -40, MidGain = -18, LowGain = -2, -- the muffle (EqualizerSoundEffect, dB): steam swallows the crisp part
			},
			-- mobile-safe: Particles = how many puffs are alive at once (Low: touch-only devices, saved graphics quality
			-- 1..LowQualityAt, or < 40 fps). Low draws fewer, bigger, denser puffs so the valve corner hides just as well.
			LowQualityAt = 4,
			Quality = {
				High = {
					Particles = 170,
					Core = { BillowShare = 0.24, PoolShare = 0.22, Size = { 7, 12 }, Alpha = 0.42 },
					Haze = { Directions = 12, Rings = { 0.4, 0.8 }, Heights = { 4, 8 }, MinDistance = 4, Size = { 16, 26 }, Alpha = { 0.76, 0.87 } },
				},
				Low = {
					Particles = 60,
					Core = { BillowShare = 0.25, PoolShare = 0.28, Size = { 9, 15 }, Alpha = 0.32 },
					Haze = { Directions = 6, Rings = { 0.55 }, Heights = { 5 }, MinDistance = 4, Size = { 20, 30 }, Alpha = { 0.78 } },
				},
			},
		},
]=]
SOURCES.TestHook = [=[
-- [STEAMFILL] Studio-only test hook: ServerStorage.SteamFillTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar
-- code gets fresh module copies, so it can't reach this manager's state). Valves are named "<Map>/<Valve>" ("Warehouse2/SteamValve_S1").
--   "valves"                 -> JSON list { path, fill, used, at, untilT, radius, jet, hiss }
--   "shoot", path, player?   -> a real shot from the player's head through the valve (OnShot, as CombatManager calls it)
--   "activate", path | "reset" | "radius", path | "masked", Vector3
--   "bots" -> JSON { name, pos, noiseAt, heardAt, clock } | "botAt", Vector3, autonomous? | "ammo", n, player?
--   "sees", player? -> JSON { sees, depth } (round 3) | "hears", player? -> JSON { steps, reload, botInSteam, playerInSteam }
local function steamTestHook()
	local HttpService = game:GetService("HttpService")
	local function pathOf(m: Instance): string
		return (m.Parent and m.Parent.Parent and m.Parent.Parent.Name or "?") .. "/" .. m.Name
	end
	local function valveBy(path: any): Model?
		for _, v in valves do
			if pathOf(v.model) == path or v.model.Name == path then return v.model end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local function botList()
		local bm = Get and Get("BotManager")
		return (bm and bm.GetBots and bm.GetBots()) or {}
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("SteamFillTestHook") or Instance.new("BindableFunction")
	hook.Name = "SteamFillTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		local now = workspace:GetServerTimeNow()
		if cmd == "valves" then
			local list = {}
			for _, v in valves do
				local m = v.model
				table.insert(list, { path = pathOf(m), fill = SteamMask.FillOf(m) ~= nil, used = v.used, at = m:GetAttribute("SteamAt"),
					untilT = m:GetAttribute("SteamUntil"), radius = SteamMask.Radius(m, now), jet = v.jet.Enabled, hiss = v.hiss.IsPlaying, now = now })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" then
			local m, p = valveBy(a), playerBy(b)
			local head = p and p.Character and p.Character:FindFirstChild("Head")
			local body = m and (m:FindFirstChild("ValveBody") or m:FindFirstChildWhichIsA("BasePart"))
			if not (head and body) then return "no head / valve" end
			local dir = (body.Position - head.Position).Unit
			manager.OnShot(head.Position, body.Position + dir * 2, p)
			return if m:GetAttribute("SteamUntil") then "steaming" else "not hit"
		elseif cmd == "activate" then
			local m = valveBy(a)
			if not m then return "no valve" end
			manager.ActivateValve(m, nil)
			return "ok"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		elseif cmd == "radius" then
			local m = valveBy(a)
			return if m then SteamMask.Radius(m, now) else -1
		elseif cmd == "masked" then
			return SteamMask.IsMasked(a)
		elseif cmd == "bots" then
			local list = {}
			for _, bot in botList() do
				table.insert(list, { name = bot.model.Name, pos = tostring(bot.root.Position), noiseAt = bot.noiseAt, heardAt = bot.heardAt, clock = os.clock() })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "botAt" then
			for _, bot in botList() do
				bot:SetAutonomous(b == true)
				bot.root.CFrame = CFrame.new(a)
				bot.root.AssemblyLinearVelocity = Vector3.zero
				return "ok"
			end
			return "no bot"
		elseif cmd == "sees" then -- round 3: can the first bot see this player (walls, smoke, steam; FOV ignored)?
			local p = playerBy(a)
			for _, bot in botList() do
				local char = p and p.Character
				local eye = bot.head and bot.head.Position
				local at = char and char:FindFirstChild("UpperTorso")
				return HttpService:JSONEncode({ sees = bot:CanSee(char, true),
					depth = (eye and at) and SteamMask.SightDepth(eye, at.Position, now) or -1 })
			end
			return "no bot"
		elseif cmd == "hears" then -- round 3: would the first bot hear this player's footsteps / a reload right now?
			local p = playerBy(a)
			local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			for _, bot in botList() do
				if not root then return "no player" end
				return HttpService:JSONEncode({ steps = not SteamMask.Muffled(root.Position, bot.root.Position),
					reload = not SteamMask.IsMasked(root.Position) and SteamMask.InFill(bot.root.Position) <= 0,
					botInSteam = SteamMask.InFill(bot.root.Position), playerInSteam = SteamMask.InFill(root.Position) })
			end
			return "no bot"
		elseif cmd == "ammo" then
			local cm = Get and Get("CombatManager")
			local p = playerBy(b)
			if cm and p then cm.SetAmmo(p, a) end
			return "ok"
		end
		return "unknown command " .. tostring(cmd)
	end
	hook.Parent = game:GetService("ServerStorage")
end

]=]
--@@END SOURCES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- // Where -------------------------------------------------------------------------------------------------------------------------
assert(workspace:FindFirstChild("LobbyMap") == nil and ServerScriptService:FindFirstChild("ArenaShootables", true) == nil,
	"steam_fill: this is the hub (lobby pad duels: ArenaShootables / ArenaLoader). Match places only this round (notes/steam_fill.md)")
local Shared = ReplicatedStorage.Modules.Shared
local Cfg = Shared.Config
local SM = ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers.ShootableManager
local Controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
local Managers = ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers
local BM, CM = Managers.BotManager, Managers.CombatManager
local FC = Controllers.FootstepController

-- // Round stamp: another round's output can still match these anchors; never install over it ----------------------------------------
do
	local stamp = SM:GetAttribute("SteamFillRound")
	assert(stamp == nil or stamp == ROUND, "steam_fill round " .. tostring(stamp) .. " is installed: UNDO it with that round's fix first")
	assert(stamp == ROUND or not SM.Source:find("[STEAMFILL]", 1, true),
		"an unstamped [STEAMFILL] edit is in ShootableManager: UNDO it with the installer that wrote it first")
end

local function norm(s: string): string return (s:gsub("\r\n", "\n")) end
local function hash(): string
	-- FNV-1a over every source this installer touches + which new modules exist
	local h = 2166136261
	local parts = { Shared.SteamMask.Source, Cfg.ShootableConfig.Source, Cfg.BotConfig.Source, SM.Source, BM.Source, CM.Source, FC.Source,
		tostring(Shared:FindFirstChild("SteamCloud") ~= nil), tostring(Controllers:FindFirstChild("SteamCloudController") ~= nil) }
	for _, s in parts do
		s = norm(s)
		for i = 1, #s do h = bit32.bxor(h, s:byte(i)); h = (h * 16777619) % 4294967296 end
	end
	return string.format("%08x", h)
end
local before = hash()

-- // The original SteamMask (restored by UNDO) ------------------------------------------------------------------------------------------
local MASK_ORIG = "-- ReplicatedStorage/Modules/Shared/SteamMask (ModuleScript)\n"
	.. "-- Is a sound at this position drowned out by a hissing steam valve? Works on server and client\n"
	.. "-- (valves carry a \"SteamUntil\" attribute in server time while they hiss).\n"
	.. "local CollectionService = game:GetService(\"CollectionService\")\n"
	.. "local Config = require(script.Parent.Config.ShootableConfig).Steam\n"
	.. "local FLAT = Vector3.new(1, 0, 1)\n\n"
	.. "local mask = {}\n\n"
	.. "function mask.IsMasked(position: Vector3): boolean\n"
	.. "\tlocal now = workspace:GetServerTimeNow()\n"
	.. "\tfor _, valve in CollectionService:GetTagged(\"SteamValve\") do\n"
	.. "\t\tlocal untilT = valve:GetAttribute(\"SteamUntil\")\n"
	.. "\t\tif untilT and untilT > now then\n"
	.. "\t\t\tlocal at = valve:IsA(\"Model\") and valve:GetPivot().Position or valve.Position\n"
	.. "\t\t\tif ((position - at) * FLAT).Magnitude <= Config.MaskRadius then return true end\n"
	.. "\t\tend\n"
	.. "\tend\n"
	.. "\treturn false\n"
	.. "end\n\n"
	.. "return mask\n"

-- // Text edits { instance, old, new } -----------------------------------------------------------------------------------------------
local edits = {}
local function edit(inst, old, new) table.insert(edits, { inst, old, new }) end

-- ShootableConfig: the Fill block inside Steam
local HIT_PAD = "\t\tHitPadding = 0.35,  -- forgiving hitbox (studs added around the valve)\n"
edit(Cfg.ShootableConfig, HIT_PAD .. "\t},\n", HIT_PAD .. SOURCES.FillBlock .. "\t},\n")

-- BotConfig: Warehouse 2's cover boxes (a missing folder is skipped)
edit(Cfg.BotConfig, "\tCoverFolders = { \"Warehouse/CollisionProxies\" }, -- where cover boxes live (paths under Workspace)\n",
	"\tCoverFolders = { \"Warehouse/CollisionProxies\", \"Warehouse2/CollisionProxies\" }, -- where cover boxes live (paths under Workspace) [STEAMFILL] + Warehouse 2\n")

-- [STEAMFILL] round 3 (Edward 2026-10-27): the AI is blinded by the steam, and steam muffles footsteps / reloads
-- BotManager: its sight test (smokeBlocks, used by CanSee) also asks the steam; footsteps are lost when the walker OR the bot is in
-- the steam; HearNoise(..., quiet = true) (a reload) isn't heard by a bot standing in the steam. Shots / blasts: unchanged.
edit(BM, "local function smokeBlocks(a: Vector3, b: Vector3): boolean\n",
	"local function smokeBlocks(a: Vector3, b: Vector3): boolean\n"
	.. "\tif SteamMask.SightBlocked(a, b) then return true end -- [STEAMFILL] round 3: the AI is blinded by the steam (fill maps only)\n")
edit(BM, "\t\tif root and character:GetAttribute(\"Stance\") ~= \"Crouch\" and not SteamMask.IsMasked(root.Position) then\n",
	"\t\t-- [STEAMFILL] round 3: lost in the steam when the walker or this bot stands in it (classic jet: the walker only, as before)\n"
	.. "\t\tif root and character:GetAttribute(\"Stance\") ~= \"Crouch\" and not SteamMask.Muffled(root.Position, self.root.Position) then\n")
edit(BM, "function manager.HearNoise(position: Vector3, radius: number)\n\tlocal now = os.clock()\n\tfor _, bot in bots do\n"
	.. "\t\tif bot:IsAlive() and (bot.root.Position - position).Magnitude <= radius then\n",
	"function manager.HearNoise(position: Vector3, radius: number, quiet: boolean?)\n"
	.. "\t-- [STEAMFILL] round 3: quiet = a reload (never a shot, a break or a blast): a bot standing in steam doesn't hear it\n"
	.. "\tlocal now = os.clock()\n\tfor _, bot in bots do\n"
	.. "\t\tif bot:IsAlive() and (bot.root.Position - position).Magnitude <= radius and not (quiet and SteamMask.InFill(bot.root.Position) > 0) then\n")
-- CombatManager: the reload's noise is "quiet"
edit(CM, "bots.HearNoise(root.Position, (ShootableConfig.ReloadHearRange or 22) * (state.config.SoundScale or 1)) --[[ABILITY]] end\n",
	"bots.HearNoise(root.Position, (ShootableConfig.ReloadHearRange or 22) * (state.config.SoundScale or 1), true) --[[ABILITY]] --[[STEAMFILL quiet]] end\n")
-- FootstepController: every step asks SteamCloud (classic: x0.04 for other people's steps in the jet's mask, exactly as before)
edit(FC, "local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n",
	"local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n"
	.. "local SteamCloud = require(Shared:WaitForChild(\"SteamCloud\")) -- [STEAMFILL] round 3: footsteps muffled in the steam\n")
edit(FC, "\t\t\t\t\t-- a hissing steam valve nearby drowns out other people's footsteps\n"
	.. "\t\t\t\t\tif character ~= me and SteamMask.IsMasked(position) then volume *= 0.04 end\n",
	"\t\t\t\t\t-- [STEAMFILL] round 3: steam drowns footsteps. Classic jet: other people's x0.04 in its mask (as before). A fill cloud:\n"
	.. "\t\t\t\t\t-- muffled and very faint when the walker or you stand in it (SteamCloud.FootstepScale)\n"
	.. "\t\t\t\t\tvolume *= SteamCloud.FootstepScale(s, position, character == me)\n")

-- ShootableManager
edit(SM, "local SoundTrim = require(Shared.SoundTrim) -- skips the hiss file's silent start\n",
	"local SoundTrim = require(Shared.SoundTrim) -- skips the hiss file's silent start\n"
	.. "local MapRegistry do -- [STEAMFILL] the maps placed in this Workspace (the tutorial place has no registry maps: Warehouse only)\n"
	.. "\tlocal reg = Shared:FindFirstChild(\"MapRegistry\") -- (FindFirstChild first: indexing a missing child errors before pcall)\n"
	.. "\tlocal ok, m = false, nil\n"
	.. "\tif reg then ok, m = pcall(require, reg) end\n"
	.. "\tif ok then MapRegistry = m end\n"
	.. "end\n")
edit(SM, "local function mapFolder()\n\tlocal map = workspace:FindFirstChild(\"Warehouse\")\n\treturn map and map:FindFirstChild(\"CollisionProxies\")\nend\n",
	"-- [STEAMFILL] every map placed in this Workspace: the Warehouse first (as before), then the registry's (Warehouse 2 ...)\n"
	.. "local function placedMaps(): { Instance }\n"
	.. "\tlocal list = {}\n"
	.. "\tlocal first = workspace:FindFirstChild(\"Warehouse\")\n"
	.. "\tif first then table.insert(list, first) end\n"
	.. "\tif MapRegistry then\n"
	.. "\t\tfor _, info in MapRegistry.List() do\n"
	.. "\t\t\tlocal m = workspace:FindFirstChild(info.WorkspaceName or info.Id)\n"
	.. "\t\t\tif m and not table.find(list, m) then table.insert(list, m) end\n"
	.. "\t\tend\n"
	.. "\tend\n"
	.. "\treturn list\n"
	.. "end\n"
	.. "local function mapFolders(): { Instance }\n"
	.. "\tlocal list = {}\n"
	.. "\tfor _, m in placedMaps() do\n"
	.. "\t\tlocal f = m:FindFirstChild(\"CollisionProxies\")\n"
	.. "\t\tif f then table.insert(list, f) end\n"
	.. "\tend\n"
	.. "\treturn list\n"
	.. "end\n")
edit(SM, "\tlocal folder = mapFolder()\n\tif not folder then return false end\n\tmapParams.FilterDescendantsInstances = { folder }\n",
	"\tlocal folders = mapFolders() -- [STEAMFILL] the walls of every placed map\n\tif #folders == 0 then return false end\n\tmapParams.FilterDescendantsInstances = folders\n")
edit(SM, "\tv.used = true\n\tmodel:SetAttribute(\"SteamUntil\", workspace:GetServerTimeNow() + Config.Steam.Duration)\n"
	.. "\tv.jet.Enabled = true\n\tv.wisp.Enabled = true\n\tv.hiss.Volume = 0.9\n\tv.SoundTrim.Play(hiss)\n"
	.. "\tlocal token = {}\n\tv.token = token\n\ttask.delay(Config.Steam.Duration, function()\n",
	"\tv.used = true\n"
	.. "\t-- [STEAMFILL] on a map with SteamFill = true the same hiss + jet, and the match's clients draw the cloud from SteamAt /\n"
	.. "\t-- SteamUntil (SteamCloud) while SteamMask grows the mask with it. SteamAt goes first: no client sees a new SteamUntil alone.\n"
	.. "\tlocal fill = SteamMask.FillOf(model)\n"
	.. "\tlocal duration = Config.Steam.Duration\n"
	.. "\tif fill and fill.Duration then duration = fill.Duration end\n"
	.. "\tlocal startT = workspace:GetServerTimeNow()\n"
	.. "\tmodel:SetAttribute(\"SteamAt\", startT)\n"
	.. "\tmodel:SetAttribute(\"SteamUntil\", startT + duration)\n"
	.. "\tv.jet.Enabled = true\n\tv.wisp.Enabled = true\n\tv.hiss.Volume = 0.9\n"
	.. "\tSoundTrim.Play(v.hiss) -- [STEAMFILL] was \"v.SoundTrim.Play(hiss)\": an error that skipped the hiss, the jet's stop and OnValve\n"
	.. "\tlocal token = {}\n\tv.token = token\n\ttask.delay(duration, function()\n")
edit(SM, "\t\tv.model:SetAttribute(\"SteamUntil\", nil)\n",
	"\t\tv.model:SetAttribute(\"SteamUntil\", nil)\n\t\tv.model:SetAttribute(\"SteamAt\", nil) -- [STEAMFILL] the clients drop the cloud at once\n")
edit(SM, "\tlocal ignore = characters()\n\tlocal map = workspace:FindFirstChild(\"Warehouse\")\n"
	.. "\tif map and map:FindFirstChild(\"Props\") then table.insert(ignore, map.Props) end\n",
	"\tlocal ignore = characters()\n"
	.. "\tfor _, placed in placedMaps() do -- [STEAMFILL] every placed map's props (bullets pass through them)\n"
	.. "\t\tlocal propsFolder = placed:FindFirstChild(\"Props\")\n"
	.. "\t\tif propsFolder then table.insert(ignore, propsFolder) end\n"
	.. "\tend\n")
edit(SM, "\tlocal map = workspace:WaitForChild(\"Warehouse\", 10)\n"
	.. "\tlocal shootables = map and map:FindFirstChild(\"Shootables\")\n"
	.. "\tif shootables then\n"
	.. "\t\tfor _, model in shootables:GetChildren() do\n"
	.. "\t\t\tif model.Name:find(\"SteamValve\") then setupValve(model)\n"
	.. "\t\t\telseif model.Name:find(\"FireBarrel\") then\n"
	.. "\t\t\t\tCollectionService:AddTag(model, \"FireBarrel\")\n"
	.. "\t\t\t\ttable.insert(barrels, { model = model, exploded = false, saved = {} })\n"
	.. "\t\t\tend\n"
	.. "\t\tend\n"
	.. "\tend\n"
	.. "\tlocal propFolder = map and map:FindFirstChild(\"Props\")\n"
	.. "\tif propFolder then\n"
	.. "\t\tfor _, prop in propFolder:GetChildren() do table.insert(props, prop) end\n"
	.. "\tend\n",
	"\tworkspace:WaitForChild(\"Warehouse\", 10)\n"
	.. "\t-- [STEAMFILL] the shootables of every placed map (the Warehouse first, as before; then Warehouse 2 ...)\n"
	.. "\tfor _, placed in placedMaps() do\n"
	.. "\t\tlocal shootables = placed:FindFirstChild(\"Shootables\")\n"
	.. "\t\tif shootables then\n"
	.. "\t\t\tfor _, model in shootables:GetChildren() do\n"
	.. "\t\t\t\tif model.Name:find(\"SteamValve\") then setupValve(model)\n"
	.. "\t\t\t\telseif model.Name:find(\"FireBarrel\") then\n"
	.. "\t\t\t\t\tCollectionService:AddTag(model, \"FireBarrel\")\n"
	.. "\t\t\t\t\ttable.insert(barrels, { model = model, exploded = false, saved = {} })\n"
	.. "\t\t\t\tend\n"
	.. "\t\t\tend\n"
	.. "\t\tend\n"
	.. "\tend\n"
	.. "\t-- props that make a noise: the Warehouse's only, as before (PropController breaks only the Warehouse's on screen, so\n"
	.. "\t-- another map's would alert the AI without breaking). Every map's props still let bullets through (OnShot).\n"
	.. "\tlocal home = workspace:FindFirstChild(\"Warehouse\")\n"
	.. "\tlocal propFolder = home and home:FindFirstChild(\"Props\")\n"
	.. "\tif propFolder then\n"
	.. "\t\tfor _, prop in propFolder:GetChildren() do table.insert(props, prop) end\n"
	.. "\tend\n")
-- the hiss fades out, then stops (looped at volume 0 it kept playing, replicated, until the next round)
edit(SM, "\t\tTweenService:Create(v.hiss, TweenInfo.new(0.8), { Volume = 0 }):Play()\n",
	"\t\tlocal fadeOut = TweenService:Create(v.hiss, TweenInfo.new(0.8), { Volume = 0 })\n"
	.. "\t\tfadeOut.Completed:Once(function() if v.token == token then v.hiss:Stop() end end) -- [STEAMFILL] stop the silent loop\n"
	.. "\t\tfadeOut:Play()\n")
-- setupValve: the jet's attachment got its WorldCFrame BEFORE it had a parent, so it was taken as relative to the valve body
-- (the jet drew at twice the valve's position: 45 studs off mid-room for S1, outside the map for S2). Parent first.
edit(SM, "\tatt.Name = \"SteamJet\"\n\tatt.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)\n\tatt.Parent = body\n",
	"\tatt.Name = \"SteamJet\"\n\tatt.Parent = body -- [STEAMFILL] parent first: a loose attachment's WorldCFrame is taken as relative (the jet drew far off)\n"
	.. "\tatt.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)\n")
edit(SM, "function manager.Start()\n", SOURCES.TestHook .. "function manager.Start()\n"
	.. "\tif RunService:IsStudio() then steamTestHook() end -- [STEAMFILL] Studio-only test hook\n")

-- // Pass 1: every anchor in every target, nothing written yet ------------------------------------------------------------------------
local sources, out = {}, {}
for _, e in edits do sources[e[1]] = sources[e[1]] or norm(e[1].Source) end
for i, e in edits do
	local s = sources[e[1]]
	local old, new = e[2], e[3]
	local done
	-- (an insert's new text holds its anchor: "done" = the installed text is there, never "the anchor is gone")
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "steam_fill: edit " .. i .. " anchor not found in " .. e[1]:GetFullName() .. " (nothing was written)")
		assert(not s:find(old, b + 1, true), "steam_fill: edit " .. i .. " anchor not unique in " .. e[1].Name .. " (nothing was written)")
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local maskNow = norm(Shared.SteamMask.Source)
local maskWant = UNDO and MASK_ORIG or SOURCES.SteamMask
assert(maskNow == MASK_ORIG or maskNow == SOURCES.SteamMask,
	"steam_fill: SteamMask is neither the original nor this round's (someone changed it): merge by hand (nothing was written)")
-- the new modules are anchors too: a same-named module that isn't ours stops the install before anything is written
if not UNDO then
	for _, pair in { { Shared, "SteamCloud" }, { Controllers, "SteamCloudController" } } do
		local m = pair[1]:FindFirstChild(pair[2])
		assert(not m or m:GetAttribute("SteamFillInstall") ~= nil,
			"steam_fill: a " .. pair[2] .. " that isn't ours is already in " .. pair[1]:GetFullName() .. " (nothing was written)")
	end
end
-- every edited source still parses
local compile = loadstring
if compile then
	for inst, s in sources do
		local f, err = compile(s)
		assert(f, "steam_fill: " .. inst.Name .. " would not parse: " .. tostring(err) .. " (nothing was written)")
	end
	for _, k in { "SteamMask", "SteamCloud", "SteamCloudController" } do
		local f, err = compile(SOURCES[k])
		assert(f, "steam_fill: " .. k .. " does not parse: " .. tostring(err))
	end
end

-- // Pass 2: write ----------------------------------------------------------------------------------------------------------------------
-- stamp first: if a write below is interrupted, the next run (install or UNDO) still recognises this round's own text
if not UNDO then SM:SetAttribute("SteamFillRound", ROUND) end
for inst, s in sources do if norm(inst.Source) ~= s then inst.Source = s end end
if maskNow ~= maskWant then Shared.SteamMask.Source = maskWant end
table.insert(out, "mask" .. (maskNow == maskWant and "=" or "+"))
local function module(parent: Instance, name: string, source: string)
	local m = parent:FindFirstChild(name)
	if UNDO then
		if m and m:GetAttribute("SteamFillInstall") then m:Destroy() table.insert(out, name .. "-") else table.insert(out, name .. "=") end
		return
	end
	if m and norm(m.Source) == source then table.insert(out, name .. "=") return end
	if not m then
		m = Instance.new("ModuleScript")
		m.Name = name
		m:SetAttribute("SteamFillInstall", ROUND)
		m.Source = source
		m.Parent = parent
	else
		m.Source = source
	end
	table.insert(out, name .. "+")
end
module(Shared, "SteamCloud", SOURCES.SteamCloud)
module(Controllers, "SteamCloudController", SOURCES.SteamCloudController)
if UNDO then SM:SetAttribute("SteamFillRound", nil) end
return ("STEAMFILL round %d %s: %s | hash %s -> %s"):format(ROUND, UNDO and "UNDO" or "install", table.concat(out, " "), before, hash())
