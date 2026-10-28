-- ReplicatedStorage/Modules/Shared/Openings (ModuleScript) [GLASS] 2026-10-28 (fix/breakable_glass.lua, notes/breakable_glass.md)
-- Windows and doors of a map: the rules shared by the server (ShootableManager in the match places, ArenaShootables for lobby pad
-- duels) and the clients (WindowGlassController, ArenaLoader). Nothing here names a map: everything is found by convention.
--
-- Window: a model with the attribute Shootable = "Glass" (normally Shootables.<Window>), holding
--   Glass        a part, or a model / folder of parts: the pane(s). Made CanCollide / CanQuery / CanTouch false at run time,
--                so it never stops a bullet, the cover probe, the camera or a player.
--   BrokenGlass  optional, a part or model: the broken look (jagged edges left in the frame). Hidden until the glass breaks.
--   The first bullet, melee swing or blast through it breaks it: the server sets GlassBroken (plus GlassBrokenAt, GlassHitAt,
--   GlassHitDir, GlassCause); every client of that match hides the pane, shows BrokenGlass and plays the shatter. Reset each round.
-- Barrier: a part tagged WindowBarrier (normally filling the window opening). Invisible, CanCollide on, CanQuery / CanTouch off,
--   in the collision group "WindowBarrier", which collides only with the characters' group. Every raycast and spatial query uses
--   the "Default" group unless it says otherwise, so bullets, the cover probe and the camera never see it; players always bump into it.
--   (CanQuery = false alone does nothing while CanCollide is on: the engine only honours it on non-colliding parts.)
-- Door (for later): a model with the attribute DoorState = "Closed" | "Open" | "Locked". Read by DoorState(); OnDoorState() is
--   where an open / close mechanic will go. It does nothing yet, so the map can carry the attribute already.
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Openings = {}
Openings.KIND = "Glass"
Openings.BARRIER_TAG = "WindowBarrier"
Openings.WINDOW_TAG = "WindowGlass" -- match places: ShootableManager tags the placed maps' windows (WindowGlassController binds them)

local FLAT = Vector3.new(1, 0, 1)
local DEFAULTS = {
	Enabled = true,          -- false: panes never break (bullets still pass through)
	HitPadding = 0.1,        -- studs around a pane for the bullet test
	MeleeReach = 1.5,        -- a swing reaches a pane this much further than it reaches a body (panes sit in a wall)
	BlastScale = 1,          -- a blast breaks panes within its Radius x this, with no wall in between
	NoiseRadius = 50,        -- the AI hears a pane break this far away (match places)
	Shards = 18,             -- falling shards per window (client)
	ShardLife = 2.5,         -- seconds a shard lives
	ShatterWindow = 1.5,     -- a client plays the shatter only for a break this recent (late joiners just see it broken)
	SoundVolume = 1.3,       -- x the game's Glass impact set (ImpactSounds)
	SoundPitch = 0.8,        -- a big pane sounds lower than a bottle
	BarrierGroup = "WindowBarrier",
	CharacterGroups = { "Characters", "DuelQueued" }, -- the groups a barrier blocks (players and the AI); every other group passes through
}
local config
function Openings.Config()
	if config then return config end
	local merged = table.clone(DEFAULTS)
	local folder = script.Parent:FindFirstChild("Config")
	local module = folder and folder:FindFirstChild("ShootableConfig")
	if module then
		local ok, sc = pcall(require, module)
		if ok and type(sc) == "table" and type(sc.Glass) == "table" then
			for k, v in sc.Glass do merged[k] = v end
		end
	end
	config = merged
	return config
end

-- // Finding the pieces -------------------------------------------------------------------------------------------------------
local function partsUnder(node: Instance?): { BasePart }
	local list = {}
	if not node then return list end
	if node:IsA("BasePart") then table.insert(list, node) end
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") then table.insert(list, d) end
	end
	return list
end

function Openings.IsWindow(model: Instance): boolean
	return model:GetAttribute("Shootable") == Openings.KIND
end

-- the pane(s): the Glass child; a window without one counts every part outside BrokenGlass
function Openings.GlassParts(model: Instance): { BasePart }
	local glass = model:FindFirstChild("Glass")
	if glass then return partsUnder(glass) end
	local broken = model:FindFirstChild("BrokenGlass")
	local list = {}
	for _, p in partsUnder(model) do
		if not (broken and (p == broken or p:IsDescendantOf(broken))) then table.insert(list, p) end
	end
	return list
end

function Openings.BrokenParts(model: Instance): { BasePart }
	return partsUnder(model:FindFirstChild("BrokenGlass"))
