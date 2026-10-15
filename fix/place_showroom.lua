--[[ fix/place_showroom.lua : place the rooms4 kit (Showroom = Kit-menu camera set, y ~400) in Tacticals_rebuild.rbxl
(LOCAL copy only; never the live place). Runs after place_hub1 / hub2 / place_rooms2 / place_rooms3.
Idempotent: run as often as you like. UNDO = true puts everything back (kit returns to Workspace.rooms4 with its imported look
and positions, old U_Showroom__* meshes and the old ARMORY sign un-hidden, K_Scale4/K_Marker4 back in rooms4, sign plate removed).
Runner: python tools/run_luau.py fix/place_showroom.lua [UNDO]
Data: kit/rooms4_manifest.json, notes/rooms4_kit.md (keep / hide table). Keeps DisplayPoint, CameraPoint, BenchTop, KeyLight and
Lights.* exactly (never written). Own assets only (TacHub1 variants).
]]
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local SR = LM:WaitForChild("Showroom")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function f3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
local M, F = Enum.Material, Enum.NormalId

---------------------------------------------------------------- slot table (= kit/rooms4_manifest.json; olive tuned as rooms3_place)
local OLIVE_BAND = rgb(111, 114, 57)   -- manifest 120,136,66 (lime under Future)
local OLIVE_NEON = rgb(66, 72, 36)     -- manifest 88,101,48
local SLOT = {
	floor_field   = {rgb(76, 62, 50), M.Concrete, "TacFloorConcrete"},
	floor_border  = {rgb(46, 38, 30), M.Concrete, "TacFloorConcrete"},
	plate_metal   = {rgb(108, 107, 104), M.Metal, "TacFloorPlate"},
	wall_body     = {rgb(107, 106, 102), M.Concrete, "TacConcretePanels"},
	wall_plate    = {rgb(102, 101, 97), M.Concrete, "TacConcretePanels"},
	wall_light    = {rgb(120, 119, 115), M.Concrete, "TacConcrete"},
	wall_kick     = {rgb(88, 87, 83), M.Concrete, "TacConcrete"},
	wall_dark     = {rgb(79, 78, 74), M.Concrete, "TacConcrete"},
	wall_upper    = {rgb(141, 140, 134), M.Concrete, "TacRibbed"},
	ceiling       = {rgb(112, 111, 107), M.Concrete, "TacConcrete"},
	ceiling_gloss = {rgb(66, 68, 62), M.SmoothPlastic, ""},
	band_olive    = {OLIVE_BAND, M.Concrete, "TacConcrete"},
	trim_metal    = {rgb(108, 107, 104), M.Metal, "TacMetal"},
	trim_light    = {rgb(124, 123, 119), M.Metal, "TacMetal"},
	beam_metal    = {rgb(67, 67, 65), M.Metal, "TacMetal"},
	dark_metal    = {rgb(48, 48, 46), M.Metal, "TacMetal"},
	neon_lamp     = {rgb(161, 157, 145), M.Neon, ""},
	neon_cream    = {rgb(180, 177, 166), M.Neon, ""},
	neon_olive    = {OLIVE_NEON, M.Neon, ""},
	label_cream   = {rgb(236, 232, 218), M.SmoothPlastic, ""},
	sign_board    = {rgb(39, 40, 37), M.SmoothPlastic, ""},
	crate_green   = {rgb(65, 94, 56), M.SmoothPlastic, ""},
	case_dark     = {rgb(48, 49, 46), M.SmoothPlastic, ""},
	drum_olive    = {rgb(70, 82, 52), M.Metal, ""},
	bench_top     = {rgb(150, 147, 140), M.SmoothPlastic, ""},   -- flat, no texture: the Kit menu's fake item shadow lies on it
}
local GRIME = "rbxassetid://110762390496312"
-- SR_Stage pieces that make the table (moved together if BenchTop's top differs); the dais disc + halo stay on the floor
local TABLE = {SR_Stage__bench_top = true, SR_Stage__trim_metal = true, SR_Stage__neon_cream = true, SR_Stage__wall_kick = true,
	SR_Stage__band_olive = true, SR_Stage__dark_metal = true}
local SIGN_TEXT = "ARMORY"

---------------------------------------------------------------- hide helpers (own attribute set Rooms4_*)
local function hideOne(inst)
	if inst:GetAttribute("Rooms4Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst:SetAttribute("Rooms4_T", inst.Transparency); inst:SetAttribute("Rooms4_C", inst.CanCollide)
		inst:SetAttribute("Rooms4_Q", inst.CanQuery); inst:SetAttribute("Rooms4_Tc", inst.CanTouch)
		inst.Transparency = 1; inst.CanCollide = false; inst.CanQuery = false; inst.CanTouch = false
	elseif inst:IsA("Decal") then
		inst:SetAttribute("Rooms4_T", inst.Transparency); inst.Transparency = 1
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst:SetAttribute("Rooms4_E", inst.Enabled); inst.Enabled = false
	else
		return 0
	end
	inst:SetAttribute("Rooms4Hidden", true)
	return 1
end
local function unhideOne(inst)
	if not inst:GetAttribute("Rooms4Hidden") then return 0 end
	if inst:IsA("BasePart") then
		inst.Transparency = inst:GetAttribute("Rooms4_T"); inst.CanCollide = inst:GetAttribute("Rooms4_C")
		inst.CanQuery = inst:GetAttribute("Rooms4_Q"); inst.CanTouch = inst:GetAttribute("Rooms4_Tc")
	elseif inst:IsA("Decal") then
		inst.Transparency = inst:GetAttribute("Rooms4_T")
	else
		inst.Enabled = inst:GetAttribute("Rooms4_E")
	end
	for _, a in {"Rooms4Hidden", "Rooms4_T", "Rooms4_C", "Rooms4_Q", "Rooms4_Tc", "Rooms4_E"} do inst:SetAttribute(a, nil) end
	return 1
end
local function hideTree(root) local n = hideOne(root); for _, d in root:GetDescendants() do n += hideOne(d) end; return n end

-- the hook parts must never be written: record them before and compare after
local HOOKS = {"DisplayPoint", "CameraPoint", "BenchTop", "KeyLight"}
local function hookState()
	local t = {}
	for _, n in HOOKS do local p = SR:FindFirstChild(n); t[n] = p and (tostring(p.CFrame) .. tostring(p.Size)) or "missing" end
	for _, p in (SR:FindFirstChild("Lights") and SR.Lights:GetChildren() or {}) do t["L_" .. p.Name] = tostring(p.CFrame) .. tostring(p.Size) end
	return t
end
local hooks0 = hookState()

---------------------------------------------------------------- UNDO
local R4 = SR:FindFirstChild("Rooms4")
local rem = SS:FindFirstChild("_RebuildRemoved")
if UNDO then
	local n = 0
	for _, d in SR:GetDescendants() do if d:GetAttribute("Rooms4Hidden") then n += unhideOne(d) end end
	say("unhidden", n)
	local src = workspace:FindFirstChild("rooms4") or Instance.new("Model"); src.Name = "rooms4"; src.Parent = workspace
	if R4 then
		for _, d in R4:GetDescendants() do
			if d:IsA("MeshPart") and d:GetAttribute("Rooms4_Orig") then
				local c, mat, mv, col, qry, tch, cs, tr = table.unpack(string.split(d:GetAttribute("Rooms4_Orig"), "|"))
				d.Color = Color3.fromHex(c); d.Material = Enum.Material[mat]; d.MaterialVariant = mv
				d.CanCollide = col == "true"; d.CanQuery = qry == "true"; d.CanTouch = tch == "true"; d.CastShadow = cs == "true"
				d.Transparency = tonumber(tr)
				if d:GetAttribute("Rooms4_OrigCF") then d.CFrame = d:GetAttribute("Rooms4_OrigCF") end
				for _, a in {"Rooms4_Orig", "Rooms4_OrigCF", "NotCover"} do d:SetAttribute(a, nil) end
				for _, t in d:GetChildren() do if t:IsA("Texture") and t.Name:match("^R4_") then t:Destroy() end end
				d.Parent = src
			end
		end
		R4:Destroy(); say("kit back in Workspace.rooms4")
	end
	if rem then for _, c in rem:GetChildren() do if c.Name == "K_Scale4" or c.Name == "K_Marker4" then c.Parent = src end end end
	say("UNDO done")
	return table.concat(log, "\n")
end

---------------------------------------------------------------- 1. kit into LobbyMap.Showroom.Rooms4 (one Model per piece); markers out
local function ensure(parent, name, class)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new(class or "Folder"); f.Name = name; f.Parent = parent end
	return f
end
rem = ensure(SS, "_RebuildRemoved")
R4 = ensure(SR, "Rooms4", "Model")
local src = workspace:FindFirstChild("rooms4")
if src then
	for _, c in src:GetChildren() do
		if c.Name == "K_Scale4" or c.Name == "K_Marker4" then
			say(c.Name, "at", f3(c.Position), "size", f3(c.Size), "-> ServerStorage._RebuildRemoved")
			c.Parent = rem
		elseif c:IsA("MeshPart") then
			c.Parent = ensure(R4, c.Name:match("^(.-)__") or "Misc", "Model")
		end
	end
	if #src:GetChildren() == 0 then src:Destroy() end
end
say("Rooms4 pieces", #R4:GetChildren(), "markers in _RebuildRemoved:", rem:FindFirstChild("K_Scale4") ~= nil, rem:FindFirstChild("K_Marker4") ~= nil)

---------------------------------------------------------------- 2. per-mesh look; no collision / query / touch (only seen through the Kit camera)
local nMesh = 0
for _, part in R4:GetDescendants() do
	if not part:IsA("MeshPart") then continue end
	local piece, slot = part.Name:match("^(.-)__(.+)$")
	local s = SLOT[slot]
	if not s then say("no slot for", part.Name); continue end
	if part:GetAttribute("Rooms4_Orig") == nil then
		part:SetAttribute("Rooms4_Orig", table.concat({part.Color:ToHex(), part.Material.Name, part.MaterialVariant, tostring(part.CanCollide),
			tostring(part.CanQuery), tostring(part.CanTouch), tostring(part.CastShadow), tostring(part.Transparency)}, "|"))
	end
	part.Anchored = true
	part.Color = s[1]; part.Material = s[2]; part.MaterialVariant = s[3]
	part.Transparency = 0; part.Reflectance = 0
	part.CastShadow = s[2] ~= M.Neon
	part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
	part:SetAttribute("NotCover", true)
	if piece == "SR_Props" and (slot == "crate_green" or slot == "case_dark" or slot == "drum_olive") then
		for _, f in {F.Front, F.Back, F.Left, F.Right} do
			local nm = "R4_grime_" .. f.Name
			local t = part:FindFirstChild(nm) or Instance.new("Texture")
			t.Name = nm; t.Texture = GRIME; t.Face = f; t.StudsPerTileU = 4; t.StudsPerTileV = 4
			t.Color3 = Color3.new(0, 0, 0); t.Transparency = 0.94; t.Parent = part
		end
	end
	nMesh += 1
end
say("meshes styled", nMesh, "(CanCollide/CanQuery/CanTouch false, NotCover)")

---------------------------------------------------------------- 3. BenchTop check: kit table top must equal BenchTop's top (Armory.UpdateShadow tableTopY)
local bench = SR:FindFirstChild("BenchTop")
local top = R4:FindFirstChild("SR_Stage__bench_top", true)
if bench and top then
	local want = bench.Position.Y + bench.Size.Y / 2
	local o = top:GetAttribute("Rooms4_OrigCF") or top.CFrame
	local have = o.Position.Y + top.Size.Y / 2
	local dy = want - have
	say(("BenchTop top %.3f (centre %s size %s); kit bench_top top as imported %.3f; dy %.3f"):format(want, f3(bench.Position), f3(bench.Size), have, dy))
	-- footprint check (x -8..8, z 5..12)
	say(("bench_top footprint x %.2f..%.2f z %.2f..%.2f; BenchTop x %.2f..%.2f z %.2f..%.2f"):format(o.X - top.Size.X / 2, o.X + top.Size.X / 2,
		o.Z - top.Size.Z / 2, o.Z + top.Size.Z / 2, bench.Position.X - bench.Size.X / 2, bench.Position.X + bench.Size.X / 2,
		bench.Position.Z - bench.Size.Z / 2, bench.Position.Z + bench.Size.Z / 2))
	for name in TABLE do
		local p = R4:FindFirstChild(name, true)
		if p then
			if p:GetAttribute("Rooms4_OrigCF") == nil then p:SetAttribute("Rooms4_OrigCF", p.CFrame) end
			p.CFrame = p:GetAttribute("Rooms4_OrigCF") + Vector3.new(0, math.abs(dy) > 0.05 and dy or 0, 0)
		end
	end
	say(("table pieces now: bench_top top %.3f"):format(top.Position.Y + top.Size.Y / 2))
else
	say("WARN BenchTop or SR_Stage__bench_top missing")
end

---------------------------------------------------------------- 4. hide the old Showroom meshes + old ARMORY sign (restorable)
local hidden = 0
for _, c in SR:GetChildren() do
	if c.Name:match("^U_Showroom__") then hidden += hideTree(c) end
end
local oldSign = SR:FindFirstChild("Sign")
if oldSign then hidden += hideTree(oldSign) end
say("hidden this run", hidden)

---------------------------------------------------------------- 5. sign text: solid backing plate 0.08 proud of the measured board face (faces -z, the camera)
do
	local board = R4:FindFirstChild("SR_Signs__sign_board", true)
	local frame = R4:FindFirstChild("SR_Signs__neon_olive", true)
	if board then
		local ex = {}
		local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
		local inc = {board}; if frame then table.insert(inc, frame) end
		local q = {}; for _, p in inc do q[p] = p.CanQuery; p.CanQuery = true end
		rp.FilterDescendantsInstances = {board}
		local cy, w, h = board.Position.Y, board.Size.X - 1.6, board.Size.Y - 0.8
		local best
		for _, o in {Vector2.new(0, 0), Vector2.new(w * 0.4, 0), Vector2.new(-w * 0.4, 0), Vector2.new(0, h * 0.35), Vector2.new(0, -h * 0.35)} do
			local r = workspace:Raycast(Vector3.new(board.Position.X + o.X, cy + o.Y, board.Position.Z - 8), Vector3.new(0, 0, 12), rp)
			if r then best = best and math.min(best, r.Position.Z) or r.Position.Z end
		end
		-- the Neon frame stands proud of the board: the plate must not poke out in front of it
		local frameFront
		if frame then
			rp.FilterDescendantsInstances = {frame}
			for _, o in {Vector2.new(board.Size.X / 2 - 0.2, 0), Vector2.new(0, board.Size.Y / 2 - 0.15)} do
				local r = workspace:Raycast(Vector3.new(board.Position.X + o.X, cy + o.Y, board.Position.Z - 8), Vector3.new(0, 0, 12), rp)
				if r then frameFront = frameFront and math.min(frameFront, r.Position.Z) or r.Position.Z end
			end
		end
		for p, v in q do p.CanQuery = v end
		if best then
			local th = 0.1
			local pos = Vector3.new(board.Position.X, cy, best - 0.08 - th / 2)
			local p = R4:FindFirstChild("SignText_Showroom") or Instance.new("Part")
			p.Name = "SignText_Showroom"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
			p.Size = Vector3.new(w, h, th); p.CFrame = CFrame.lookAt(pos, pos - Vector3.zAxis)
			p.Material = M.SmoothPlastic; p.Color = rgb(39, 40, 37); p.Transparency = 0
			p:SetAttribute("NotCover", true); p.Parent = R4
			local g = p:FindFirstChild("Text") or Instance.new("SurfaceGui")
			g.Name = "Text"; g.Face = F.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
			g.LightInfluence = 0; g.Brightness = 1.2; g.MaxDistance = 0; g.Parent = p
			local l = g:FindFirstChild("Label") or Instance.new("TextLabel")
			l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.8); l.Position = UDim2.fromScale(0, 0.1)
			l.Text = SIGN_TEXT; l.TextScaled = true; l.TextColor3 = rgb(236, 232, 218)
			l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy); l.Parent = g
			say(("SignText_Showroom %s board face z %.3f plate front z %.3f frame front z %s size %.1f x %.1f"):format(SIGN_TEXT, best,
				pos.Z - th / 2, frameFront and ("%.3f"):format(frameFront) or "-", w, h))
		else
			say("WARN sign board face not found")
		end
	else
		say("WARN no SR_Signs__sign_board")
	end
end

---------------------------------------------------------------- 6. hooks untouched?
local hooks1 = hookState()
local same = true
for k, v in hooks0 do if hooks1[k] ~= v then same = false; say("WARN hook changed", k) end end
say("hook parts unchanged:", same, "| RoomLight Showroom:", (function() local n = 0 for _, p in CS:GetTagged("RoomLight") do if p:GetAttribute("Room") == "Showroom" then n += 1 end end return n end)())
-- nothing between CameraPoint and DisplayPoint (all kit parts, CanQuery forced on for the test)
do
	local cam, dp = SR.CameraPoint.Position, SR.DisplayPoint.Position
	local parts = {}
	for _, d in R4:GetDescendants() do if d:IsA("BasePart") then parts[d] = d.CanQuery; d.CanQuery = true end end
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = {R4}
	local r = workspace:Raycast(cam, dp - cam, rp)
	for d, v in parts do d.CanQuery = v end
	say("camera -> display point line:", r and ("BLOCKED by " .. r.Instance.Name .. " at " .. f3(r.Position)) or "clear")
end
return table.concat(log, "\n")
