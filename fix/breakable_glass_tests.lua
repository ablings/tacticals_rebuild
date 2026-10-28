-- fix/breakable_glass_tests.lua [GLASS] unit tests for Shared.Openings (the rules of the breakable window glass). Edit mode, any place
-- with fix/breakable_glass.lua installed (hub or match). Runs on FRESH module instances (clones in a temp folder: Studio's plugin VM
-- caches require per instance), on fake windows 3000 studs up (nothing in the map is touched), and removes everything after.
-- Returns "N/N passed" and the failures.
local RS = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Shared = RS.Modules.Shared
local tmp = Instance.new("Folder")
tmp.Name = "_GlassTest"
local cfgFolder = Instance.new("Folder")
cfgFolder.Name = "Config"
cfgFolder.Parent = tmp
Shared.Config.ShootableConfig:Clone().Parent = cfgFolder
for _, n in { "SoundTrim", "ImpactSounds" } do
	local m = Shared:FindFirstChild(n)
	if m then m:Clone().Parent = tmp end
end
local mod = Shared.Openings:Clone()
mod.Parent = tmp
tmp.Parent = RS
local world = Instance.new("Folder")
world.Name = "_GlassTestWorld"
world.Parent = workspace

local results, passed, total = {}, 0, 0
local function check(name: string, ok: boolean, detail: any?)
	total += 1
	if ok then passed += 1 else table.insert(results, "FAIL " .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or "")) end
end

