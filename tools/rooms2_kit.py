"""Tacticals rooms pass 2: Shop + Armory + their corridors (RIVALS style, Tacticals palette). Own geometry only.

Run inside Blender 5.2 (Blender MCP) with kit/rooms2_kit.blend open:
    exec(open(r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms2_kit.py").read())
Reuses tools/hub_kit.py (materials, box/prism/lathe/cyl/rod, Wall frames, railing, props, finalize) so the rooms match the hub.
Studio coordinates (x east, y up, z north, 1 unit = 1 stud); finalize() converts to Blender Z-up like hub1.
Mesh = <piece>__<material>. Pieces: S_* shop, A_* armory, C_CorrN / C_CorrS corridors, K_Scale2 / K_Marker2 markers.
Never calls read_homefile.
"""
import bpy, bmesh, math, os, json, re
from mathutils import Vector, Matrix

_HUB = r"C:/Users/aroki/Documents/tacticals_rebuild/tools/hub_kit.py"
exec(open(_HUB).read().split('if __name__ == "__main__" or True:')[0], globals())

KIT = ROOT + "/kit/"

# ------------------------------------------------------------------ room frames (survey: layout.md, slice_y4, plan_*.png)
# Shop interior x -30..30, z 69..110.5, ceiling 13.5. Front wall (door) face z 69, doorway 11 wide through z 64..69.
# Armory interior x -31..31, z -112.5..-67, ceiling 22. Front wall face z -67, doorway through z -67..-64.
# Corridors x -5.4..5.4 (frames 4.9 -> 9.8 clear), z 49..64 / -64..-49, clear 12.2.
SH = dict(x0=-30.0, x1=30.0, zf=69.0, zb=110.5, H=13.5)
AR = dict(x0=-31.0, x1=31.0, zf=-67.0, zb=-112.5, H=22.0)
TW = 2.0  # room wall thickness behind the face

# ------------------------------------------------------------------ local-frame box (for rifles and props in any orientation)
def lbox(piece, mat, O, eu, ev, ew, u0, u1, v0, v1, w0, w1, bev=0.05, seg=1):
    O = Vector(O); eu = Vector(eu); ev = Vector(ev); ew = Vector(ew)
    a = O + eu * u0 + ev * v0 + ew * w0
    b = O + eu * u1 + ev * v1 + ew * w1
    box(piece, mat, a.x, b.x, a.y, b.y, a.z, b.z, bev, seg)

def rifle(piece, O, eu, ev, ew, kind=0):
    """Stylised service rifle, ~4.4 long: stock, grip, receiver, mag, handguard, barrel, optic. u along barrel, v up."""
    acc_mat = "drum_olive" if kind % 2 == 0 else "case_dark"
    lbox(piece, "case_dark", O, eu, ev, ew, 0.0, 1.05, -0.32, 0.30, -0.13, 0.13, 0.06)         # stock
    lbox(piece, "dark_metal", O, eu, ev, ew, 0.0, 0.12, -0.36, 0.34, -0.15, 0.15, 0.03)        # butt pad
    lbox(piece, "dark_metal", O, eu, ev, ew, 1.0, 2.55, -0.26, 0.33, -0.15, 0.15, 0.05)        # receiver
    lbox(piece, "case_dark", O, eu, ev, ew, 1.35, 1.62, -0.95, -0.26, -0.12, 0.12, 0.05)       # grip
    lbox(piece, acc_mat, O, eu, ev, ew, 1.85, 2.25, -1.05, -0.26, -0.11, 0.11, 0.05)           # magazine
    lbox(piece, acc_mat, O, eu, ev, ew, 2.5, 3.55, -0.22, 0.26, -0.16, 0.16, 0.06)             # handguard
    lbox(piece, "dark_metal", O, eu, ev, ew, 3.5, 4.4, -0.06, 0.08, -0.07, 0.07, 0.02)         # barrel
    lbox(piece, "dark_metal", O, eu, ev, ew, 4.25, 4.45, -0.1, 0.12, -0.1, 0.1, 0.03)          # muzzle
    if kind % 3 != 2:
        lbox(piece, "dark_metal", O, eu, ev, ew, 1.3, 2.35, 0.36, 0.62, -0.1, 0.1, 0.05)       # optic
        lbox(piece, "trim_metal", O, eu, ev, ew, 1.28, 1.36, 0.36, 0.66, -0.12, 0.12, 0.02)    # optic ring

def ammo_can(piece, cx, cy, cz, along_x=True):
    dx, dz = (0.75, 0.38) if along_x else (0.38, 0.75)
    box(piece, "crate_green", cx - dx, cx + dx, cy, cy + 0.85, cz - dz, cz + dz, 0.06)
    box(piece, "dark_metal", cx - dx - 0.03, cx + dx + 0.03, cy + 0.78, cy + 0.95, cz - dz - 0.03, cz + dz + 0.03, 0.03)
    box(piece, "label_cream", cx - 0.25, cx + 0.25, cy + 0.35, cy + 0.6, cz - dz - 0.02, cz + dz + 0.02, 0.0)
    if along_x:
        box(piece, "dark_metal", cx - 0.35, cx + 0.35, cy + 0.95, cy + 1.05, cz - 0.06, cz + 0.06, 0.02)
    else:
        box(piece, "dark_metal", cx - 0.06, cx + 0.06, cy + 0.95, cy + 1.05, cz - 0.35, cz + 0.35, 0.02)

# ------------------------------------------------------------------ banded wall zones for low (shop) and tall (armory) rooms
def zones(W, piece, s0, s1, H, ymin=0.0):
    T = TW
    if s1 - s0 < 0.05:
        return
    if ymin < 7:
        W.box(piece, "wall_kick", s0, s1, max(0.0, ymin), 7.0, -T, 0.3, 0.12)
        if ymin <= 0:
            W.box(piece, "trim_metal", s0, s1, 0.0, 0.8, 0.25, 0.62, 0.1)
    if ymin < 10:
        W.box(piece, "band_olive", s0, s1, 7.1, 9.9, -T, 0.5, 0.12)
        W.box(piece, "trim_metal", s0, s1, 6.85, 7.15, -T, 0.62, 0.06)
        W.box(piece, "trim_metal", s0, s1, 9.85, 10.15, -T, 0.62, 0.06)
    if H < 16:  # shop: body 10..12.2, canted cornice 12.2..13.5
        W.box(piece, "wall_body", s0, s1, max(10.0, ymin), 12.2, -T, 0.0, 0.1)
        prof = [(-T, 12.2), (0.0, 12.2), (0.45, 12.75), (1.0, 13.15), (1.0, 13.5), (-T, 13.5)]
        W.prism(piece, "wall_light", prof, s0, s1)
        W.box(piece, "trim_metal", s0, s1, 12.1, 12.3, -T, 0.15, 0.04)
    else:       # armory: body 10..15.5, dark band, ribbed upper, cornice 20.2..22
        W.box(piece, "wall_body", s0, s1, max(10.0, ymin), 15.5, -T, 0.0, 0.1)
        W.box(piece, "wall_dark", s0, s1, max(15.5, ymin), 16.6, -T, 0.25, 0.1)
        W.box(piece, "trim_light", s0, s1, 16.45, 16.75, -T, 0.42, 0.06)
        W.box(piece, "wall_upper", s0, s1, max(16.6, ymin), 20.2, -T, 0.0, 0.1)
        prof = [(-T, 20.2), (0.0, 20.2), (0.6, 20.9), (1.5, 21.5), (1.5, 22.0), (-T, 22.0)]
        W.prism(piece, "wall_light", prof, s0, s1)
        W.box(piece, "trim_metal", s0, s1, 20.1, 20.3, -T, 0.15, 0.04)

def plates(W, piece, s0, s1, y0, y1, d0=0.0, d1=0.55, cols=2):
    """Proud concrete panels (2 x 2 per bay by default)."""
    w = s1 - s0
    if w < 3:
        return
    step = (w - 2.2) / cols
    ym = (y0 + y1) / 2
    for i in range(cols):
        a = s0 + 1.1 + i * step + 0.12; b = a + step - 0.24
        for (c, d) in ((y0, ym - 0.12), (ym + 0.12, y1)):
            W.box(piece, "wall_plate", a, b, c, d, d0, d1, 0.1)

