"""Warehouse 2 read-back: the BUILT gameplay layer (notes/warehouse2_dump.json, from tools/wh2_dump.lua) against the old
Warehouse's (notes/warehouse_study/warehouse_dump.json), in plan coordinates. Tolerance 0.001 studs.

    python tools/wh2_readback.py

Checks: every cover proxy (same name, plan position, size, height, collide / query / touch, invisible, no NotCover), both spawn
markers (position, facing, size), every shootable part (position, size, collide / query, attributes, tags on the models), the
camera skin (old names + rectangles, minus the ones inside the wider doors), every wall / floor / yard proxy NotCover, no art
that collides / queries / touches, the registry entry, and the old Warehouse untouched (instance count).
Exit 1 on any difference."""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = json.load(open(os.path.join(ROOT, "notes", "warehouse_study", "warehouse_dump.json"), encoding="utf-8"))
NEW = json.load(open(os.path.join(ROOT, "notes", "warehouse2_dump.json"), encoding="utf-8"))
OC = (-84.2, 0.4, 7.5)
NC = (-84.2, 0.4, -300.0)
TOL = 1e-3
OLD_WAREHOUSE_INSTANCES = 555  # sum of warehouse_classes in the study dump (2026-10-26)


def plan(p, c):
    x, y, z = p["pos"]
    return (-(x - c[0]), y - c[1], z - c[2])


errs, notes = [], []


def same(a, b, what):
    if any(abs(u - v) > TOL for u, v in zip(a, b)):
        errs.append(f"{what}: old {tuple(round(u, 3) for u in a)} new {tuple(round(v, 3) for v in b)}")


def piece(n):
    s = n[5:]
    return s[:1] in "PCWL" and s[1:].isdigit()


old_p = {p["name"]: p for p in OLD["proxies"] if piece(p["name"])}
new_p = {p["name"]: p for p in NEW["proxies"]}
for nm, o in sorted(old_p.items()):
    n = new_p.get(nm)
    if not n:
        errs.append(f"{nm}: missing"); continue
    same(plan(o, OC), plan(n, NC), nm + " position")
    same(o["size"], n["size"], nm + " size")
    if any(abs(r) > 0.01 for r in n["rot"]):
        errs.append(f"{nm}: rotated {n['rot']}")
    if not (n["collide"] and n["query"] and n.get("touch", True)) or n["transp"] != 1:
        errs.append(f"{nm}: flags collide {n['collide']} query {n['query']} touch {n.get('touch')} transp {n['transp']}")
    if (n["attrs"] or {}).get("NotCover"):
        errs.append(f"{nm}: NotCover set on a cover piece")
extra_pieces = [k for k in new_p if piece(k) and k not in old_p]
if extra_pieces:
    errs.append(f"new cover pieces not in the old map: {extra_pieces}")
notes.append(f"cover pieces: {len(old_p)} compared")

for o in OLD["spawns"]:
    n = next((s for s in NEW["spawns"] if s["name"] == o["name"]), None)
    if not n:
        errs.append(o["name"] + ": missing"); continue
    same(plan(o, OC), plan(n, NC), o["name"] + " position")
    same(o["size"], n["size"], o["name"] + " size")
    d = (n["rot"][1] - o["rot"][1] + 180) % 360 - 180
    if abs(d) > 0.01:
        errs.append(f"{o['name']}: facing old {o['rot'][1]:.3f} new {n['rot'][1]:.3f}")
notes.append(f"spawns: {len(OLD['spawns'])} compared")

key = lambda p: (p["parent"], p["name"], round(plan(p, OC if p in OLD["shootables"] else NC)[1], 2))
ob = sorted(OLD["shootables"], key=lambda p: (p["parent"], p["name"], round(p["pos"][1], 2), round(p["pos"][0], 2)))
nb = sorted(NEW["shootables"], key=lambda p: (p["parent"], p["name"], round(p["pos"][1], 2), round(p["pos"][0], 2)))
if len(ob) != len(nb):
    errs.append(f"shootable parts: old {len(ob)} new {len(nb)}")
for o, n in zip(ob, nb):
    tag = f"{o['parent']}.{o['name']}"
    same(plan(o, OC), plan(n, NC), tag + " position")
    same(o["size"], n["size"], tag + " size")
    if (o["collide"], o["query"]) != (n["collide"], n["query"]):
        errs.append(f"{tag}: collide/query old {(o['collide'], o['query'])} new {(n['collide'], n['query'])}")
    if (o["attrs"] or {}) != (n["attrs"] or {}):
        errs.append(f"{tag}: attributes old {o['attrs']} new {n['attrs']}")
for m, v in NEW["shootableModels"].items():
    want = "FireBarrel" if m.startswith("FireBarrel") else "SteamValve"
    if want not in v["tags"] or v["attrs"].get("Shootable") != want:
        errs.append(f"{m}: tags {v['tags']} attrs {v['attrs']}")
