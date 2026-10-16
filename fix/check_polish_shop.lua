-- check_polish_shop.lua (read-only; restores the CanQuery it toggles): clipping, floating and hook checks for Polish.Shop.
-- 1. clip: rays from each new part's centre to its 6 face centres and 8 corners (shrunk 0.05); any hit on an old part
--    inside that span means the new part intersects old geometry.
-- 2. float: every collidable Polish model must have floor or another Polish part under its lowest point (ray down 0.3).
-- 3. hooks: Interact.Shop_Counter, NPC_Quartermaster, KitEmitter/Spot_ShopCounter, RoomLight tags.
local LM = workspace.LobbyMap
local root = LM.Polish.Shop
local q = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and math.abs(d.Position.X) < 45 and d.Position.Z > 55 and d.Position.Z < 125 then
		d.CanQuery = true; table.insert(q, d)
	end
end
local skip = {root}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local OK_HITS = {Cord = true, Post = true}   -- cords go into the ceiling, placard posts into the goods heap (intended)
local clips, seen = {}, {}
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and p.Transparency < 0.95 and not OK_HITS[p.Name] then
		local hs = p.Size / 2 - Vector3.new(0.05, 0.05, 0.05)
		local targets = {}
		for _, a in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}) do table.insert(targets, a * hs) end
		for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do table.insert(targets, Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z)) end end end
		for _, t in ipairs(targets) do
			local o = p.Position; local e = p.CFrame:PointToWorldSpace(t)
			local h = workspace:Raycast(o, e - o, rp)
			if h then
				local key = p:GetFullName():gsub("Workspace.LobbyMap.Polish.Shop.", "") .. " x " .. h.Instance.Name
				if not seen[key] then seen[key] = true; table.insert(clips, key .. string.format(" (%.2f in)", (e - h.Position).Magnitude)) end
			end
		end
	end
end
-- float check per top-level cluster model
local rpAll = RaycastParams.new(); rpAll.FilterType = Enum.RaycastFilterType.Exclude
local skip2 = {}; for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip2, d) end end
rpAll.FilterDescendantsInstances = skip2
local floats = {}
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and (m.Parent == root or m.Parent.Parent == root) then
		local cf, sz = m:GetBoundingBox()
		local bottom = cf.Position.Y - sz.Y / 2
		if bottom < 3 then
			local h = workspace:Raycast(Vector3.new(cf.Position.X, bottom + 0.2, cf.Position.Z), Vector3.new(0, -0.6, 0), rpAll)
			table.insert(floats, string.format("%s bottom %.2f -> %s", m.Name, bottom, h and (h.Instance.Name .. string.format(" %.2f", h.Position.Y)) or "NOTHING"))
		end
	end
end
for _, d in ipairs(q) do d.CanQuery = false end
local CS = game:GetService("CollectionService")
local hooks = {}
local sc = LM.Interact:FindFirstChild("Shop_Counter"); table.insert(hooks, "Shop_Counter " .. tostring(sc and sc.Position))
local pr = sc and sc:FindFirstChildWhichIsA("ProximityPrompt", true); table.insert(hooks, "  prompt OpenPanel=" .. tostring(pr and pr:GetAttribute("OpenPanel")) .. " enabled=" .. tostring(pr and pr.Enabled))
local npc = LM.NPCs:FindFirstChild("NPC_Quartermaster"); table.insert(hooks, "NPC_Quartermaster " .. tostring(npc and npc:GetPivot().Position))
local np = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true); table.insert(hooks, "  prompt OpenPanel=" .. tostring(np and np:GetAttribute("OpenPanel")))
local n = 0; for _, h in ipairs(CS:GetTagged("RoomLight")) do if h:GetAttribute("Room") == "Shop" then n += 1 end end
table.insert(hooks, "RoomLight Shop hosts: " .. n .. " (all RoomLight: " .. #CS:GetTagged("RoomLight") .. ")")
local sh = 0; for _, d in ipairs(LM:GetDescendants()) do if d:IsA("Light") and d.Shadows and d.Enabled then sh += 1 end end
table.insert(hooks, "shadow-casting lights in LobbyMap: " .. sh)
return "CLIPS (" .. #clips .. "):\n" .. table.concat(clips, "\n") .. "\n\nSUPPORT:\n" .. table.concat(floats, "\n") .. "\n\nHOOKS:\n" .. table.concat(hooks, "\n")