local ok, err = pcall(function()
	local O = require(mod)
	local C = O.Config()
	check("config from ShootableConfig.Glass", require(cfgFolder.ShootableConfig).Glass ~= nil and C.BarrierGroup == "WindowBarrier")
	check("config defaults kept", type(C.Shards) == "number" and C.Enabled == true)
	local BASE = Vector3.new(3000, 3000, 3000)

	local function part(parent, name, size, cf)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
		p.Parent = parent
		return p
	end
	-- a window facing Z at BASE: pane 6 x 5 x 0.2, a broken look, a barrier in the opening
	local function window(name: string, at: Vector3, withGlassChild: boolean?)
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("Shootable", "Glass")
		if withGlassChild ~= false then
			part(m, "Glass", Vector3.new(6, 5, 0.2), CFrame.new(at))
		else
			part(m, "Pane", Vector3.new(6, 5, 0.2), CFrame.new(at))
		end
		local broken = Instance.new("Model")
		broken.Name = "BrokenGlass"
		broken.Parent = m
		part(broken, "Edge", Vector3.new(1, 3, 0.2), CFrame.new(at + Vector3.new(-2.5, 0, 0)))
		m.Parent = world
		return m
	end
	local w = window("W1", BASE)

	-- finding the pieces
	check("IsWindow", O.IsWindow(w) and not O.IsWindow(world))
	check("GlassParts = the Glass child", #O.GlassParts(w) == 1 and O.GlassParts(w)[1].Name == "Glass")
	check("BrokenParts", #O.BrokenParts(w) == 1)
	local w2 = window("W2", BASE + Vector3.new(30, 0, 0), false)
	check("no Glass child: every part outside BrokenGlass", #O.GlassParts(w2) == 1 and O.GlassParts(w2)[1].Name == "Pane")

	-- preparing: glass ignored by every query
	local found = O.PrepareTree(world)
	check("PrepareTree finds both windows", #found.windows == 2)
	local g = O.GlassParts(w)[1]
	check("glass CanCollide/CanQuery/CanTouch off", not g.CanCollide and not g.CanQuery and not g.CanTouch)
	check("broken look prepared too", not O.BrokenParts(w)[1].CanQuery and not O.BrokenParts(w)[1].CanCollide)
	check("a ray passes the pane", workspace:Raycast(BASE - Vector3.new(0, 0, 10), Vector3.new(0, 0, 20)) == nil)

	-- the barrier: blocks characters only, invisible to rays / sphere casts / box queries
	check("EnsureBarrierGroup", O.EnsureBarrierGroup())
	local bar = part(world, "Barrier", Vector3.new(6, 5, 1), CFrame.new(BASE + Vector3.new(60, 0, 0)))
	bar:AddTag("WindowBarrier")
	local f2 = O.PrepareTree(world)
	check("PrepareTree finds the barrier", #f2.barriers == 1 and f2.barriers[1] == bar)
	check("barrier invisible, collides, no touch", bar.Transparency == 1 and bar.CanCollide and not bar.CanTouch)
	check("barrier group", bar.CollisionGroup == "WindowBarrier")
	check("group: blocks Characters", PhysicsService:CollisionGroupsAreCollidable("WindowBarrier", "Characters"))
	check("group: passes Default", not PhysicsService:CollisionGroupsAreCollidable("WindowBarrier", "Default"))
	local from = bar.Position - Vector3.new(0, 0, 10)
	check("default raycast passes the barrier", workspace:Raycast(from, Vector3.new(0, 0, 20)) == nil)
	local ex = RaycastParams.new()
	ex.FilterType = Enum.RaycastFilterType.Exclude
	ex.FilterDescendantsInstances = {}
	check("exclude-filter raycast (the guns') passes it", workspace:Raycast(from, Vector3.new(0, 0, 20), ex) == nil)
	local inc = RaycastParams.new()
	inc.FilterType = Enum.RaycastFilterType.Include
	inc.FilterDescendantsInstances = { world }
	check("include-filter raycast (map walls) passes it", workspace:Raycast(from, Vector3.new(0, 0, 20), inc) == nil)
	check("spherecast (camera) passes it", workspace:Spherecast(from, 1, Vector3.new(0, 0, 20)) == nil)
	check("box query (cover probe) misses it", #workspace:GetPartBoundsInBox(bar.CFrame, Vector3.new(2, 2, 2)) == 0)
	local asChar = RaycastParams.new()
	asChar.CollisionGroup = "Characters"
	local hitAsChar = workspace:Raycast(from, Vector3.new(0, 0, 20), asChar)
	check("a Characters-group ray does hit it (it is there for bodies)", hitAsChar ~= nil and hitAsChar.Instance == bar)

	-- scripted moves (vault / dive / the AI's vault) stop at a barrier
	local bp = bar.Position
	check("move through the barrier: stopped", O.BarrierBetween(bp - Vector3.new(0, 0, 3), bp + Vector3.new(0, 0, 3)))
	check("move beside it: free", not O.BarrierBetween(bp + Vector3.new(5, 0, -3), bp + Vector3.new(5, 0, 3)))
	check("hugging it, moving away: free", not O.BarrierBetween(bp - Vector3.new(0, 0, 1), bp - Vector3.new(0, 0, 4)))
	check("hugging it, moving along it: free", not O.BarrierBetween(bp - Vector3.new(1, 0, 1), bp - Vector3.new(-1, 0, 1)))
	check("hugging it, moving into it: stopped", O.BarrierBetween(bp - Vector3.new(0, 0, 1), bp))
	check("vault arc over the sill through it: stopped", O.BarrierOnArc(bp - Vector3.new(0, 2.5, 3), bp + Vector3.new(0, 1, 0), bp + Vector3.new(0, -2.5, 3)))
	check("vault arc beside it: free", not O.BarrierOnArc(bp + Vector3.new(8, -2.5, -3), bp + Vector3.new(8, 1, 0), bp + Vector3.new(8, -2.5, 3)))

	-- bullets
	local hit, t, at = O.SegmentHit(w, BASE - Vector3.new(0, 0, 10), BASE + Vector3.new(0, 0, 30))
	check("a shot through the pane hits it", hit and t ~= nil and math.abs(t - 0.2475) < 0.01, t)
	check("hit point on the pane's face", at ~= nil and math.abs(at.Z - (BASE.Z - 0.2)) < 0.01, at)
	check("a shot that stops before the pane misses", not (O.SegmentHit(w, BASE - Vector3.new(0, 0, 10), BASE - Vector3.new(0, 0, 1))))
	check("a shot beside the pane misses", not (O.SegmentHit(w, BASE + Vector3.new(4, 0, -10), BASE + Vector3.new(4, 0, 10))))
	check("a shot along the pane's plane (above it) misses", not (O.SegmentHit(w, BASE + Vector3.new(-10, 3, 0), BASE + Vector3.new(10, 3, 0))))

	-- blasts
	check("blast 5 studs off, radius 11: breaks", (O.BlastHit(w, BASE + Vector3.new(0, 0, -5), 11)))
	check("blast 12 studs off, radius 11: no", not (O.BlastHit(w, BASE + Vector3.new(0, 0, -12), 11)))
	check("blast behind a wall: no", not (O.BlastHit(w, BASE + Vector3.new(0, 0, -5), 11, function() return true end)))
	local seen
	O.BlastHit(w, BASE + Vector3.new(0, 0, -5), 11, function(a, b) seen = { a, b } return false end)
	check("wall test runs from the blast to just in front of the pane", seen ~= nil and seen[2].Z < BASE.Z - 0.1 and seen[2].Z > BASE.Z - 1)

	-- melee (reach and angle like MeleeManager)
	local root = BASE + Vector3.new(0, -1, -2.5)
	check("swing facing the pane, 2.4 studs: breaks", (O.MeleeHit(w, root, Vector3.new(0, 0, 1), 4.5, 60)))
	check("swing facing away: no", not (O.MeleeHit(w, root, Vector3.new(0, 0, -1), 4.5, 60)))
	check("swing out of reach: no", not (O.MeleeHit(w, BASE + Vector3.new(0, 0, -8), Vector3.new(0, 0, 1), 4.5, 60)))
	check("F-key swing (180 deg) facing away: breaks", (O.MeleeHit(w, root, Vector3.new(0, 0, -1), 4.5, 180)))

	-- state
	check("Break once", O.Break(w, at, Vector3.new(0, 0, 40), "Shot"))
	check("GlassBroken + attributes", w:GetAttribute("GlassBroken") == true and w:GetAttribute("GlassCause") == "Shot"
		and typeof(w:GetAttribute("GlassHitAt")) == "Vector3" and type(w:GetAttribute("GlassBrokenAt")) == "number")
	check("hit direction stored unit", math.abs(w:GetAttribute("GlassHitDir").Magnitude - 1) < 1e-3)
	check("a second Break does nothing", not O.Break(w, at, nil, "Melee") and w:GetAttribute("GlassCause") == "Shot")
	O.Reset(w)
	check("Reset: whole, attributes cleared", w:GetAttribute("GlassBroken") == false and w:GetAttribute("GlassHitAt") == nil
		and w:GetAttribute("GlassCause") == nil and not O.IsBroken(w))
	C.Enabled = false
	check("Enabled = false: never breaks", not O.Break(w, at, nil, "Shot"))
	C.Enabled = true

	-- doors (a reader only for now)
	local door = Instance.new("Model")
	door.Name = "Door"
	door.Parent = world
	check("no DoorState = Closed", O.DoorState(door) == "Closed")
	door:SetAttribute("DoorState", "Open")
	check("DoorState Open", O.DoorState(door) == "Open")
	door:SetAttribute("DoorState", "Ajar")
	check("unknown DoorState = Closed", O.DoorState(door) == "Closed")
	check("OnDoorState does nothing yet", O.OnDoorState(door, "Open") == false)
	local conns = O.WatchDoors(world)
	check("WatchDoors watches the door", #conns == 1)
	door:SetAttribute("DoorState", "Locked")
	for _, c in conns do c:Disconnect() end

	-- the client look: pane hidden / broken look shown, shatter only for a fresh break
	local w3 = window("W3", BASE + Vector3.new(90, 0, 0))
	local binds = O.BindClient(w3)
	local g3, b3 = O.GlassParts(w3)[1], O.BrokenParts(w3)[1]
	check("intact: pane shown, broken look hidden", g3.LocalTransparencyModifier == 0 and b3.LocalTransparencyModifier == 1)
	local function shards()
		local n = 0
		for _, d in workspace:GetChildren() do if d.Name == "GlassShard" then n += 1 end end
		return n
	end
	local n0 = shards()
	O.Break(w3, g3.Position, Vector3.new(0, 0, 1), "Shot")
	task.wait()
	check("broken: pane hidden, broken look shown", g3.LocalTransparencyModifier == 1 and b3.LocalTransparencyModifier == 0)
	check("a fresh break throws shards", shards() - n0 >= 10, shards() - n0)
	O.Reset(w3)
	task.wait()
	check("reset: pane back", g3.LocalTransparencyModifier == 0 and b3.LocalTransparencyModifier == 1)
	-- an old break (a late joiner): broken look, no shatter
	w3:SetAttribute("GlassBrokenAt", workspace:GetServerTimeNow() - 10)
	local n1 = shards()
	w3:SetAttribute("GlassBroken", true)
	task.wait()
	check("an old break: broken look, no shards", g3.LocalTransparencyModifier == 1 and shards() == n1, shards() - n1)
	for _, c in binds do c:Disconnect() end
	-- a late bind sees the state
	local binds2 = O.BindClient(w3)
	check("late bind shows it broken", g3.LocalTransparencyModifier == 1)
	for _, c in binds2 do c:Disconnect() end
end)
if not ok then table.insert(results, "ERROR " .. tostring(err)) end
for _, d in workspace:GetChildren() do if d.Name == "GlassShard" then d:Destroy() end end
for _, a in workspace.Terrain:GetChildren() do if a.Name == "GlassShatter" then a:Destroy() end end
world:Destroy()
tmp:Destroy()
return ("%d/%d passed\n%s"):format(passed, total, table.concat(results, "\n"))