def pier(W, piece, s, H, light=None):
    """Concrete pilaster with metal plinth, olive band wrap, metal capital that carries the ceiling beam."""
    W.box(piece, "wall_light", s - 1.1, s + 1.1, 0.0, H, -TW, 1.2, 0.25, 2)
    W.box(piece, "trim_metal", s - 1.3, s + 1.3, 0.0, 1.6, -TW, 1.45, 0.12)
    W.box(piece, "band_olive", s - 1.2, s + 1.2, 7.1, 9.9, -TW, 1.35, 0.1)
    W.box(piece, "trim_metal", s - 1.35, s + 1.35, H - 1.9, H - 1.2, -TW, 1.6, 0.1)
    if light == "big":
        wall_light(W, s, 1.2, 13.4, piece=piece.split("_")[0] + "_Lights")
    elif light == "small":
        small_light(W, s, 1.2, 11.15, piece=piece.split("_")[0] + "_Lights")

def small_light(W, s, d, yc, piece):
    """Short capsule (fits the 13.5 shop): metal housing, Neon capsule, one dark strap."""
    W.box(piece, "trim_metal", s - 0.75, s + 0.75, yc - 1.05, yc + 1.05, d - 0.1, d + 0.4, 0.15, 2)
    W.box(piece, "neon_lamp", s - 0.45, s + 0.45, yc - 0.8, yc + 0.8, d + 0.25, d + 0.65, 0.2, 3)
    W.box(piece, "dark_metal", s - 0.56, s + 0.56, yc - 0.12, yc + 0.12, d + 0.2, d + 0.75, 0.04)

def downlight(piece, cx, cz, y, r=1.1):
    """Round ceiling housing = the home of a RoomLight Part."""
    cyl(piece, "trim_metal", cx, cz, r, y, y + 0.55, seg=24, bev=0.08)
    cyl(piece, "dark_metal", cx, cz, r + 0.15, y + 0.4, y + 0.6, seg=24, bev=0.04)
    cyl(piece, "neon_lamp", cx, cz, r * 0.72, y - 0.08, y + 0.02, seg=24, bev=0.0)

def sign_board(piece, W, s0, s1, y0, y1, d=0.2):
    W.box(piece, "sign_board", s0, s1, y0, y1, d, d + 0.7, 0.15, 2)
    e = 0.22
    for (a, b, c, dd) in ((s0, s1, y0, y0 + e), (s0, s1, y1 - e, y1), (s0, s0 + e, y0, y1), (s1 - e, s1, y0, y1)):
        W.box(piece, "neon_olive", a, b, c, dd, d + 0.7, d + 0.82, 0.0)

def display_niche(W, piece, sc, w=7.0, y0=1.2, y1=6.6, items="cases"):
    """Proud display case below the band: concrete frame, dark back, lamp line, metal shelves with stock on them."""
    a, b = sc - w / 2, sc + w / 2
    W.box(piece, "wall_light", a - 0.7, a, 0.0, y1 + 0.6, 0.0, 1.6, 0.18, 2)
    W.box(piece, "wall_light", b, b + 0.7, 0.0, y1 + 0.6, 0.0, 1.6, 0.18, 2)
    W.box(piece, "wall_light", a - 0.7, b + 0.7, y1, y1 + 0.6, 0.0, 1.6, 0.18, 2)
    W.box(piece, "wall_light", a - 0.7, b + 0.7, 0.0, y0, 0.0, 1.6, 0.12)
    W.box(piece, "trim_metal", a - 0.8, b + 0.8, y0 - 0.12, y0, 0.0, 1.75, 0.04)
    W.box(piece, "dark_metal", a, b, y0, y1, 0.3, 0.45, 0.0)
    W.box(piece, "neon_lamp", a + 0.3, b - 0.3, y1 - 0.25, y1 - 0.05, 0.6, 1.2, 0.0)
    W.box(piece, "trim_metal", a - 0.05, b + 0.05, y1 - 0.35, y1 - 0.25, 0.45, 1.3, 0.02)
    ys = [y0 + (y1 - y0) * t for t in (0.42,)]
    for yy in ys:
        W.box(piece, "trim_metal", a, b, yy - 0.08, yy + 0.08, 0.45, 1.45, 0.03)
    W.box(piece, "label_cream", sc - 1.0, sc + 1.0, 0.35, 0.8, 1.6, 1.68, 0.0)
    # stock on the shelves
    for k, yy in enumerate([y0] + [v + 0.08 for v in ys]):
        n = 3
        for i in range(n):
            s = a + (i + 0.5) * w / n
            p = W.p(s, yy, 0.95)
            if items == "cases":
                if (i + k) % 2 == 0:
                    ammo_can(piece, p[0], p[1], p[2], along_x=(W.along == "x"))
                else:
                    sz = 0.9
                    q0 = W.p(s - sz, yy, 0.55); q1 = W.p(s + sz, yy + 1.3, 1.35)
                    box(piece, "crate_green", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.08)
                    q0 = W.p(s - 0.4, yy + 0.7, 1.35); q1 = W.p(s + 0.4, yy + 1.0, 1.39)
                    box(piece, "label_cream", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.0)
            else:  # rifles lying on the shelf, barrel along the wall
                eu = Vector(W.p(1, 0, 0)) - Vector(W.p(0, 0, 0))
                ew = Vector(W.p(0, 0, 1)) - Vector(W.p(0, 0, 0))
                if i == 1:
                    rifle(piece, W.p(s - 2.2, yy + 1.15, 0.95), eu, (0, 1, 0), ew, kind=i + k)

def shelving(W, piece, s0, s1, depth=1.8, levels=(0.3, 2.9, 5.5), top=6.7, seed=0):
    """Metal storage shelving against a wall with crates / cans / drums on it."""
    n = max(1, int(round((s1 - s0) / 4.0)))
    for i in range(n + 1):
        s = s0 + (s1 - s0) * i / n
        W.box(piece, "beam_metal", s - 0.15, s + 0.15, 0.0, top, 0.05, 0.35, 0.04)
        W.box(piece, "beam_metal", s - 0.15, s + 0.15, 0.0, top, depth - 0.3, depth, 0.04)
    for yy in levels:
        W.box(piece, "trim_metal", s0, s1, yy, yy + 0.18, 0.0, depth, 0.04)
        W.box(piece, "dark_metal", s0, s1, yy + 0.18, yy + 0.32, depth - 0.12, depth, 0.02)
    W.box(piece, "trim_metal", s0, s1, top - 0.15, top, 0.0, depth, 0.04)
    k = seed
    for yy in levels:
        s = s0 + 0.4
        while s < s1 - 1.0:
            k += 1
            c = k % 4
            yb = yy + 0.18
            if c == 0 and s + 1.8 < s1:
                q0 = W.p(s, yb, 0.3); q1 = W.p(s + 1.8, yb + 1.6, depth - 0.2)
                box(piece, "crate_green", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.08)
                q0 = W.p(s + 0.5, yb + 0.9, depth - 0.2); q1 = W.p(s + 1.3, yb + 1.25, depth - 0.16)
                box(piece, "label_cream", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.0)
                s += 2.1
            elif c == 1:
                p = W.p(s + 0.8, yb, depth / 2)
                ammo_can(piece, p[0], p[1], p[2], along_x=(W.along == "x"))
                p = W.p(s + 0.8, yb + 0.95, depth / 2)
                ammo_can(piece, p[0], p[1], p[2], along_x=(W.along == "x"))
                s += 1.9
            elif c == 2 and yy < 1:
                p = W.p(s + 0.75, yb, depth / 2)
                lathe(piece, "drum_olive", [(0.05, 0.0), (0.7, 0.0), (0.74, 0.08), (0.74, 0.8), (0.78, 0.86), (0.74, 0.92),
                                            (0.74, 1.9), (0.7, 2.0), (0.05, 2.0)], cx=p[0], cz=p[2], seg=20, y0=p[1])
                s += 1.7
            else:
                q0 = W.p(s, yb, 0.4); q1 = W.p(s + 1.4, yb + 0.9, depth - 0.3)
                box(piece, "case_dark", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.12)
                q0 = W.p(s + 0.2, yb + 0.4, depth - 0.3); q1 = W.p(s + 1.2, yb + 0.55, depth - 0.25)
                box(piece, "drum_olive", q0[0], q1[0], q0[1], q1[1], q0[2], q1[2], 0.02)
                s += 1.7

