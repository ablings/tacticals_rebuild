--[[ fix/lap_fix.lua : small, safe fixes from the Play-mode lap (notes/lap1.md, 2026-10-15).
Tacticals_rebuild.rbxl (LOCAL copy) only. Runs after place_hub1, hub2, place_rooms2, place_rooms3, place_showroom, place_training,
overlap_fix. Idempotent: new parts live in LobbyMap.Hub1.LapFix (rebuilt each run); moved instances keep their original CFrame /
Size / Parent in Lap_* attributes and every run recomputes from those. UNDO = true puts everything back.
Runner: python tools/run_luau.py fix/lap_fix.lua [UNDO]
Mesh nudges on kit meshes (Duels door soffit, Duels lines, Showroom stage) are in fix/overlap_fix.lua (they share its originals).

 L1  hub N / S walls above the gates (x -5.7..5.7, y 52..68) and E wall above the tunnel (z -11..11): the kit's bay infill
     stops at y 52 (tools/hub_kit.py build_long_wall / build_east), so sky + the TimesSquare towers showed through.
     Infill Parts copy the neighbouring zones' cornice / top fill (and the missing trim_light lip at 35.8).
 L2  tunnel -> hangar threshold x 104..105: Hub1's tunnel floor stops at 104 and Rooms3's hangar floor starts at 105, leaving a
     1-stud-deep trench across the whole tunnel (one through-hole at z -7.25). Floor plate added (walkable, collides).
 L3  SignText_Deck sat on the plane of D_Signs__label_cream (x -138.920): z-fight, cream plate flashing through "DECK". +0.04 x.
 L4  SignText_SHOP / SignText_ARMORY were placed at the OLD signs' x -3.75 / 8.5 wide (place_hub1 hard-coded), the new kit board
     is x -8..8: text off-centre. Re-centred at x 0, 14.5 wide (place_hub1.lua data corrected too).
 L5  NPC_DuelsOfficer's right arm went through the stair rail (H_Stairs__trim_light): moved 0.8 toward the door axis (-z).
 L6  Workspace._UVTest x3 (grid-offset test cubes from the Training step-2 session) floating in Training: moved to
     ServerStorage._RebuildRemoved.
]]
local UNDO = false --@UNDO
local LM = workspace:WaitForChild("LobbyMap")
local SS = game:GetService("ServerStorage")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local Hub1 = LM.Hub1

local function find(root, name) for _, d in root:GetDescendants() do if d.Name == name then return d end end end
local function keepCF(p) if p:GetAttribute("Lap_OrigCF") == nil then p:SetAttribute("Lap_OrigCF", p:IsA("Model") and p:GetPivot() or p.CFrame) end; return p:GetAttribute("Lap_OrigCF") end
local function keepSize(p) if p:GetAttribute("Lap_OrigSize") == nil then p:SetAttribute("Lap_OrigSize", p.Size) end; return p:GetAttribute("Lap_OrigSize") end

---------------------------------------------------------------- UNDO
if UNDO then
	local f = Hub1:FindFirstChild("LapFix"); if f then f:Destroy(); say("LapFix folder removed") end
	local n = 0
	for _, d in LM:GetDescendants() do
		if d:GetAttribute("Lap_OrigCF") ~= nil then
			if d:IsA("Model") then d:PivotTo(d:GetAttribute("Lap_OrigCF")) else d.CFrame = d:GetAttribute("Lap_OrigCF") end
			if d:GetAttribute("Lap_OrigSize") then d.Size = d:GetAttribute("Lap_OrigSize") end
			d:SetAttribute("Lap_OrigCF", nil); d:SetAttribute("Lap_OrigSize", nil); n += 1
		end
	end
	local rr = SS:FindFirstChild("_RebuildRemoved")
	if rr then for _, d in rr:GetChildren() do if d:GetAttribute("Lap_OrigParent") == "Workspace" then d.Parent = workspace; d:SetAttribute("Lap_OrigParent", nil); n += 1 end end end
	say("UNDO: restored", n)
	return table.concat(log, "\n")
end

---------------------------------------------------------------- L1 wall infill
local old = Hub1:FindFirstChild("LapFix"); if old then old:Destroy() end
local F = Instance.new("Folder"); F.Name = "LapFix"
local function look(meshName)
	local m = find(Hub1, meshName); assert(m, "missing " .. meshName)
	return m.Color, m.Material, m.MaterialVariant
end
local function mk(class, name, size, cf, src, parent)
	local p = Instance.new(class); p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf
	p.Color, p.Material, p.MaterialVariant = look(src)
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("LapNew", true); p:SetAttribute("NotCover", true)
	p.Parent = parent; return p
