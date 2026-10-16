-- polish_exfil2.lua : Exfil small fixes from the fresh-eyes review (notes/review_exfil.md). Tacticals_rebuild.rbxl ONLY.
-- Run after polish_exfil.lua (a re-run of polish_exfil.lua rebuilds Polish.Exfil, so re-run this one after it).
-- 1. Windsock: the polish_exfil windsock (10-stud mast, 1.3-stud sock on the open-edge walk at (149.4, 18.5)) filled the top
--    of the view at the edge. Hidden (originals stored) and rebuilt smaller in the north-east corner on the kerb behind the
--    edge rail and the invisible clip wall (x 152.25, z 24.8): 7-stud mast, slimmer sock (0.75 -> 0.38, half the mouth),
--    streaming south over the kerb, outside the walk. Same amber/cream/near-black, amber obstruction lamp (Neon only).
-- 2. Container labels: the two blank cream plates of IndustrialProps.F_Container20 (north side 3.8 x 0.7, west end
--    0.8 x 0.8) get near-black stencil text (cargo codes), plus warm-grey painted markings on the skin, on transparent carriers.
-- Not touched: the ExfilBarrier fires from both sides (walking back from the pad can launch the cutscene): Edward's call,
-- see notes/polish_exfil.md round 2.
-- Idempotent and UNDO-able: hidden properties stored once (typed JSON) in attribute PolishExfil2_Orig; new parts in
-- Workspace.LobbyMap.Polish.Exfil.Round2. No lights, nothing new collides except the mast base and pole (behind the clip wall).
-- UNDO: python tools/run_luau.py fix/polish_exfil2.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local ATTR = "PolishExfil2_Orig"
local C = Color3.fromRGB
local M = Enum.Material
local log = {}
local function say(s) table.insert(log, s) end

local PX = LM.Polish:FindFirstChild("Exfil")
assert(PX, "run fix/polish_exfil.lua first")

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	else return o.v end
end
local function setP(inst, props)
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	for k, v in pairs(props) do
		if o[k] == nil then o[k] = encV(inst[k]) end
		inst[k] = v
	end
	inst:SetAttribute(ATTR, HttpService:JSONEncode(o))
end

if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	if PX:FindFirstChild("Round2") then PX.Round2:Destroy() end
	return "UNDO polish_exfil2: restored " .. n .. " instances, removed Polish.Exfil.Round2"
end
if PX:FindFirstChild("Round2") then PX.Round2:Destroy() end
local root = Instance.new("Folder"); root.Name = "Round2"
root:SetAttribute("PolishPass", "polish_exfil2.lua")

local AMBER_PAINT = C(212, 122, 42)
local AMBER_NEON = C(190, 108, 26)
local AMBER_FABRIC = C(214, 128, 40)
local CREAM = C(236, 232, 218)
local NEAR_BLACK = C(10, 12, 10)
local STENCIL = C(28, 28, 26)
local DARK = C(40, 37, 34)
local METAL = C(108, 107, 104)

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	if o.shape then p.Shape = o.shape end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
	p.Anchored = true; p.CanCollide = o.collide == true; p.CanQuery = o.collide == true; p.CanTouch = false
	p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.transparent then p.Transparency = 1 end
	p:SetAttribute("NotCover", true)
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------------
-- 1. windsock
---------------------------------------------------------------------------------------------------
local old = PX:FindFirstChild("Windsock")
local nHid = 0
if old then
	for _, d in ipairs(old:GetDescendants()) do
		if d:IsA("BasePart") then
			setP(d, {Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false}); nHid += 1
		end
	end
