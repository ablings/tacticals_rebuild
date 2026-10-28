"""MapAudit (roblox_kits/checks/audit/MapAudit.lua, what run_checks.py --map runs) on the built House + HouseExterior.
The match place has no ServerStorage.KitChecks / KitMaps, so the kit's MapAudit source is inlined.
    python tools/house_audit.py [--play]
Edit pass: MapAudit.run(House) with the map's own attribute Indoor = true (SKY runs), MapAudit.run(HouseExterior) (Indoor = false).
--play: the same in a Play server (starts and stops Play), so nothing differs live.
The enclosure proof is tools/house_check.py on the read-back (3D flood over both floors: 0 cells outside) + its control."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import house_mcp  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(os.path.expanduser("~"), "Documents", "roblox_kits", "checks", "audit", "MapAudit.lua")
PASS = r'''
local map = workspace.House
local r = MapAudit.run(map)
r.opts = "map attribute Indoor = " .. tostring(map:GetAttribute("Indoor"))
local ext = workspace:FindFirstChild("HouseExterior")
local rx = ext and MapAudit.run(ext) or { fails = 0, warns = 0, findings = {}, stats = {} }
rx.opts = "exterior attribute Indoor = " .. tostring(ext and ext:GetAttribute("Indoor"))
return game:GetService("HttpService"):JSONEncode({ house = r, exterior = rx })
'''
def run(dm):
    src = open(KIT, encoding="utf-8").read()
    src = src[:src.rindex("return MapAudit")]
    o = house_mcp.lua(src + PASS, dm)
    return json.loads(o[o.index("{"):o.rindex("}") + 1])
if __name__ == "__main__":
    res = {"Edit": run("Edit")}
    if "--play" in sys.argv:
        print(house_mcp.call("start_stop_play", {"is_start": True}).strip())
        try:
            res["Play"] = run("Server")
        finally:
            print(house_mcp.call("start_stop_play", {"is_start": False}).strip())
    bad = 0
    for dm, r1 in res.items():
        for k in ("house", "exterior"):
            r = r1[k]
            print(f"MAP AUDIT [{k}, {dm}] {r.get('opts', '')}: {r['fails']} FAIL, {r['warns']} WARN  stats {r['stats']}")
            for f in r["findings"][:60]:
                print(f"  {f['level']} {f['code']} {f['where']}: {f['message']}")
            bad += r["fails"]
    json.dump(res, open(os.path.join(ROOT, "notes", "house_audit.json"), "w"), indent=1)
    sys.exit(1 if bad else 0)
