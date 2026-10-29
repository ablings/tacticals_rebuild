-- fix/smoke_alarm.lua [SMOKEALARM] 2026-10-28, round 3 (rounds 1-2 only ever ran on the test copies: UNDO them with
-- `git show 5fe0db6:fix/smoke_alarm.lua` / `git show 4b7a81f:fix/smoke_alarm.lua` first). Work order (Lead plan, approved by Edward): "a smoke alarm that can be shot
-- out, maybe two of them, that do a light beep; shooting it out will also muddy footsteps like the warehouse map". Notes:
-- notes/smoke_alarm.md. Built by tools/smoke_alarm_build.py (embeds fix/smoke_alarm/*.lua below). Edit mode.
-- ONE installer for both kinds of place (it finds out which it is in). Needs breakable glass round 1 first (it anchors beside its
-- text; on a match place steam fill round 5 too):
--   MATCH places (Matchmaking / Ranked / the combined match place)
--     adds   Shared.SmokeAlarm (the rules, server state, client look), Client.Controllers.SmokeAlarmController
--     edits  ShootableConfig (SmokeAlarm block), SteamMask (IsMasked + FillMuffled ask SmokeAlarm: footsteps / reloads in a blare
--            are masked for players and the AI, the steam's way), ShootableManager (the placed maps' alarms: shots, blasts, melee,
--            ResetAll; Studio-only ServerStorage.SmokeAlarmTestHook)
--   HUB (lobby pad duels)
--     adds   Shared.SmokeAlarm
--     edits  ShootableConfig, SteamMask (IsMasked), FootstepController (you in a blare can't hear people either),
--            ArenaShootables (per arena: OnShot / Explode / OnMelee / ResetAll / Destroy), ArenaLoader (the Visual twin follows)
--   both   places the two alarms (SmokeAlarm_G on the ground-floor ceiling, SmokeAlarm_U on the upper one, both at the house's plan
--          centre: notes/smoke_alarm.md) into Workspace.House.Shootables and into the lobby's House duel source
--          (ServerStorage._DuelSource.House) when present. No House in the place: nothing at all is written.
-- Every edit sits BESIDE the glass / steam installers' inserted text (never inside it), so theirs still re-run and UNDO. Exception:
-- SteamMask is a whole-module check in fix/steam_fill.lua: re-running steam fill needs this UNDOne first.
-- Idempotent (second run: every line "="); checks EVERY anchor in every target, and the new module names, before writing anything;
-- stamps SmokeAlarmRound on ShootableManager BEFORE the first write and refuses any other round; UNDO (UNDO = true, or
-- tools/smoke_alarm_build.py --run <id> UNDO) puts every edit back, removes the new modules and the placed alarms.
-- Prints a state hash before / after: UNDO returns to the "before" hash. DRY = true checks everything and writes nothing.
local UNDO = false --@UNDO
local DRY = false --@DRY
local ROUND = 3
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.SmokeAlarm = [=[
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
	MeleeReach = 0,            -- extra reach on top of the weapon's (0: a knife from the floor never reaches a ceiling alarm)
	BlastScale = 1.25,         -- a blast breaks alarms within its Radius x this, with no wall in between (1.25: a frag lying on
	                           -- the floor under a 12-13 stud ceiling reaches it; at 1 only mid-air blasts did)
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

-- SmokeAlarm.Server(models, opts?) -> set. One set per map (match places) or per lobby arena (ArenaShootables).
--   opts.geometry: { Instance } or () -> { Instance }: the map's collision (what a swing or a blast can't pass). Every face counts,
--     floors and ceilings too: the alarm sits on a ceiling with a floor above it, so a wall test that skips horizontal faces (made
--     so a floor-level blast isn't blocked by its own floor) would let a swing or a grenade upstairs break the alarm below.
--   opts.isLive: (model) -> bool: false = this alarm's map isn't being played (no chirps). Default: always live.
function SmokeAlarm.Server(models: { Instance }, opts)
	opts = if type(opts) == "table" then opts else {}
	local self = setmetatable({ alarms = {}, geometry = opts.geometry, isLive = opts.isLive, dead = false }, Set)
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

-- is a part one of this set's alarms? (the lobby's Solid layer holds the alarms too: they never block themselves)
function Set:IsAlarmPart(part: Instance): boolean
	for _, a in self.alarms do
		if part:IsDescendantOf(a.model) then return true end
	end
	return false
end

-- Is anything of the map's collision between a and b? Floors and ceilings count (see Server). The alarms themselves don't.
-- No geometry given (a map without collision proxies): nothing blocks, like the callers' own wall tests.
function Set:Blocked(a: Vector3, b: Vector3): boolean
	local geo = self.geometry
	if type(geo) == "function" then geo = geo() end
	if type(geo) ~= "table" or #geo == 0 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = geo
	local from = a
	for _ = 1, 8 do
		local dir = b - from
		if dir.Magnitude < 0.05 then return false end
		local hit = workspace:Raycast(from, dir, params)
		if not hit then return false end
		if not self:IsAlarmPart(hit.Instance) then return true end
		from = hit.Position + dir.Unit * 0.05
	end
	return false
end

-- the low-battery chirp: every ChirpMin..ChirpMax seconds per alarm while it isn't broken (clients play it from ChirpAt)
function Set:Step()
	if self.dead then return end
	local cfg = SmokeAlarm.Config()
	if cfg.Enabled == false then return end
	local clock = os.clock()
	for _, a in self.alarms do
		if not a.broken and a.model.Parent and clock >= a.nextChirp and not (self.isLive and not self.isLive(a.model)) then
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

-- a melee swing (MeleeManager -> OnMelee, after its wind-up; the callers also skip it once combat is off): origin = the
-- attacker's root, look = flat facing, reach / angle = the weapon's. The alarm breaks when its nearest point is within
-- reach + MeleeReach of the head, inside the swing's angle (or within 1.5 studs flat: right under it), at or above the head
-- (never from above it), and nothing of the map's collision is between (Blocked: never through a floor or a wall). On the
-- House only a 6.5-7 stud weapon reaches, and only the upstairs alarm (12-stud ceiling) from right under it.
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
					-- never from above it, never through a floor / wall (the same test as a blast's)
					ok = ok and near.Y >= head.Y and not self:Blocked(head, near)
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
			if not self:Blocked(position + Vector3.new(0, 1, 0), target) then
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
]=]
SOURCES.SmokeAlarmController = [=[
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/SmokeAlarmController (ModuleScript) [SMOKEALARM] 2026-10-28
-- Match places: every smoke alarm ShootableManager tagged "SmokeAlarm" (the placed maps' Shootable = "SmokeAlarm" models) chirps,
-- blinks, blares and breaks on this client from its attributes (SmokeAlarm.BindClient). One match per match server, so every
-- client here is that match's player or spectator. Lobby pad-duel arenas (Workspace.DuelArenas) are skipped: ArenaLoader binds
-- their client-only Visual twin for that match's players only. (fix/smoke_alarm.lua, notes/smoke_alarm.md)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [alarm] = { connections }

function controller.Start()
	local SmokeAlarm = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SmokeAlarm"))
	local function bind(alarm: Instance)
		if bound[alarm] or alarm:FindFirstAncestor("DuelArenas") then return end
		bound[alarm] = SmokeAlarm.BindClient(alarm, alarm)
	end
	for _, a in CollectionService:GetTagged(SmokeAlarm.TAG) do task.spawn(bind, a) end
	CollectionService:GetInstanceAddedSignal(SmokeAlarm.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(SmokeAlarm.TAG):Connect(function(alarm)
		local conns = bound[alarm]
		bound[alarm] = nil
		for _, c in conns or {} do c:Disconnect() end
	end)
end

return controller
]=]
SOURCES.AlarmBlock = [=[
	-- [SMOKEALARM] 2026-10-28 shootable ceiling smoke alarms (models with Shootable = "SmokeAlarm"; fix/smoke_alarm.lua,
	-- notes/smoke_alarm.md; the rules: Shared.SmokeAlarm). A quiet low-battery chirp every ChirpMin..ChirpMax seconds (random per
	-- alarm); the first bullet, melee swing or blast sets it blaring for BlareTime seconds, which masks footsteps and reloads
	-- within MaskRadius on its floor for players and the AI (like a steam valve; gunshots and fire stay audible); then it's
	-- broken and silent until the round resets.
	SmokeAlarm = {
		Enabled = true,          -- false: alarms are plain props (no chirp, can't be shot out)
		ChirpMin = 25,           -- seconds between chirps (random per alarm, every gap)
		ChirpMax = 40,
		ChirpVolume = 0.16,      -- quiet: a location cue (heard to ~45 studs), not an annoyance
		BlareTime = 7,           -- seconds it blares once shot
		BlareVolume = 0.75,
		MaskRadius = 28,         -- studs (flat) around the alarm where footsteps / reloads are masked while it blares
		MaskBelow = 16,          -- ... from this far below the alarm (its own floor) ...
		MaskAbove = 2,           -- ... to this far above it (never the floor upstairs)
		ListenerInBlare = true,  -- standing in the blare you can't hear people either (the steam's rule)
		HitPadding = 0.3,        -- studs around the alarm for the bullet test
		BlastScale = 1.25,       -- a blast breaks alarms within its Radius x this, with no wall in between (a frag on the floor
		                         -- under a 12-13 stud ceiling reaches; floors and walls between still block)
	},
]=]
SOURCES.TestHook = [=[
-- [SMOKEALARM] Studio-only test hook: ServerStorage.SmokeAlarmTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar
-- code gets fresh module copies, so it can't reach this manager's state). Alarms are named by their model name ("SmokeAlarm_G").
--   "alarms"               -> JSON list { name, pos, broken, blareAt, blareUntil, chirpAt, now }
--   "shoot", name, player? -> a real OnShot from the player's head through the alarm (as CombatManager calls it)
--   "chirp", name          -> chirp now (skips the 25-40 s wait)
--   "reset"                -> ResetAll (as a new round does)
--   "masked", Vector3      -> SteamMask.IsMasked (what footsteps / reloads ask)
--   "spawnai", Vector3     -> a BotManager AI (not autonomous: it stands still and only perceives) at that spot; "botAt", Vector3 moves it
--   "melee", Vector3 root, Vector3 look, reach, angle -> the real manager.OnMelee (as MeleeManager calls it after its wind-up)
--   "blast", Vector3, kind?  -> the real manager.Explode (a "Frag" by default): everything a grenade does there
--   "hears", player?       -> JSON { steps, reload, botInBlare, playerInBlare }: the AI's REAL _perceive / HearNoise once (first bot),
--                             the reload exactly as CombatManager gates it (IsMasked at the source, then HearNoise(..., quiet = true))
local function alarmTestHook()
	local HttpService = game:GetService("HttpService")
	local SmokeAlarmMod = require(Shared.SmokeAlarm)
	local function alarmBy(name: any)
		for _, a in (alarms and alarms.alarms or {}) do
			if a.model.Name == name then return a end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("SmokeAlarmTestHook") or Instance.new("BindableFunction")
	hook.Name = "SmokeAlarmTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		local now = workspace:GetServerTimeNow()
		if cmd == "alarms" then
			local list = {}
			for _, e in (alarms and alarms.alarms or {}) do
				local m = e.model
				table.insert(list, { name = m.Name, pos = tostring(e.pos), broken = e.broken, blareAt = m:GetAttribute("BlareAt"),
					blareUntil = m:GetAttribute("BlareUntil"), chirpAt = m:GetAttribute("ChirpAt"), nextChirpIn = e.nextChirp - os.clock(), now = now })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" then
			local e, p = alarmBy(a), playerBy(b)
			local head = p and p.Character and p.Character:FindFirstChild("Head")
			local base = e and e.model:FindFirstChild("Base")
			if not (head and base) then return "no head / alarm" end
			local dir = (base.Position - head.Position).Unit
			manager.OnShot(head.Position, base.Position + dir * 2, p)
			return if e.broken then "blaring" else "not hit"
		elseif cmd == "chirp" then
			local e = alarmBy(a)
			if not e then return "no alarm" end
			e.nextChirp = 0
			alarms:Step()
			return "ok"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		elseif cmd == "masked" then
			return SteamMask.IsMasked(a)
		elseif cmd == "melee" then
			local reach, angle = b and b.reach or 6, b and b.angle or 70
			manager.OnMelee(a.root, a.look, reach, angle, nil)
			return "ok"
		elseif cmd == "blast" then
			manager.Explode(a, b or "Frag", nil)
			return "ok"
		elseif cmd == "spawnai" then
			local bm = Get and Get("BotManager")
			if not (bm and bm.Spawn) then return "no BotManager" end
			bm.Spawn(CFrame.new(a), { autonomous = false, name = "AlarmTestAI" })
			return "ok"
		elseif cmd == "botAt" then
			local bm = Get and Get("BotManager")
			for _, bot in ((bm and bm.GetBots and bm.GetBots()) or {}) do
				bot.root.CFrame = CFrame.new(a)
				bot.root.AssemblyLinearVelocity = Vector3.zero
				return "ok"
			end
			return "no bot"
		elseif cmd == "hears" then
			local p = playerBy(a)
			local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local bm = Get and Get("BotManager")
			local list = (bm and bm.GetBots and bm.GetBots()) or {}
			for _, bot in list do
				if not (root and bm) then return "no player" end
				local vel = root.AssemblyLinearVelocity
				local heard0, noise0, known0, noisePos0 = bot.heardAt, bot.noiseAt, bot.lastKnown, bot.noisePos
				root.AssemblyLinearVelocity = Vector3.new(12, 0, 0)
				bot.heardAt = nil
				bot:_perceive()
				local steps: any = bot.heardAt ~= nil
				if bot.visible then steps = "seen" end
				root.AssemblyLinearVelocity = vel
				bot.noiseAt = nil
				if not SteamMask.IsMasked(root.Position) then
					bm.HearNoise(root.Position, (Config.ReloadHearRange or 22), true)
				end
				local reload = bot.noiseAt ~= nil
				bot.heardAt, bot.noiseAt, bot.lastKnown, bot.noisePos = heard0, noise0, known0, noisePos0 -- a probe mustn't start a hunt
				return HttpService:JSONEncode({ steps = steps, reload = reload,
					botInBlare = SmokeAlarmMod.Blaring(bot.root.Position, now), playerInBlare = SmokeAlarmMod.Blaring(root.Position, now) })
			end
			return "no bot"
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

local function norm(s: string): string return (s:gsub("\r\n", "\n")) end
for k, v in SOURCES do SOURCES[k] = norm(v) end

-- // Where -------------------------------------------------------------------------------------------------------------------------
local Shared = ReplicatedStorage.Modules.Shared
local Cfg = Shared.Config
local Managers = ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers
local SM = Managers.ShootableManager
local Controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
local FC = Controllers.FootstepController
local MASK = Shared.SteamMask
local AS = ServerScriptService:FindFirstChild("ArenaShootables", true)
local HUB = workspace:FindFirstChild("LobbyMap") ~= nil and AS ~= nil
local KIND = HUB and "hub" or "match"
local AL = HUB and StarterPlayer.StarterPlayerScripts:FindFirstChild("ArenaLoader") or nil
if HUB then assert(AL, "smoke_alarm: hub without StarterPlayerScripts.ArenaLoader (nothing was written)") end

-- // Round stamp ------------------------------------------------------------------------------------------------------------------
local targets = { Cfg.ShootableConfig, MASK, SM }
if HUB then table.insert(targets, AS) table.insert(targets, AL) table.insert(targets, FC) end
do
	local stamp = SM:GetAttribute("SmokeAlarmRound")
	assert(stamp == nil or stamp == ROUND, "smoke_alarm round " .. tostring(stamp) .. " is installed: UNDO it with that round's fix first")
	if stamp == nil then
		for _, inst in targets do
			assert(not norm(inst.Source):find("[SMOKEALARM]", 1, true),
				"smoke_alarm: an unstamped [SMOKEALARM] edit is in " .. inst.Name .. ": UNDO it with the installer that wrote it first")
		end
	end
end

-- the House models that get alarms: the match places' Workspace.House, the lobby's duel source (ServerStorage._DuelSource.House)
local function houseModels(): { Instance }
	local list = {}
	local w = workspace:FindFirstChild("House")
	if w then table.insert(list, w) end
	local src = ServerStorage:FindFirstChild("_DuelSource")
	local hs = src and src:FindFirstChild("House")
	if hs then
		local inner = hs:FindFirstChild("House")
		table.insert(list, inner or hs)
	end
	return list
end
local function placedAlarms(): { Instance }
	local list = {}
	for _, house in houseModels() do
		for _, d in house:GetDescendants() do
			if d:GetAttribute("SmokeAlarmInstall") ~= nil and d:IsA("Model") then table.insert(list, d) end
		end
	end
	return list
end

-- The work order: no House in this place = do nothing (no code, no alarms). UNDO still runs (it only removes what is ours).
if not UNDO and #houseModels() == 0 then
	return ("SMOKEALARM round %d (%s): no House in this place (Workspace.House / ServerStorage._DuelSource.House): nothing written"):format(ROUND, KIND)
end
if not UNDO then
	assert(SM:GetAttribute("GlassRound") == 1, "smoke_alarm: needs breakable glass round 1 installed first (fix/breakable_glass.lua): its text is the anchor")
	if not HUB then assert(SM:GetAttribute("SteamFillRound") == 5, "smoke_alarm: a match place needs steam fill round 5 first (fix/steam_fill.lua)") end
end

local function hash(): string
	-- FNV-1a over every source this installer touches + which new modules exist + where the placed alarms are
	local h = 2166136261
	local parts = {}
	for _, t in targets do table.insert(parts, t.Source) end
	for _, m in { Shared:FindFirstChild("SmokeAlarm"), Controllers:FindFirstChild("SmokeAlarmController") } do
		table.insert(parts, if m then m.Source else "none")
	end
	for _, m in placedAlarms() do table.insert(parts, m:GetFullName() .. tostring(m:GetPivot().Position) .. tostring(m:GetAttribute("SmokeAlarmModel"))) end
	for _, s in parts do
		s = norm(s)
		for i = 1, #s do h = bit32.bxor(h, s:byte(i)); h = (h * 16777619) % 4294967296 end
	end
	return string.format("%08x", h)
end
local before = hash()

-- // Text edits { instance, old, new } -----------------------------------------------------------------------------------------------
local edits = {}
local function edit(inst, old, new) table.insert(edits, { inst, old, new }) end
local TAG = " -- [SMOKEALARM]"

-- ShootableConfig (both): the SmokeAlarm block before the reload line (the glass block after it stays as its installer wrote it)
local RELOAD_NOTE = "\t-- Reloads: the AI hears one this close (a hissing steam valve masks it)\n"
edit(Cfg.ShootableConfig, RELOAD_NOTE, SOURCES.AlarmBlock .. RELOAD_NOTE)

-- SteamMask (both): a blaring alarm masks quiet sounds like a hissing valve
edit(MASK, "local CollectionService = game:GetService(\"CollectionService\")\n",
	"local CollectionService = game:GetService(\"CollectionService\")\n"
	.. "local SmokeAlarm = require(script.Parent.SmokeAlarm)" .. TAG .. " a blaring smoke alarm masks quiet sounds too\n")
edit(MASK, "function mask.IsMasked(position: Vector3): boolean\n\tlocal now = workspace:GetServerTimeNow()\n",
	"function mask.IsMasked(position: Vector3): boolean\n\tlocal now = workspace:GetServerTimeNow()\n"
	.. "\tif SmokeAlarm.Blaring(position, now) then return true end" .. TAG .. " footsteps / reloads in a blaring alarm's radius, its floor\n")
-- A lobby that got the fill steam (its FootstepController asks SteamCloud.FootstepScale -> SteamMask.FillMuffled, 2026-10-28)
-- takes the match places' footstep rule (FillMuffled asks the alarm); an older lobby keeps the FootstepController edits below.
local HUBFILL = HUB and norm(FC.Source):find("SteamCloud.FootstepScale(", 1, true) ~= nil
if not HUB or HUBFILL then
	-- the fill steam's rule for players' footsteps (muffled, very faint; you in the blare can't hear people) and the AI (Muffled).
	-- First thing in the function, BEFORE its Steam.Fill gate: turning the steam fill off must not turn the alarm's rule off.
	local FILLM = "function mask.FillMuffled(source: Vector3, listener: Vector3?, now: number?): boolean\n"
	edit(MASK, FILLM, FILLM
		.. "\tif SmokeAlarm.Muffles(source, listener, now) then return true end" .. TAG .. " the walker or the listener in a blare (any Fill flag)\n")
end
if not HUB then

	-- ShootableManager (match places)
	local OPEN = "local Openings = require(Shared.Openings) -- [GLASS] window glass, player-only barriers, door states (the rules)\n"
	edit(SM, OPEN, OPEN
		.. "local SmokeAlarm = require(Shared.SmokeAlarm)" .. TAG .. " shootable ceiling smoke alarms (the rules + server state)\n"
		.. "local alarms = nil" .. TAG .. " the placed maps' alarms (SmokeAlarm.Server), made in Start\n")
	local GSTART = "\t-- [GLASS] window panes, player-only barriers and door states of every placed map\n"
	edit(SM, GSTART,
		"\t-- [SMOKEALARM] the smoke alarms of every placed map (Shootables.<SmokeAlarm_*>, Shootable = \"SmokeAlarm\")\n"
		.. "\tdo\n"
		.. "\t\tlocal found = {}\n"
		.. "\t\tfor _, placed in placedMaps() do\n"
		.. "\t\t\tlocal sh = placed:FindFirstChild(\"Shootables\")\n"
		.. "\t\t\tfor _, m in (sh and sh:GetChildren() or {}) do\n"
		.. "\t\t\t\tif SmokeAlarm.IsAlarm(m) then table.insert(found, m) end\n"
		.. "\t\t\tend\n"
		.. "\t\tend\n"
		.. "\t\t-- an alarm on a map that isn't being played stays quiet (ArenaMap = the voted map; none set: every map is live)\n"
		.. "\t\tlocal function liveMap(m: Instance): boolean\n"
		.. "\t\t\tlocal id = ReplicatedStorage:GetAttribute(\"ArenaMap\")\n"
		.. "\t\t\tif type(id) ~= \"string\" then return true end\n"
		.. "\t\t\tlocal info = MapRegistry and MapRegistry.Get and MapRegistry.Get(id)\n"
		.. "\t\t\tlocal placed = workspace:FindFirstChild(info and info.WorkspaceName or id)\n"
		.. "\t\t\treturn placed == nil or m:IsDescendantOf(placed)\n"
		.. "\t\tend\n"
		.. "\t\t-- the wall test for swings and blasts: every placed map's collision, floors and ceilings included\n"
		.. "\t\talarms = SmokeAlarm.Server(found, { geometry = mapFolders, isLive = liveMap })\n"
		.. (("\t\t" .. SOURCES.TestHook:gsub("\n", "\n\t\t")):gsub("\t+$", "")) -- (indented into this block)
		.. "\t\tif RunService:IsStudio() then alarmTestHook() end\n"
		.. "\tend\n"
		.. GSTART)
	local GSHOT = "\t-- [GLASS] glass never stops a bullet (it is CanQuery off): every pane the shot crossed, up to where it stopped, breaks\n"
	edit(SM, GSHOT, "\tif alarms then alarms:Hit(origin, endPos) end" .. TAG .. " the first alarm the shot reached blares\n" .. GSHOT)
	-- (after the glass block: its inserted text runs from the spawnFire line through its loop, so never split it)
	local CHAIN = "\t-- chain reaction\n\tif cfg.Chain then\n\t\tfor _, b in barrels do\n"
	edit(SM, CHAIN, "\tif alarms then alarms:Blast(position, cfg.Radius) end" .. TAG .. " alarms in reach, no wall between\n" .. CHAIN)
	local VALVE_ACTIVE = "function manager.IsValveActive(model: Model): boolean\n\treturn (model:GetAttribute(\"SteamUntil\") or 0) > workspace:GetServerTimeNow()\nend\n"
	edit(SM, VALVE_ACTIVE, VALVE_ACTIVE
		.. "do" .. TAG .. " a melee swing reaches the smoke alarms too (then the glass, as before)\n"
		.. "\tlocal glassMelee = manager.OnMelee\n"
		.. "\tfunction manager.OnMelee(origin: Vector3, look: Vector3, reach: number, angle: number, attacker: Player?)\n"
		.. "\t\tif alarms and ReplicatedStorage:GetAttribute(\"CombatEnabled\") ~= false then alarms:Melee(origin, look, reach, angle) end\n"
		.. "\t\tif glassMelee then glassMelee(origin, look, reach, angle, attacker) end\n"
		.. "\tend\n"
		.. "end\n")
	local FIRES = "\tfor _, f in fires do f.untilT = 0 end\n"
	edit(SM, FIRES, "\tif alarms then alarms:Reset() end" .. TAG .. " alarms whole and chirping again\n" .. FIRES)
else
	-- FootstepController (an older hub without the fill steam): the listener rule (you in a blare can't hear people); the
	-- source rule is IsMasked's
	if not HUBFILL then
	edit(FC, "local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n",
		"local SteamMask = require(Shared:WaitForChild(\"SteamMask\"))\n"
		.. "local SmokeAlarm = require(Shared:WaitForChild(\"SmokeAlarm\"))" .. TAG .. "\n")
	edit(FC, "\t\t\t\t\tif character ~= me and SteamMask.IsMasked(position) then volume *= 0.04 end\n",
		"\t\t\t\t\t-- [SMOKEALARM] a blaring smoke alarm drowns them too, and standing in one you can't hear people\n"
		.. "\t\t\t\t\tif character ~= me and (SteamMask.IsMasked(position) or SmokeAlarm.Muffles(position)) then volume *= 0.04 end\n")
	end

	-- ArenaShootables: the alarms of ONE arena (state on its Solid layer; ArenaLoader draws the Visual twin)
	local OPEN = "local Openings = require(Shared.Openings) -- [GLASS] window glass, player-only barriers, door states (the rules)\n"
	edit(AS, OPEN, OPEN .. "local SmokeAlarm = require(Shared.SmokeAlarm)" .. TAG .. " shootable ceiling smoke alarms\n")
	local GNEW = "\t-- [GLASS] window panes (Shootables.<Window>, Shootable = \"Glass\"), barriers (tag WindowBarrier), door states (DoorState)\n"
	edit(AS, GNEW,
		"\t-- [SMOKEALARM] smoke alarms (Shootables.<SmokeAlarm_*>, Shootable = \"SmokeAlarm\"): chirp, blare when shot, reset per round\n"
		.. "\tdo\n"
		.. "\t\tlocal found = {}\n"
		.. "\t\tfor _, m in (shoot and shoot:GetChildren() or {}) do\n"
		.. "\t\t\tif SmokeAlarm.IsAlarm(m) then table.insert(found, m) end\n"
		.. "\t\tend\n"
		.. "\t\t-- its own wall test on this arena's Solid layer, floors and ceilings included (self:wallBetween skips horizontal\n"
		.. "\t\t-- faces, so a grenade upstairs would break the alarm below)\n"
		.. "\t\tself.alarms = SmokeAlarm.Server(found, { geometry = function() return self.rayParams.FilterDescendantsInstances end })\n"
		.. "\tend\n"
		.. GNEW)
	local GSHOT = "\t-- [GLASS] glass never stops a bullet (CanQuery off): every pane the shot crossed, up to where it stopped, breaks\n"
	edit(AS, GSHOT, "\tif self.alarms then self.alarms:Hit(origin, endPos) end" .. TAG .. " the first alarm the shot reached blares\n" .. GSHOT)
	local GBLAST = "\t-- [GLASS] the blast breaks every pane in reach with no wall in between\n"
	edit(AS, GBLAST, "\tif self.alarms then self.alarms:Blast(position, cfg.Radius) end" .. TAG .. " alarms in reach, no wall between\n" .. GBLAST)
	local STEP = "\nfunction ArenaShootables:Step(dt: number)\n"
	edit(AS, STEP,
		"\ndo" .. TAG .. " a melee swing in this arena reaches its smoke alarms too (then the glass, as before)\n"
		.. "\tlocal glassMelee = ArenaShootables.OnMelee\n"
		.. "\tfunction ArenaShootables:OnMelee(origin: Vector3, look: Vector3, reach: number, angle: number, attacker: Player?)\n"
		.. "\t\t-- the lobby's MeleeManager re-checks only health after the wind-up: skip the alarm once this arena's combat is off\n"
		.. "\t\tif self.alarms and not self.dead and self.arena.state:GetAttribute(\"CombatEnabled\") ~= false then self.alarms:Melee(origin, look, reach, angle) end\n"
		.. "\t\tif glassMelee then return glassMelee(self, origin, look, reach, angle, attacker) end\n"
		.. "\tend\n"
		.. "end\n"
		.. STEP)
	local RESET = "\tself.fires = {}\n\tfor character in self.burning do self:extinguish(character) end\n"
	edit(AS, RESET, "\tif self.alarms then self.alarms:Reset() end" .. TAG .. " alarms whole and chirping again\n" .. RESET)
	local DESTROY = "function ArenaShootables:Destroy()\n\tself.dead = true\n"
	edit(AS, DESTROY, DESTROY .. "\tif self.alarms then self.alarms:Destroy() end" .. TAG .. "\n")

	-- ArenaLoader: the client-only Visual twin follows the Solid alarm (chirp, LED, blare, broken look) for this match's players
	local AOPEN = "local Openings = require(Shared:WaitForChild(\"Openings\")) -- [GLASS] window glass (Shootable = \"Glass\"), barriers\n"
	edit(AL, AOPEN, AOPEN .. "local SmokeAlarm = require(Shared:WaitForChild(\"SmokeAlarm\"))" .. TAG .. " shootable ceiling smoke alarms\n")
	local VALVE = "\t\t\t\t\telseif kind == \"SteamValve\" then bindValve(sm, vm, conns); n += 1\n"
	edit(AL, VALVE,
		"\t\t\t\t\telseif kind == \"SmokeAlarm\" then" .. TAG .. " chirp / LED / blare / broken look from the Solid alarm\n"
		.. "\t\t\t\t\t\tfor _, c in SmokeAlarm.BindClient(sm, vm) do table.insert(conns, c) end\n"
		.. "\t\t\t\t\t\tn += 1\n"
		.. VALVE)
end

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
		assert(a, "smoke_alarm: edit " .. i .. " anchor not found in " .. e[1]:GetFullName() .. " (nothing was written)")
		assert(not s:find(old, b + 1, true), "smoke_alarm: edit " .. i .. " anchor not unique in " .. e[1].Name .. " (nothing was written)")
		-- an anchor starts and ends at a token boundary (never inside a longer name or call)
		local before_, after_ = s:sub(a - 1, a - 1), s:sub(b + 1, b + 1)
		assert(not (old:sub(1, 1):match("[%w_]") and before_:match("[%w_%.:]")) and not (old:sub(-1):match("[%w_]") and after_:match("[%w_]")),
			"smoke_alarm: edit " .. i .. " anchor is inside a longer token in " .. e[1].Name .. " (nothing was written)")
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local newModules = { { Shared, "SmokeAlarm", SOURCES.SmokeAlarm } }
if not HUB then table.insert(newModules, { Controllers, "SmokeAlarmController", SOURCES.SmokeAlarmController }) end
if not UNDO then
	for _, nm in newModules do
		local m = nm[1]:FindFirstChild(nm[2])
		assert(not m or m:GetAttribute("SmokeAlarmInstall") ~= nil,
			"smoke_alarm: a " .. nm[2] .. " that isn't ours is already in " .. nm[1]:GetFullName() .. " (nothing was written)")
	end
end
local compile = loadstring
if compile then
	for inst, s in sources do
		local f, err = compile(s)
		assert(f, "smoke_alarm: " .. inst.Name .. " would not parse: " .. tostring(err) .. " (nothing was written)")
	end
	for _, nm in newModules do
		local f, err = compile(nm[3])
		assert(f, "smoke_alarm: " .. nm[2] .. " does not parse: " .. tostring(err))
	end
end

-- // The alarm model and where it goes --------------------------------------------------------------------------------------------
-- Plan centre of the house (x 0, y 0: the middle of Slab_LD, the landing's floor slab), the exact midpoint between the point-
-- symmetric spawns: ground floor = the cross hall's ceiling (Slab_LD's underside, 13), upper = the landing's ceiling (Ceiling_U's
-- underside, 26). notes/smoke_alarm.md has the reasons.
local function worldExtents(p: BasePart): Vector3
	local function axis(v: Vector3) return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) end
	return axis(p.CFrame.RightVector) * p.Size.X + axis(p.CFrame.UpVector) * p.Size.Y + axis(p.CFrame.LookVector) * p.Size.Z
end
local function findPart(root: Instance, name: string): BasePart?
	local best
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == name or d.Name:sub(-#name - 1) == "_" .. name) then
			-- prefer the collision proxy's box (exact numbers) over an art mesh of the same name
			if not best or d:FindFirstAncestor("CollisionProxies") then best = d end
		end
	end
	return best
end
local function spotsFor(house: Instance): ({ { name: string, at: Vector3 } }?, string?)
	local slab = findPart(house, "Slab_LD")
	local ceil = findPart(house, "Ceiling_U")
	if not slab or not ceil then return nil, "no Slab_LD / Ceiling_U in " .. house:GetFullName() end
	local e, ce = worldExtents(slab), worldExtents(ceil)
	local c = slab.Position
	return {
		{ name = "SmokeAlarm_G", at = Vector3.new(c.X, c.Y - e.Y / 2, c.Z) },
		{ name = "SmokeAlarm_U", at = Vector3.new(c.X, ceil.Position.Y - ce.Y / 2, c.Z) },
	}, nil
end

local MODEL = "1b" -- bump when the model changes: a placed alarm of another version is rebuilt
local WHITE, SHELL, TRIM = Color3.fromRGB(240, 240, 236), Color3.fromRGB(230, 230, 226), Color3.fromRGB(196, 196, 190)
local function buildAlarm(name: string, at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Shootable", "SmokeAlarm")
	m:SetAttribute("NotCover", true)
	m:SetAttribute("SmokeAlarmInstall", ROUND)
	m:SetAttribute("SmokeAlarmModel", MODEL)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's axis is X: stand it up
	local function part(n: string, shape, size: Vector3, below: number, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = n
		p.Shape = shape
		p.Size = size
		local h = if shape == Enum.PartType.Cylinder then size.X else size.Y
		p.CFrame = CFrame.new(at - Vector3.new(0, below + h / 2, 0)) * (if shape == Enum.PartType.Cylinder then up else CFrame.identity)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, true, false
		p:SetAttribute("NotCover", true)
		p.Parent = m
		return p
	end
	local base = part("Base", Enum.PartType.Cylinder, Vector3.new(0.12, 1.4, 1.4), 0.01, WHITE)
	part("Cover", Enum.PartType.Cylinder, Vector3.new(0.34, 1.16, 1.16), 0.13, SHELL)
	part("CoverRing", Enum.PartType.Cylinder, Vector3.new(0.05, 0.96, 0.96), 0.47, TRIM)
	part("CoverButton", Enum.PartType.Cylinder, Vector3.new(0.07, 0.34, 0.34), 0.47, WHITE)
	-- inside the housing (hidden while it is shut): the circuit board and the battery, seen once it hangs open
	part("Board", Enum.PartType.Cylinder, Vector3.new(0.05, 0.98, 0.98), 0.14, Color3.fromRGB(38, 66, 44))
	local battery = part("Battery", Enum.PartType.Block, Vector3.new(0.5, 0.16, 0.3), 0.19, Color3.fromRGB(28, 28, 30))
	battery.CFrame = battery.CFrame + Vector3.new(-0.18, 0, 0)
	local led = part("Led", Enum.PartType.Ball, Vector3.new(0.14, 0.14, 0.14), 0.42, Color3.fromRGB(70, 14, 12))
	led.CFrame = led.CFrame + Vector3.new(0, 0, 0.38)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 40)
	light.Brightness = 2
	light.Range = 5
	light.Shadows = false
	light.Enabled = false
	light.Parent = led
	m.PrimaryPart = base
	return m
end

local placeLog = {}
local plans = {}
for _, house in houseModels() do
	local spots, why = spotsFor(house)
	if not spots then
		table.insert(placeLog, why)
	else
		table.insert(plans, { house = house, spots = spots })
	end
end

if DRY then
	return ("SMOKEALARM round %d DRY %s (%s): %s | houses %d %s | hash %s (nothing written)"):format(ROUND, UNDO and "UNDO" or "install",
		KIND, table.concat(out, " "), #plans, table.concat(placeLog, "; "), before)
end

-- // Pass 2: write ----------------------------------------------------------------------------------------------------------------------
if not UNDO then SM:SetAttribute("SmokeAlarmRound", ROUND) end
for inst, s in sources do if norm(inst.Source) ~= s then inst.Source = s end end
for _, nm in newModules do
	local parent, name, source = nm[1], nm[2], nm[3]
	local m = parent:FindFirstChild(name)
	if UNDO then
		if m and m:GetAttribute("SmokeAlarmInstall") then m:Destroy() table.insert(out, name .. "-") else table.insert(out, name .. "=") end
	elseif m and norm(m.Source) == source then
		table.insert(out, name .. "=")
	else
		if not m then
			m = Instance.new("ModuleScript")
			m.Name = name
			m:SetAttribute("SmokeAlarmInstall", ROUND)
			m.Source = source
			m.Parent = parent
		else
			m.Source = source
		end
		table.insert(out, name .. "+")
	end
end
-- the alarms: rebuilt at the computed spots (same spot and same model = "="), removed by UNDO
for _, plan in plans do
	local shoot = plan.house:FindFirstChild("Shootables")
	for _, spot in plan.spots do
		local old = shoot and shoot:FindFirstChild(spot.name)
		if UNDO then
			if old and old:GetAttribute("SmokeAlarmInstall") then old:Destroy() table.insert(placeLog, spot.name .. "-") end
		else
			local same = old and old:GetAttribute("SmokeAlarmInstall") == ROUND and old:GetAttribute("SmokeAlarmModel") == MODEL and (old:GetPivot().Position - (spot.at - Vector3.new(0, 0.07, 0))).Magnitude < 0.01
			if same then
				table.insert(placeLog, spot.name .. "=")
			else
				assert(not old or old:GetAttribute("SmokeAlarmInstall") ~= nil, "smoke_alarm: a " .. spot.name .. " that isn't ours is in " .. plan.house:GetFullName())
				if old then old:Destroy() end
				if not shoot then
					shoot = Instance.new("Folder")
					shoot.Name = "Shootables"
					shoot.Parent = plan.house
				end
				buildAlarm(spot.name, spot.at).Parent = shoot
				table.insert(placeLog, ("%s+ %s"):format(spot.name, tostring(spot.at)))
			end
		end
	end
end
if UNDO then SM:SetAttribute("SmokeAlarmRound", nil) end
return ("SMOKEALARM round %d %s (%s): %s | %s | hash %s -> %s"):format(ROUND, UNDO and "UNDO" or "install", KIND, table.concat(out, " "),
	table.concat(placeLog, " "), before, hash())