end
local ws = Instance.new("Model"); ws.Name = "Windsock"; ws.Parent = root
do
	-- the kerb top behind the edge rail (rail x ~151.7, kerb to x 152.6, top 1.40); players stop at the clip wall x 151.4
	local x, z = 152.25, 24.8
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {LM.Polish}
	local h = workspace:Raycast(Vector3.new(x, 12, z), Vector3.new(0, -14, 0), rp)
	local top = (h and h.Position.Y) or 1.4
	local H = 7
	part(ws, "Base", Vector3.new(0.55, 0.14, 0.55), CFrame.new(x, top + 0.07, z), DARK, M.Metal, {collide = true})
	part(ws, "Pole", Vector3.new(H, 0.2, 0.2), CFrame.new(x, top + 0.14 + H / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		METAL, M.Metal, {shape = Enum.PartType.Cylinder, collide = true, shadow = true})
	for i = 0, 3 do
		part(ws, "PoleBand" .. i, Vector3.new(0.4, 0.23, 0.23), CFrame.new(x, top + 0.4 + i * 0.4, z) * CFrame.Angles(0, 0, math.rad(90)),
			i % 2 == 0 and AMBER_PAINT or NEAR_BLACK, M.SmoothPlastic, {shape = Enum.PartType.Cylinder})
	end
	local ty = top + 0.14 + H
	part(ws, "Lamp", Vector3.new(0.34, 0.34, 0.34), CFrame.new(x, ty + 0.17, z), AMBER_NEON, M.Neon, {shape = Enum.PartType.Ball})
	part(ws, "LampCap", Vector3.new(0.08, 0.38, 0.38), CFrame.new(x, ty + 0.02, z) * CFrame.Angles(0, 0, math.rad(90)), DARK, M.Metal, {shape = Enum.PartType.Cylinder})
	-- swivel arm and a tapered sock streaming south (wind from the north), drooping a little more per segment
	local dir = Vector3.new(0, -math.sin(math.rad(14)), -math.cos(math.rad(14)))
	part(ws, "Arm", Vector3.new(0.08, 0.08, 0.5), CFrame.new(x, ty - 0.4, z - 0.25), DARK, M.Metal)
	local function along(pos, d) return CFrame.lookAt(pos, pos + d) * CFrame.Angles(0, math.rad(90), 0) end
	local dia = {0.75, 0.66, 0.57, 0.47, 0.38}
	local pos = Vector3.new(x, ty - 0.4, z - 0.5)
	for i, d in ipairs(dia) do
		local len = 0.62
		local di = (dir + Vector3.new(0, -0.04 * i, 0)).Unit
		local c = pos + di * (len / 2)
		part(ws, "Sock" .. i, Vector3.new(len, d, d), along(c, di), i % 2 == 1 and AMBER_FABRIC or CREAM, M.Fabric,
			{shape = Enum.PartType.Cylinder, shadow = true})
		pos = pos + di * len
	end
	say(("windsock: old hidden (%d parts), new 7-stud mast on the kerb at (%.2f, %.2f, %.2f)"):format(nHid, x, top, z))
end

---------------------------------------------------------------------------------------------------
-- 2. container stencils. The label MeshPart's query hull is its bounding box, so the visible plates were measured from
--    captures: north plate x 115.0..119.0, y 5.62..6.32 on the north side (z 17.11); west plate z 14.8..15.63,
--    y 4.73..5.51 on the west end doors (x 108.93). Each plate gets near-black text; the container skin gets
--    painted warm-grey stencils (operator, code, weights) beside them, like real cargo markings.
---------------------------------------------------------------------------------------------------
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local PAINT = C(200, 196, 186)
local cont = LM.IndustrialProps:FindFirstChild("F_Container20")
local lab = cont and cont:FindFirstChild("F_Container20__label_cream")
local function stencil(name, size, cf, lines, color, align)
	local p = part(root, name, size, cf, CREAM, M.SmoothPlastic, {transparent = true})
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 100; g.LightInfluence = 1; g.Parent = p
	local n = #lines
	for i, ln in ipairs(lines) do
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.94, 0.86 / n)
		t.Position = UDim2.fromScale(0.03, 0.07 + (i - 1) * 0.86 / n)
		t.Text = ln; t.TextScaled = true; t.FontFace = FONT; t.TextColor3 = color
		t.TextXAlignment = align or Enum.TextXAlignment.Left; t.Parent = g
	end
	return p
end
if lab then
	local zn, xw = 17.11 + 0.035, 108.58 - 0.03
	local function north(name, x0, x1, y0, y1, lines, color, align)
		local c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, zn)
		return stencil(name, Vector3.new(x1 - x0, y1 - y0, 0.02), CFrame.lookAt(c, c + Vector3.zAxis), lines, color, align)
	end
	local function west(name, z0, z1, y0, y1, x, lines, color, align)
		local c = Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2)
		return stencil(name, Vector3.new(z1 - z0, y1 - y0, 0.02), CFrame.lookAt(c, c - Vector3.xAxis), lines, color, align)
	end
	-- on the plates (near-black)
	north("PlateNorth", 115.12, 118.88, 5.68, 6.27, {"TCU 204117  22G1"}, STENCIL, Enum.TextXAlignment.Center)
	west("PlateWest", 14.86, 15.57, 4.79, 5.45, 108.93 - 0.035, {"22G1", "C20"}, STENCIL, Enum.TextXAlignment.Center)
	-- painted on the skin (warm grey)
	north("PaintOperator", 109.6, 114.6, 5.6, 6.35, {"SKY BASE LOGISTICS"}, PAINT)
	north("PaintWeights", 109.6, 118.9, 4.7, 5.3, {"MAX GROSS 24,000 KG    TARE 2,200 KG    NET 21,800 KG"}, PAINT)
	west("PaintCode", 11.6, 15.6, 6.0, 6.6, xw, {"TCU 204117"}, PAINT)
	say("container stencils: 2 plates + 3 painted markings")
else
	say("WARN F_Container20 label plate not found")
end

root.Parent = PX
return table.concat(log, "\n")
