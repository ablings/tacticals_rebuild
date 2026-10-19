-- fix/abilities_install.lua [ABILITY2] 2026-10-19, Phases 2 + 3 of Edward's weapon identities (notes/weapon_abilities.md:
-- "add them all and their abilities"). Both places (hub + match), Edit mode. Run after fix/weapon_abilities.lua (phase 1).
-- Built by tools/abilities_build.py (embeds scripts/abilities/* below). Idempotent; UNDO swaps every edit back and removes
-- the two modules.
--   installs  ServerScriptService.Shared.Abilities, Client.Controllers.AbilityController
--   configs   WeaponConfig: Shotgun class, PumpShotgun, DualPistols, Revolver Knockback, Mobility() for melee too, Loadout
--             MeleeConfig: Knife Lunge, Fists Takedown, Bat (Charge), Katana (Parry), RiotShield (Shield, BashStun, MoveSpeed)
--             GadgetConfig: StickyGrenade (thrown), Landmine (Use = "Place"), Medkit (Use = "Channel")
--             ShootableConfig: StickyGrenade / Landmine blasts; LobbyConfig (every copy): the 8 new items
--   managers  CombatManager: extra arg (aimed / pellet), pellets, Dual Pistols moving fire rate, shell reload, BulletHit
--             MeleeManager: Takedown, SwingExtra (lunge / charge / parry window), MeleeHit; GadgetManager: any kit gadget
--   repo      every Repository.Weapons / .Melee template's WeaponId / MeleeId = its own name (Pistol said "Revolver")
local UNDO = false --@UNDO
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.Abilities = [=[-- ServerScriptService.Shared.Abilities (ModuleScript, hub + match places) [ABILITY2] 2026-10-19, Edward's weapon identities
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
]=]
SOURCES.AbilityController = [=[-- StarterPlayer.StarterPlayerScripts.Client.Controllers.AbilityController (ModuleScript, hub + match) [ABILITY2] 2026-10-19
-- The client half of the weapon abilities (server: ServerScriptService.Shared.Abilities). Combat.AbilityFx tells this
-- client what happened to it, and everyone what to show:
--   ForceCover  (Revolver Knockback Shot) you dash into the nearest cover on the far side from the shooter; aim / peek locked
--   Breach      (Pump Shotgun Door Breaker) you're knocked out of your cover, away from the shooter
--   Knockback   (Bat Home Run) you're launched by the given velocity
--   Stun        (Fists takedown topple, Riot Shield bash) slowed, can't aim or shoot (attribute NoFireUntil) for a moment
--   Parry / ShieldBlock / ShieldBreak / Takedown / MineArmed / MineTrip / Heal: sparks, clangs and thuds where they happen
-- It also keeps player attribute RevolverReady (true while the Revolver is fully aimed in: the UI's gold crosshair ring,
-- and what WeaponController sends as "aimed"), and fires the Fists takedown when a vault lands next to an enemy
-- (CoverController calls OnVaultLanded).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local MeleeConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeleeConfig"))
local WeaponConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponConfig"))
local Combat = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat")
local Get = shared.Get
local FLAT = Vector3.new(1, 0, 1)

local controller = {}
local WAIST = (function()
	local ok, C = pcall(function() return require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig")) end)
	return ok and C.WaistHeight or -0.5
end)()

local REVOLVER_SETTLE = 0.25 -- seconds aimed in before the Revolver counts as fully aimed
local CLANG = "rbxassetid://9117197553"
local THUD = "rbxassetid://12222216"

-- // Helpers
local function myParts()
	local c = localPlayer.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return c, hum, root :: BasePart end
	return nil, nil, nil
end

local function flatUnit(v: Vector3): Vector3?
	local f = v * FLAT
	return f.Magnitude > 0.05 and f.Unit or nil
end

local function soundAt(position: Vector3, id: string, volume: number, pitch: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 90
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 2)
end

local function sparks(position: Vector3, color: Color3, count: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.25, 0)
	e.Lifetime = NumberRange.new(0.15, 0.35)
	e.Speed = NumberRange.new(12, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 8
	l.Brightness = 4
	l.Parent = a
	task.delay(0.08, function() l.Enabled = false end)
	Debris:AddItem(a, 1)
end

local function shake(strength: number)
	local Camera = Get("CameraController")
	if Camera and Camera.AddRecoil then
		Camera.AddRecoil(strength, (math.random() - 0.5) * strength * 1.4, 6)
	end
end

-- slowed + no aim / no fire for `time` seconds
local function stun(time: number, scale: number?)
	local now = os.clock()
	localPlayer:SetAttribute("StunUntil", math.max(localPlayer:GetAttribute("StunUntil") or 0, now + time))
	localPlayer:SetAttribute("StunScale", scale or 0.25)
	localPlayer:SetAttribute("NoFireUntil", math.max(localPlayer:GetAttribute("NoFireUntil") or 0, now + time))
	local Cover = Get("CoverController")
	if Cover and Cover.Suppress then pcall(Cover.Suppress, time) end
end

-- // Forced moves
local coverParams = OverlapParams.new()
coverParams.FilterType = Enum.RaycastFilterType.Exclude

local function coverCandidates(root: BasePart, from: Vector3): { { part: BasePart, stand: Vector3, d: number } }
	local list = {}
	local exclude = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(exclude, p.Character) end end
	for _, b in CollectionService:GetTagged("Bot") do table.insert(exclude, b) end
	coverParams.FilterDescendantsInstances = exclude
	local away = flatUnit(root.Position - from) or root.CFrame.LookVector
	local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local feetY = root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
	for _, part in workspace:GetPartBoundsInRadius(root.Position, 26, coverParams) do
		if part.Anchored and part.CanCollide and part.Transparency < 0.9 then
			local half = part.Size / 2
			local top = part.Position.Y + math.abs(half.Y)
			local bottom = part.Position.Y - math.abs(half.Y)
			-- waist-high or taller, standing on your floor, not a huge slab (floors, the map's outer walls)
			-- the cover system casts at waist height: the top must clear it
			if top > root.Position.Y + WAIST + 0.4 and bottom < feetY + 1 and part.Size.X < 40 and part.Size.Z < 40 then
				local reach = math.max(part.Size.X, part.Size.Z) / 2 + 2
				local stand = Vector3.new(part.Position.X, root.Position.Y, part.Position.Z) + away * reach
				local d = ((part.Position - root.Position) * FLAT).Magnitude
				-- prefer cover that's between you and the shooter... or at least not past them
				local toPart = flatUnit(part.Position - root.Position)
				local fromDir = flatUnit(from - root.Position)
				local penalty = (toPart and fromDir and toPart:Dot(fromDir) > 0.6) and 6 or 0
				table.insert(list, { part = part, stand = stand, d = d + penalty })
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	return list
end

local function debug(...)
	if localPlayer:GetAttribute("AbilityDebug") then print("[AbilityController]", ...) end
end

local function forceCover(data)
	local _, _, root = myParts()
	if not root or typeof(data.from) ~= "Vector3" then return debug("ForceCover: no root / from") end
	local Cover = Get("CoverController")
	if not Cover then return debug("ForceCover: no CoverController") end
	local lockout = data.lockout or 0.6
	-- in cover already: knocked back into it (the peek is cancelled)
	if Cover.IsInCover() then
		pcall(Cover.Suppress, lockout)
		shake(2.5)
		return
	end
	if Cover.IsMoving() then return debug("ForceCover: already moving") end
	local list = coverCandidates(root, data.from)
	debug("ForceCover:", #list, "candidates")
	for i, c in list do
		if i > 6 then break end
		local ok, moved = pcall(Cover.ForceRush, c.part, c.stand)
		debug("  ", c.part:GetFullName(), ok, moved, Cover._lastRushError, "inCover", Cover.IsInCover(), "dist", math.floor(c.d))
		if ok and moved then
			pcall(Cover.Suppress, lockout + 0.5) -- no aiming on the way in or for a moment after
			shake(2.5)
			return
		end
	end
	-- nothing to dash to: just the flinch
	pcall(Cover.Suppress, lockout)
	shake(2.5)
end

-- A push that survives ground friction: the horizontal part is held (easing out) for `time` s, the lift is one impulse
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

local function breach(data)
	local _, hum, root = myParts()
	if not root or not hum or typeof(data.from) ~= "Vector3" then return end
	local Cover = Get("CoverController")
	if Cover and Cover.IsInCover() then Cover.LeaveCover() end
	local away = flatUnit(root.Position - data.from) or -root.CFrame.LookVector
	shove(root, away * (data.speed or 40) + Vector3.new(0, 10, 0), 0.35)
	stun(0.5, 0.6)
	shake(4)
end

local function knockback(data)
	local _, hum, root = myParts()
	if not root or not hum or typeof(data.velocity) ~= "Vector3" then return end
	local Cover = Get("CoverController")
	if Cover and Cover.IsInCover() then Cover.LeaveCover() end
	shove(root, data.velocity, 0.45)
	stun(0.6, 0.5)
	shake(5)
end

local function stunned(data)
	local _, hum = myParts()
	if not hum then return end
	local time = data.time or 1
	stun(time, 0.2)
	shake(data.topple and 6 or 3)
	if data.topple then
		local Cover = Get("CoverController")
		if Cover and Cover.IsInCover() then Cover.LeaveCover() end
		hum:ChangeState(Enum.HumanoidStateType.FallingDown)
		task.delay(time, function()
			if hum.Parent and hum.Health > 0 and hum:GetState() == Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
end

-- // Fists Vault Takedown: called by CoverController when a vault lands
local lastTakedown = 0
function controller.OnVaultLanded()
	local character, _, root = myParts()
	if not root then return end
	local id = localPlayer:GetAttribute("KitMelee")
	if type(id) ~= "string" or not MeleeConfig.Weapons[id] then id = MeleeConfig.Default end
	local cfg = MeleeConfig.Weapons[id] and MeleeConfig.Weapons[id].Takedown
	if not cfg or os.clock() - lastTakedown < 1 then return end
	local list = {}
	for _, p in Players:GetPlayers() do if p.Character and p.Character ~= character then table.insert(list, p.Character) end end
	for _, b in CollectionService:GetTagged("Bot") do table.insert(list, b) end
	for _, other in list do
		local r = other:FindFirstChild("HumanoidRootPart")
		local h = other:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (r.Position - root.Position).Magnitude <= cfg.Radius then
			lastTakedown = os.clock()
			Combat:WaitForChild("Melee"):FireServer("Takedown")
			return
		end
	end
end

-- // Revolver: fully aimed in
local aimedSince: number? = nil
local function updateRevolverReady()
	local character = localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local config = tool and WeaponConfig.Get(tool:GetAttribute("WeaponId") or "")
	local Camera = Get("CameraController")
	local aiming = config and config.Knockback and Camera and Camera.IsAiming and Camera.IsAiming()
	if aiming then
		aimedSince = aimedSince or os.clock()
	else
		aimedSince = nil
	end
	local settle = (config and config.Knockback and config.Knockback.AimTime) or REVOLVER_SETTLE
	local ready = aimedSince ~= nil and os.clock() - aimedSince >= settle
	if (localPlayer:GetAttribute("RevolverReady") == true) ~= ready then
		localPlayer:SetAttribute("RevolverReady", ready or nil)
	end
end

function controller.Start()
	local Fx = Combat:WaitForChild("AbilityFx", 30)
	if Fx then
		Fx.OnClientEvent:Connect(function(kind, data)
			if type(data) ~= "table" then data = {} end
			if kind == "ForceCover" then forceCover(data)
			elseif kind == "Breach" then breach(data)
			elseif kind == "Knockback" then knockback(data)
			elseif kind == "Stun" then stunned(data)
			elseif kind == "Parry" and typeof(data.position) == "Vector3" then
				sparks(data.position, Color3.fromRGB(255, 230, 150), 26)
				soundAt(data.position, CLANG, 1, 1.35)
			elseif kind == "ShieldBlock" and typeof(data.position) == "Vector3" then
				sparks(data.position, Color3.fromRGB(255, 210, 120), 10)
				soundAt(data.position, CLANG, 0.7, 0.75)
			elseif kind == "ShieldBreak" and typeof(data.position) == "Vector3" then
				sparks(data.position, Color3.fromRGB(200, 220, 255), 40)
				soundAt(data.position, CLANG, 1.2, 0.45)
			elseif kind == "Takedown" and typeof(data.position) == "Vector3" then
				soundAt(data.position, THUD, 1.2, 0.45)
				sparks(data.position, Color3.fromRGB(240, 240, 240), 8)
			elseif kind == "MineArmed" and typeof(data.position) == "Vector3" then
				soundAt(data.position, CLANG, 0.25, 2.2)
			elseif kind == "MineTrip" and typeof(data.position) == "Vector3" then
				soundAt(data.position, CLANG, 0.9, 2.8)
			elseif kind == "Heal" and typeof(data.character) == "Instance" then
				local root = data.character:FindFirstChild("HumanoidRootPart")
				if root then sparks(root.Position, Color3.fromRGB(90, 255, 140), 14) end
			end
		end)
	end
	RunService.Heartbeat:Connect(updateRevolverReady)
	localPlayer.CharacterAdded:Connect(function()
		localPlayer:SetAttribute("NoFireUntil", nil)
		localPlayer:SetAttribute("RevolverReady", nil)
	end)
end

return controller
]=]
--@@END SOURCES

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Cfg = RS.Modules.Shared.Config
local Mg = SSS.ServerScripts["[Server] Init"].GameManager.Managers
local Controllers = game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers

local WEAPON_BLOCK = [==[
-- [ABILITY2] 2026-10-19 the rest of Edward's weapon identities (notes/weapon_abilities.md)
-- Shotguns: a blast of pellets (Pellets rays in a PelletSpread cone; one shell), brutal up close, nothing at range.
WeaponConfig.Classes.Shotgun = {
	FireMode = "Semi",
	Loudness = 1.1,
	HipFireSpread = 2,
	BlindFireSpread = 6,
	VaultFireSpread = 12,
	HipFireFaceTime = 0.5,
	CasingEject = "Fire",
	AllowedAttachments = {},
	MoveSpeed = 0.91,
	AimMoveSpeed = 0.8,
}
-- Revolver Knockback Shot: a hit while fully aimed in (aimed AimTime s: player attribute RevolverReady) sends the target
-- dashing into the nearest cover; their aim / peek is locked for Lockout s
WeaponConfig.Weapons.Revolver.Knockback = { AimTime = 0.25, Lockout = 0.8 }
-- Pump Shotgun Door Breaker: a hit within DoorBreaker.Range studs knocks the target out of cover (Push studs/s).
-- ShellReload: one shell every ShellTime (after StartDelay); a shot cuts the reload short.
WeaponConfig.Weapons.PumpShotgun = {
	Class = "Shotgun",
	DisplayName = "PUMP SHOTGUN",
	ToolName = "PumpShotgun",
	MagazineSize = 6,
	ReserveAmmo = 30,
	FireInterval = 0.85, -- the pump
	ReloadTime = 0.5, -- per shell (ShellReload)
	ShellReload = { ShellTime = 0.5, StartDelay = 0.2 },
	Range = 120,
	Pellets = 8,
	PelletSpread = 4.5, -- degrees: the cone the pellets fill around where you aim (aimed); hip fire adds HipFireSpread
	Damage = { Head = 30, Body = 18 }, -- per pellet
	Falloff = { Start = 6, End = 28, Min = 0.25 },
	MoveSpeed = 0.91,
	DoorBreaker = { Range = 6, Push = 42 },
	Recoil = { Pitch = 5, YawMin = -1, YawMax = 1, Recovery = 7 },
	Animations = table.clone(NO_ANIMS),
	AnimationSourcePrefix = "Pistol",
	Effects = {
		TracerColor = Color3.fromRGB(255, 215, 150), TracerWidth = 0.03, TracerTime = 0.04,
		Muzzle = muzzle(1.6, 5, 3, 12, 8, 10, 16, true, { SideJets = true }),
		GasPuff = 0,
	},
}
-- Dual Pistols Akimbo: no aiming in (NoAim), hip fire dead accurate, twice the fire rate while moving (MovingFireInterval)
WeaponConfig.Weapons.DualPistols = {
	Class = "Pistol",
	DisplayName = "DUAL PISTOLS",
	ToolName = "DualPistols",
	MagazineSize = 24,
	ReserveAmmo = 96,
	FireInterval = 0.24,
	MovingFireInterval = 0.12,
	ReloadTime = 1.4,
	Range = 220,
	HipFireSpread = 0,
	NoAim = true,
	Akimbo = true, -- shots alternate between the two muzzles (Barrel / LeftBarrel)
	Damage = { Head = 44, Body = 22 },
	Falloff = { Start = 25, End = 90, Min = 0.5 },
	MoveSpeed = 1.04,
	Recoil = { Pitch = 1.3, YawMin = -0.7, YawMax = 0.7, Recovery = 13 },
	Animations = table.clone(NO_ANIMS),
	AnimationSourcePrefix = "Pistol",
	Effects = {
		TracerColor = Color3.fromRGB(255, 225, 165), TracerWidth = 0.04, TracerTime = 0.05,
		Muzzle = muzzle(1.0, 3, 2, 6, 4, 6, 11, true),
		GasPuff = 0,
	},
}

-- Movement multiplier of what this character is holding: a gun's MoveSpeed, a melee item's MoveSpeed (the riot shield
-- is heavy), else 1
function WeaponConfig.Mobility(character: Model?): number
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool then return 1 end
	local config = WeaponConfig.Weapons[tool:GetAttribute("WeaponId") or ""]
	if config then return config.MoveSpeed or 1 end
	local meleeId = tool:GetAttribute("MeleeId")
	if meleeId then
		local ok, melee = pcall(function() return require(script.Parent.MeleeConfig).Weapons[meleeId] end)
		if ok and melee and melee.MoveSpeed then return melee.MoveSpeed end
	end
	return 1
end

]==]

local MELEE_BLOCK = [==[

-- [ABILITY2] 2026-10-19 Edward's melee identities (notes/weapon_abilities.md)
-- Knife Slide Lunge: the first swing during or within Window s after a slide lunges Distance studs forward, +Bonus damage
MeleeConfig.Weapons.Knife.Lunge = { Window = 0.45, Distance = 6, Bonus = 25, Time = 0.16 }
-- Fists Vault Takedown: land a vault within Radius studs of an enemy: Damage, Stun s topple; once per TargetCooldown per target
MeleeConfig.Weapons.Fists.Takedown = { Damage = 50, Radius = 5, Stun = 1.0, TargetCooldown = 8 }
-- Bat Home Run: hold the swing Charge.Time s; a charged hit does Charge.Damage and knocks them back (studs/s) and up
MeleeConfig.Weapons.Bat = {
	DisplayName = "BAT",
	Tool = "Bat",
	Damage = 35,
	Range = 6.5,
	Angle = 70,
	Cooldown = 0.75,
	HitDelay = 0.16,
	Animation = "",
	AnimationSource = "MeleeSlash",
	Charge = { Time = 0.8, Damage = 60, Knockback = 55, Lift = 22 },
}
-- Katana Parry: for Parry.Window s after each swing connects, bullets from within Parry.Angle of the front are deflected
MeleeConfig.Weapons.Katana = {
	DisplayName = "KATANA",
	Tool = "Katana",
	Damage = 55,
	Range = 7,
	Angle = 75,
	Cooldown = 0.65,
	HitDelay = 0.12,
	Animation = "",
	AnimationSource = "MeleeSlash",
	Parry = { Window = 0.35, Angle = 70 },
}
-- Riot Shield Bulwark: held out it stops bullets from within Shield.Angle of the front until it has soaked Shield.Health
-- (then it breaks for that life). Slow to carry (MoveSpeed). Its bash stuns for BashStun s.
MeleeConfig.Weapons.RiotShield = {
	DisplayName = "RIOT SHIELD",
	Tool = "RiotShield",
	Damage = 15,
	Range = 5.5,
	Angle = 70,
	Cooldown = 1.0,
	HitDelay = 0.12,
	Animation = "",
	AnimationSource = "MeleePunch",
	MoveSpeed = 0.8,
	Shield = { Angle = 75, Health = 400 },
	BashStun = 0.7,
}

return MeleeConfig
]==]

local GADGET_BLOCK = [==[

-- [ABILITY2] 2026-10-19 the new gadgets (notes/weapon_abilities.md). Use = "Place" / "Channel": pressed, not thrown.
-- Sticky Grenade: thrown like a frag; sticks to the first surface or body it touches; blows FuseTime s after the throw
GadgetConfig.StickyGrenade = withThrow({
	DisplayName = "STICKY",
	ChargesAttribute = "StickyCharges",
	ChargesPerRound = 1,
	Bounciness = 0,
	FuseTime = 2.2,
})
-- Landmine: put down just ahead of you; arms after ArmTime s; an enemy within TriggerRadius sets it off (TriggerDelay)
GadgetConfig.Landmine = {
	DisplayName = "LANDMINE",
	ChargesAttribute = "MineCharges",
	ChargesPerRound = 1,
	Use = "Place",
	ArmTime = 1.2,
	TriggerRadius = 4,
	TriggerDelay = 0.3,
	Cooldown = 1,
}
-- Medkit: heals Heal HP over ChannelTime s; taking damage stops it (player attribute MedkitUntil while healing)
GadgetConfig.Medkit = {
	DisplayName = "MEDKIT",
	ChargesAttribute = "MedkitCharges",
	ChargesPerRound = 1,
	Use = "Channel",
	Heal = 60,
	ChannelTime = 2.5,
	Cooldown = 1,
}

return GadgetConfig
]==]

local SHOOTABLE_NEW = "\t\t-- [ABILITY2] the new gadgets' blasts (kind = the kill feed's weapon)\n"
	.. "\t\tStickyGrenade = { KillRadius = 3, Radius = 10, MaxDamage = 85, MinDamage = 20, Ignite = false, Shake = 0.7, ShakeRange = 55, Chain = true },\n"
	.. "\t\tLandmine = { KillRadius = 3, Radius = 9, MaxDamage = 90, MinDamage = 25, Ignite = false, Shake = 0.8, ShakeRange = 50, Chain = true },\n"
	.. "\t\tFrag = {\n\t\t\tKillRadius = 3.5,"

local ITEMS_GUNS = "\t-- [ABILITY2] new guns\n"
	.. "\tPumpShotgun = { Name = \"Pump Shotgun\", Slot = \"Weapon\", Price = 2500, Rarity = \"Epic\",\n"
	.. "\t\tDesc = \"Point-blank power. A close hit knocks them out of cover. Reloads shell by shell.\" },\n"
	.. "\tDualPistols = { Name = \"Dual Pistols\", Slot = \"Weapon\", Price = 2200, Rarity = \"Rare\",\n"
	.. "\t\tDesc = \"No aiming in. Dead accurate from the hip, twice the fire rate on the move.\" },\n"
local ITEMS_GADGETS = "\t-- [ABILITY2] new gadgets\n"
	.. "\tStickyGrenade = { Name = \"Sticky Grenade\", Slot = \"Gadget\", Price = 1500, Rarity = \"Rare\",\n"
	.. "\t\tDesc = \"Sticks to walls and people, then blows.\" },\n"
	.. "\tLandmine = { Name = \"Landmine\", Slot = \"Gadget\", Price = 1800, Rarity = \"Epic\",\n"
	.. "\t\tDesc = \"Put it down, it arms. The next enemy to walk over it won't.\" },\n"
	.. "\tMedkit = { Name = \"Medkit\", Slot = \"Gadget\", Price = 1000, Rarity = \"Rare\",\n"
	.. "\t\tDesc = \"Patch up 60 HP over a couple of seconds. Getting hit stops it.\" },\n"
local ITEMS_MELEE = "\t-- [ABILITY2] new melee\n"
	.. "\tBat = { Name = \"Bat\", Slot = \"Melee\", Price = 1000, Rarity = \"Rare\",\n"
	.. "\t\tDesc = \"Hold to charge: a charged hit knocks them out of cover or off a ledge.\" },\n"
	.. "\tKatana = { Name = \"Katana\", Slot = \"Melee\", Price = 2500, Rarity = \"Epic\",\n"
	.. "\t\tDesc = \"Right after a swing, bullets from the front are deflected.\" },\n"
	.. "\tRiotShield = { Name = \"Riot Shield\", Slot = \"Melee\", Price = 3000, Rarity = \"Legendary\",\n"
	.. "\t\tDesc = \"Blocks bullets from the front while held. Bash to stun. Slow to carry.\" },\n"
local KNIFE_LINE = "\t\tDesc = \"More damage and reach than fists.\" },\n"

local edits = {} -- { inst, old, new }
local function edit(inst, old, new) table.insert(edits, { inst, old, new }) end

-- // configs
local WC = Cfg.WeaponConfig
local LINK = "-- Link every weapon to its class (missing fields fall back to the class)\n"
edit(WC, LINK, WEAPON_BLOCK .. LINK)
edit(WC, "WeaponConfig.DefaultWeapon = \"Pistol\"",
	"table.insert(WeaponConfig.Loadout, \"PumpShotgun\") -- [ABILITY2]\ntable.insert(WeaponConfig.Loadout, \"DualPistols\")\n\nWeaponConfig.DefaultWeapon = \"Pistol\"")
edit(Cfg.MeleeConfig, "return {\n\tDefault = \"Fists\",", "local MeleeConfig = {\n\tDefault = \"Fists\",")
edit(Cfg.GadgetConfig, "\nreturn {\n\t-- Smokes and flashes never run out", "\nlocal GadgetConfig = {\n\t-- Smokes and flashes never run out")
edit(Cfg.ShootableConfig, "\t\tFrag = {\n\t\t\tKillRadius = 3.5,", SHOOTABLE_NEW)

-- // CombatManager
local CM = Mg.CombatManager
edit(CM, "HitRewind.Start()\n", "HitRewind.Start()\nlocal Abilities = require(game:GetService(\"ServerScriptService\").Shared.Abilities) -- [ABILITY2]\n")
edit(CM, "local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any)\n",
	"local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any, extra: any)\n")
edit(CM, "\tif state.reloading then return finish(\"reloading\") end\n\tif state.ammo <= 0 then return finish(\"no ammo\") end\n",
	"\t-- [ABILITY2] Pump Shotgun: pellets 2..N of one blast ride on the first one's shell; a shot cuts a shell-by-shell reload short\n"
	.. "\tlocal pelletFollow = config.Pellets and type(extra) == \"table\" and type(extra.pellet) == \"number\" and extra.pellet > 1\n"
	.. "\t\tand (state.pelletsLeft or 0) > 0 and os.clock() - state.lastFire < 0.15\n"
	.. "\tif state.reloading and config.ShellReload and state.ammo > 0 then cancelReload(tool, state) end\n"
	.. "\tif state.reloading then return finish(\"reloading\") end\n\tif state.ammo <= 0 and not pelletFollow then return finish(\"no ammo\") end\n")
edit(CM, "\tlocal now = os.clock()\n\tif now - state.lastFire < config.FireInterval * V.FireIntervalTolerance then\n\t\treturn finish(\"firing too fast\")\n\tend\n\n"
	.. "\t-- The shot happens: it costs ammo even if it hits nothing\n\tstate.ammo -= 1\n\tstate.lastFire = now\n",
	"\tlocal now = os.clock()\n"
	.. "\tif pelletFollow then\n"
	.. "\t\tstate.pelletsLeft -= 1 -- [ABILITY2] the same blast: no extra shell, no fire-rate check\n"
	.. "\telse\n"
	.. "\t\t-- [ABILITY2] Dual Pistols: twice the fire rate while moving\n"
	.. "\t\tlocal interval = config.FireInterval\n"
	.. "\t\tif config.MovingFireInterval then\n"
	.. "\t\t\tlocal movingRoot = character:FindFirstChild(\"HumanoidRootPart\")\n"
	.. "\t\t\tif movingRoot and (movingRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 4 then interval = config.MovingFireInterval end\n"
	.. "\t\tend\n"
	.. "\t\tif now - state.lastFire < interval * V.FireIntervalTolerance then\n\t\t\treturn finish(\"firing too fast\")\n\t\tend\n\n"
	.. "\t\t-- The shot happens: it costs ammo even if it hits nothing\n\t\tstate.ammo -= 1\n\t\tstate.lastFire = now\n"
	.. "\t\tstate.pelletsLeft = (config.Pellets or 1) - 1\n"
	.. "\tend\n")
edit(CM, "\tif config.Rhythm then damage = math.max(1, math.floor(damage * rhythm(player, config, true) + 0.5)) end -- [ABILITY]\n",
	"\tif config.Rhythm then damage = math.max(1, math.floor(damage * rhythm(player, config, true) + 0.5)) end -- [ABILITY]\n"
	.. "\tdo -- [ABILITY2] Katana parry / Riot Shield block / Revolver knockback / shotgun door breaker\n"
	.. "\t\tlocal stopped = Abilities.BulletHit(player, config, victimCharacter, origin, hitPosition, damage, distance, extra)\n"
	.. "\t\tif stopped then return finish(stopped) end\n"
	.. "\tend\n")
edit(CM, "\tstate.reloading = true\n\tstate.reloadToken += 1\n\tlocal token = state.reloadToken\n",
	"\tif state.config.ShellReload then return Abilities.ShellReload(player, tool, state, syncAttributes) end -- [ABILITY2] shell by shell\n"
	.. "\tstate.reloading = true\n\tstate.reloadToken += 1\n\tlocal token = state.reloadToken\n")

-- // MeleeManager
local MM = Mg.MeleeManager
edit(MM, "local Combat = ReplicatedStorage.Events.Combat\n",
	"local Combat = ReplicatedStorage.Events.Combat\nlocal Abilities = require(game:GetService(\"ServerScriptService\").Shared.Abilities) -- [ABILITY2]\n")
edit(MM, "local function onSwing(player: Player, kind: any)\n",
	"local function onSwing(player: Player, kind: any)\n\tif kind == \"Takedown\" then return Abilities.Takedown(player) end -- [ABILITY2] Fists vault takedown\n")
edit(MM, "\tlastSwing[player] = now\n",
	"\tlastSwing[player] = now\n\tlocal extra = Abilities.SwingExtra(player, weapon, kind) -- [ABILITY2] knife lunge / bat charge / katana parry window\n")
edit(MM, "if dist <= weapon.Range and flat.Magnitude > 0.1", "if dist <= weapon.Range + extra.range and flat.Magnitude > 0.1")
edit(MM, "local damage = backstab and victimHum.Health or weapon.Damage -- from behind: always lethal",
	"local damage = backstab and victimHum.Health or (weapon.Damage + extra.damage) -- from behind: always lethal ([ABILITY2] + lunge / charge bonus)")
edit(MM, "\tbest:SetAttribute(\"LastMeleeHit\", os.clock())\n",
	"\tbest:SetAttribute(\"LastMeleeHit\", os.clock())\n\tAbilities.MeleeHit(player, weapon, extra, best, root) -- [ABILITY2] bat knockback / shield bash stun\n")

-- // GadgetManager
local GM = Mg.GadgetManager
edit(GM, "local Get = shared.Get\n", "local Get = shared.Get\nlocal Abilities = require(game:GetService(\"ServerScriptService\").Shared.Abilities) -- [ABILITY2]\n")
edit(GM, "if (gadget ~= \"Smoke\" and gadget ~= \"Flash\" and gadget ~= \"Frag\") or not isValidDirection(direction) then return end",
	"if type(gadget) ~= \"string\" or type(GadgetConfig[gadget]) ~= \"table\" or not GadgetConfig[gadget].ChargesAttribute or not isValidDirection(direction) then return end -- [ABILITY2] any kit gadget")
edit(GM, "\tthrowGrenade(gadget, player.Character, direction, power, mode, side)\nend\n",
	"\tif Abilities.Gadget(player, gadget, cfg, direction, power, mode, side, launchVelocity) then return end -- [ABILITY2] sticky / mine / medkit\n"
	.. "\tthrowGrenade(gadget, player.Character, direction, power, mode, side)\nend\n")
edit(GM, "for _, name in { \"Smoke\", \"Flash\", \"Frag\" } do", "for _, name in { \"Smoke\", \"Flash\", \"Frag\", \"StickyGrenade\", \"Landmine\", \"Medkit\" } do -- [ABILITY2]")

-- // every LobbyConfig copy (the hub's, and the match place's pseudo-lobby original)
local lobbyConfigs = {}
for _, d in game:GetDescendants() do
	if d:IsA("ModuleScript") and d.Name == "LobbyConfig" and d.Source:find(KNIFE_LINE, 1, true) then table.insert(lobbyConfigs, d) end
end
for _, LC in lobbyConfigs do
	edit(LC, "\t-- gadgets (GadgetConfig ids)\n", ITEMS_GUNS .. "\t-- gadgets (GadgetConfig ids)\n")
	edit(LC, "\t-- melee (MeleeConfig ids)\n", ITEMS_GADGETS .. "\t-- melee (MeleeConfig ids)\n")
	edit(LC, KNIFE_LINE, KNIFE_LINE .. ITEMS_MELEE)
end

-- // run the edits (appends handled after)
local out = {}
local sources = {}
for _, e in edits do sources[e[1]] = sources[e[1]] or e[1].Source end
for i, e in edits do
	local s = sources[e[1]]
	local old, new = e[2], e[3]
	local done
	if UNDO then
		old, new = new, old
		done = not s:find(old, 1, true) -- the edited text isn't there: nothing to undo
	else
		done = s:find(new, 1, true) ~= nil
	end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found in " .. e[1]:GetFullName())
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique in " .. e[1].Name)
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
-- MeleeConfig / GadgetConfig: the new entries go at the end, then the module returns its table
local appends = { { Cfg.MeleeConfig, MELEE_BLOCK }, { Cfg.GadgetConfig, GADGET_BLOCK } }
for _, ap in appends do
	local inst, block = ap[1], ap[2]
	local s = sources[inst] or inst.Source
	local a, b = s:find(block, 1, true)
	if UNDO then
		if a then s = s:sub(1, a - 1) .. s:sub(b + 1) end
	elseif not a then
		s = s:gsub("%s+$", "") .. "\n" .. block
	end
	sources[inst] = s
end
for inst, s in sources do
	local f, err = loadstring(s)
	assert(f, inst:GetFullName() .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
end

-- // modules
local function put(parent: Instance, name: string, src: string?)
	local m = parent:FindFirstChild(name)
	if UNDO then
		if m then m:Destroy() end
		return name .. " removed"
	end
	assert(src, name .. " source missing (run tools/abilities_build.py)")
	assert(loadstring(src), name .. " would not parse")
	if m and not m:IsA("ModuleScript") then m:Destroy() m = nil end
	if not m then
		m = Instance.new("ModuleScript")
		m.Name = name
		m.Parent = parent
	end
	if m.Source ~= src then m.Source = src end
	return name .. " ok"
end
table.insert(out, put(SSS:WaitForChild("Shared"), "Abilities", SOURCES.Abilities))
table.insert(out, put(Controllers, "AbilityController", SOURCES.AbilityController))

-- // template ids
if not UNDO then
	local R = RS.Repository
	for _, t in R.Weapons:GetChildren() do if t:IsA("Tool") then t:SetAttribute("WeaponId", t.Name) end end
	for _, t in R.Melee:GetChildren() do if t:IsA("Tool") then t:SetAttribute("MeleeId", t.Name) end end
end
return table.concat(out, " ") .. " | LobbyConfigs " .. #lobbyConfigs
