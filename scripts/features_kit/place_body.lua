-- scripts/features_kit/place_body.lua : body of fix/place_features_kit.lua (MESH / PIECE tables are generated above it).
-- Bookkeeping (all own attributes, prefix FK_):
--   FK_New      on every instance this script creates (destroyed by UNDO)
--   records     ServerStorage._FeaturesKitRemoved.Records: ObjectValue per moved instance (Value = it, child From = old parent),
--               restored in reverse order by UNDO. "Removed" originals sit in ServerStorage._FeaturesKitRemoved.
--   FK_Hidden   hidden in place (FK_T/FK_C/FK_Q/FK_Tc saved); FK_OrigCF / FK_OrigSize for moved/resized parts.
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
local M, F = Enum.Material, Enum.NormalId

local TEX = {hazard = "rbxassetid://79584884795039", grate = "rbxassetid://119843963596060"}   -- own (tex/asset_ids.json)
local CREAM, INK, OLIVE = rgb(236, 232, 218), rgb(10, 12, 10), rgb(138, 156, 74)
local TITLE = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

---------------------------------------------------------------- bookkeeping
local function stashFolder()
	local s = SS:FindFirstChild("_FeaturesKitRemoved")
	if not s then s = Instance.new("Folder"); s.Name = "_FeaturesKitRemoved"; s.Parent = SS end
	local r = s:FindFirstChild("Records")
	if not r then r = Instance.new("Folder"); r.Name = "Records"; r.Parent = s end
	return s, r
