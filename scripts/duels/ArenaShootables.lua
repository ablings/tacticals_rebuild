-- ServerScriptService/Shared/ArenaShootables (ModuleScript): doors, fire barrels, steam valves and explosions of ONE
-- lobby duel arena (lobby duels phase 2, 2026-10-16). Per-arena port of the match place's ShootableManager + DoorManager.
-- LobbyDuelManager makes one per match (ArenaShootables.new(arena)) once the Solid layer is in Workspace; the lobby's
-- ShootableManager stub routes shots / frag blasts to the arena that contains them.
--
-- Server state lives on the arena's Solid models (they replicate, and only this match's clients have the Visual twin):
--   Interactive.<Door>   (child "Shutter")              DoorOpen (bool), DoorMoving (bool), DoorAt (server time the roll started),
--                                                       DoorHeight. The Solid shutter is tweened here (collision); the
--                                                       client tweens its Visual shutter from the same attributes.
--   Shootables.<Barrel>  (attr Shootable = "FireBarrel") Exploded (bool), FireUntil (server time, burning ground)
--   Shootables.<Valve>   (attr Shootable = "SteamValve") SteamUntil (server time; SteamMask reads it on server and client)
-- Effects: Events.Combat.Explosion goes only to this match's players + spectators (MatchState.FireScoped); burning ground,
-- steam jets and door motion are drawn by the clients' ArenaLoader. Burning players carry the match place's BurnFX.
-- Nothing here names a map: doors / shootables are found by the conventions above (the Warehouse blueprint).
--
-- arena = { id, solid (Model in Workspace), origin (Vector3), info (MapInfo), visual (template Model), state (Configuration),
--           characters () -> {Model}, isMember (Player) -> bool, rayFilter {Instance} }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Modules.Shared
local Config = require(Shared.Config.ShootableConfig)
local SoundTrim = require(Shared.SoundTrim)
local MatchState = require(Shared.MatchState)
local Combat = ReplicatedStorage.Events.Combat

local FLAT = Vector3.new(1, 0, 1)
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local HISS = "rbxassetid://4772620521"
local ROLL_TIME = 1.6

local ArenaShootables = {}
ArenaShootables.__index = ArenaShootables
ArenaShootables.ROLL_TIME = ROLL_TIME

local function now() return workspace:GetServerTimeNow() end

-- Does segment a->b pass through the box? (match place ShootableManager)
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

