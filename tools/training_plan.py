"""Proposed Training layout (spec v1, 2026-10-15): writes out/training_spec/plan_new.png + plan_new.json.
Coordinates: x east, z north, studs; floor top y 600. Pure data for the Step 2 builder; nothing touches Studio."""
import json, math, os, random
from collections import Counter
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "out", "training_spec")
random.seed(7)
items = []  # dict(kind, x0, z0, x1, z1, h)


def box(kind, cx, cz, sx, sz, h, **kw):
    items.append(dict(kind=kind, x0=cx - sx / 2, z0=cz - sz / 2, x1=cx + sx / 2, z1=cz + sz / 2, h=h, **kw))


A = 128                      # arena half size -> 256 x 256
GX0, GX1, GZ = 128, 352, 36  # gallery x 128..352, z -36..36
FIRE = 136                   # gallery firing line

# perimeter (east wall has the gallery mouth at z -36..36)
box("wall", 0, A + 1, 2 * A + 4, 2, 36)
box("wall", 0, -A - 1, 2 * A + 4, 2, 36)
box("wall", -A - 1, 0, 2, 2 * A + 4, 36)
box("wall", A + 1, (A + GZ) / 2 + 0.5, 2, A - GZ + 3, 36)
box("wall", A + 1, -(A + GZ) / 2 - 0.5, 2, A - GZ + 3, 36)
box("wall", (GX0 + GX1) / 2 + 1, GZ + 1, GX1 - GX0, 2, 36)
box("wall", (GX0 + GX1) / 2 + 1, -GZ - 1, GX1 - GX0, 2, 36)
box("wall", GX1 + 1, 0, 2, 2 * GZ + 4, 36)
for sx in (-1, 1):
    for sz in (-1, 1):
        box("bastion", sx * (A - 12), sz * (A - 12), 24, 24, 30, roof=True)

# spawn plaza + 16 arrivals on a ring, facing outward
box("plaza", 0, 0, 40, 40, 0.2)
arrivals = []
for i in range(16):
    a = i * math.tau / 16
    arrivals.append(dict(x=round(14 * math.cos(a), 1), z=round(14 * math.sin(a), 1), facing_deg_from_east=round(math.degrees(a), 1)))

# gallery: two lanes, sign + spot every 25 studs from the firing line
spots, signs = [], []
for k in range(1, 9):
    for lane, zc in (("N", 20), ("S", -20)):
        x = FIRE + 25 * k
        spots.append(dict(x=x, z=zc, roof=0, zone="gallery %s %d" % (lane, 25 * k)))
        signs.append(dict(x=x, z=zc + (12 if lane == "N" else -12), text=str(25 * k), zone="gallery"))
for k in range(8):
    items.append(dict(kind="band", x0=FIRE + 25 * k, z0=-GZ, x1=FIRE + 25 * (k + 1), z1=GZ, h=0.1, alt=k % 2))
box("counter", FIRE - 4, 26, 2, 20, 3.5)
box("counter", FIRE - 4, -26, 2, 20, 3.5)

# NW block maze (roofs walkable at +24)
maze = [(-112, 44, 20, 24), (-84, 40, 16, 16), (-60, 46, 24, 20), (-36, 40, 12, 16), (-108, 76, 24, 16), (-76, 80, 16, 24),
        (-48, 76, 20, 20), (-112, 108, 20, 16), (-80, 112, 24, 16), (-50, 108, 16, 20), (-30, 92, 12, 12), (-94, 60, 8, 8)]
for (x, z, sx, sz) in maze:
    box("block24", x, z, sx, sz, 24, roof=True)
for (x, z, sx, sz) in [(-98, 44, 8, 6), (-72, 43, 8, 6), (-92, 78, 8, 6), (-62, 78, 8, 6), (-96, 110, 8, 6),
                       (-112, 60, 6, 8), (-48, 61, 6, 10), (-50, 92, 8, 6)]:
    box("bridge", x, z, sx, sz, 1, top=24)
