"""House map, 1965 test-site restyle, PART B exterior: the desert test site seen through the windows (unreachable; low
poly, texture-driven, mobile-safe).
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/v2/tools/build_exterior_1965.py -- [--nobake]
Same coordinates as build_house.py (layout plan: x east, y north, z up; outside ground z = -1, house floor z = 0) and the
same output names as v1 (fbx/H_Exterior.fbx + K_ScaleCube / K_Marker, house_exterior.json, house_exterior.blend), so the
installer's swap is drop-in. Every visible surface is a tiling texture or a baked atlas (no plain colours that Import 3D
would drop), except the power poles / wires (installer PLAIN Pole / Wire) and the far houses' dark glass (GlassDark).
Contents: desert ground, a dirt cul-de-sac, dry yards, the second test house across the street (mint siding on fieldstone,
an open garage with pegboard, bikes and our own banner), pastel ranch neighbours, picket and weathered fences, a trellis,
rounded 1960s cars + a delivery truck with our own lettering, test dummies, sandbag emplacements, wooden power poles, our
own warning signs, two steel instrument masts (one framed by the foyer window), a ring of mesas, a hazy desert sky."""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_house as bh
from build_house import *        # noqa  (hcore names, add_poly, box_faces, tiled_object, plain_material, kinds65 ...)
import numpy as np

BLEND = os.path.join(ROOT, "house_exterior.blend")
GZ = -1.0
EXT = bh.SHELL
R = random.Random(65)

for k_, v_ in {
    "car_mint": dict(paint=(150, 190, 168), rough=0.35, mottle=0.1, chip=0.25, under=(110, 70, 44), rust=0.25, dirt=0.4, dust=0.35),
    "car_butter": dict(paint=(222, 204, 132), rough=0.35, mottle=0.1, chip=0.25, under=(110, 70, 44), rust=0.25, dirt=0.4, dust=0.35),
    "car_salmon": dict(paint=(206, 150, 128), rough=0.35, mottle=0.1, chip=0.25, under=(110, 70, 44), rust=0.25, dirt=0.4, dust=0.35),
    "car_cream": dict(paint=(226, 218, 190), rough=0.35, mottle=0.1, chip=0.2, under=(110, 70, 44), rust=0.2, dirt=0.4, dust=0.35, paintable=True),
    "car_olive": dict(paint=(118, 128, 78), rough=0.4, mottle=0.1, chip=0.3, under=(110, 70, 44), rust=0.3, dirt=0.45, dust=0.35),
    "tyre65": dict(paint=(30, 30, 28), rough=0.9, dirt=0.4, dust=0.4),
    "whitewall": dict(paint=(214, 208, 192), rough=0.7, dirt=0.4),
    "chrome_ext": dict(paint=(186, 184, 176), rough=0.25, metal_paint=1.0, rust=0.2, dirt=0.3),
    "lamp_lens": dict(paint=(226, 214, 170), rough=0.2),
    "lamp_tail": dict(paint=(140, 60, 40), rough=0.2),
    "burlap": dict(paint=(176, 152, 108), weave=True, rough=1.0, mottle=0.2, bump=0.7, dirt=0.4, dust=0.3),
    "steel_mast": dict(paint=(150, 148, 140), rough=0.5, metal_paint=0.6, rust=0.3, dirt=0.3),
    "cabin_paint": dict(paint=(206, 200, 184), rough=0.5, chip=0.3, under=(110, 104, 96), rust=0.2, dirt=0.35),
    "sign_board": dict(paint=(232, 222, 190), rough=0.7, paintable=True, dirt=0.3),
    "post_wood": dict(under=(132, 112, 84), wood=True, rough=0.8, dirt=0.4),
    "bark_dry": dict(paint=(110, 92, 72), rough=0.9, mottle=0.3, bump=0.7),
    "leaf_dry": dict(paint=(132, 128, 78), rough=0.8, mottle=0.3),
    "leaf_dry2": dict(paint=(108, 102, 64), rough=0.8, mottle=0.3),
    "banner": dict(paint=(107, 122, 58), weave=True, rough=0.9, paintable=True),
}.items():
    d_ = dict(DEF); d_.update(dict(dust=0.25, dirt=0.3)); d_.update(v_); K[k_] = d_


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


def disc(group, mat, cx, cy, r, z0, z1, n=24):
    pts = [Vector((cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), 0)) for i in range(n)]
    add_poly(mat, [Vector((p.x, p.y, z1)) for p in pts], group)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        add_poly(mat, [Vector((a.x, a.y, z0)), Vector((b.x, b.y, z0)), Vector((b.x, b.y, z1)), Vector((a.x, a.y, z1))], group)


# ----------------------------------------------------------------------------------------------------------- ground
def ground():
    quad("Ground", "Desert", -900, 900, -900, 900, GZ)
    # the dirt cul-de-sac: a packed-dirt road from the west ending in a turning circle in front of the house
    boxp("Street", "DirtRoad", -260, 14, -75.0, -61.0, GZ - 0.3, GZ + 0.12)
    disc("Street", "DirtRoad", 14.0, -68.0, 15.0, GZ - 0.3, GZ + 0.121, n=28)
    for (y0, y1) in ((-61.0, -57.0), (-79.0, -75.0)):       # old crumbling concrete kerbs and sidewalk
        boxp("Street", "Concrete65", -260, 0.0, y0, y1, GZ - 0.3, GZ + 0.3)
    # dry yards: patchy lawn slabs 0.15 on the sand (never flush), a concrete path and driveway
    for (x0, x1, y0, y1) in ((-44, 0.5, -55, -31), (5.5, 15.5, -55, -31), (30.5, 44, -55, -31), (-44, 44, 31, 74)):
        boxp("Yard", "DryGrass", x0, x1, y0, y1, GZ - 0.2, GZ + 0.15)
    boxp("Yard", "Concrete65", 16.0, 30.0, -56.0, -31.0, GZ - 0.2, GZ + 0.18)
    boxp("Yard", "Concrete65", 0.5, 5.5, -56.0, -34.0, GZ - 0.2, GZ + 0.18)
    boxp("Yard", "Concrete65", -14.0, 16.0, 31.0, 43.0, GZ - 0.2, GZ + 0.25)


