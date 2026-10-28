-- fix/house_lobby_prep.lua [HOUSE] lobby only: fold a trimmed copy of the House's exterior into its duel source, so the pad-duel
-- arena (duel_split_map ONLY='House') shows the street through the windows. Run after tools/duel_map_port.py (roots House,
-- HouseExterior) and before fix/duel_split_map.lua ONLY='House'.
-- Why trimmed: lobby arena slots are spaced by the biggest map footprint (MapRegistry.SlotSpacing); the match exterior's 1,800-stud
-- ground and 440-stud street would push every arena thousands of studs apart. Kept: the yards, fences, the houses across, behind
-- and beside, cars, trees, lamps; the ground and the street cut to 320 studs; the four far power poles dropped.
-- Idempotent (rebuilds _DuelSource.House.House.Exterior). UNDO = true removes it.
local UNDO = false --@UNDO
local src = game:GetService("ServerStorage"):FindFirstChild("_DuelSource")
src = src and src:FindFirstChild("House")
assert(src and src:FindFirstChild("House") and src:FindFirstChild("HouseExterior"), "house_lobby_prep: no _DuelSource.House.{House,HouseExterior} (run tools/duel_map_port.py first)")
local old = src.House:FindFirstChild("Exterior")
if old then old:Destroy() end
if UNDO then return "UNDO: _DuelSource.House.House.Exterior removed" end
local ext = src.HouseExterior:Clone()
ext.Name = "Exterior"
local o = src.House:GetAttribute("PlanOrigin")
local SPAN = 320
local cut, scaled = 0, 0
for _, d in ext:GetDescendants() do
	if d:IsA("BasePart") then
		local n = d.Name
		if n == "PowerPole_01" or n == "PowerPole_02" or n == "PowerPole_10" or n == "PowerPole_11" then
			d:Destroy(); cut += 1
		elseif n:match("^Ext_Ground") then
			d.Size = Vector3.new(SPAN, d.Size.Y, SPAN + 40); scaled += 1
		elseif n:match("^Ext_Street") or n == "PowerWires" then
			d.Size = Vector3.new(SPAN, d.Size.Y, d.Size.Z); scaled += 1
		end
	end
end
for _, d in ext:GetDescendants() do if d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end end
ext.Parent = src.House
local _, s = src.House:GetBoundingBox()
return ("house_lobby_prep: exterior folded in (%d far poles cut, %d ground/street pieces cut to %d); House footprint %.0f x %.0f"):format(cut, scaled, SPAN, s.X, s.Z)
