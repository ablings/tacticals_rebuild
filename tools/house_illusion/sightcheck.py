"""Run tools/house_illusion/sightcheck.lua for every clear window (standing + crouched eye) of notes/maps/house_layout.json.
python tools/house_illusion/sightcheck.py [Edit|Server]   (Studio by HOUSE_STUDIO window name, via tools/house_mcp.py)"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import house_mcp  # noqa: E402
OX, OY, OZ = -650.0, 1.2, -450.0
OUT = {'W_S_G': (0, -1), 'W_S_U': (0, -1), 'W_N_G': (0, 1), 'W_N_U': (0, 1), 'W_W': (-1, 0), 'W_E_G': (1, 0), 'W_E_U': (1, 0), 'W_U4': (0, 1), 'I_X9_U': (1, 0)}
L = json.load(open(os.path.join(HERE, "..", "..", "notes", "maps", "house_layout.json")))
rows = []
for o in L["openings"]:
    if o.get("kind") != "window" or o.get("frosted") or o.get("interior"):
        continue
    fl = 0 if o["storey"] == "G" else 14
    mid = (o["a"] + o["b"]) / 2
    ox, oy = OUT[o["wall"]]
    wx, wy = (mid, o["line"]) if o["axis"] == "x" else (o["line"], mid)
    for tag, h in (("st", 4.6), ("cr", 3.3)):
        ex, ey = wx + ox * 0.6, wy + oy * 0.6  # just outside the glass
        # world: x = OX + plan x, z = OZ - plan y; outward plan (ox, oy) -> world (ox, -oy)
        rows.append('{"%s_%s", %.2f, %.2f, %.2f, %d, %d}' % (o["id"], tag, OX + ex, OY + fl + h, OZ - ey, ox, -oy))
src = open(os.path.join(HERE, "sightcheck.lua"), encoding="utf-8").read()
src = src.replace("local WINDOWS = {} --@WINDOWS", "local WINDOWS = {" + ",\n".join(rows) + "}")
print(house_mcp.lua(src, sys.argv[1] if len(sys.argv) > 1 else "Edit"))