# ----------------------------------------------------------------------------------------------------------- fences
def picket(group, x0, y0, x1, y1, h=3.5, gap=0.55):
    """white picket fence along x or y: posts, two rails, pointed pickets (TrimWhite)"""
    along_x = abs(y1 - y0) < 1e-6
    L = abs(x1 - x0) if along_x else abs(y1 - y0)
    a0 = min(x0, x1) if along_x else min(y0, y1)
    c = y0 if along_x else x0
    def B(a, b, t0, t1, z0, z1):
        if along_x:
            boxp(group, "TrimWhite", a, b, c + t0, c + t1, z0, z1)
        else:
            boxp(group, "TrimWhite", c + t0, c + t1, a, b, z0, z1)
    for z in (GZ + 0.9, GZ + h - 0.9):
        B(a0, a0 + L, 0.05, 0.2, z, z + 0.25)
    n = int(L / gap)
    for i in range(n):
        a = a0 + i * gap + 0.08
        hh = h + (0.2 if i % 7 == 3 else 0.0) - (0.6 if i % 11 == 5 else 0.0)      # a few broken / missing tops
        if i % 13 == 6:
            continue                                                              # a missing picket
        if along_x:
            prism_pts = [(a, GZ), (a + 0.3, GZ), (a + 0.3, GZ + hh - 0.25), (a + 0.15, GZ + hh), (a, GZ + hh - 0.25)]
            for t, sg in ((c - 0.05, -1), (c + 0.05, 1)):
                pass
            q = [Vector((p[0], c - 0.05, p[1])) for p in prism_pts]
            q2 = [Vector((p[0], c + 0.05, p[1])) for p in reversed(prism_pts)]
            add_poly("TrimWhite", list(reversed(q)) if True else q, group)
            add_poly("TrimWhite", list(reversed(q2)), group)
            for k in range(len(prism_pts)):
                p, r_ = prism_pts[k], prism_pts[(k + 1) % len(prism_pts)]
                add_poly("TrimWhite", [Vector((p[0], c - 0.05, p[1])), Vector((r_[0], c - 0.05, r_[1])), Vector((r_[0], c + 0.05, r_[1])), Vector((p[0], c + 0.05, p[1]))], group)
        else:
            B(a, a + 0.3, -0.05, 0.05, GZ, GZ + hh)


def board_fence(group, x0, y0, x1, y1, h=7.0):
    """weathered grey board fence (FenceWood both faces) with posts every 6"""
    if abs(y1 - y0) < 1e-6:
        boxp(group, "FenceWood", min(x0, x1), max(x0, x1), y0 - 0.15, y0 + 0.15, GZ, GZ + h)
        for x in np.arange(min(x0, x1), max(x0, x1) + 0.1, 6.0):
            boxp(group, "FenceWood", x - 0.3, x + 0.3, y0 - 0.33, y0 + 0.33, GZ, GZ + h + 0.3)
    else:
        boxp(group, "FenceWood", x0 - 0.15, x0 + 0.15, min(y0, y1), max(y0, y1), GZ, GZ + h)
        for y in np.arange(min(y0, y1), max(y0, y1) + 0.1, 6.0):
            boxp(group, "FenceWood", x0 - 0.33, x0 + 0.33, y - 0.3, y + 0.3, GZ, GZ + h + 0.3)


# ----------------------------------------------------------------------------------------------------------- houses
def wall_with_windows(group, axis, out_sign, line, a0, a1, z0, z1, wins, mat, t=1.0, base=None):
    """a wall with real openings (wall minus openings as a grid); dark glass 0.35 behind the face; a white trim frame
    proud 0.12; base = (texture, height): a fieldstone base course up to that z"""
    tin, tout = (line - out_sign * t, line) if out_sign > 0 else (line, line - out_sign * t)
    tl, th = min(tin, tout), max(tin, tout)
    def B(alo, ahi, zlo, zhi, mm=mat, tlo=tl, thi=th):
        if alo >= ahi - 1e-6 or zlo >= zhi - 1e-6:
            return
        sb = zlo <= z0 + 1e-6 and z0 <= GZ + 0.61
        if base and mm == mat and zlo < base[1] - 1e-6:
            if zhi > base[1] + 1e-6:
                B(alo, ahi, zlo, base[1], base[0], tlo, thi)
                B(alo, ahi, base[1], zhi, mm, tlo, thi)
                return
            mm = base[0]
        if axis == "x":
            boxp(group, mm, alo, ahi, tlo, thi, zlo, zhi, skip_bottom=sb)
        else:
            boxp(group, mm, tlo, thi, alo, ahi, zlo, zhi, skip_bottom=sb)
    ca = sorted({a0, a1} | {v for w in wins for v in (w[0], w[1]) if a0 < v < a1})
    cz = sorted({z0, z1} | {v for w in wins for v in (w[2], w[3]) if z0 < v < z1})
    for i in range(len(ca) - 1):
        for j in range(len(cz) - 1):
            am, zm = (ca[i] + ca[i + 1]) / 2, (cz[j] + cz[j + 1]) / 2
            if any(w[0] < am < w[1] and w[2] < zm < w[3] for w in wins):
                continue
            B(ca[i], ca[i + 1], cz[j], cz[j + 1])
    for w in wins:
        wa, wb, wz0, wz1 = w[:4]
        kind = w[4] if len(w) > 4 else "win"
        g0 = line - out_sign * 0.35
        gl, gh = sorted((g0, g0 - out_sign * 0.1))
        if kind == "win":
            B(wa - 0.02, wb + 0.02, wz0 - 0.02, wz1 + 0.02, "GlassDark", gl, gh)
        f0 = line + out_sign * 0.12
        fl, fh = sorted((line - out_sign * 0.37, f0))
        fw = 0.3
        B(wa - fw, wa + 0.03, wz0 - fw, wz1 + fw, "TrimWhite", fl, fh)
        B(wb - 0.03, wb + fw, wz0 - fw, wz1 + fw, "TrimWhite", fl, fh)
        B(wa + 0.03, wb - 0.03, wz0 - fw, wz0 + 0.03, "TrimWhite", fl, fh)
        B(wa + 0.03, wb - 0.03, wz1 - 0.03, wz1 + fw, "TrimWhite", fl, fh)
        if kind == "win":     # a meeting rail and a centre muntin: 2-over-2 sashes like ours
            ml, mh = sorted((line - out_sign * 0.37, line + out_sign * 0.02))
            B((wa + wb) / 2 - 0.08, (wa + wb) / 2 + 0.08, wz0, wz1, "TrimWhite", ml, mh)
            B(wa, wb, (wz0 + wz1) / 2 - 0.1, (wz0 + wz1) / 2 + 0.1, "TrimWhite", ml, mh)


