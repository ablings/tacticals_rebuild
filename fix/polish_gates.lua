-- polish_gates.lua : N / S gate corridors polish (overnight pass). Tacticals_rebuild.rbxl ONLY.
-- Identity: AIRLOCK BULKHEADS. Short, tight, transitional: ribbed corrugated metal walls, a near-black band, near-black
-- bulkhead ribs, cool-neutral white strips in the wall recess, door status lights at the two airlock ribs, hazard-stripe
-- sills (near-black + cream) at the hub end and under both airlock ribs. Each corridor previews its room: the last bay of the
-- N corridor turns to the Shop's warm cream panels and warm strips (and the Shop doorway frame takes the Shop's cream), the
-- last bay of the S corridor to the Armory's gunmetal (the Armory doorway frame is already gunmetal).
-- The hub's SHOP sign text reads OUTFITTERS (the Shop is the OUTFITTERS cosmetic shop since Shop round 3).
-- RIVALS method (read-only captures of its doorways): dark metal door reveals, light concrete surrounds, a yellow stripe at
-- the door foot, Neon strips as the light source. Our accent swap: cream / near-black hazard.
-- Lights: no Light instances added or changed (Neon only). Nothing new collides, nothing narrows the corridor: new wall
-- pieces sit in the wall recess or within 0.06 of the wall plate (clear width 10.18 there; the ribs keep the minimum).
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishGates_Orig; new parts in
-- Workspace.LobbyMap.Polish.Gates. UNDO: python tools/run_luau.py fix/polish_gates.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local R2 = LM.Rooms2
local ATTR = "PolishGates_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(...) local t = {} for _, v in ipairs({...}) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "UDim2" then return {t = "u", v = {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "u" then return UDim2.new(o.v[1], o.v[2], o.v[3], o.v[4])
	else return o.v end
end
local touched = 0
local function setP(inst, props)
	if not inst then return end
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
	touched += 1
end

local polish = LM:FindFirstChild("Polish")
if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			for k, v in pairs(HttpService:JSONDecode(s)) do
				local val = decV(v)
				-- a first run stored the sign label's UDim2 Size untyped (lost): its original is Scale 1 x 0.8
				if val == nil and k == "Size" and d:IsA("GuiObject") then val = UDim2.fromScale(1, 0.8) end
				d[k] = val
			end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if polish and polish:FindFirstChild("Gates") then polish.Gates:Destroy() end
	return "UNDO polish_gates: restored " .. n .. " instances, removed Polish.Gates"
end
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Gates") then polish.Gates:Destroy() end
local PG = Instance.new("Folder"); PG.Name = "Gates"

---------------------------------------------------------------------------------------------------
-- palette (render-checked with tools/part_pixels.py; see notes/polish_gates.md)
---------------------------------------------------------------------------------------------------
local CREAM, NEAR = C(236, 232, 218), C(10, 12, 10)
local STRIP_COOL = C(214, 222, 228)
local STRIP_WARM = C(240, 214, 176)
local LAMP_GO = C(96, 118, 50)
local LAMP_STOP = C(74, 22, 20)
-- the corridor meshes (C_CorrN / C_CorrS are corridor-only)
local ENV = {
	-- first pass rendered blue (B-R +10..+32) and dark: each value is the neutral target divided by the measured render
	-- ratio (60% of the full correction), walls on the ribbed concrete variant instead of Metal (sky specular)
	wall_plate = {C(144, 136, 130), M.Concrete, "TacRibbed"},
	door_leaf = {C(90, 77, 70), M.Metal, "TacCorrugatedMetal"},
	band_olive = {C(34, 30, 28), M.Plastic, ""},
	wall_kick = {C(44, 39, 36), M.Plastic, ""},
	beam_metal = {C(46, 40, 36), M.Plastic, ""},
	trim_metal = {C(104, 90, 82), M.Metal, "TacMetal"},
	ceiling = {C(101, 90, 83), M.Plastic, ""},
	plate_metal = {C(89, 73, 65), M.Metal, "TacFloorPlate"},
	floor_border = {C(52, 44, 40), M.Concrete, "TacFloorConcrete"},
	neon_lamp = {STRIP_COOL, M.Neon, ""},
	neon_cream = {C(108, 108, 104), M.Neon, ""},
}
local nEnv = 0
for _, f in ipairs({R2.C_CorrN, R2.C_CorrS}) do
	for _, p in ipairs(f:GetChildren()) do
		local spec = p:IsA("BasePart") and ENV[p.Name:match("__(.+)$") or ""]
		if spec then setP(p, {Color = spec[1], Material = spec[2], MaterialVariant = spec[3]}); nEnv += 1 end
	end
	local hz = f:FindFirstChild(f.Name .. "__hazard")
	local tx = hz and hz:FindFirstChildWhichIsA("Texture")
	if tx then setP(tx, {Color3 = CREAM}) end