end

-- // Preparing a map (server on its own copy, each client on a client-only copy) --------------------------------------------------
-- glass and its broken look never collide, never block a ray, never fire Touched
function Openings.PrepareWindow(model: Instance)
	local parts = Openings.GlassParts(model)
	for _, p in Openings.BrokenParts(model) do table.insert(parts, p) end
	for _, p in parts do
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
end

-- Server: the barrier's collision group, colliding only with the characters' group(s). Safe to call again (and in Edit mode:
-- the installer runs it so the group is saved in the place, and clients have it from the first frame).
function Openings.EnsureBarrierGroup(): boolean
	local c = Openings.Config()
	local ok, err = pcall(function()
		local g = c.BarrierGroup
		if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
		local first = c.CharacterGroups[1]
		if first and not PhysicsService:IsCollisionGroupRegistered(first) then PhysicsService:RegisterCollisionGroup(first) end
		for _, other in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable(g, other.name, table.find(c.CharacterGroups, other.name) ~= nil)
		end
	end)
	if not ok then warn("[Openings] barrier collision group: " .. tostring(err)) end
	return ok
end

function Openings.PrepareBarrier(part: BasePart)
	part.Transparency = 1
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.CanQuery = false -- (no effect while CanCollide is on; kept so the part says what it is)
	local g = Openings.Config().BarrierGroup
	local ok, registered = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, g)
	if ok and registered then part.CollisionGroup = g end
end

-- Every window and barrier under `root`. Returns { windows = { Model }, barriers = { BasePart } }.
function Openings.PrepareTree(root: Instance)
	local found = { windows = {}, barriers = {} }
	local function visit(d: Instance)
		if d:IsA("BasePart") and d:HasTag(Openings.BARRIER_TAG) then
			Openings.PrepareBarrier(d)
			table.insert(found.barriers, d)
		elseif not d:IsA("BasePart") and Openings.IsWindow(d) then
			Openings.PrepareWindow(d)
			table.insert(found.windows, d)
		end
	end
	visit(root)
	for _, d in root:GetDescendants() do visit(d) end
	return found
end

-- // Hit tests (pure) ----------------------------------------------------------------------------------------------------------
-- Does segment a->b pass through the box? Returns hit, t (0..1 along the segment where it enters).
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
Openings.SegmentHitsBox = segmentHitsBox

-- the closest point of a part's box to p
local function closestOnBox(part: BasePart, p: Vector3): Vector3
	local local_ = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(local_.X, -h.X, h.X), math.clamp(local_.Y, -h.Y, h.Y), math.clamp(local_.Z, -h.Z, h.Z)))
end

-- Did the segment a->b cross any pane? Returns hit, t, the world point where it entered.
function Openings.SegmentHit(model: Instance, a: Vector3, b: Vector3): (boolean, number?, Vector3?)
	local pad = Openings.Config().HitPadding
	local bestT = math.huge
	for _, p in Openings.GlassParts(model) do
		local hit, t = segmentHitsBox(a, b, p.CFrame, p.Size, pad)
		if hit and t < bestT then bestT = t end
	end
	if bestT == math.huge then return false, nil, nil end
	return true, bestT, a + (b - a) * bestT
end

-- the closest point of any pane to p, and its distance (nil, huge for a window with no pane)
function Openings.ClosestPoint(model: Instance, p: Vector3): (Vector3?, number)
	local best, bestD = nil, math.huge
	for _, part in Openings.GlassParts(model) do
		local q = closestOnBox(part, p)
		local d = (q - p).Magnitude
		if d < bestD then best, bestD = q, d end
	end
	return best, bestD
end

-- A blast at `position` with `radius` reaches a pane when the pane's closest point is in range and `blocked(from, to)` (the
-- caller's wall test, optional) sees no wall between the blast and a point just in front of the pane.
function Openings.BlastHit(model: Instance, position: Vector3, radius: number, blocked: ((Vector3, Vector3) -> boolean)?): (boolean, Vector3?)
	local q, d = Openings.ClosestPoint(model, position)
	if not q or d > radius * Openings.Config().BlastScale then return false, nil end
	if blocked and d > 0.6 then
		local from = position + Vector3.new(0, 1, 0)
		local to = q + (from - q).Unit * 0.5
		if blocked(from, to) then return false, nil end
	end
	return true, q
end