def counter(piece, x0, x1, zf, inw, top=3.75, depth=2.6, emblem_x=None):
    """Service counter, front face at z=zf facing the player side (inw = direction toward the player)."""
    W = Wall("x", zf, inw)
    W.box(piece, "wall_kick", x0 + 0.2, x1 - 0.2, 0.0, 0.55, -depth + 0.2, -0.3, 0.06)
    W.box(piece, "wall_body", x0, x1, 0.55, top - 0.35, -depth, 0.0, 0.1)
    n = max(2, int((x1 - x0) / 2.6))
    pw = (x1 - x0) / n
    for i in range(n):
        a = x0 + i * pw + 0.14; b = a + pw - 0.28
        W.box(piece, "wall_plate", a, b, 0.8, 2.45, 0.0, 0.22, 0.08)
        W.box(piece, "trim_metal", a + pw - 0.28, a + pw, 0.65, 2.6, 0.0, 0.3, 0.03)
    W.box(piece, "band_olive", x0, x1, 2.6, 3.0, 0.0, 0.18, 0.04)
    W.box(piece, "trim_light", x0 - 0.15, x1 + 0.15, top - 0.35, top, -depth - 0.1, 0.35, 0.1)
    W.box(piece, "plate_metal", x0 + 0.3, x1 - 0.3, top, top + 0.03, -depth + 0.3, 0.05, 0.0)
    W.box(piece, "dark_metal", x0 + 0.2, x1 - 0.2, 1.4, 1.6, -depth - 0.4, -depth, 0.03)  # staff-side shelf lip
    if emblem_x is not None:
        W.box(piece, "label_cream", emblem_x - 1.6, emblem_x + 1.6, 1.05, 2.25, 0.22, 0.3, 0.02)
    # end returns toward the wall behind
    for (a, b) in ((x0, x0 + 0.9), (x1 - 0.9, x1)):
        W.box(piece, "wall_body", a, b, 0.0, top - 0.35, -depth - 1.9, -depth, 0.1)
        W.box(piece, "trim_light", a - 0.1, b + 0.1, top - 0.35, top, -depth - 2.0, -depth, 0.08)

def terminal(piece, cx, y, zf, inw):
    """Counter terminal: base, tilted-look screen block facing the player, cream Neon edge."""
    W = Wall("x", zf, inw)
    W.box(piece, "dark_metal", cx - 1.0, cx + 1.0, y, y + 0.2, -1.6, -0.5, 0.05)
    W.box(piece, "dark_metal", cx - 0.15, cx + 0.15, y + 0.2, y + 0.8, -1.3, -1.0, 0.03)
    W.box(piece, "dark_metal", cx - 0.95, cx + 0.95, y + 0.7, y + 1.95, -1.35, -1.05, 0.06)
    W.box(piece, "screen", cx - 0.82, cx + 0.82, y + 0.82, y + 1.83, -1.05, -1.0, 0.0)
    W.box(piece, "neon_cream", cx - 0.82, cx + 0.82, y + 0.74, y + 0.8, -1.05, -1.0, 0.0)

def stanchion(piece, cx, cz, h=1.3):
    cyl(piece, "trim_metal", cx, cz, 0.45, 0.0, 0.18, seg=16, bev=0.05)
    cyl(piece, "trim_light", cx, cz, 0.16, 0.18, h, seg=12, bev=0.0)
    cyl(piece, "neon_cream", cx, cz, 0.24, h, h + 0.22, seg=12, bev=0.05)

# ------------------------------------------------------------------ floors (dark slab grid, border, kerb, lane insert + lines)
def room_floor(piece, lines, x0, x1, z0, z1, xs, zs, lane_z=None, lane_dir=1):
    g = 0.15
    B = 2.5
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            box(piece, "floor_field", xs[i] + g, xs[i + 1] - g, -1.0, 0.0, zs[j] + g, zs[j + 1] - g, 0.06)
    box(piece, "floor_border", x0, x1, -1.0, -0.06, z0, z1, 0.0)
    box(piece, "floor_border", x0, x1, -1.0, 0.02, z0, z0 + B, 0.05)
    box(piece, "floor_border", x0, x1, -1.0, 0.02, z1 - B, z1, 0.05)
    box(piece, "floor_border", x0, x0 + B, -1.0, 0.02, z0 + B, z1 - B, 0.05)
    box(piece, "floor_border", x1 - B, x1, -1.0, 0.02, z0 + B, z1 - B, 0.05)
    # metal kerb strip on the field edge
    for (a, b, c, d) in ((x0 + B - 0.2, x1 - B + 0.2, z0 + B - 0.2, z0 + B + 0.2), (x0 + B - 0.2, x1 - B + 0.2, z1 - B - 0.2, z1 - B + 0.2),
                         (x0 + B - 0.2, x0 + B + 0.2, z0 + B, z1 - B), (x1 - B - 0.2, x1 - B + 0.2, z0 + B, z1 - B)):
        box(piece, "trim_metal", a, b, -0.2, 0.07, c, d, 0.04)
    if lane_z:
        za, zb = sorted(lane_z)
        box(piece, "floor_insert", -3.0, 3.0, -0.2, 0.03, za, zb, 0.03)
        for xx in (-3.45, 3.45):
            box(lines, "neon_cream", xx - 0.19, xx + 0.19, -0.4, 0.07, za, zb, 0.0)

def ring_segments(piece, mat, cx, cz, r0, r1, gaps_deg=(90, 270), half_gap=14, seg=96, top=0.07):
    """Floor Neon ring with gaps where the lanes cross."""
    gs = sorted(gaps_deg)
    for i, g in enumerate(gs):
        nxt = gs[(i + 1) % len(gs)] + (360 if i == len(gs) - 1 else 0)
        a0 = math.radians(g + half_gap); a1 = math.radians(nxt - half_gap)
        lathe(piece, mat, [(r0, -0.4), (r1, -0.4), (r1, top), (r0, top)], cx=cx, cz=cz, seg=seg, a0=a0, a1=a1)

# ------------------------------------------------------------------ ceilings (slab, I-beams on pier lines, purlins, coffers, lamp strips)
def room_ceiling(piece, lights, x0, x1, z0, z1, H, beam_x, purlin_z, beam_d, strip_x):
    box(piece, "ceiling", x0 - TW, x1 + TW, H, H + 1.5, z0 - TW, z1 + TW, 0.1)
    xs = [x0] + beam_x + [x1]
    zs = [z0] + purlin_z + [z1]
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            a, b, c, d = xs[i] + 1.2, xs[i + 1] - 1.2, zs[j] + 1.0, zs[j + 1] - 1.0
            if b - a > 2 and d - c > 2:
                box(piece, "ceiling_gloss", a, b, H - 0.35, H, c, d, 0.12)
                box(piece, "trim_metal", a - 0.25, b + 0.25, H - 0.5, H - 0.32, c - 0.25, d + 0.25, 0.04)
    Bm = piece.replace("Ceiling", "Beams")
    for x in beam_x:
        box(Bm, "beam_metal", x - 0.35, x + 0.35, H - beam_d + 0.3, H - 0.3, z0, z1, 0.06)
        box(Bm, "beam_metal", x - 0.9, x + 0.9, H - beam_d, H - beam_d + 0.3, z0, z1, 0.08)
        box(Bm, "beam_metal", x - 0.9, x + 0.9, H - 0.3, H, z0, z1, 0.08)
        zz = z0 + 4.0
        while zz < z1 - 2:
            box(Bm, "beam_metal", x - 0.8, x + 0.8, H - beam_d + 0.3, H - 0.3, zz - 0.1, zz + 0.1, 0.02)
            zz += 4.0
    for z in purlin_z:
        box(Bm, "beam_metal", x0, x1, H - beam_d * 0.6, H, z - 0.4, z + 0.4, 0.06)
        box(Bm, "beam_metal", x0, x1, H - beam_d * 0.6 - 0.25, H - beam_d * 0.6, z - 0.75, z + 0.75, 0.06)
    for x in strip_x:
        for j in range(len(zs) - 1):
            c, d = zs[j] + 1.4, zs[j + 1] - 1.4
            if d - c < 2:
                continue
            box(lights, "trim_metal", x - 0.75, x + 0.75, H - 0.6, H - 0.3, c, d, 0.06)
            box(lights, "neon_lamp", x - 0.45, x + 0.45, H - 0.72, H - 0.55, c + 0.25, d - 0.25, 0.0)

