-- ServerScriptService.Shared.Abilities (ModuleScript, hub + match places) [ABILITY2] 2026-10-19, Edward's weapon identities
-- (notes/weapon_abilities.md, "add them all and their abilities"). The server side of every ability that isn't a plain
-- number in a config. CombatManager / MeleeManager / GadgetManager call in here (fix/abilities_install.lua adds the calls);
-- the victim's client does the movement part (Client.Controllers.AbilityController) through RemoteEvent Combat.AbilityFx.
--
--   guns   Revolver Knockback Shot   a fully aimed-in hit sends the target dashing into the nearest cover (aim cancelled)
--          Pump Shotgun Door Breaker a hit within DoorBreaker.Range knocks the target out of their cover
--          (pellets / shell-by-shell reload: CombatManager + WeaponController; Dual Pistols: WeaponController + config)
--   melee  Fists Vault Takedown      vault into an enemy: 50 damage, ~1 s topple/stun, per-target cooldown
--          Knife Slide Lunge         the first swing during / right after a slide lunges forward for bonus damage
--          Bat Home Run              a charged swing knocks the target back (out of cover, off ledges)
--          Katana Parry              a short window after each swing: bullets from the front are deflected
--          Riot Shield Bulwark       held out it stops bullets from the front (it can break); its bash stuns
--   gadgets Sticky Grenade (sticks, then blows), Landmine (placed, arms, triggers on an enemy), Medkit (heal over a channel)
--
-- Server -> client  Combat.AbilityFx(kind, data):
--   to the victim: "ForceCover" {from, lockout} | "Breach" {from, speed} | "Knockback" {velocity} | "Stun" {time, topple, from}
--   to everyone in the match: "Parry" {position, from} | "ShieldBlock" {position} | "ShieldBreak" {position}
--                             | "Takedown" {position} | "MineArmed" {position} | "MineTrip" {position} | "Heal" {character}
-- Shooter's HitConfirm gets a 6th arg kind = "Takedown" for the takedown (UI: big TAKEDOWN marker); the victim humanoid's
-- LastAttackKind = "Takedown" (kill feed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Modules.Shared
local MeleeConfig = require(Shared.Config.MeleeConfig)
local MatchState do -- lobby duels keep per-match state; the match place uses ReplicatedStorage
	local m = Shared:FindFirstChild("MatchState")
	local ok, res = pcall(function() return m and require(m) end)
	MatchState = ok and res or nil
end
local Combat = ReplicatedStorage.Events.Combat

local Fx = Combat:FindFirstChild("AbilityFx")
if not Fx then
	Fx = Instance.new("RemoteEvent")
	Fx.Name = "AbilityFx"
	Fx.Parent = Combat
end

local A = {}
local FLAT = Vector3.new(1, 0, 1)

-- // Helpers ----------------------------------------------------------------------------------------------------------
local function flatUnit(v: Vector3): Vector3?
	local f = v * FLAT
	return f.Magnitude > 0.05 and f.Unit or nil
end

local function stateOf(player: Player, key: string)
	if MatchState and MatchState.Get then return MatchState.Get(player, key) end
	return ReplicatedStorage:GetAttribute(key)
end

local function combatOn(player: Player): boolean
	return stateOf(player, "CombatEnabled") ~= false
end

-- may `player` hurt `victim`? (same match, not themselves, no friendly fire in a live match)
local function canHurt(player: Player, victim: Model): boolean
	if victim == player.Character then return false end
	if MatchState and MatchState.SameMatch and not MatchState.SameMatch(player, victim) then return false end
	local owner = Players:GetPlayerFromCharacter(victim) or victim
	if stateOf(player, "LiveMatch") and player:GetAttribute("Team") ~= nil and owner:GetAttribute("Team") == player:GetAttribute("Team") then
		return false
	end
	return true
end

local function characters(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(list, p.Character) end end
	for _, b in CollectionService:GetTagged("Bot") do if b.Parent then table.insert(list, b) end end
	return list
end

local function alive(character: Model?): (Humanoid?, BasePart?)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return hum, root :: BasePart end
	return nil, nil
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local function clearBetween(a: Vector3, b: Vector3, ignore: { Instance }): boolean
	losParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(a, b - a, losParams) == nil
end

-- everyone watching this character's match (lobby duel arenas only reach their own audience)
local function fxAll(subject: Instance, kind: string, data)
	if MatchState and MatchState.FireScoped then
		MatchState.FireScoped(Fx, subject, kind, data)
	else
		Fx:FireAllClients(kind, data)
	end
end

-- A push that survives ground friction (bots): the horizontal part is held, easing out, for `time` s
local function shove(root: BasePart, velocity: Vector3, time: number)
	local flat = velocity * FLAT
	root.AssemblyLinearVelocity = velocity
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - t0) / time
		if a >= 1 or not root.Parent then conn:Disconnect() return end
		local f = flat * (1 - a * a)
		root.AssemblyLinearVelocity = Vector3.new(f.X, root.AssemblyLinearVelocity.Y, f.Z)
	end)