end
local nRec = 0
local function move(inst, newParent)          -- re-parent with a record (UNDO puts it back)
	local _, R = stashFolder()
	nRec += 1
	local rec = Instance.new("ObjectValue"); rec.Name = string.format("R%05d", #R:GetChildren() + 1); rec.Value = inst
	local from = Instance.new("ObjectValue"); from.Name = "From"; from.Value = inst.Parent; from.Parent = rec
	if inst:IsA("Attachment") then rec:SetAttribute("AttCF", inst.CFrame) end   -- local CFrame (re-parenting keeps it, not the world one)
	rec.Parent = R
	inst.Parent = newParent
end
local function remove(inst) move(inst, (stashFolder())) end   -- "delete" UNDO-ably
local function mark(inst) inst:SetAttribute("FK_New", true); return inst end
local function hide(inst)
	if inst:GetAttribute("FK_Hidden") then return end
	if inst:IsA("BasePart") then
		inst:SetAttribute("FK_T", inst.Transparency); inst:SetAttribute("FK_C", inst.CanCollide)
		inst:SetAttribute("FK_Q", inst.CanQuery); inst:SetAttribute("FK_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
		for _, d in inst:GetChildren() do if d:IsA("Decal") then hide(d) end end   -- Texture is a Decal
	elseif inst:IsA("Decal") then
		inst:SetAttribute("FK_T", inst.Transparency); inst.Transparency = 1
	else return end
	inst:SetAttribute("FK_Hidden", true)
end
local function setCF(p, cf, size)              -- move / resize an existing part (original kept)
	if p:GetAttribute("FK_OrigCF") == nil then p:SetAttribute("FK_OrigCF", p.CFrame) end
	if size and p:GetAttribute("FK_OrigSize") == nil then p:SetAttribute("FK_OrigSize", p.Size) end
	if size then p.Size = size end
	p.CFrame = cf
end

local function undoAll()
	local S = SS:FindFirstChild("_FeaturesKitRemoved")
	local R = S and S:FindFirstChild("Records")
	local nBack, nStale = 0, 0
	if R then
		local recs = R:GetChildren()
		table.sort(recs, function(a, b) return a.Name > b.Name end)
		for _, rec in recs do
			local inst, from = rec.Value, rec:FindFirstChild("From") and rec.From.Value
			if inst then
				local clash = from and from:FindFirstChild(inst.Name)
				if clash == inst then clash = nil end
				if clash and (clash:GetAttribute("FK_New") or clash:FindFirstAncestorWhichIsA("Model") and clash:FindFirstAncestorWhichIsA("Model"):GetAttribute("FK_New")) then clash = nil end
				local alive = from and (from:IsDescendantOf(workspace) or from:IsDescendantOf(SS) and from ~= S and not from:IsDescendantOf(S))
				-- a stashed original whose old parent was rebuilt meanwhile (fix/install_features.lua re-run) is stale: drop it
				if alive and not (clash and inst:IsA("BasePart") and inst.Name == "Screen_Leaderboard") then
					inst.Parent = from; nBack += 1
					if rec:GetAttribute("AttCF") then inst.CFrame = rec:GetAttribute("AttCF") end
				else
					inst:Destroy(); nStale += 1
				end
			end
		end
	end
	local nNew = 0
	for _, root in {LM, SS} do
		for _, d in root:GetDescendants() do
			if d.Parent and d:GetAttribute("FK_New") then d:Destroy(); nNew += 1 end
		end
	end
	local nHid = 0
	for _, d in LM:GetDescendants() do
		if d:GetAttribute("FK_Hidden") then
			if d:IsA("BasePart") then
				d.Transparency = d:GetAttribute("FK_T"); d.CanCollide = d:GetAttribute("FK_C"); d.CanQuery = d:GetAttribute("FK_Q"); d.CanTouch = d:GetAttribute("FK_Tc")
			else d.Transparency = d:GetAttribute("FK_T") end
			for _, a in {"FK_Hidden", "FK_T", "FK_C", "FK_Q", "FK_Tc"} do d:SetAttribute(a, nil) end
			nHid += 1
		end
		if d:IsA("BasePart") and d:GetAttribute("FK_OrigCF") ~= nil then
			if d:GetAttribute("FK_OrigSize") ~= nil then d.Size = d:GetAttribute("FK_OrigSize"); d:SetAttribute("FK_OrigSize", nil) end
			d.CFrame = d:GetAttribute("FK_OrigCF"); d:SetAttribute("FK_OrigCF", nil)
		end
		if d:IsA("BasePart") and d:GetAttribute("FK_FloorHidden") then
			d.Transparency = d:GetAttribute("FK_OrigT"); d.CanQuery = d:GetAttribute("FK_OrigQ")
			for _, a in {"FK_FloorHidden", "FK_OrigT", "FK_OrigQ"} do d:SetAttribute(a, nil) end
		end
	end
	-- swap bins: PrimaryPart back to the old Body
	local sb = LM.Training:FindFirstChild("Extras") and LM.Training.Extras:FindFirstChild("SwapBins")
	for _, m in (sb and sb:GetChildren() or {}) do
		if m:IsA("Model") and not m.PrimaryPart and m:FindFirstChild("Body") then m.PrimaryPart = m.Body end
	end
	if S then S:Destroy() end
	say("undo: restored", nBack, "stale dropped", nStale, "new removed", nNew, "unhidden", nHid)
end

---------------------------------------------------------------- templates (ServerStorage.features -> ServerStorage.FeaturesKit)
local function styleMesh(p, d)
	if p:GetAttribute("FK_Orig") == nil then
		p:SetAttribute("FK_Orig", table.concat({p.Material.Name, p.MaterialVariant, p.Color:ToHex(), tostring(p.CanCollide), tostring(p.CanQuery),
			tostring(p.CanTouch), tostring(p.CastShadow), tostring(p.Transparency), p.CollisionFidelity.Name}, "|"))
	end
	p.Anchored = true
	p.Color = rgb(d[1], d[2], d[3]); p.Material = M[d[4]]; p.MaterialVariant = d[5]
	p.CanCollide = d[6]; p.CanQuery = d[7]; p.CanTouch = false
	p.Transparency = d[10]; p.CastShadow = d[11] and d[4] ~= "Neon" and d[4] ~= "Glass"
	if d[8] then p:SetAttribute("NotCover", true) else p:SetAttribute("NotCover", nil) end
	local fid = (d[6] or d[7]) and Enum.CollisionFidelity[d[9]] or Enum.CollisionFidelity.Box
	if p.CollisionFidelity ~= fid then p.CollisionFidelity = fid end
	local ov = d[12]
	if ov ~= "" then
		local isHaz = ov:find("hazard")
		local t = Instance.new("Texture"); t.Name = "FK_" .. (isHaz and "hazard" or "grate"); t.Face = F.Top
		t.Texture = isHaz and TEX.hazard or TEX.grate
		t.StudsPerTileU = isHaz and 4 or 3; t.StudsPerTileV = isHaz and 1 or 3
		t.Color3 = isHaz and Color3.new(1, 1, 1) or rgb(76, 76, 72); t.Parent = p
		if isHaz then p.Color = INK end   -- as hub1/rooms3: dark base, the texture carries the stripes
	end
end
local function unstyleMesh(p)
	local o = p:GetAttribute("FK_Orig"); if not o then return end
	local a = string.split(o, "|")
	p.Material = M[a[1]]; p.MaterialVariant = a[2]; p.Color = Color3.fromHex(a[3]); p.CanCollide = a[4] == "true"; p.CanQuery = a[5] == "true"
	p.CanTouch = a[6] == "true"; p.CastShadow = a[7] == "true"; p.Transparency = tonumber(a[8])
	if p.CollisionFidelity.Name ~= a[9] then p.CollisionFidelity = Enum.CollisionFidelity[a[9]] end
	p:SetAttribute("FK_Orig", nil); p:SetAttribute("NotCover", nil)
	for _, t in p:GetChildren() do if t.Name:match("^FK_") then t:Destroy() end end
end

local function buildTemplates()
	-- markers out of the way (as every earlier kit)
	local src0, RR = SS:FindFirstChild("features"), SS:FindFirstChild("_RebuildRemoved")
	for _, n in {"K_Scale5", "K_Marker5"} do local k = src0 and src0:FindFirstChild(n); if k and RR then move(k, RR) end end
	local KIT = SS:FindFirstChild("FeaturesKit")
	if KIT then return KIT end
	local src = SS:FindFirstChild("features")
	assert(src, "ServerStorage.features (the imported kit) is missing")
	KIT = Instance.new("Folder"); KIT.Name = "FeaturesKit"
	KIT:SetAttribute("Note", "Feature props kit templates (kit/features.fbx). Piece Models at their FBX row positions; pivot = piece pivot. fix/place_features_kit.lua")
	local models = {}
	for _, p in src:GetChildren() do
		if p:IsA("MeshPart") then
			local piece = p.Name:match("^(.-)__")
			if PIECE[piece] and MESH[p.Name] then
				styleMesh(p, MESH[p.Name])
				local m = models[piece]
				if not m then m = Instance.new("Model"); m.Name = piece; models[piece] = m; m.Parent = KIT end
				p.Parent = m
			end
		end
	end
	for piece, m in models do
		local body
		for _, p in m:GetChildren() do if MESH[p.Name] and MESH[p.Name][13] == "collision_body" then body = p end end
		if not body then
			local best = 0
			for _, p in m:GetChildren() do local v = p.Size.X * p.Size.Y * p.Size.Z; if v > best then best = v; body = p end end
		end
		m.PrimaryPart = body
		body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(PIECE[piece].pivot))
	end
	KIT.Parent = SS
	local n = 0; for _ in models do n += 1 end
	say("templates: ServerStorage.FeaturesKit", n, "piece models")
	return KIT
end
local function undoTemplates()
	local KIT = SS:FindFirstChild("FeaturesKit"); if not KIT then return end
	local src = SS:FindFirstChild("features")
	if not src then src = Instance.new("Folder"); src.Name = "features"; src.Parent = SS end
	for _, m in KIT:GetChildren() do
		for _, p in m:GetChildren() do
			if p:IsA("MeshPart") then unstyleMesh(p); p.PivotOffset = CFrame.new(); p.Parent = src end
		end
	end
	KIT:Destroy()
	say("templates returned to ServerStorage.features (import look)")
end

---------------------------------------------------------------- placing
local KIT
-- clone a piece, scale it about its pivot (s = Vector3 in piece axes), put the pivot at cf
local function place(piece, cf, parent, s, name)
	local t = KIT:FindFirstChild(piece); assert(t, "no template " .. piece)
	local m = t:Clone(); m.Name = name or piece; mark(m)
	if s and (s - Vector3.one).Magnitude > 1e-4 then
		local pv = m:GetPivot()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local rel = pv:ToObjectSpace(p.CFrame)
				p.Size = p.Size * s
				p.CFrame = pv * CFrame.new(rel.Position * s) * rel.Rotation
			end
		end
		local b = m.PrimaryPart
		b.PivotOffset = b.CFrame:ToObjectSpace(pv)
		m:SetAttribute("FK_Scale", s)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end
local function mesh(m, slot)
	for _, p in m:GetChildren() do if p:IsA("BasePart") and p.Name:match("__" .. slot .. "$") then return p end end
end
local function setAll(m, props) for _, p in m:GetDescendants() do if p:IsA("BasePart") then for k, v in props do p[k] = v end end end end

local rpWorld = RaycastParams.new(); rpWorld.FilterType = Enum.RaycastFilterType.Exclude; rpWorld.RespectCanCollide = true
local function refreshFilter()
	local ex = {}
	for _, d in LM:GetDescendants() do if d:GetAttribute("FK_New") and d:IsA("Model") then table.insert(ex, d) end end
	if LM:FindFirstChild("Features") then table.insert(ex, LM.Features) end
	if LM:FindFirstChild("NPCs") then table.insert(ex, LM.NPCs) end
	if LM:FindFirstChild("Interact") then table.insert(ex, LM.Interact) end
	rpWorld.FilterDescendantsInstances = ex
end
local function down(x, z, yFrom, depth)
	local r = workspace:Raycast(Vector3.new(x, yFrom, z), Vector3.new(0, -(depth or 40), 0), rpWorld)
	return r and r.Position.Y, r
end
local function wallAt(from, dir)
	local r = workspace:Raycast(from, dir, rpWorld)
	if r and math.abs(r.Normal:Dot(-dir.Unit)) > 0.95 then return r.Position, r.Normal end
	return nil
end
local function mountCF(pos, n) n = Vector3.new(n.X, 0, n.Z).Unit; return CFrame.lookAt(pos, pos + n) end   -- -Z (Front) along n
-- how far the wall behind a wall piece's footprint sticks out past the mount plane (ribs, bands, plates): sample a 7 x 5 grid
local function protrusion(piece, cf0, s)
	local P = PIECE[piece]; s = s or Vector3.one
	local mn, mx = P.min * s, P.max * s
	local prot = 0
	for i = 0, 6 do for j = 0, 4 do
		local o = cf0 * Vector3.new(mn.X + (mx.X - mn.X) * i / 6, mn.Y + (mx.Y - mn.Y) * j / 4, -3)
		local h = workspace:Raycast(o, cf0.LookVector * -6, rpWorld)
		if h then prot = math.max(prot, 3 - (h.Position - o).Magnitude) end
	end end
	return prot
end

-- clearance: parts (collision/query) inside the piece's bounds, shrunk by `pad`, ignoring the piece and `ignore`
local function clearance(m, piece, pad, ignore)
	local P = PIECE[piece]; local s = m:GetAttribute("FK_Scale") or Vector3.one
	local mn, mx = P.min * s, P.max * s
	local c = (mn + mx) / 2; local size = (mx - mn) - Vector3.new(pad, pad, pad) * 2
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {m}; for _, i in ignore or {} do table.insert(ex, i) end
	op.FilterDescendantsInstances = ex
	local hits = workspace:GetPartBoundsInBox(m:GetPivot() * CFrame.new(c), size, op)
	local names, seen = {}, {}
	for _, h in hits do
		if h.CanCollide or h.CanQuery then
			-- bounds test is coarse for big merged meshes: confirm with GetPartsInPart on a probe
			if not seen[h.Name] then seen[h.Name] = true; table.insert(names, h.Name) end
		end
	end
	if #names == 0 then return "clear" end
	local probe = Instance.new("Part"); probe.Anchored = true; probe.CanCollide = false; probe.Size = size
	probe.CFrame = m:GetPivot() * CFrame.new(c); probe.Parent = workspace
	local op2 = OverlapParams.new(); op2.FilterType = Enum.RaycastFilterType.Exclude
	op2.FilterDescendantsInstances = {m, probe, table.unpack(ignore or {})}
	local real = {}
	for _, h in workspace:GetPartsInPart(probe, op2) do if h.CanCollide or h.CanQuery then real[h:GetFullName():gsub("Workspace%.LobbyMap%.", "")] = true end end
	probe:Destroy()
	local r = {}; for k in real do table.insert(r, k) end
	return #r == 0 and "clear" or ("HITS " .. table.concat(r, ", "))
end

---------------------------------------------------------------- 2. screens
local function placeScreens(Fe)
	local jobs = {
		-- {screen part, kind, piece, scale, centre override (y/z/x), feature folder}
		{LM.Signs:FindFirstChild("Screen_Leaderboard"), "Leaderboard", "F_Screen16x9", Vector3.new(0.54, 0.593, 0.7)},
		{Fe.LikesBoard:FindFirstChild("Screen_Likes"), "Likes", "F_Screen16x9", Vector3.new(0.54, 0.593, 0.7)},
		{Fe.DuelsTV:FindFirstChild("Screen_DuelsTV"), "DuelsTV", "F_TVArmWall", Vector3.new(1.3, 1.3, 1.3)},
		{Fe.AdBoard:FindFirstChild("Screen_Ad"), "Ad", "F_TVArmWall", Vector3.new(1.3, 1.3, 1.3)},
		{Fe.TrainingScreen:FindFirstChild("Screen_Training"), "Training", "F_TVArmWall", Vector3.new(1.3, 1.3, 1.3), {z = -21}},
		{Fe.DuelsSign:FindFirstChild("Screen_DuelsSign"), "DuelsSign", "F_Screen12x4", Vector3.new(0.75, 0.6, 0.7), {y = 5.95}},   -- frame 4.1..8.6: clears the landing (top 4.0), header on the band
	}
	for _, j in jobs do
		local old, kind, piece, s, over = j[1], j[2], j[3], j[4], j[5] or {}
		if not old then say("screen", kind, "MISSING part: skipped"); continue end
		local n = old.CFrame.LookVector
		local c = old.Position
		c = Vector3.new(over.x or c.X, over.y or c.Y, over.z or c.Z)
		local wall, wn = wallAt(c + n * 3, -n * 8)
		if not wall then say("screen", kind, "no wall face found behind", f3(c)); continue end
		local cf = mountCF(Vector3.new(wall.X, c.Y, wall.Z), wn)
		local prot = protrusion(piece, cf, s)
		cf = cf * CFrame.new(0, 0, -prot)
		local parent = old.Parent
		if kind == "Leaderboard" then parent = LM.Signs end
		local m = place(piece, cf, parent, s, piece .. "_" .. kind)
		local scr = mesh(m, "screen")
		-- the kit screen face becomes the screen: same name, tag/attribute (or the leaderboard's name/path)
		for _, t in CS:GetTags(old) do CS:AddTag(scr, t) end
		for k, v in old:GetAttributes() do if not k:match("^FK_") then scr:SetAttribute(k, v) end end
		scr.Name = old.Name
		mark(scr)
		if kind == "Leaderboard" then scr:SetAttribute("LF_New", true); scr.Parent = LM.Signs end   -- install_features removes it on a re-install
		remove(old)   -- the temporary plate + its TempBezel / TempLip
		say("screen", kind, piece, "scale", f3(s), "at", f3(scr.Position), "face", f3(scr.Size), "wall", f3(wall), "standoff", string.format("%.2f", prot), "clearance", clearance(m, piece, 0.1))
	end
end

---------------------------------------------------------------- 3. reward stand (item 14)
local STAND = Vector3.new(-15, 0, -24)   -- ahead-left of the spawn (spawn faces -Z); clear of the Armory lane (x +-8) and the vents
local function rewardModel()
	local src = RS:FindFirstChild("Repository") and RS.Repository:FindFirstChild("Weapons") and RS.Repository.Weapons:FindFirstChild("Sniper")
	local m = Instance.new("Model"); m.Name = "RewardModel"
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d:Clone()
				for _, c in p:GetChildren() do
					if not (c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance") or c:IsA("Decal") or c:IsA("DataModelMesh")) then c:Destroy() end
				end
				p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
				p:SetAttribute("NotCover", true)
				p.Parent = m
			end
		end
		m:SetAttribute("Source", src:GetFullName())
	end
	if #m:GetChildren() == 0 then   -- placeholder: a small olive kit crate
		local c = KIT.F_Crate4A:Clone(); for _, p in c:GetChildren() do p.Parent = m end; c:Destroy()
		m:SetAttribute("Source", "placeholder F_Crate4A")
	end
	return m
end
local function placeStand(Fe)
	local RSf = mark(Instance.new("Folder")); RSf.Name = "RewardStand"; RSf.Parent = Fe
	local fy = down(STAND.X, STAND.Z, 6) or 0
	local P = Vector3.new(STAND.X, fy, STAND.Z)
	local cf = CFrame.lookAt(P, Vector3.new(0, fy, 0))   -- name plate (-Z) faces the spawn
	local SC = 1.25   -- a touch bigger than authored so it reads from the spawn (28 studs)
	local m = place("F_RewardStand", cf, RSf, Vector3.new(SC, SC, SC))
	-- name plate text (Scale-only UI)
	local plate = mesh(m, "label_cream")
	local g = Instance.new("SurfaceGui"); g.Name = "NamePlate"; g.Face = F.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100; g.LightInfluence = 0.6; g.MaxDistance = 90; g.Parent = plate
	local function lab(parent, name, txt, pos, size, color, font)
		local l = Instance.new("TextLabel"); l.Name = name; l.BackgroundTransparency = 1; l.Position = pos; l.Size = size
		l.Text = txt; l.TextScaled = true; l.FontFace = font or TITLE; l.TextColor3 = color; l.Parent = parent; return l
	end
	lab(g, "Title", "TOP OPERATOR", UDim2.fromScale(0.06, 0.04), UDim2.fromScale(0.88, 0.26), rgb(88, 101, 48))
	lab(g, "TopName", "—", UDim2.fromScale(0.04, 0.3), UDim2.fromScale(0.92, 0.42), INK)
	lab(g, "TopWins", "", UDim2.fromScale(0.06, 0.72), UDim2.fromScale(0.88, 0.24), rgb(60, 62, 56))
	-- board over the halo, readable from the spawn
	local anchor = mark(Instance.new("Part")); anchor.Name = "BoardAnchor"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false
	anchor.CanTouch = false; anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.CFrame = cf * CFrame.new(0, 9.4 * SC, 0); anchor.Parent = m
	local bb = Instance.new("BillboardGui"); bb.Name = "TopBoard"; bb.Size = UDim2.fromScale(7, 2.1); bb.LightInfluence = 0; bb.MaxDistance = 110
	bb.Parent = anchor
	lab(bb, "Header", "#1  TOP OPERATOR", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.32), OLIVE)
	lab(bb, "BoardName", "—", UDim2.fromScale(0, 0.3), UDim2.fromScale(1, 0.48), CREAM)
	lab(bb, "BoardWins", "", UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), rgb(200, 196, 186))
	for _, l in bb:GetChildren() do local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Color = INK; st.Transparency = 0.2; st.Parent = l end
	-- reward model on the spin anchor (0, 6, 0): parts welded to an anchored SpinRoot tagged LobbySpin (LobbyFX spins it)
	local rm = rewardModel(); mark(rm)
	local bcf, bsz = rm:GetBoundingBox()
	local longest = math.max(bsz.X, bsz.Y, bsz.Z)
	if longest > 0 then rm:ScaleTo(rm:GetScale() * (3.4 * SC / longest)) end
	bcf, bsz = rm:GetBoundingBox()
	local spinAt = cf * CFrame.new(0, 6 * SC, 0)
	rm:PivotTo(rm:GetPivot() + (spinAt.Position - bcf.Position))
	local root = Instance.new("Part"); root.Name = "SpinRoot"; root.Anchored = true; root.CanCollide = false; root.CanQuery = false; root.CanTouch = false
	root.Transparency = 1; root.Size = Vector3.new(0.2, 0.2, 0.2); root.CFrame = CFrame.new(spinAt.Position); root.Parent = rm
	for _, p in rm:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			local w = Instance.new("WeldConstraint"); w.Part0 = root; w.Part1 = p; w.Parent = p
		end
	end
	rm.PrimaryPart = root
	root:SetAttribute("spin", 40); root:SetAttribute("bob", true)
	CS:AddTag(root, "LobbySpin")
	rm.Parent = RSf
	say("reward stand at", f3(P), "facing spawn; reward", rm:GetAttribute("Source"), "size", f3(select(2, rm:GetBoundingBox())), "clearance", clearance(m, "F_RewardStand", 0.15))
end

---------------------------------------------------------------- 4. drop pits (kit rim, slab floor with real holes)
local HOLE_W, HOLE_L = 8, 10          -- x / z (kit hole is 10 x 10: rim scaled 0.8 in X so 5+ stud walkways stay either side)
local PITS = {{x = -114, z = 17}, {x = -114, z = -17}}
local function placePits(Fe)
	local DP = Fe:FindFirstChild("DropPits"); assert(DP, "Features.DropPits missing")
	local D = LM.Rooms3.D_Floor
	local field, border = D.D_Floor__floor_field, D.D_Floor__floor_border
	local FY, BY = 16.0, 16.03     -- field / border tops (measured)
	-- visible floor slabs (field + border frame) with the two holes; non-colliding (collision = FloorProxy)
	local VF = mark(Instance.new("Folder")); VF.Name = "FloorSlabs"; VF.Parent = DP
	local function slab(src, x0, x1, z0, z1, top)
		if x1 - x0 < 0.01 or z1 - z0 < 0.01 then return end
		local p = Instance.new("Part"); p.Name = "Slab_" .. (src == field and "field" or "border"); p.Anchored = true
		p.Size = Vector3.new(x1 - x0, 1, z1 - z0); p.CFrame = CFrame.new((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2)
		p.Material = src.Material; p.MaterialVariant = src.MaterialVariant; p.Color = src.Color
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("NotCover", true); p.Parent = VF
	end
	local fx0, fx1, fz = -137.35, -97.65, 42.35
	local hx0, hx1 = -114 - HOLE_W / 2, -114 + HOLE_W / 2
	-- the visible hole is 0.1 wider each side than the walkable one: the slab edges hide behind the kit lip/liner (no coplanar faces)
	local vx0, vx1, vz0, vz1 = hx0 - 0.1, hx1 + 0.1, 12 - 0.1, 22 + 0.1
	slab(field, fx0, vx0, -fz, fz, FY); slab(field, vx1, fx1, -fz, fz, FY)
	slab(field, vx0, vx1, -fz, -vz1, FY); slab(field, vx0, vx1, -vz0, vz0, FY); slab(field, vx0, vx1, vz1, fz, FY)
	slab(border, -140, -95, 42.35, 45, BY); slab(border, -140, -95, -45, -42.35, BY)
	slab(border, -140, fx0, -42.35, 42.35, BY); slab(border, fx1, -95, -42.35, 42.35, BY)
	-- hide the two one-piece floor meshes (their look is the slabs now); DropPits off shows them again ([FEAT] in the manager)
	for _, m in {field, border} do
		if not m:GetAttribute("FK_FloorHidden") then
			m:SetAttribute("FK_OrigT", m.Transparency); m:SetAttribute("FK_OrigQ", m.CanQuery); m:SetAttribute("FK_FloorHidden", true)
			m.Transparency = 1; m.CanQuery = false
		end
	end
	-- collision proxy: same 5 slabs, holes widened to 8 x 10
	local PX = DP:FindFirstChild("FloorProxy")
	local want = {
		{-140, hx0, -45, 45}, {hx1, -95, -45, 45}, {hx0, hx1, -12, 12}, {hx0, hx1, 22, 45}, {hx0, hx1, -45, -22},
	}
	local pr = PX and PX:GetChildren() or {}
	table.sort(pr, function(a, b) return a.Position.X + a.Position.Z * 0.001 < b.Position.X + b.Position.Z * 0.001 end)
	-- match by role: widest x-span west, east, then the centre strips by z
	local west, east, mids = nil, nil, {}
	for _, p in pr do
		if p.Position.X < -120 then west = p elseif p.Position.X > -108 then east = p else table.insert(mids, p) end
	end
	table.sort(mids, function(a, b) return a.Position.Z < b.Position.Z end)   -- -33.5, 0, 33.5
	local order = {west, east, mids[2], mids[3], mids[1]}
	for i, w in want do
		local p = order[i]
		if p then
			local top = p.Position.Y + p.Size.Y / 2
			setCF(p, CFrame.new((w[1] + w[2]) / 2, top - 0.5, (w[3] + w[4]) / 2), Vector3.new(w[2] - w[1], 1, w[4] - w[3]))
		end
	end
	-- each pit: kit rim (scaled 0.8 x), old rim/lip/void/shaft parts removed, catch resized, KEEP CLEAR moved off the rim
	for i, P in PITS do
		local pit = DP:FindFirstChild("Pit_" .. i)
		if not pit then say("pit", i, "missing"); continue end
		for _, c in pit:GetChildren() do
			if c.Name == "Void" or c.Name == "Rim" or c.Name == "Lip" or c.Name == "Shaft" then remove(c) end
		end
		local m = place("F_PitRim", CFrame.new(P.x, FY, P.z), pit, Vector3.new(HOLE_W / 10, 1, HOLE_L / 10), "KitRim")
		setAll(m, {CanCollide = false, CanQuery = false, CanTouch = false})   -- the rim floor is the proxy slab; a Box hull would close the hole
		local catch = pit:FindFirstChild("Catch")
		if catch then setCF(catch, CFrame.new(P.x, catch.Position.Y, P.z), Vector3.new(HOLE_W, catch.Size.Y, HOLE_L)) end
		local st = pit:FindFirstChild("Stencil_KEEPCLEAR")
		if st then
			local sgn = P.z > 0 and 1 or -1
			setCF(st, st.CFrame + Vector3.new(0, 0, P.z - sgn * (HOLE_L / 2 + 1.2 + 0.85) - st.Position.Z))
		end
		say("pit", i, "rim at", f3(m:GetPivot().Position), "hole", HOLE_W, "x", HOLE_L, "catch", catch and f3(catch.Size))
	end
	say("pit floor: field/border meshes hidden; slabs", #VF:GetChildren())
end

---------------------------------------------------------------- 5. fixtures: spotlights, beacons, hologram cones
local function placeFixtures(Fe)
	-- 29 spotlights -> F_TrussSpot clamped at the old rod top, tilted toward the target (max 60 deg); light on an aimed attachment
	local nS = 0
	for _, sp in Fe.Spotlights:GetChildren() do
		local H = sp:FindFirstChild("Housing"); if not H then continue end
		local light = H:FindFirstChildWhichIsA("SpotLight")
		local dir = H.CFrame.LookVector
		local rod, yoke = sp:FindFirstChild("Rod"), sp:FindFirstChild("Yoke")
		local top = rod and (rod.Position.Y + rod.Size.Y / 2) or (yoke and yoke.Position.Y + 0.1) or H.Position.Y + 0.85
		local mount = Vector3.new(H.Position.X, top, H.Position.Z)
		local hd = Vector3.new(dir.X, 0, dir.Z); hd = hd.Magnitude > 1e-3 and hd.Unit or Vector3.zAxis
		local theta = math.min(math.acos(math.clamp(-dir.Y, -1, 1)), math.rad(60))
		local cf = CFrame.lookAt(mount, mount + hd) * CFrame.Angles(theta, 0, 0)
		local m = place("F_TrussSpot", cf, sp, nil, "KitSpot")
		local lens = mesh(m, "lens_warm")
		local att = mark(Instance.new("Attachment")); att.Name = "Aim"; att.Parent = lens
		att.WorldCFrame = CFrame.lookAt(lens.Position, lens.Position + dir)
		if light then move(light, att); light.Face = F.Front end
		for _, c in sp:GetChildren() do if c:IsA("BasePart") and not c:GetAttribute("FK_New") then remove(c) end end
		nS += 1
	end
	say("spotlights ->", nS, "F_TrussSpot (lights re-parented to an aimed attachment on the lens)")
	-- 30 beacons -> F_BeaconMast (scale 0.5, 7.2 tall) standing where the old base stood; lamp tag/light/phase on the kit lens
	local nB = 0
	for _, b in Fe.Beacons:GetChildren() do
		local base, lamp = b:FindFirstChild("Base"), b:FindFirstChild("Lamp"); if not (base and lamp) then continue end
		local by = base.Position.Y - 0.175   -- the old base was built at mount + 0.175
		local m = place("F_BeaconMast", CFrame.new(base.Position.X, by, base.Position.Z), b, Vector3.new(0.5, 0.5, 0.5), "KitBeacon")
		local lens = mesh(m, "lens_amber")
		lens.Color = lamp.Color
		lens:SetAttribute("Phase", lamp:GetAttribute("Phase") or 0)
		local pl = lamp:FindFirstChildWhichIsA("Light"); if pl then move(pl, lens) end
		CS:AddTag(lens, "LF_Beacon")
		remove(base); remove(lamp)
		nB += 1
		say("beacon", b.Name, "mast base", f3(Vector3.new(base.Position.X, by, base.Position.Z)), "lens", f3(lens.Position), "clearance", clearance(m, "F_BeaconMast", 0.1))
	end
	-- 31 hologram cones -> F_HoloEmitter under each cone (Beam + attachments re-parented to the kit lens; kit cone shell dropped)
	local IX = Fe.InteractFX
	local CONES = {
		{"Cone_ShopCounter", 0.45}, {"Cone_GunWall", 0.8, "Ring_GunWall"}, {"Cone_ArmoryDais", 0.6},
	}
	for _, c in CONES do
		local host = IX:FindFirstChild(c[1]); if not host then continue end
		local A0, A1, beam = host:FindFirstChild("A0"), host:FindFirstChild("A1"), host:FindFirstChildWhichIsA("Beam")
		local a1w = A1 and A1.WorldPosition
		local base = host.Position
		local fy = down(base.X, base.Z, base.Y + 2, 6) or base.Y
		local s = c[2]
		local m = place("F_HoloEmitter", CFrame.new(base.X, fy, base.Z), IX, Vector3.new(s, s, s), "KitEmitter_" .. c[1]:gsub("Cone_", ""))
		local shell = mesh(m, "holo_cone"); if shell then shell:Destroy() end
		setAll(m, {CanQuery = false})   -- never in the way of the interactable's prompt line of sight
		local lens = mesh(m, "holo_lens")
		local topY = fy + 0.93 * s
		if A0 then move(A0, lens); A0.WorldPosition = Vector3.new(base.X, topY + 0.02, base.Z) end
		if A1 then move(A1, lens); A1.WorldPosition = a1w end
		if beam then move(beam, lens) end
		remove(host)
		if c[3] and IX:FindFirstChild(c[3]) then remove(IX[c[3]]) end   -- the kit carries its own olive floor ring
		say("emitter", c[1], "scale", s, "base y", string.format("%.2f", fy), "clearance", clearance(m, "F_HoloEmitter", 0.15))
	end
end

---------------------------------------------------------------- 6. industrial props (RIVALS manner: along walls, corridor ceilings, hangar edges)
-- floor pieces: {piece, x, z, yaw deg, scale?, colour?}; wall pieces: {piece, from (inside the room), dir (toward the wall), y (pivot), along?}
local OLIVE_DRAB, SAGE, WARM, NEAR_BLACK = rgb(88, 98, 58), rgb(167, 173, 152), rgb(200, 196, 186), rgb(40, 42, 38)
-- hangar: the only free floor pocket off the routes is north of the walkway at the tunnel end (searched with GetPartsInPart on a
-- 2-stud grid; the south side is the diagonal hangar -> pad route, the deck edges are E_Gear / E_PadWalls / the heli)
local FLOOR_PROPS = {
	-- one container only (v1 had a warm-grey 20 + a stacked 10: read white and walled off the hangar view / mouth beacon)
	{"F_Container20", 117.0, 13.5, 180, OLIVE_DRAB, "hangar north pocket by the tunnel mouth, doors toward the tunnel"},
}
local WALL_PROPS = {
	-- east tunnel (x 88..106, walls z +-11, ceiling ~15)
	{"F_PipeRun", Vector3.new(97, 9.6, 0), Vector3.new(0, 0, 20), "tunnel north wall, high"},
	{"F_PipeRun", Vector3.new(97, 9.6, 0), Vector3.new(0, 0, -20), "tunnel south wall, high"},
	{"F_PowerBox", Vector3.new(100, 4.1, 0), Vector3.new(0, 0, -20), "tunnel south wall"},
	{"F_JunctionBox", Vector3.new(92.5, 6.2, 0), Vector3.new(0, 0, 20), "tunnel north wall"},
	{"F_PowerBox", Vector3.new(97.5, 4.1, 0), Vector3.new(0, 0, 20), "tunnel north wall, under the pipes"},
	{"F_Intercom", Vector3.new(103.5, 5.2, 0), Vector3.new(0, 0, 20), "tunnel north wall, hangar end"},
	-- north corridor (Shop; x +-5.2, z 44..72, ceiling ~12.3)
	{"F_PipeRun", Vector3.new(0, 8.4, 56), Vector3.new(20, 0, 0), "Shop corridor east wall, under the rib caps"},
	{"F_Intercom", Vector3.new(0, 5.2, 47.5), Vector3.new(-20, 0, 0), "Shop corridor west wall, hub end"},
	{"F_JunctionBox", Vector3.new(0, 6.6, 54), Vector3.new(-20, 0, 0), "Shop corridor west wall, between ribs"},
	-- south corridor (Armory)
	{"F_PipeRun", Vector3.new(0, 8.4, -56), Vector3.new(-20, 0, 0), "Armory corridor west wall, under the rib caps"},
	-- (no power box in the corridors: 1.3 deep at walking height takes the Armory corridor under check_rooms2's 9.5 minimum)
	{"F_Intercom", Vector3.new(0, 5.2, -47.5), Vector3.new(20, 0, 0), "Armory corridor east wall, hub end"},
}
local function placeProps(Fe)
	local PF = mark(Instance.new("Folder")); PF.Name = "IndustrialProps"; PF.Parent = LM
	local ex = rpWorld.FilterDescendantsInstances; table.insert(ex, PF); rpWorld.FilterDescendantsInstances = ex
	for _, pr in FLOOR_PROPS do
		local fy = pr[7] or down(pr[2], pr[3], 12) or 0
		local m = place(pr[1], CFrame.new(pr[2], fy, pr[3]) * CFrame.Angles(0, math.rad(pr[4]), 0), PF)
		local body = mesh(m, "container_olive"); if body then body.Color = pr[5] end
		say("prop", pr[1], f3(m:GetPivot().Position), pr[6], "clearance", clearance(m, pr[1], 0.12))
	end
	for _, pr in WALL_PROPS do
		local from = pr[2]
		local r = workspace:Raycast(from, pr[3], rpWorld)
		if not r then say("prop", pr[1], "NO WALL from", f3(from), pr[4]); continue end
		-- flush to the most protruding surface over the piece's footprint (ribs, bands): sample the wall behind its bounds
		local n = -pr[3].Unit
		local cf0 = mountCF(Vector3.new(r.Position.X, from.Y, r.Position.Z), n)
		local prot = protrusion(pr[1], cf0)
		local m = place(pr[1], cf0 * CFrame.new(0, 0, -prot), PF)
		say("prop", pr[1], f3(m:GetPivot().Position), pr[4], "standoff", string.format("%.2f", prot), "clearance", clearance(m, pr[1], 0.1))
	end
end

---------------------------------------------------------------- 7. Training: bins + crates 1:1
local function placeTraining()
	local T = LM.Training
	local SB = T:FindFirstChild("Extras") and T.Extras:FindFirstChild("SwapBins")
	local nb = 0
	for _, bin in (SB and SB:GetChildren() or {}) do
		local body = bin:IsA("Model") and bin:FindFirstChild("Body")
		if not body then continue end
		local pivotBefore = bin:GetPivot()
		local k = place("F_SwapBin", body.CFrame * CFrame.new(0, -1.25, 0), workspace, nil, "KitBin")
		local kb = mesh(k, "crate_green")
		for _, p in k:GetChildren() do p.Parent = bin; mark(p) end
		k:Destroy()
		kb.PivotOffset = CFrame.new()          -- pivot = body centre, as the old Body
		local att = body:FindFirstChild("PromptAt")
		if att then local lc = att.CFrame; move(att, kb); att.CFrame = lc end
		bin.PrimaryPart = kb
		for _, n in {"Body", "Lid", "Stripe"} do local p = bin:FindFirstChild(n); if p and not p:GetAttribute("FK_New") then remove(p) end end
		local d = (bin:GetPivot().Position - pivotBefore.Position).Magnitude
		nb += 1
		if d > 1e-3 then say("bin pivot moved", d) end
	end
	say("bins ->", nb, "F_SwapBin (Model, TrainingBin attr, BinPrompt kept; PrimaryPart = kit body, pivot unchanged)")
	-- crates
	local R2 = T:FindFirstChild("Range2")
	local crates, straps = {}, {}
	for _, d in (R2 and R2:GetDescendants() or {}) do
		if d:IsA("BasePart") and not d:GetAttribute("FK_New") then
			if d.Name == "Crate" then table.insert(crates, d) elseif d.Name == "CrateStrap" then table.insert(straps, d) end
		end
	end
	table.sort(crates, function(a, b) return a.Position.X * 1000 + a.Position.Z < b.Position.X * 1000 + b.Position.Z end)
	local VAR = {"A", "B", "C"}
	local n4, n5, nStrap = 0, 0, 0
	for i, c in crates do
		local s = math.floor(c.Size.Y + 0.5)
		local piece = "F_Crate" .. s .. VAR[(i - 1) % 3 + 1]
		if not KIT:FindFirstChild(piece) then say("no crate piece for size", s, c:GetFullName()); continue end
		local yaw = (Random.new(i * 7919):NextInteger(0, 3)) * 90
		local m = place(piece, c.CFrame * CFrame.new(0, -s / 2, 0) * CFrame.Angles(0, math.rad(yaw), 0), c.Parent, nil, "KitCrate")
		local body = mesh(m, "crate_green")
		local err = (body.Size - c.Size).Magnitude + (body.Position - c.Position).Magnitude
		if err > 0.01 then say("crate body mismatch", c:GetFullName(), err) end
		hide(c)
		for _, st in straps do
			if math.abs(st.Position.X - c.Position.X) < 0.05 and math.abs(st.Position.Z - c.Position.Z) < 0.05 then hide(st); nStrap += 1 end
		end
		if s == 4 then n4 += 1 else n5 += 1 end
	end
	say("crates ->", n4, "x 4-stud +", n5, "x 5-stud kit crates (A/B/C rotated, random 90 yaw); old parts hidden", #crates, "straps", nStrap)
end

---------------------------------------------------------------- run
undoAll()
if UNDO then
	undoTemplates()
	say("UNDO done")
	return table.concat(log, "\n")
end
KIT = buildTemplates()
refreshFilter()
local Fe = LM:FindFirstChild("Features")
assert(Fe, "LobbyMap.Features missing: run fix/install_features.lua first")
local steps = {{"screens", placeScreens}, {"reward stand", placeStand}, {"pits", placePits}, {"fixtures", placeFixtures},
	{"props", placeProps}, {"training", placeTraining}}
for _, st in steps do
	local ok, err = pcall(st[2], Fe)
	if not ok then say("ERROR in", st[1], err) end
	task.wait()
end
return table.concat(log, "\n")
