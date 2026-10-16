-- polish_olive.lua : lobby-wide olive tone (overnight hub pass). Tacticals_rebuild.rbxl ONLY.
-- Problem (reviews of the Armory, Duels, Exfil, gates): the shared olive paint read LIME under Future + daylight. Measured
-- with tools/part_pixels.py in the hub: band_olive 111,114,57 rendered G/R 1.27-1.39 (77,97,50 / 64,82,44), the spawn-disc
-- centre 112,126,62 rendered 163,186,114, neon_olive 66,72,36 rendered 40,53,23 (G/R 1.33), crate_green 65,94,56 rendered
-- 27,63,42 (kelly green). The loading-screen olive 138,156,74 has G/R 1.13, B/R 0.54.
-- Fix: part colours chosen by a trial capture (several candidates on different meshes in one frame, then measured):
--   band 138,130,60   renders 110,119,56 / 78,87,40 / 69,75,35 (G/R 1.08-1.12, B/R ~0.5): olive, a little brighter
--   disc 90,96,36     (disc centre is lit by the spawn key: render ratio ~1.5 -> about 136,152,75)
--   neon 84,88,48     (neon 92,88,38 rendered 98,93,31 = khaki; 66,72,36 rendered green; 88,90,38 rendered 90,97,31 /
--                      101,107,15 = gold: Neon blue renders at ~0.4, so B is raised)
--   crate 104,88,40 / drum 100,84,38 / container 104,94,46 (sky-blue fill adds B and G: renders dark olive, not kelly)
-- Scope: the SHARED olive paint everywhere (suffixes band_olive, neon_olive, disc_center, crate_green, crate_trim,
-- drum_olive, container_olive; the features-kit Wayfinding label edge). Skipped on purpose (room-specific, already measured
-- by their own pass): anything under LobbyMap.Polish, and any part another polish pass recoloured (attribute Polish*_Orig:
-- Exfil amber, Duels cream/olive teams and dark-olive bands, gate corridors' near-black band, Armory dark-olive crates).
-- Idempotent and UNDO-able: originals stored once (typed JSON) in attribute PolishOlive_Orig.
-- UNDO: python tools/run_luau.py fix/polish_olive.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local ATTR = "PolishOlive_Orig"
local C = Color3.fromRGB

local BAND = C(138, 130, 60)
local NEON = C(84, 88, 48)
local NEON_BRIGHT = C(96, 100, 54)
local RULES = {
	band_olive = BAND,
	neon_olive = NEON,
	disc_center = C(90, 96, 36),
	crate_green = C(104, 88, 40),
	crate_trim = C(104, 88, 40),
	drum_olive = C(100, 84, 38),
	container_olive = C(104, 94, 46),
}

if UNDO then
	local n = 0
	for _, d in ipairs(LM:GetDescendants()) do
		local s = d:GetAttribute(ATTR)
		if s then
			local o = HttpService:JSONDecode(s)
			if o.Color then d.Color = Color3.new(o.Color[1], o.Color[2], o.Color[3]) end
			d:SetAttribute(ATTR, nil); n += 1
		end
	end
	return "UNDO polish_olive: restored " .. n .. " parts"
end

local function otherPass(d)
	for k, _ in pairs(d:GetAttributes()) do
		if k:match("^Polish.*_Orig") and k ~= ATTR and k ~= "PolishHub_Orig" then return k end
	end
	return nil
end
local polish = LM:FindFirstChild("Polish")
local counts, skipped = {}, {}
local function setColor(d, col, key)
	local s = d:GetAttribute(ATTR)
	if not s then
		local c = d.Color
		d:SetAttribute(ATTR, HttpService:JSONEncode({Color = {c.R, c.G, c.B}}))
	end
	d.Color = col
	counts[key] = (counts[key] or 0) + 1
end
for _, d in ipairs(LM:GetDescendants()) do
	if d:IsA("BasePart") and not (polish and d:IsDescendantOf(polish)) then
		local suf = d.Name:match("__(.+)$") or d.Name
		local col = RULES[suf]
		if not col and suf == "Edge" and d.Material == Enum.Material.Neon and d.Parent and d:IsDescendantOf(LM.Features) then
			local r, g = d.Color.R, d.Color.G
			if g > r then col = NEON_BRIGHT; suf = "wayfinding Edge" end
		end
		if col then
			local other = d:GetAttribute(ATTR) == nil and otherPass(d)
			if other then
				skipped[other] = (skipped[other] or 0) + 1
			else
				-- the features-kit Neon (88,101,48) is a brighter olive than the kit's 66,72,36: keep it a step brighter
				if suf == "neon_olive" and (d:GetAttribute(ATTR) and HttpService:JSONDecode(d:GetAttribute(ATTR)).Color[2] > 0.37 or d.Color.G > 0.37) then
					col = NEON_BRIGHT
				end
				setColor(d, col, suf)
			end
		end
	end
end
local out = {"polish_olive:"}
for k, n in pairs(counts) do table.insert(out, ("  %s %d"):format(k, n)) end
for k, n in pairs(skipped) do table.insert(out, ("  skipped (%s) %d"):format(k, n)) end
return table.concat(out, "\n")