# ------------------------------------------------------------------ corridors (gate -> room doorway)
def corridor(piece, z_hub, z_room):
    """Lining x -5.4..5.4 between the hub wall back face and the room door wall; ring frames keep 9.8 x 12.2 clear."""
    za, zb = sorted((z_hub, z_room))
    sg = 1 if z_room > z_hub else -1
    for side in (-1, 1):
        W = Wall("z", side * 5.4, -side)
        W.box(piece, "wall_kick", za, zb, 0.0, 7.0, -1.5, 0.0, 0.1)
        W.box(piece, "trim_metal", za, zb, 0.0, 0.8, 0.0, 0.3, 0.06)
        W.box(piece, "band_olive", za, zb, 7.1, 9.9, -1.5, 0.22, 0.08)
        W.box(piece, "trim_metal", za, zb, 6.85, 7.15, -1.5, 0.3, 0.04)
        W.box(piece, "trim_metal", za, zb, 9.85, 10.15, -1.5, 0.3, 0.04)
        W.box(piece, "door_leaf", za, zb, 10.15, 13.0, -1.5, 0.0, 0.06)  # corrugated cladding above the band
        # proud kick plates between frames
        frames = [za + 3.0 + 4.5 * k for k in range(4) if za + 3.0 + 4.5 * k < zb - 1]
        edges = [za] + frames + [zb]
        for i in range(len(edges) - 1):
            if edges[i + 1] - edges[i] > 2.0:
                W.box(piece, "wall_plate", edges[i] + 0.7, edges[i + 1] - 0.7, 1.4, 6.3, 0.0, 0.25, 0.08)
        for f in frames:
            W.box(piece, "beam_metal", f - 0.45, f + 0.45, 0.0, 13.0, 0.0, 0.5, 0.08)
            W.box(piece, "trim_metal", f - 0.6, f + 0.6, 0.0, 1.2, 0.0, 0.6, 0.06)
            prism(piece, "beam_metal", [W.p(f - 0.4, 12.2, 0.5), W.p(f - 0.4, 10.9, 0.5), W.p(f - 0.4, 12.2, 1.6)],
                  Vector(W.p(f + 0.4, 0, 0)) - Vector(W.p(f - 0.4, 0, 0)))
    for f in [za + 3.0 + 4.5 * k for k in range(4) if za + 3.0 + 4.5 * k < zb - 1]:
        box(piece, "beam_metal", -5.4, 5.4, 12.2, 13.0, f - 0.45, f + 0.45, 0.08)
    box(piece, "ceiling", -6.9, 6.9, 13.0, 14.2, za, zb, 0.06)
    box(piece, "trim_metal", -1.0, 1.0, 12.55, 13.0, za + 0.3, zb - 0.3, 0.06)
    box(piece, "neon_lamp", -0.6, 0.6, 12.45, 12.6, za + 0.6, zb - 0.6, 0.0)
    # floor: metal plate deck, dark edge strips, cream runway lines continuing the hub lanes
    box(piece, "plate_metal", -5.4, 5.4, -0.25, 0.0, za, zb, 0.03)
    for side in (-1, 1):
        a, b = sorted((side * 4.3, side * 5.4))
        box(piece, "floor_border", a, b, -0.25, 0.02, za, zb, 0.02)
        box(piece, "neon_cream", side * 3.9 - 0.19, side * 3.9 + 0.19, -0.4, 0.07, za, zb, 0.0)
    ha, hb = sorted((z_room, z_room - sg * 0.7))
    box(piece, "hazard", -4.3, 4.3, 0.0, 0.08, ha, hb, 0.0)

def door_portal(piece, zf, inw, H, D=-5.0):
    """Room-side doorway, clear 11 wide x 12.2 high, through the wall zf..zf-inw*5 (the corridor end).
    Concrete cheeks proud 1.0 into the room, metal reveal, olive band across the head, threshold + hazard."""
    W = Wall("x", zf, inw)
    for sg in (-1, 1):
        a, b = sorted((sg * 5.8, sg * 9.8))
        W.box(piece, "wall_light", a, b, 0.0, min(H, 13.6), D, 1.0, 0.3, 2)
        W.box(piece, "trim_metal", a - 0.1, b + 0.1, 0.0, 1.8, D, 1.25, 0.12)
        W.box(piece, "band_olive", a, b, 7.1, 9.9, D, 1.15, 0.1)
        a2, b2 = sorted((sg * 5.5, sg * 5.8))
        W.box(piece, "trim_metal", a2, b2, 0.0, 12.2, D, 1.0, 0.04)
        prism(piece, "trim_metal", [W.p(sg * 5.5, 12.2, 1.0), W.p(sg * 4.5, 12.2, 1.0), W.p(sg * 5.5, 11.2, 1.0)],
              Vector(W.p(0, 0, D)) - Vector(W.p(0, 0, 1.0)))
    top = min(H, 13.6)
    W.box(piece, "wall_light", -9.8, 9.8, 12.2, top, D, 1.0, 0.3, 2)
    W.box(piece, "trim_metal", -5.8, 5.8, 12.2, 12.45, D, 1.0, 0.04)
    if H > 16:
        W.box(piece, "band_olive", -9.8, 9.8, 12.9, 13.5, D, 1.12, 0.06)
    W.box(piece, "plate_metal", -5.5, 5.5, -0.25, 0.04, D, 1.0, 0.03)
    W.box(piece, "hazard", -5.5, 5.5, 0.0, 0.08, 1.0, 1.6, 0.0)