local function flameEmitter(parent: Instance, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = FIRE_TEX
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 140, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(0.4, size), NumberSequenceKeypoint.new(1, size * 0.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(0, 7, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = rate
	e.Parent = parent
	return e
end

-- // Construction ----------------------------------------------------------------------------------------------------------
function ArenaShootables.new(arena)
	local self = setmetatable({ arena = arena, doors = {}, barrels = {}, valves = {}, fires = {}, burning = {}, conns = {} }, ArenaShootables)
	local solid = arena.solid
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Include
	self.rayParams.FilterDescendantsInstances = arena.rayFilter or { solid }

	-- doors: Interactive.<Door> with a Shutter; the prompt sits where the Visual layer has the door's Panel
	local inter = solid:FindFirstChild("Interactive")
	local vInter = arena.visual and arena.visual:FindFirstChild("Interactive")
	for _, model in (inter and inter:GetChildren() or {}) do
		local shutter = model:FindFirstChild("Shutter")
		if shutter and shutter:IsA("BasePart") then
			local vPanel = vInter and vInter:FindFirstChild(model.Name) and vInter[model.Name]:FindFirstChild("Panel")
			local panel = Instance.new("Part")
			panel.Name = "PanelPrompt"
			panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch, panel.CastShadow = true, false, false, false, false
			panel.Transparency = 1
			panel.Size = vPanel and vPanel.Size or Vector3.new(1, 1, 0.3)
			panel.CFrame = vPanel and (CFrame.new(arena.origin) * vPanel.CFrame) or shutter.CFrame
			panel.Parent = model
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Shutter"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = panel
			local door = { model = model, shutter = shutter, closedCF = shutter.CFrame, height = model:GetAttribute("OpenHeight") or 10,
				prompt = prompt, open = false, busy = false }
			model:SetAttribute("DoorHeight", door.height)
			model:SetAttribute("DoorOpen", false)
			model:SetAttribute("DoorMoving", false)
			table.insert(self.conns, prompt.Triggered:Connect(function(player)
				-- only this match's live players can work its doors
				if arena.isMember(player) and player:GetAttribute("Alive") ~= false then self:SetDoor(door, not door.open) end
			end))
			table.insert(self.doors, door)
		end
	end

	-- shootables: Shootables.<Model> with attribute Shootable (FireBarrel / SteamValve); the name is the fallback
	local shoot = solid:FindFirstChild("Shootables")
	for _, model in (shoot and shoot:GetChildren() or {}) do
		local kind = model:GetAttribute("Shootable") or (model.Name:find("FireBarrel") and "FireBarrel") or (model.Name:find("SteamValve") and "SteamValve")
		if kind == "FireBarrel" and model:FindFirstChild("Body") then
			table.insert(self.barrels, { model = model, exploded = false, saved = {} })
		elseif kind == "SteamValve" then
			local parts = {}
			for _, p in model:GetDescendants() do if p:IsA("BasePart") then table.insert(parts, p) end end
			if #parts > 0 then table.insert(self.valves, { model = model, parts = parts, used = false }) end
		end
	end
	return self
end

function ArenaShootables:Counts()
	return #self.doors, #self.barrels, #self.valves
end

-- // Doors ------------------------------------------------------------------------------------------------------------------
function ArenaShootables:SetDoor(door, open: boolean)
	if door.open == open or door.busy or self.dead then return end
	door.busy = true
	door.open = open
	door.prompt.Enabled = false
	door.model:SetAttribute("DoorAt", now())
	door.model:SetAttribute("DoorMoving", true)
	door.model:SetAttribute("DoorOpen", open)
	local goal = open and door.closedCF + Vector3.new(0, door.height, 0) or door.closedCF
	local tween = TweenService:Create(door.shutter, TweenInfo.new(ROLL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal })
	tween:Play()
	task.spawn(function()
		tween.Completed:Wait()
		if self.dead then return end
		door.model:SetAttribute("DoorMoving", false)
		door.prompt.ActionText = open and "Close" or "Open"
		door.prompt.Enabled = true
		door.busy = false
	end)
end

-- // Burning --------------------------------------------------------------------------------------------------------------------
function ArenaShootables:hurt(character: Model, amount: number, attacker: Player?, from: Vector3?, kind: string?)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or amount <= 0 then return end
	-- no friendly fire in a live match (your own blast still hurts you); only this match's bodies are ever passed in
	local owner = Players:GetPlayerFromCharacter(character) or character
	if attacker and owner ~= attacker and self.arena.state:GetAttribute("LiveMatch") and owner:GetAttribute("Team") ~= nil
		and owner:GetAttribute("Team") == attacker:GetAttribute("Team") then return end
	hum:SetAttribute("LastAttacker", attacker and attacker.UserId or 0)
	hum:SetAttribute("LastAttackKind", kind or "Blast")
	hum:SetAttribute("LastHitZone", nil)
	hum:TakeDamage(amount)
	local victim = Players:GetPlayerFromCharacter(character)
	if victim and from then Combat.DamageTaken:FireClient(victim, from, amount) end
	if kind ~= "Burn" and attacker and Combat:FindFirstChild("HitConfirm") and victim ~= attacker then
		Combat.HitConfirm:FireClient(attacker, "Body", amount, hum.Health <= 0)
	end
end

function ArenaShootables:ignite(character: Model, attacker: Player?, seconds: number?)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or self.dead then return end
	local untilT = os.clock() + (seconds or Config.Burn.Time)
	local entry = self.burning[character]
	if entry then entry.untilT = math.max(entry.untilT, untilT) return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	local holder = Instance.new("Attachment")
	holder.Name = "BurnFX"
	holder.Parent = torso
	flameEmitter(holder, 2.2, 45)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50); light.Brightness = 2.5; light.Range = 12
	light.Parent = holder
	local roar = Instance.new("Sound")
	roar.SoundId = HISS; roar.PlaybackSpeed = 0.45; roar.Volume = 0.5; roar.Looped = true; roar.RollOffMaxDistance = 70
	roar.Parent = holder
	SoundTrim.Play(roar)
	character:SetAttribute("Burning", true)
	self.burning[character] = { untilT = untilT, attacker = attacker }
end

function ArenaShootables:extinguish(character: Model)
	self.burning[character] = nil
	if character.Parent then character:SetAttribute("Burning", nil) end
	for _, d in character:GetDescendants() do
		if d.Name == "BurnFX" then
			for _, e in d:GetChildren() do if e:IsA("ParticleEmitter") then e.Enabled = false end end
			Debris:AddItem(d, 1)
			d.Name = "BurnFXOff"
		end
	end
end

-- // Explosions -----------------------------------------------------------------------------------------------------------------
function ArenaShootables:wallBetween(a: Vector3, b: Vector3): boolean
	local hit = workspace:Raycast(a, b - a, self.rayParams)
	return hit ~= nil and hit.Instance.Name ~= "COLP_Floor" and math.abs(hit.Normal.Y) < 0.9
end

function ArenaShootables:Explode(position: Vector3, kind: string, attacker: Player?, source)
	local cfg = Config.Explosions[kind]
	if not cfg or self.dead then return end
	MatchState.FireScoped(Combat.Explosion, self.arena.id, position, kind)
	local gadgets = shared.Get and shared.Get("GadgetManager")
	if gadgets and gadgets.PushSmoke then gadgets.PushSmoke(position, cfg.Radius * 1.5) end
	local from = position + Vector3.new(0, 1, 0)
	for _, character in self.arena.characters() do
		local root = character:FindFirstChild("HumanoidRootPart")
		local hum = character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - position).Magnitude
			local head = character:FindFirstChild("Head")
			local exposed = not self:wallBetween(from, root.Position) or (head and not self:wallBetween(from, head.Position))
			if d <= cfg.Radius and exposed then
				local amount
				if d <= cfg.KillRadius then
					amount = hum.MaxHealth * 3
				else
					local t = (d - cfg.KillRadius) / (cfg.Radius - cfg.KillRadius)
					amount = cfg.MaxDamage + (cfg.MinDamage - cfg.MaxDamage) * t
				end
				self:hurt(character, amount, attacker, position, kind)
				if cfg.Ignite and hum.Health > 0 then self:ignite(character, attacker) end
			end
		end
	end
	if cfg.FireRadius then
		-- burning ground: logic here, the flames are drawn by the match's clients from FireUntil / FireAt
		local untilT = os.clock() + cfg.FireTime
		table.insert(self.fires, { position = position - Vector3.new(0, 1, 0), radius = cfg.FireRadius, untilT = untilT, attacker = attacker })
		if source then
			source:SetAttribute("FireAt", position)
			source:SetAttribute("FireRadius", cfg.FireRadius)
			source:SetAttribute("FireUntil", now() + cfg.FireTime)
		end
	end
	if cfg.Chain then
		for _, b in self.barrels do
			if not b.exploded and (b.model.Body.Position - position).Magnitude <= cfg.Radius then
				task.delay(0.12 + math.random() * 0.12, function() self:ExplodeBarrel(b, attacker) end)
			end
		end
	end
end

function ArenaShootables:ExplodeBarrel(b, attacker: Player?)
	if b.exploded or self.dead then return end
	b.exploded = true
	local position = b.model.Body.Position
	for _, p in b.model:GetDescendants() do
		if p:IsA("BasePart") then
			b.saved[p] = b.saved[p] or { p.CanCollide, p.CanQuery }
			p.CanCollide, p.CanQuery = false, false
		end
	end
	b.model:SetAttribute("Exploded", true)
	self:Explode(position, "Barrel", attacker, b.model)
end

function ArenaShootables:ActivateValve(v, shooter: Player?)
	if v.used or self.dead then return end
	v.used = true
	v.model:SetAttribute("SteamUntil", now() + Config.Steam.Duration)
end

-- // Shots: the first shootable along the bullet's path reacts --------------------------------------------------------------------
function ArenaShootables:OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)
	if self.dead then return end
	-- the bullet stops at the first solid thing (walls, cover): nothing behind it reacts
	local dir = endPos - origin
	if dir.Magnitude > 0.05 then
		local hit = workspace:Raycast(origin, dir, self.rayParams)
		if hit then endPos = hit.Position + dir.Unit * 0.3 end
	end
	local best, bestT, bestKind = nil, math.huge, nil
	for _, v in self.valves do
		if not v.used then
			for _, p in v.parts do
				local hit, t = segmentHitsBox(origin, endPos, p.CFrame, p.Size, Config.Steam.HitPadding)
				if hit and t < bestT then best, bestT, bestKind = v, t, "Valve" end
			end
		end
	end
	for _, b in self.barrels do
		if not b.exploded then
			local body = b.model.Body
			local hit, t = segmentHitsBox(origin, endPos, body.CFrame, body.Size, 0.15)
			if hit and t < bestT then best, bestT, bestKind = b, t, "Barrel" end
		end
	end
	if bestKind == "Valve" then self:ActivateValve(best, shooter)
	elseif bestKind == "Barrel" then self:ExplodeBarrel(best, shooter) end
	return bestKind
