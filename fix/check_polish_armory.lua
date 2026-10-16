-- check_polish_armory.lua (read-only; restores the CanQuery it toggles): clipping, floating, light and hook checks
-- for Polish.Armory.
-- 1. clip (rays): from each new part's centre to its 6 face centres and 8 corners (shrunk 0.05); a hit on an old part
--    inside that span means the new part intersects old geometry.
-- 2. clip (probe): GetPartsInPart with a copy 0.12 smaller than each new part (catches thin parts the rays miss).
-- 3. float: every top-level Polish model must have floor/old geometry under it, or (wall pieces) wall behind it.
-- 4. hooks: Interact.GunWall_Kit / Armory_Dais prompts, NPC_Supply, FeaturedScissors Spin, RoomLight tags, lights.
-- 5. round 2 (polish_armory2.lua): every WeaponSlot_* has an Anchor (PrimaryPart), WeaponId = its config entry, exactly one
--    visible Weapon model and no welds/joints/constraints; the featured slot sits inside FeaturedScissors; baked guns hidden.
local LM = workspace.LobbyMap
local root = LM.Polish.Armory
local CS = game:GetService("CollectionService")
local function inArmory(p) return math.abs(p.X) < 40 and p.Z < -55 and p.Z > -125 end
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and inArmory(d.Position) and not d:IsDescendantOf(root) then
		d.CanQuery = true; table.insert(q, d)
	end
end
local skip = {root}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local clips, seen = {}, {}
local function note(p, h, extra)
	local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Armory.", "") .. " x " .. h.Name
	if not seen[key] then seen[key] = true; table.insert(clips, key .. (extra or "")) end
end
local FSLOT = LM.Rooms.Armory:FindFirstChild("FeaturedScissors") and LM.Rooms.Armory.FeaturedScissors:FindFirstChild("WeaponSlot_Featured_1")
local newParts = root:GetDescendants()
if FSLOT then for _, d in ipairs(FSLOT:GetDescendants()) do table.insert(newParts, d) end; table.insert(skip, FSLOT) end
rp.FilterDescendantsInstances = skip
for _, p in ipairs(newParts) do
	if p:IsA("BasePart") and p.Transparency < 0.95 then
		local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
		local targets = {}
		for _, a in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, a * hs) end
		for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z)) end end end
		for _, t in ipairs(targets) do
			local o = p.Position; local e = p.CFrame:PointToWorldSpace(t)
			local h = workspace:Raycast(o, e - o, rp)
			if h then note(p, h.Instance, string.format(" (ray, %.2f in)", (e - h.Position).Magnitude)) end
		end
	end
end
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = skip
local tmp = Instance.new("Folder"); tmp.Name = "_ArmoryProbe"; tmp.Parent = workspace
local nProbe = 0
op.FilterDescendantsInstances = skip
for _, p in ipairs(newParts) do
	if p:IsA("BasePart") and p.Transparency < 0.95 and p.Size.X > 0.2 and p.Size.Y > 0.2 and p.Size.Z > 0.2 then
		local pr = p:Clone(); pr:ClearAllChildren(); pr.Size = p.Size - Vector3.new(0.12, 0.12, 0.12)
		pr.Transparency = 1; pr.CanCollide = false; pr.CanQuery = true; pr.Parent = tmp
		nProbe += 1
		for _, h in ipairs(workspace:GetPartsInPart(pr, op)) do
			if not h:IsDescendantOf(tmp) and h.Transparency < 0.95 then note(p, h, " (probe)") end
		end
		pr:Destroy()
	end
end
tmp:Destroy()
-- support: floor groups need something under them, wall groups something behind them
local floats = {}
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and (m.Parent == root or m.Parent.Parent == root) and m.Name:sub(1, 4) ~= "Gun_" then
		local cf, sz = m:GetBoundingBox()
		local p = cf.Position
		local bottom = p.Y - sz.Y / 2
		local h
		if bottom < 3 then
			h = workspace:Raycast(Vector3.new(p.X, bottom + 0.2, p.Z), Vector3.new(0, -0.6, 0), rp)
		else
			local sgn = p.X < 0 and -1 or 1
			h = workspace:Raycast(Vector3.new(p.X, p.Y, p.Z), Vector3.new(sgn * 2.5, 0, 0), rp)
		end
		table.insert(floats, string.format("%s bottom %.2f -> %s", m.Name, bottom, h and (h.Instance.Name .. string.format(" @%.2f,%.2f", h.Position.X, h.Position.Y)) or "NOTHING"))
	end