def gable_roof(group, x0, x1, y0, y1, zeave, rise, over=1.4, thick=0.5):
    """shallow gable, ridge along x, shingles on top, white fascia; gable ends in the wall texture"""
    ym = (y0 + y1) / 2
    for (ya, yb) in ((y0 - over, ym), (y1 + over, ym)):
        za = zeave - over * rise / ((y1 - y0) / 2)
        P = lambda x, y, dz: Vector((x, y, (za + (zeave + rise - za) * (abs(y - ya) / abs(yb - ya))) + dz))
        top = [P(x0 - over, ya, thick), P(x1 + over, ya, thick), P(x1 + over, yb, thick), P(x0 - over, yb, thick)]
        bot = [P(x0 - over, yb, 0), P(x1 + over, yb, 0), P(x1 + over, ya, 0), P(x0 - over, ya, 0)]
        if (top[1] - top[0]).cross(top[2] - top[0]).z < 0:
            top = list(reversed(top))
        if (bot[1] - bot[0]).cross(bot[2] - bot[0]).z > 0:
            bot = list(reversed(bot))
        add_poly("Shingle", top, group); add_poly("TrimWhite", bot, group)
        for x in (x0 - over, x1 + over):
            s = [P(x, ya, 0), P(x, yb, 0), P(x, yb, thick), P(x, ya, thick)]
            if (s[1] - s[0]).cross(s[2] - s[0]).x * (x - (x0 + x1) / 2) < 0:
                s = list(reversed(s))
            add_poly("TrimWhite", s, group)
        e = [P(x0 - over, ya, 0), P(x1 + over, ya, 0), P(x1 + over, ya, thick), P(x0 - over, ya, thick)]
        if (e[1] - e[0]).cross(e[2] - e[0]).y * (ya - ym) < 0:
            e = list(reversed(e))
        add_poly("TrimWhite", e, group)
    return ym


def test_house(group, cx, cy, W, D, facing, siding, storeys=2, garage=True, porch=True):
    """a 1960s house on a fieldstone base: lap siding, white trim, 2-over-2 windows, a shallow gable, a front porch
    with posts, an open garage (pegboard back wall, workbench, bikes, our own banner)"""
    x0, x1, y0, y1 = cx - W / 2, cx + W / 2, cy - D / 2, cy + D / 2
    zb = GZ + 0.6
    H1 = 11.0
    zt = zb + H1 * storeys
    boxp(group, "Fieldstone", x0 - 0.3, x1 + 0.3, y0 - 0.3, y1 + 0.3, GZ - 0.2, zb)
    front = y0 if facing < 0 else y1
    back = y1 if facing < 0 else y0
    fs = -1 if facing < 0 else 1
    base = ("Fieldstone", zb + 2.4)
    gw = (x0 + 3, x0 + 15) if garage else None
    wins_g = [(x0 + 19, x0 + 25, zb + 3, zb + 9), (x1 - 11, x1 - 5, zb + 3, zb + 9)]
    door = (x0 + 28.5, x0 + 33.0, zb, zb + 8.6, "door")
    open_g = [(gw[0], gw[1], zb, zb + 8.4, "door")] if gw else []
    wall_with_windows(group, "x", fs, front, x0, x1, zb, zb + H1, wins_g + [door] + open_g, siding, base=base)
    if storeys > 1:
        wins_u = [(x0 + 4, x0 + 11, zb + 14, zb + 20), (cx - 3, cx + 3, zb + 14, zb + 20), (x1 - 11, x1 - 4, zb + 14, zb + 20)]
        wall_with_windows(group, "x", fs, front, x0, x1, zb + H1, zt, wins_u, siding)
    wall_with_windows(group, "x", -fs, back, x0, x1, zb, zt, [(x0 + 6, x0 + 13, zb + 3, zb + 9)] + ([(x1 - 13, x1 - 6, zb + 14, zb + 20)] if storeys > 1 else []), siding, base=base)
    for x, s in ((x0, -1), (x1, 1)):
        wins = [(cy - 3, cy + 3, zb + 3, zb + 9)] + ([(cy - 4, cy + 4, zb + 14, zb + 20)] if storeys > 1 else [])
        wall_with_windows(group, "y", s, x, y0 + (1 if fs > 0 else 0), y1 - (1 if fs < 0 else 0), zb, zt, wins, siding, base=base)
    # front door leaf (weathered white) recessed, a porch slab, posts and a little roof over it
    lo_, hi_ = sorted((front - fs * 0.2, front - fs * 0.37))
    boxp(group, "TrimWhite", door[0], door[1], lo_, hi_, zb, door[3], skip_bottom=False)
    if porch:
        py0, py1 = sorted((front, front + fs * 6.0))
        boxp(group, "Concrete65", door[0] - 3, door[1] + 3, py0, py1, GZ - 0.2, zb)
        for px in (door[0] - 2.6, door[1] + 2.6):
            yy = front + fs * 5.6
            boxp(group, "TrimWhite", px - 0.25, px + 0.25, yy - 0.25, yy + 0.25, zb, zb + 9.4)
        boxp(group, "Shingle", door[0] - 3.2, door[1] + 3.2, py0 - (0 if fs > 0 else 0.3), py1 + (0.3 if fs > 0 else 0), zb + 9.4, zb + 9.9, skip_bottom=False)
    # the open garage: a dark interior box with a pegboard back wall, a workbench, two bikes and our own banner
    if gw:
        gi0, gi1 = sorted((front - fs * 0.5, front - fs * 12.0))
        boxp(group, "Concrete65", gw[0], gw[1], gi0, gi1, zb - 0.02, zb, skip_bottom=True)
        wallb = gi0 if fs > 0 else gi1
        lo_, hi_ = sorted((wallb, wallb + fs * 0.1))
        boxp(group, "Pegboard", gw[0], gw[1], lo_, hi_, zb, zb + 8.4)
        for xx in (gw[0], gw[1]):
            boxp(group, "Pegboard", xx - 0.05, xx + 0.05, gi0, gi1, zb, zb + 8.4)
        quad(group, "Ceiling65", gw[0], gw[1], gi0, gi1, zb + 8.4) if False else add_poly("Ceiling65", [(gw[0], gi1, zb + 8.4), (gw[1], gi1, zb + 8.4), (gw[1], gi0, zb + 8.4), (gw[0], gi0, zb + 8.4)], group)
        bl, bh_ = sorted((wallb + fs * 0.1, wallb + fs * 2.4))
        boxp(group, "FenceWood", gw[0] + 1, gw[0] + 7, bl, bh_, zb, zb + 3.2)
    quad(group, "Ceiling65", x0, x1, y0, y1, zt)
    gable_roof(group, x0, x1, y0, y1, zt, 4.5)
    for x, sg in ((x0, -1), (x1, 1)):
        tri = [Vector((x, y0, zt)), Vector((x, y1, zt)), Vector((x, (y0 + y1) / 2, zt + 4.5 + 0.2))]
        if (tri[1] - tri[0]).cross(tri[2] - tri[0]).x * sg < 0:
            tri = list(reversed(tri))
        add_poly(siding, tri, group)
    return dict(front=front, fs=fs, garage=gw, zb=zb, door=door)