end

-- An effect on a victim: players move themselves (their client owns their body); the server moves bots
local function push(victim: Model, kind: string, data)
	local vp = Players:GetPlayerFromCharacter(victim)
	if vp then
		Fx:FireClient(vp, kind, data)
		return
	end
	local hum, root = alive(victim)
	if not hum or not root then return end
	if kind == "Knockback" then
		shove(root, data.velocity, 0.45)
	elseif kind == "Breach" and data.from then
		local away = flatUnit(root.Position - data.from) or root.CFrame.LookVector
		shove(root, away * (data.speed or 40) + Vector3.new(0, 10, 0), 0.35)
	elseif kind == "Stun" then
		victim:SetAttribute("StunnedUntil", os.clock() + (data.time or 1))
		if data.topple then hum:ChangeState(Enum.HumanoidStateType.FallingDown) end
	end
end

-- Damage from an ability (same bookkeeping as CombatManager / MeleeManager: kill credit, hit marker, damage direction)
local function hurt(attacker: Player, victim: Model, amount: number, attackKind: string, confirmKind: string?)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or amount <= 0 then return end
	hum:SetAttribute("LastAttacker", attacker.UserId)
	hum:SetAttribute("LastAttackKind", attackKind)
	hum:SetAttribute("LastAttackWeapon", attackKind == "Takedown" and "Fists" or attackKind) -- [KILLFEED] the item, for the kill feed icon
	hum:SetAttribute("LastNoScope", nil)
	hum:SetAttribute("LastHitZone", "Body")
	hum:TakeDamage(amount)
	local confirm = Combat:FindFirstChild("HitConfirm")
	if confirm then confirm:FireClient(attacker, "Body", amount, hum.Health <= 0, false, confirmKind) end
	local root = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	local vp = Players:GetPlayerFromCharacter(victim)
	local taken = Combat:FindFirstChild("DamageTaken")
	if vp and taken and root then taken:FireClient(vp, root.Position, amount) end
	local onHit = victim:FindFirstChild("OnHit") -- firing-range dummies show the numbers
	if onHit and onHit:IsA("BindableEvent") then onHit:Fire(attacker, "Body", amount, 0, attackKind) end
end

-- // Bullets: parry, shield, knockback, door breaker -------------------------------------------------------------------
local parryWindows = setmetatable({}, { __mode = "k" }) -- [Model] = { from, to, cos }
local breachAt = setmetatable({}, { __mode = "k" })     -- [Model] = os.clock() of the last breach (one per shotgun blast)
local knockAt = setmetatable({}, { __mode = "k" })