end

-- // Per frame: burning players and standing in fire ----------------------------------------------------------------------------
function ArenaShootables:Step(dt: number)
	if self.dead then return end
	local clock = os.clock()
	for character, entry in self.burning do
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not character.Parent or not hum or hum.Health <= 0 or clock > entry.untilT then
			self:extinguish(character)
		else
			self:hurt(character, Config.Burn.Dps * dt, entry.attacker, nil, "Burn")
		end
	end
	self.acc = (self.acc or 0) + dt
	if self.acc >= 0.2 and #self.fires > 0 then
		self.acc = 0
		for i = #self.fires, 1, -1 do
			local fire = self.fires[i]
			if clock > fire.untilT then
				table.remove(self.fires, i)
			else
				for _, character in self.arena.characters() do
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						local off = root.Position - fire.position
						if (off * FLAT).Magnitude <= fire.radius * 0.85 and math.abs(off.Y) < 5 then self:ignite(character, fire.attacker, 1.5) end
					end
				end
			end
		end
	end
end

-- // New round: everything back (barrels whole, valves ready, doors shut, no fire) --------------------------------------------------
function ArenaShootables:ResetAll()
	for _, b in self.barrels do
		for p, s in b.saved do if p.Parent then p.CanCollide, p.CanQuery = s[1], s[2] end end
		b.saved = {}
		b.exploded = false
		b.model:SetAttribute("Exploded", nil)
		b.model:SetAttribute("FireUntil", nil)
	end
	for _, v in self.valves do
		v.used = false
		v.model:SetAttribute("SteamUntil", nil)
	end
	self.fires = {}
	for character in self.burning do self:extinguish(character) end
	for _, door in self.doors do
		door.open, door.busy = false, false
		door.shutter.CFrame = door.closedCF
		door.prompt.ActionText = "Open"
		door.prompt.Enabled = true
		door.model:SetAttribute("DoorOpen", false)
		door.model:SetAttribute("DoorMoving", false)
		door.model:SetAttribute("DoorAt", now())
	end
end

function ArenaShootables:Destroy()
	self.dead = true
	for character in self.burning do self:extinguish(character) end
	for _, c in self.conns do c:Disconnect() end
end

-- // Light helpers for LobbyDuelManager ---------------------------------------------------------------------------------------------
function ArenaShootables:Contains(position: Vector3): boolean
	local size = self.arena.info and self.arena.info.Size or Vector3.new(200, 60, 200)
	local d = position - self.arena.origin
	return math.abs(d.X) <= size.X / 2 + 20 and math.abs(d.Z) <= size.Z / 2 + 20 and d.Y > -40 and d.Y < size.Y + 60
end

return ArenaShootables
