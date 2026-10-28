-- fix/lobby_steam_fill.lua [LOBBYSTEAM] 2026-10-28, round 1 (live port 45: Warehouse 2 in the lobby's pad duels).
-- The match places' steam fill ([STEAMFILL] round 5, fix/steam_fill.lua) for LOBBY PAD DUELS: a valve on a map whose model carries
-- SteamFill = true (Warehouse 2) steams the room up in the duel slot too. Lobby (Tacticals_rebuild.rbxl) only, Edit mode.
-- Built by tools/lobby_steam_fill_build.py (embeds fix/steam_fill/{SteamMask,SteamCloud,ShootableConfig_Fill}.lua: the SAME
-- shared sources as the match places, so both games draw and mask the same cloud).
--   replaces  ReplicatedStorage.Modules.Shared.SteamMask   (classic path: same maths as the original; fill path added)
--   adds      ReplicatedStorage.Modules.Shared.SteamCloud  (client: the cloud)
--   edits     ShootableConfig (Steam.Fill block), FootstepController (steps muffled in the steam, as in the match places),
--             ServerScriptService.Shared.ArenaShootables: valves tagged SteamValve (lobby valves never masked noise before),
--               SteamAt + the fill duration on a shot, SteamAt cleared on a new round, ScriptOnly doors get no Open prompt;
--             StarterPlayerScripts.ArenaLoader: the cloud bound on the Solid valve of a fill map (SteamCloud.Bind), the jet's
--               attachment parented before its WorldCFrame (it drew far off), ScriptOnly doors left as built.
-- Not ported (lobby has no such code path): the AI's steam blindness (BotManager edits of the match places).
-- Idempotent (second run: every line "="); checks EVERY anchor in every target before writing anything (each must match once);
-- stamps the round on ArenaShootables (LobbySteamFillRound) BEFORE the first write and refuses any other round; UNDO = true puts
-- every edit back and removes SteamCloud (installed by this script only). Prints a state hash before / after.
local UNDO = false --@UNDO
local ROUND = 1
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
-- people"). FootstepController asks this for every step it plays. Fill clouds (SteamMask.FillMuffled): when the walker or you
-- stand in the steam, or enough steam lies between you, the step is muffled (an EqualizerSoundEffect on that Sound cuts the crisp highs) and very faint (Fill.Footsteps.Volume; your own:
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
	if cfg then inSteam = SteamMask.FillMuffled(source, ear()) end -- the one rule the AI uses too
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
			-- round 3 (Edward 2026-10-27): the AI is blinded by the steam, and footsteps in, near or through it are muddied to very faint
			Sight = {
				BlindDepth = 6,      -- studs of steam a bot's sight line may cross before it can't see (a player 6+ studs into the haze is hidden)
				CoreRadius = 9,      -- studs around the cloud's centre that count as the thick core
				CoreWeight = 3,      -- a stud of core counts this much (the valve corner blinds after 2 studs)
				Step = 0.5,          -- studs between samples along the line (only the wall fan and the height band are sampled)
			},
			Footsteps = {
				ListenerInSteam = true, -- standing in the steam you can't hear people either (false: only steps IN or THROUGH it)
				ThroughDepth = 6,    -- steps on the far side of this much steam (weighted like Sight; works without it) are muffled too (0 = off)
				Volume = 0.06,       -- other people's muffled steps: x this (very faint; you can't place them)
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
--@@END SOURCES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

assert(workspace:FindFirstChild("LobbyMap") ~= nil and ServerScriptService:FindFirstChild("ArenaShootables", true) ~= nil,
	"lobby_steam_fill: not the lobby (no LobbyMap / ArenaShootables): the match places take fix/steam_fill.lua")
local Shared = ReplicatedStorage.Modules.Shared
local Cfg = Shared.Config
local AS = ServerScriptService.Shared.ArenaShootables
local AL = StarterPlayer.StarterPlayerScripts.ArenaLoader
local FC = StarterPlayer.StarterPlayerScripts.Client.Controllers.FootstepController

do
	local stamp = AS:GetAttribute("LobbySteamFillRound")
	assert(stamp == nil or stamp == ROUND, "lobby_steam_fill round " .. tostring(stamp) .. " is installed: UNDO it with that round's fix first")
	assert(stamp == ROUND or not AS.Source:find("[LOBBYSTEAM]", 1, true),
		"an unstamped [LOBBYSTEAM] edit is in ArenaShootables: UNDO it with the installer that wrote it first")
end

local function norm(s: string): string return (s:gsub("\r\n", "\n")) end
local function hash(): string
	local h = 2166136261
	local parts = { Shared.SteamMask.Source, Cfg.ShootableConfig.Source, AS.Source, AL.Source, FC.Source, tostring(Shared:FindFirstChild("SteamCloud") ~= nil) }
	for _, s in parts do
		s = norm(s)
		for i = 1, #s do h = bit32.bxor(h, s:byte(i)); h = (h * 16777619) % 4294967296 end
	end
	return string.format("%08x", h)
end
local before = hash()

-- the original SteamMask (= the match places' before [STEAMFILL]; restored by UNDO)
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

local edits = {}
local function edit(inst, old, new) table.insert(edits, { inst, old, new }) end

-- ShootableConfig: the Fill block inside Steam (same block as the match places)
local HIT_PAD = "\t\tHitPadding = 0.35,  -- forgiving hitbox (studs added around the valve)\n"
edit(Cfg.ShootableConfig, HIT_PAD .. "\t},\n", HIT_PAD .. SOURCES.FillBlock .. "\t},\n")

-- FootstepController (same edit as the match places)
edit(FC, "local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n",
	"local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n"
	.. "local SteamCloud = require(Shared:WaitForChild(\"SteamCloud\")) -- [STEAMFILL] round 3: footsteps muffled in the steam\n")
edit(FC, "\t\t\t\t\t-- a hissing steam valve nearby drowns out other people's footsteps\n"
	.. "\t\t\t\t\tif character ~= me and SteamMask.IsMasked(position) then volume *= 0.04 end\n",
	"\t\t\t\t\t-- [STEAMFILL] round 3: steam drowns footsteps. Classic jet: other people's x0.04 in its mask (as before). A fill cloud:\n"
	.. "\t\t\t\t\t-- muffled and very faint when the walker or you stand in it, or it lies between you (SteamCloud.FootstepScale)\n"
	.. "\t\t\t\t\tvolume *= SteamCloud.FootstepScale(s, position, character == me)\n")

-- ArenaShootables (server)
edit(AS, "local MatchState = require(Shared.MatchState)\n",
	"local MatchState = require(Shared.MatchState)\n"
	.. "local SteamMask = require(Shared.SteamMask) -- [LOBBYSTEAM] fill maps: the valve steams the room up (match places' [STEAMFILL])\n"
	.. "local CollectionService = game:GetService(\"CollectionService\")\n")
edit(AS, "\t\tlocal shutter = model:FindFirstChild(\"Shutter\")\n\t\tif shutter and shutter:IsA(\"BasePart\") then\n",
	"\t\tlocal shutter = model:FindFirstChild(\"Shutter\")\n"
	.. "\t\t-- [LOBBYSTEAM] a ScriptOnly door (Warehouse 2's roll-up doors) stays shut: no prompt, never moved here\n"
	.. "\t\tif shutter and shutter:IsA(\"BasePart\") and model:GetAttribute(\"ScriptOnly\") ~= true then\n")
edit(AS, "\t\t\tif #parts > 0 then table.insert(self.valves, { model = model, parts = parts, used = false }) end\n",
	"\t\t\tif #parts > 0 then\n"
	.. "\t\t\t\tCollectionService:AddTag(model, \"SteamValve\") -- [LOBBYSTEAM] SteamMask finds it (footsteps; lobby valves never masked before)\n"
	.. "\t\t\t\ttable.insert(self.valves, { model = model, parts = parts, used = false })\n"
	.. "\t\t\tend\n")
edit(AS, "\tv.used = true\n\tv.model:SetAttribute(\"SteamUntil\", now() + Config.Steam.Duration)\n",
	"\tv.used = true\n"
	.. "\t-- [LOBBYSTEAM] SteamAt first (the clients draw the cloud from SteamAt / SteamUntil); a fill map hisses for Fill.Duration\n"
	.. "\tlocal fill = SteamMask.FillOf(v.model)\n"
	.. "\tlocal startT = now()\n"
	.. "\tv.model:SetAttribute(\"SteamAt\", startT)\n"
	.. "\tv.model:SetAttribute(\"SteamUntil\", startT + (if fill and fill.Duration then fill.Duration else Config.Steam.Duration))\n")
edit(AS, "\t\tv.used = false\n\t\tv.model:SetAttribute(\"SteamUntil\", nil)\n",
	"\t\tv.used = false\n\t\tv.model:SetAttribute(\"SteamUntil\", nil)\n"
	.. "\t\tv.model:SetAttribute(\"SteamAt\", nil) -- [LOBBYSTEAM] the clients drop the cloud at once\n")

-- ArenaLoader (client)
edit(AL, "local MapRegistry = require(Shared:WaitForChild(\"MapRegistry\"))\n",
	"local MapRegistry = require(Shared:WaitForChild(\"MapRegistry\"))\n"
	.. "local SteamMask = require(Shared:WaitForChild(\"SteamMask\")) -- [LOBBYSTEAM] fill maps: the cloud (match places' [STEAMFILL])\n"
	.. "local SteamCloud = require(Shared:WaitForChild(\"SteamCloud\"))\n")
edit(AL, "\tlocal shutter = visModel:FindFirstChild(\"Shutter\")\n\tif not (shutter and shutter:IsA(\"BasePart\")) then return end\n",
	"\tlocal shutter = visModel:FindFirstChild(\"Shutter\")\n"
	.. "\tif not (shutter and shutter:IsA(\"BasePart\")) or solidModel:GetAttribute(\"ScriptOnly\") == true then return end -- [LOBBYSTEAM] ScriptOnly: shut, as built\n")
edit(AL, "\tatt.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)\n\tatt.Parent = body\n",
	"\tatt.Parent = body -- [LOBBYSTEAM] parent first: a loose attachment's WorldCFrame is taken as relative (the jet drew far off)\n"
	.. "\tatt.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)\n")
edit(AL, "\ttable.insert(conns, solidModel:GetAttributeChangedSignal(\"SteamUntil\"):Connect(apply))\n\tapply()\nend\n",
	"\ttable.insert(conns, solidModel:GetAttributeChangedSignal(\"SteamUntil\"):Connect(apply))\n\tapply()\n"
	.. "\t-- [LOBBYSTEAM] a fill map: the cloud follows the server's Solid valve (it carries SteamAt / SteamUntil and sits in the map's\n"
	.. "\t-- Solid collision, which stops the steam at the walls); unload disconnects it with the rest\n"
	.. "\tif SteamMask.FillOf(solidModel) then\n"
	.. "\t\tlocal handle = SteamCloud.Bind(solidModel)\n"
	.. "\t\ttable.insert(conns, { Disconnect = function() handle:Destroy() end })\n"
	.. "\tend\n"
	.. "end\n")

-- // Pass 1: check every anchor (each exactly once, at a line start) before writing anything --------------------------------------
local function count(hay: string, needle: string): number
	local n, i = 0, 1
	while true do
		local a, b = hay:find(needle, i, true)
		if not a then return n end
		if a == 1 or hay:sub(a - 1, a - 1) == "\n" then n += 1 end
		i = b + 1
	end
end
local sources = {}
for _, e in edits do
	local inst, old, new = e[1], e[2], e[3]
	local s = sources[inst] or norm(inst.Source)
	local from, to = old, new
	if UNDO then from, to = new, old end
	local nFrom, nTo = count(s, from), count(s, to)
	if nFrom == 1 and (nTo == 0 or from:find(to, 1, true)) then -- (UNDO of an insertion: the old text sits inside the new)
		local a, b = s:find(from, 1, true)
		s = s:sub(1, a - 1) .. to .. s:sub(b + 1)
		e.state = "+"
	elseif nTo == 1 and nFrom == 0 then
		e.state = "="
	elseif nTo >= 1 and nFrom >= 1 and to:find(from, 1, true) then
		e.state = "=" -- the new text contains the old (an insertion): already done
	else
		error(("lobby_steam_fill: anchor in %s matched %d / %d times (nothing was written): %s"):format(inst.Name, nFrom, nTo, from:sub(1, 80)))
	end
	sources[inst] = s
end
local maskNow = norm(Shared.SteamMask.Source)
local maskWant = UNDO and MASK_ORIG or SOURCES.SteamMask
assert(maskNow == MASK_ORIG or maskNow == SOURCES.SteamMask,
	"lobby_steam_fill: SteamMask is neither the original nor the shared fill version: merge by hand (nothing was written)")
if not UNDO then
	local m = Shared:FindFirstChild("SteamCloud")
	assert(not m or m:GetAttribute("SteamFillInstall") ~= nil, "lobby_steam_fill: a SteamCloud that isn't ours is in Shared (nothing was written)")
end
local compile = loadstring
if compile then
	for inst, s in sources do
		local f, err = compile(s)
		assert(f, "lobby_steam_fill: " .. inst.Name .. " would not parse: " .. tostring(err) .. " (nothing was written)")
	end
	for _, k in { "SteamMask", "SteamCloud" } do
		local f, err = compile(SOURCES[k])
		assert(f, "lobby_steam_fill: " .. k .. " does not parse: " .. tostring(err))
	end
end

-- // Pass 2: write (stamp first) -----------------------------------------------------------------------------------------------------
if not UNDO then AS:SetAttribute("LobbySteamFillRound", ROUND) end
local out = {}
for inst, s in sources do if norm(inst.Source) ~= s then inst.Source = s end end
for _, e in edits do table.insert(out, e[1].Name .. e.state) end
if maskNow ~= maskWant then Shared.SteamMask.Source = maskWant end
table.insert(out, "mask" .. (maskNow == maskWant and "=" or "+"))
local m = Shared:FindFirstChild("SteamCloud")
if UNDO then
	if m and m:GetAttribute("SteamFillInstall") then m:Destroy() table.insert(out, "SteamCloud-") else table.insert(out, "SteamCloud=") end
	AS:SetAttribute("LobbySteamFillRound", nil)
elseif m and norm(m.Source) == SOURCES.SteamCloud then
	table.insert(out, "SteamCloud=")
else
	if not m then
		m = Instance.new("ModuleScript")
		m.Name = "SteamCloud"
		m:SetAttribute("SteamFillInstall", "lobby" .. ROUND)
		m.Source = SOURCES.SteamCloud
		m.Parent = Shared
	else
		m.Source = SOURCES.SteamCloud
	end
	table.insert(out, "SteamCloud+")
end
return ("LOBBYSTEAM round %d %s: %s | hash %s -> %s"):format(ROUND, UNDO and "UNDO" or "install", table.concat(out, " "), before, hash())