-- A melee swing from `origin` facing `look` reaches a pane within `reach` studs and `angle` degrees of the facing (flat).
function Openings.MeleeHit(model: Instance, origin: Vector3, look: Vector3, reach: number, angle: number): (boolean, Vector3?)
	local q, d = Openings.ClosestPoint(model, origin)
	if not q or d > reach then return false, nil end
	local flat = (q - origin) * FLAT
	if flat.Magnitude < 0.1 then return true, q end
	local facing = look * FLAT
	if facing.Magnitude < 1e-3 then return false, nil end
	local deg = math.deg(math.acos(math.clamp(facing.Unit:Dot(flat.Unit), -1, 1)))
	return deg <= angle, q
end

-- // Scripted moves vs barriers ---------------------------------------------------------------------------------------------------
-- A vault, climb or dive moves the body by CFrame, so physics never stops it at a barrier. Does moving the root a -> b go INTO one?
-- pad = how far the body reaches past its root. A root already within pad of a barrier may still move away from it (or along it);
-- only a move into the barrier's own box counts then.
function Openings.BarrierBetween(a: Vector3, b: Vector3, pad: number?): boolean
	pad = pad or 0.75
	for _, p in CollectionService:GetTagged(Openings.BARRIER_TAG) do
		if p:IsA("BasePart") and p.CanCollide and p:IsDescendantOf(workspace) then
			local hit, t = segmentHitsBox(a, b, p.CFrame, p.Size, pad)
			if hit and t > 0 then return true end
			if hit then
				local hit2, t2 = segmentHitsBox(a, b, p.CFrame, p.Size, 0)
				if hit2 and t2 > 0 then return true end
			end
		end
	end
	return false
end
-- the same along a quadratic curve from -> over -> to (the vault arc), sampled
function Openings.BarrierOnArc(from: Vector3, over: Vector3, to: Vector3, pad: number?): boolean
	local last = from
	for i = 1, 10 do
		local t = i / 10
		local p = from:Lerp(over, t):Lerp(over:Lerp(to, t), t)
		if Openings.BarrierBetween(last, p, pad) then return true end
		last = p
	end
	return false
end

-- // State (server writes, everyone reads) -----------------------------------------------------------------------------------
function Openings.IsBroken(model: Instance): boolean
	return model:GetAttribute("GlassBroken") == true
end

-- Server: break it once. at = where it broke (world), dir = the way the hit travelled, cause = "Shot" | "Melee" | "Blast".
-- GlassBroken goes last: clients react to it and read the others.
function Openings.Break(model: Instance, at: Vector3?, dir: Vector3?, cause: string?): boolean
	if Openings.IsBroken(model) or Openings.Config().Enabled == false then return false end
	model:SetAttribute("GlassHitAt", at)
	model:SetAttribute("GlassHitDir", (dir and dir.Magnitude > 1e-3) and dir.Unit or nil)
	model:SetAttribute("GlassCause", cause)
	model:SetAttribute("GlassBrokenAt", workspace:GetServerTimeNow())
	model:SetAttribute("GlassBroken", true)
	return true
end

-- Server: whole again (new round)
function Openings.Reset(model: Instance)
	model:SetAttribute("GlassBroken", false)
	for _, k in { "GlassBrokenAt", "GlassHitAt", "GlassHitDir", "GlassCause" } do model:SetAttribute(k, nil) end
end

-- // Doors (for later) ---------------------------------------------------------------------------------------------------------
Openings.DOOR_STATES = { Closed = true, Open = true, Locked = true }
function Openings.DoorState(model: Instance): string
	local s = model:GetAttribute("DoorState")
	if type(s) == "string" and Openings.DOOR_STATES[s] then return s end
	return "Closed"
end
-- Where a door open / close mechanic goes (collision, tween, sound, prompt). Does nothing yet: returns false = "not handled".
function Openings.OnDoorState(model: Instance, state: string): boolean
	return false
end
-- Server: every model under root carrying DoorState is read once and on every change. Returns the connections.
function Openings.WatchDoors(root: Instance): { RBXScriptConnection }
	local conns = {}
	for _, d in root:GetDescendants() do
		if d:GetAttribute("DoorState") ~= nil then
			Openings.OnDoorState(d, Openings.DoorState(d))
			table.insert(conns, d:GetAttributeChangedSignal("DoorState"):Connect(function()
				Openings.OnDoorState(d, Openings.DoorState(d))
			end))
		end
	end
	return conns
end

-- // Client: the look ------------------------------------------------------------------------------------------------------------
local impactSounds
local function playGlassSound(at: Vector3)
	if impactSounds == nil then
		local m = script.Parent:FindFirstChild("ImpactSounds")
		local ok, mod = false, nil
		if m then ok, mod = pcall(require, m) end
		impactSounds = ok and mod or false
	end
	if not impactSounds then return end
	local c = Openings.Config()
	impactSounds.Play(at, "Glass", c.SoundVolume, c.SoundPitch)
	task.delay(0.07, function() impactSounds.Play(at, "Glass", c.SoundVolume * 0.6, c.SoundPitch * 1.25) end)
