-- polish_final.lua : cross-room fixes from the final whole-lobby lap (overnight polish, 2026-10-16). Tacticals_rebuild.rbxl ONLY.
-- Run LAST, after every other polish script (polish_olive in particular: a re-run of polish_olive resets the olive Neon, so
-- run polish_final again after it). Notes: notes/polish_final.md.
-- 1. Olive Neon reads olive, not yellow-green. Measured in Play (tools/play_pixels.py, hub disc view): the shared olive Neon
--    84,88,48 rendered 90,101,22 (G/R 1.12, B/R 0.24, chartreuse) next to the hub band rendering 82,82,41 (G/R 0.99, B/R 0.50).
--    Trial frame (two candidates on the disc ring and the floor lines): 100,90,66 -> 136,108,48 (gold), 92,88,60 -> 99,91,43,
--    88,88,64 -> 102,102,44 (G/R 1.00, B/R 0.43), 90,88,68 -> 95,91,55 (0.96 / 0.58). Chosen 88,88,66 (between the last two).
--    The features-kit "bright" olive 96,100,54 moves by the same step to 100,99,75. Scope: every Neon part polish_olive set
--    (attribute PolishOlive_Orig), plus leftover round-1 lime Neon 90,106,42 (Polish.Duels BoardBottomLine, Polish.Armory
--    EdgeL/R/T) and the Shop stage DaisRing (dark olive 107,122,58 Neon, read lime under the warm pools).
--    Left alone on purpose (deliberate room accents): Duels team-B Frames 94,99,46, the hub DUELS sign bar, gate GO lights,
--    Armory sage glows, Training quadrant colours / pad rings / range lines, Exfil amber.
-- 2. Hub hologram rings: at the spawn the rings swept across every gate view (ring1 15.3 wide at y 9.5, T 0.5). Ring1 10 x 0.09,
--    ring2 7.4 x 0.07, both T 0.78: changed pixels in the toN view 7.4% -> 3.2%, contrast 62 -> 36 levels (rings on vs hidden).
--    Position, spin and colour unchanged (LobbyFX spins them by CFrame only).
-- 3. Light budget (Play, counted per area; none added): 6 leftover old-lobby PointLights (Lights.PointLight at y 6, |z| 51,
--    invisible 1-stud hosts 2 studs BEHIND the hub wall kick, Shadows off, so their light came through the wall) and the 9
--    TimesSquare billboard SurfaceLights (x 357-382; on vs off from the Exfil pad: mean change 0.07 levels, nothing reachable
--    is lit by them) are switched off. 59 -> 44 enabled lights with the camera at the hub.
-- 4. Duels doorway (hub side): H_DuelsDoor__trim_metal carries two Texture objects on its Left/Right faces; on the 7-stud deep
--    reveal they project edge-on and render as radial streaks in Play. The two Textures are hidden (Transparency 1).
-- Idempotent and UNDO-able: every touched property stored once (typed JSON) in attribute PolishFinal_Orig. Nothing is created,
-- moved, renamed or deleted; no hook is touched. UNDO: python tools/run_luau.py fix/polish_final.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local ATTR = "PolishFinal_Orig"
local C = Color3.fromRGB
local log = {}
local function say(s) table.insert(log, s) end

local function encV(v)
	local t = typeof(v)
	if t == "Color3" then return {t = "c", v = {v.R, v.G, v.B}}
	elseif t == "Vector3" then return {t = "v", v = {v.X, v.Y, v.Z}}
	elseif t == "EnumItem" then return {t = "e", e = tostring(v.EnumType), v = v.Name}
	else return {t = "p", v = v} end
end
local function decV(o)
	if o.t == "c" then return Color3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "v" then return Vector3.new(o.v[1], o.v[2], o.v[3])
	elseif o.t == "e" then return Enum[o.e][o.v]
	else return o.v end
end
local function origOf(inst, k)
	local s = inst:GetAttribute(ATTR)
	local o = s and HttpService:JSONDecode(s) or {}
	if o[k] ~= nil then return decV(o[k]) end
	return inst[k]
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

