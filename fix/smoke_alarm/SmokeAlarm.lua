-- ReplicatedStorage/Modules/Shared/SmokeAlarm (ModuleScript) [SMOKEALARM] 2026-10-28 (fix/smoke_alarm.lua, notes/smoke_alarm.md)
-- Shootable ceiling smoke alarms (Edward: "a smoke alarm that can be shot out, maybe two of them, that do a light beep; shooting
-- it out will also muddy footsteps like the warehouse map"). One module for the server (ShootableManager in the match places,
-- ArenaShootables in lobby pad duels) and the clients (SmokeAlarmController in the match places, ArenaLoader in the lobby).
--
-- An alarm = a model with the attribute Shootable = "SmokeAlarm" (normally Shootables.<SmokeAlarm_*>) holding
--   Base   the ceiling plate (its top face sits on the ceiling)
--   Cover  the white housing under it (hangs open when the alarm is broken)
--   Led    the small red light (blinks with every chirp, flashes while it blares, dark once broken)
-- Server state, as attributes on the model the server owns (it replicates; in a lobby duel that's the Solid twin):
--   AlarmPos (Vector3, where it is: the mask's centre), ChirpAt (server time of the last low-battery chirp),
--   AlarmBroken (bool), BlareAt / BlareUntil (server time it was shot / stops blaring). No remotes.
-- While it blares, footsteps and reloads within Config.MaskRadius on its floor are masked for players and the AI, exactly the
-- way a steam valve masks them (SteamMask.IsMasked / Muffled ask SmokeAlarm.Blaring / Muffles). Gunshots, breaks, blasts and
-- fire never ask. Then it's broken and silent until the round resets.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local SmokeAlarm = {}
SmokeAlarm.KIND = "SmokeAlarm"
SmokeAlarm.TAG = "SmokeAlarm" -- the server tags the model that carries the state (match places: the map's; lobby: the Solid twin)

local FLAT = Vector3.new(1, 0, 1)
local DEFAULTS = {
	Enabled = true,            -- false: alarms are plain props (no chirp, can't be shot out)
	ChirpMin = 25,             -- seconds between low-battery chirps (random per alarm, every gap)
	ChirpMax = 40,
	FirstChirpMin = 4,         -- the first chirp of a round comes this soon at the earliest
	ChirpVolume = 0.16,        -- quiet: a location cue, not an annoyance
	ChirpPitch = 2.9,          -- a high, short chirp
	ChirpLength = 0.14,        -- seconds of the beep file played (it is 2.1 s long: a chirp is a pip)
	ChirpRollOff = { 3, 45 },  -- studs: full volume within 3, silent past 45 (InverseTapered)
	BlareTime = 7,             -- seconds it blares once shot
	BlareVolume = 0.75,
	BlarePitch = 2.2,
	BlareRollOff = { 10, 130 },
	BlareOn = 0.42,            -- the blare pattern (a real alarm's "temporal three"): 3 x (on, off), then a pause
	BlareOff = 0.12,
	BlarePause = 0.55,
	MaskRadius = 28,           -- studs (flat) around the alarm where footsteps / reloads are masked while it blares
	MaskBelow = 16,            -- ... from this far below the alarm (its floor) ...
	MaskAbove = 2,             -- ... to this far above it (not the floor upstairs)
	ListenerInBlare = true,    -- standing in the blare you can't hear people either (the steam's ListenerInSteam rule)
	HitPadding = 0.3,          -- studs added around the parts for the bullet test
	MeleeReach = 1.5,          -- a swing reaches the alarm this much further than a body
	BlastScale = 1,            -- a blast breaks alarms within its Radius x this, with no wall in between
	SoundId = "rbxassetid://9117197553", -- the beep the gadgets already use live
	LedOn = Color3.fromRGB(255, 45, 35),
	LedOff = Color3.fromRGB(70, 14, 12),
}
local config
function SmokeAlarm.Config()
	if config then return config end
	local merged = table.clone(DEFAULTS)
	local ok, shootable = pcall(function() return require(script.Parent.Config.ShootableConfig) end)
	local own = ok and type(shootable) == "table" and shootable.SmokeAlarm
	if type(own) == "table" then for k, v in own do merged[k] = v end end
	config = merged
	return config
end

local function serverNow(): number return workspace:GetServerTimeNow() end

-- // The mask ---------------------------------------------------------------------------------------------------------------------
-- Is this position inside the blare of one alarm (its floor, within MaskRadius) right now?
function SmokeAlarm.InBlare(alarm: Instance, position: Vector3, now: number?): boolean
	local untilT = alarm:GetAttribute("BlareUntil")
	if type(untilT) ~= "number" or untilT <= (now or serverNow()) then return false end
	local at = alarm:GetAttribute("AlarmPos")
	if typeof(at) ~= "Vector3" then return false end
	local cfg = SmokeAlarm.Config()
	local dy = position.Y - at.Y
	if dy < -cfg.MaskBelow or dy > cfg.MaskAbove then return false end
	return ((position - at) * FLAT).Magnitude <= cfg.MaskRadius
end

-- Is a quiet sound (a footstep, a reload) at this position drowned out by a blaring alarm? SteamMask.IsMasked asks this.
function SmokeAlarm.Blaring(position: Vector3, now: number?): boolean
	if typeof(position) ~= "Vector3" then return false end
	local cfg = SmokeAlarm.Config()
	if cfg.Enabled == false then return false end
	now = now or serverNow()
	for _, alarm in CollectionService:GetTagged(SmokeAlarm.TAG) do
		if SmokeAlarm.InBlare(alarm, position, now) then return true end
	end
	return false
end

-- The steam's footstep rule for the alarm: lost when the source is in the blare, or the listener is (ListenerInBlare).
-- SteamMask.FillMuffled asks this (match places: players hear it muffled and very faint, the AI not at all); with no
-- listener given on a client, the local character is the listener.
function SmokeAlarm.Muffles(source: Vector3, listener: Vector3?, now: number?): boolean
	now = now or serverNow()
	if SmokeAlarm.Blaring(source, now) then return true end
	if SmokeAlarm.Config().ListenerInBlare == false then return false end
	if listener == nil and RunService:IsClient() then
		local me = game:GetService("Players").LocalPlayer
		local root = me and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		listener = root and root.Position
	end
	return listener ~= nil and SmokeAlarm.Blaring(listener, now)
end

-- // Server ---------------------------------------------------------------------------------------------------------------------------
-- Does segment a->b pass through the box? (t = where along a->b it enters, 0..1)
local function segmentHitsBox(a: Vector3, b: Vector3, cf: CFrame, size: Vector3, pad: number): (boolean, number)
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local d = lb - la
	local tmin, tmax = 0, 1
	local half = size / 2 + Vector3.one * pad
	for _, axis in { "X", "Y", "Z" } do
		local o, v, h = la[axis], d[axis], half[axis]
		if math.abs(v) < 1e-6 then
			if o < -h or o > h then return false, 0 end
		else
			local t1, t2 = (-h - o) / v, (h - o) / v
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return false, 0 end
		end
	end
	return true, tmin
end
SmokeAlarm.SegmentHitsBox = segmentHitsBox

-- Is this model an alarm? (attribute Shootable = "SmokeAlarm", or the name as a fallback, like the valves)
function SmokeAlarm.IsAlarm(model: Instance): boolean
	return model:GetAttribute("Shootable") == SmokeAlarm.KIND or (model:IsA("Model") and model.Name:find("SmokeAlarm") == 1)
end

local Set = {}
Set.__index = Set

-- SmokeAlarm.Server(models, wallBetween?) -> set. One set per map (match places) or per lobby arena (ArenaShootables).
-- wallBetween(a, b) -> bool: a wall between a blast and the alarm (the caller's own map walls).
function SmokeAlarm.Server(models: { Instance }, wallBetween: ((Vector3, Vector3) -> boolean)?)
	local self = setmetatable({ alarms = {}, wallBetween = wallBetween, dead = false }, Set)
	for _, model in models do
		local parts = {}
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then table.insert(parts, p) end end
		if #parts > 0 then
			local pos = model:IsA("Model") and model:GetPivot().Position or parts[1].Position
			local base = model:FindFirstChild("Base")
			if base and base:IsA("BasePart") then pos = base.Position end
			model:SetAttribute("AlarmPos", pos)
			CollectionService:AddTag(model, SmokeAlarm.TAG)
			table.insert(self.alarms, { model = model, parts = parts, pos = pos, broken = false, nextChirp = 0 })
		end
	end
	self:Reset()
	if #self.alarms > 0 then
		local acc = 0
		self.conn = RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc < 0.25 then return end
			acc = 0
			self:Step()
		end)
	end
	return self
end

function Set:Count(): number return #self.alarms end

-- the low-battery chirp: every ChirpMin..ChirpMax seconds per alarm while it isn't broken (clients play it from ChirpAt)
function Set:Step()
	if self.dead then return end
	local cfg = SmokeAlarm.Config()
	if cfg.Enabled == false then return end
	local clock = os.clock()
	for _, a in self.alarms do
		if not a.broken and a.model.Parent and clock >= a.nextChirp then
			a.model:SetAttribute("ChirpAt", serverNow())
			a.nextChirp = clock + cfg.ChirpMin + math.random() * (cfg.ChirpMax - cfg.ChirpMin)
		end
	end
end

function Set:Break(a, cause: string?)
	local cfg = SmokeAlarm.Config()
	if self.dead or a.broken or cfg.Enabled == false then return false end
	a.broken = true
	local t = serverNow()
	a.model:SetAttribute("BlareAt", t) -- BlareAt first: no client sees a new BlareUntil alone
	a.model:SetAttribute("BlareUntil", t + cfg.BlareTime)
	a.model:SetAttribute("AlarmCause", cause or "Bullet")
	a.model:SetAttribute("AlarmBroken", true)
	return true
end

-- a bullet from origin to endPos (already stopped at the first wall by the caller): the first alarm it passes breaks.
-- Returns the alarm's model and where along the segment it was hit (0..1), or nil.
function Set:Hit(origin: Vector3, endPos: Vector3): (Instance?, number?)
	if self.dead or typeof(origin) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return nil, nil end
	local pad = SmokeAlarm.Config().HitPadding
	local best, bestT = nil, math.huge
	for _, a in self.alarms do
		if not a.broken then
			for _, p in a.parts do
				local hit, t = segmentHitsBox(origin, endPos, p.CFrame, p.Size, pad)
				if hit and t < bestT then best, bestT = a, t end
			end
		end
	end
	if best and self:Break(best, "Bullet") then return best.model, bestT end
	return nil, nil
end

-- a melee swing (MeleeManager -> OnMelee, after its wind-up re-checks): origin = the attacker's root, look = flat facing,
-- reach / angle = the weapon's. The alarm breaks when its nearest point is within reach + MeleeReach of the head and inside
-- the swing's angle (or straight overhead). A ceiling alarm is normally out of a knife's reach: you have to shoot it.
function Set:Melee(origin: Vector3, look: Vector3, reach: number, angle: number?): Instance?
	if self.dead or typeof(origin) ~= "Vector3" or typeof(look) ~= "Vector3" or type(reach) ~= "number" then return nil end
	local cfg = SmokeAlarm.Config()
	local head = origin + Vector3.new(0, 1.5, 0)
	local flatLook = look * FLAT
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else nil
	local half = math.rad((angle or 70) / 2)
	for _, a in self.alarms do
		if not a.broken then
			for _, p in a.parts do
				local lp = p.CFrame:PointToObjectSpace(head)
				local h = p.Size / 2
				local near = p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z)))
				if (near - head).Magnitude <= reach + cfg.MeleeReach then
					local off = (near - head) * FLAT
					local ok = off.Magnitude < 1.5 or (flatLook ~= nil and math.acos(math.clamp(off.Unit:Dot(flatLook), -1, 1)) <= half)
					if ok and self:Break(a, "Melee") then return a.model end
				end
			end
		end
	end
	return nil
end

-- a blast at `position` with radius `radius`: every alarm within radius x BlastScale with no wall in between breaks
function Set:Blast(position: Vector3, radius: number): number
	if self.dead or typeof(position) ~= "Vector3" or type(radius) ~= "number" then return 0 end
	local r = radius * SmokeAlarm.Config().BlastScale
	local n = 0
	for _, a in self.alarms do
		if not a.broken and (a.pos - position).Magnitude <= r then
			-- aim just below the alarm: a ray ending on its own ceiling isn't a wall between them
			local target = a.pos - Vector3.new(0, 0.6, 0)
			if not (self.wallBetween and self.wallBetween(position + Vector3.new(0, 1, 0), target)) then
				if self:Break(a, "Blast") then n += 1 end
			end
		end
	end
	return n
end

-- new round: every alarm whole, quiet, chirping again (first chirp at a random time, so the alarms never chirp together)
function Set:Reset()
	local cfg = SmokeAlarm.Config()
	local clock = os.clock()
	for _, a in self.alarms do
		a.broken = false
		a.nextChirp = clock + cfg.FirstChirpMin + math.random() * (cfg.ChirpMax - cfg.FirstChirpMin)
		for _, k in { "AlarmBroken", "BlareAt", "BlareUntil", "AlarmCause", "ChirpAt" } do a.model:SetAttribute(k, nil) end
	end
end

function Set:Destroy()
	self.dead = true
	if self.conn then self.conn:Disconnect() end
	for _, a in self.alarms do
		for _, k in { "AlarmBroken", "BlareAt", "BlareUntil", "AlarmCause", "ChirpAt" } do a.model:SetAttribute(k, nil) end
		CollectionService:RemoveTag(a.model, SmokeAlarm.TAG)
	end
end

-- // Client: the look and the sounds -----------------------------------------------------------------------------------------------
-- SmokeAlarm.BindClient(state, look) -> { RBXScriptConnection }: `state` carries the server's attributes, `look` is what this
-- client draws (match places: the same model; lobby duels: the Visual twin of the Solid model). Everything here is local.
function SmokeAlarm.BindClient(state: Instance, look: Instance)
	local cfg = SmokeAlarm.Config()
	local conns = {}
	local base = look:FindFirstChild("Base")
	local cover = look:FindFirstChild("Cover")
	local led = look:FindFirstChild("Led")
	if not (base and base:IsA("BasePart")) then return conns end
	local coverCF = cover and cover:IsA("BasePart") and cover.CFrame
	local ledMat = led and led:IsA("BasePart") and led.Material
	local light = led and led:FindFirstChildOfClass("PointLight")

	local att = Instance.new("Attachment")
	att.Name = "AlarmSound"
	att.Parent = base -- parent first: an Attachment's world values are relative until it has a parent
	att.WorldPosition = base.Position
	local function sound(name: string, vol: number, pitch: number, roll)
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = cfg.SoundId
		s.Volume = vol
		s.PlaybackSpeed = pitch
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = roll[1]
		s.RollOffMaxDistance = roll[2]
		s.Parent = att
		return s
	end
	local chirp = sound("Chirp", cfg.ChirpVolume, cfg.ChirpPitch, cfg.ChirpRollOff)
	local blare = sound("Blare", cfg.BlareVolume, cfg.BlarePitch, cfg.BlareRollOff)
	blare.Looped = true

	local function setLed(on: boolean)
		if not (led and led:IsA("BasePart")) then return end
		led.Color = on and cfg.LedOn or cfg.LedOff
		led.Material = on and Enum.Material.Neon or (ledMat or Enum.Material.SmoothPlastic)
		if light then light.Enabled = on end
	end
	-- the housing (Cover and every part named Cover*, plus the Led on it) hangs open from one top edge, hinged on the plate and
	-- tipped 28 degrees down (world space: any part shape)
	local moving = {} -- [part] = { closed CFrame, hanging CFrame }
	if cover and coverCF then
		local function axis(v: Vector3) return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) end
		local s = cover.Size
		local ext = axis(coverCF.RightVector) * s.X + axis(coverCF.UpVector) * s.Y + axis(coverCF.LookVector) * s.Z
		local hinge = coverCF.Position + Vector3.new(ext.X / 2, ext.Y / 2, 0)
		local swing = CFrame.new(hinge) * CFrame.Angles(0, 0, math.rad(28)) * CFrame.new(-hinge)
		for _, p in look:GetChildren() do
			if p:IsA("BasePart") and (p.Name:sub(1, 5) == "Cover" or p == led) then moving[p] = { p.CFrame, swing * p.CFrame } end
		end
	end
	local function setBroken(broken: boolean)
		for p, cfs in moving do p.CFrame = if broken then cfs[2] else cfs[1] end
	end

	local token = {}
	local function blink(seconds: number)
		local t = {}
		token = t
		setLed(true)
		task.delay(seconds, function() if token == t then setLed(false) end end)
	end

	-- the chirp: only a fresh one (a late joiner doesn't hear an old ChirpAt)
	table.insert(conns, state:GetAttributeChangedSignal("ChirpAt"):Connect(function()
		local at = state:GetAttribute("ChirpAt")
		if type(at) ~= "number" or serverNow() - at > 1 or state:GetAttribute("AlarmBroken") then return end
		chirp.TimePosition = 0
		chirp:Play()
		blink(0.18)
		local t = token
		task.delay(cfg.ChirpLength, function() if token == t then chirp:Stop() end end)
	end))

	local runToken
	local function apply()
		local broken = state:GetAttribute("AlarmBroken") == true
		local untilT = state:GetAttribute("BlareUntil")
		local left = type(untilT) == "number" and (untilT - serverNow()) or 0
		setBroken(broken)
		local mine = {}
		runToken = mine
		if not broken then
			blare:Stop()
			token = {}
			setLed(false)
			return
		end
		if left <= 0 then
			blare:Stop()
			token = {}
			setLed(false) -- broken and silent for the rest of the round
			return
		end
		-- a fresh break: a short burst of sparks from the housing
		local at = state:GetAttribute("BlareAt")
		if type(at) == "number" and serverNow() - at < 0.6 then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160))
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.12, 0)
			e.Lifetime = NumberRange.new(0.2, 0.45)
			e.Speed = NumberRange.new(6, 12)
			e.SpreadAngle = Vector2.new(70, 70)
			e.Acceleration = Vector3.new(0, -30, 0)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Rate = 0
			e.Parent = base
			e:Emit(14)
			Debris:AddItem(e, 1)
		end
		-- the blare: three long tones, a pause, again, until BlareUntil; the LED flashes with it
		task.spawn(function()
			while runToken == mine do
				for _ = 1, 3 do
					if runToken ~= mine or serverNow() >= untilT then break end
					blare.TimePosition = 0
					blare:Play()
					setLed(true)
					task.wait(cfg.BlareOn)
					blare:Stop()
					setLed(false)
					task.wait(cfg.BlareOff)
				end
				if runToken ~= mine or serverNow() >= untilT then break end
				task.wait(cfg.BlarePause)
			end
			if runToken == mine then
				blare:Stop()
				setLed(false)
			end
		end)
	end
	table.insert(conns, state:GetAttributeChangedSignal("AlarmBroken"):Connect(apply))
	table.insert(conns, state:GetAttributeChangedSignal("BlareUntil"):Connect(apply))
	apply()
	-- unbinding (the arena unloads / the model goes): the sounds go with it
	table.insert(conns, { Disconnect = function()
		runToken = {}
		token = {}
		if att.Parent then att:Destroy() end
		setBroken(false)
	end } :: any)
	return conns
end

return SmokeAlarm
