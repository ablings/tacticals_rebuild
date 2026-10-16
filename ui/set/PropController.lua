local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/PropController (ModuleScript)
-- Set dressing you can shoot: bottles shatter, the apple bursts, chairs and cans get knocked over,
-- boxes jolt, extinguishers spray. Purely visual and local - bullets pass straight through props
-- (they're CanQuery = false), so they never block a shot or count as cover. Every client sees the
-- same thing because every client gets the same WeaponFired event. Props reset after a while.
-- Your OWN shots don't wait for that event: WeaponController calls OnLocalShot the moment you fire, so a
-- bottle you shoot breaks (and sounds) on the same frame; the server's echo of your shot is then ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ImpactSounds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("ImpactSounds"))
-- Breakable kind -> impact sound (same sound for everything of a kind)
local SOUND_FOR = { Glass = "Glass", Fruit = "Fruit", Wood = "Wood", Cardboard = "Cardboard", Metal = "Metal" }

local controller = {}

local RESET_AFTER = 30
local props = {} -- { model, cframes = {part -> CFrame}, broken = false }

local function segmentHitsBox(a: Vector3, b: Vector3, cf: CFrame, size: Vector3): boolean
	-- slab test in the box's space
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local d = lb - la
	local tmin, tmax = 0, 1
	local half = size / 2 + Vector3.one * 0.15 -- a little forgiving: they're small
	for _, axis in { "X", "Y", "Z" } do
		local o, v, h = la[axis], d[axis], half[axis]
		if math.abs(v) < 1e-6 then
			if o < -h or o > h then return false end
		else
			local t1, t2 = (-h - o) / v, (h - o) / v
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return false end
		end
	end
	return true
end

local function burst(at: Vector3, color: Color3, count: number, size: number, speed: number, material)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Size = Vector3.new(size * (0.5 + math.random()), size * 0.4, size * (0.5 + math.random()))
		p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Color = color
		p.Material = material or Enum.Material.Glass
		p.Transparency = material == Enum.Material.Glass and 0.3 or 0
		p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
		p.CollisionGroup = "Default"
		p.Parent = workspace
		p.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit * speed * (0.5 + math.random())
		p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30
		Debris:AddItem(p, 4 + math.random() * 2)
	end
end

local function puff(at: Vector3, color: Color3, amount: number, lifetime: number?)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(lifetime or 0.8, (lifetime or 0.8) * 1.6)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.LightInfluence = 1
	e.Enabled = false
	e.Parent = a
	e:Emit(amount)
	Debris:AddItem(a, 4)
	return e
end

local function hide(entry)
	for part in entry.cframes do part.LocalTransparencyModifier = 1 part.CanCollide = false end
end

local function weldCopy(model: Model)
	local root = model.PrimaryPart
	if not root then return end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and not p:FindFirstChild("PropWeld") then
			local w = Instance.new("WeldConstraint")
			w.Name = "PropWeld"
			w.Part0, w.Part1 = root, p
			w.Parent = p
		end
	end
end

-- Knocked over: the real prop hides and a local copy (which this client simulates) goes flying
local function knock(entry, dir: Vector3, strength: number)
	local copy = entry.model:Clone()
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") then p.Anchored = false p.CanCollide = true p.CanQuery = false end
	end
	weldCopy(copy)
	hide(entry)
	copy.Parent = workspace
	local root = copy.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = dir * strength + Vector3.new(0, strength * 0.4, 0)
		root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8
	end
	entry.copy = copy
end


local function reset(entry)
	for part, cf in entry.cframes do
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CFrame = cf
		part.LocalTransparencyModifier = 0
		part.CanCollide = entry.collide[part]
	end
	if entry.copy then entry.copy:Destroy() entry.copy = nil end
	entry.broken = false
end

local function hit(entry, origin: Vector3, at: Vector3)
	local model = entry.model
	local kind = model:GetAttribute("Breakable")
	local dir = (at - origin).Unit
	local root = model.PrimaryPart
	local center = root and root.Position or at
	ImpactSounds.Play(at, SOUND_FOR[kind] or ImpactSounds.Classify(root))
	if kind == "Metal" then
		-- a hollow can / extinguisher rings out: a bright tink on top of the clank
		task.delay(0.03, function() ImpactSounds.Play(at, "Metal", 0.5, 1.7 + math.random() * 0.4) end)
	end
	if kind == "Glass" then
		entry.broken = true
		hide(entry)
		burst(center, root and root.Color or Color3.new(0.3, 0.5, 0.3), 9, 0.22, 14)
		puff(center, Color3.fromRGB(220, 220, 220), 3, 0.3)
	elseif kind == "Fruit" then
		entry.broken = true
		hide(entry)
		burst(center, Color3.fromRGB(240, 220, 170), 6, 0.18, 10, Enum.Material.SmoothPlastic)
		burst(center, Color3.fromRGB(170, 30, 26), 4, 0.15, 9, Enum.Material.SmoothPlastic)
	elseif kind == "Wood" then
		puff(at, Color3.fromRGB(150, 120, 80), 6, 0.5)
		burst(at, Color3.fromRGB(130, 100, 66), 4, 0.2, 8, Enum.Material.Wood)
		if model.Name == "Chair" then entry.broken = true knock(entry, dir, 16) end
	elseif kind == "Cardboard" then
		puff(at, Color3.fromRGB(170, 150, 120), 5, 0.6)
		if model:GetExtentsSize().Magnitude < 3.5 then entry.broken = true knock(entry, dir, 12) end
	elseif kind == "Metal" then
		if model.Name == "Extinguisher" then
			-- burst of white powder that hangs in the air for a moment
			local e = puff(center, Color3.fromRGB(235, 235, 235), 40, 2.5)
			e.Speed = NumberRange.new(6, 14)
		else
			entry.broken = true
			knock(entry, dir, 18)
			puff(center, root and root.Color or Color3.new(1, 1, 1), 6, 0.6)
		end
	end
	if entry.broken then
		task.delay(RESET_AFTER, function() if entry.broken then reset(entry) end end)
	end
end

local localPlayer = game:GetService("Players").LocalPlayer

local function onShot(shooter, origin: Vector3, endPos: Vector3)
	if typeof(origin) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end
	if shooter == localPlayer and shooter ~= nil and not controller._fromLocal then return end -- already shown instantly
	-- the shot carries on through props: test the whole line to where it stopped
	for _, entry in props do
		if not entry.broken and entry.model.Parent then
			local cf, size = entry.model:GetBoundingBox()
			if segmentHitsBox(origin, endPos, cf, size) then
				-- impact point ~ closest point on the shot line to the prop
				local d = (endPos - origin)
				local t = math.clamp((cf.Position - origin):Dot(d) / d:Dot(d), 0, 1)
				hit(entry, origin, origin + d * t)
			end
		end
	end
end

-- WeaponController: your shot, right now (client prediction)
function controller.OnLocalShot(origin: Vector3, endPos: Vector3)
	controller._fromLocal = true
	onShot(localPlayer, origin, endPos)
	controller._fromLocal = false
end

function controller.Start()
	-- bind a map's Props folder; `owner` tags the entries so an arena's props can be dropped when its clone goes
	local function bindProps(folder, owner)
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("Breakable") then
				local entry = { model = model, cframes = {}, collide = {}, broken = false, owner = owner }
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then entry.cframes[p] = p.CFrame entry.collide[p] = p.CanCollide end
				end
				table.insert(props, entry)
			end
		end
	end
	local function dropProps(owner)
		for i = #props, 1, -1 do
			if props[i].owner == owner then table.remove(props, i) end
		end
	end
	task.spawn(function()
		local map = workspace:WaitForChild("Warehouse", 30)
		local folder = map and map:WaitForChild("Props", 10)
		if folder then bindProps(folder, map) end
	end)
	-- lobby duels: each match's arena is a Workspace child with the DuelArena attribute, cloned in (and re-made) per match
	local function watchArena(child)
		if child:GetAttribute("DuelArena") == nil then return end
		task.spawn(function()
			local folder = child:WaitForChild("Props", 10)
			if folder and child.Parent then
				dropProps(child)
				bindProps(folder, child)
			end
		end)
	end
	for _, child in workspace:GetChildren() do watchArena(child) end
	workspace.ChildAdded:Connect(watchArena)
	workspace.ChildRemoved:Connect(function(child)
		if child:GetAttribute("DuelArena") ~= nil then dropProps(child) end
	end)
	local fired = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat"):WaitForChild("WeaponFired")
	fired.OnClientEvent:Connect(onShot)
end

return controller