# ----------------------------------------------------------------------------------------------------------- props
def vehicle(name, style, paint, atlas):
    """own-design rounded 1960s vehicles (generic proportions), length along +X. style: sedan, wagon, truck"""
    mb = MB(name, atlas, 6.0)
    if style == "truck":
        L, W = 17.0, 6.4
        rbox(mb, (-L / 2, -W / 2, 1.3), (-L / 2 + 11.5, W / 2, 9.0), paint, r=0.35, segs=2)               # box body
        rbox(mb, (-L / 2 + 11.7, -W / 2 + 0.2, 1.3), (L / 2, W / 2 - 0.2, 5.0), paint, r=0.6, segs=3)     # cab lower
        rbox(mb, (-L / 2 + 11.7, -W / 2 + 0.4, 4.8), (L / 2 - 1.6, W / 2 - 0.4, 7.6), paint, r=0.5, segs=3)
        mb.boxr((L / 2 - 2.0, -W / 2 + 0.6, 5.2), (L / 2 - 1.45, W / 2 - 0.6, 7.2), "glass65")
        for sy in (-1, 1):
            mb.boxr((-L / 2 + 0.6, sy * (W / 2) - 0.02, 2.0), (-L / 2 + 11.0, sy * (W / 2) + 0.02, 8.6), "car_cream")
            mb.decal("decals65/truck_side", (0, sy, 0), (-L / 2 + 5.8, sy * W / 2, 5.3), 10.2, 5.1, col=None, op=1.0, kinds=["car_cream"], depth=0.1)
        wheels = [(-L / 2 + 2.6, 1.6), (-L / 2 + 8.0, 1.6), (L / 2 - 2.8, 1.6)]
        r_ = 1.5
    else:
        L, W = (15.0, 5.8) if style == "wagon" else (14.6, 5.8)
        prof = [(-L / 2, 1.0), (L / 2 - 0.3, 1.0), (L / 2, 1.4), (L / 2, 2.6), (L / 2 - 1.2, 3.2), (-L / 2 + 0.4, 3.2), (-L / 2, 2.6)]
        mb.prism(prof, "Y", -W / 2, W / 2, paint)
        for sy in (-1, 1):   # rounded fenders
            mb.tube([(-L / 2 + 0.6, sy * (W / 2 - 0.05), 2.9), (L / 2 - 0.8, sy * (W / 2 - 0.05), 2.9)], 0.3, "chrome_ext", segs=6) if False else None
            mb.boxr((-L / 2 + 0.3, sy * (W / 2) - 0.03, 2.05), (L / 2 - 0.3, sy * (W / 2) + 0.03, 2.2), "chrome_ext")      # side chrome strip
        if style == "wagon":
            cab = [(-L / 2 + 0.5, 3.15), (L / 2 - 4.6, 3.15), (L / 2 - 6.0, 5.3), (-L / 2 + 0.7, 5.3)]
        else:
            cab = [(-L / 2 + 3.2, 3.15), (L / 2 - 4.4, 3.15), (L / 2 - 6.2, 5.2), (-L / 2 + 4.8, 5.2)]
        mb.prism(cab, "Y", -W / 2 + 0.5, W / 2 - 0.5, "glass65")
        mb.boxr((cab[3][0] + 0.1, -W / 2 + 0.45, cab[3][1] - 0.1), (cab[2][0] - 0.1, W / 2 - 0.45, cab[3][1] + 0.15), paint)
        for x in (cab[0][0] + 0.15, cab[1][0] - 0.25):
            mb.boxr((x - 0.12, -W / 2 + 0.45, 3.1), (x + 0.12, W / 2 - 0.45, cab[3][1]), paint)
        for sx, k in ((1, "chrome_ext"), (-1, "chrome_ext")):
            mb.boxr((sx * L / 2 - (0.25 if sx > 0 else -0.05), -W / 2 + 0.2, 1.2), (sx * L / 2 + (0.05 if sx > 0 else 0.25), W / 2 - 0.2, 1.75), k)   # bumpers
        for sy in (-1, 1):
            mb.lathe([(0, 0), (0.35, 0), (0.35, 0.1), (0, 0.12)], 10, "lamp_lens", M=Matrix.Translation((L / 2, sy * (W / 2 - 0.9), 2.2)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
            mb.boxr((-L / 2 - 0.06, sy * (W / 2 - 0.7) - 0.25, 2.0), (-L / 2 + 0.04, sy * (W / 2 - 0.7) + 0.25, 2.8), "lamp_tail")
        wheels = [(-L / 2 + 2.8, 1.25), (L / 2 - 3.0, 1.25)]
        r_ = 1.2
    for (x, rr) in wheels:
        for sy in (-1, 1):
            M = Matrix.Translation((x, sy * (W / 2 - 0.5), rr)) @ Matrix.Rotation(math.radians(90), 4, "X")
            mb.lathe([(0, -0.5), (r_, -0.5), (r_ + 0.06, -0.35), (r_ + 0.06, 0.35), (r_, 0.5), (0, 0.5)], 12, "tyre65", M=M)
            s_ = 0.52 if sy > 0 else -0.52
            mb.lathe([(0, 0.0), (r_ * 0.62, 0.0), (r_ * 0.62, 0.04), (0, 0.04)], 12, "whitewall", M=Matrix.Translation((x, sy * (W / 2 - 0.5) + s_ * 1.0 - (0.0), rr)) @ Matrix.Rotation(math.radians(-90 * sy), 4, "X"))
    mb.decal("decals65/fx_blot", (0, 0, 1), (0, 0, 6.0), 6.0, 4.0, col=None, op=0.5, kinds=[paint], depth=6.0)
    return finish(mb)


def sandbags(name, L, rows=4, curve=0.0):
    """a sandbag emplacement wall: staggered courses of rounded burlap bags along x (length L), optional bend"""
    mb = MB(name, "Sandbags", rows * 0.6)
    for r in range(rows):
        n = int(L / 1.6)
        for i in range(n):
            x = -L / 2 + (i + 0.5 + (0.5 if r % 2 else 0)) * (L / n)
            if x > L / 2 - 0.6:
                continue
            y = curve * (x / (L / 2)) ** 2
            fs = rbox(mb, (-0.8, -0.55, 0.0), (0.8, 0.55, 0.62), "burlap", r=0.22, segs=2)
            xf_ = Matrix.Translation((x, y, r * 0.55)) @ Matrix.Rotation(math.radians(R.uniform(-6, 6)), 4, "Z")
            vs = {v for f in fs for v in f.verts}
            for v in vs:
                v.co = xf_ @ v.co
    return finish(mb)


def sign_post(name, img, w=4.0, h=2.5, post_h=6.0, tilt=0.0):
    mb = MB(name, "Signs", post_h + h)
    for sx in (-1, 1):
        mb.boxr((sx * (w / 2 - 0.3) - 0.15, -0.15, GZ - 0.3), (sx * (w / 2 - 0.3) + 0.15, 0.15, GZ + post_h + h - 0.2), "post_wood")
    fs = mb.boxr((-w / 2, -0.25, GZ + post_h), (w / 2, -0.15, GZ + post_h + h), "sign_board")
    mb.decal("decals65/" + img, (0, -1, 0), (0, -0.25, GZ + post_h + h / 2), w, h, col=None, op=1.0, kinds=["sign_board"], depth=0.1)
    mb.decal("decals65/" + img, (0, 1, 0), (0, -0.15, GZ + post_h + h / 2), w, h, col=None, op=0.0, kinds=["sign_board"], depth=0.05) if False else None
    if tilt:
        for v in mb.bm.verts:
            v.co = Matrix.Rotation(math.radians(tilt), 4, "Y") @ v.co
    return finish(mb)


def mast(name, h, base_w, cabin=True):
    """steel lattice instrument mast (our own design): 4 tapering legs, X bracing every 12, a boxy instrument cabin with
    a railed deck near the top, antennae and a cable reel at the foot"""
    mb = MB(name, "Mast", h)
    top_w = base_w * 0.35
    levels = int(h / 12)
    def leg(sx, sy, z):
        w = base_w + (top_w - base_w) * (z / h)
        return Vector((sx * w / 2, sy * w / 2, GZ + z))
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for (sx, sy) in corners:
        mb.tube([leg(sx, sy, 0), leg(sx, sy, h)], 0.45, "steel_mast", segs=4)
    for k in range(levels):
        za, zb_ = k * 12.0, min(h, (k + 1) * 12.0)
        for i in range(4):
            c0, c1 = corners[i], corners[(i + 1) % 4]
            mb.tube([leg(*c0, za), leg(*c1, zb_)], 0.18, "steel_mast", segs=4)
            mb.tube([leg(*c1, za), leg(*c0, zb_)], 0.18, "steel_mast", segs=4)
            mb.tube([leg(*c0, zb_), leg(*c1, zb_)], 0.2, "steel_mast", segs=4)
    if cabin:
        cz = h - 14.0
        w = base_w + (top_w - base_w) * (cz / h) + 6.0
        mb.boxr((-w / 2, -w / 2, GZ + cz), (w / 2, w / 2, GZ + cz + 8.0), "cabin_paint")
        mb.boxr((-w / 2 - 0.05, -w / 2 - 0.05, GZ + cz + 3.5), (w / 2 + 0.05, w / 2 + 0.05, GZ + cz + 5.5), "glass65")
        mb.boxr((-w / 2 - 1.5, -w / 2 - 1.5, GZ + cz - 0.4), (w / 2 + 1.5, w / 2 + 1.5, GZ + cz), "steel_mast")
        mb.boxr((-w / 2 - 1.0, -w / 2 - 1.0, GZ + cz + 8.0), (w / 2 + 1.0, w / 2 + 1.0, GZ + cz + 8.6), "steel_mast")
    for i, (dx, dy, hh) in enumerate(((0, 0, 14.0), (1.5, 0.5, 9.0), (-1.2, -0.8, 7.0))):
        mb.tube([(dx, dy, GZ + h), (dx, dy, GZ + h + hh)], 0.15, "steel_mast", segs=4)
    mb.lathe([(0, 0), (1.6, 0), (1.6, 1.2), (0, 1.2)], 12, "post_wood", M=Matrix.Translation((base_w * 0.9, 0, GZ)))
    return finish(mb)


def dry_tree(name, seed, h, dead=False):
    """a dry desert tree (baked atlas so Import 3D keeps the colour): leaning trunk, a few branches; sparse dry leaf
    clumps, or bare for a dead fruit tree"""
    rng = random.Random(seed)
    mb = MB(name, "DryTrees", h)
    lean = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0))
    top = Vector((0, 0, GZ + h * 0.5)) + lean
    mb.tube([(0, 0, GZ - 0.3), tuple(top)], 0.45, "bark_dry", segs=6)
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi)
        e = top + Vector((math.cos(a) * rng.uniform(2.5, 4.5), math.sin(a) * rng.uniform(2.5, 4.5), rng.uniform(1.5, h * 0.45)))
        mid = top.lerp(e, 0.5) + Vector((0, 0, 0.8))
        mb.tube([tuple(top), tuple(mid), tuple(e)], 0.18, "bark_dry", segs=5)
        if not dead:
            r = rng.uniform(1.4, 2.4)
            ellipsoid(mb, tuple(e), (r, r, r * 0.6), "leaf_dry" if i % 2 else "leaf_dry2", segs=7, rings=4)
    return finish(mb)