end
-- pipe runs in the corridors: their olive band rendered lime; dark olive like the Armory crates
for _, m in ipairs(LM.IndustrialProps:GetChildren()) do
	if m.Name == "F_PipeRun" then
		local p = m:GetPivot().Position
		if math.abs(p.X) < 6 and math.abs(p.Z) > 48 and math.abs(p.Z) < 65 then
			local b = m:FindFirstChild("F_PipeRun__band_olive")
			if b then setP(b, {Color = C(78, 82, 46)}); nEnv += 1 end
		end
	end
end
-- the Shop doorway frame takes the Shop's cream (the Armory frame is gunmetal already, from polish_armory)
local sw = R2.S_Walls
setP(R2.S_Door:FindFirstChild("S_Door__wall_light"), {Color = sw.S_Walls__wall_light.Color, MaterialVariant = sw.S_Walls__wall_light.MaterialVariant})
setP(R2.S_Door:FindFirstChild("S_Door__trim_metal"), {Color = C(150, 132, 104)})
say("corridor meshes recoloured:", nEnv)

-- the hub sign over the N gate: SHOP -> OUTFITTERS (a text sign: SurfaceGui label on Hub1.Overlays.SignText_SHOP)
local st = LM.Hub1.Overlays:FindFirstChild("SignText_SHOP")
local lbl = st and st:FindFirstChild("Text") and st.Text:FindFirstChild("Label")
if lbl then setP(lbl, {Text = "OUTFITTERS", Size = UDim2.fromScale(0.92, 0.7)}); say("SHOP sign -> OUTFITTERS") else say("WARN SignText_SHOP label not found") end

