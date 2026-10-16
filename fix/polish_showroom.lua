-- polish_showroom.lua : the Showroom as a CLEAN PHOTO STUDIO (overnight polish). Tacticals_rebuild.rbxl ONLY. Run after
-- place_showroom.lua and polish_olive.lua.
-- What players see: only CameraPoint's view (LobbyUIController.Armory: Scriptable camera at CameraPoint, FOV 40, the item drawn
-- in a ViewportFrame lit from KeyLight -> DisplayPoint, and the room behind it BLURRED, BlurEffect 16). So the set is judged as
-- a soft background: tone, gradient and colour, not detail. Measured frame (rays from CameraPoint at FOV 40, 16:9): the bench
-- fills the bottom edge, the back wall (z 33) fills the rest, x -24.5..24.5, y ~401..418; the floor behind the bench is never
-- in frame (the sight line over the bench's back edge reaches the floor at z ~37).
-- Identity (Edward): cream cyclorama, a plinth, soft key + rim light, minimal accent; no ambient particles, nothing RIVALS lacks.
-- 1. Cyclorama: a cream sweep in front of the old ARMORY backdrop wall: back panel at z 30 (x -27..27, y 405.9..425.5) and a
--    radius-6 cove (8 segments) down to the floor at z 24 (no floor apron: the floor behind the plinth is never in frame).
--    Matte SmoothPlastic, CastShadow off, nothing collides or is queryable (the room is never walked).
-- 1b. The SR_Props crate / case / rack stacks at the frame's side edges are hidden.
-- 2. Plinth: the stage bench as a plinth: cream top, warm-grey body, the Metal front plate (rendered sky-blue) to warm-grey
--    Plastic, the front Neon strip off-glow (it read as a screen at the frame's bottom edge); the olive band stays as the one
--    thin accent line.
-- 3. Light (own lights only, count unchanged): KeyLight softer and neutral-warm (angle 60 -> 75); Pendant1/2 become cool rim
--    lights high behind the display; Pendant3/4 become the background light: low behind the plinth, a warm glow on the cove
--    behind the item (each in a small near-black lamp can, hidden from the camera by the plinth); Fill neutral.
-- Hooks untouched: DisplayPoint, CameraPoint, BenchTop, KeyLight (name, part, CFrame), Lights.* (names, RoomLight tag, Room).
-- Idempotent and UNDO-able: touched properties stored once (typed JSON) in attribute PolishShowroom_Orig; new parts in
-- Workspace.LobbyMap.Polish.Showroom. Comments on their own line. UNDO: python tools/run_luau.py fix/polish_showroom.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local S = LM.Showroom
local K = S.Rooms4
local ATTR = "PolishShowroom_Orig"
local C = Color3.fromRGB
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "CFrame" then return {t = "cf", v = {v:GetComponents()}}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
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
	if polish and polish:FindFirstChild("Showroom") then polish.Showroom:Destroy() end
	return "UNDO polish_showroom: restored " .. n .. " instances, removed Polish.Showroom"
end
if not polish then polish = Instance.new("Folder"); polish.Name = "Polish"; polish.Parent = LM end
if polish:FindFirstChild("Showroom") then polish.Showroom:Destroy() end
local root = Instance.new("Folder"); root.Name = "Showroom"
root:SetAttribute("PolishPass", "polish_showroom.lua")

-- paint values divided by the measured render ratio in this set (cyc 0.95 / 1.01 / 1.06: the sky fill cools whites), so
-- the cyc renders cream and not cool white 221,229,229 (a first pass at 60% still rendered neutral, B-R 0: near white the
-- render compresses, so the paint needs the full warm lean); the plinth one step darker than the cyc
local CREAM = C(232, 208, 176)
local CYC = C(244, 214, 180)
local WARM_GREY = C(212, 186, 152)
local PLINTH_DARK = C(168, 150, 124)
local NEAR_BLACK = C(10, 12, 10)

local function part(parent, name, size, cf, color, shape)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	if shape then p.Shape = shape end
	p.Material = Enum.Material.SmoothPlastic; p.Anchored = true
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("NotCover", true); p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------------
-- 1. cyclorama
---------------------------------------------------------------------------------------------------
local cyc = Instance.new("Folder"); cyc.Name = "Cyclorama"; cyc.Parent = root
local W = 54
-- the floor trim mesh tops out at 400.07 and the cove's outer face sits 0.2 below its inner face: the sweep starts at
-- 400.3 so the lowest cove segment clears the floor (the apron is never in frame)
local FLOOR = 400.3
local R = 6
local Z0 = 24
local ZB = Z0 + R
local YC = FLOOR + R
-- back panel: vertical, its front face at z = ZB, from the top of the cove up under the ceiling (426.5)
part(cyc, "CycBack", Vector3.new(W, 425.5 - YC, 0.2), CFrame.new(0, (425.5 + YC) / 2, ZB + 0.1), CYC)
-- cove: quarter circle, centre (z Z0, y YC), from the floor (angle 0: straight down) to the back panel (angle 90: toward +z)
local N = 8
local seg = 2 * R * math.sin(math.rad(90 / N / 2)) + 0.06
for i = 0, N - 1 do
	local a = math.rad((i + 0.5) * 90 / N)
	-- point on the arc: down = -y, back = +z; surface normal points to the centre
	local pz, py = Z0 + R * math.sin(a), YC - R * math.cos(a)
	local n = Vector3.new(0, math.cos(a), -math.sin(a))
	local pos = Vector3.new(0, py, pz) - n * 0.1
	-- the part's Y axis is the inward normal; its Z axis runs along the arc
	local along = Vector3.new(0, math.sin(a), math.cos(a))
	part(cyc, "CycCove", Vector3.new(W, 0.2, seg), CFrame.fromMatrix(pos, Vector3.xAxis, n, along), CYC)
end
-- side returns: short cream wings at the panel ends so a wide screen never shows the old wall past the sweep
for _, sx in ipairs({-1, 1}) do
	part(cyc, "CycWing", Vector3.new(0.2, 425.5 - FLOOR, 6), CFrame.new(sx * (W / 2 + 0.1), (425.5 + FLOOR) / 2, ZB - 3 + 0.2), CYC)
end
-- the crate / case / rack stacks (SR_Props, merged per material) stood at the frame's side edges in front of the sweep:
-- hidden (they are set dressing in a room that is only ever seen from CameraPoint)
local nHid = 0
local props = K:FindFirstChild("SR_Props")
if props then
	for _, d in ipairs(props:GetDescendants()) do
		if d:IsA("BasePart") then
			setP(d, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}); nHid += 1
		end
	end
end
say("cyclorama: back panel, " .. N .. " cove segments, 2 wings; SR_Props hidden: " .. nHid)

---------------------------------------------------------------------------------------------------
-- 2. plinth (the stage bench; BenchTop itself is an invisible hook and is not touched)
---------------------------------------------------------------------------------------------------
local st = K:FindFirstChild("SR_Stage")
if st then
	setP(st:FindFirstChild("SR_Stage__bench_top"), {Color = CREAM})
	setP(st:FindFirstChild("SR_Stage__trim_metal"), {Color = WARM_GREY, Material = Enum.Material.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__wall_kick"), {Color = PLINTH_DARK, Material = Enum.Material.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__dark_metal"), {Color = PLINTH_DARK, Material = Enum.Material.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__neon_cream"), {Color = WARM_GREY, Material = Enum.Material.SmoothPlastic})
	setP(st:FindFirstChild("SR_Stage__band_olive"), {Color = C(110, 120, 52), Material = Enum.Material.SmoothPlastic})
	-- the blank label plate on the plinth front (SR_Signs__label_cream) rendered sky-blue at the frame's bottom edge
	local sg = K:FindFirstChild("SR_Signs")
	setP(sg and sg:FindFirstChild("SR_Signs__label_cream"), {Color = WARM_GREY})
	say("plinth recoloured")
end

---------------------------------------------------------------------------------------------------
-- 3. light: retune the room's own lights (count unchanged)
---------------------------------------------------------------------------------------------------
local key = S.KeyLight:FindFirstChildWhichIsA("SpotLight")
if key then setP(key, {Color = C(255, 244, 228), Brightness = 2.6, Angle = 75}) end
local L = S.Lights
local function relight(name, pos, props)
	local p = L:FindFirstChild(name)
	if not p then return end
	setP(p, {CFrame = CFrame.new(pos)})
	local l = p:FindFirstChildWhichIsA("Light")
	if l then setP(l, props) end
end
-- rim: high behind the display point (0, 406.3, 8), cool white
relight("Pendant1", Vector3.new(6, 411.5, 15), {Color = C(226, 232, 240), Brightness = 0.9, Range = 14})
relight("Pendant2", Vector3.new(-6, 411.5, 15), {Color = C(226, 232, 240), Brightness = 0.9, Range = 14})
-- background light: low behind the plinth, a warm glow on the cove behind the item
relight("Pendant3", Vector3.new(-5, 401.2, 21.5), {Color = C(255, 238, 214), Brightness = 1.4, Range = 16})
relight("Pendant4", Vector3.new(5, 401.2, 21.5), {Color = C(255, 238, 214), Brightness = 1.4, Range = 16})
relight("Fill", L.Fill and L.Fill.Position or Vector3.new(0, 418, 18), {Color = C(236, 232, 224), Brightness = 0.45})
-- visible sources: a small near-black lamp can under each background light (hidden from the camera by the plinth)
local cans = Instance.new("Folder"); cans.Name = "LampCans"; cans.Parent = root
-- the floor trim top under the cans
local FLOOR_TOP = 400.07
for _, nm in ipairs({"Pendant3", "Pendant4"}) do
	local p = L:FindFirstChild(nm)
	if p then
		local base = p.Position
		part(cans, "LampCan", Vector3.new(0.9, 1.0, 1.0), CFrame.new(base.X, FLOOR_TOP + 0.45, base.Z - 0.15) * CFrame.Angles(0, 0, math.pi / 2), NEAR_BLACK, Enum.PartType.Cylinder)
		local lens = part(cans, "LampLens", Vector3.new(0.06, 0.8, 0.8), CFrame.new(base.X, FLOOR_TOP + 0.6, base.Z + 0.42) * CFrame.Angles(0, math.pi / 2, 0), C(255, 238, 214), Enum.PartType.Cylinder)
		lens.Material = Enum.Material.Neon
	end
end
say("lights retuned: KeyLight, Pendant1/2 rim, Pendant3/4 background, Fill")

root.Parent = polish
return table.concat(log, "\n")