end
-- wall frame as in tools/hub_kit.py: along x (N/S) or z (E); face = inner wall face; inw = direction into the room
local WALLS = {
	{tag = "N", along = "x", face = 44.0, inw = -1, s0 = -5.7, s1 = 5.7},
	{tag = "S", along = "x", face = -44.0, inw = 1, s0 = -5.7, s1 = 5.7},
	{tag = "E", along = "z", face = 88.0, inw = -1, s0 = -11.0, s1 = 11.0},
}
local nNew = 0
for _, W in WALLS do
	local function P(s, y, d) local n = W.face + W.inw * d; if W.along == "x" then return Vector3.new(s, y, n) else return Vector3.new(n, y, s) end end
	local alongV = W.along == "x" and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local outV = W.along == "x" and Vector3.new(0, 0, -W.inw) or Vector3.new(-W.inw, 0, 0)   -- room -> wall
	local L = W.s1 - W.s0; local sm = (W.s0 + W.s1) / 2
	local src = "H_Wall" .. W.tag .. "__"
	-- axis-aligned box from (s0..s1, y0..y1, d0..d1)
	local function box(name, mesh, y0, y1, d0, d1)
		local c = P(sm, (y0 + y1) / 2, (d0 + d1) / 2)
		local sz = W.along == "x" and Vector3.new(L, y1 - y0, d1 - d0) or Vector3.new(d1 - d0, y1 - y0, L)
		mk("Part", W.tag .. "_" .. name, sz, CFrame.new(c), src .. mesh, F); nNew += 1
	end
	box("CorniceBack", "wall_light", 52.0, 58.4, -5.0, 0.0)
	box("CorniceTop", "wall_light", 57.6, 58.4, 0.0, 3.6)
	-- chamfer (0,52) -> (3.6,57.6): upside-down wedge, flat top at 57.6, tall face against the wall
	local up = Vector3.new(0, -1, 0); local zAx = outV; local xAx = up:Cross(zAx)
	local wc = P(sm, 54.8, 1.8)
	local w = mk("WedgePart", W.tag .. "_CorniceChamfer", Vector3.new(L, 5.6, 3.6), CFrame.fromMatrix(wc, xAx, up, zAx), src .. "wall_light", F); nNew += 1
	box("TopTrim", "trim_metal", 58.4, 59.0, -5.0, 3.9)
	box("TopFill", "wall_dark", 59.0, 68.0, -5.0, 3.4)
	box("LipTrim", "trim_light", 35.8, 36.3, -5.0, 0.45)
	local _ = alongV; _ = w
end
say("L1 wall infill parts", nNew)

---------------------------------------------------------------- L2 tunnel / hangar threshold
do
	local c, m, v = look("H_Tunnel__floor_border")
	local p = Instance.new("Part"); p.Name = "TunnelThreshold"; p.Anchored = true
	p.Size = Vector3.new(1.0, 1.02, 27.0); p.CFrame = CFrame.new(104.5, -0.49, 0)   -- x 104..105, y -1.0..0.02, z -13.5..13.5
	p.Color, p.Material, p.MaterialVariant = c, m, v
	p.CanCollide = true; p.CanQuery = true; p.CanTouch = true; p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("LapNew", true); p.Parent = F
	say("L2 threshold plate x 104..105 top 0.02")
end
F.Parent = Hub1

---------------------------------------------------------------- L3 / L4 sign overlays
local deck = find(LM.Rooms3, "SignText_Deck")
if deck then
	local cf0 = keepCF(deck)
	deck.CFrame = cf0 + Vector3.new(0.04, 0, 0)
	say("L3 SignText_Deck x", string.format("%.3f -> %.3f", cf0.X, deck.Position.X))
end
local ov = Hub1:FindFirstChild("Overlays")
for _, n in {"SignText_SHOP", "SignText_ARMORY"} do
	local s = ov and ov:FindFirstChild(n)
	if s then
		local cf0 = keepCF(s); local s0 = keepSize(s)
		s.Size = Vector3.new(14.5, s0.Y, s0.Z)
		s.CFrame = cf0.Rotation + Vector3.new(0, cf0.Y, cf0.Z)
		say("L4", n, string.format("x %.2f w %.2f -> x %.2f w %.2f", cf0.X, s0.X, s.Position.X, s.Size.X))
	end
end

---------------------------------------------------------------- L5 Duels officer
local npc = LM.NPCs:FindFirstChild("NPC_DuelsOfficer")
if npc then
	local cf0 = keepCF(npc)
	npc:PivotTo(cf0 + Vector3.new(0, 0, -0.8))
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = {npc}
	local hits = {}
	-- the stair / landing meshes are CanQuery off: make them queryable for the check only, then restore
	local tmp = {}
	for _, d in Hub1:GetDescendants() do if d:IsA("BasePart") and not d.CanQuery and (d.Position - npc:GetPivot().Position).Magnitude < 60 then tmp[d] = true; d.CanQuery = true end end
	for _, p in npc:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			for _, h in workspace:GetPartsInPart(p, op) do if h.Transparency < 1 then hits[p.Name .. " x " .. h.Name] = true end end
		end
	end
	for d in tmp do d.CanQuery = false end
	local l = {} for k in hits do table.insert(l, k) end
	say("L5 NPC_DuelsOfficer z", string.format("%.2f -> %.2f", cf0.Z, npc:GetPivot().Z), "intersections (collision geometry):", #l > 0 and table.concat(l, "; ") or "none")
end

---------------------------------------------------------------- L6 stray test cubes
local rr = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder", SS); rr.Name = "_RebuildRemoved"
local nUV = 0
for _, d in workspace:GetChildren() do
	if d.Name == "_UVTest" then d:SetAttribute("Lap_OrigParent", "Workspace"); d.Parent = rr; nUV += 1 end
end
say("L6 _UVTest moved to ServerStorage._RebuildRemoved:", nUV)
return table.concat(log, "\n")