end

-- Shards fall out of the pane(s), a puff of glitter at the hit, and the glass sound. Client-only parts (Default group: they fall
-- through barriers and land on the floor), cleaned up by Debris.
function Openings.Shatter(panes: { BasePart }, at: Vector3?, dir: Vector3?, parent: Instance?)
	local c = Openings.Config()
	if #panes == 0 then return end
	local area, total = {}, 0
	for i, p in panes do
		local s = p.Size
		area[i] = math.max(s.X * s.Y, s.Y * s.Z, s.X * s.Z)
		total += area[i]
	end
	at = at or panes[1].Position
	local push = (dir and dir.Magnitude > 1e-3) and dir.Unit or Vector3.zero
	for i, pane in panes do
		local n = math.max(2, math.floor(c.Shards * area[i] / math.max(total, 1e-3) + 0.5))
		local s = pane.Size
		-- the pane's two long axes
		local axes = { { pane.CFrame.RightVector, s.X }, { pane.CFrame.UpVector, s.Y }, { pane.CFrame.LookVector, s.Z } }
		table.sort(axes, function(a, b) return a[2] > b[2] end)
		for _ = 1, n do
			local u = (math.random() - 0.5) * axes[1][2]
			local v = (math.random() - 0.5) * axes[2][2]
			local pos = pane.Position + axes[1][1] * u + axes[2][1] * v
			if (pos - at).Magnitude > 3 and math.random() < 0.5 then pos = pos:Lerp(at, 0.5) end -- more of them round the hit
			local shard = Instance.new("Part")
			shard.Name = "GlassShard"
			local w = 0.25 + math.random() * 0.6
			shard.Size = Vector3.new(w, 0.05, w * (0.4 + math.random() * 0.8))
			shard.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
			shard.Material = Enum.Material.Glass
			shard.Color = pane.Color
			shard.Transparency = math.clamp(pane.Transparency, 0.2, 0.6)
			shard.CanQuery, shard.CanTouch, shard.CastShadow = false, false, false
			shard.CollisionGroup = "Default"
			shard.Parent = parent or workspace
			shard.AssemblyLinearVelocity = push * (4 + math.random() * 10)
				+ Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * 6
			shard.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 25
			Debris:AddItem(shard, c.ShardLife * (0.8 + math.random() * 0.4))
		end
	end
	local a = Instance.new("Attachment")
	a.Name = "GlassShatter"
	a.Parent = workspace.Terrain -- (parent first: a loose attachment's world position is taken as relative)
	a.WorldPosition = at
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(235, 242, 245))
	e.LightEmission = 0.4
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.04) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = a
	if push.Magnitude > 0 then a.WorldCFrame = CFrame.lookAt(at, at + push) e.EmissionDirection = Enum.NormalId.Front end
	e:Emit(30)
	Debris:AddItem(a, 2)
	playGlassSound(at)
end

-- Client: make `visual` (the window this client draws: the replicated one in a match place, the client-only Visual twin in a lobby
-- duel) follow `source` (the server's window, which carries the attributes). Returns the connections (disconnect to unbind).
function Openings.BindClient(source: Instance, visual: Instance?): { RBXScriptConnection }
	local look = visual or source
	Openings.PrepareWindow(look)
	local glass, broken = Openings.GlassParts(look), Openings.BrokenParts(look)
	local shown: boolean? = nil
	local function apply(live: boolean)
		local isBroken = Openings.IsBroken(source)
		if isBroken == shown then return end
		shown = isBroken
		for _, p in glass do p.LocalTransparencyModifier = if isBroken then 1 else 0 end
		for _, p in broken do p.LocalTransparencyModifier = if isBroken then 0 else 1 end
		if isBroken and live then
			local t = source:GetAttribute("GlassBrokenAt")
			if type(t) == "number" and workspace:GetServerTimeNow() - t <= Openings.Config().ShatterWindow then
				local at, dir = source:GetAttribute("GlassHitAt"), source:GetAttribute("GlassHitDir")
				Openings.Shatter(glass, if typeof(at) == "Vector3" then at else nil, if typeof(dir) == "Vector3" then dir else nil)
			end
		end
	end
	apply(false)
	return { source:GetAttributeChangedSignal("GlassBroken"):Connect(function() apply(true) end) }
end

return Openings