-- Called by CombatManager for a validated hit, after the damage is worked out and before it's applied.
-- Returns a reason string if the bullet was stopped (no damage), else nil (and the on-hit abilities have fired).
function A.BulletHit(shooter: Player, config, victim: Model, origin: Vector3, hitPosition: Vector3, damage: number, distance: number, extra: any): string?
	local hum, root = alive(victim)
	if not hum or not root then return nil end
	local toShooter = flatUnit(origin - root.Position)
	local facing = flatUnit(root.CFrame.LookVector)
	local cosToShooter = (toShooter and facing) and facing:Dot(toShooter) or -1
	local now = os.clock()

	-- Katana Parry: a bullet from the front inside the window after a swing is deflected
	local w = parryWindows[victim]
	if w and now >= w.from and now <= w.to and cosToShooter >= w.cos then
		fxAll(victim, "Parry", { position = hitPosition, from = origin })
		return "parried (katana)"
	end

	-- Riot Shield: held out, it takes bullets from the front until it breaks
	local tool = victim:FindFirstChildOfClass("Tool")
	local melee = tool and tool:GetAttribute("Melee") and MeleeConfig.Weapons[tool:GetAttribute("MeleeId") or ""]
	if melee and melee.Shield and not tool:GetAttribute("ShieldBroken") and cosToShooter >= math.cos(math.rad(melee.Shield.Angle)) then
		local left = (tool:GetAttribute("ShieldHealth") or melee.Shield.Health) - damage
		tool:SetAttribute("ShieldHealth", math.max(left, 0))
		if left <= 0 then
			tool:SetAttribute("ShieldBroken", true)
			fxAll(victim, "ShieldBreak", { position = hitPosition })
			-- the slab falls off: what's left is the grip
			for _, p in tool:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "Handle" then p.Transparency = 1 end
			end
		else
			fxAll(victim, "ShieldBlock", { position = hitPosition, from = origin })
		end
		return "blocked by the riot shield"
	end

	if hum.Health - damage <= 0 then return nil end -- it kills: nothing else to do

	-- Revolver Knockback Shot: a fully aimed-in hit sends the target dashing into the nearest cover
	local aimed = type(extra) == "table" and extra.aimed == true
	local raised = shooter.Character and shooter.Character:GetAttribute("AimRaised")
	if config.Knockback and aimed and raised ~= false and now - (knockAt[victim] or 0) > 0.3 then
		knockAt[victim] = now
		push(victim, "ForceCover", { from = origin, lockout = config.Knockback.Lockout })
	end

	-- Pump Shotgun Door Breaker: point blank knocks them out of their cover (once per blast, not per pellet)
	if config.DoorBreaker and distance <= config.DoorBreaker.Range and now - (breachAt[victim] or 0) > 0.3 then
		breachAt[victim] = now
		push(victim, "Breach", { from = origin, speed = config.DoorBreaker.Push })
	end
	return nil
end

-- // Shell-by-shell reload (Pump Shotgun) -------------------------------------------------------------------------------
-- CombatManager.onReload hands over here when config.ShellReload is set. One shell every ShellTime until the tube is full,
-- the spares run out, or the reload is cancelled (a shot, holstering: reloadToken changes).
function A.ShellReload(player: Player, tool: Tool, state, sync: (Tool, any) -> ())
	local R = state.config.ShellReload
	state.reloading = true
	state.reloadToken += 1
	local token = state.reloadToken
	sync(tool, state)
	task.spawn(function()
		task.wait(R.StartDelay or 0)
		while state.reloadToken == token and state.reloading do
			task.wait(R.ShellTime)
			if state.reloadToken ~= token or not state.reloading then return end
			if tool.Parent ~= player.Character then break end
			if state.ammo >= state.config.MagazineSize or state.reserve <= 0 then break end
			state.ammo += 1
			if not stateOf(player, "InfiniteAmmo") then state.reserve -= 1 end
			sync(tool, state)
			if state.ammo >= state.config.MagazineSize or state.reserve <= 0 then break end
		end
		if state.reloadToken == token then
			state.reloading = false
			sync(tool, state)
		end
	end)
end