box("ramp", -24, 64, 8, 28, 24, rise="N")
for (x, z) in [(-123, 60), (-66, 30), (-30, 108), (-123, 92), (-96, 125), (-40, 125)]:
    box("truss", x, z, 2, 2, 24)

# NE towers + overwatch
for (x, z) in [(56, 96), (100, 60), (40, 52)]:
    box("tower", x, z, 8, 8, 60)
box("block24", 92, 104, 28, 24, 24, roof=True)
box("ramp", 72, 104, 10, 8, 24, rise="E")
box("block24", 64, 40, 20, 12, 24, roof=True)
box("truss", 64, 33, 2, 2, 24)
for (x, z, sx, sz) in [(32, 80, 12, 2), (80, 80, 2, 12), (110, 30, 12, 2), (36, 114, 2, 12), (76, 64, 12, 2)]:
    box("tall", x, z, sx, sz, 10)

# SW cover / peek course: rows of Tacticals cover pieces
for i, x in enumerate([-36, -56, -76, -96]):
    for j, z in enumerate([-36, -60, -84, -108]):
        kind = ["low", "low", "pillar", "low", "block", "tall"][(i + j * 2) % 6]
        sx, sz, h = dict(low=(2, 10, 3), block=(5, 5, 4), pillar=(4, 4, 12), tall=(2, 12, 10))[kind]
        box(kind, x + random.uniform(-3, 3), z + random.uniform(-4, 4), sx, sz, h)
box("tall", -116, -72, 2, 40, 10)

# SE open free-fire field: floor lines 25/50/75/100 from the plaza south edge (z -20)
for k in range(1, 5):
    items.append(dict(kind="line", x0=20, z0=-20 - 25 * k - 0.25, x1=124, z1=-20 - 25 * k + 0.25, h=0.1))
    signs.append(dict(x=122, z=-20 - 25 * k + 3, text=str(25 * k), zone="field"))
for (x, z) in [(40, -40), (76, -38), (108, -48), (52, -64), (92, -70), (34, -90), (70, -96), (112, -100), (50, -116)]:
    long_ = random.random() < .6
    box("low" if long_ else "block", x, z, 10 if long_ else 5, 2 if long_ else 5, 3)
for (x, z) in [(64, -84), (100, -118)]:
    box("tall", x, z, 12, 2, 10)

# boulevards: some low cover so the walks are not empty
for (x, z) in [(-60, 8), (-92, -10), (8, 60), (-10, 96), (10, -60), (-8, -100), (60, -6), (96, 8)]:
    horiz = abs(x) > abs(z)
    box("low", x, z, 2 if horiz else 10, 10 if horiz else 2, 3)

# arena enemy spots (part centre = surface + 3)
for (x, z, y, zone) in [
    (-100, 60, 0, "maze"), (-60, 62, 0, "maze"), (-90, 96, 0, "maze"), (-64, 94, 0, "maze"), (-38, 60, 0, "maze"),
    (-112, 44, 24, "maze roof"), (-60, 46, 24, "maze roof"), (-80, 112, 24, "maze roof"), (-48, 76, 24, "maze roof"),
    (92, 104, 24, "overwatch roof"), (64, 40, 24, "overwatch roof"), (-116, 116, 30, "bastion roof"), (116, 116, 30, "bastion roof"),
    (84, 52, 0, "towers"), (48, 112, 0, "towers"), (112, 84, 0, "towers"),
    (-46, -40, 0, "cover"), (-66, -64, 0, "cover"), (-86, -86, 0, "cover"), (-106, -40, 0, "cover"), (-110, -106, 0, "cover"), (-122, -72, 0, "cover"),
    (44, -45, 0, "field 25"), (84, -46, 0, "field 25"), (60, -70, 0, "field 50"), (100, -96, 0, "field 75"), (40, -120, 0, "field 100"), (88, -120, 0, "field 100"),
]:
    spots.append(dict(x=x, z=z, roof=y, zone=zone))