notes.append(f"shootables: {len(nb)} parts in {len(NEW['shootableModels'])} models compared")

old_sk = {c["name"]: c for c in OLD["camskin"]}
new_sk = {c["name"]: c for c in NEW["camskin"]}
dropped = []
for nm, o in sorted(old_sk.items()):
    n = new_sk.get(nm)
    if not n:
        dropped.append(nm); continue
    po, pn = plan(o, OC), plan(n, NC)
    same((po[0], po[2]), (pn[0], pn[2]), nm + " plan position")
    same((o["size"][0], o["size"][2]), (n["size"][0], n["size"][2]), nm + " plan size")
for nm in dropped:  # only the ones inside the wider (20) door openings may go
    o = old_sk[nm]; e = plan(o, OC)[0]; w = o["size"][0]
    if not ("_N_" in nm or "_S_" in nm) or e - w / 2 > 10.6 or e + w / 2 < -10.6:
        errs.append(f"{nm}: camera skin dropped outside the door zone")
notes.append(f"camera skin: {len(new_sk)} kept, {len(dropped)} dropped inside the new doors ({', '.join(dropped)})")

for p in NEW["proxies"]:
    nm = p["name"]
    if piece(nm):
        continue
    if not (p["attrs"] or {}).get("NotCover"):
        errs.append(f"{nm}: wall / floor / yard proxy without NotCover")
    if not (p["collide"] and p["query"]) or p["transp"] != 1:
        errs.append(f"{nm}: flags {p['collide']} {p['query']} {p['transp']}")
for p in NEW["bounds"]:
    if not p["collide"] or p["query"] or p["transp"] != 1:
        errs.append(f"{p['name']}: bound flags collide {p['collide']} query {p['query']}")
for p in NEW["props"]:
    if p["name"].startswith("PCOL_") and (not p["collide"] or p["query"]):
        errs.append(f"{p['name']}: prop blocker flags")
if NEW["art"]["colliding"]:
    errs.append(f"art that collides / queries / touches: {NEW['art']['colliding'][:10]}")
notes.append(f"art parts: {NEW['art']['count']}, colliding / querying / touching: {len(NEW['art']['colliding'])}")
reg = NEW["registry"]
if not reg or reg["attrs"].get("DisplayName") != "Warehouse 2" or reg["attrs"].get("Modes") != "1v1" or not reg["hasInfo"]:
    errs.append(f"registry entry: {reg}")
if NEW["warehouseIntact"] != OLD_WAREHOUSE_INSTANCES:
    errs.append(f"old Warehouse instance count {NEW['warehouseIntact']} (was {OLD_WAREHOUSE_INSTANCES})")
if not NEW["mapAttrs"].get("SteamFill"):
    errs.append("Warehouse2 lacks SteamFill = true")
notes.append(f"old Warehouse: {NEW['warehouseIntact']} instances (study dump {OLD_WAREHOUSE_INSTANCES}); registry {reg['attrs']}")
# round 6: both doors shut, scriptable, not interactable by players; the hall is an indoor map, the yards are the exterior
doors = {d["name"]: d for d in NEW.get("doors", [])}
for nm in ("Door_S", "Door_N"):
    d = doors.get(nm)
    if not d or not d["shutter"]:
        errs.append(f"{nm}: missing (Interactive.{nm}.Shutter)"); continue
    a, sh = d["attrs"], d["shutter"]
    if a.get("Open") is not False or a.get("Moving") is not False or not a.get("OpenHeight") or "Warehouse2Door" not in d["tags"]:
        errs.append(f"{nm}: state {a} tags {d['tags']}")
    if not (sh["collide"] and sh["query"]) or not (sh["attrs"] or {}).get("NotCover") or d["prompts"]:
        errs.append(f"{nm}: shutter collide {sh['collide']} query {sh['query']} NotCover {(sh['attrs'] or {}).get('NotCover')} prompts {d['prompts']}")
    if sh["size"][0] < 20 or sh["size"][1] < 14:
        errs.append(f"{nm}: shutter {sh['size']} does not fill the 20 x 14 opening")
notes.append("doors: " + ", ".join(f"{k} open={v['attrs'].get('Open')} size={[round(x, 2) for x in v['shutter']['size']]} prompts={v['prompts']}" for k, v in doors.items()))
if NEW["mapAttrs"].get("Indoor") is not True:
    errs.append("Warehouse2 lacks Indoor = true")
if not NEW.get("exteriorAttrs") or NEW["exteriorAttrs"].get("Indoor") is not False:
    errs.append(f"Warehouse2Exterior: {NEW.get('exteriorAttrs')}")

print("\n".join("- " + n for n in notes))
print(f"READ-BACK: {len(errs)} differences")
for e in errs:
    print("  " + e)
sys.exit(1 if errs else 0)