def trellis(name):
    mb = MB(name, "Signs", 9.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.boxr((sx * 2.2 - 0.12, sy * 0.8 - 0.12, GZ), (sx * 2.2 + 0.12, sy * 0.8 + 0.12, GZ + 7.0), "post_wood")
    pts = [(2.2 * math.cos(math.pi * i / 10), 0, GZ + 7.0 + 1.6 * math.sin(math.pi * i / 10)) for i in range(11)]
    for sy in (-0.8, 0.8):
        mb.tube([(p[0], sy, p[2]) for p in pts], 0.12, "post_wood", segs=5)
    for i in range(1, 10):
        p = pts[i]
        mb.tube([(p[0], -0.8, p[2]), (p[0], 0.8, p[2])], 0.07, "post_wood", segs=4)
    for k in range(6):
        ellipsoid(mb, (R.uniform(-2.2, 2.2), R.uniform(-0.8, 0.8), GZ + R.uniform(5.5, 8.4)), (0.6, 0.5, 0.5), "leaf_dry2", segs=6, rings=4)
    return finish(mb)


def bike(name):
    mb = MB(name, "Signs", 3.4)
    for x in (-1.6, 1.6):
        mb.revolve([(1.0, -0.06), (1.12, -0.06), (1.12, 0.06), (1.0, 0.06)], 16, "tyre65", M=Matrix.Translation((x, 0, 1.12)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    mb.tube([(-1.6, 0, 1.12), (-0.3, 0, 2.4), (1.2, 0, 2.6), (1.6, 0, 1.12)], 0.07, "car_olive", segs=5)
    mb.tube([(-0.3, 0, 2.4), (0.2, 0, 1.12), (-1.6, 0, 1.12)], 0.07, "car_olive", segs=5)
    mb.tube([(1.2, 0, 2.6), (1.2, 0, 3.2), (1.5, 0, 3.3)], 0.05, "chrome_ext", segs=4)
    return finish(mb)


def banner(name):
    """a hanging cloth banner of our own design (olive field, a cream band, a mustard star): not a flag with a symbol"""
    mb = MB(name, "Signs", 4.0)
    pts = [(-2.5 + 5.0 * i / 10, 0.08 * math.sin(i * 1.3)) for i in range(11)]
    poly = [(x, y - 0.03) for x, y in pts] + [(x, y + 0.03) for x, y in reversed(pts)]
    mb.prism(poly, "Z", 0.0, 3.2, "banner")
    mb.decal("decals65/pennant", (0, -1, 0), (0, -0.1, 1.6), 5.0, 2.5, col=None, op=1.0, kinds=["banner"], depth=0.2)
    mb.tube([(-2.7, 0, 3.3), (2.7, 0, 3.3)], 0.06, "post_wood", segs=5)
    return finish(mb)


def pole(name, x, y, h=26.0):
    """wooden power pole: crossarm, insulators, a transformer can (installer PLAIN 'Pole')"""
    mb = MB(name, "Plain:Pole", h)
    mb.lathe([(0, GZ - 0.3), (0.45, GZ - 0.3), (0.32, GZ + h), (0, GZ + h)], 8, "stem")
    mb.boxr((-0.2, -3.2, GZ + h - 1.6), (0.2, 3.2, GZ + h - 1.1), "stem")
    for yy in (-2.8, 0.0, 2.8):
        mb.lathe([(0, 0), (0.12, 0), (0.1, 0.45), (0, 0.45)], 6, "stem", M=Matrix.Translation((0, yy, GZ + h - 1.1)))
    mb.lathe([(0, 0), (0.7, 0), (0.7, 2.0), (0, 2.0)], 8, "stem", M=Matrix.Translation((0.0, 0.9, GZ + h - 5.0)))
    o = finish(mb); o.location = (x, y, 0)
    return o


def wires(name, poles_xy, hz, offsets=(-2.8, 0.0, 2.8), sag=2.2, house_drop=None):
    mb = MB(name, "Plain:Wire", 2.0)
    for ox in offsets:
        for (xa, ya), (xb, yb) in zip(poles_xy, poles_xy[1:]):
            pts = [(xa + (xb - xa) * i / 8, ya + ox + (yb - ya) * i / 8, hz - sag * 4 * (i / 8) * (1 - i / 8)) for i in range(9)]
            mb.tube(pts, 0.07, "rubber65", segs=4)
    if house_drop:
        (xa, ya, za), (xb, yb, zb) = house_drop
        pts = [(xa + (xb - xa) * i / 8, ya + (yb - ya) * i / 8, za + (zb - za) * i / 8 - 1.6 * 4 * (i / 8) * (1 - i / 8)) for i in range(9)]
        mb.tube(pts, 0.06, "rubber65", segs=4)
    return finish(mb)


def mesas(group):
    """a ring of flat-topped mesas and buttes at 450-820 studs: steep sloped prisms in the strata texture"""
    rng = random.Random(7)
    for i in range(22):
        a = 2 * math.pi * i / 22 + rng.uniform(-0.08, 0.08)
        d = rng.uniform(470, 800)
        w = rng.uniform(60, 180); dd = rng.uniform(40, 90); hh = rng.uniform(28, 75)
        cx, cy = d * math.cos(a), d * math.sin(a)
        t = Vector((-math.sin(a), math.cos(a), 0)); n = Vector((math.cos(a), math.sin(a), 0))
        inset = rng.uniform(0.18, 0.3)
        def P(u, v, z):
            return Vector((cx, cy, 0)) + t * u + n * v + Vector((0, 0, z))
        lo = [P(-w / 2, -dd / 2, GZ - 2), P(w / 2, -dd / 2, GZ - 2), P(w / 2, dd / 2, GZ - 2), P(-w / 2, dd / 2, GZ - 2)]
        hi = [P(-w / 2 * (1 - inset), -dd / 2 * (1 - inset), GZ + hh), P(w / 2 * (1 - inset), -dd / 2 * (1 - inset), GZ + hh),
              P(w / 2 * (1 - inset), dd / 2 * (1 - inset), GZ + hh), P(-w / 2 * (1 - inset), dd / 2 * (1 - inset), GZ + hh)]
        add_poly("MesaRock", hi, group)
        for k in range(4):
            q = [lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]]
            nn = (q[1] - q[0]).cross(q[3] - q[0])
            c = sum(q, Vector()) / 4 - Vector((cx, cy, c_z := 0))
            if nn.dot(Vector((c.x, c.y, 0))) < 0:
                q = list(reversed(q))
            add_poly("MesaRock", q, group)


# ----------------------------------------------------------------------------------------------------------- sky
def sky_images():
    """hazy desert sky (procedural): cream-tan horizon, pale blue-grey above, faint high streaks; Roblox Sky faces"""
    out = os.path.join(TEX, "sky"); os.makedirs(out, exist_ok=True)
    def save(name, arr):          # arr rows top-first, 0..255 RGB
        h, w = arr.shape[:2]
        a = np.concatenate([np.clip(arr[::-1], 0, 255) / 255.0, np.ones((h, w, 1))], axis=2).astype(np.float32)
        img = bpy.data.images.new(name, w, h, alpha=False)
        img.pixels.foreach_set(a.ravel())
        img.filepath_raw = os.path.join(out, name + ".png"); img.file_format = "PNG"; img.save()
    n = 1024
    yy = np.linspace(0, 1, n)[:, None]        # 0 = top row
    hor = np.array([226, 210, 176], np.float32); mid = np.array([206, 204, 190], np.float32); top = np.array([168, 182, 190], np.float32)
    t = 1 - yy
    col_ = np.where(t[..., None] < 0.35, hor + (mid - hor) * (t[..., None] / 0.35), mid + (top - mid) * ((t[..., None] - 0.35) / 0.65))
    img = np.repeat(col_, n, axis=1)
    rng = np.random.default_rng(3)
    w = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    g = np.exp(-((fx * 8) ** 2 + (fy * 60) ** 2) * 2)
    streak = np.real(np.fft.ifft2(np.fft.fft2(w) * g)); streak = (streak - streak.min()) / (streak.max() - streak.min())
    mask = np.clip((t - 0.35) * 3, 0, 1) * np.clip((0.95 - t) * 4, 0, 1)
    img = img + (np.array([240, 236, 226])[None, None, :] - img) * (np.clip(streak - 0.55, 0, 1) * 1.4 * mask)[..., None]
    save("sky_side", img)
    save("sky_up", np.full((256, 256, 3), top, np.float32))
    save("sky_dn", np.full((256, 256, 3), hor * 0.92, np.float32))


# ----------------------------------------------------------------------------------------------------------- main
PLAIN_KIND = {"Pole": (96, 78, 60), "Wire": (20, 20, 20)}
PLAIN_COL = {"GlassDark": (40, 46, 50)}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sky_images()
    ground()
    # our side / back fences (weathered boards), a picket fence along the front with gaps for the path and the drive
    board_fence("Fences", -46.0, -40.0, -46.0, 75.0); board_fence("Fences", 46.0, -40.0, 46.0, 75.0)
    board_fence("Fences", -46.0, 75.0, 46.0, 75.0)
    board_fence("Fences", -46.0, -40.0, -41.0, -40.0); board_fence("Fences", 41.0, -40.0, 46.0, -40.0)
    for (x0, x1) in ((-44.0, 0.0), (6.0, 15.5), (30.5, 44.0)):
        picket("Yard", x0, -55.3, x1, -55.3)
    # the second test house across the cul-de-sac (mint), its picket fence and trellis; ranch neighbours (butter, salmon)
    th = test_house("Across", 0.0, -120.0, 66.0, 40.0, 1, "SidingMint")
    picket("Fences", -46.0, -92.0, -3.0, -92.0); picket("Fences", 3.0, -92.0, 46.0, -92.0)
    test_house("AcrossW", -90.0, -122.0, 62.0, 36.0, 1, "SidingButter", storeys=1)
    test_house("AcrossE", 90.0, -122.0, 62.0, 36.0, 1, "SidingSalmon", storeys=1, garage=False)
    test_house("NeighbourW", -86.0, -6.0, 60.0, 38.0, -1, "SidingButter", storeys=1, garage=False, porch=False)
    test_house("NeighbourE", 86.0, -6.0, 60.0, 38.0, -1, "SidingSalmon", storeys=2, garage=False, porch=False)
    test_house("BehindW", -40.0, 108.0, 58.0, 34.0, 1, "SidingMint", storeys=1, garage=False, porch=False)
    test_house("BehindE", 40.0, 108.0, 58.0, 34.0, 1, "SidingWhite", storeys=1, garage=False, porch=False)
    mesas("Mesas")
    obs = []
    # baked props
    props = []
    def add(o, loc, rz=0.0):
        o.location = loc; o.rotation_euler = (0, 0, math.radians(rz)); props.append(o); return o
    vehicles = [vehicle("Car_Wagon", "wagon", "car_mint", "Car1"), vehicle("Car_Sedan", "sedan", "car_butter", "Car2"),
                vehicle("Car_SedanSalmon", "sedan", "car_salmon", "Car3"), vehicle("Truck_Dairy", "truck", "car_olive", "Car4")]
    place = {"Car_Wagon": ((23.0, -43.0, GZ + 0.18), 90), "Car_Sedan": ((-34.0, -64.0, GZ + 0.12), 0),
             "Car_SedanSalmon": ((-22.0, -106.0, GZ + 0.18), -84), "Truck_Dairy": ((-70.0, -71.5, GZ + 0.12), 180)}
    for o in vehicles:
        add(o, *place[o.name])
    sb = [sandbags("Sandbags_1", 14.0, rows=4, curve=1.5), sandbags("Sandbags_2", 10.0, rows=3, curve=-1.0), sandbags("Sandbags_3", 12.0, rows=5)]
    add(sb[0], (34.0, -86.0, GZ + 0.0), 10); add(sb[1], (-56.0, 60.0, GZ + 0.15), 75); add(sb[2], (120.0, -40.0, GZ), -20)
    signs = [sign_post("Sign_Restricted", "sign_restricted", 5.0, 3.1, 4.5), sign_post("Sign_Danger", "sign_danger", 5.0, 3.1, 4.5, tilt=4),
             sign_post("Sign_RoadClosed", "sign_road", 5.0, 3.1, 3.5), sign_post("Sign_Restricted2", "sign_restricted", 4.0, 2.5, 4.0, tilt=-6)]
    add(signs[0], (40.0, -83.0, 0), 180); add(signs[1], (-30.0, 82.0, 0), 0); add(signs[2], (-120.0, -60.0, 0), 160); add(signs[3], (60.0, 82.0, 0), 10)
    add(trellis("Trellis_Across"), (0.0, -94.0, 0), 0)
    add(trellis("Trellis_Ours"), (-10.0, 46.0, 0), 90)
    gw = th["garage"]
    gy = th["front"] - th["fs"] * 9.0
    add(bike("Bike_1"), (gw[0] + 9.0, gy, th["zb"] + 3.2), 0)
    add(bike("Bike_2"), (gw[0] + 10.5, gy + 0.6, th["zb"] + 3.0), 0)
    add(banner("Banner_Garage"), ((gw[0] + gw[1]) / 2, th["front"] - th["fs"] * 11.0, th["zb"] + 4.6), 0 if th["fs"] < 0 else 180)
    for i, (x, y, h, dead) in enumerate(((-30, -46, 13, False), (36, 62, 11, True), (-62, -96, 14, False), (60, -98, 12, True),
                                         (-118, -48, 15, False), (118, -52, 10, True), (-20, 92, 12, False), (150, -95, 13, False))):
        add(dry_tree(f"DryTree_{i + 1:02d}", 300 + i, h, dead), (x, y, 0), R.uniform(0, 360))
    add(mast("Mast_South", 128.0, 18.0), (34.0, -360.0, 0), 20)        # framed by the foyer's feature window (south)
    add(mast("Mast_NE", 96.0, 14.0), (260.0, 250.0, 0), -15)            # for the north / east windows
    # test dummies outside (from the furniture masters): leaning on the across house's picket fence, on its porch step
    import dress65
    dm = dress65.load_masters(os.path.join(ROOT, "house_furniture.blend"), {"D65_Dummy_Lean", "D65_Dummy_SitB", "D65_Dummy_SitA"})
    if dm:
        def dmy(m, name, loc, rz):
            o = bpy.data.objects.new(name, dm[m].data); coll("Exterior").objects.link(o)
            o.location = loc; o.rotation_euler = (0, 0, math.radians(rz)); o["atlas"] = "Dummies"; obs.append(o)
        dmy("D65_Dummy_Lean", "Dummy_Ext_Fence", (-16.0, -90.85, GZ), 180.0)     # hands on the fence top (3.45 = picket 3.5)
        dmy("D65_Dummy_SitB", "Dummy_Ext_Porch", (30.5, -93.6, GZ + 1.6 + 0.3), 0.0)
        dmy("D65_Dummy_Lean", "Dummy_Ext_Truck", (-63.5, -66.4, GZ + 0.12), 90.0)
    # power poles along the far sidewalk, wires, a service drop to our front wall
    poles = [(x, -78.0) for x in range(-200, 41, 40)]
    for i, (x, y) in enumerate(poles):
        obs.append(pole(f"PowerPole_{i + 1:02d}", x, y))
    obs.append(wires("PowerWires", poles, GZ + 26.0 - 0.7, house_drop=((0.0, -78.0, GZ + 26.0 - 2.0), (-8.0, -31.2, 24.0))))
    back_poles = [(x, 82.0) for x in range(-160, 161, 40)]
    for i, (x, y) in enumerate(back_poles):
        obs.append(pole(f"PowerPoleBack_{i + 1:02d}", x, y))
    obs.append(wires("PowerWiresBack", back_poles, GZ + 26.0 - 0.7))
    atl_files = {}
    if not NOBAKE:
        setup_cycles()
        groups = {}
        for o in props:
            groups.setdefault(o["atlas"], []).append(o)
        for atl, objs in groups.items():
            saved = [(o, o.location.copy(), o.rotation_euler.copy()) for o in objs]
            x = 0.0
            for o in objs:
                o.rotation_euler = (0, 0, 0); o.location = (0, 0, 0)
                bpy.context.view_layer.update()
                lo, hi = bbox([o])
                o.location = (9000 + x - lo.x, 9000, 0)
                bpy.context.view_layer.update()
                x += (hi.x - lo.x) + 6
            imgs = bake_atlas(atl, objs)
            finalize(objs, atlas_material(atl, imgs))
            atl_files[atl] = {p: f"tex/{PREFIX}{atl}_{p}.png" for p in imgs}
            for o, l, r in saved:
                o.location = l; o.rotation_euler = r
            bpy.context.view_layer.update()
    obs += props
    for o in obs:
        if str(o.get("atlas", "")).startswith("Plain:"):
            k = o["atlas"].split(":", 1)[1]
            me = o.data
            me.materials.clear(); me.materials.append(plain_material("H_" + k, PLAIN_KIND[k], 0.7))
            for p in me.polygons:
                p.material_index = 0
            for nm in [l.name for l in me.uv_layers if l.name != "UVMap"]:
                me.uv_layers.remove(me.uv_layers[nm])
    log("deduped", bh.dedupe_shell(), "hidden back-to-back faces")
    groups = []
    for (grp, mat), polys in sorted(EXT.items()):
        if mat in PLAIN_COL:
            ob = tiled_object(f"Ext_{grp}_{mat}", "TrimWhite", polys)
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
    man = dict(note="1965 desert test site. Same coordinates as house_shell.json (layout plan; outside ground z = -1). All art, "
                    "CanCollide off, unreachable. Sky: tex/sky/sky_side.png for SkyboxBk/Ft/Lf/Rt, sky_up.png Up, sky_dn.png Dn. "
                    "The v1 H_Trees (green trees) should NOT be imported with this exterior: its dry trees are DryTree_XX here.",
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