cnt = Counter(i["kind"] for i in items)
json.dump(dict(arena=dict(x=[-A, A], z=[-A, A]), gallery=dict(x=[GX0, GX1], z=[-GZ, GZ], fire_line_x=FIRE), floor_top=600,
               roof_top=624, items=items, arrivals=arrivals, enemy_spots=spots, signs=signs, counts=dict(cnt)),
          open(os.path.join(OUT, "plan_new.json"), "w"), indent=1)

# ---------------------------------------------------------------- draw
S, M = 2, 50
W = (GX1 + 8 + A + 8) * S + 2 * M + 60
H = (2 * A + 8) * S + 2 * M + 170


def P(x, z):
    return (M + (x + A + 4) * S, M + 20 + (A + 4 - z) * S)


im = Image.new("RGB", (int(W), int(H)), (24, 26, 24))
d = ImageDraw.Draw(im)
try:
    F = ImageFont.truetype("arialbd.ttf", 15); f = ImageFont.truetype("arial.ttf", 12); FT = ImageFont.truetype("arialbd.ttf", 19)
except OSError:
    F = f = FT = ImageFont.load_default()


def rect(i, fill, outline=None):
    d.rectangle([P(i["x0"], i["z1"]), P(i["x1"], i["z0"])], fill=fill, outline=outline)


d.rectangle([P(-A, A), P(A, -A)], fill=(200, 196, 186))
d.rectangle([P(GX0, GZ), P(GX1, -GZ)], fill=(200, 196, 186))
zones = [((-A, 20, -20, A), "NW  BLOCK MAZE + ROOF DECK (+24)", (190, 186, 176)), ((20, 20, A, A), "NE  TOWERS + OVERWATCH", (192, 192, 178)),
         ((-A, -A, -20, -20), "SW  COVER / PEEK COURSE", (185, 190, 176)), ((20, -A, A, -20), "SE  OPEN FREE-FIRE FIELD", (196, 198, 184))]
for (x0, z0, x1, z1), name, col in zones:
    d.rectangle([P(x0, z1), P(x1, z0)], fill=col)
for g in range(-125, GX1 + 1, 25):  # 25-stud reference grid
    if g <= A:
        d.line([P(g, A), P(g, -A)], fill=(178, 174, 164))
    else:
        d.line([P(g, GZ), P(g, -GZ)], fill=(178, 174, 164))
for g in range(-125, A + 1, 25):
    d.line([P(-A, g), P(A, g)], fill=(178, 174, 164))
for i in items:
    if i["kind"] == "band":
        rect(i, (167, 173, 152) if i["alt"] else (188, 190, 172))
for i in items:
    if i["kind"] == "plaza":
        rect(i, (138, 156, 74), (107, 122, 58))
    elif i["kind"] == "line":
        rect(i, (107, 122, 58))
for (x0, z0, x1, z1), name, col in zones:
    zl = z0 + 9 if z0 > 0 else z1 - 1
    d.text((P(x0 + 4, zl)[0], P(x0, zl)[1]), name, fill=(60, 64, 52), font=F)
STY = dict(wall=((10, 12, 10), None), bastion=((86, 88, 84), (10, 12, 10)), block24=((120, 122, 116), (40, 42, 38)),
           tower=((60, 62, 58), (10, 12, 10)), tall=((96, 98, 92), None), pillar=((96, 98, 92), None), low=((150, 150, 142), (90, 90, 84)),
           block=((150, 150, 142), (90, 90, 84)), counter=((107, 122, 58), None), bridge=((160, 160, 150), (60, 60, 56)),
           ramp=((214, 210, 196), (60, 60, 56)), truss=((236, 232, 218), (10, 12, 10)))
for i in items:
    if i["kind"] in STY:
        rect(i, *STY[i["kind"]])
        if i["kind"] == "ramp":
            a, b = P(i["x0"], i["z1"]), P(i["x1"], i["z0"])
            for t in range(1, 6):
                if i["rise"] == "N":
                    y = a[1] + (b[1] - a[1]) * t / 6; d.line([(a[0], y), (b[0], y)], fill=(60, 60, 56))
                else:
                    x = a[0] + (b[0] - a[0]) * t / 6; d.line([(x, a[1]), (x, b[1])], fill=(60, 60, 56))