# ------------------------------------------------------------------ SHOP
def build_shop():
    x0, x1, zf, zb, H = SH["x0"], SH["x1"], SH["zf"], SH["zb"], SH["H"]
    WF = Wall("x", zf, +1); WB = Wall("x", zb, -1); WW_ = Wall("z", x0, +1); WE_ = Wall("z", x1, -1)
    P = "S_Walls"; Pi = "S_Piers"
    # front wall either side of the doorway portal; back wall; side walls (corners closed by the x-walls)
    zones(WF, P, x0 - TW, -9.8, H); zones(WF, P, 9.8, x1 + TW, H)
    zones(WB, P, x0 - TW, x1 + TW, H)
    zones(WW_, P, zf, zb, H); zones(WE_, P, zf, zb, H)
    door_portal("S_Door", zf, +1, H)
    corridor("C_CorrN", 49.0, 64.0)
    # piers: front/back on x -20,-10,10,20 (front skips +-10: portal), sides at z 79.5, 90, 100
    for s in (-20.0, 20.0):
        pier(WF, Pi, s, H, light="small")
    for s in (-20.0, -10.0, 10.0, 20.0):
        pier(WB, Pi, s, H, light="small" if abs(s) > 15 else None)
    for s in (79.5, 90.0, 100.0):
        pier(WW_, Pi, s, H, light="small"); pier(WE_, Pi, s, H, light="small")
    # kick-zone panels where nothing stands
    for (a, b) in ((x0, -20.0), (-20.0, -9.8), (9.8, 20.0), (20.0, x1)):
        plates(WF, P, a + (0.5 if a == x0 else 0), b - (0.5 if b == x1 else 0), 1.3, 6.5, 0.3, 0.55)
    for (a, b) in ((x0, -20.0), (20.0, x1)):
        plates(WB, P, a + 0.5, b - 0.5, 1.3, 6.5, 0.3, 0.55)
    for W in (WW_, WE_):
        plates(W, P, zf + 0.5, 79.5, 1.3, 6.5, 0.3, 0.55)
        plates(W, P, 100.0, zb - 0.5, 1.3, 6.5, 0.3, 0.55)
    # display walls: two proud cases per side wall (stock on shelves), rifle cases on the east wall
    for sc in (84.75, 95.0):
        display_niche(WW_, "S_Displays", sc, w=6.4, items="cases")
        display_niche(WE_, "S_Displays", sc, w=6.4, items="rifles")
    # back wall: storage shelving in the side bays, sign board over the counter bay, lockers behind the NPC
    shelving(WB, "S_Shelves", -18.8, -11.2, seed=1)
    shelving(WB, "S_Shelves", 11.2, 18.8, seed=5)
    shelving(WB, "S_Shelves", -8.6, 1.4, levels=(0.3, 2.9), top=5.2, seed=3)
    for i in range(3):  # lockers behind the quartermaster (x 2.5..8.5)
        a = 2.6 + i * 2.05
        WB.box("S_Shelves", "trim_metal", a, a + 1.95, 0.4, 6.4, 0.0, 1.0, 0.1)
        WB.box("S_Shelves", "door_leaf", a + 0.1, a + 1.85, 0.6, 6.2, 1.0, 1.1, 0.04)
        for yy in (5.4, 5.7, 6.0):
            WB.box("S_Shelves", "dark_metal", a + 0.4, a + 1.55, yy, yy + 0.12, 1.1, 1.15, 0.0)
        WB.box("S_Shelves", "label_cream", a + 0.55, a + 1.4, 4.6, 4.9, 1.1, 1.14, 0.0)
    WB.box("S_Walls", "trim_metal", 2.4, 8.8, 0.0, 0.4, 0.0, 1.2, 0.06)
    sign_board("S_Signs", WB, -6.0, 6.0, 10.3, 12.05, d=0.15)
    WB.box("S_Signs", "label_cream", -2.4, 2.4, 9.95, 10.25, 0.6, 0.9, 0.03)
    # counter (Shop_Counter prompt at (3,3,101.8) sits inside it; NPC_Quartermaster behind at (10,0,106.7))
    counter("S_Counter", -10.0, 16.0, 100.6, -1, emblem_x=7.0)
    terminal("S_Counter", -2.5, 3.78, 100.6, -1)
    terminal("S_Counter", 12.5, 3.78, 100.6, -1)
    box("S_Counter", "plate_metal", -9.0, 15.0, 0.0, 0.06, 103.4, 108.2, 0.02)  # staff deck behind the counter
    # featured item plinth (hero) at (0, 88)
    cx, cz = 0.0, 88.0
    D = "S_Plinth"
    lathe(D, "floor_border", [(4.4, -0.2), (5.3, -0.2), (5.3, 0.25), (5.1, 0.42), (4.4, 0.42)], cx=cx, cz=cz, seg=96)
    lathe(D, "neon_olive", [(4.05, -0.2), (4.4, -0.2), (4.4, 0.58), (4.05, 0.58)], cx=cx, cz=cz, seg=96)
    lathe(D, "plate_metal", [(2.9, -0.2), (4.05, -0.2), (4.05, 0.78), (3.9, 0.92), (2.9, 0.92)], cx=cx, cz=cz, seg=96)
    cyl(D, "disc_plate", cx, cz, 2.9, -0.2, 0.85, seg=64, bev=0.06)
    for k in range(24):  # tick inlays on the metal ring
        a = math.radians(15 * k); ca, sa = math.cos(a), math.sin(a)
        r0, r1, w = 3.15, 3.75, 0.07
        pts = [(cx + r0 * ca - w * sa, 0.92, cz + r0 * sa + w * ca), (cx + r1 * ca - w * sa, 0.92, cz + r1 * sa + w * ca),
               (cx + r1 * ca + w * sa, 0.92, cz + r1 * sa - w * ca), (cx + r0 * ca + w * sa, 0.92, cz + r0 * sa - w * ca)]
        prism(D, "dark_metal", pts, (0, 0.03, 0))
    cyl(D, "trim_metal", cx, cz, 1.25, 0.85, 2.5, seg=32, bev=0.08)
    cyl(D, "dark_metal", cx, cz, 1.33, 1.5, 1.72, seg=32, bev=0.03)
    cyl(D, "neon_cream", cx, cz, 1.3, 2.2, 2.3, seg=32, bev=0.0)
    cyl(D, "trim_light", cx, cz, 1.75, 2.5, 2.78, seg=32, bev=0.08)
    for sx in (-1.0, 1.0):  # cradle forks holding the featured rifle
        box(D, "dark_metal", cx + sx - 0.12, cx + sx + 0.12, 2.78, 3.5, cz - 0.12, cz + 0.12, 0.03)
        box(D, "dark_metal", cx + sx - 0.12, cx + sx + 0.12, 3.35, 3.6, cz - 0.3, cz + 0.3, 0.03)
    rifle(D, (cx - 2.2, 3.9, cz), (1, 0, 0), (0, 1, 0), (0, 0, 1), kind=0)
    for q in range(4):
        a = math.radians(45 + 90 * q)
        stanchion(D, cx + 6.2 * math.cos(a), cz + 6.2 * math.sin(a))
    # floor
    room_floor("S_Floor", "S_Lines", x0, x1, zf, zb, [-27.5, -20.0, -10.0, 0.0, 10.0, 20.0, 27.5], [71.5, 79.5, 90.0, 100.0, 108.0],
               lane_z=(zf, 81.2))
    ring_segments("S_Lines", "neon_cream", cx, cz, 6.6, 6.98, gaps_deg=(270, 90), half_gap=26)
    ring_segments("S_Lines", "neon_olive", cx, cz, 7.5, 7.75, gaps_deg=(0, 90, 180, 270), half_gap=30)
    box("S_Floor", "hazard", -9.5, 15.5, 0.0, 0.08, 99.4, 100.1, 0.0)
    # freestanding pedestals (west side, L_Pedestals) and gear racks (east side, L_Racks)
    for i, z in enumerate((79.0, 85.5, 92.0)):
        pedestal("S_Displays", -18.0, z, i)
    for (z0r, z1r) in ((78.0, 84.0), (88.0, 94.0)):
        gear_rack("S_Racks", 22.0, z0r, z1r)
    # ceiling: beams on the pier lines, purlins on the side piers, lamp strips in the coffers
    room_ceiling("S_Ceiling", "S_Lights", x0, x1, zf, zb, H, [-20.0, -10.0, 10.0, 20.0], [79.5, 90.0, 100.0], 1.0,
                 [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0])
    for (lx, lz) in ((0.0, 97.0), (22.0, 86.0), (-17.5, 85.0), (0.0, 74.0)):   # RoomLight homes (L_Counter/L_Racks/L_Pedestals/L_Entry)
        downlight("S_Lights", lx, lz, H - 0.75)
    # props: crate stacks in the front corners and by the back-wall shelving
    prop_crate("S_Props", -26.6, 0.0, 72.6, 4.0); prop_crate("S_Props", -22.4, 0.0, 72.4, 3.0); prop_crate("S_Props", -26.4, 4.0, 72.8, 3.0)
    prop_crate("S_Props", 26.6, 0.0, 72.6, 4.0); prop_drum("S_Props", 22.6, 0.0, 72.0); prop_drum("S_Props", 22.4, 0.0, 74.9)
    prop_longcase("S_Props", -24.0, 0.0, 106.4, True); prop_longcase("S_Props", -24.0, 2.2, 106.4, True)
    prop_crate("S_Props", 25.8, 0.0, 106.5, 4.0); ammo_can("S_Props", 25.8, 4.0, 106.5)

def pedestal(piece, cx, cz, k):
    box(piece, "trim_metal", cx - 1.5, cx + 1.5, 0.0, 0.4, cz - 1.5, cz + 1.5, 0.1)
    box(piece, "wall_light", cx - 1.2, cx + 1.2, 0.4, 3.0, cz - 1.2, cz + 1.2, 0.2, 2)
    box(piece, "band_olive", cx - 1.25, cx + 1.25, 2.2, 2.45, cz - 1.25, cz + 1.25, 0.04)
    box(piece, "trim_light", cx - 1.45, cx + 1.45, 3.0, 3.25, cz - 1.45, cz + 1.45, 0.08)
    box(piece, "neon_cream", cx - 1.25, cx + 1.25, 0.4, 0.5, cz - 1.25, cz + 1.25, 0.0)
    box(piece, "label_cream", cx + 1.2, cx + 1.24, 1.2, 1.8, cz - 0.6, cz + 0.6, 0.0)
    if k == 0:
        ammo_can(piece, cx, 3.25, cz, along_x=False)
    elif k == 1:
        rifle(piece, (cx, 4.45, cz - 2.2), (0, 0, 1), (0, 1, 0), (1, 0, 0), kind=1)
        for sz_ in (-0.9, 0.9):
            box(piece, "dark_metal", cx - 0.1, cx + 0.1, 3.25, 4.2, cz + sz_ - 0.1, cz + sz_ + 0.1, 0.02)
            box(piece, "dark_metal", cx - 0.28, cx + 0.28, 4.05, 4.25, cz + sz_ - 0.1, cz + sz_ + 0.1, 0.02)
    else:
        prop_drum(piece, cx, 3.25, cz) if False else cyl(piece, "drum_olive", cx, cz, 0.8, 3.25, 4.9, seg=24, bev=0.08)
        cyl(piece, "dark_metal", cx, cz, 0.84, 3.8, 3.95, seg=24, bev=0.02)
        cyl(piece, "dark_metal", cx, cz, 0.84, 4.3, 4.45, seg=24, bev=0.02)

def gear_rack(piece, cx, z0, z1, h=6.4):
    """Freestanding double-sided rack: base plinth, posts, top bar, rifles standing both sides."""
    box(piece, "trim_metal", cx - 1.4, cx + 1.4, 0.0, 0.7, z0, z1, 0.1)
    box(piece, "dark_metal", cx - 1.2, cx + 1.2, 0.7, 0.85, z0 + 0.2, z1 - 0.2, 0.03)
    for z in (z0 + 0.2, z1 - 0.2):
        box(piece, "beam_metal", cx - 0.25, cx + 0.25, 0.7, h, z - 0.2, z + 0.2, 0.05)
    box(piece, "beam_metal", cx - 0.3, cx + 0.3, h - 0.4, h, z0, z1, 0.06)
    box(piece, "wall_plate", cx - 0.15, cx + 0.15, 0.85, h - 0.4, z0 + 0.4, z1 - 0.4, 0.03)
    box(piece, "trim_metal", cx - 1.0, cx + 1.0, 4.4, 4.6, z0 + 0.3, z1 - 0.3, 0.04)   # barrel rest
    box(piece, "neon_lamp", cx - 0.2, cx + 0.2, h - 0.5, h - 0.4, z0 + 0.4, z1 - 0.4, 0.0)
    box(piece, "label_cream", cx - 1.42, cx + 1.42, 0.2, 0.5, (z0 + z1) / 2 - 0.8, (z0 + z1) / 2 + 0.8, 0.0)
    n = int((z1 - z0 - 1.0) / 1.0)
    for side in (-1, 1):
        for i in range(n):
            z = z0 + 1.0 + i * 1.0
            rifle(piece, (cx + side * 1.1, 0.85, z), (0, 1, 0), (side, 0, 0), (0, 0, 1), kind=i + (side > 0))

