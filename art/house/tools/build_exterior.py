"""House map, PART B exterior: what players see through the windows (unreachable; low poly, texture-driven, mobile-safe).
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/tools/build_exterior.py -- [--nobake]
Same coordinates as build_house.py (layout plan: x east, y north, z up; outside ground at z = -1, house floor z = 0).
Zones from house_layout.json exterior{}: street y -80..-56, front yard y -56..-31, the house across y -150..-88, side yards
x +-(42..90), back yard y 31..75. Big surfaces use the tiling textures (tex/tile); small props use plain colours; the cars
share one baked atlas. Every window of the far houses is a real recessed opening (dark glass 0.35 behind the face + frame).
Writes art/house/house_exterior.blend, fbx/H_Exterior.fbx (+ K_ScaleCube / K_Marker), house_exterior.json."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_house as bh
from build_house import *        # noqa  (hcore names, add_poly, box_faces, tiled_object, plain_material ...)

BLEND = os.path.join(ROOT, "house_exterior.blend")
import hcore as _hc
_hc.ATLAS_RES.update({"Cars": 2048})
GZ = -1.0       # outside ground level
EXT = bh.SHELL  # (group, material) -> polys

for k_, v_ in {
    "car_white": dict(paint=(222, 222, 218), rough=0.25, mottle=0.03, dirt=0.15),
    "car_slate": dict(paint=(70, 86, 104), rough=0.25, mottle=0.03, dirt=0.15),
    "car_wine": dict(paint=(110, 34, 40), rough=0.25, mottle=0.03, dirt=0.15),
    "car_charcoal": dict(paint=(46, 48, 50), rough=0.25, mottle=0.03, dirt=0.15),
    "tyre": dict(paint=(24, 24, 24), rough=0.85, dirt=0.25),
    "rim": dict(paint=(150, 152, 154), rough=0.35, mottle=0.04),
    "lamp_red": dict(paint=(150, 24, 24), rough=0.2),
    "lamp_white": dict(paint=(236, 234, 226), rough=0.2),
}.items():
    d_ = dict(DEF); d_.update(v_); K[k_] = d_


def boxp(group, mat, x0, x1, y0, y1, z0, z1, skip_bottom=True, mats=None):
    for nrm, quad in box_faces(x0, x1, y0, y1, z0, z1):
        if skip_bottom and nrm.z < -0.5:
            continue
        m = mat
        if mats:
            m = mats.get("top" if nrm.z > 0.5 else "side", mat)
        add_poly(m, quad, group)


def quad(group, mat, x0, x1, y0, y1, z):
    add_poly(mat, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], group)


# ----------------------------------------------------------------------------------------------------------- ground
def ground():
    # one big lawn under everything, then paved / street pieces as 0.15-0.25 thick slabs on top of it (never flush)
    quad("Ground", "Grass", -900, 900, -900, 900, GZ)       # to the horizon from the upper windows
    # street: road sunk below the kerbs; sidewalks either side
    boxp("Street", "Asphalt", -220, 220, -75.0, -61.0, GZ - 0.3, GZ + 0.12)
    for (y0, y1) in ((-61.0, -56.0), (-80.0, -75.0)):
        boxp("Street", "Concrete", -220, 220, y0, y1, GZ - 0.3, GZ + 0.3)
    # centre line dashes, edge lines and a crossing (cream paint, 0.12 proud of the asphalt)
    for x in range(-216, 220, 10):
        boxp("Street", "Paint", x, x + 5, -68.15, -67.85, GZ + 0.12, GZ + 0.24)
    for y in (-73.6, -62.4):
        boxp("Street", "Paint", -220, 220, y - 0.12, y + 0.12, GZ + 0.12, GZ + 0.24)
    for i in range(7):
        x0 = -16 + i * 2.2
        boxp("Street", "Paint", x0, x0 + 1.2, -74.6, -61.4, GZ + 0.12, GZ + 0.24)
    # our driveway (east, x 16..30) and the front path (x 0.5..5.5) up to the step; dropped kerb at the driveway
    boxp("Yard", "Concrete", 16.0, 30.0, -56.0, -31.0, GZ - 0.2, GZ + 0.18)
    boxp("Yard", "Concrete", 0.5, 5.5, -56.0, -34.0, GZ - 0.2, GZ + 0.18)
    # back patio and a path to the shed
    boxp("Yard", "Concrete", -14.0, 16.0, 31.0, 43.0, GZ - 0.2, GZ + 0.25)
    boxp("Yard", "Concrete", 22.0, 25.0, 43.0, 60.0, GZ - 0.2, GZ + 0.18)
    # low hedge along our front boundary (gaps for the path and the driveway)
    for (x0, x1) in ((-44.0, 0.0), (6.0, 15.5), (30.5, 44.0)):
        boxp("Yard", "Hedge", x0, x1, -55.6, -54.0, GZ, GZ + 2.4)


# ----------------------------------------------------------------------------------------------------------- fences
def fence(group, x0, y0, x1, y1, h=7.0, post_every=6.0):
    """timber board fence (tiled 'Fence' boards on both faces) with charcoal posts and a cap"""
    L = math.hypot(x1 - x0, y1 - y0)
    if abs(y1 - y0) < 1e-6:
        boxp(group, "Fence", min(x0, x1), max(x0, x1), y0 - 0.15, y0 + 0.15, GZ, GZ + h)
        boxp(group, "FencePost", min(x0, x1), max(x0, x1), y0 - 0.33, y0 + 0.33, GZ + h - 0.05, GZ + h + 0.2, skip_bottom=False)
        n = max(1, int(L / post_every))
        for i in range(n + 1):
            x = min(x0, x1) + L * i / n
            boxp(group, "FencePost", x - 0.3, x + 0.3, y0 - 0.3, y0 + 0.3, GZ, GZ + h + 0.15)
    else:
        boxp(group, "Fence", x0 - 0.15, x0 + 0.15, min(y0, y1), max(y0, y1), GZ, GZ + h)
        boxp(group, "FencePost", x0 - 0.33, x0 + 0.33, min(y0, y1), max(y0, y1), GZ + h - 0.05, GZ + h + 0.2, skip_bottom=False)
        n = max(1, int(L / post_every))
        for i in range(n + 1):
            y = min(y0, y1) + L * i / n
            boxp(group, "FencePost", x0 - 0.3, x0 + 0.3, y - 0.3, y + 0.3, GZ, GZ + h + 0.15)


# ----------------------------------------------------------------------------------------------------------- far houses
def wall_with_windows(group, axis, out_sign, line, a0, a1, z0, z1, wins, mat, t=1.0):
    """a wall (thickness t, outer face at `line`, inside toward -out_sign) with real openings: piers / sills / lintels as
    boxes around each window, dark glass 0.35 behind the outer face, a charcoal frame ring proud 0.12 of the face."""
    tin, tout = (line - out_sign * t, line) if out_sign > 0 else (line, line - out_sign * t)
    tl, th = min(tin, tout), max(tin, tout)
    def B(alo, ahi, zlo, zhi, mm=mat, tlo=tl, thi=th):
        if alo >= ahi - 1e-6 or zlo >= zhi - 1e-6:
            return
        sb = zlo <= z0 + 1e-6 and z0 <= GZ + 0.61      # only the cells standing on the plinth skip their bottom face
        if axis == "x":
            boxp(group, mm, alo, ahi, tlo, thi, zlo, zhi, skip_bottom=sb)
        else:
            boxp(group, mm, tlo, thi, alo, ahi, zlo, zhi, skip_bottom=sb)
    # the wall minus the openings, as a grid cut at every opening edge (openings may share columns: a pier-by-pier walk
    # filled the second window of a column back in)
    ca = sorted({a0, a1} | {v for w in wins for v in (w[0], w[1]) if a0 < v < a1})
    cz = sorted({z0, z1} | {v for w in wins for v in (w[2], w[3]) if z0 < v < z1})
    for i in range(len(ca) - 1):
        for j in range(len(cz) - 1):
            am, zm = (ca[i] + ca[i + 1]) / 2, (cz[j] + cz[j + 1]) / 2
            if any(w[0] < am < w[1] and w[2] < zm < w[3] for w in wins):
                continue
            B(ca[i], ca[i + 1], cz[j], cz[j + 1])
    for (wa, wb, wz0, wz1) in wins:
        g0 = line - out_sign * 0.35
        gl, gh = sorted((g0, g0 - out_sign * 0.1))
        if wz1 - wz0 < 8.5:        # windows get dark glass; door / garage openings are filled by their panel
            B(wa - 0.02, wb + 0.02, wz0 - 0.02, wz1 + 0.02, "GlassDark", gl, gh)
        f0 = line + out_sign * 0.12
        fl, fh = sorted((line - out_sign * 0.37, f0))      # reaches 0.02 into the glass: no slit
        fw = 0.22
        B(wa - fw, wa + 0.03, wz0 - fw, wz1 + fw, "Frame", fl, fh)
        B(wb - 0.03, wb + fw, wz0 - fw, wz1 + fw, "Frame", fl, fh)
        B(wa + 0.03, wb - 0.03, wz0 - fw, wz0 + 0.03, "Frame", fl, fh)
        B(wa + 0.03, wb - 0.03, wz1 - 0.03, wz1 + fw, "Frame", fl, fh)
        if wb - wa > 5 and wz1 - wz0 < 8.5:      # windows only (not the door / garage openings)
            m = (wa + wb) / 2
            ml, mh = sorted((line - out_sign * 0.37, line + out_sign * 0.05))
            B(m - 0.1, m + 0.1, wz0, wz1, "Frame", ml, mh)


def gable_roof(group, x0, x1, y0, y1, zeave, rise, along="x", over=1.2, thick=0.6, mat="RoofTile"):
    """simple gable roof, ridge along `along`, plus the two gable-end triangles (wall material)"""
    if along == "x":
        ym = (y0 + y1) / 2
        for (ya, yb) in ((y0 - over, ym), (y1 + over, ym)):
            za = zeave - over * rise / ((y1 - y0) / 2)
            P = lambda x, y, dz: Vector((x, y, (za + (zeave + rise - za) * (abs(y - ya) / abs(yb - ya))) + dz))
            top = [P(x0 - over, ya, thick), P(x1 + over, ya, thick), P(x1 + over, yb, thick), P(x0 - over, yb, thick)]
            bot = [P(x0 - over, yb, 0), P(x1 + over, yb, 0), P(x1 + over, ya, 0), P(x0 - over, ya, 0)]
            n = (top[1] - top[0]).cross(top[2] - top[0])
            if n.z < 0:
                top = list(reversed(top))
            n = (bot[1] - bot[0]).cross(bot[2] - bot[0])
            if n.z > 0:
                bot = list(reversed(bot))
            add_poly(mat, top, group); add_poly("Charcoal", bot, group)
            for x in (x0 - over, x1 + over):
                s = [P(x, ya, 0), P(x, yb, 0), P(x, yb, thick), P(x, ya, thick)]
                n = (s[1] - s[0]).cross(s[2] - s[0])
                if n.x * (x - (x0 + x1) / 2) < 0:
                    s = list(reversed(s))
                add_poly("Charcoal", s, group)
            e = [P(x0 - over, ya, 0), P(x1 + over, ya, 0), P(x1 + over, ya, thick), P(x0 - over, ya, thick)]
            n = (e[1] - e[0]).cross(e[2] - e[0])
            if n.y * (ya - ym) < 0:
                e = list(reversed(e))
            add_poly("Charcoal", e, group)
        for x, sg in ((x0, -1), (x1, 1)):
            tri = [Vector((x, y0, zeave)), Vector((x, y1, zeave)), Vector((x, ym, zeave + rise + 0.2))]
            n = (tri[1] - tri[0]).cross(tri[2] - tri[0])
            if n.x * sg < 0:
                tri = list(reversed(tri))
            add_poly("SidingWhite", tri, group)


def far_house(group, cx, cy, W, D, facing, wall_mat, roof_rise=7.0, garage=True, storeys=2):
    """a two-storey modern house, footprint W (x) by D (y), front facing -Y if facing < 0 else +Y, ground floor at GZ+0.6"""
    x0, x1, y0, y1 = cx - W / 2, cx + W / 2, cy - D / 2, cy + D / 2
    zb = GZ + 0.6
    H1 = 12.0
    zt = zb + H1 * storeys
    boxp(group, "Concrete", x0 - 0.3, x1 + 0.3, y0 - 0.3, y1 + 0.3, GZ - 0.2, zb)
    front = y0 if facing < 0 else y1
    back = y1 if facing < 0 else y0
    fs = -1 if facing < 0 else 1
    # front: garage door + front door on the ground, 3 windows upstairs
    gw = (x0 + 3, x0 + 15) if garage else None
    wins_g = [(x0 + 19, x0 + 26, zb + 3, zb + 9.5), (x1 - 12, x1 - 4, zb + 3, zb + 9.5)]
    wins_u = [(x0 + 4, x0 + 12, zb + 15, zb + 21.5), (cx - 3, cx + 4, zb + 15, zb + 21.5), (x1 - 12, x1 - 4, zb + 15, zb + 21.5)]
    door = (x0 + 28.5, x0 + 33.5, zb, zb + 9.5)
    wall_with_windows(group, "x", fs, front, x0, x1, zb, zb + H1, wins_g + [door] + ([(gw[0], gw[1], zb, zb + 9.0)] if gw else []), wall_mat)
    wall_with_windows(group, "x", fs, front, x0, x1, zb + H1, zt, wins_u, wall_mat)
    wall_with_windows(group, "x", -fs, back, x0, x1, zb, zt, [(x0 + 6, x0 + 14, zb + 3, zb + 9.5), (x1 - 14, x1 - 6, zb + 15, zb + 21.5)], wall_mat)
    for x, s in ((x0, -1), (x1, 1)):
        wall_with_windows(group, "y", s, x, y0 + (1 if fs > 0 else 0), y1 - (1 if fs < 0 else 0), zb, zt,
                          [(cy - 4, cy + 4, zb + 15, zb + 21.5), (cy - 3, cy + 3, zb + 3, zb + 9.5)], wall_mat)
    # garage door panel and the front door leaf, inset 0.35 (over the dark glass of those openings: 0.15 in front of it)
    if gw:
        lo_, hi_ = sorted((front - fs * 0.2, front - fs * 0.37))
        boxp(group, "GarageDoor", gw[0], gw[1], lo_, hi_, zb, zb + 9.0, skip_bottom=False)
    lo_, hi_ = sorted((front - fs * 0.2, front - fs * 0.37))
    boxp(group, "DoorOak", door[0], door[1], lo_, hi_, zb, zb + 9.5, skip_bottom=False)
    quad(group, "CeilingWhite", x0, x1, y0, y1, zt)    # a lid under the roof (never seen, closes the box)
    gable_roof(group, x0, x1, y0, y1, zt, roof_rise)
    # front path + driveway to the street side
    boxp(group, "Concrete", gw[0] if gw else x0 + 3, gw[1] if gw else x0 + 15, min(front, front + fs * 22), max(front, front + fs * 22), GZ - 0.2, GZ + 0.18)


# ----------------------------------------------------------------------------------------------------------- props (plain / baked)
PROPS = []


def tree(name, kind, seed, h=16.0):
    """low-poly faceted tree (Asset Library: Low-Poly Faceted Tree). Knobs changed: 7-sided trunk with a lean (was a
    straight octagon), crown of 3-4 stacked faceted blobs / a stacked-cone conifer (was one blob), our two greens."""
    rng = random.Random(seed)
    mb = MB(name, "Plain:Tree", h)
    lean = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
    mb.lathe([(0, GZ - 0.2), (0.75, GZ - 0.2), (0.62, GZ + 0.6), (0.45, GZ + h * 0.45), (0.0, GZ + h * 0.45)], 7, "stem",
             deform=lambda v: v + lean * max(0.0, (v.z - GZ) / h))
    top = Vector((0, 0, GZ + h * 0.45)) + lean * 0.45
    leaves = MB(name + "_Leaves", "Plain:Leaves", h)
    leaves2 = MB(name + "_LeavesDark", "Plain:LeavesDark", h)
    if kind == "broad":
        for i in range(4):
            c = top + Vector((rng.uniform(-2.2, 2.2), rng.uniform(-2.2, 2.2), rng.uniform(1.5, h * 0.45)))
            r = rng.uniform(2.8, 4.2)
            ellipsoid(leaves if i % 2 == 0 else leaves2, c, (r, r * rng.uniform(0.85, 1.1), r * 0.8), "leaf" if i % 2 == 0 else "leaf_dark", segs=7, rings=4)
    else:
        z = top.z - 3.0          # the trunk top ends inside the second cone (no 0.1 slit)
        for i, r in enumerate((4.2, 3.4, 2.5, 1.5)):
            (leaves2 if i % 2 else leaves).lathe([(0, z), (r, z), (0, z + 4.2)], 7, "leaf_dark" if i % 2 else "leaf", M=Matrix.Translation(Vector((top.x, top.y, 0))))
            z += 2.6
    a = finish(mb); b = finish(leaves); c = finish(leaves2)
    for o in (a, b, c):
        for p in o.data.polygons:
            p.use_smooth = False
    return [a, b, c]


def car(name, kind, style, paint):
    """low-poly car (own design, generic proportions), length along +X. style 'suv' / 'sedan'. 1 stud = 0.35 m."""
    mb = MB(name, "Cars", 5.0)
    L, W = (13.4, 5.6) if style == "suv" else (13.0, 5.2)
    hb, hr = (2.9, 5.4) if style == "suv" else (2.5, 4.4)
    # lower body: side profile extruded across Y
    prof = [(-L / 2, 0.9), (L / 2, 0.9), (L / 2, hb - 0.4), (L / 2 - 0.5, hb), (-L / 2 + 0.4, hb), (-L / 2, hb - 0.5)]
    mb.prism(prof, "Y", -W / 2, W / 2, paint)
    # cabin: trapezoid profile, a bit narrower
    if style == "suv":
        cab = [(-L / 2 + 0.6, hb - 0.05), (L / 2 - 3.6, hb - 0.05), (L / 2 - 5.2, hr), (-L / 2 + 0.9, hr)]
    else:
        cab = [(-L / 2 + 2.0, hb - 0.05), (L / 2 - 3.4, hb - 0.05), (L / 2 - 5.4, hr), (-L / 2 + 3.8, hr)]
    mb.prism(cab, "Y", -W / 2 + 0.35, W / 2 - 0.35, "glass_dark")
    xa, xb = cab[3][0] + 0.15, cab[2][0] - 0.15
    mb.boxr((xa, -W / 2 + 0.3, hr - 0.1), (xb, W / 2 - 0.3, hr + 0.15), paint)          # roof skin
    mb.boxr((-L / 2 + 0.6, -W / 2 + 0.3, hb - 0.1), (L / 2 - 0.6, W / 2 - 0.3, hb + 0.25), paint)  # belt line
    for sx in (-1, 1):
        x = sx * (L / 2 - 2.6)
        for sy in (-1, 1):
            M = Matrix.Translation((x, sy * (W / 2 - 0.45), 1.1)) @ Matrix.Rotation(math.radians(90), 4, "X")
            mb.lathe([(0, -0.45), (1.1, -0.45), (1.15, -0.3), (1.15, 0.3), (1.1, 0.45), (0, 0.45)], 12, "tyre", M=M)
    for sy in (-1, 1):
        mb.boxr((L / 2 - 0.08, sy * (W / 2 - 0.9) - 0.4, hb - 0.9), (L / 2 + 0.05, sy * (W / 2 - 0.9) + 0.4, hb - 0.55), "lamp_white")
        mb.boxr((-L / 2 - 0.05, sy * (W / 2 - 0.8) - 0.45, hb - 0.9), (-L / 2 + 0.08, sy * (W / 2 - 0.8) + 0.45, hb - 0.55), "lamp_red")
    mb.boxr((-L / 2 - 0.12, -W / 2 + 0.2, 0.9), (-L / 2 + 0.3, W / 2 - 0.2, 1.5), "plastic_black")
    mb.boxr((L / 2 - 0.3, -W / 2 + 0.2, 0.9), (L / 2 + 0.12, W / 2 - 0.2, 1.5), "plastic_black")
    o = finish(mb)
    return o


def pole(name, x, y, h=26.0):
    mb = MB(name, "Plain:Pole", h)
    mb.lathe([(0, GZ - 0.3), (0.45, GZ - 0.3), (0.32, GZ + h), (0, GZ + h)], 8, "stem")
    mb.boxr((-0.2, -3.2, GZ + h - 1.6), (0.2, 3.2, GZ + h - 1.1), "stem")          # cross-arm across the street line
    for yy in (-2.8, 0.0, 2.8):
        mb.lathe([(0, 0), (0.12, 0), (0.1, 0.45), (0, 0.45)], 6, "ceramic", M=Matrix.Translation((0, yy, GZ + h - 1.1)))
    mb.lathe([(0, 0), (0.7, 0), (0.7, 2.0), (0, 2.0)], 8, "plastic_grey", M=Matrix.Translation((0.0, 0.9, GZ + h - 5.0)))   # transformer
    o = finish(mb); o.location = (x, y, 0)
    return o


def wires(name, poles_xy, hz, offsets=(-2.8, 0.0, 2.8), sag=1.6, house_drop=None):
    mb = MB(name, "Plain:Wire", 2.0)
    for ox in offsets:
        for (xa, ya), (xb, yb) in zip(poles_xy, poles_xy[1:]):
            # poles run along x; the three conductors sit on the cross-arm at y offsets
            pts = [(xa + (xb - xa) * i / 8, ya + ox + (yb - ya) * i / 8, hz - sag * 4 * (i / 8) * (1 - i / 8)) for i in range(9)]
            mb.tube(pts, 0.07, "plastic_black", segs=4)
    if house_drop:
        (xa, ya, za), (xb, yb, zb) = house_drop
        pts = [(xa + (xb - xa) * i / 8, ya + (yb - ya) * i / 8, za + (zb - za) * i / 8 - 1.2 * 4 * (i / 8) * (1 - i / 8)) for i in range(9)]
        mb.tube(pts, 0.06, "plastic_black", segs=4)
    return finish(mb)


def lamp_post(name, x, y, facing):
    mb = MB(name, "Plain:Pole2", 14.0)
    mb.lathe([(0, GZ), (0.3, GZ), (0.18, GZ + 13.0), (0, GZ + 13.0)], 8, "black_metal")
    mb.boxr((-0.15, facing * 0.0 - 0.15, GZ + 12.8), (0.15, facing * 2.6 + 0.15 if facing > 0 else 0.15, GZ + 13.1), "black_metal") if facing > 0 else \
        mb.boxr((-0.15, -2.6, GZ + 12.8), (0.15, 0.15, GZ + 13.1), "black_metal")
    yy = 2.4 * (1 if facing > 0 else -1)
    mb.boxr((-0.45, yy - 0.7, GZ + 12.5), (0.45, yy + 0.7, GZ + 12.9), "black_metal")
    o = finish(mb); o.location = (x, y, 0)
    return o


def mailbox(name, x, y):
    mb = MB(name, "Plain:Mailbox", 4.0)
    mb.boxr((-0.15, -0.15, GZ), (0.15, 0.15, GZ + 3.3), "black_metal")
    rbox(mb, (-0.55, -0.9, GZ + 3.2), (0.55, 0.9, GZ + 4.1), "black_metal", r=0.2)
    mb.boxr((0.5, 0.3, GZ + 3.7), (0.62, 0.42, GZ + 4.5), "plastic_grey")
    o = finish(mb); o.location = (x, y, 0)
    return o


def shed(group, x0, x1, y0, y1):
    boxp(group, "Fence", x0, x1, y0, y1, GZ, GZ + 8.25)
    s = 2.0 / (y1 - y0 + 2)
    P = lambda x, y, dz: Vector((x, y, GZ + 8.0 + (y - (y0 - 1)) * s + dz))
    top = [P(x0 - 1, y0 - 1, 0.4), P(x1 + 1, y0 - 1, 0.4), P(x1 + 1, y1 + 1, 0.4), P(x0 - 1, y1 + 1, 0.4)]
    add_poly("RoofMetal", top, group)
    for q in ([P(x0 - 1, y1 + 1, 0), P(x1 + 1, y1 + 1, 0), P(x1 + 1, y0 - 1, 0), P(x0 - 1, y0 - 1, 0)],):
        add_poly("Charcoal", q, group)
    for (xa, ya, xb, yb) in ((x0 - 1, y0 - 1, x1 + 1, y0 - 1), (x1 + 1, y1 + 1, x0 - 1, y1 + 1), (x1 + 1, y0 - 1, x1 + 1, y1 + 1), (x0 - 1, y1 + 1, x0 - 1, y0 - 1)):
        add_poly("Charcoal", [P(xa, ya, 0), P(xb, yb, 0), P(xb, yb, 0.4), P(xa, ya, 0.4)], group)
    tri = lambda x, sg: [Vector((x, y0, GZ + 8.0)), Vector((x, y1, GZ + 8.0)), Vector((x, y1, GZ + 8.0 + (y1 - y0 + 1) * s))]
    for x, sg in ((x0, -1), (x1, 1)):
        t = tri(x, sg)
        n = (t[1] - t[0]).cross(t[2] - t[0])
        add_poly("Fence", t if n.x * sg > 0 else list(reversed(t)), group)
    q = [Vector((x1, y1, GZ + 8.0)), Vector((x0, y1, GZ + 8.0)), Vector((x0, y1, GZ + 8.0 + (y1 - y0 + 1) * s)), Vector((x1, y1, GZ + 8.0 + (y1 - y0 + 1) * s))]
    add_poly("Fence", q, group)
    boxp(group, "DoorOak", (x0 + x1) / 2 - 1.8, (x0 + x1) / 2 + 1.8, y0 - 0.12, y0 + 0.05, GZ, GZ + 7.0)


# ----------------------------------------------------------------------------------------------------------- sky
def sky_images():
    """Roblox Sky faces from the generated sky: the side made seamless left-right (cross-fade with its mirror), the top a
    smooth crop of the upper colour, the bottom the haze colour. tex/sky/sky_{side,up,dn}.png"""
    import numpy as np
    src = os.path.join(TEX, "gen", "sky.png")
    out = os.path.join(TEX, "sky"); os.makedirs(out, exist_ok=True)
    im = bpy.data.images.load(src)
    w, h = im.size
    px = np.array(im.pixels[:], np.float32).reshape(h, w, 4)
    mir = px[:, ::-1]
    t = np.linspace(0, 1, w)[None, :, None]
    blend_ = np.abs(t - 0.5) * 2                  # 1 at the edges, 0 in the middle
    side = px * (1 - blend_ ** 3) + mir * blend_ ** 3
    # warm the lower band a little toward the palette's cream (late afternoon), keep blue above
    zz = np.linspace(0, 1, h)[:, None, None]       # 0 = bottom row (Blender pixels start at the bottom)
    warm = np.array([236, 226, 206, 255], np.float32)[None, None, :] / 255.0
    side = side * (1 - 0.22 * (1 - zz) ** 2) + warm * 0.22 * (1 - zz) ** 2
    def save(name, arr):
        img = bpy.data.images.new(name, arr.shape[1], arr.shape[0], alpha=False)
        img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
        img.filepath_raw = os.path.join(out, name + ".png"); img.file_format = "PNG"; img.save()
    save("sky_side", side)
    top = np.ones((256, 256, 4), np.float32) * side[-6:-1].mean(axis=(0, 1))[None, None, :]
    save("sky_up", top)
    dn = np.ones((256, 256, 4), np.float32) * side[0:5].mean(axis=(0, 1))[None, None, :]
    save("sky_dn", dn)


# ----------------------------------------------------------------------------------------------------------- main
PLAIN_COL = {"Paint": (232, 226, 210), "FencePost": (48, 46, 44), "GlassDark": (40, 46, 50), "Frame": (44, 44, 44),
             "GarageDoor": (196, 196, 192), "DoorOak": (150, 112, 76), "Charcoal": (44, 44, 44), "SidingWhite": (226, 224, 218),
             "RoofTile": (84, 80, 78)}
PLAIN_KIND = {"Tree": (92, 70, 52), "Leaves": None, "Pole": (96, 78, 60), "Pole2": (30, 30, 31), "Wire": (20, 20, 20), "Mailbox": (30, 30, 31)}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sky_images()
    ground()
    # our side fences (x +-46) from the front corners to the back fence, the back fence at y 75
    fence("Fences", -46.0, -40.0, -46.0, 75.0)
    fence("Fences", 46.0, -40.0, 46.0, 75.0)
    fence("Fences", -46.0, 75.0, 46.0, 75.0)
    fence("Fences", -46.0, -40.0, -41.0, -40.0); fence("Fences", 41.0, -40.0, 46.0, -40.0)   # gates line to the house corners
    shed("Yard", 26.0, 36.0, 60.0, 68.0)
    # neighbours at both sides (their walls and windows seen from our side windows), behind, and across the street
    far_house("NeighbourW", -84.0, -6.0, 64.0, 40.0, -1, "Brick")
    far_house("NeighbourE", 84.0, -6.0, 64.0, 40.0, -1, "Render")
    far_house("Across", 0.0, -120.0, 66.0, 40.0, 1, "Siding")
    far_house("AcrossW", -88.0, -122.0, 62.0, 38.0, 1, "Brick")
    far_house("AcrossE", 88.0, -122.0, 62.0, 38.0, 1, "Render")
    far_house("BehindW", -40.0, 108.0, 60.0, 36.0, 1, "Render", garage=False)
    far_house("BehindE", 40.0, 108.0, 60.0, 36.0, 1, "Brick", garage=False)
    fence("Fences", -46.0, -92.0, 46.0, -92.0, h=4.0)            # the across house's front fence (low)
    for (x0, x1) in ((-160, -46), (46, 160)):
        fence("Fences", x0, 75.0, x1, 75.0)
    obs = []
    # trees
    spots = [(-30, -46, "broad"), (36, -48, "broad"), (-34, 58, "broad"), (6, 66, "cone"), (-60, -98, "broad"), (24, -98, "cone"),
             (60, -96, "broad"), (-110, -50, "cone"), (112, -50, "broad"), (-70, 70, "broad"), (78, 72, "cone"), (-140, -96, "broad"),
             (140, -98, "cone"), (-20, 92, "cone"), (20, 92, "broad")]
    for i, (x, y, k) in enumerate(spots):
        for o in tree(f"Tree_{i + 1:02d}", k, 100 + i, h=random.Random(i).uniform(14, 20)):
            o.location = (x, y, 0); obs.append(o)
    # power poles along the far (south) sidewalk, wires, a service drop to our front wall
    poles = [(x, -78.0) for x in range(-200, 201, 40)]
    for i, (x, y) in enumerate(poles):
        obs.append(pole(f"PowerPole_{i + 1:02d}", x, y))
    obs.append(wires("PowerWires", poles, GZ + 26.0 - 0.7, house_drop=((0.0, -78.0, GZ + 26.0 - 2.0), (-8.0, -31.2, 24.0))))
    for i, x in enumerate((-60, 60)):
        obs.append(lamp_post(f"StreetLamp_{i + 1}", x, -58.5, -1))
    obs.append(mailbox("Mailbox", 8.5, -54.8))
    # cars (one baked atlas)
    cars = [car("Car_FamilySUV", "car", "suv", "car_white"), car("Car_SedanSlate", "car", "sedan", "car_slate"),
            car("Car_SedanWine", "car", "sedan", "car_wine"), car("Car_SUVCharcoal", "car", "suv", "car_charcoal")]
    place = {"Car_FamilySUV": ((23.0, -43.0, GZ + 0.18), 90), "Car_SedanSlate": ((-30.0, -63.6, GZ + 0.12), 0),
             "Car_SedanWine": ((44.0, -72.4, GZ + 0.12), 180), "Car_SUVCharcoal": ((-24.0, -110.0, GZ + 0.18), -90)}
    atl_files = {}
    if not NOBAKE:
        setup_cycles()
        x = 0.0
        for o in cars:
            o.location = (8000 + x, 8000, 0); x += 20
        bpy.context.view_layer.update()
        imgs = bake_atlas("Cars", cars)
        finalize(cars, atlas_material("Cars", imgs))
        atl_files["Cars"] = {p: f"tex/{PREFIX}Cars_{p}.png" for p in imgs}
    for o in cars:
        (loc, rz) = place[o.name]
        o.location = loc; o.rotation_euler = (0, 0, math.radians(rz))
    obs += cars
    for o in obs:
        if str(o.get("atlas", "")).startswith("Plain:"):
            k = o["atlas"].split(":", 1)[1]
            me = o.data
            if k in ("Leaves", "LeavesDark"):   # one tone per mesh, so each tints on its own in Studio
                me.materials.clear(); me.materials.append(plain_material("H_" + k, (64, 96, 54) if k == "Leaves" else (44, 72, 44), 0.8))
                for p in me.polygons:
                    p.material_index = 0
            else:
                me.materials.clear(); me.materials.append(plain_material("H_" + k, PLAIN_KIND[k], 0.7))
                for p in me.polygons:
                    p.material_index = 0
            for nm in [l.name for l in me.uv_layers if l.name != "UVMap"]:
                me.uv_layers.remove(me.uv_layers[nm])
    log("deduped", bh.dedupe_shell(), "hidden back-to-back faces")
    # tiled / plain groups
    groups = []
    for (grp, mat), polys in sorted(EXT.items()):
        if mat in PLAIN_COL:
            ob = tiled_object(f"Ext_{grp}_{mat}", "Render", polys)
            ob.data.materials.clear(); ob.data.materials.append(plain_material("H_" + mat, PLAIN_COL[mat], 0.6))
            ob["tile"] = mat
        else:
            ob = tiled_object(f"Ext_{grp}_{mat}", mat, polys)
        groups.append(ob)
    allobs = groups + obs
    for o in allobs:
        for c in o.users_collection:
            c.objects.unlink(o)
        coll("Exterior").objects.link(o)
    for c in list(bpy.data.collections):
        if c.name in ("Masters", "House") and not c.objects:
            bpy.data.collections.remove(c)
    cube, mk = scale_cube_marker()
    cube.location = (0, -120, 30); mk.location = (12, -120, 25)
    bpy.context.view_layer.update()
    man = dict(note="Same coordinates as house_shell.json (layout plan; outside ground z = -1). All art, CanCollide off, unreachable. "
                    "Sky: tex/sky/sky_side.png for SkyboxBk/Ft/Lf/Rt, sky_up.png for SkyboxUp, sky_dn.png for SkyboxDn.",
               atlases=atl_files, tiles={k: f"tex/tile/T_{k}.png" for k in bh.TILES}, objects=[])
    for o in allobs:
        lo, hi = bbox([o])
        man["objects"].append(dict(name=o.name, tris=tris(o), material=[m.name for m in o.data.materials],
                                   bbox_plan=[[round(v, 2) for v in lo], [round(v, 2) for v in hi]]))
    man["total_tris"] = sum(e["tris"] for e in man["objects"])
    json.dump(man, open(os.path.join(ROOT, "house_exterior.json"), "w"), indent=1)
    if not NOBAKE:
        export_fbx(os.path.join(FBXD, "H_Exterior.fbx"), allobs + [cube, mk])
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    log("DONE", len(allobs), "objects", man["total_tris"], "tris")


if __name__ == "__main__":
    main()