for s in spots:
    x, y = P(s["x"], s["z"])
    d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(255, 120, 90) if s["roof"] else (196, 40, 40), outline=(10, 12, 10))
for a in arrivals:
    x, y = P(a["x"], a["z"])
    d.polygon([(x - 4, y + 4), (x + 4, y + 4), (x, y - 5)], fill=(236, 232, 218), outline=(10, 12, 10))
for s in signs:
    x, y = P(s["x"], s["z"])
    d.text((x - 8, y - 7), s["text"], fill=(10, 12, 10), font=f)
d.text(P(-11, 4), "SPAWN", fill=(236, 232, 218), font=F)
d.text(P(138, GZ + 22), "DISTANCE GALLERY 224 x 72", fill=(236, 232, 218), font=F)
d.text(P(138, GZ + 12), "2 lanes, sign + EnemySpot every 25 studs (25..200)", fill=(236, 232, 218), font=f)
d.line([P(FIRE, GZ), P(FIRE, -GZ)], fill=(10, 12, 10), width=2)
d.text(P(FIRE + 2, -GZ - 6), "firing line x 136 (low counters)", fill=(236, 232, 218), font=f)
d.text(P(24, -14), "floor lines 25/50/75/100 from plaza edge", fill=(60, 64, 52), font=f)
d.rectangle([P(-88, 121), P(88, -121)], outline=(10, 12, 10))
d.text(P(-30, -110), "current room 172 x 238", fill=(10, 12, 10), font=f)
d.text((M, 14), "TACTICALS TRAINING v2 (proposal): arena 256 x 256 + gallery 224 x 72, floor y 600, roof deck y 624, open sky", fill=(236, 232, 218), font=FT)
ly = H - 150
leg = [((10, 12, 10), "perimeter wall 36 (grid)"), ((86, 88, 84), "corner bastion 30, roof walkable"), ((120, 122, 116), "block 24, roof walkable"),
       ((60, 62, 58), "tower 60 (landmark)"), ((96, 98, 92), "tall cover 10-12 / pillar"), ((150, 150, 142), "low cover 3-4 (vaultable)"),
       ((160, 160, 150), "roof bridge slab"), ((214, 210, 196), "stair ramp to +24"), ((236, 232, 218), "truss ladder"), ((138, 156, 74), "spawn plaza")]
for n, (c, t) in enumerate(leg):
    x = M + (n % 4) * 280; y = ly + (n // 4) * 24
    d.rectangle([x, y, x + 18, y + 14], fill=c, outline=(236, 232, 218))
    d.text((x + 26, y), t, fill=(236, 232, 218), font=f)
y = ly + 78
d.ellipse([M, y, M + 12, y + 12], fill=(196, 40, 40)); d.text((M + 20, y - 1), "EnemySpot, floor", fill=(236, 232, 218), font=f)
d.ellipse([M + 280, y, M + 292, y + 12], fill=(255, 120, 90)); d.text((M + 300, y - 1), "EnemySpot, roof", fill=(236, 232, 218), font=f)
d.polygon([(M + 560, y + 12), (M + 572, y + 12), (M + 566, y)], fill=(236, 232, 218)); d.text((M + 580, y - 1), "Arrive part", fill=(236, 232, 218), font=f)
d.text((M + 840, y - 1), "spots %d (gallery 16), arrivals %d, grid 25 studs" % (len(spots), len(arrivals)), fill=(236, 232, 218), font=f)
d.text((M, y + 26), "+X east, +Z north (up). Outline = current room footprint for scale. Positions indicative; the builder refines them in Studio.", fill=(167, 173, 152), font=f)
im.save(os.path.join(OUT, "plan_new.png"))
print(dict(cnt), "spots", len(spots), "arrivals", len(arrivals), "signs", len(signs), "size", im.size)