---------------------------------------------------------------------------------------------------
-- helpers + measuring
---------------------------------------------------------------------------------------------------
local function part(parent, name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end
local qOn = {}
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 and math.abs(d.Position.Z) > 30 and math.abs(d.Position.Z) < 80 then
		d.CanQuery = true; table.insert(qOn, d)
	end
end
local skip = {polish}
for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") and d.Transparency >= 0.95 then table.insert(skip, d) end end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = skip
-- runs along z (sgn side) where a ray at height y toward the wall hits a part whose name contains `want`
local function runs(sgn, side, y, want, xmin)
	local out, cur = {}, nil
	for i = 0, 340 do
		local az = 47.5 + i * 0.05
		local h = workspace:Raycast(Vector3.new(0, y, az * sgn), Vector3.new(8 * side, 0, 0), rp)
		local ok = h and h.Instance.Name:find(want, 1, true) and math.abs(h.Position.X) >= xmin
		if ok then
			if cur then cur.b = az else cur = {a = az, b = az, x = math.abs(h.Position.X)}; table.insert(out, cur) end
		else cur = nil end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- per corridor
---------------------------------------------------------------------------------------------------
local RIBS = {52.0, 61.0}
for _, cor in ipairs({{"N", 1, "C_CorrN"}, {"S", -1, "C_CorrS"}}) do
	local tag, sgn, mesh = cor[1], cor[2], cor[3]
	local F = Instance.new("Folder"); F.Name = tag
	local nStrip, nLamp, nSill, nPanel = 0, 0, 0, 0
	-- 1. wall strips in the recess between the wall plate and the band (face 5.40, y ~6.35-7.0)
	for _, side in ipairs({-1, 1}) do
		local rr = runs(sgn, side, 6.68, mesh .. "__wall_kick", 5.35)
		for _, r in ipairs(rr) do
			local a, b = r.a + 0.12, r.b - 0.12
			if b - a > 0.8 then
				local far = r.b > 61.6
				local col = (far and tag == "N") and STRIP_WARM or STRIP_COOL
				local zc = (a + b) / 2 * sgn
				-- the recess back is at 5.40 between y 6.35 and 6.85 (a trim ledge at 5.10 starts above it)
				part(F, far and "StripFar" or "Strip", Vector3.new(0.14, 0.3, b - a), CFrame.new(side * 5.31, 6.6, zc), col, M.Neon)
				nStrip += 1
			end
		end
	end
	-- 2. door status lights on the upper wall, hub side of each airlock rib, both walls: near-black housing, a lit
	--    olive-green GO lens over an unlit red STOP lens (lenses face into the corridor)
	for _, rz in ipairs(RIBS) do
		for _, side in ipairs({-1, 1}) do
			local z = (rz - 0.95) * sgn
			local h = workspace:Raycast(Vector3.new(0, 11.0, z), Vector3.new(8 * side, 0, 0), rp)
			local wx = h and math.abs(h.Position.X) or 5.40
			local m = Instance.new("Model"); m.Name = "StatusLight"
			part(m, "Housing", Vector3.new(0.26, 1.05, 0.62), CFrame.new(side * (wx - 0.13 - 0.01), 11.0, z), C(22, 23, 24), M.Metal)
			local x = side * (wx - 0.27 - 0.03)
			for _, l in ipairs({{11.25, LAMP_GO, M.Neon, "Go"}, {10.76, LAMP_STOP, M.SmoothPlastic, "Stop"}}) do
				local p = part(m, l[4], Vector3.new(0.06, 0.34, 0.34), CFrame.new(x, l[1], z), l[2], l[3])
				p.Shape = Enum.PartType.Cylinder
			end
			m.Parent = F
			nLamp += 1
		end
	end
	-- 3. hazard sills (near-black + cream TX_hazard_stripe): the hub end and under both airlock ribs
	local HAZ = "rbxassetid://79584884795039"
	for _, s in ipairs({{"SillHub", 49.75, 0.8}, {"SillRibA", RIBS[1], 1.1}, {"SillRibB", RIBS[2], 1.1}}) do
		-- three pieces: the cream floor lines (|x| 3.72..4.08) stay visible through the sill
		for _, seg in ipairs({{-4.84, -4.13}, {-3.67, 3.67}, {4.13, 4.84}}) do
			local p = part(F, s[1], Vector3.new(seg[2] - seg[1], 0.06, s[3]), CFrame.new((seg[1] + seg[2]) / 2, 0.03, s[2] * sgn), NEAR, M.SmoothPlastic)
			local tx = Instance.new("Texture"); tx.Texture = HAZ; tx.Face = Enum.NormalId.Top; tx.Color3 = CREAM
			tx.StudsPerTileU = 4; tx.StudsPerTileV = 1; tx.OffsetStudsU = seg[1]; tx.Parent = p
		end
		nSill += 1
	end
	-- 4. destination bay (between the far rib and the room doorway): the wall plate, and the band on the wall without the
	--    pipe run, faced in the room's own wall finish (N: the Shop's cream panels; S: the Armory's gunmetal)
	local pipeSide = tag == "N" and 1 or -1
	for _, side in ipairs({-1, 1}) do
		for _, spec in ipairs({{4.0, "__wall_plate", 1.55, 6.3, "DestPanel"}, {8.5, "__band_olive", 7.3, 9.85, "DestBand"}}) do
			if not (spec[5] == "DestBand" and side == pipeSide) then
				for _, r in ipairs(runs(sgn, side, spec[1], mesh .. spec[2], 5.1)) do
					if r.a > 61.2 and r.b - r.a > 1 then
						local a, b = r.a + 0.15, r.b - 0.15
						-- most proud face over the run at three heights
						local face = 9
						for _, y in ipairs({spec[3] + 0.1, (spec[3] + spec[4]) / 2, spec[4] - 0.1}) do
							for _, zz in ipairs({a, (a + b) / 2, b}) do
								local h = workspace:Raycast(Vector3.new(0, y, zz * sgn), Vector3.new(8 * side, 0, 0), rp)
								if h then face = math.min(face, math.abs(h.Position.X)) end
							end
						end
						local x = side * (face - 0.025 - 0.03)
						local size = Vector3.new(0.05, spec[4] - spec[3], b - a)
						local cf = CFrame.new(x, (spec[3] + spec[4]) / 2, (a + b) / 2 * sgn)
						local p
						if tag == "N" then
							local src = spec[5] == "DestBand" and sw.S_Walls__wall_light or sw.S_Walls__wall_body
							p = part(F, spec[5], size, cf, src.Color, M.Concrete); p.MaterialVariant = src.MaterialVariant
						else
							local src = spec[5] == "DestBand" and R2.A_Walls.A_Walls__wall_dark or R2.A_Walls.A_Walls__wall_plate
							p = part(F, spec[5], size, cf, src.Color, src.Material); p.MaterialVariant = src.MaterialVariant
						end
						nPanel += 1
					end
				end
			end
		end
	end
	F.Parent = PG
	say(tag, "strips", nStrip, "status lights", nLamp, "sills", nSill, "destination panels", nPanel)
end

for _, d in ipairs(qOn) do d.CanQuery = false end
PG.Parent = polish
say("touched", touched)
return table.concat(log, "\n")
