"""MapAudit (roblox_kits/checks/audit/MapAudit.lua, the code run_checks.py --map runs) on the built Warehouse 2, plus the two
checks MapAudit can't make on this map, a hall sky sweep and an enclosure flood test.

    python tools/wh2_audit.py            (starts Play for pass 2 + sweeps, stops it again; Studio must be in Edit)

The match place has no ServerStorage.KitChecks / KitMaps, so the kit's MapAudit source is inlined and run on Workspace.Warehouse2.
1. Edit, read-only: MapAudit.run(map) as built (opts printed). HOLE is live at the yard edges (the aprons are not tagged).
2. Play server (nothing persists): the roof proxies' CanQuery off, MapAudit.run(map, {indoor = false}) so the floor rays see the
   hall floor itself. SKY is not MapAudit's to judge here: the yards are open-air by design and every art part is CanQuery off,
   so MapAudit's SKY (indoor = true) would count the yards and the whole drawn roof as holes. Instead:
3. Hall sky sweep (Play server): every art part CanQuery on for the sweep; from every hall floor cell (1-stud grid, h 3) a ray
   straight up must hit the drawn roof (sheet, frame, purlin, lamp, ridge) or a skylight's glass: "nothing" = a hole to the sky.
4. Enclosure flood (Play server): a 1-stud flood fill from spawn A over cells a body can stand in (floor found by a down ray on
   the gameplay layer; blocked if a colliding part taller than a hop + step (3.5 above the cell's floor) overlaps the body
   column). Every reached cell must lie inside the hall or a yard (e +-40.5 by n +-57, or e +-24.8 by n up to +-79.3).
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wh2_mcp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(os.path.expanduser("~"), "Documents", "roblox_kits", "checks", "audit", "MapAudit.lua")

PASS1 = r'''
local map = workspace.Warehouse2
local r = MapAudit.run(map, { indoor = false })
r.opts = "indoor=false (yards are open-air; see the hall sky sweep)"
return game:GetService("HttpService"):JSONEncode(r)
'''

PASS2 = r'''
local map = workspace.Warehouse2
local HS = game:GetService("HttpService")
local O = map:GetAttribute("PlanOrigin") or Vector3.new(-84.2, 0.4, -300)
local out = {}
-- 2. roof proxies out of the rays (Play: not saved)
for _, p in map.CollisionProxies:GetChildren() do if p.Name:match("^COLP_Ceiling") then p.CanQuery = false end end
out.roofLifted = MapAudit.run(map, { indoor = false })
for _, p in map.CollisionProxies:GetChildren() do if p.Name:match("^COLP_Ceiling") then p.CanQuery = true end end
-- 3. hall sky sweep: art queryable for the sweep
for _, d in map.Visuals:GetDescendants() do if d:IsA("BasePart") then d.CanQuery = true end end
local inc = RaycastParams.new()
inc.FilterType = Enum.RaycastFilterType.Include
inc.FilterDescendantsInstances = { map.Visuals, map.Cover }
local pieces = {}
for _, p in map.CollisionProxies:GetChildren() do if p.Name:match("^COLP_[PCWL]%d") then table.insert(pieces, p) end end
local function inPiece(v)
	for _, p in pieces do
		local l = p.CFrame:PointToObjectSpace(v)
		if math.abs(l.X) <= p.Size.X / 2 and math.abs(l.Z) <= p.Size.Z / 2 and math.abs(l.Y) <= p.Size.Y / 2 then return true end
	end
	return false
end
local sky = { roof = 0, skylight = 0, glazing = 0, lamp = 0, hole = 0, cells = 0, holes = {} }
for e = -40, 40, 1 do
	for n = -56.5, 56.5, 1 do
		local at = O + Vector3.new(-e, 3, n)
		if not inPiece(at) then
			sky.cells += 1
			local hit = workspace:Raycast(at, Vector3.new(0, 60, 0), inc)
			if not hit then
				sky.hole += 1
				if #sky.holes < 20 then table.insert(sky.holes, { e, n }) end
			elseif hit.Instance.Name == "RoofSkylight" then sky.skylight += 1
			elseif hit.Instance.Name:match("Glazing") then sky.glazing += 1
			elseif hit.Instance:FindFirstAncestor("Lamps") then sky.lamp += 1
			else sky.roof += 1 end
		end
	end
end
out.sky = sky
for _, d in map.Visuals:GetDescendants() do if d:IsA("BasePart") then d.CanQuery = false end end
-- 4. enclosure flood from spawn A
local floorP = RaycastParams.new()
floorP.FilterType = Enum.RaycastFilterType.Include
floorP.FilterDescendantsInstances = { map.CollisionProxies, map.CamSkin, map.Props, map.Shootables }
local solids = {}
for _, root in { map.CollisionProxies, map.CamSkin, map.Bounds, map.Props, map.Shootables } do
	for _, d in root:GetDescendants() do if d:IsA("BasePart") and d.CanCollide then table.insert(solids, d) end end
end
local ov = OverlapParams.new()
ov.FilterType = Enum.RaycastFilterType.Include
ov.FilterDescendantsInstances = solids
local function standable(e, n)
	local top = O + Vector3.new(-e, 16, n) -- under the roof proxies (eaves 18); nothing reachable is taller than 11.2
	local hit = workspace:Raycast(top, Vector3.new(0, -30, 0), floorP)
	if not hit then return nil, "void" end
	local fy = hit.Position.Y
	if fy - O.Y > 3.5 then return nil, "top of " .. hit.Instance.Name end -- a top nobody can reach (hop 2.2 + step)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(-e + O.X, fy + 2.75, n + O.Z), Vector3.new(1.6, 4.5, 1.6), ov)
	for _, p in parts do
		if p.Position.Y + p.Size.Y / 2 > fy + 0.6 then return nil, "blocked" end
	end
	return fy
end
local seen, queue, reached = {}, { { -31, -50 } }, 0
local box = { e0 = 1e9, e1 = -1e9, n0 = 1e9, n1 = -1e9 }
local outside = {}
seen["-31,-50"] = true
local head = 1
while head <= #queue and reached < 40000 do
	local c = queue[head]; head += 1
	if standable(c[1], c[2]) then
		reached += 1
		box.e0 = math.min(box.e0, c[1]); box.e1 = math.max(box.e1, c[1]); box.n0 = math.min(box.n0, c[2]); box.n1 = math.max(box.n1, c[2])
		local inHall = math.abs(c[1]) <= 40.5 and math.abs(c[2]) <= 57
		local inYard = math.abs(c[1]) <= 24.8 and math.abs(c[2]) <= 79.3
		if not (inHall or inYard) and #outside < 20 then table.insert(outside, c) end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local k = (c[1] + d[1]) .. "," .. (c[2] + d[2])
			if not seen[k] then seen[k] = true; table.insert(queue, { c[1] + d[1], c[2] + d[2] }) end
		end
	end
end
out.flood = { reached = reached, bbox = box, outside = outside, capped = reached >= 40000 }
return HS:JSONEncode(out)
'''


def main():
    src = open(KIT, encoding="utf-8").read()
    src = src[:src.rindex("return MapAudit")]
    o1 = wh2_mcp.lua(src + PASS1, "Edit")
    r1 = json.loads(o1[o1.index("{"):o1.rindex("}") + 1])
    print(wh2_mcp.call("start_stop_play", {"is_start": True}).strip())
    try:
        o2 = wh2_mcp.lua(src + PASS2, "Server")
        r2 = json.loads(o2[o2.index("{"):o2.rindex("}") + 1])
    finally:
        print(wh2_mcp.call("start_stop_play", {"is_start": False}).strip())
    bad = 0
    for k, r in (("built (Edit)", r1), ("roof proxies lifted (Play)", r2["roofLifted"])):
        print(f"MAP AUDIT Warehouse2 [{k}] opts indoor=false: {r['fails']} FAIL, {r['warns']} WARN  stats {r['stats']}")
        for f in r["findings"]:
            print(f"  {f['level']} {f['code']} {f['where']}: {f['message']}")
        bad += r["fails"]
    s = r2["sky"]
    print(f"HALL SKY SWEEP: {s['cells']} cells: roof {s['roof']}, skylight glass {s['skylight']}, lamps {s['lamp']}, side glazing {s['glazing']}, HOLES {s['hole']} {s['holes']}")
    f = r2["flood"]
    print(f"ENCLOSURE FLOOD from spawn A: {f['reached']} standable cells reached, extent e {f['bbox']['e0']}..{f['bbox']['e1']} n {f['bbox']['n0']}..{f['bbox']['n1']}; "
          f"outside the hall + yards: {len(f['outside'])} {f['outside']}{' (CAPPED)' if f['capped'] else ''}")
    bad += s["hole"] + len(f["outside"]) + (1 if f["capped"] else 0)
    json.dump({"built": r1, **r2}, open(os.path.join(ROOT, "notes", "warehouse2_audit.json"), "w"), indent=1)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