-- // Melee -------------------------------------------------------------------------------------------------------------
local lastSwingAt = {} -- [Player] = os.clock() of the last accepted swing (for the bat's charge)
local lastLungeAt = {} -- [Player] = os.clock() of the last knife lunge
-- a lunge comes out of a slide: the body must be moving faster than a walk (sprint / slide / the lunge itself)
local WALK = (function()
	local ok, M = pcall(function() return require(Shared.Config.MovementConfig) end)
	return ok and M.Speeds and M.Speeds.Walk or 14
end)()
local function movingFast(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.AssemblyLinearVelocity * FLAT).Magnitude > WALK + 2
end
local takedownAt = {}  -- [Player] = os.clock()
local takedownTargets = setmetatable({}, { __mode = "k" }) -- [Model victim] = { [Player] = os.clock() }

-- Called by MeleeManager.onSwing once the swing is accepted (after its cooldown check).
-- Returns the extra reach / damage for this swing.
function A.SwingExtra(player: Player, weapon, kind: any)
	local now = os.clock()
	local e = { range = 0, damage = 0 }
	local previous = lastSwingAt[player] or 0
	lastSwingAt[player] = now
	if kind == "Lunge" and weapon.Lunge and now - (lastLungeAt[player] or 0) > 1.5 and movingFast(player) then
		lastLungeAt[player] = now
		e.range, e.damage, e.lunge = weapon.Lunge.Distance, weapon.Lunge.Bonus, true
	elseif kind == "Charged" and weapon.Charge and now - previous >= weapon.Charge.Time then
		e.damage, e.charged = weapon.Charge.Damage - weapon.Damage, true
	end
	if weapon.Parry and player.Character then
		parryWindows[player.Character] = {
			from = now + weapon.HitDelay,
			to = now + weapon.HitDelay + weapon.Parry.Window,
			cos = math.cos(math.rad(weapon.Parry.Angle)),
		}
		player.Character:SetAttribute("ParryUntil", workspace:GetServerTimeNow() + weapon.HitDelay + weapon.Parry.Window)
	end
	return e
end

-- Called by MeleeManager.onSwing after the damage is applied to `victim`.
function A.MeleeHit(player: Player, weapon, extra, victim: Model, attackerRoot: BasePart)
	local hum, root = alive(victim)
	if not hum or not root then return end
	if extra and extra.charged and weapon.Charge then
		local away = flatUnit(root.Position - attackerRoot.Position) or attackerRoot.CFrame.LookVector
		push(victim, "Knockback", { velocity = away * weapon.Charge.Knockback + Vector3.new(0, weapon.Charge.Lift, 0) })
	end
	if weapon.BashStun then
		push(victim, "Stun", { time = weapon.BashStun, from = attackerRoot.Position })
	end
end

-- Fists Vault Takedown (MeleeManager: the Melee remote with kind "Takedown", sent by the vaulting player's client on landing)
function A.Takedown(player: Player)
	if not combatOn(player) then return end
	local id = player:GetAttribute("KitMelee")
	if type(id) ~= "string" or not MeleeConfig.Weapons[id] then id = MeleeConfig.Default end
	local cfg = MeleeConfig.Weapons[id].Takedown
	if not cfg then return end
	local character = player.Character
	local hum, root = alive(character)
	if not hum or not root then return end
	local now = os.clock()
	if now - (takedownAt[player] or 0) < 3 then return end -- (one every 3 s; 8 s per target)
	local best, bestDist = nil, (cfg.Radius or 5) + 1.5 -- lag allowance
	for _, other in characters() do
		local oh, orp = alive(other)
		if oh and orp and canHurt(player, other) then
			local d = (orp.Position - root.Position).Magnitude
			local last = takedownTargets[other] and takedownTargets[other][player]
			if d < bestDist and (not last or now - last >= cfg.TargetCooldown)
				and clearBetween(root.Position, orp.Position, { character :: Model, other }) then
				best, bestDist = other, d
			end
		end
	end
	if not best then return end
	takedownAt[player] = now
	takedownTargets[best] = takedownTargets[best] or {}
	takedownTargets[best][player] = now
	local _, victimRoot = alive(best)
	hurt(player, best, cfg.Damage, "Takedown", "Takedown")
	push(best, "Stun", { time = cfg.Stun, topple = true, from = root.Position })
	fxAll(character :: Model, "Takedown", { position = victimRoot and victimRoot.Position or root.Position })
end

-- // Gadgets -----------------------------------------------------------------------------------------------------------
local function shootables()
	return shared.Get and shared.Get("ShootableManager")
end
local function explode(position: Vector3, kind: string, player: Player)
	local S = shootables()
	if not S then return end
	local ok, has = pcall(function() return require(Shared.Config.ShootableConfig).Explosions[kind] ~= nil end)
	S.Explode(position, (ok and has) and kind or "Frag", player)
end

local function beep(parent: Instance, pitch: number, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://9117197553"
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 3
	s.RollOffMaxDistance = 35
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 2)
end

local function bodyParts(except: Model?): { BasePart }
	local out = {}
	for _, c in characters() do
		if c ~= except then
			for _, p in c:GetDescendants() do if p:IsA("BasePart") then table.insert(out, p) end end
		end
	end
	return out
end

-- Sticky Grenade: thrown like a frag; the first thing it touches (wall, floor, a body) it sticks to, then it blows
local function throwSticky(player: Player, cfg, direction: Vector3, power: number, side: number, launchVelocity)
	local character = player.Character
	local hum, root = alive(character)
	local head = character and character:FindFirstChild("Head")
	if not hum or not root or not head then return end
	local g = Instance.new("Part")
	g.Name = "StickyGrenade" -- (GadgetManager.ClearAll removes "...Grenade" parts between rounds)
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.one * 0.55
	g.Color = Color3.fromRGB(70, 110, 60)
	g.Material = Enum.Material.SmoothPlastic
	g.CanQuery = false
	g.CustomPhysicalProperties = PhysicalProperties.new(2, 2, 0, 1, 1)
	local origin = head.Position
	if side and side ~= 0 then
		local right = direction:Cross(Vector3.yAxis)
		if right.Magnitude > 0.05 then
			local offset = right.Unit * side * 1.7
			if clearBetween(origin, origin + offset, { character :: Model }) then origin += offset end
		end
	end
	g.CFrame = CFrame.new(origin + direction * 1.5)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 255, 90)
	light.Range = 4
	light.Brightness = 2
	light.Parent = g
	g.Parent = workspace
	g:SetNetworkOwner(nil)
	g.AssemblyLinearVelocity = launchVelocity(cfg, direction, power)
	-- it doesn't stick to the thrower
	for _, p in (character :: Model):GetDescendants() do
		if p:IsA("BasePart") then
			local c = Instance.new("NoCollisionConstraint")
			c.Part0, c.Part1 = g, p
			c.Parent = g
		end
	end
	local stuck = false
	local function stick(to: BasePart)
		if stuck or not g.Parent then return end
		stuck = true
		g.AssemblyLinearVelocity = Vector3.zero
		if to.Anchored then
			g.Anchored = true
		else
			g.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = g, to
			w.Parent = g
		end
		beep(g, 1.6, 0.6)
	end
	g.Touched:Connect(function(other)
		if other:IsDescendantOf(character :: Model) or not other.CanCollide then return end
		stick(other)
	end)
	-- bodies: grenades normally pass through them; a sticky grabs on when it gets close
	local bodyParams = OverlapParams.new()
	bodyParams.FilterType = Enum.RaycastFilterType.Include
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if stuck or not g.Parent then conn:Disconnect() return end
		bodyParams.FilterDescendantsInstances = bodyParts(character)
		local near = workspace:GetPartBoundsInRadius(g.Position, 0.9, bodyParams)
		if near[1] then stick(near[1]) end
	end)
	-- the fuse: faster beeps toward the end
	task.spawn(function()
		local t0 = os.clock()
		while g.Parent and os.clock() - t0 < cfg.FuseTime do
			local left = cfg.FuseTime - (os.clock() - t0)
			beep(g, 2.2, 0.35)
			light.Brightness = 4
			task.wait(0.06)
			light.Brightness = 1
			task.wait(math.clamp(left * 0.25, 0.08, 0.4))
		end
		if not g.Parent then return end
		local position = g.Position
		g:Destroy()
		explode(position, "StickyGrenade", player)
	end)
