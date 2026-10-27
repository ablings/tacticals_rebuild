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