# ------------------------------------------------------------------ ARMORY
def wall_rack(W, piece, s0, s1, top=6.3):
    """Wall-mounted rifle rack (rifles standing, muzzle up) below the band, lamp line under the band."""
    W.box(piece, "trim_metal", s0, s1, 0.0, 0.9, 0.0, 1.5, 0.1)
    W.box(piece, "dark_metal", s0 + 0.1, s1 - 0.1, 0.9, 1.0, 0.1, 1.4, 0.02)
    W.box(piece, "dark_metal", s0, s1, 1.0, top, 0.0, 0.25, 0.05)
    for s in (s0, s1):
        W.box(piece, "beam_metal", s - 0.2, s + 0.2, 0.0, top + 0.3, 0.0, 1.6, 0.06)
    W.box(piece, "trim_metal", s0, s1, 4.2, 4.45, 0.0, 1.4, 0.04)
    W.box(piece, "trim_metal", s0, s1, top, top + 0.3, 0.0, 1.6, 0.06)
    W.box(piece, "neon_lamp", s0 + 0.3, s1 - 0.3, top - 0.12, top, 0.9, 1.3, 0.0)
    W.box(piece, "label_cream", (s0 + s1) / 2 - 1.0, (s0 + s1) / 2 + 1.0, 0.35, 0.7, 1.5, 1.55, 0.0)
    eu = (0, 1, 0)
    ev = tuple(Vector(W.p(0, 0, 1)) - Vector(W.p(0, 0, 0)))
    ew = tuple(Vector(W.p(1, 0, 0)) - Vector(W.p(0, 0, 0)))
    n = int((s1 - s0 - 1.0) / 1.05)
    for i in range(n):
        s = s0 + 1.0 + i * 1.05
        rifle(piece, W.p(s, 1.0, 1.05), eu, ev, ew, kind=i)

def bench(piece, cx, cz, along_x=True, lamp_y=6.2):
    L, Wd, top = 6.0, 2.4, 3.0
    dx, dz = (L / 2, Wd / 2) if along_x else (Wd / 2, L / 2)
    box(piece, "trim_light", cx - dx, cx + dx, top - 0.3, top, cz - dz, cz + dz, 0.08)
    box(piece, "plate_metal", cx - dx + 0.25, cx + dx - 0.25, top, top + 0.03, cz - dz + 0.25, cz + dz - 0.25, 0.0)
    for sx in (-1, 1):
        for sz_ in (-1, 1):
            px, pz = cx + sx * (dx - 0.3), cz + sz_ * (dz - 0.3)
            box(piece, "beam_metal", px - 0.18, px + 0.18, 0.0, top - 0.3, pz - 0.18, pz + 0.18, 0.04)
    box(piece, "dark_metal", cx - dx + 0.3, cx + dx - 0.3, 0.7, 0.85, cz - dz + 0.3, cz + dz - 0.3, 0.02)
    # olive drawer unit under one end
    ux = cx + (dx - 1.3 if along_x else 0); uz = cz + (0 if along_x else dz - 1.3)
    box(piece, "drum_olive", ux - 1.0, ux + 1.0, 0.85, top - 0.35, uz - 1.0, uz + 1.0, 0.08)
    for yy in (1.3, 2.0):
        box(piece, "dark_metal", ux - 0.5, ux + 0.5, yy, yy + 0.12, uz - 1.06, uz + 1.06, 0.0)
    # rifle and a can on top
    if along_x:
        rifle(piece, (cx - 2.6, top + 0.19, cz - 0.2), (1, 0, 0), (0, 0, 1), (0, 1, 0), kind=1)
    else:
        rifle(piece, (cx - 0.2, top + 0.19, cz - 2.6), (0, 0, 1), (1, 0, 0), (0, 1, 0), kind=1)
    ammo_can(piece, cx + (2.0 if along_x else 0.5), top, cz + (0.5 if along_x else 2.0), along_x)
    # task lamp (home of the L_Bench RoomLight at y 8.5): post at the back edge, arm, head
    bx, bz = (cx, cz + dz - 0.2) if along_x else (cx + dx - 0.2, cz)
    box(piece, "dark_metal", bx - 0.12, bx + 0.12, top, lamp_y + 0.6, bz - 0.12, bz + 0.12, 0.03)
    hx, hz = cx, cz
    box(piece, "dark_metal", min(bx, hx) - 0.1, max(bx, hx) + 0.1, lamp_y + 0.5, lamp_y + 0.7, min(bz, hz) - 0.1, max(bz, hz) + 0.1, 0.03)
    box(piece, "trim_metal", hx - 1.4 if along_x else hx - 0.4, hx + 1.4 if along_x else hx + 0.4, lamp_y, lamp_y + 0.5,
        hz - 0.4 if along_x else hz - 1.4, hz + 0.4 if along_x else hz + 1.4, 0.08)
    box(piece, "neon_lamp", hx - 1.2 if along_x else hx - 0.25, hx + 1.2 if along_x else hx + 0.25, lamp_y - 0.08, lamp_y,
        hz - 0.25 if along_x else hz - 1.2, hz + 0.25 if along_x else hz + 1.2, 0.0)

def display_case(piece, x0, x1, z0, z1, top=3.2):
    box(piece, "trim_metal", x0, x1, 0.0, 0.5, z0, z1, 0.1)
    box(piece, "case_dark", x0 + 0.15, x1 - 0.15, 0.5, top - 0.9, z0 + 0.15, z1 - 0.15, 0.12)
    box(piece, "band_olive", x0 + 0.1, x1 - 0.1, top - 1.35, top - 1.1, z0 + 0.1, z1 - 0.1, 0.03)
    box(piece, "trim_light", x0, x1, top - 0.9, top - 0.7, z0, z1, 0.06)
    box(piece, "dark_metal", x0 + 0.3, x1 - 0.3, top - 0.7, top - 0.6, z0 + 0.3, z1 - 0.3, 0.0)
    for x in (x0, x1):
        for z in (z0, z1):
            box(piece, "trim_metal", x - 0.1 if x == x0 else x - 0.2, x + 0.2 if x == x0 else x + 0.1, top - 0.7, top,
                z - 0.1 if z == z0 else z - 0.2, z + 0.2 if z == z0 else z + 0.1, 0.03)
    box(piece, "trim_metal", x0, x1, top - 0.05, top, z0, z1, 0.0) if False else None
    box(piece, "glass", x0 + 0.15, x1 - 0.15, top - 0.08, top - 0.02, z0 + 0.15, z1 - 0.15, 0.0)
    box(piece, "neon_cream", x0 + 0.3, x1 - 0.3, top - 0.66, top - 0.6, z0 + 0.3, z0 + 0.45, 0.0)
    n = int((x1 - x0) / 5.0)
    for i in range(n):
        xs = x0 + 0.5 + i * 5.0
        rifle(piece, (xs, top - 0.45, (z0 + z1) / 2 + 0.2), (1, 0, 0), (0, 0, -1), (0, 1, 0), kind=i)
    box(piece, "label_cream", (x0 + x1) / 2 - 1.0, (x0 + x1) / 2 + 1.0, 1.2, 1.6, z0 + 0.1, z0 + 0.14, 0.0)

