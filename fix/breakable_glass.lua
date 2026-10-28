-- fix/breakable_glass.lua [GLASS] 2026-10-28, round 1. Work order (Lead plan, approved by Edward): "windows let bullets through and
-- the glass breaks, but not the frame, so nobody can leave". Breakable window glass as a general shootable, for the new map House.
-- Notes: notes/breakable_glass.md. Built by tools/breakable_glass_build.py (embeds fix/breakable_glass/*.lua below). Edit mode.
-- ONE installer for both kinds of place (it finds out which it is in):
--   MATCH places (Matchmaking / Ranked / the combined match place; needs steam fill round 5 first: it anchors on its text)
--     adds   ReplicatedStorage.Modules.Shared.Openings (the rules), Client.Controllers.WindowGlassController (the look)
--     edits  ShootableConfig (Glass block), ShootableManager (windows / barriers / doors of every placed map; shots, blasts and the
--            new OnMelee break panes; ResetAll; Studio-only ServerStorage.GlassTestHook), MeleeManager (a swing calls OnMelee),
--            CameraController (its CanCollide/!CanQuery box test skips barriers), CoverController (a vault / climb / dive stops at a
--            barrier: they move the body by CFrame), BotManager (a barrier is never a cover spot; the AI never vaults through one)
--   HUB (lobby pad duels: ArenaShootables / ArenaLoader)
--     adds   Shared.Openings
--     edits  ShootableConfig, ArenaShootables (per arena: windows, barriers, doors; OnShot / Explode / OnMelee / ResetAll), ArenaLoader
--            (the Visual twin follows the Solid window; the clone's glass / barriers prepared), the lobby ShootableManager stub
--            (OnMelee -> the arena), MeleeManager, CameraController, CoverController
--   both   registers the collision group "WindowBarrier" (collides with "Characters" only) so it is saved in the place.
-- Idempotent (second run: every line "="); checks EVERY anchor in every target, and the new module names, before writing anything;
-- stamps GlassRound on ShootableManager BEFORE the first write and refuses any other round; UNDO (set UNDO = true, or
-- tools/breakable_glass_build.py --run <id> UNDO) puts every edit back and removes the new modules (the collision group stays: harmless).
-- Prints a state hash before / after: UNDO returns to the "before" hash. DRY = true checks everything and writes nothing.
local UNDO = false --@UNDO
local DRY = false --@DRY
local ROUND = 1
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.Openings = [=[
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
]=]
SOURCES.WindowGlassController = [=[
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/WindowGlassController (ModuleScript) [GLASS] 2026-10-28
-- Match places: every window ShootableManager tagged "WindowGlass" (the placed maps' Shootable = "Glass" models) follows its
-- GlassBroken attribute: pane hidden, BrokenGlass shown, shatter + sound when it breaks (Openings.BindClient). One match per match
-- server, so every client here is that match's player or spectator. Lobby pad-duel arenas (Workspace.DuelArenas) are skipped:
-- ArenaLoader binds their client-only Visual twin for that match's players only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [window] = { RBXScriptConnection }

function controller.Start()
	local Openings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Openings"))
	local function bind(window: Instance)
		if bound[window] or window:FindFirstAncestor("DuelArenas") then return end
		bound[window] = Openings.BindClient(window)
	end
	for _, w in CollectionService:GetTagged(Openings.WINDOW_TAG) do task.spawn(bind, w) end
	CollectionService:GetInstanceAddedSignal(Openings.WINDOW_TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(Openings.WINDOW_TAG):Connect(function(window)
		local conns = bound[window]
		bound[window] = nil
		for _, c in conns or {} do c:Disconnect() end
	end)
end

return controller
]=]
SOURCES.GlassBlock = [=[

	-- [GLASS] breakable window glass (fix/breakable_glass.lua, notes/breakable_glass.md; the rules: Shared.Openings).
	-- A window = a model with the attribute Shootable = "Glass" holding a Glass part (and an optional BrokenGlass look). Bullets,
	-- melee and blasts pass through it and the hit lands behind it; the first one breaks it (reset every round). The opening stays
	-- shut to players by a part tagged WindowBarrier (invisible, ignored by every ray).
	Glass = {
		Enabled = true,          -- false: panes never break (bullets still pass through)
		HitPadding = 0.1,        -- studs around a pane for the bullet test
		MeleeReach = 1.5,        -- a swing reaches a pane this much further than a body (panes sit in a wall)
		BlastScale = 1,          -- a blast breaks panes within its Radius x this, with no wall in between
		NoiseRadius = 50,        -- the AI hears a pane break this far away (match places)
		Shards = 18,             -- falling shards per window (client)
		ShardLife = 2.5,         -- seconds a shard lives
		ShatterWindow = 1.5,     -- clients play the shatter only for a break this recent (late joiners see it broken)
		SoundVolume = 1.3,       -- x the Glass impact sounds (ImpactSounds)
		SoundPitch = 0.8,        -- a big pane sounds lower than a bottle
		BarrierGroup = "WindowBarrier",
		CharacterGroups = { "Characters", "DuelQueued" }, -- the collision groups a barrier blocks (players and the AI)
	},
]=]
SOURCES.TestHook = [=[
-- [GLASS] Studio-only test hook: ServerStorage.GlassTestHook:Invoke(cmd, a, b) runs in the game's VM (MCP / command-bar code gets
-- fresh module copies, so it can't reach this manager's state). Windows are named "<Map>/<Window>" ("Warehouse2/TestWindow").
--   "windows"                  -> JSON list { path, broken, cause, at }
--   "shoot", path, player?     -> a real OnShot from the player's head through the pane's centre to 40 studs past it
--   "melee", path, player?     -> OnMelee from the player's root facing the pane (reach 6, angle 70: a knife)
--   "blast", path, studs       -> a real Explode("Frag") that far in front of the pane (keep players away)
--   "reset"                    -> ResetAll (as a new round does)
local function glassTestHook()
	local HttpService = game:GetService("HttpService")
	local function pathOf(m: Instance): string
		local map = m:FindFirstAncestorWhichIsA("Model")
		while map and map.Parent ~= workspace do map = map.Parent and map.Parent:FindFirstAncestorWhichIsA("Model") or nil end
		return (map and map.Name or "?") .. "/" .. m.Name
	end
	local function windowBy(path: any): Instance?
		for _, w in windows do
			if pathOf(w) == path or w.Name == path then return w end
		end
		return nil
	end
	local function playerBy(name: any): Player?
		if type(name) == "string" then return Players:FindFirstChild(name) :: Player? end
		return Players:GetPlayers()[1]
	end
	local hook = game:GetService("ServerStorage"):FindFirstChild("GlassTestHook") or Instance.new("BindableFunction")
	hook.Name = "GlassTestHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any)
		if cmd == "windows" then
			local list = {}
			for _, w in windows do
				table.insert(list, { path = pathOf(w), broken = Openings.IsBroken(w), cause = w:GetAttribute("GlassCause"),
					at = tostring(w:GetAttribute("GlassHitAt")) })
			end
			return HttpService:JSONEncode(list)
		elseif cmd == "shoot" or cmd == "melee" then
			local w, p = windowBy(a), playerBy(b)
			local char = p and p.Character
			local head = char and char:FindFirstChild("Head")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local pane = w and Openings.GlassParts(w)[1]
			if not (head and root and pane) then return "no player / window" end
			if cmd == "shoot" then
				local dir = (pane.Position - head.Position).Unit
				manager.OnShot(head.Position, pane.Position + dir * 40, p)
			else
				manager.OnMelee(root.Position, (pane.Position - root.Position).Unit, 6, 70, p)
			end
			return if Openings.IsBroken(w) then "broken" else "intact"
		elseif cmd == "blast" then
			local w = windowBy(a)
			local pane = w and Openings.GlassParts(w)[1]
			if not pane then return "no window" end
			local s = pane.Size -- the pane's thinnest axis is its facing
			local normal = pane.CFrame.LookVector
			if s.X <= s.Y and s.X <= s.Z then normal = pane.CFrame.RightVector elseif s.Y <= s.Z then normal = pane.CFrame.UpVector end
			manager.Explode(pane.Position + normal * (tonumber(b) or 4), "Frag", nil)
			return if Openings.IsBroken(w) then "broken" else "intact"
		elseif cmd == "reset" then
			manager.ResetAll()
			return "ok"
		end
		return "unknown command " .. tostring(cmd)
	end
	hook.Parent = game:GetService("ServerStorage")
end
]=]
--@@END SOURCES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function norm(s: string): string return (s:gsub("\r\n", "\n")) end
for k, v in SOURCES do SOURCES[k] = norm(v) end

-- // Where -------------------------------------------------------------------------------------------------------------------------
local Shared = ReplicatedStorage.Modules.Shared
local Cfg = Shared.Config
local Managers = ServerScriptService.ServerScripts["[Server] Init"].GameManager.Managers
local SM, MM = Managers.ShootableManager, Managers.MeleeManager
local Controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
local CC = Controllers.CameraController
local COV = Controllers.CoverController
local AS = ServerScriptService:FindFirstChild("ArenaShootables", true)
local HUB = workspace:FindFirstChild("LobbyMap") ~= nil and AS ~= nil
local KIND = HUB and "hub" or "match"
if not HUB then
	assert(SM:GetAttribute("SteamFillRound") == 5,
		"breakable_glass: a match place needs steam fill round 5 installed first (fix/steam_fill.lua); its ShootableManager text is the anchor")
end
local AL = HUB and StarterPlayer.StarterPlayerScripts:FindFirstChild("ArenaLoader") or nil
local BM = (not HUB) and Managers:FindFirstChild("BotManager") or nil
if HUB then assert(AL, "breakable_glass: hub without StarterPlayerScripts.ArenaLoader (nothing was written)") end

-- // Round stamp ------------------------------------------------------------------------------------------------------------------
do
	local stamp = SM:GetAttribute("GlassRound")
	assert(stamp == nil or stamp == ROUND, "breakable_glass round " .. tostring(stamp) .. " is installed: UNDO it with that round's fix first")
	if stamp == nil then
		for _, inst in { SM, MM, CC, COV, AS or SM, AL or SM, BM or SM, Cfg.ShootableConfig } do
			assert(not norm(inst.Source):find("[GLASS]", 1, true),
				"breakable_glass: an unstamped [GLASS] edit is in " .. inst.Name .. ": UNDO it with the installer that wrote it first")
		end
	end
end

local targets = { Cfg.ShootableConfig, SM, MM, CC, COV }
if HUB then table.insert(targets, AS) table.insert(targets, AL) else table.insert(targets, BM) end
local function hash(): string
	-- FNV-1a over every source this installer touches + which new modules exist
	local h = 2166136261
	local parts = {}
	for _, t in targets do table.insert(parts, t.Source) end
	table.insert(parts, tostring(Shared:FindFirstChild("Openings") ~= nil))
	table.insert(parts, tostring(Controllers:FindFirstChild("WindowGlassController") ~= nil))
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

-- ShootableConfig: the Glass block at the end (same text in the hub and the match places)
edit(Cfg.ShootableConfig, "\tReloadHearRange = 22,\n}\n", "\tReloadHearRange = 22,\n" .. SOURCES.GlassBlock .. "}\n")

-- MeleeManager (both places): after the wind-up re-checks, the swing breaks the window glass it reaches
local MELEE_LOOK = "\tlocal look = (root.CFrame.LookVector * FLAT).Unit\n"
edit(MM, MELEE_LOOK .. "\tlocal best, bestDist = nil, math.huge\n",
	MELEE_LOOK
	.. "\tdo -- [GLASS] the swing breaks window glass it reaches (ShootableManager.OnMelee; the lobby's routes it to the duel arena)\n"
	.. "\t\tlocal shootables = shared.Get and shared.Get(\"ShootableManager\")\n"
	.. "\t\tif shootables and shootables.OnMelee then shootables.OnMelee(root.Position, look, weapon.Range + extra.range, swingAngle, player) end\n"
	.. "\tend\n"
	.. "\tlocal best, bestDist = nil, math.huge\n")

-- CameraController (both): its own box test for CanCollide / !CanQuery blockers must skip window barriers (players only)
edit(CC, "\t\tif p:IsA(\"BasePart\") and p.CanCollide and not p.CanQuery and not p:FindFirstAncestor(\"Hold\") and not p:FindFirstAncestor(\"FX\") and not p:FindFirstAncestor(\"Props\") then\n",
	"\t\t-- [GLASS] window barriers (tag WindowBarrier) block players only: the camera passes them like every ray\n"
	.. "\t\tif p:IsA(\"BasePart\") and p.CanCollide and not p.CanQuery and not p:HasTag(\"WindowBarrier\") and not p:FindFirstAncestor(\"Hold\") and not p:FindFirstAncestor(\"FX\") and not p:FindFirstAncestor(\"Props\") then\n")

-- CoverController (both): a vault / climb / dive moves the root by CFrame (no physics), so it stops itself at a window barrier
edit(COV, "-- // Per frame\nlocal function updateMovement(): boolean\n",
	"-- [GLASS] window barriers (tag WindowBarrier) stop bodies, not rays: a vault / climb / dive moves the root by CFrame (no physics),\n"
	.. "-- so it stops itself at one (nobody leaves through a window). Cover dashes walk (MoveTo): physics stops those.\n"
	.. "local Openings = require(Shared:WaitForChild(\"Openings\"))\n"
	.. "local function stopAtBarrier(root: BasePart, to: Vector3): boolean\n"
	.. "\tif not Openings.BarrierBetween(root.Position, to) then return false end\n"
	.. "\troot.AssemblyLinearVelocity = Vector3.zero\n"
	.. "\tfinishMovement()\n"
	.. "\treturn true\n"
	.. "end\n\n"
	.. "-- // Per frame\nlocal function updateMovement(): boolean\n")
edit(COV, "\t\troot.CFrame = CFrame.lookAt(position, position + face) * CFrame.Angles(-pitch, 0, 0)\n",
	"\t\tif stopAtBarrier(root, position) then return true end -- [GLASS]\n"
	.. "\t\troot.CFrame = CFrame.lookAt(position, position + face) * CFrame.Angles(-pitch, 0, 0)\n")
edit(COV, "\t\troot.CFrame = CFrame.lookAt(position, position + vault.facing)\n",
	"\t\tif stopAtBarrier(root, position) then return true end -- [GLASS]\n"
	.. "\t\troot.CFrame = CFrame.lookAt(position, position + vault.facing)\n")

if not HUB then
	-- BotManager: the AI's vault is an anchored CFrame arc: never over a window sill through a barrier
	edit(BM, "\tlocal facing = -spot.normal\n\tif self.tracks.Crouch and self.tracks.Crouch.IsPlaying then self.tracks.Crouch:Stop(0.1) end\n",
		"\tlocal facing = -spot.normal\n"
		.. "\tif require(Shared.Openings).BarrierOnArc(from, over, landing) then return false end -- [GLASS] never through a window barrier\n"
		.. "\tif self.tracks.Crouch and self.tracks.Crouch.IsPlaying then self.tracks.Crouch:Stop(0.1) end\n")
	-- BotManager: a barrier in a cover folder is never a cover spot
	edit(BM, "\t\t\tif part:IsA(\"BasePart\") and part.CanCollide and part.Size.Y >= 2.5 and part.Size.Y <= 11\n",
		"\t\t\t-- [GLASS] a window barrier (tag WindowBarrier) is no cover: bullets pass it\n"
		.. "\t\t\tif part:IsA(\"BasePart\") and part.CanCollide and not part:HasTag(\"WindowBarrier\") and part.Size.Y >= 2.5 and part.Size.Y <= 11\n")

	-- ShootableManager (match places)
	edit(SM, "local Get = shared.Get\n", "local Get = shared.Get\n"
		.. "local Openings = require(Shared.Openings) -- [GLASS] window glass, player-only barriers, door states (the rules)\n")
	edit(SM, "local valves, barrels, props = {}, {}, {}\n", "local valves, barrels, props = {}, {}, {}\n"
		.. "-- [GLASS] window panes of every placed map (Shootable = \"Glass\"); manager.OnGlass fires (window, cause, by) when one breaks\n"
		.. "local windows = {}\n"
		.. "manager.OnGlass = Instance.new(\"BindableEvent\")\n"
		.. "local function breakWindow(model: Instance, at: Vector3?, from: Vector3?, cause: string, by: Player?): boolean\n"
		.. "\tlocal point = at\n"
		.. "\tif not point then point = Openings.ClosestPoint(model, from or model:GetPivot().Position) end\n"
		.. "\tlocal dir = (from and point) and (point - from) or nil\n"
		.. "\tif not Openings.Break(model, point, dir, cause) then return false end\n"
		.. "\tlocal bots = Get(\"BotManager\")\n"
		.. "\tif bots and bots.HearNoise and point then bots.HearNoise(point, Openings.Config().NoiseRadius) end\n"
		.. "\tmanager.OnGlass:Fire(model, cause, by)\n"
		.. "\treturn true\n"
		.. "end\n")
	edit(SM, "\tif cfg.FireRadius then spawnFire(position, cfg.FireRadius, cfg.FireTime, attacker) end\n",
		"\tif cfg.FireRadius then spawnFire(position, cfg.FireRadius, cfg.FireTime, attacker) end\n"
		.. "\t-- [GLASS] the blast breaks every pane in reach with no wall in between\n"
		.. "\tfor _, w in windows do\n"
		.. "\t\tlocal hit, at = Openings.BlastHit(w, position, cfg.Radius, wallBetween)\n"
		.. "\t\tif hit then breakWindow(w, at, position, \"Blast\", attacker) end\n"
		.. "\tend\n")
	edit(SM, "function manager.IsValveActive(model: Model): boolean\n",
		"-- [GLASS] a melee swing (MeleeManager, after its wind-up) breaks the panes it reaches\n"
		.. "function manager.OnMelee(origin: Vector3, look: Vector3, reach: number, angle: number, attacker: Player?)\n"
		.. "\tlocal extra = Openings.Config().MeleeReach\n"
		.. "\tfor _, w in windows do\n"
		.. "\t\tlocal hit, at = Openings.MeleeHit(w, origin, look, reach + extra, angle)\n"
		.. "\t\tif hit then breakWindow(w, at, origin, \"Melee\", attacker) end\n"
		.. "\tend\n"
		.. "end\n\n"
		.. SOURCES.TestHook .. "\n"
		.. "function manager.IsValveActive(model: Model): boolean\n")
	edit(SM, "\tfor _, f in fires do f.untilT = 0 end\n",
		"\tfor _, f in fires do f.untilT = 0 end\n\tfor _, w in windows do Openings.Reset(w) end -- [GLASS] panes whole again\n")
	edit(SM, "\t-- props along the path make noise (bullets pass through them)\n",
		"\t-- [GLASS] glass never stops a bullet (it is CanQuery off): every pane the shot crossed, up to where it stopped, breaks\n"
		.. "\tfor _, w in windows do\n"
		.. "\t\tlocal hit, _, at = Openings.SegmentHit(w, origin, endPos)\n"
		.. "\t\tif hit then breakWindow(w, at, origin, \"Shot\", shooter) end\n"
		.. "\tend\n"
		.. "\t-- props along the path make noise (bullets pass through them)\n")
	edit(SM, "\t-- burning + standing in fire\n",
		"\t-- [GLASS] window panes, player-only barriers and door states of every placed map\n"
		.. "\tOpenings.EnsureBarrierGroup()\n"
		.. "\tfor _, placed in placedMaps() do\n"
		.. "\t\tlocal found = Openings.PrepareTree(placed)\n"
		.. "\t\tfor _, w in found.windows do\n"
		.. "\t\t\tif not table.find(windows, w) then\n"
		.. "\t\t\t\ttable.insert(windows, w)\n"
		.. "\t\t\t\tOpenings.Reset(w)\n"
		.. "\t\t\t\tCollectionService:AddTag(w, Openings.WINDOW_TAG)\n"
		.. "\t\t\tend\n"
		.. "\t\tend\n"
		.. "\t\tOpenings.WatchDoors(placed)\n"
		.. "\tend\n"
		.. "\tif RunService:IsStudio() then glassTestHook() end\n"
		.. "\t-- burning + standing in fire\n")
else
	-- the lobby's ShootableManager stub: a swing inside a duel arena goes to that arena
	edit(SM, "-- [DUEL] frag grenades (GadgetManager) and blasts",
		"-- [GLASS] a melee swing inside a lobby duel arena: that arena's window glass (MeleeManager -> here -> ArenaShootables:OnMelee)\n"
		.. "function manager.OnMelee(origin: Vector3, look: Vector3, reach: number, angle: number, attacker: Player?)\n"
		.. "\tlocal LDM = shared.Get and shared.Get(\"LobbyDuelManager\")\n"
		.. "\tlocal m = LDM and LDM.MatchAt and LDM.MatchAt(origin)\n"
		.. "\tif m and m.shoot and m.shoot.OnMelee then m.shoot:OnMelee(origin, look, reach, angle, attacker) end\n"
		.. "end\n\n"
		.. "-- [DUEL] frag grenades (GadgetManager) and blasts")

	-- ArenaShootables: windows / barriers / doors of ONE arena (state on its Solid layer; ArenaLoader draws the Visual twin)
	edit(AS, "local MatchState = require(Shared.MatchState)\n", "local MatchState = require(Shared.MatchState)\n"
		.. "local Openings = require(Shared.Openings) -- [GLASS] window glass, player-only barriers, door states (the rules)\n")
	edit(AS, "\treturn self\nend\n\nfunction ArenaShootables:Counts()\n",
		"\t-- [GLASS] window panes (Shootables.<Window>, Shootable = \"Glass\"), barriers (tag WindowBarrier), door states (DoorState)\n"
		.. "\tOpenings.EnsureBarrierGroup()\n"
		.. "\tself.windows = Openings.PrepareTree(solid).windows\n"
		.. "\tfor _, w in self.windows do Openings.Reset(w) end\n"
		.. "\tfor _, c in Openings.WatchDoors(solid) do table.insert(self.conns, c) end\n"
		.. "\treturn self\nend\n\nfunction ArenaShootables:Counts()\n")
	edit(AS, "\tif cfg.Chain then\n\t\tfor _, b in self.barrels do\n",
		"\t-- [GLASS] the blast breaks every pane in reach with no wall in between\n"
		.. "\tfor _, w in self.windows or {} do\n"
		.. "\t\tlocal hit, at = Openings.BlastHit(w, position, cfg.Radius, function(a, b) return self:wallBetween(a, b) end)\n"
		.. "\t\tif hit then Openings.Break(w, at, at and (at - position) or nil, \"Blast\") end\n"
		.. "\tend\n"
		.. "\tif cfg.Chain then\n\t\tfor _, b in self.barrels do\n")
	edit(AS, "\tif bestKind == \"Valve\" then self:ActivateValve(best, shooter)\n",
		"\t-- [GLASS] glass never stops a bullet (CanQuery off): every pane the shot crossed, up to where it stopped, breaks\n"
		.. "\tfor _, w in self.windows or {} do\n"
		.. "\t\tlocal hit, _, at = Openings.SegmentHit(w, origin, endPos)\n"
		.. "\t\tif hit then Openings.Break(w, at, endPos - origin, \"Shot\") end\n"
		.. "\tend\n"
		.. "\tif bestKind == \"Valve\" then self:ActivateValve(best, shooter)\n")
	edit(AS, "-- // Per frame: burning players and standing in fire",
		"-- [GLASS] a melee swing in this arena (MeleeManager -> the lobby ShootableManager -> here) breaks the panes it reaches\n"
		.. "function ArenaShootables:OnMelee(origin: Vector3, look: Vector3, reach: number, angle: number, attacker: Player?)\n"
		.. "\tif self.dead then return end\n"
		.. "\tlocal extra = Openings.Config().MeleeReach\n"
		.. "\tfor _, w in self.windows or {} do\n"
		.. "\t\tlocal hit, at = Openings.MeleeHit(w, origin, look, reach + extra, angle)\n"
		.. "\t\tif hit then Openings.Break(w, at, at and (at - origin) or nil, \"Melee\") end\n"
		.. "\tend\n"
		.. "end\n\n"
		.. "-- // Per frame: burning players and standing in fire")
	edit(AS, "\tself.fires = {}\n\tfor character in self.burning do self:extinguish(character) end\n",
		"\tself.fires = {}\n\tfor character in self.burning do self:extinguish(character) end\n"
		.. "\tfor _, w in self.windows or {} do Openings.Reset(w) end -- [GLASS] panes whole again\n")

	-- ArenaLoader: the client-only Visual twin's windows follow the Solid layer's; its glass / barriers prepared at clone time
	edit(AL, "local MapRegistry = require(Shared:WaitForChild(\"MapRegistry\"))\n", "local MapRegistry = require(Shared:WaitForChild(\"MapRegistry\"))\n"
		.. "local Openings = require(Shared:WaitForChild(\"Openings\")) -- [GLASS] window glass (Shootable = \"Glass\"), barriers\n")
	edit(AL, "\t\t\t\t\telseif kind == \"SteamValve\" then bindValve(sm, vm, conns); n += 1 end\n",
		"\t\t\t\t\telseif kind == \"SteamValve\" then bindValve(sm, vm, conns); n += 1\n"
		.. "\t\t\t\t\telseif kind == \"Glass\" then -- [GLASS] pane hidden / broken look / shatter + sound from GlassBroken\n"
		.. "\t\t\t\t\t\tfor _, c in Openings.BindClient(sm, vm) do table.insert(conns, c) end\n"
		.. "\t\t\t\t\t\tn += 1\n"
		.. "\t\t\t\t\tend\n")
	edit(AL, "\tclone:SetAttribute(\"DuelArena\", id)\n",
		"\tclone:SetAttribute(\"DuelArena\", id)\n"
		.. "\tOpenings.PrepareTree(clone) -- [GLASS] this client's copy: panes never block a ray, barriers block players only\n")
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
		assert(a, "breakable_glass: edit " .. i .. " anchor not found in " .. e[1]:GetFullName() .. " (nothing was written)")
		assert(not s:find(old, b + 1, true), "breakable_glass: edit " .. i .. " anchor not unique in " .. e[1].Name .. " (nothing was written)")
		-- an anchor starts and ends at a token boundary (never inside a longer name or call)
		local before_, after_ = s:sub(a - 1, a - 1), s:sub(b + 1, b + 1)
		assert(not (old:sub(1, 1):match("[%w_]") and before_:match("[%w_%.:]")) and not (old:sub(-1):match("[%w_]") and after_:match("[%w_]")),
			"breakable_glass: edit " .. i .. " anchor is inside a longer token in " .. e[1].Name .. " (nothing was written)")
		sources[e[1]] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
-- the new modules are anchors too: a same-named module that isn't ours stops the install before anything is written
local newModules = { { Shared, "Openings", SOURCES.Openings } }
if not HUB then table.insert(newModules, { Controllers, "WindowGlassController", SOURCES.WindowGlassController }) end
if not UNDO then
	for _, nm in newModules do
		local m = nm[1]:FindFirstChild(nm[2])
		assert(not m or m:GetAttribute("GlassInstall") ~= nil,
			"breakable_glass: a " .. nm[2] .. " that isn't ours is already in " .. nm[1]:GetFullName() .. " (nothing was written)")
	end
end
-- every edited source and every new module parses
local compile = loadstring
if compile then
	for inst, s in sources do
		local f, err = compile(s)
		assert(f, "breakable_glass: " .. inst.Name .. " would not parse: " .. tostring(err) .. " (nothing was written)")
	end
	for _, nm in newModules do
		local f, err = compile(nm[3])
		assert(f, "breakable_glass: " .. nm[2] .. " does not parse: " .. tostring(err))
	end
end
if DRY then
	return ("GLASS round %d DRY %s (%s): %s | hash %s (nothing written)"):format(ROUND, UNDO and "UNDO" or "install", KIND, table.concat(out, " "), before)
end

-- // Pass 2: write ----------------------------------------------------------------------------------------------------------------------
-- stamp first: if a write below is interrupted, the next run (install or UNDO) still recognises this round's own text
if not UNDO then SM:SetAttribute("GlassRound", ROUND) end
for inst, s in sources do if norm(inst.Source) ~= s then inst.Source = s end end
for _, nm in newModules do
	local parent, name, source = nm[1], nm[2], nm[3]
	local m = parent:FindFirstChild(name)
	if UNDO then
		if m and m:GetAttribute("GlassInstall") then m:Destroy() table.insert(out, name .. "-") else table.insert(out, name .. "=") end
	elseif m and norm(m.Source) == source then
		table.insert(out, name .. "=")
	else
		if not m then
			m = Instance.new("ModuleScript")
			m.Name = name
			m:SetAttribute("GlassInstall", ROUND)
			m.Source = source
			m.Parent = parent
		else
			m.Source = source
		end
		table.insert(out, name .. "+")
	end
end
-- the barrier's collision group, saved in the place (the server sets it again at start; clients have it from the first frame)
if not UNDO then
	local PhysicsService = game:GetService("PhysicsService")
	local ok = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("WindowBarrier") then PhysicsService:RegisterCollisionGroup("WindowBarrier") end
		if not PhysicsService:IsCollisionGroupRegistered("Characters") then PhysicsService:RegisterCollisionGroup("Characters") end
		for _, g in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable("WindowBarrier", g.name, g.name == "Characters" or g.name == "DuelQueued")
		end
	end)
	table.insert(out, ok and "group+" or "group!")
end
if UNDO then SM:SetAttribute("GlassRound", nil) end
return ("GLASS round %d %s (%s): %s | hash %s -> %s"):format(ROUND, UNDO and "UNDO" or "install", KIND, table.concat(out, " "), before, hash())
