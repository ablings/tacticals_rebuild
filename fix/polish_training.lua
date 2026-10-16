-- polish_training.lua : Training TOUCH-UP (overnight polish). Tacticals_rebuild.rbxl ONLY. Run after place_training.lua,
-- place_features_kit.lua and polish_olive.lua.
-- Identity (Edward): Edward set the standard himself: the Tacticals grid-tile range, rebuilt Parts-first. A clinical, cool,
-- even-lit range. This pass changes NO gameplay: dummies, EnemySpots, Arrivals, bins, jump pads, tightropes, cover and lines
-- stay where they are. It only adds wayfinding by quadrant and tunes the grid read.
-- Quadrants (arena x/z -128..128 round the plaza; gallery east of x 128):
--   A = NW (x<0, z>0, the block maze)        olive      138,156,74
--   B = NE (x>0, z>0, towers + overwatch)    cream      236,232,218
--   C = SE (x>0, z<0, the distance field)    sage       167,173,152
--   D = SW (x<0, z<0, the cover course)      warm grey  150,146,136 (the darker warm grey: 200,196,186 vanishes on the 206 walls)
--   gallery (x>128): near-black band = the firing range, not a quadrant
-- 1. Wall bands: the olive perimeter band (rendered lime, 87,114,69 G/R 1.31) is split per quadrant and painted in the
--    quadrant colour, with near-black edge strips so cream / sage / warm grey still read on the near-white walls.
--    The old bands ran on through the four 24 x 24 corner bastions; every old arena band is hidden and rebuilt per quadrant
--    between the bastions (|x|, |z| <= 104; the east halves from the gallery mouth at 36 to 104).
-- 2. Big quadrant letters: a near-black plate (16 x 18) per quadrant wall (8), letter in the quadrant colour, SECTOR + zone name,
--    at y 631 (622..640, above the band, readable from the floor and the +24 roof decks). Positions from a ray scan: the whole
--    plate is visible from the plaza corner of that quadrant (B's east wall from the boulevard, y 636).
-- 3. Floor markings: 12 x 12 quadrant-colour plates with a near-black border and letter, two at each plaza exit (one each side
--    of the boulevard: the quadrant on that side), reading upright when you walk out of the plaza. The diagonals are full of cover.
-- 4. Swap bins: a near-black floor frame with a cream edge round each bin and a WEAPON SWAP stencil, so the 9 bins no longer
--    read as 24 more cover crates (same Blender crate kit, same olive paint).
-- 5. Grid: the tile line texture (TX_overlay_grid, two copies 0.06 apart) darker (58 -> 34) and stronger (T 0.45 -> 0.32):
--    measured in Play, the line contrast on the near floor was only ~10 levels (161 vs 171) and ~34 on the walls.
-- Lights: none added or changed. Nothing new collides, is queryable or touchable; everything new carries NotCover.
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishTraining_Orig; new parts in
-- Workspace.LobbyMap.Polish.Training. Comments on their own line. UNDO: python tools/run_luau.py fix/polish_training.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local T = LM.Training
local R = T.Range2
local ATTR = "PolishTraining_Orig"
local C = Color3.fromRGB
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "UDim2" then return {t = "u", v = {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}}
	elseif t == "CFrame" then return {t = "cf", v = {v:GetComponents()}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "u" then return UDim2.new(o.v[1], o.v[2], o.v[3], o.v[4])
	elseif o.t == "cf" then return CFrame.new(table.unpack(o.v))
	else return o.v end
end
local function setP(inst, props)
	if not inst then return end
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
end
local function hide(p)
	setP(p, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
end

local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if polish and polish:FindFirstChild("Training") then polish.Training:Destroy() end
	return "UNDO polish_training: restored " .. n .. " instances, removed Polish.Training"
end
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Training") then polish.Training:Destroy() end
local root = Instance.new("Folder"); root.Name = "Training"
root:SetAttribute("PolishPass", "polish_training.lua")

local NEAR_BLACK = C(10, 12, 10)
local CREAM = C(236, 232, 218)
local QUAD = {
	A = {col = C(138, 156, 74), ink = NEAR_BLACK, sx = -1, sz = 1, zone = "MAZE"},
	B = {col = C(236, 232, 218), ink = NEAR_BLACK, sx = 1, sz = 1, zone = "TOWERS"},
	C = {col = C(167, 173, 152), ink = NEAR_BLACK, sx = 1, sz = -1, zone = "FIELD"},
	D = {col = C(150, 146, 136), text = C(200, 196, 186), ink = NEAR_BLACK, sx = -1, sz = -1, zone = "COVER"},
}
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local function part(parent, name, size, cf, color, mat)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic; p.Anchored = true
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true); p.Parent = parent
	return p
end
local function label(parent, text, pos, size, color, align)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Position = pos; l.Size = size; l.Text = text
	l.TextScaled = true; l.FontFace = FONT; l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center; l.Parent = parent
	return l
end
local function frame(parent, pos, size, color)
	local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.Position = pos; f.Size = size; f.BackgroundColor3 = color; f.Parent = parent
	return f
end
local function gui(p, face, pps)
	local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 20; g.LightInfluence = 0.35; g.Brightness = 1.2; g.Parent = p
	return g
end
local U = UDim2.fromScale

---------------------------------------------------------------------------------------------------
-- 1. wall bands per quadrant
---------------------------------------------------------------------------------------------------
local bandF = Instance.new("Folder"); bandF.Name = "Bands"; bandF.Parent = root
local nBand, nHid = 0, 0
local function bandSeg(name, q, cf, len, alongX)
	-- cf: band centre; the band is 3 tall, 0.4 thick like the original
	local col = QUAD[q] and QUAD[q].col or NEAR_BLACK
	local sz = alongX and Vector3.new(len, 3, 0.4) or Vector3.new(0.4, 3, len)
	local b = part(bandF, "Band_" .. name, sz, cf, col)
	-- near-black edge strips (0.3 tall) 0.06 proud of the band face
	-- inward normal (away from the wall the band is on)
	local n = alongX and Vector3.new(0, 0, -math.sign(cf.Z)) or Vector3.new(-math.sign(cf.X), 0, 0)
	for _, dy in ipairs({1.35, -1.35}) do
		local es = alongX and Vector3.new(len, 0.3, 0.52) or Vector3.new(0.52, 0.3, len)
		part(bandF, "BandEdge_" .. name, es, cf + Vector3.new(0, dy, 0) + n * 0.06, NEAR_BLACK)
	end
	nBand += 1
	return b
end
for _, b in ipairs(R.Shell:GetChildren()) do
	if b.Name == "WallBand" then
		local p = b.Position
		if math.abs(p.Z - 127.8) < 0.5 and math.abs(p.X) < 1 then
			-- north band: A (x<0) | B (x>0)
			hide(b); nHid += 1
			bandSeg("N_A", "A", CFrame.new(-52, p.Y, p.Z), 104, true)
			bandSeg("N_B", "B", CFrame.new(52, p.Y, p.Z), 104, true)
		elseif math.abs(p.Z + 127.8) < 0.5 and math.abs(p.X) < 1 then
			-- south band: D (x<0) | C (x>0)
			hide(b); nHid += 1
			bandSeg("S_D", "D", CFrame.new(-52, p.Y, p.Z), 104, true)
			bandSeg("S_C", "C", CFrame.new(52, p.Y, p.Z), 104, true)
		elseif math.abs(p.X + 127.8) < 0.5 then
			-- west band: D (z<0) | A (z>0)
			hide(b); nHid += 1
			bandSeg("W_D", "D", CFrame.new(p.X, p.Y, -52), 104, false)
			bandSeg("W_A", "A", CFrame.new(p.X, p.Y, 52), 104, false)
		elseif math.abs(p.X - 127.8) < 0.5 then
			-- east band halves already split by the gallery mouth: recolour + edges
			local q = p.Z > 0 and "B" or "C"
			hide(b); nHid += 1
			bandSeg("E_" .. q, q, CFrame.new(p.X, p.Y, math.sign(p.Z) * 70), 68, false)
		else
			-- gallery bands: near-black range band
			setP(b, {Color = C(34, 36, 32), Material = Enum.Material.SmoothPlastic})
		end
	end
end
say(string.format("bands: %d old hidden, %d quadrant segments", nHid, nBand))
-- the bastion bands (one per corner) and the tower bands (all three towers stand in B) take their quadrant's colour, with
-- the same near-black edges (boxes 0.06 proud all round, 0.3 tall at the band's top and bottom)
local function quadOf(pos) return (pos.X < 0 and (pos.Z > 0 and "A" or "D")) or (pos.Z > 0 and "B" or "C") end
local nRing = 0
for _, f in ipairs({R.Blocks, R.Towers}) do
	for _, b in ipairs(f:GetChildren()) do
		if b.Name == "Band" and b:IsA("BasePart") then
			local qd = quadOf(b.Position)
			setP(b, {Color = QUAD[qd].col, Material = Enum.Material.SmoothPlastic})
			for _, dy in ipairs({b.Size.Y / 2 - 0.15, -b.Size.Y / 2 + 0.15}) do
				part(bandF, "BandEdge_Ring_" .. qd, Vector3.new(b.Size.X + 0.12, 0.3, b.Size.Z + 0.12), b.CFrame + Vector3.new(0, dy, 0), NEAR_BLACK)
			end
			nRing += 1
		end
	end
end
say("bastion / tower bands recoloured: " .. nRing)

-- the 4 field distance boards on the east wall (y 604.7..607.3) ran into the band (607..610) and the cream wall line
-- (606.63..606.88) since place_training: lower them 1.6 (603.1..605.7), clear of both. Signs only, no gameplay.
local nDS = 0
for _, s in ipairs(R.Signs:GetChildren()) do
	local stored = s:GetAttribute(ATTR) and HttpService:JSONDecode(s:GetAttribute(ATTR)).CFrame
	local cf0 = stored and decV(stored) or s.CFrame
	if s.Name == "DistSign" and math.abs(cf0.X - 127.9) < 0.3 and math.abs(cf0.Y - 606) < 0.2 then
		setP(s, {CFrame = cf0 - Vector3.new(0, 1.6, 0)}); nDS += 1
	end
end
say("field distance boards lowered: " .. nDS)

---------------------------------------------------------------------------------------------------
-- 2. big quadrant letters on the perimeter walls (positions from the visibility scan, see header)
---------------------------------------------------------------------------------------------------
local letF = Instance.new("Folder"); letF.Name = "Letters"; letF.Parent = root
-- {quadrant, wall plane point (plate centre), inward normal}
local PLATES = {
	{"A", Vector3.new(-16, 631, 127.9), Vector3.new(0, 0, -1)},
	{"A", Vector3.new(-127.9, 631, 24), Vector3.new(1, 0, 0)},
	{"B", Vector3.new(56, 631, 127.9), Vector3.new(0, 0, -1)},
	{"B", Vector3.new(127.9, 636, 52), Vector3.new(-1, 0, 0)},
	{"C", Vector3.new(64, 631, -127.9), Vector3.new(0, 0, 1)},
	{"C", Vector3.new(127.9, 631, -82), Vector3.new(-1, 0, 0)},
	{"D", Vector3.new(-64, 631, -127.9), Vector3.new(0, 0, 1)},
	{"D", Vector3.new(-127.9, 631, -64), Vector3.new(1, 0, 0)},
}
for i, pl in ipairs(PLATES) do
	local q, c, n = pl[1], pl[2], pl[3]
	local Q = QUAD[q]
	-- plate 0.2 thick: centre 127.88, its back 0.02 off the wall face (wall faces at |128|)
	local pos = c + n * 0.02
	local plate = part(letF, "Letter_" .. q .. "_" .. i, Vector3.new(16, 18, 0.2), CFrame.lookAt(pos, pos + n), NEAR_BLACK)
	plate:SetAttribute("Quadrant", q)
	-- 8 px per stud: TextScaled stops at 100 px, so at 20 px/stud the letter came out a third of the plate
	local g = gui(plate, Enum.NormalId.Front, 8)
	frame(g, U(0, 0), U(1, 0.07), Q.col)
	frame(g, U(0, 0.93), U(1, 0.07), Q.col)
	label(g, q, U(0.05, 0.08), U(0.9, 0.62), Q.text or Q.col)
	label(g, "SECTOR " .. q, U(0.08, 0.70), U(0.84, 0.11), CREAM)
	label(g, Q.zone, U(0.08, 0.81), U(0.84, 0.09), C(167, 173, 152))
end
say("letters: " .. #PLATES)

---------------------------------------------------------------------------------------------------
-- 3. floor plates off each plaza corner (free floor checked by a ray grid; slide outward until clear)
---------------------------------------------------------------------------------------------------
local floorF = Instance.new("Folder"); floorF.Name = "FloorMarks"; floorF.Parent = root
local skip = {}
for _, d in ipairs(T:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
table.insert(skip, root)
local tmpQ = {}
for _, d in ipairs(T:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 then d.CanQuery = true; table.insert(tmpQ, d) end
end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
local function floorFree(cx, cz, half)
	for dx = -half, half, 1 do
		for dz = -half, half, 1 do
			local h = workspace:Raycast(Vector3.new(cx + dx, 640, cz + dz), Vector3.new(0, -60, 0), rp)
			if not h or h.Instance.Name ~= "Floor" or math.abs(h.Position.Y - 600) > 0.01 then return false end
		end
	end
	return true
end
local nFloor = 0
-- two plates at each plaza exit (N, E, S, W), one each side of the boulevard, 28 out and 13 off the axis: the quadrant you
-- walk into on that side. Exit direction = LookVector, so the letters read upright walking out of the plaza.
local EXITS = {
	{Vector3.new(0, 0, 1), {{"A", -13}, {"B", 13}}},
	{Vector3.new(1, 0, 0), {{"B", 13}, {"C", -13}}},
	{Vector3.new(0, 0, -1), {{"C", 13}, {"D", -13}}},
	{Vector3.new(-1, 0, 0), {{"D", -13}, {"A", 13}}},
}
for _, ex in ipairs(EXITS) do
	local dir = ex[1]
	for _, qo in ipairs(ex[2]) do
		local q, off = qo[1], qo[2]
		local Q = QUAD[q]
		-- off is along x for N/S exits and along z for E/W exits
		local c = dir * 28 + (dir.X == 0 and Vector3.new(off, 0, 0) or Vector3.new(0, 0, off))
		if floorFree(c.X, c.Z, 6) then
			local placed = Vector3.new(c.X, 600.01, c.Z)
			-- the Top-face gui's up edge is the part's -X side: turn the plate so -X points out of the plaza
			local p = part(floorF, "Floor_" .. q, Vector3.new(12, 0.1, 12), CFrame.lookAt(placed, placed + dir) * CFrame.Angles(0, -math.pi / 2, 0), NEAR_BLACK)
			p:SetAttribute("Quadrant", q)
			local g = gui(p, Enum.NormalId.Top, 12)
			frame(g, U(0.06, 0.06), U(0.88, 0.88), Q.col)
			label(g, q, U(0.12, 0.08), U(0.76, 0.68), NEAR_BLACK)
			label(g, "SECTOR " .. q .. "  " .. Q.zone, U(0.12, 0.76), U(0.76, 0.12), NEAR_BLACK)
			nFloor += 1
		else
			say("floor plate " .. q .. " at " .. tostring(c) .. ": not free")
		end
	end
end
say("floor plates: " .. nFloor)

---------------------------------------------------------------------------------------------------
-- 4. swap bin frames + WEAPON SWAP stencil
---------------------------------------------------------------------------------------------------
local binF = Instance.new("Folder"); binF.Name = "BinMarks"; binF.Parent = root
local nBin, nSt = 0, 0
for i, bin in ipairs(T.Extras.SwapBins:GetChildren()) do
	if bin:IsA("Model") then
		local cf, sz = bin:GetBoundingBox()
		-- surface = the bottom of the crate body (bins stand on the floor or a roof); frame follows the bin's yaw
		local body = bin.PrimaryPart or bin:FindFirstChild("F_SwapBin__crate_green")
		local y = body.Position.Y - body.Size.Y / 2
		-- the plaza plate is 0.1 proud of the floor: take the highest surface round the bin (rays just outside its footprint)
		local rpB = RaycastParams.new(); rpB.FilterType = Enum.RaycastFilterType.Exclude
		rpB.FilterDescendantsInstances = {bin, root, table.unpack(skip)}
		for _, o in ipairs({Vector3.new(2.3, 0, 0), Vector3.new(-2.3, 0, 0), Vector3.new(0, 0, 2.3), Vector3.new(0, 0, -2.3)}) do
			local hh = workspace:Raycast(body.Position + o + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), rpB)
			if hh and hh.Position.Y > y and hh.Position.Y < y + 0.3 then y = hh.Position.Y end
		end
		local _, yaw = body.CFrame:ToEulerAnglesYXZ()
		local szB = bin:FindFirstChild("F_SwapBin__dark_metal") and bin.F_SwapBin__dark_metal.Size or sz
		sz = Vector3.new(szB.X, sz.Y, szB.Z)
		local half = math.max(sz.X, sz.Z) / 2 + 0.15
		local w = 0.5
		-- the two plaza bins stand 45 degrees turned 3 studs inside the plaza edge line: a slimmer frame stays inside it
		if y > 600.05 and y < 601 then half = math.max(sz.X, sz.Z) / 2 + 0.05; w = 0.25 end
		local base = CFrame.new(cf.X, y + 0.035, cf.Z) * CFrame.Angles(0, yaw, 0)
		-- four strips round the bin, near-black with a thin cream outer edge
		for k = 0, 3 do
			local rot = CFrame.Angles(0, k * math.pi / 2, 0)
			local strip = base * rot * CFrame.new(0, 0, half + w / 2)
			part(binF, "BinFrame_" .. i, Vector3.new(2 * half + 2 * w, 0.07, w), strip, NEAR_BLACK)
			part(binF, "BinEdge_" .. i, Vector3.new(2 * half + 2 * w, 0.08, 0.12), base * rot * CFrame.new(0, 0, half + w - 0.06), CREAM)
		end
		nBin += 1
		-- stencil on the side facing the plaza centre (or the arena centre for roof bins), if that floor is free
		local toC = Vector3.new(-cf.X, 0, -cf.Z)
		if toC.Magnitude < 1 then toC = Vector3.new(0, 0, 1) end
		toC = toC.Unit
		local sp = Vector3.new(cf.X, y + 0.035, cf.Z) + toC * (half + w + 1.6)
		local ok = true
		for _, a in ipairs({-2.5, 0, 2.5}) do
			for _, b in ipairs({-0.9, 0.9}) do
				local side = toC:Cross(Vector3.yAxis)
				local pt = sp + side * a + toC * b
				local hh = workspace:Raycast(pt + Vector3.new(0, 6, 0), Vector3.new(0, -8, 0), rp)
				if not hh or math.abs(hh.Position.Y - y) > 0.05 then ok = false end
			end
		end
		if ok then
			-- the Top-face gui's up edge is the part's -X side: RightVector = toward the plaza, so the text's top is toward the
			-- bin and it reads upright from the plaza side; the 6-stud side (Z) runs across the approach
			local st = part(binF, "BinStencil_" .. i, Vector3.new(2, 0.06, 6), CFrame.fromMatrix(sp, toC, Vector3.yAxis), NEAR_BLACK)
			st.Transparency = 0.15
			local g = gui(st, Enum.NormalId.Top, 30)
			label(g, "WEAPON SWAP", U(0.04, 0.1), U(0.92, 0.8), CREAM)
			nSt += 1
		end
	end
end
say(string.format("bins: %d framed, %d stencils", nBin, nSt))
for _, d in ipairs(tmpQ) do d.CanQuery = false end

---------------------------------------------------------------------------------------------------
-- 5. grid line read
---------------------------------------------------------------------------------------------------
local nTex = 0
for _, d in ipairs(R:GetDescendants()) do
	if d:IsA("Texture") and d.Texture:find("86361987736184") then
		setP(d, {Color3 = C(34, 34, 34), Transparency = 0.32}); nTex += 1
	end
end
say("grid textures: " .. nTex)

root.Parent = polish
return table.concat(log, "\n")