def build_armory():
    x0, x1, zf, zb, H = AR["x0"], AR["x1"], AR["zf"], AR["zb"], AR["H"]
    WF = Wall("x", zf, -1); WB = Wall("x", zb, +1); WW_ = Wall("z", x0, +1); WE_ = Wall("z", x1, -1)
    P = "A_Walls"; Pi = "A_Piers"
    bx = [-20.67, -10.33, 10.33, 20.67]
    bz = [-78.4, -89.75, -101.1]
    zones(WF, P, x0 - TW, -9.8, H); zones(WF, P, 9.8, x1 + TW, H)
    zones(WF, P, -9.8, 9.8, H, ymin=13.6)  # wall above the door portal
    zones(WB, P, x0 - TW, x1 + TW, H)
    zones(WW_, P, zb, zf, H); zones(WE_, P, zb, zf, H)
    door_portal("A_Door", zf, -1, H, D=-3.0)
    corridor("C_CorrS", -49.0, -64.0)
    for s in (-20.67, 20.67):
        pier(WF, Pi, s, H, light="big")
    for s in (-20.67, 10.33, 20.67):  # no pier at -10.33: the gun wall stands there
        pier(WB, Pi, s, H, light="big" if s > 15 else None)
    WB.box(Pi, "trim_metal", -10.33 - 1.35, -10.33 + 1.35, H - 1.9, H - 1.2, -TW, 1.6, 0.1)  # corbel for the beam
    for s in bz:
        pier(WW_, Pi, s, H, light="big"); pier(WE_, Pi, s, H, light="big")
    # body-zone panels (10.6..15) on every bay, kick panels where nothing stands
    edges_x = [x0] + bx + [x1]
    edges_z = [zb] + sorted(bz) + [zf]
    for W, edges in ((WF, edges_x), (WB, edges_x)):
        for i in range(len(edges) - 1):
            a, b = edges[i] + (0.4 if i == 0 else 1.2), edges[i + 1] - (0.4 if i == len(edges) - 2 else 1.2)
            if W is WF and b > -9.8 and a < 9.8:
                continue
            plates(W, P, a, b, 10.6, 15.0, 0.0, 0.3)
    for W in (WW_, WE_):
        for i in range(len(edges_z) - 1):
            plates(W, P, edges_z[i] + 0.4 + (0.8 if i else 0), edges_z[i + 1] - 0.4 - (0.8 if i < 3 else 0), 10.6, 15.0, 0.0, 0.3)
    for (a, b) in ((x0, -20.67), (-20.67, -9.8), (9.8, 20.67), (20.67, x1)):
        plates(WF, P, a + (0.5 if a == x0 else 1.2), b - (0.5 if b == x1 else 1.2), 1.3, 6.5, 0.3, 0.55)
    # upper ribbed band: slim lamp line per bay (as the hub's non-window bays)
    for W, edges in ((WF, edges_x), (WB, edges_x), (WW_, edges_z), (WE_, edges_z)):
        for i in range(len(edges) - 1):
            if edges[i + 1] - edges[i] > 6:
                W.box("A_Lights", "neon_lamp", edges[i] + 2.0, edges[i + 1] - 2.0, 18.9, 19.2, 0.0, 0.3, 0.0)
    # GUN WALL on the back wall, x -16.6..4.1 (GunWall_Kit prompt (0,6,-110.5) stands in front of it)
    G = "A_GunWall"
    ga, gb = -16.6, 4.1
    for (a, b) in ((ga, ga + 1.2), (gb - 1.2, gb)):
        WB.box(G, "wall_light", a, b, 0.0, 15.0, 0.0, 1.9, 0.3, 2)
        WB.box(G, "trim_metal", a - 0.1, b + 0.1, 0.0, 1.6, 0.0, 2.1, 0.1)
        WB.box(G, "band_olive", a - 0.05, b + 0.05, 7.1, 9.9, 0.0, 2.0, 0.1)
    WB.box(G, "wall_light", ga, gb, 13.6, 15.0, 0.0, 1.9, 0.3, 2)
    WB.box(G, "wall_light", ga + 1.2, gb - 1.2, 0.0, 0.8, 0.0, 1.9, 0.12)
    WB.box(G, "trim_metal", ga + 1.2, gb - 1.2, 0.7, 0.85, 0.0, 2.0, 0.03)
    WB.box(G, "wall_plate", ga + 1.2, gb - 1.2, 0.85, 13.6, 0.0, 0.7, 0.05)
    s = ga + 1.2 + 3.05
    while s < gb - 1.5:
        WB.box(G, "beam_metal", s - 0.12, s + 0.12, 0.85, 13.6, 0.7, 0.85, 0.02)
        s += 3.05
    WB.box(G, "trim_metal", ga + 1.2, gb - 1.2, 13.1, 13.6, 0.0, 1.5, 0.06)
    WB.box(G, "neon_lamp", ga + 1.5, gb - 1.5, 12.95, 13.1, 0.9, 1.4, 0.0)
    eu = (1, 0, 0); ev = (0, 1, 0); ew = (0, 0, 1)
    for r, yr in enumerate((2.6, 6.1, 9.6)):
        WB.box(G, "trim_metal", ga + 1.4, gb - 1.4, yr - 0.15, yr + 0.1, 0.7, 1.25, 0.03)
        for i in range(4):
            xs = ga + 1.65 + i * 4.45
            for pg in (xs + 1.1, xs + 3.1):  # pegs
                WB.box(G, "dark_metal", pg - 0.08, pg + 0.08, yr + 0.1, yr + 0.35, 0.85, 1.6, 0.02)
            rifle(G, WB.p(xs, yr + 1.05, 1.4), eu, ev, ew, kind=i + r)
            WB.box(G, "label_cream", xs + 1.6, xs + 2.8, yr - 0.12, yr + 0.06, 1.25, 1.28, 0.0)
    sign_board("A_Signs", WB, -12.6, -0.4, 15.6, 18.6, d=0.2)
    WB.box("A_Signs", "label_cream", -9.5, -3.5, 15.1, 15.5, 0.6, 0.9, 0.03)
    WB.box("A_Floor", "plate_metal", ga + 1.2, gb - 1.2, 0.0, 0.05, 1.9, 5.4, 0.02)
    WB.box("A_Floor", "hazard", ga + 1.2, gb - 1.2, 0.0, 0.08, 5.4, 6.0, 0.0)
    # SUPPLY counter + raised deck for NPC_Supply (7, ~1, -110.6)
    S = "A_Supply"
    box(S, "stair", 4.6, 18.6, 0.0, 0.85, zb, -107.6, 0.08)
    box(S, "plate_metal", 4.6, 18.4, 0.85, 1.0, zb, -107.9, 0.03)
    box(S, "trim_metal", 4.6, 18.6, 0.6, 1.02, -108.1, -107.6, 0.05)
    counter(S, 5.0, 18.6, -105.0, +1, emblem_x=11.8)
    terminal(S, 8.0, 3.78, -105.0, +1)
    shelving(WB, S, 12.4, 18.4, depth=1.6, levels=(1.0, 3.6, 6.2), top=7.4, seed=2)
    for i in range(2):  # lockers behind the NPC
        a = 5.0 + i * 2.1
        WB.box(S, "trim_metal", a, a + 2.0, 1.0, 7.0, 0.0, 0.8, 0.1)
        WB.box(S, "door_leaf", a + 0.1, a + 1.9, 1.2, 6.8, 0.8, 0.9, 0.04)
        WB.box(S, "label_cream", a + 0.6, a + 1.4, 5.2, 5.5, 0.9, 0.94, 0.0)
    sign_board("A_Signs", WB, 5.6, 17.6, 10.7, 12.9, d=1.5)
    box("A_Floor", "hazard", 5.0, 18.6, 0.0, 0.08, -104.9, -104.3, 0.0)
    # featured display DAIS at (-10, -96): Armory_Dais prompt + FeaturedScissors (y 2..5, Spin) sit above its centre
    cx, cz = -10.0, -96.0
    D = "A_Dais"
    lathe(D, "floor_border", [(4.8, -0.2), (5.8, -0.2), (5.8, 0.3), (5.6, 0.45), (4.8, 0.45)], cx=cx, cz=cz, seg=96)
    lathe(D, "neon_olive", [(4.45, -0.2), (4.8, -0.2), (4.8, 0.62), (4.45, 0.62)], cx=cx, cz=cz, seg=96)
    lathe(D, "plate_metal", [(3.2, -0.2), (4.45, -0.2), (4.45, 0.85), (4.3, 1.0), (3.2, 1.0)], cx=cx, cz=cz, seg=96)
    lathe(D, "neon_cream", [(2.9, -0.2), (3.2, -0.2), (3.2, 0.95), (2.9, 0.95)], cx=cx, cz=cz, seg=96)
    gap = math.radians(2.0)
    for k in range(8):
        a0 = math.radians(45 * k) + gap; a1 = math.radians(45 * (k + 1)) - gap
        lathe(D, "disc_plate", [(1.05, 0.6), (2.9, 0.6), (2.9, 0.92), (2.8, 1.02), (1.15, 1.02), (1.05, 0.92)], cx=cx, cz=cz, seg=64, a0=a0, a1=a1)
    cyl(D, "floor_border", cx, cz, 2.9, -0.2, 0.62, seg=48, bev=0.0)
    cyl(D, "disc_center", cx, cz, 1.05, 0.6, 1.25, seg=32, bev=0.06)
    cyl(D, "neon_olive", cx, cz, 0.6, 1.25, 1.32, seg=24, bev=0.0)
    for k in range(32):
        a = math.radians(360 / 32 * k); ca, sa = math.cos(a), math.sin(a)
        r0, r1, w = 3.45, 4.15, 0.07
        pts = [(cx + r0 * ca - w * sa, 1.0, cz + r0 * sa + w * ca), (cx + r1 * ca - w * sa, 1.0, cz + r1 * sa + w * ca),
               (cx + r1 * ca + w * sa, 1.0, cz + r1 * sa - w * ca), (cx + r0 * ca + w * sa, 1.0, cz + r0 * sa - w * ca)]
        prism(D, "dark_metal", pts, (0, 0.03, 0))
    for q in range(4):
        a = math.radians(45 + 90 * q)
        stanchion(D, cx + 6.6 * math.cos(a), cz + 6.6 * math.sin(a), h=1.5)
    # hood over the dais (home of L_Dais at y 19), hung from the ceiling
    cyl(D, "trim_metal", cx, cz, 2.6, 18.6, 19.4, seg=48, bev=0.12)
    cyl(D, "dark_metal", cx, cz, 2.75, 19.3, 19.6, seg=48, bev=0.05)
    lathe(D, "neon_lamp", [(1.9, 18.5), (2.3, 18.5), (2.3, 18.62), (1.9, 18.62)], cx=cx, cz=cz, seg=48)
    for q in range(3):
        a = math.radians(120 * q + 30)
        rod(D, "trim_light", (cx + 2.0 * math.cos(a), 19.6, cz + 2.0 * math.sin(a)), (cx + 2.0 * math.cos(a), H, cz + 2.0 * math.sin(a)), 0.1, 8)
    # wall racks (west + east middle bays), workbenches (L_BenchA/B), central display case
    for W in (WW_, WE_):
        wall_rack(W, "A_Racks", -100.3, -90.55)
        wall_rack(W, "A_Racks", -88.95, -79.2)
    bench("A_Benches", 12.0, -83.0, True)
    bench("A_Benches", 20.0, -87.5, True)
    display_case("A_Displays", 2.0, 12.5, -97.4, -94.6)
    # floor
    room_floor("A_Floor", "A_Lines", x0, x1, zb, zf, [-28.5, -20.67, -10.33, 0.0, 10.33, 20.67, 28.5],
               [-110.0, -101.1, -89.75, -78.4, -69.5], lane_z=(zf, -80.0))
    ring_segments("A_Lines", "neon_olive", cx, cz, 7.4, 7.68, gaps_deg=(45, 135, 225, 315), half_gap=12)
    ring_segments("A_Lines", "neon_cream", cx, cz, 8.3, 8.5, gaps_deg=(0, 90, 180, 270), half_gap=35)
    # ceiling
    room_ceiling("A_Ceiling", "A_Lights", x0, x1, zb, zf, H, bx, sorted(bz), 2.2, [-25.8, -15.5, -5.2, 5.2, 15.5, 25.8])
    for (lx, ly, lz) in ((0.0, 14.0, -90.0),):  # L_Fill pendant (hung from the ceiling)
        downlight("A_Lights", lx, lz, ly, r=1.4)
        rod("A_Lights", "trim_light", (lx, ly + 0.6, lz), (lx, H, lz), 0.1, 8)
    # L_GunWall (0,17.5,-106): wall-washer bar on arms over the gun wall
    box("A_Lights", "trim_metal", -15.0, 2.5, 17.3, 17.8, -106.6, -105.6, 0.08)
    box("A_Lights", "neon_lamp", -14.7, 2.2, 17.2, 17.32, -106.4, -105.8, 0.0)
    for xa in (-12.0, -1.0):
        box("A_Lights", "dark_metal", xa - 0.1, xa + 0.1, 17.5, 17.7, zb, -105.8, 0.02)
    # props
    prop_crate("A_Props", -27.4, 0.0, -70.8, 4.0); prop_crate("A_Props", -23.2, 0.0, -71.0, 4.0); prop_crate("A_Props", -25.3, 4.0, -70.9, 4.0)
    prop_drum("A_Props", -27.0, 0.0, -75.6)
    prop_crate("A_Props", 27.4, 0.0, -70.8, 4.0); prop_longcase("A_Props", 23.0, 0.0, -70.6, True); prop_longcase("A_Props", 23.0, 2.2, -70.6, True)
    prop_crate("A_Props", -27.4, 0.0, -108.6, 4.0); prop_crate("A_Props", -27.4, 0.0, -104.4, 3.0); prop_drum("A_Props", -23.5, 0.0, -109.4)
    prop_crate("A_Props", 27.2, 0.0, -104.0, 4.0); prop_crate("A_Props", 27.2, 4.0, -104.0, 3.0); ammo_can("A_Props", 24.4, 0.0, -103.2)
    prop_console("A_Props", 25.5, 0.0, -96.0, face=1) if False else None