if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			for k, v in pairs(HttpService:JSONDecode(s)) do d[k] = decV(v) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	return "UNDO polish_final: restored " .. n .. " instances"
end

local function rgb(c) return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) end
local function is(c, r, g, b) local R, G, B = rgb(c); return math.abs(R - r) <= 1 and math.abs(G - g) <= 1 and math.abs(B - b) <= 1 end

-- 1. olive Neon
local NEON = C(88, 88, 66)
local NEON_BRIGHT = C(100, 99, 75)
local nOlive, nBright, nLeft = 0, 0, 0
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
		local c0 = origOf(d, "Color")
		if d:GetAttribute("PolishOlive_Orig") then
			if is(c0, 84, 88, 48) then setP(d, {Color = NEON}); nOlive += 1
			elseif is(c0, 96, 100, 54) then setP(d, {Color = NEON_BRIGHT}); nBright += 1 end
		elseif is(c0, 90, 106, 42) and (d.Name == "BoardBottomLine" or d.Name:match("^Edge[LRT]$")) then
			setP(d, {Color = NEON}); nLeft += 1
		elseif d.Name == "DaisRing" and is(c0, 107, 122, 58) then
			setP(d, {Color = NEON}); nLeft += 1
		end
	end
end
say(("1. olive Neon: %d shared 84,88,48 -> 88,88,66; %d bright 96,100,54 -> 100,99,75; %d leftover lime/dark-olive Neon -> 88,88,66"):format(nOlive, nBright, nLeft))

-- 2. hologram rings
local holo = LM.FX:FindFirstChild("Hologram")
if holo then
	setP(holo:FindFirstChild("HoloRing1"), {Size = Vector3.new(10, 0.09, 10), Transparency = 0.78})
	setP(holo:FindFirstChild("HoloRing2"), {Size = Vector3.new(7.4, 0.07, 7.4), Transparency = 0.78})
	say("2. hologram rings: ring1 10 x 0.09, ring2 7.4 x 0.07, T 0.78")
end

-- 3. lights
local nWall, nTS = 0, 0
for _, p in ipairs(LM.Lights:GetChildren()) do
	if p.Name == "PointLight" and p:IsA("BasePart") then
		local pos = p.Position
		if math.abs(pos.Y - 6) < 0.6 and math.abs(math.abs(pos.Z) - 51) < 0.6 and math.abs(pos.X) > 35 then
			local l = p:FindFirstChildWhichIsA("Light")
			if l and (l.Enabled or l:GetAttribute(ATTR)) then setP(l, {Enabled = false}); nWall += 1 end
		end
	end
end
local ts = LM:FindFirstChild("TimesSquare")
if ts then
	for _, l in ipairs(ts:GetDescendants()) do
		if l:IsA("SurfaceLight") and (l.Enabled or l:GetAttribute(ATTR)) then setP(l, {Enabled = false}); nTS += 1 end
	end
end
say(("3. lights off: %d hub-wall PointLights behind the wall kick, %d TimesSquare SurfaceLights (0 added)"):format(nWall, nTS))

-- 4. Duels doorway streaks
local trim = LM.Hub1:FindFirstChild("H_DuelsDoor") and LM.Hub1.H_DuelsDoor:FindFirstChild("H_DuelsDoor__trim_metal")
local nTex = 0
if trim then
	for _, t in ipairs(trim:GetChildren()) do
		if t:IsA("Texture") and (t.Face == Enum.NormalId.Left or t.Face == Enum.NormalId.Right) then setP(t, {Transparency = 1}); nTex += 1 end
	end
end
say(("4. Duels doorway: %d side Textures on H_DuelsDoor__trim_metal hidden"):format(nTex))

local en = 0
for _, l in ipairs(workspace:GetDescendants()) do if l:IsA("Light") and l.Enabled then en += 1 end end
say(("instances touched (incl. re-runs) %d; enabled lights in Workspace (Edit) %d"):format(touched, en))
return table.concat(log, "\n")
