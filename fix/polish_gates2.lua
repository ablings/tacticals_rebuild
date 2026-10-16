-- polish_gates2.lua : gate corridors review fix (fresh-eyes review, notes/review_gates.md). Tacticals_rebuild.rbxl ONLY.
-- The N corridor's features-kit F_JunctionBox (west wall, z 54, y 5..8.2) is non-colliding and stands 0.34 proud of the
-- bulkhead ribs, so a player hugging the wall walks through it. Its body (dark_metal) and lid trim (trim_light) now collide
-- with a Box hull: inner face x -4.45, so the collidable corridor width stays 9.60 (the ribs set the same minimum).
-- Run after polish_gates.lua. Idempotent and UNDO-able: originals in attribute PolishGates2_Orig.
-- UNDO: python tools/run_luau.py fix/polish_gates2.lua UNDO
local UNDO = false --@UNDO

local HttpService = game:GetService("HttpService")
local LM = workspace.LobbyMap
local ATTR = "PolishGates2_Orig"

local jb
for _, m in ipairs(LM.IndustrialProps:GetChildren()) do
	if m.Name == "F_JunctionBox" then
		local p = m:GetPivot().Position
		if math.abs(p.X) < 6 and p.Z > 48 and p.Z < 62 then jb = m end
	end
end
assert(jb, "N corridor F_JunctionBox not found")

local n = 0
for _, name in ipairs({"F_JunctionBox__dark_metal", "F_JunctionBox__trim_light"}) do
	local p = jb:FindFirstChild(name)
	if p then
		local s = p:GetAttribute(ATTR)
		if UNDO then
			if s then
				local o = HttpService:JSONDecode(s)
				p.CanCollide = o.CanCollide
				p.CanQuery = o.CanQuery
				p.CollisionFidelity = Enum.CollisionFidelity[o.CollisionFidelity]
				p:SetAttribute("NotCover", o.NotCover)
				p:SetAttribute(ATTR, nil); n += 1
			end
		else
			if not s then
				p:SetAttribute(ATTR, HttpService:JSONEncode({CanCollide = p.CanCollide, CanQuery = p.CanQuery, CollisionFidelity = p.CollisionFidelity.Name, NotCover = p:GetAttribute("NotCover")}))
			end
			p.CollisionFidelity = Enum.CollisionFidelity.Box
			p.CanCollide = true
			p.CanQuery = true
			p:SetAttribute("NotCover", true)
			n += 1
		end
	end
end
return (UNDO and "UNDO polish_gates2: restored " or "polish_gates2: junction box colliding parts ") .. n