def build_markers2():
    box("K_Scale2", "label_cream", -5, 5, 115, 125, -5, 5, 0.0)
    box("K_Marker2", "neon_olive", 15, 25, 115, 117, -1, 1, 0.0)
    box("K_Marker2", "neon_olive", 15, 17, 117, 123, -1, 1, 0.0)
    box("K_Marker2", "neon_olive", 15, 17, 115, 117, 1, 5, 0.0)

# ------------------------------------------------------------------ collections, manifest
HERO = ("S_Plinth", "A_Dais", "A_GunWall", "S_Counter", "A_Supply", "S_Signs", "A_Signs")
def coll_for(piece):
    if piece.startswith("K_"):
        return "R2_Markers"
    if piece in HERO:
        return "R2_Hero"
    if piece.startswith(("S_Props", "A_Props", "S_Displays", "A_Displays", "S_Racks", "A_Racks", "A_Benches", "S_Shelves")):
        return "R2_Props"
    return "R2_Shell"

STUDIO_RGB = {"band_olive": (120, 136, 66), "neon_olive": (88, 101, 48)}  # hub1_place colour decisions
NOCOLLIDE_MATS = {"neon_lamp", "neon_cream", "neon_olive", "void", "glass", "label_cream", "screen", "hazard", "ceiling_gloss", "sign_board"}
NOCOLLIDE_PIECES = ("S_Ceiling", "A_Ceiling", "S_Beams", "A_Beams", "S_Lights", "A_Lights", "S_Signs", "A_Signs", "S_Lines", "A_Lines")
BOX_PIECES = ("S_Floor", "A_Floor")

def studio_fields(mat):
    s = MATS[mat][6]
    base = s.split()[0]
    v = re.search(r"(Tac\w+)", s)
    if mat.startswith("neon") or mat == "void":
        base = "Neon"
    if mat == "glass":
        base = "Glass"
    return base, (v.group(1) if v else "")

def manifest(stats):
    out = []
    for st in stats:
        mat = st["material"]; piece = st["piece"]
        base, var = studio_fields(mat)
        coll = not (mat in NOCOLLIDE_MATS or piece.startswith(NOCOLLIDE_PIECES) or piece.startswith("K_"))
        # high-only pieces of the walls (cornice, ribbed upper) never meet a player: still collide (they are wall), fine
        fid = "Box" if (piece in BOX_PIECES and mat in ("floor_field", "floor_border", "floor_insert", "plate_metal")) else "PreciseConvexDecomposition"
        e = dict(st)
        e["rgb"] = list(STUDIO_RGB.get(mat, st["rgb"]))
        e["material_studio"] = base
        e["variant"] = var
        e["variant_folder"] = "MaterialService.TacHub1" if var else ""
        e["can_collide"] = coll
        e["collision_fidelity"] = fid if coll else "Box"
        e["cast_shadow"] = not (mat.startswith("neon") or mat == "glass")
        e["transparency"] = 0.6 if mat == "glass" else 0.0
        e["texture_overlay"] = {"hazard": "TX_hazard_stripe 4x1 Top", "grate": "TX_grate_alpha 3x3"}.get(mat, "")
        out.append(e)
    return out

def clear_rooms():
    for cn in ("R2_Shell", "R2_Hero", "R2_Props", "R2_Markers"):
        c = bpy.data.collections.get(cn)
        if c:
            for ob in list(c.objects):
                me = ob.data
                bpy.data.objects.remove(ob, do_unlink=True)
                if me and me.users == 0:
                    bpy.data.meshes.remove(me)

def build_rooms():
    clear_rooms()
    ACC.clear()
    build_shop(); build_armory(); build_markers2()
    # drop the degenerate placeholder boxes (zero-size calls are ignored by box())
    stats = finalize()
    man = manifest(stats)
    with open(KIT + "rooms2_manifest.json", "w") as f:
        json.dump(man, f, indent=1)
    return man

if __name__ == "__main__" or True:
    MAN = build_rooms()