end

-- Landmine: dropped at your feet ahead of you; arms after ArmTime; an enemy within TriggerRadius sets it off
local mines = {} -- [Player] = { mine part }
local function placeMine(player: Player, cfg)
	local character = player.Character
	local hum, root = alive(character)
	if not hum or not root then return end
	local look = flatUnit(root.CFrame.LookVector) or Vector3.zAxis
	local from = root.Position + look * 2 + Vector3.new(0, 1, 0)
	losParams.FilterDescendantsInstances = characters()
	local floor = workspace:Raycast(from, Vector3.new(0, -8, 0), losParams)
	if not floor then return end
	local mine = Instance.new("Part")
	mine.Name = "LandmineGrenade" -- (cleared between rounds with the grenades)
	mine.Shape = Enum.PartType.Cylinder
	mine.Size = Vector3.new(0.22, 1.3, 1.3)
	mine.CFrame = CFrame.new(floor.Position + Vector3.new(0, 0.11, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mine.Anchored, mine.CanCollide, mine.CanQuery, mine.CanTouch = true, false, false, false
	mine.Color = Color3.fromRGB(58, 62, 52)
	mine.Material = Enum.Material.Metal
	mine:SetAttribute("Owner", player.UserId)
	local led = Instance.new("Part")
	led.Name = "LED"
	led.Shape = Enum.PartType.Ball
	led.Size = Vector3.one * 0.18
	led.CFrame = mine.CFrame * CFrame.new(0.13, 0, 0)
	led.Anchored, led.CanCollide, led.CanQuery, led.CanTouch = true, false, false, false
	led.Material = Enum.Material.Neon
	led.Color = Color3.fromRGB(60, 60, 60)
	led.Parent = mine
	mine.Parent = workspace
	mines[player] = mines[player] or {}
	table.insert(mines[player], mine)
	beep(mine, 1.2, 0.4)
	task.delay(cfg.ArmTime, function()
		if not mine.Parent then return end
		led.Color = Color3.fromRGB(255, 40, 30)
		beep(mine, 1.9, 0.3)
		fxAll(character :: Model, "MineArmed", { position = mine.Position })
		local conn
		local nextCheck = 0
		conn = RunService.Heartbeat:Connect(function()
			if not mine.Parent then conn:Disconnect() return end
			if os.clock() < nextCheck then return end
			nextCheck = os.clock() + 0.1
			for _, other in characters() do
				local _, orp = alive(other)
				if orp and other ~= player.Character and player.Parent and canHurt(player, other)
					and (orp.Position - mine.Position).Magnitude <= cfg.TriggerRadius then
					conn:Disconnect()
					fxAll(mine, "MineTrip", { position = mine.Position })
					beep(mine, 2.6, 0.8)
					task.delay(cfg.TriggerDelay, function()
						if not mine.Parent then return end
						local position = mine.Position
						mine:Destroy()
						explode(position, "Landmine", player)
					end)
					return
				end
			end
		end)
	end)
end

-- Medkit: heal over a channel. Taking damage stops it. Player attribute MedkitUntil (server time) while channelling.
local channels = {} -- [Player] = token
local function useMedkit(player: Player, cfg)
	local hum, root = alive(player.Character)
	if not hum or not root or channels[player] then return end
	if hum.Health >= hum.MaxHealth then return end
	local token = {}
	channels[player] = token
	player:SetAttribute("MedkitUntil", workspace:GetServerTimeNow() + cfg.ChannelTime)
	fxAll(player.Character :: Model, "Heal", { character = player.Character })
	task.spawn(function()
		local steps = math.max(1, math.floor(cfg.ChannelTime / 0.25))
		local per = cfg.Heal / steps
		local last = hum.Health
		for _ = 1, steps do
			task.wait(cfg.ChannelTime / steps)
			if channels[player] ~= token or hum.Health <= 0 or hum.Health < last - 0.01 then break end -- hit: stopped
			hum.Health = math.min(hum.MaxHealth, hum.Health + per)
			last = hum.Health
		end
		if channels[player] == token then channels[player] = nil end
		player:SetAttribute("MedkitUntil", nil)
	end)
end

-- Called by GadgetManager.onThrow after the charge is spent. True = handled here (not a plain grenade).
function A.Gadget(player: Player, gadget: string, cfg, direction: Vector3, power: number, mode: string, side: number, launchVelocity): boolean
	if gadget == "StickyGrenade" then
		throwSticky(player, cfg, direction, power, side, launchVelocity)
		return true
	elseif gadget == "Landmine" then
		placeMine(player, cfg)
		return true
	elseif gadget == "Medkit" then
		useMedkit(player, cfg)
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	lastSwingAt[player], takedownAt[player], channels[player], lastLungeAt[player] = nil, nil, nil, nil
	for _, m in mines[player] or {} do if m.Parent then m:Destroy() end end
	mines[player] = nil
end)

return A
