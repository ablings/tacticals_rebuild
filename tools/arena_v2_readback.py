"""Read the BUILT Arena back from a Studio place and turn it into a layout JSON the plan checker can run on.

    python tools/arena_v2_readback.py <studio_id> [<lua path to the map model>]
        default model path: workspace.Arena (the match place). Lobby source: game.ServerStorage._DuelSource.Arena.Arena

Writes out/arena_v2/built_layout.json (the plan JSON with every piece's parts and ramp replaced by what is in Studio) and
prints a part-by-part diff against notes/maps/arena_v2_layout.json (tolerance 0.001), plus build facts the checker can't see:
anchored / collide / NotCover per role, axis alignment, the 0.5 grid, spawn markers. Exit 1 on any difference.
Then:  python -I tools/arena_v2_check.py out/arena_v2/built_layout.json built
"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lookdev"))
from run import call  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PLAN = json.load(open(os.path.join(ROOT, "notes", "maps", "arena_v2_layout.json"), encoding="utf-8"))
OUT = os.path.join(ROOT, "out", "arena_v2")

LUA = r'''
local HS = game:GetService("HttpService")
local map = %s
local ORIGIN, FT = Vector3.new(-600, 0, 0), 0.6
local out = { parts = {}, other = {}, spawns = {} }
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") then
		local cf, s = p.CFrame, p.Size
		local axis = true
		for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
			if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.999 then axis = false end
		end
		local h = cf:VectorToWorldSpace(s / 2)
		h = Vector3.new(math.abs(h.X), math.abs(h.Y), math.abs(h.Z))
		local lo, hi = cf.Position - h - ORIGIN, cf.Position + h - ORIGIN
		local rec = { name = p.Name, class = p.ClassName, folder = p.Parent.Name, piece = p:GetAttribute("PieceId"), kind = p:GetAttribute("Kind"),
			role = p:GetAttribute("Role"), side = p:GetAttribute("Side"), notCover = p:GetAttribute("NotCover") == true,
			anchored = p.Anchored, collide = p.CanCollide, query = p.CanQuery, touch = p.CanTouch, transparency = p.Transparency, axis = axis,
			x0 = r3(lo.X), x1 = r3(hi.X), y0 = r3(-hi.Z), y1 = r3(-lo.Z), z0 = r3(lo.Y - FT), z1 = r3(hi.Y - FT),
			textures = #p:GetChildren(), material = p.Material.Name, color = { math.floor(p.Color.R * 255 + 0.5), math.floor(p.Color.G * 255 + 0.5), math.floor(p.Color.B * 255 + 0.5) } }
		if p:IsA("WedgePart") then
			-- low end = the LookVector side (front), high end = the back
			local lv = cf.LookVector
			local foot = cf.Position + lv * s.Z / 2 - ORIGIN
			local top = cf.Position - lv * s.Z / 2 - ORIGIN
			rec.ramp = { foot = { r3(foot.X), r3(-foot.Z) }, top = { r3(top.X), r3(-top.Z) }, width = r3(s.X), rise = r3(s.Y), run = r3(s.Z),
				highY = r3(cf:PointToWorldSpace(Vector3.new(0, s.Y / 2, s.Z / 2)).Y - FT) }
		end
		if p.Parent.Name == "MatchSpawns" then
			local lv = cf.LookVector
			table.insert(out.spawns, { name = p.Name, x = r3(cf.Position.X - ORIGIN.X), y = r3(-(cf.Position.Z - ORIGIN.Z)), z = r3(cf.Position.Y - FT),
				face = { r3(lv.X), r3(-lv.Z) }, right = { r3(cf.RightVector.X), r3(-cf.RightVector.Z) } })
		end
		table.insert(rec.piece and out.parts or out.other, rec)
	end
end
out.attrs = { LayoutVersion = map:GetAttribute("LayoutVersion"), Surface = map:GetAttribute("Surface") }
return HS:JSONEncode(out)
'''


def main():
    sid = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) > 2 else "workspace.Arena"
    raw = call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": LUA % path})
    data = json.loads(raw[raw.index("{"):raw.rindex("}") + 1])
    os.makedirs(OUT, exist_ok=True)
    json.dump(data, open(os.path.join(OUT, "built_raw.json"), "w"), indent=1)
    bad = []
    by_piece = {}
    for rec in data["parts"]:
        by_piece.setdefault(rec["piece"], []).append(rec)
    built = json.loads(json.dumps(PLAN))
    for p in built["pieces"]:
        recs = by_piece.pop(p["id"], [])
        blocks = [r for r in recs if r["class"] == "Part"]
        wedges = [r for r in recs if r["class"] == "WedgePart"]
        new_parts = [{k: r[k] for k in ("x0", "x1", "y0", "y1", "z0", "z1")} | {"role": r["role"]} for r in blocks]
        # diff (order-free): every plan part must have a built twin within 0.001
        key = lambda q: (q["role"], *(round(q[k], 3) for k in ("x0", "x1", "y0", "y1", "z0", "z1")))
        want, got = sorted(map(key, p["parts"])), sorted(map(key, new_parts))
        if want != got:
            bad.append(f"{p['id']}: plan {set(want) - set(got)} built {set(got) - set(want)}")
        p["parts"] = new_parts
        if p.get("ramp"):
            if len(wedges) != 1:
                bad.append(f"{p['id']}: {len(wedges)} ramp wedges")
            else:
                w = wedges[0]["ramp"]
                pr = p["ramp"]
                for k in ("foot", "top"):
                    if max(abs(a - b) for a, b in zip(w[k], pr[k])) > 1e-3: bad.append(f"{p['id']} ramp {k}: plan {pr[k]} built {w[k]}")
                for k in ("width", "rise", "run"):
                    if abs(w[k] - pr[k]) > 1e-3: bad.append(f"{p['id']} ramp {k}: plan {pr[k]} built {w[k]}")
                if abs(w["highY"] - pr["rise"]) > 1e-3: bad.append(f"{p['id']} ramp slope rises the wrong way (high end at {w['highY']})")
                p["ramp"] = dict(pr, foot=w["foot"], top=w["top"], width=w["width"], rise=w["rise"], run=w["run"])
        for r in recs:
            if not r["anchored"] or not r["collide"] or r["transparency"] >= 1:
                bad.append(f"{r['name']}: anchored {r['anchored']} collide {r['collide']} transparency {r['transparency']}")
            if not r["axis"] and r["class"] == "Part":
                bad.append(f"{r['name']}: not axis-aligned")
            for k in ("x0", "x1", "y0", "y1"):
                if abs(r[k] * 2 - round(r[k] * 2)) > 1e-3: bad.append(f"{r['name']}: {k} {r[k]} off the 0.5 grid")
            want_nc = r["role"] in ("deck", "curb", "ramp")
            if r["notCover"] != want_nc:
                bad.append(f"{r['name']}: NotCover {r['notCover']} (want {want_nc})")
    for pid in by_piece:
        bad.append(f"built piece not in the plan: {pid}")
    # spawns
    sp = {s["name"]: s for s in data["spawns"]}
    for team in ("A", "B"):
        s, plan = sp.get("Spawn" + team), PLAN["spawns"][team]
        if not s:
            bad.append(f"Spawn{team} missing"); continue
        if abs(s["x"] - plan["spots"][0][0]) > 1e-3 or abs(s["y"] - plan["spots"][0][1]) > 1e-3:
            bad.append(f"Spawn{team} at {s['x']},{s['y']} (plan {plan['spots'][0]})")
        if abs(s["face"][0] - plan["face"][0]) > 1e-3 or abs(s["face"][1] - plan["face"][1]) > 1e-3:
            bad.append(f"Spawn{team} faces {s['face']} (plan {plan['face']})")
        # RoundManager: teammate k at marker * CFrame.new(side * step, 3, 0): slots 2 / 3 at -4 / +4 along the right vector
        spots = [[round(s["x"] + d * s["right"][0], 3), round(s["y"] + d * s["right"][1], 3)] for d in (0, -4, 4)]
        if sorted(map(tuple, spots)) != sorted(map(tuple, plan["spots"])):
            bad.append(f"Spawn{team} team spots {spots} (plan {plan['spots']})")
    json.dump(built, open(os.path.join(OUT, "built_layout.json"), "w"), indent=1)
    roles = {}
    for r in data["parts"]:
        roles.setdefault(r["role"], set()).add(tuple(r["color"]))
    print("built parts", len(data["parts"]), "| other parts", len(data["other"]), "| map attrs", data["attrs"])
    print("colours by role", {k: sorted(v) for k, v in roles.items()})
    print("other", [(o["name"], o["notCover"], o["collide"]) for o in data["other"]])
    print("DIFF vs plan:", "none" if not bad else "")
    for b in bad: print("  " + b)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