end
for _, d in ipairs(q) do d.CanQuery = false end

local hooks = {}
for _, n in ipairs({"GunWall_Kit", "Armory_Dais"}) do
	local i = LM.Interact:FindFirstChild(n)
	local pr = i and i:FindFirstChildWhichIsA("ProximityPrompt", true)
	table.insert(hooks, string.format("%s %s prompt OpenPanel=%s enabled=%s", n, tostring(i and i.Position), tostring(pr and pr:GetAttribute("OpenPanel")), tostring(pr and pr.Enabled)))
end
local npc = LM.NPCs:FindFirstChild("NPC_Supply")
local np = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true)
table.insert(hooks, "NPC_Supply " .. tostring(npc and npc:GetPivot().Position) .. " OpenPanel=" .. tostring(np and np:GetAttribute("OpenPanel")))
local fs = LM.Rooms.Armory:FindFirstChild("FeaturedScissors")
table.insert(hooks, "FeaturedScissors Spin=" .. tostring(fs and fs:GetAttribute("Spin")) .. " at " .. tostring(fs and fs:GetPivot().Position))
local n = 0; for _, h in ipairs(CS:GetTagged("RoomLight")) do if h:GetAttribute("Room") == "Armory" then n += 1 end end
table.insert(hooks, "RoomLight Armory hosts: " .. n .. " (all RoomLight: " .. #CS:GetTagged("RoomLight") .. ")")
local nl = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then nl += 1 end end
table.insert(hooks, "new lights in Polish.Armory: " .. nl)
local sh = 0; for _, d in ipairs(LM:GetDescendants()) do if d:IsA("Light") and d.Shadows and d.Enabled then sh += 1 end end
table.insert(hooks, "shadow-casting lights in LobbyMap: " .. sh)
local blockers = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") and d.CanCollide then blockers += 1 end end
table.insert(hooks, "collidable new parts: " .. blockers)
-- 5. weapon slots
local slots = {}
local okMod, cfg = pcall(function() return require(game:GetService("ServerStorage").ArmoryWeaponSlots:Clone()) end)
local nSlot, slotBad, welds = 0, {}, 0
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("Model") and d.Name:match("^WeaponSlot_") then
		nSlot += 1
		local a = d:FindFirstChild("Anchor")
		local w = d:FindFirstChild("Weapon")
		local want = okMod and (cfg.Slots[d.Name] or cfg.Default)
		local vis = 0
		if w then for _, x in ipairs(w:GetDescendants()) do
			if x:IsA("BasePart") and x.Transparency < 0.5 then vis += 1 end
			if x:IsA("JointInstance") or x:IsA("Constraint") or x:IsA("WeldConstraint") then welds += 1 end
		end end
		if not (a and d.PrimaryPart == a and w and vis > 0 and d:GetAttribute("WeaponId") == want) then
			table.insert(slotBad, d:GetFullName())
		end
	end
end
table.insert(hooks, ("weapon slots: %d (config module %s), bad %d, welds/joints in weapons %d, featured slot inside FeaturedScissors: %s"):format(
	nSlot, okMod and "ok" or "MISSING", #slotBad, welds, tostring(FSLOT ~= nil)))
for _, b in ipairs(slotBad) do table.insert(hooks, "  BAD " .. b) end
local baked = 0
for _, n in ipairs({"A_GunWall__case_dark", "A_GunWall__drum_olive", "A_GunWall__dark_metal", "A_Benches__case_dark", "A_Displays__dark_metal", "A_Displays__drum_olive"}) do
	local p = LM.Rooms2:FindFirstChild(n, true); if p and p.Transparency < 1 then baked += 1 end
end
for _, p in ipairs(LM.Rooms2.A_Racks:GetDescendants()) do if p:IsA("BasePart") and p.Transparency < 1 then baked += 1 end end
table.insert(hooks, "baked weapon meshes still visible: " .. baked)
local tag = LM.NPCs.NPC_Supply:FindFirstChild("Tag")
table.insert(hooks, "NPC_Supply tag " .. tostring(tag and tag.Size) .. " offset " .. tostring(tag and tag.StudsOffset))

return "CLIPS (" .. #clips .. ", probes " .. nProbe .. "):\n" .. table.concat(clips, "\n") .. "\n\nSUPPORT:\n" .. table.concat(floats, "\n") .. "\n\nHOOKS:\n" .. table.concat(hooks, "\n")
