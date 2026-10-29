"""Generate fix/map_house.lua from tools/house_installer.lua + notes/maps/house_layout.json (+ room lights and the map's
lighting, defined here). Never hand-edit fix/map_house.lua.
    python tools/house_lua.py"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
L = json.load(open(os.path.join(ROOT, "notes", "maps", "house_layout.json")))
TPL = open(os.path.join(HERE, "house_installer.lua"), encoding="utf-8").read()
OUT = os.path.join(ROOT, "fix", "map_house.lua")

# the map's daylight (MapInfo.Lighting, applied by RoundManager when House wins the vote) --@LIGHTING
# 1965 test-site restyle (art/house/v2, vault Map Styles / Test Site House "Lighting and window light"): a hazy warm desert
# afternoon, inside clearly darker than the bright windows, warm and slightly desaturated. Clean modern values (v1) kept below.
LIGHTING_V1 = dict(clock=16.2, latitude=35, bright=2.6, exposure=0, ambient="112, 110, 106", outdoor="128, 126, 122",
                   diffuse=0.45, specular=0.25, density=0.24, offset=0.1, haze=1.2, glare=0.1, atmoColor="205, 214, 224",
                   decay="150, 160, 176", gradeBright=0, contrast=0.08, saturation=-0.04, tint="255, 250, 244", bloom=0.3,
                   bloomSize=22, threshold=2.0)
LIGHTING = dict(clock=15.5, latitude=35, bright=2.8, exposure=0, ambient="86, 80, 72", outdoor="170, 160, 140",
                diffuse=0.4, specular=0.2, density=0.35, offset=0.1, haze=2.5, glare=0.1, atmoColor="214, 196, 166",
                decay="150, 120, 90", gradeBright=0, contrast=0.06, saturation=-0.14, tint="255, 246, 228", bloom=0.25,
                bloomSize=20, threshold=2.2)
# room looks of the 1965 kit (art/house/v2/house_furniture.json variant_map: layout id -> model, same collision box)
V2 = os.path.join(ROOT, "art", "house", "v2", "house_furniture.json")
VARIANTS = json.load(open(V2))["variant_map"] if os.path.exists(V2) else {}
WARM = [255, 238, 214]
LAMP = [255, 206, 158]


def room_lights():
    out = []
    for r in L["rooms"]:
        if r["id"] in ("EN",):
            continue
        st = L["storeys"][r["storey"]]
        ceil = st["ceiling"] if r["id"] != "FY" else L["storeys"]["U"]["ceiling"]
        h = ceil - st["floor"]
        for qi, q in enumerate(r["rects"]):
            w, d = q["x1"] - q["x0"], q["y1"] - q["y0"]
            nx, ny = max(1, round(w / 20)), max(1, round(d / 20))
            if r["id"] in ("MB", "BR2", "BR3"): nx, ny = 2, 1   # bedrooms: two fixtures (spot + fill each), light budget   # ~1 per 400 sq studs (light budget ~40: style card)
            if w < 6 or d < 6:
                continue
            for i in range(nx):
                for j in range(ny):
                    x = q["x0"] + w * (i + 0.5) / nx
                    y = q["y0"] + d * (j + 0.5) / ny
                    out.append(dict(id=f"L_{r['id']}_{qi}_{i}{j}", kind="down", x=round(x, 2), y=round(y, 2), z=round(ceil - 0.3, 2),
                                    angle=(150 if r["id"] in ("MB", "BR2", "BR3", "LR", "CH") else 120), range=round(h + 12, 1), bright=(5.0 if r["id"] in ("MB", "BR2", "BR3") else (4.2 if r["id"] in ("LR", "CH") else 2.4)),  # LR / CH: dark 1965 coffee paint + fieldstone rendered near-black (grade 1965 r1)
                                    fill=(0.9 if r["id"] in ("MB", "BR2", "BR3") else 0),
                                    color=WARM, shadows=False))  # bedrooms brighter (Edward 2026-10-28)
    # the foyer plant read as a dark silhouette: a warm uplight in its planter (Edward 2026-10-28)
    out.append(dict(id="L_FY_PlantUp", kind="point", x=4.5, y=-14.5, z=3.8, range=11, bright=1.2, color=LAMP, shadows=False))
    for d in L["dressing"]:
        lift = {"H_FloorLamp": 5.3, "H_PendantLamp": -3.4}.get(d["model"])   # table lamps: art only (light budget)
        if lift is None:
            continue
        out.append(dict(id="L_" + d["id"], kind="point", x=d["x"], y=d["y"], z=round(d["z"] + lift, 2), range=12, bright=0.7,
                        color=LAMP, shadows=False))
    return out


def lua(v, ind=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k}={lua(x)}" for k, x in v.items()) + "}"
    raise TypeError(type(v))


KEEP_PART = ("id", "shape", "x0", "x1", "y0", "y1", "z0", "z1", "role", "cover", "model", "foot_y", "top_y", "cx", "cy", "w", "d", "yaw")
parts = [{k: p[k] for k in KEEP_PART if k in p} for p in L["parts"]]
windows = [dict(id=o["id"], wall=o["wall"], axis=o["axis"], a=o["a"], b=o["b"], z0=o["z0"], z1=o["z1"],
                interior=bool(o.get("interior")), frosted=bool(o.get("frosted"))) for o in L["openings"] if o["kind"] == "window"]
doors = [{k: d[k] for k in ("id", "model", "state", "locked", "hinge", "leaf", "z0", "open_deg", "closed_dir", "open_dir_side",
                            "angle_deg", "leaf_yaw_deg")} for d in L["doors"]]
furniture = [{k: f[k] for k in ("id", "room", "model", "cover", "x0", "x1", "y0", "y1", "z0", "z1", "face")} for f in L["furniture"]]
dressing = [{k: d[k] for k in ("id", "model", "room", "x", "y", "z", "face", "size", "hang")} for d in L["dressing"]]
spawns = {t: dict(x=s["x"], y=s["y"], z=s["z"], look=s["look"]) for t, s in L["spawns"].items()}
lights = room_lights()

lines = ["local L = { -- generated by tools/house_lua.py from notes/maps/house_layout.json (never hand-edit)",
         f"\tversion = {L['version']},",
         f"\tshell = {lua(L['shell'])},",
         f"\tspawns = {lua(spawns)},",
         f"\tlighting = {lua(LIGHTING)},",
         f"\tvariants = {lua(VARIANTS)},",
         "\tparts = {"] + [f"\t\t{lua(p)}," for p in parts] + ["\t},", "\twindows = {"] + [f"\t\t{lua(w)}," for w in windows] + \
        ["\t},", "\tdoors = {"] + [f"\t\t{lua(d)}," for d in doors] + ["\t},", "\tfurniture = {"] + [f"\t\t{lua(f)}," for f in furniture] + \
        ["\t},", "\tdressing = {"] + [f"\t\t{lua(d)}," for d in dressing] + ["\t},", "\tlights = {"] + [f"\t\t{lua(l)}," for l in lights] + \
        ["\t},", "}"]
code = TPL.replace("--@@LAYOUT", "-- @LAYOUT BEGIN\n" + "\n".join(lines) + "\n-- @LAYOUT END")
open(OUT, "w", encoding="utf-8", newline="\n").write(code)
print("wrote", OUT, len(code), "chars;", len(parts), "parts,", len(windows), "windows,", len(doors), "doors,", len(furniture),
      "furniture,", len(dressing), "dressing,", len(lights), "lights")
