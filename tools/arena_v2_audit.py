"""MapAudit (roblox_kits/checks/audit/MapAudit.lua, the code tools/run_checks.py --map runs) on the built Arena, read-only.

    python tools/arena_v2_audit.py <studio_id> [<lua path to the map model>] [Edit|Server]

The match place has no ServerStorage.KitChecks / KitMaps, so instead of run_checks.py --map (which audits KitMaps copies) the
kit's MapAudit source is inlined and run on the map itself. Nothing is written to the place. MapAudit's SPAWN check looks for a
`Spawns` folder; the Arena's spawns are MatchSpawns.SpawnA / SpawnB plus the 2v2/3v3 teammate spots (RoundManager: marker *
CFrame.new(+-4, 3, 0)), so the same floor / headroom test is run on all six spots here.
"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lookdev"))
from run import call  # noqa: E402

KIT = os.path.join(os.path.expanduser("~"), "Documents", "roblox_kits", "checks", "audit", "MapAudit.lua")

RUNNER = r'''
local map = %s
local r = MapAudit.run(map)
-- the Arena's own spawn spots: each marker and its 2v2 / 3v3 teammate spots, same test as MapAudit's SPAWN
local ex = RaycastParams.new()
ex.FilterType = Enum.RaycastFilterType.Include
ex.FilterDescendantsInstances = { map }
local spots = 0
for _, m in (map:FindFirstChild("MatchSpawns") and map.MatchSpawns:GetChildren() or {}) do
	for _, dx in { 0, -4, 4 } do
		local p = (m.CFrame * CFrame.new(dx, 0, 0)).Position
		spots += 1
		local down = workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), ex)
		local up = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, 6, 0), ex)
		local where = m.Name .. "@" .. dx
		if not down then table.insert(r.findings, { level = "FAIL", code = "SPAWN", where = where, message = "no floor within 6 below" }) r.fails += 1 end
		if up then table.insert(r.findings, { level = "FAIL", code = "SPAWN", where = where, message = "headroom < 6 (" .. up.Instance.Name .. ")" }) r.fails += 1 end
		if down and down.Instance.Name ~= "Slab" then table.insert(r.findings, { level = "WARN", code = "SPAWN", where = where, message = "stands on " .. down.Instance.Name }) r.warns += 1 end
	end
end
r.stats.spawnSpots = spots
return game:GetService("HttpService"):JSONEncode(r)
'''


def main():
    sid = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) > 2 else "workspace.Arena"
    dm = sys.argv[3] if len(sys.argv) > 3 else "Edit"
    src = open(KIT, encoding="utf-8").read()
    src = src[:src.rindex("return MapAudit")]  # inline the module
    out = call("execute_luau", {"studio_id": sid, "datamodel_type": dm, "code": src + RUNNER % path})
    r = json.loads(out[out.index("{"):out.rindex("}") + 1])
    print(f"MAP AUDIT {path}: {r['fails']} FAIL, {r['warns']} WARN  stats {r['stats']}")
    for f in r["findings"]:
        print(f"  {f['level']} {f['code']} {f['where']}: {f['message']}")
    sys.exit(1 if r["fails"] else 0)


if __name__ == "__main__":
    main()
