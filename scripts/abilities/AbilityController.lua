-- StarterPlayer.StarterPlayerScripts.Client.Controllers.AbilityController (ModuleScript, hub + match) [ABILITY2] 2026-10-19
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
