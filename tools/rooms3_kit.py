"""Tacticals rooms pass 3: Duels hall (+ west gate, passage, west deck) and Exfil hangar + helicopter pad. Own geometry only.

Run inside Blender 5.2 (Blender MCP) with kit/rooms3_kit.blend open:
    g = {"__name__": "__main__"}; exec(open(r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms3_kit.py").read(), g)
Reuses tools/rooms2_kit.py (which reuses tools/hub_kit.py): materials, box/prism/lathe/cyl/rod, Wall frames, railing, wall_light,
props (crates, drums, cases, ammo cans, benches, shelving, rifles), finalize. Studio coordinates (x east, y up, z north).
Mesh = <piece>__<material>. Pieces: D_* Duels, E_* Exfil, X_Clip (invisible clip), K_Scale3 / K_Marker3 markers.
Never calls read_homefile.
"""
import bpy, bmesh, math, os, json, re
from mathutils import Vector, Matrix

_R2 = r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms2_kit.py"
exec(open(_R2).read().rsplit('if __name__ == "__main__" or True:', 1)[0], globals())

# invisible clip material (Transparency 1 in Studio, collides)
MATS["clip"] = ((255, 255, 255), None, 10, 0.0, 1.0, False, "SmoothPlastic, Transparency 1 (invisible clip)")

# ------------------------------------------------------------------ banded wall zones, parametrised by floor (base) and top
DUELS = dict(base=16.0, body_top=40.0, dark=(40.0, 44.0), upper=(44.0, 58.0), corn=(58.0, 64.0), top=70.0,
             prof=[(0.0, 58.0), (0.9, 60.6), (2.2, 62.6), (3.4, 63.4), (3.4, 64.0)])
HANGAR = dict(base=0.0, body_top=15.4, dark=(15.4, 16.4), upper=(16.4, 18.6), corn=(18.6, 20.0), top=20.0,
              prof=[(0.0, 18.6), (0.5, 19.2), (1.1, 19.6), (1.1, 20.0)])

def bandwall(W, piece, s0, s1, S, T=2.0, ymin=None):
    if s1 - s0 < 0.05:
        return
    b = S["base"]; lo = b if ymin is None else ymin
    if lo < b + 7:
        W.box(piece, "wall_kick", s0, s1, max(b, lo), b + 7.0, -T, 0.3, 0.12)
        if lo <= b:
            W.box(piece, "trim_metal", s0, s1, b, b + 0.8, 0.25, 0.62, 0.1)
    if lo < b + 10:
        W.box(piece, "band_olive", s0, s1, b + 7.1, b + 9.9, -T, 0.5, 0.12)
        W.box(piece, "trim_metal", s0, s1, b + 6.85, b + 7.15, -T, 0.62, 0.06)
        W.box(piece, "trim_metal", s0, s1, b + 9.85, b + 10.15, -T, 0.62, 0.06)
    if lo < S["body_top"]:
        W.box(piece, "wall_body", s0, s1, max(b + 10.0, lo), S["body_top"], -T, 0.0, 0.1)
    d0, d1 = S["dark"]
    if lo < d1:
        W.box(piece, "wall_dark", s0, s1, max(d0, lo), d1, -T, 0.25, 0.1)
        W.box(piece, "trim_light", s0, s1, d1 - 0.2, d1 + 0.3, -T, 0.45, 0.06)
    u0, u1 = S["upper"]
    if lo < u1:
        W.box(piece, "wall_upper", s0, s1, max(u0, lo), u1, -T, 0.0, 0.1)
    c0, c1 = S["corn"]
    prof = [(-T, c0)] + S["prof"] + [(-T, c1)]
    W.prism(piece, "wall_light", prof, s0, s1)
    cd = S["prof"][-1][0]
    if S["top"] > c1 + 0.6:
        W.box(piece, "trim_metal", s0, s1, c1, c1 + 0.6, -T, cd + 0.3, 0.1)
        W.box(piece, "wall_dark", s0, s1, c1 + 0.6, S["top"], -T, cd - 0.2, 0.1)

def pier3(W, piece, s, base, top, light_y=None, lights=None, d=1.2):
    W.box(piece, "wall_light", s - 1.1, s + 1.1, base, top, -TW, d, 0.25, 2)
    W.box(piece, "trim_metal", s - 1.3, s + 1.3, base, base + 1.6, -TW, d + 0.25, 0.12)
    W.box(piece, "band_olive", s - 1.2, s + 1.2, base + 7.1, base + 9.9, -TW, d + 0.15, 0.1)
    W.box(piece, "trim_metal", s - 1.35, s + 1.35, top - 1.9, top - 1.2, -TW, d + 0.4, 0.1)
    if light_y is not None:
        wall_light(W, s, d, light_y, piece=lights)

def window3(W, piece, s0, s1, y0, y1, hw=4.0):
    """Proud metal-framed sky window (frame, mullion, glass) in the ribbed band."""
    sm = (s0 + s1) / 2; hw = min(hw, (s1 - s0) / 2 - 2.0)
    W.box(piece, "trim_metal", sm - hw - 0.6, sm + hw + 0.6, y0 - 0.6, y0, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - hw - 0.6, sm + hw + 0.6, y1, y1 + 0.6, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - hw - 0.6, sm - hw, y0, y1, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm + hw, sm + hw + 0.6, y0, y1, -0.2, 0.6, 0.12)
    W.box(piece, "trim_metal", sm - 0.2, sm + 0.2, y0, y1, -0.1, 0.3, 0.06)
    W.box(piece, "glass", sm - hw, sm + hw, y0, y1, 0.02, 0.12, 0.0)

def floor_grid(piece, x0, x1, z0, z1, xs, zs, y, B=2.5, field="floor_field"):
    """Dark slab grid (0.3 joints), darkest border band, metal kerb strip; slab top = y."""
    g = 0.15
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            box(piece, field, xs[i] + g, xs[i + 1] - g, y - 1.0, y, zs[j] + g, zs[j + 1] - g, 0.06)
    box(piece, "floor_border", x0, x1, y - 1.0, y - 0.06, z0, z1, 0.0)
    for (a, b, c, d) in ((x0, x1, z0, z0 + B), (x0, x1, z1 - B, z1), (x0, x0 + B, z0 + B, z1 - B), (x1 - B, x1, z0 + B, z1 - B)):
        box(piece, "floor_border", a, b, y - 1.0, y + 0.02, c, d, 0.05)
    for (a, b, c, d) in ((x0 + B - 0.2, x1 - B + 0.2, z0 + B - 0.2, z0 + B + 0.2), (x0 + B - 0.2, x1 - B + 0.2, z1 - B - 0.2, z1 - B + 0.2),
                         (x0 + B - 0.2, x0 + B + 0.2, z0 + B, z1 - B), (x1 - B - 0.2, x1 - B + 0.2, z0 + B, z1 - B)):
        box(piece, "trim_metal", a, b, y - 0.2, y + 0.07, c, d, 0.04)

def ring3(piece, mat, cx, cz, r0, r1, y, gaps_deg=(0, 180), half_gap=14, seg=96, h=0.07):
    gs = sorted(gaps_deg)
    for i, gdeg in enumerate(gs):
        nxt = gs[(i + 1) % len(gs)] + (360 if i == len(gs) - 1 else 0)
        a0 = math.radians(gdeg + half_gap); a1 = math.radians(nxt - half_gap)
        lathe(piece, mat, [(r0, -0.4), (r1, -0.4), (r1, h), (r0, h)], cx=cx, cz=cz, seg=seg, a0=a0, a1=a1, y0=y)

def lamp_box(piece, cx, y, cz, sx=2.0, sz=1.0):
    """Ceiling / truss flood box: metal housing, Neon lens on the underside."""
    box(piece, "trim_metal", cx - sx / 2, cx + sx / 2, y, y + 0.7, cz - sz / 2, cz + sz / 2, 0.1)
    box(piece, "dark_metal", cx - sx / 2 - 0.08, cx + sx / 2 + 0.08, y + 0.55, y + 0.8, cz - sz / 2 - 0.08, cz + sz / 2 + 0.08, 0.04)
    box(piece, "neon_lamp", cx - sx / 2 + 0.2, cx + sx / 2 - 0.2, y - 0.08, y + 0.02, cz - sz / 2 + 0.15, cz + sz / 2 - 0.15, 0.0)

# ================================================================== DUELS (floor y 16; hall x -140..-95, z -45..45)
DB = 16.0
DX0, DX1, DZ = -140.0, -95.0, 45.0
DPIER_X = [-128.75, -117.5, -106.25]
# pad footprints from the survey (barrier rectangles), split line, team-1 side (+1 = above split), post (PostCollide) rect
PADS = [
    ("1v1_A", (-105.0, -93.0, -30.0, -7.0), "z", -18.5, +1, (-97.6, -95.6, -19.5, -17.5)),  # post moved: survey post is inside the hub wall
    ("1v1_B", (-105.0, -93.0, 7.0, 30.0), "z", 18.5, -1, (-97.6, -95.6, 17.5, 19.5)),
    ("2v2_A", (-137.0, -123.0, -33.0, -7.0), "z", -20.0, +1, (-138.0, -136.0, -21.0, -19.0)),
    ("2v2_B", (-137.0, -123.0, 7.0, 33.0), "z", 20.0, -1, (-138.0, -136.0, 19.0, 21.0)),
    ("3v3_A", (-127.0, -101.0, -43.0, -29.0), "x", -114.0, +1, (-115.0, -113.0, -30.0, -28.0)),
    ("3v3_B", (-127.0, -101.0, 29.0, 43.0), "x", -114.0, +1, (-115.0, -113.0, 28.0, 30.0)),
]
XLIM = -95.7   # nothing of the pad dressing east of the hub-wall cladding

def build_duels_walls():
    P = "D_Walls"; Pi = "D_Piers"; L = "D_Lights"
    WN_ = Wall("x", DZ, -1); WS_ = Wall("x", -DZ, +1)
    for W in (WN_, WS_):
        bandwall(W, P, DX0 - 2.0, DX1, DUELS)
        edges = [DX0] + DPIER_X + [DX1]
        for i in range(len(edges) - 1):
            a, b = edges[i] + (0.4 if i == 0 else 1.2), edges[i + 1] - (0.4 if i == len(edges) - 2 else 1.2)
            plates(W, P, a, b, 26.6, 39.4, 0.0, 0.3)
            plates(W, P, a, b, 17.3, 22.5, 0.3, 0.55)
            if i % 2 == 0:
                window3(W, P, edges[i], edges[i + 1], 47.0, 55.0)
            else:
                W.box(L, "neon_lamp", edges[i] + 2.0, edges[i + 1] - 2.0, 50.6, 50.9, 0.0, 0.3, 0.0)
        for s in DPIER_X:
            pier3(W, Pi, s, DB, 64.0, light_y=DB + 14.2, lights=L)
    # east: cladding over the hub west wall's Duels face (x -95), door z +-5.5 (y 16..24)
    WE_ = Wall("z", DX1, -1)
    for (a, b) in ((-DZ, -5.5), (5.5, DZ)):
        bandwall(WE_, P, a, b, DUELS, T=0.02)
        plates(WE_, P, a + (0.4 if a < 0 else 4.0), b - (4.0 if a < 0 else 0.4), 26.6, 39.4, 0.0, 0.3, cols=3)
    bandwall(WE_, P, -5.5, 5.5, DUELS, T=0.02, ymin=28.4)
    for s in (-37.5, 37.5):
        pier3(WE_, Pi, s, DB, 64.0, light_y=DB + 14.2, lights=L)
    # corner fills (hub wall ends at |z| 44)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 44.0, sg * 47.0))
        box(P, "wall_dark", -97.0, -90.0, 0.0, 70.0, z0, z1, 0.1)
    # Duels-side door portal (clear 11 x 8 kept: reveal outside +-5.5, head at 24)
    D = "D_Door"
    for sg in (-1, 1):
        a, b = sorted((sg * 5.5, sg * 6.9))
        WE_.box(D, "wall_light", a, b, DB, 28.4, 0.0, 1.0, 0.25, 2)
        WE_.box(D, "trim_metal", a - 0.05, b + 0.05, DB, DB + 1.6, 0.0, 1.2, 0.1)
        WE_.box(D, "band_olive", a, b, DB + 7.1, DB + 9.9, 0.0, 1.12, 0.08)
        a2, b2 = sorted((sg * 5.5, sg * 5.75))
        WE_.box(D, "trim_metal", a2, b2, DB, 24.0, 0.0, 1.05, 0.03)
    WE_.box(D, "wall_light", -6.9, 6.9, 24.0, 28.4, 0.0, 1.0, 0.25, 2)
    WE_.box(D, "band_olive", -6.9, 6.9, 24.8, 27.6, 0.0, 1.15, 0.08)
    WE_.box(D, "trim_metal", -5.75, 5.75, 24.0, 24.25, 0.0, 1.05, 0.03)
    WE_.box(D, "hazard", -5.5, 5.5, DB, DB + 0.08, 0.0, 1.1, 0.0)
    WE_.box("D_Signs", "label_cream", -2.6, 2.6, 28.8, 29.6, 0.0, 0.3, 0.04)

def build_duels_west():
    """West gate: concrete base + glazed screen at x -140..-142 with a 9 x 12 portal at z +-4.5, lined passage to x -155."""
    W = Wall("z", DX0, +1); P = "D_West"
    T = 2.0
    for (a, b) in ((-DZ - 2.0, -8.5), (8.5, DZ + 2.0)):
        W.box(P, "wall_kick", a, b, DB, DB + 7.0, -T, 0.3, 0.12)
        W.box(P, "trim_metal", a, b, DB, DB + 0.8, 0.25, 0.62, 0.1)
        W.box(P, "band_olive", a, b, DB + 7.1, DB + 9.9, -T, 0.5, 0.12)
        W.box(P, "trim_metal", a, b, DB + 6.85, DB + 7.15, -T, 0.62, 0.06)
        W.box(P, "trim_metal", a, b, DB + 9.85, DB + 10.15, -T, 0.62, 0.06)
        W.box(P, "wall_body", a, b, 26.15, 26.6, -T, 0.2, 0.06)
        W.box(P, "trim_light", a, b, 26.6, 27.0, -T, 0.8, 0.08)        # sill
    # head over the portal + glazing frame
    W.box(P, "wall_light", -8.5, 8.5, 28.0, 32.0, -T, 1.0, 0.25, 2)
    W.box(P, "band_olive", -8.5, 8.5, 29.0, 31.0, -T, 1.15, 0.08)
    W.box(P, "trim_metal", -8.6, 8.6, 28.75, 29.05, -T, 1.25, 0.04)
    W.box(P, "trim_metal", -8.6, 8.6, 30.95, 31.25, -T, 1.25, 0.04)
    W.box(P, "trim_light", -8.5, 8.5, 32.0, 32.4, -T, 0.8, 0.08)
    mull = [-45.0, -36.0, -26.0, -15.5, -8.5, 8.5, 15.5, 26.0, 36.0, 45.0]
    for zz in mull:
        W.box(P, "beam_metal", zz - 0.35, zz + 0.35, 26.6, 58.0, -1.6, 0.35, 0.06)
    for yy in (37.0, 47.5):
        W.box(P, "beam_metal", -DZ, DZ, yy - 0.25, yy + 0.25, -1.6, 0.3, 0.05)
    W.box(P, "beam_metal", -DZ, DZ, 57.6, 58.2, -1.6, 0.4, 0.06)
    for (a, b, y0) in ((-DZ, -8.5, 27.0), (8.5, DZ, 27.0), (-8.5, 8.5, 32.4)):
        W.box(P, "glass", a, b, y0, 57.6, -1.05, -0.95, 0.0)
    # structural piers (proud 0.8 so the 2v2 posts at x -138 stay clear) + top zones
    for zz in (-26.0, 26.0):
        W.box(P, "wall_light", zz - 1.1, zz + 1.1, DB, 64.0, -T, 0.8, 0.25, 2)
        W.box(P, "trim_metal", zz - 1.3, zz + 1.3, DB, DB + 1.6, -T, 1.0, 0.12)
        W.box(P, "band_olive", zz - 1.2, zz + 1.2, DB + 7.1, DB + 9.9, -T, 0.95, 0.1)
        wall_light(W, zz, 0.8, DB + 14.2, piece="D_Lights")
    prof = [(-T, 58.2)] + [(0.0, 58.2), (0.9, 60.6), (2.2, 62.6), (3.4, 63.4), (3.4, 64.0)] + [(-T, 64.0)]
    W.prism(P, "wall_light", prof, -DZ - 2.0, DZ + 2.0)
    W.box(P, "trim_metal", -DZ - 2.0, DZ + 2.0, 64.0, 64.6, -T, 3.7, 0.1)
    W.box(P, "wall_dark", -DZ - 2.0, DZ + 2.0, 64.6, 70.0, -T, 3.2, 0.1)
    # portal cheeks + reveal (clear 9.0 wide x 12 high: y 16..28)
    for sg in (-1, 1):
        a, b = sorted((sg * 4.5, sg * 8.5))
        W.box(P, "wall_light", a, b, DB, 28.0, -T, 1.0, 0.25, 2)
        W.box(P, "trim_metal", a - 0.05, b + 0.05, DB, DB + 1.6, -T, 1.2, 0.1)
        W.box(P, "band_olive", a, b, DB + 7.1, DB + 9.9, -T, 1.12, 0.08)
        a2, b2 = sorted((sg * 4.5, sg * 4.75))
        W.box(P, "trim_metal", a2, b2, DB, 28.0, -T, 1.05, 0.03)
    W.box(P, "trim_metal", -4.75, 4.75, 27.75, 28.0, -T, 1.05, 0.03)
    W.box(P, "hazard", -4.5, 4.5, DB, DB + 0.08, 0.0, 1.0, 0.0)
    sign_board("D_Signs", W, -5.0, 5.0, 32.8, 35.2, d=0.2)
    W.box("D_Signs", "label_cream", -2.4, 2.4, 33.4, 34.6, 1.02, 1.08, 0.0)
    # passage x -155..-142 (inner faces z +-4.9, ring frames keep 9.0 x 12.0 clear), deck-side portal
    S = "D_Pass"
    box(S, "plate_metal", -155.0, -140.0, DB - 0.25, DB, -5.6, 5.6, 0.03)
    for sg in (-1, 1):
        a, b = sorted((sg * 4.4, sg * 5.6))
        box(S, "floor_border", -155.0, -142.0, DB - 0.25, DB + 0.02, a, b, 0.02)
        za, zb = sorted((sg * 4.9, sg * 6.4))
        box(S, "wall_kick", -155.0, -142.0, DB, DB + 7.0, za, zb, 0.1)
        box(S, "band_olive", -155.0, -142.0, DB + 7.1, DB + 9.9, za - (0.12 if sg < 0 else 0), zb + (0.12 if sg > 0 else 0), 0.08)
        box(S, "door_leaf", -155.0, -142.0, DB + 9.9, 28.6, za, zb, 0.06)
        zc, zd = sorted((sg * 4.9, sg * 4.6))
        box(S, "trim_metal", -155.0, -142.0, DB, DB + 0.8, zc, zd, 0.05)
        box(S, "neon_cream", -155.0, -140.0, DB - 0.4, DB + 0.07, sg * 3.45 - 0.19, sg * 3.45 + 0.19, 0.0)
        for x in (-152.0, -148.0, -144.5):
            ze, zf = sorted((sg * 4.5, sg * 4.9))
            box(S, "beam_metal", x - 0.4, x + 0.4, DB, 28.6, ze, zf, 0.06)
    for x in (-152.0, -148.0, -144.5):
        box(S, "beam_metal", x - 0.4, x + 0.4, 28.0, 28.6, -4.9, 4.9, 0.06)
    box(S, "ceiling", -155.0, -142.0, 28.6, 29.8, -6.6, 6.6, 0.08)
    box(S, "trim_metal", -154.5, -142.5, 28.3, 28.6, -0.9, 0.9, 0.05)
    box(S, "neon_lamp", -154.2, -142.8, 28.2, 28.32, -0.55, 0.55, 0.0)
    for sg in (-1, 1):  # deck-side end portal x -156.4..-155
        a, b = sorted((sg * 4.5, sg * 7.6))
        box(S, "wall_light", -156.4, -154.6, DB, 30.4, a, b, 0.25, 2)
        box(S, "band_olive", -156.55, -154.5, DB + 7.1, DB + 9.9, a, b, 0.08)
        box(S, "trim_metal", -156.6, -154.5, DB, DB + 1.6, a - 0.05, b + 0.05, 0.1)
    box(S, "wall_light", -156.4, -154.6, 28.0, 30.4, -7.6, 7.6, 0.25, 2)
    box(S, "band_olive", -156.55, -154.5, 28.6, 29.8, -7.6, 7.6, 0.06)
    box(S, "hazard", -156.4, -155.4, DB, DB + 0.08, -4.5, 4.5, 0.0)

def build_duels_floor():
    F = "D_Floor"; Ln = "D_Lines"
    floor_grid(F, DX0, DX1, -DZ, DZ, [-137.5] + DPIER_X + [-97.5], [-42.5, -29.0, -7.0, 7.0, 29.0, 42.5], DB)
    # centre lane (gate -> door), medallion at (-114, 0)
    cx = -114.0
    for (a, b) in ((-139.6, cx - 8.2), (cx + 8.2, -95.4)):
        box(F, "floor_insert", a, b, DB - 0.2, DB + 0.03, -3.0, 3.0, 0.03)
        for zz in (-3.45, 3.45):
            box(Ln, "neon_cream", a, b, DB - 0.4, DB + 0.07, zz - 0.19, zz + 0.19, 0.0)
    lathe(F, "floor_border", [(0.0, -0.3), (6.6, -0.3), (6.6, 0.03), (0.0, 0.03)], cx=cx, cz=0.0, seg=96, y0=DB)
    lathe(F, "plate_metal", [(3.0, -0.2), (4.6, -0.2), (4.6, 0.05), (3.0, 0.05)], cx=cx, cz=0.0, seg=96, y0=DB)
    cyl(F, "disc_center", cx, 0.0, 2.2, DB - 0.2, DB + 0.06, seg=48, bev=0.05)
    ring3(Ln, "neon_olive", cx, 0.0, 7.2, 7.55, DB, gaps_deg=(0, 180), half_gap=22)
    ring3(Ln, "neon_cream", cx, 0.0, 4.75, 5.0, DB, gaps_deg=(0, 90, 180, 270), half_gap=18)
    for k in range(24):
        a = math.radians(15 * k); ca, sa = math.cos(a), math.sin(a)
        r0, r1, w = 3.3, 4.3, 0.07
        pts = [(cx + r0 * ca - w * sa, DB + 0.05, r0 * sa + w * ca), (cx + r1 * ca - w * sa, DB + 0.05, r1 * sa + w * ca),
               (cx + r1 * ca + w * sa, DB + 0.05, r1 * sa - w * ca), (cx + r0 * ca + w * sa, DB + 0.05, r0 * sa - w * ca)]
        prism(F, "dark_metal", pts, (0, 0.03, 0))
    for q in (0, 180):  # cream arrowheads on the lane pointing to the two exits
        a = math.radians(q); ca = math.cos(a)
        tri = [(cx + 1.0 * ca, DB + 0.06, -0.9), (cx + 2.6 * ca, DB + 0.06, 0.0), (cx + 1.0 * ca, DB + 0.06, 0.9), (cx + 1.5 * ca, DB + 0.06, 0.0)]
        prism(Ln, "neon_cream", tri, (0, 0.05, 0))

def build_pads():
    P = "D_Pads"; Ln = "D_Lines"
    for k, (name, (x0, x1, z0, z1), ax, split, t1side, post) in enumerate(PADS):
        x1c = min(x1, XLIM)
        hy = DB + 0.07 + 0.004 * k    # tiny per-pad height offset where footprints overlap
        o, kw, nw = 0.1, 0.75, 0.38
        # metal kerb ring outside the barrier rectangle (open on the wall side for the 1v1 pads)
        ko0, ko1 = o + nw, o + nw + kw
        box(P, "plate_metal", x0 - ko1, x1c + (ko1 if x1c == x1 else 0.0), DB - 0.2, DB + 0.12 + 0.004 * k, z0 - ko1, z0 - ko0, 0.06)
        box(P, "plate_metal", x0 - ko1, x1c + (ko1 if x1c == x1 else 0.0), DB - 0.2, DB + 0.12 + 0.004 * k, z1 + ko0, z1 + ko1, 0.06)
        box(P, "plate_metal", x0 - ko1, x0 - ko0, DB - 0.2, DB + 0.12 + 0.004 * k, z0 - ko0, z1 + ko0, 0.06)
        if x1c == x1:
            box(P, "plate_metal", x1 + ko0, x1 + ko1, DB - 0.2, DB + 0.12 + 0.004 * k, z0 - ko0, z1 + ko0, 0.06)
        # team cells: Team1 cream, Team2 olive (RIVALS purple / gold role); Neon line on the three outer sides of each cell
        if ax == "z":
            cells = [((x0, x1c, split, z1), +1), ((x0, x1c, z0, split), -1)]
        else:
            cells = [((split, x1c, z0, z1), +1), ((x0, split, z0, z1), -1)]
        for (cx0, cx1, cz0, cz1), side in cells:
            mat = "neon_cream" if side == t1side else "neon_olive"
            a0, a1 = o, o + nw
            sides = []
            if ax == "z":
                outer_z = cz1 if side > 0 else cz0
                sides.append(("z", outer_z, cx0 - a1, cx1 + (a1 if x1c == x1 else 0.0)))
                sides.append(("x", cx0, cz0, cz1))
                if x1c == x1:
                    sides.append(("x", cx1, cz0, cz1))
            else:
                sides.append(("z", cz0, cx0, cx1)); sides.append(("z", cz1, cx0, cx1))
                outer_x = cx1 if side > 0 else cx0
                sides.append(("x", outer_x, cz0 - a1, cz1 + a1))
            for (kind, v, s0, s1) in sides:
                if kind == "z":
                    sgn = 1 if v >= (cz0 + cz1) / 2 else -1
                    za, zb = sorted((v + sgn * a0, v + sgn * a1))
                    box(Ln, mat, s0, s1, DB - 0.4, hy, za, zb, 0.0)
                else:
                    sgn = 1 if v >= (cx0 + cx1) / 2 else -1
                    xa, xb = sorted((v + sgn * a0, v + sgn * a1))
                    box(Ln, mat, xa, xb, DB - 0.4, hy, s0, s1, 0.0)
            # cream label plate on the kerb at the cell's outer edge (team / slot text by SurfaceGui)
            if ax == "z":
                mz = (cz1 + ko0 + 0.37) if side > 0 else (cz0 - ko0 - 0.37)
                mx = (cx0 + cx1) / 2
                box(P, "label_cream", mx - 1.3, mx + 1.3, DB + 0.12, DB + 0.16 + 0.004 * k, mz - 0.22, mz + 0.22, 0.0)
            else:
                mx = (cx1 + ko0 + 0.37) if side > 0 else (cx0 - ko0 - 0.37)
                mz = (cz0 + cz1) / 2
                box(P, "label_cream", mx - 0.22, mx + 0.22, DB + 0.12, DB + 0.16 + 0.004 * k, mz - 1.3, mz + 1.3, 0.0)
        # split marker: metal strip with a cream / olive half at each end (outside the cells)
        if ax == "z":
            for xe in ([x0 - ko1] + ([x1 + ko0] if x1c == x1 else [])):
                box(P, "dark_metal", xe, xe + kw, DB + 0.12, DB + 0.16, split - 0.5, split + 0.5, 0.02)
        else:
            for ze in (z0 - ko1, z1 + ko0):
                box(P, "dark_metal", split - 0.5, split + 0.5, DB + 0.12, DB + 0.16, ze, ze + kw, 0.02)
        # pylon on the PostCollide footprint (2 x 5 x 2): Holo board floats above at y 24-25
        px0, px1, pz0, pz1 = post
        box(P, "trim_metal", px0 - 0.15, px1 + 0.15, DB, DB + 0.9, pz0 - 0.15, pz1 + 0.15, 0.1)
        box(P, "wall_light", px0 + 0.05, px1 - 0.05, DB + 0.9, DB + 5.0, pz0 + 0.05, pz1 - 0.05, 0.2, 2)
        box(P, "band_olive", px0, px1, DB + 3.0, DB + 3.35, pz0, pz1, 0.04)
        box(P, "trim_metal", px0 - 0.2, px1 + 0.2, DB + 5.0, DB + 5.45, pz0 - 0.2, pz1 + 0.2, 0.08)
        box(P, "dark_metal", px0 + 0.1, px1 - 0.1, DB + 5.45, DB + 5.6, pz0 + 0.1, pz1 - 0.1, 0.03)
        pmx, pmz = (px0 + px1) / 2, (pz0 + pz1) / 2
        if ax == "z":   # faces normal to z look at the two cells; faces normal to x carry the mode plate
            for side in (+1, -1):
                mat = "neon_cream" if side == t1side else "neon_olive"
                zf = pz1 if side > 0 else pz0
                za, zb = sorted((zf, zf + side * 0.06))
                box(Ln, mat, pmx - 0.2, pmx + 0.2, DB + 1.2, DB + 4.7, za, zb, 0.0)
            for xf in (px0, px1):
                sgn = -1 if xf == px0 else 1
                xa, xb = sorted((xf, xf + sgn * 0.05))
                box(P, "label_cream", xa, xb, DB + 3.6, DB + 4.7, pmz - 0.75, pmz + 0.75, 0.0)
        else:
            for side in (+1, -1):
                mat = "neon_cream" if side == t1side else "neon_olive"
                xf = px1 if side > 0 else px0
                xa, xb = sorted((xf, xf + side * 0.06))
                box(Ln, mat, xa, xb, DB + 1.2, DB + 4.7, pmz - 0.2, pmz + 0.2, 0.0)
            for zf in (pz0, pz1):
                sgn = -1 if zf == pz0 else 1
                za, zb = sorted((zf, zf + sgn * 0.05))
                box(P, "label_cream", pmx - 0.75, pmx + 0.75, DB + 3.6, DB + 4.7, za, zb, 0.0)

def build_duels_roof():
    R = "D_Roof"; Tr = "D_Trusses"; L = "D_Lights"
    y0, y1 = 66.0, 70.0
    wx0, wx1, wz = -131.0, -104.0, 36.0     # open sky well
    strips = [(-142.0, -93.5, wz, 47.0), (-142.0, -93.5, -47.0, -wz), (wx1, -93.5, -wz, wz), (-142.0, wx0, -wz, wz)]
    for (a, b, c, d) in strips:
        box(R, "ceiling", a, b, y0, y1, c, d, 0.1)
    # coffers + lamp strips under the ring
    for (a, b, c, d) in ((wx0, wx1, wz + 1.0, DZ - 1.2), (wx0, wx1, -DZ + 1.2, -wz - 1.0)):
        xs = [DX0 + 1.0] + DPIER_X + [DX1 - 1.0]
        for i in range(len(xs) - 1):
            box(R, "ceiling_gloss", xs[i] + 1.3, xs[i + 1] - 1.3, y0 - 0.35, y0, c, d, 0.12)
            box(R, "trim_metal", xs[i] + 1.05, xs[i + 1] - 1.05, y0 - 0.5, y0 - 0.32, c - 0.25, d + 0.25, 0.04)
            zm = (c + d) / 2
            box(L, "trim_metal", xs[i] + 2.2, xs[i + 1] - 2.2, y0 - 0.6, y0 - 0.3, zm - 0.75, zm + 0.75, 0.06)
            box(L, "neon_lamp", xs[i] + 2.5, xs[i + 1] - 2.5, y0 - 0.72, y0 - 0.55, zm - 0.45, zm + 0.45, 0.0)
    for (a, b) in ((wx1 + 1.2, DX1 - 1.0), (DX0 + 1.0, wx0 - 1.2)):
        for (c, d) in ((-wz + 1.0, -12.0), (-10.0, 10.0), (12.0, wz - 1.0)):
            box(R, "ceiling_gloss", a, b, y0 - 0.35, y0, c, d, 0.12)
            box(R, "trim_metal", a - 0.25, b + 0.25, y0 - 0.5, y0 - 0.32, c - 0.25, d + 0.25, 0.04)
        xm = (a + b) / 2
        box(L, "trim_metal", xm - 0.75, xm + 0.75, y0 - 0.6, y0 - 0.3, -wz + 2.0, wz - 2.0, 0.06)
        box(L, "neon_lamp", xm - 0.45, xm + 0.45, y0 - 0.72, y0 - 0.55, -wz + 2.3, wz - 2.3, 0.0)
    # well fascia + olive Neon line round the opening
    for (a, b, c, d) in ((wx0, wx1, wz - 0.6, wz), (wx0, wx1, -wz, -wz + 0.6), (wx0, wx0 + 0.6, -wz, wz), (wx1 - 0.6, wx1, -wz, wz)):
        box(R, "trim_light", a, b, y0 - 1.2, y1 + 0.4, c, d, 0.08)
    for (a, b, c, d) in ((wx0 + 0.6, wx1 - 0.6, wz - 0.85, wz - 0.6), (wx0 + 0.6, wx1 - 0.6, -wz + 0.6, -wz + 0.85),
                         (wx0 + 0.6, wx0 + 0.85, -wz + 0.6, wz - 0.6), (wx1 - 0.85, wx1 - 0.6, -wz + 0.6, wz - 0.6)):
        box(Tr, "neon_olive", a, b, y0 - 1.2, y0 - 0.95, c, d, 0.0)
    # three open trusses across the well (top chord 69..70, bottom chord 62.4..63.2), flood boxes under them
    for x in (-124.5, -117.5, -110.5):
        box(Tr, "beam_metal", x - 0.5, x + 0.5, 69.0, 70.0, -wz - 1.0, wz + 1.0, 0.08)
        box(Tr, "beam_metal", x - 0.5, x + 0.5, 62.4, 63.2, -wz, wz, 0.08)
        zs = [-wz + 6.0 * k for k in range(13)]
        for z in zs:
            box(Tr, "beam_metal", x - 0.3, x + 0.3, 63.2, 69.0, z - 0.25, z + 0.25, 0.04)
        for i in range(len(zs) - 1):
            za, zb = (zs[i], zs[i + 1]) if i % 2 == 0 else (zs[i + 1], zs[i])
            rod(Tr, "beam_metal", (x, 63.2, za), (x, 69.0, zb), 0.18, 8)
        for z in (-wz, wz):
            prism(Tr, "beam_metal", [(x - 0.4, 62.4, z), (x - 0.4, 66.0, z), (x - 0.4, 66.0, z + (2.5 if z > 0 else -2.5))], (0.8, 0, 0))
        for z in (-18.0, -6.0, 6.0, 18.0):
            lamp_box(L, x, 61.6, z, 1.4, 2.2)
    for z in (-12.0, 12.0):   # tie beams between the trusses
        box(Tr, "beam_metal", wx0, wx1, 68.6, 69.4, z - 0.3, z + 0.3, 0.05)

def build_duels_base():
    B = "D_Base"
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 45.0, sg * 47.0))
        box(B, "wall_dark", -142.0, -95.0, 4.0, 16.0, z0, z1, 0.1)
        box(B, "trim_metal", -142.2, -95.0, 15.2, 16.0, z0 - 0.1, z1 + 0.1, 0.08)
        box(B, "band_olive", -142.1, -95.0, 11.1, 12.9, z0 - 0.05, z1 + 0.05, 0.06)
        prism(B, "beam_metal", [(-142.0, 4.0, sg * 47.0), (-142.0, 4.0, sg * 43.0), (-142.0, 0.5, sg * 43.0)], (47.0, 0, 0))
    box(B, "wall_dark", -142.0, -140.0, 4.0, 16.0, -45.0, 45.0, 0.1)
    box(B, "band_olive", -142.1, -141.0, 11.1, 12.9, -45.0, 45.0, 0.06)
    box(B, "wall_dark", -141.0, -95.0, 2.5, 4.0, -45.0, 45.0, 0.1)
    box(B, "beam_metal", -140.0, -96.0, 0.5, 2.5, -43.0, 43.0, 0.2)

def build_deck():
    """West deck x -200..-155, z -30..30, floor y 16, fenced inside the invisible HeliN/S/End walls."""
    F = "D_Deck"
    floor_grid(F, -200.0, -155.0, -30.0, 30.0, [-197.5, -186.0, -175.0, -164.5, -157.5], [-27.5, -15.0, -4.5, 4.5, 15.0, 27.5], DB)
    box(F, "floor_insert", -197.0, -156.0, DB - 0.2, DB + 0.03, -3.0, 3.0, 0.03)
    for zz in (-3.45, 3.45):
        box("D_Lines", "neon_cream", -197.0, -156.0, DB - 0.4, DB + 0.07, zz - 0.19, zz + 0.19, 0.0)
    box(F, "hazard", -199.0, -198.0, DB, DB + 0.08, -6.0, 6.0, 0.0)
    # underside: slab + fascia beam + chamfered keel (floating base)
    box(F, "wall_dark", -200.0, -155.0, 13.4, 15.0, -30.0, 30.0, 0.1)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 29.6, sg * 30.4))
        box(F, "beam_metal", -200.4, -155.0, 14.0, 15.6, z0, z1, 0.08)
        prism(F, "wall_dark", [(-199.0, 13.4, sg * 29.0), (-199.0, 13.4, sg * 20.0), (-199.0, 8.0, sg * 20.0)], (43.0, 0, 0))
    box(F, "beam_metal", -200.4, -199.6, 14.0, 15.6, -30.4, 30.4, 0.08)
    box(F, "wall_dark", -199.0, -156.0, 8.0, 13.4, -20.0, 20.0, 0.15)
    # edge kerb + guard rail (inside the invisible walls at z +-30 / x -200)
    R = "D_DeckRail"
    for (a, b, c, d) in ((-200.0, -155.0, 28.9, 29.9), (-200.0, -155.0, -29.9, -28.9), (-199.9, -198.9, -28.9, 28.9)):
        box(R, "wall_kick", a, b, DB, DB + 0.9, c, d, 0.1)
        box(R, "trim_metal", a - 0.05, b + 0.05, DB + 0.9, DB + 1.05, c - 0.05, d + 0.05, 0.04)
    box(R, "neon_cream", -198.9, -198.84, DB + 0.3, DB + 0.55, -28.9, 28.9, 0.0)
    for sg in (-1, 1):
        box(R, "neon_cream", -198.9, -155.0, DB + 0.3, DB + 0.55, sg * 28.9 - (0.06 if sg > 0 else 0), sg * 28.9 + (0.06 if sg < 0 else 0), 0.0)
        railing(R, (-157.0, DB + 1.05, sg * 29.4), (-199.4, DB + 1.05, sg * 29.4), 3.2)
    railing(R, (-199.4, DB + 1.05, -29.4), (-199.4, DB + 1.05, 29.4), 3.2)
    # props: crate stacks, lookout scope, floodlight masts
    Pp = "D_Props"
    prop_crate(Pp, -195.4, DB, 25.0, 4.0); prop_crate(Pp, -191.2, DB, 25.3, 3.0); prop_crate(Pp, -195.2, DB + 4.0, 25.1, 3.0)
    prop_longcase(Pp, -186.0, DB, 26.4, True); prop_drum(Pp, -195.6, DB, -24.6); prop_drum(Pp, -192.6, DB, -25.6)
    prop_crate(Pp, -170.0, DB, -26.0, 4.0); ammo_can(Pp, -167.2, DB, -26.4)
    for zz in (-12.0, 12.0):
        scope(Pp, -196.6, DB, zz)
    for zz in (-26.5, 26.5):
        mast(Pp, -160.0, DB, zz, 14.0, face=-1)

def scope(piece, cx, y, cz):
    """Lookout rangefinder on a tripod, aimed out past the rail (-x)."""
    for a in (0, 120, 240):
        r = math.radians(a)
        rod(piece, "dark_metal", (cx, y + 3.6, cz), (cx + 1.0 * math.cos(r), y, cz + 1.0 * math.sin(r)), 0.07, 6)
    cyl(piece, "trim_metal", cx, cz, 0.28, y + 3.5, y + 3.9, seg=12, bev=0.03)
    box(piece, "case_dark", cx - 0.5, cx + 0.5, y + 3.9, y + 4.55, cz - 0.42, cz + 0.42, 0.1)
    rod(piece, "dark_metal", (cx - 0.4, y + 4.25, cz - 0.2), (cx - 1.7, y + 4.35, cz - 0.2), 0.17, 12)
    rod(piece, "dark_metal", (cx - 0.4, y + 4.25, cz + 0.2), (cx - 1.7, y + 4.35, cz + 0.2), 0.17, 12)
    box(piece, "drum_olive", cx - 0.35, cx + 0.35, y + 4.55, y + 4.7, cz - 0.3, cz + 0.3, 0.03)
    rod(piece, "dark_metal", (cx + 0.5, y + 4.2, cz), (cx + 1.3, y + 3.6, cz), 0.05, 6)

def mast(piece, cx, y, cz, h, face=1):
    """Floodlight mast: plinth, pole, crossarm, two lamp heads facing +-x."""
    box(piece, "wall_light", cx - 0.9, cx + 0.9, y, y + 1.0, cz - 0.9, cz + 0.9, 0.15, 2)
    box(piece, "trim_metal", cx - 1.0, cx + 1.0, y + 1.0, y + 1.2, cz - 1.0, cz + 1.0, 0.05)
    cyl(piece, "beam_metal", cx, cz, 0.32, y + 1.2, y + h, seg=12, bev=0.04)
    box(piece, "band_olive", cx - 0.36, cx + 0.36, y + 7.1, y + 9.9, cz - 0.36, cz + 0.36, 0.05)
    box(piece, "beam_metal", cx - 0.2, cx + 0.2, y + h - 0.4, y + h, cz - 2.0, cz + 2.0, 0.04)
    for dz in (-1.3, 1.3):
        hx = cx + face * 0.5
        box(piece, "trim_metal", hx - 0.55, hx + 0.55, y + h - 1.5, y + h - 0.4, cz + dz - 0.7, cz + dz + 0.7, 0.1)
        xa, xb = sorted((hx + face * 0.55, hx + face * 0.62))
        box(piece, "neon_lamp", xa, xb, y + h - 1.35, y + h - 0.55, cz + dz - 0.55, cz + dz + 0.55, 0.0)
        box(piece, "dark_metal", hx - 0.6, hx + 0.6, y + h - 0.45, y + h - 0.3, cz + dz - 0.75, cz + dz + 0.75, 0.02)
    cyl(piece, "neon_olive", cx, cz, 0.18, y + h, y + h + 0.35, seg=10, bev=0.04)   # beacon

# ================================================================== EXFIL (hangar x 105..126 roof 20; pad x 126..152, z -27..27)
HX0, HX1, HZ = 105.0, 126.0, 27.0
PX1 = 152.0
CAM = ((120.0, 9.0, -18.0), (133.0, 4.0, 2.0))   # ExfilFX cutscene camera: keep this sightline clear

def build_hangar():
    P = "E_Walls"; Pi = "E_Piers"; L = "E_Lights"
    WN_ = Wall("x", HZ, -1); WS_ = Wall("x", -HZ, +1); WW_ = Wall("z", HX0, +1)
    for W in (WN_, WS_):
        bandwall(W, P, 103.0, HX1 - 1.2, HANGAR)
        for (a, b) in ((HX0 + 0.4, 108.8), (111.2, 114.8), (117.2, 120.8)):
            plates(W, P, a, b, 10.6, 15.0, 0.0, 0.3)
        for s in (110.0, 116.0, 122.0):
            pier3(W, Pi, s, 0.0, 20.0, light_y=13.0 if s != 122.0 else None, lights=L)
    for (a, b) in ((-HZ - 2.0, -15.2), (15.2, HZ + 2.0)):
        bandwall(WW_, P, a, b, HANGAR)
        plates(WW_, P, a + (0.4 if a < 0 else 1.0), b - (1.0 if a < 0 else 0.4), 10.6, 15.0, 0.0, 0.3)
    # hangar-side tunnel portal (clear 22.0 x 18.0): cheeks, reveal, head, band wrap
    T = "E_Portal"
    for sg in (-1, 1):
        a, b = sorted((sg * 11.0, sg * 15.2))
        WW_.box(T, "wall_light", a, b, 0.0, 20.0, 0.0, 1.4, 0.3, 2)
        WW_.box(T, "trim_metal", a - 0.05, b + 0.05, 0.0, 1.8, 0.0, 1.6, 0.12)
        WW_.box(T, "band_olive", a, b, 7.1, 9.9, 0.0, 1.55, 0.1)
        a2, b2 = sorted((sg * 11.0, sg * 11.3))
        WW_.box(T, "trim_metal", a2, b2, 0.0, 18.0, 0.0, 1.45, 0.04)
        wall_light(WW_, sg * 13.1, 1.4, 13.0, piece=L)
    WW_.box(T, "wall_light", -15.2, 15.2, 18.0, 20.0, 0.0, 1.4, 0.2, 2)
    WW_.box(T, "trim_metal", -11.3, 11.3, 18.0, 18.25, 0.0, 1.45, 0.04)
    WW_.box(T, "hazard", -11.0, 11.0, 0.0, 0.08, 1.4, 2.2, 0.0)
    WW_.box("E_Signs", "label_cream", -2.4, 2.4, 18.55, 19.45, 1.4, 1.5, 0.03)
    # ceiling (slab 20..21.5, I-beams on the pier lines, purlins, coffers, lamp strips)
    room_ceiling("E_Ceiling", L, HX0, HX1, -HZ, HZ, 20.0, [110.0, 116.0, 122.0], [-13.5, 13.5], 1.8, [107.5, 119.0, 124.0])
    downlight(L, 114.0, 0.0, 19.25)            # home of RoomLight L_Hangar
    # mouth at x 126: cheek columns, roll-up door guides, header with the door's bottom slats (clear 52.4 wide, 17.0 high)
    M = "E_Mouth"
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 26.2, sg * 29.0))
        box(M, "wall_light", 124.6, 127.6, 0.0, 21.5, z0, z1, 0.3, 2)
        box(M, "trim_metal", 124.5, 127.7, 0.0, 1.8, z0 - 0.05, z1 + 0.05, 0.12)
        box(M, "band_olive", 124.5, 127.7, 7.1, 9.9, z0 - 0.04, z1 + 0.04, 0.1)
        za, zb = sorted((sg * 25.8, sg * 26.2))
        box(M, "trim_metal", 125.4, 126.8, 0.0, 17.0, za, zb, 0.04)
        box(M, "dark_metal", 125.75, 126.45, 0.0, 17.0, za - (0.3 if sg > 0 else 0), zb + (0.3 if sg < 0 else 0), 0.03)
    box(M, "wall_light", 124.6, 127.6, 18.4, 21.5, -29.0, 29.0, 0.3, 2)
    box(M, "trim_metal", 124.5, 127.7, 18.1, 18.45, -29.0, 29.0, 0.06)
    for i in range(2):   # rolled-up door: the two bottom slats show under the header
        y0 = 17.0 + i * 0.55
        box(M, "door_leaf", 125.6, 126.6, y0, y0 + 0.5, -25.8, 25.8, 0.08)
    box(M, "band_olive", 125.55, 126.65, 17.0, 17.35, -25.8, 25.8, 0.04)
    for sg in (-1, 1):   # capsule lights on the cheeks, facing the pad
        wall_light(Wall("z", 127.6, +1), sg * 27.6, 0.0, 13.0, piece=L)
    # EXFIL board inside the header (above every cutscene sightline: lowest board edge 15.4)
    W = Wall("z", 124.6, -1)
    sign_board("E_Signs", W, -6.0, 6.0, 15.4, 17.9, d=0.0)
    W.box("E_Signs", "label_cream", -2.4, 2.4, 14.95, 15.3, 0.4, 0.62, 0.03)

def build_exfil_floor():
    F = "E_Floor"; Ln = "E_Lines"
    floor_grid(F, HX0, HX1 - 0.6, -HZ, HZ, [107.5, 113.0, 119.0, 123.0], [-24.5, -13.5, 0.0, 13.5, 24.5], 0.0)
    box(F, "floor_insert", HX0 + 0.2, HX1 - 0.8, -0.2, 0.03, -7.9, 7.9, 0.03)
    for zz in (-8.4, 8.4):
        box(Ln, "neon_cream", HX0, HX1 - 0.6, -0.4, 0.07, zz - 0.19, zz + 0.19, 0.0)
    # threshold sill at the mouth with the light-curtain emitter under the ExfilBarrier (x 127.35..127.65, z -12..12)
    box(F, "plate_metal", HX1 - 0.6, 129.0, -0.25, 0.04, -26.2, 26.2, 0.03)
    box(F, "hazard", 125.8, 126.6, 0.0, 0.08, -25.8, 25.8, 0.0)
    box(F, "dark_metal", 127.0, 128.0, -0.3, 0.07, -12.6, 12.6, 0.03)
    box(Ln, "neon_cream", 127.31, 127.69, -0.3, 0.09, -12.2, 12.2, 0.0)
    for sg in (-1, 1):
        za, zb = sorted((sg * 12.6, sg * 13.6))
        box(F, "trim_metal", 126.9, 128.1, 0.0, 0.35, za, zb, 0.08)
    # pad deck x 129..152: slab grid + border, helipad marking centred (137, 0) (heli body sits on its west half)
    floor_grid(F, 129.0, PX1, -HZ, HZ, [131.5, 137.0, 143.5, 149.5], [-24.5, -10.5, 0.0, 10.5, 24.5], 0.0)
    H = "E_Helipad"
    cx, cz = 137.0, 0.0
    lathe(H, "label_cream", [(6.0, -0.1), (6.7, -0.1), (6.7, 0.05), (6.0, 0.05)], cx=cx, cz=cz, seg=96)
    lathe(H, "case_dark", [(0.0, -0.1), (6.0, -0.1), (6.0, 0.03), (0.0, 0.03)], cx=cx, cz=cz, seg=96)
    for zz in (-1.9, 1.9):    # "H" read from the hangar (strokes along +x)
        box(H, "label_cream", cx - 2.6, cx + 2.6, -0.1, 0.05, zz - 0.45, zz + 0.45, 0.0)
    box(H, "label_cream", cx - 0.45, cx + 0.45, -0.1, 0.05, -1.45, 1.45, 0.0)
    hs = 8.5; arm = 3.2; tw = 0.8
    for sx in (-1, 1):
        for sz in (-1, 1):
            xc, zc = cx + sx * hs, cz + sz * hs
            xa, xb = sorted((xc, xc - sx * arm)); za, zb = sorted((zc, zc + sz * tw * -1))
            box(H, "hazard", xa, xb, 0.0, 0.08, za, zb, 0.0)
            xa, xb = sorted((xc, xc - sx * tw)); za, zb = sorted((zc, zc - sz * arm))
            box(H, "hazard", xa, xb, 0.0, 0.08, za, zb, 0.0)
    for k in range(16):       # cream edge lights round the circle
        a = math.radians(22.5 * k + 11.25)
        cyl(H, "neon_cream", cx + 7.3 * math.cos(a), cz + 7.3 * math.sin(a), 0.22, 0.0, 0.16, seg=10, bev=0.04)

def build_pad_walls():
    """Pad side blast walls (z +-27, top 10 + rail) and the open sky edge at x 152 (kerb + guard rail)."""
    P = "E_PadWalls"
    for sg in (-1, 1):
        W = Wall("x", sg * HZ, -sg)
        W.box(P, "wall_kick", 127.6, PX1 + 0.6, 0.0, 7.0, -1.6, 0.3, 0.12)
        W.box(P, "trim_metal", 127.6, PX1 + 0.6, 0.0, 0.8, 0.25, 0.62, 0.1)
        W.box(P, "band_olive", 127.6, PX1 + 0.6, 7.1, 9.9, -1.6, 0.45, 0.1)
        W.box(P, "trim_metal", 127.6, PX1 + 0.6, 6.85, 7.15, -1.7, 0.55, 0.05)
        W.box(P, "trim_light", 127.6, PX1 + 0.6, 9.9, 10.4, -1.75, 0.6, 0.08)
        for (a, b) in ((128.2, 134.6), (135.4, 141.8), (142.6, 149.0)):
            W.box(P, "wall_plate", a, b, 1.4, 6.2, 0.3, 0.55, 0.08)
        for s in (135.0, 142.2, 149.4):
            W.box(P, "wall_light", s - 0.6, s + 0.6, 0.0, 10.4, 0.0, 0.9, 0.15, 2)
        a = W.p(127.8, 10.4, -0.5); b = W.p(PX1 + 0.4, 10.4, -0.5)
        railing("E_Rail", a, b, 3.4)
    # open edge
    box(P, "wall_kick", PX1 - 1.2, PX1 + 0.6, 0.0, 1.2, -HZ, HZ, 0.12)
    box(P, "trim_metal", PX1 - 1.3, PX1 + 0.7, 1.2, 1.4, -HZ, HZ, 0.05)
    box("E_Lines", "neon_cream", PX1 - 1.27, PX1 - 1.2, 0.4, 0.65, -HZ + 0.5, HZ - 0.5, 0.0)
    railing("E_Rail", (PX1 - 0.3, 1.4, -HZ + 0.3), (PX1 - 0.3, 1.4, HZ - 0.3), 3.4)
    for k in range(9):        # olive edge studs on the kerb top
        z = -24.0 + 6.0 * k
        cyl("E_Lines", "neon_olive", PX1 - 0.3, z, 0.2, 1.4, 1.62, seg=10, bev=0.04)
    # floating base under hangar + pad
    B = "E_Base"
    box(B, "wall_dark", 103.0, PX1 + 0.6, -6.0, -1.0, -29.0, 29.0, 0.12)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * 29.0, sg * 29.4))
        box(B, "band_olive", 103.0, PX1 + 0.6, -3.4, -2.2, z0, z1, 0.05)
        prism(B, "wall_dark", [(103.0, -6.0, sg * 29.0), (103.0, -6.0, sg * 18.0), (103.0, -11.0, sg * 18.0)], (49.6, 0, 0))
    box(B, "band_olive", PX1 + 0.6, PX1 + 1.0, -3.4, -2.2, -29.0, 29.0, 0.05)
    box(B, "wall_dark", 106.0, PX1 - 2.0, -11.0, -6.0, -18.0, 18.0, 0.2)
    box(B, "beam_metal", 108.0, PX1 - 4.0, -12.0, -11.0, -14.0, 14.0, 0.2)
    # invisible clip (old pad walls reached ~18): open edge and over the side walls
    box("X_Clip", "clip", PX1, PX1 + 0.6, 1.4, 18.0, -HZ - 1.6, HZ + 1.6, 0.0)
    for sg in (-1, 1):
        z0, z1 = sorted((sg * HZ, sg * (HZ + 1.6)))
        box("X_Clip", "clip", 127.6, PX1, 10.4, 18.0, z0, z1, 0.0)

def tool_chest(piece, cx, cz):
    box(piece, "drum_olive", cx - 1.2, cx + 1.2, 0.5, 3.6, cz - 0.7, cz + 0.7, 0.1)
    for k in range(5):
        y = 0.9 + k * 0.55
        box(piece, "dark_metal", cx - 1.0, cx + 1.0, y, y + 0.08, cz - 0.76, cz - 0.7, 0.0)
        box(piece, "trim_light", cx - 0.35, cx + 0.35, y + 0.2, y + 0.3, cz - 0.82, cz - 0.7, 0.02)
    box(piece, "trim_metal", cx - 1.25, cx + 1.25, 3.6, 3.75, cz - 0.75, cz + 0.75, 0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            rod(piece, "dark_metal", (cx + sx * 0.95, 0.25, cz + sz * 0.5 - 0.1), (cx + sx * 0.95, 0.25, cz + sz * 0.5 + 0.1), 0.25, 10)
    rod(piece, "trim_metal", (cx + 1.35, 3.0, cz - 0.4), (cx + 1.35, 3.0, cz + 0.4), 0.06, 6)

def bowser(piece, x0, z0):
    """Fuel bowser trailer: chassis, 4 wheels, olive tank with straps, hose reel, drawbar, cream panels."""
    zm = z0 + 1.6
    box(piece, "beam_metal", x0, x0 + 7.4, 0.9, 1.5, z0 + 0.2, z0 + 3.0, 0.08)
    for xw in (x0 + 1.4, x0 + 5.9):
        for (za, zb) in ((z0 - 0.1, z0 + 0.5), (z0 + 2.7, z0 + 3.3)):
            rod(piece, "dark_metal", (xw, 0.85, za), (xw, 0.85, zb), 0.85, 16)
            rod(piece, "trim_metal", (xw, 0.85, za - 0.02), (xw, 0.85, zb + 0.02), 0.4, 10)
    rod(piece, "drum_olive", (x0 + 0.5, 2.9, zm), (x0 + 6.6, 2.9, zm), 1.4, 20)
    for xs in (x0 + 0.5, x0 + 6.6):
        rod(piece, "drum_olive", (xs - 0.1, 2.9, zm), (xs + 0.1, 2.9, zm), 1.25, 20)
    for xs in (x0 + 1.6, x0 + 3.55, x0 + 5.5):
        rod(piece, "dark_metal", (xs - 0.12, 2.9, zm), (xs + 0.12, 2.9, zm), 1.47, 20)
    cyl(piece, "trim_metal", x0 + 3.55, zm, 0.45, 4.2, 4.55, seg=12, bev=0.04)
    box(piece, "label_cream", x0 + 2.2, x0 + 4.9, 2.4, 3.3, z0 + 0.15, z0 + 0.2, 0.0)
    box(piece, "label_cream", x0 + 2.2, x0 + 4.9, 2.4, 3.3, z0 + 3.0, z0 + 3.05, 0.0)
    rod(piece, "dark_metal", (x0 + 7.0, 1.9, z0 + 0.6), (x0 + 7.0, 1.9, z0 + 2.6), 0.75, 16)
    rod(piece, "case_dark", (x0 + 7.0, 1.9, z0 + 0.9), (x0 + 7.0, 1.9, z0 + 2.3), 0.85, 16)
    box(piece, "beam_metal", x0 - 2.2, x0, 0.85, 1.15, zm - 0.15, zm + 0.15, 0.04)
    box(piece, "dark_metal", x0 - 2.5, x0 - 2.1, 0.7, 1.2, zm - 0.3, zm + 0.3, 0.04)

def gpu_cart(piece, x0, z0):
    """Ground power unit: military-green body with louvres, panel, wheels, coiled cable."""
    box(piece, "beam_metal", x0, x0 + 5.0, 0.8, 1.2, z0, z0 + 2.4, 0.06)
    box(piece, "crate_green", x0 + 0.2, x0 + 4.8, 1.2, 3.6, z0 + 0.1, z0 + 2.3, 0.15, 2)
    for k in range(6):
        y = 1.6 + k * 0.3
        box(piece, "dark_metal", x0 + 0.6, x0 + 2.8, y, y + 0.14, z0 + 0.04, z0 + 0.12, 0.02)
        box(piece, "dark_metal", x0 + 0.6, x0 + 2.8, y, y + 0.14, z0 + 2.28, z0 + 2.36, 0.02)
    box(piece, "dark_metal", x0 + 3.3, x0 + 4.5, 2.0, 3.2, z0 + 0.02, z0 + 0.12, 0.03)
    box(piece, "screen", x0 + 3.45, x0 + 4.35, 2.55, 3.05, z0 - 0.0, z0 + 0.03, 0.0)
    box(piece, "neon_olive", x0 + 3.45, x0 + 3.75, 2.15, 2.35, z0 - 0.02, z0 + 0.03, 0.0)
    box(piece, "label_cream", x0 + 0.8, x0 + 2.4, 3.15, 3.45, z0 + 2.3, z0 + 2.34, 0.0)
    box(piece, "trim_metal", x0 + 0.1, x0 + 4.9, 3.6, 3.75, z0 + 0.05, z0 + 2.35, 0.04)
    for xw in (x0 + 0.9, x0 + 4.1):
        for (za, zb) in ((z0 - 0.15, z0 + 0.3), (z0 + 2.1, z0 + 2.55)):
            rod(piece, "dark_metal", (xw, 0.6, za), (xw, 0.6, zb), 0.6, 14)
    lathe(piece, "case_dark", [(0.55, 3.75), (0.9, 3.75), (0.9, 4.15), (0.55, 4.15)], cx=x0 + 1.4, cz=z0 + 1.2, seg=24)

def build_exfil_props():
    P = "E_Props"
    WN_ = Wall("x", HZ, -1); WS_ = Wall("x", -HZ, +1)
    # north bay: tool wall + workbench, parts shelving, tool chest, crate stack by the mouth
    WN_.box(P, "dark_metal", 106.6, 113.6, 3.6, 6.8, 0.3, 0.42, 0.04)
    WN_.box(P, "trim_metal", 106.5, 113.7, 6.8, 7.0, 0.3, 0.7, 0.03)
    for i in range(9):
        s = 107.2 + i * 0.72
        h = 0.9 + (i % 3) * 0.35
        WN_.box(P, "trim_light", s, s + 0.16, 4.8, 4.8 + h, 0.42, 0.55, 0.02)
        WN_.box(P, "drum_olive" if i % 2 else "case_dark", s - 0.12, s + 0.28, 4.6, 4.85, 0.42, 0.62, 0.03)
    bench(P, 110.0, 24.0, True, lamp_y=6.2)
    shelving(WN_, P, 117.4, 121.2, depth=1.8, seed=4)
    tool_chest(P, 114.6, 24.8)
    prop_crate(P, 123.0, 0.0, 23.2, 4.0); prop_crate(P, 122.8, 4.0, 23.4, 3.0); prop_crate(P, 123.2, 0.0, 19.4, 3.0)
    # south bay (behind the cutscene camera, x < 116): pilot lockers, bench seat, drums
    for i in range(4):
        a = 105.8 + i * 2.05
        WS_.box(P, "trim_metal", a, a + 1.95, 0.4, 7.0, 0.0, 1.2, 0.1)
        WS_.box(P, "door_leaf", a + 0.1, a + 1.85, 0.6, 6.8, 1.2, 1.3, 0.04)
        for yy in (5.9, 6.2, 6.5):
            WS_.box(P, "dark_metal", a + 0.4, a + 1.55, yy, yy + 0.12, 1.3, 1.35, 0.0)
        WS_.box(P, "label_cream", a + 0.55, a + 1.4, 5.0, 5.3, 1.3, 1.34, 0.0)
    WS_.box(P, "trim_metal", 106.2, 113.6, 0.0, 0.4, 0.0, 1.4, 0.05)
    box(P, "trim_light", 106.6, 113.2, 1.7, 1.95, -23.6, -22.3, 0.06)       # bench seat in front of the lockers
    for xx in (107.4, 112.4):
        box(P, "beam_metal", xx - 0.15, xx + 0.15, 0.0, 1.7, -23.2, -22.7, 0.03)
    prop_drum(P, 114.6, 0.0, -25.0)
    # pad: fuel bowser (north, clear of the tail at z 18-23 x 132), GPU (south-east), crates by the north mouth cheek
    G = "E_Gear"
    bowser(G, 141.6, 19.6)
    gpu_cart(G, 140.2, -24.4)
    prop_drum(G, 146.9, 0.0, -24.3); prop_drum(G, 146.6, 0.0, -21.3)
    prop_crate(G, 129.0, 0.0, 23.6, 4.0); prop_crate(G, 129.1, 4.0, 23.7, 3.0); ammo_can(G, 133.8, 0.0, 24.6, True)
    for zz in (-24.2, 24.2):
        mast(G, 149.6, 0.0, zz, 15.0, face=-1)
    # chocks + tie-down eyes round the helipad
    for (x, z) in ((131.0, -7.5), (131.0, 7.5), (143.0, -7.5), (143.0, 7.5)):
        cyl(G, "dark_metal", x, z, 0.35, 0.0, 0.12, seg=10, bev=0.03)
        lathe(G, "trim_metal", [(0.18, 0.12), (0.3, 0.12), (0.3, 0.2), (0.18, 0.2)], cx=x, cz=z, seg=12)

def build_markers3():
    box("K_Scale3", "label_cream", -5, 5, 115, 125, -5, 5, 0.0)
    box("K_Marker3", "neon_olive", 15, 25, 115, 117, -1, 1, 0.0)
    box("K_Marker3", "neon_olive", 15, 17, 117, 123, -1, 1, 0.0)
    box("K_Marker3", "neon_olive", 15, 17, 115, 117, 1, 5, 0.0)

# ------------------------------------------------------------------ collections, manifest
HERO3 = ("D_Pads", "E_Helipad", "D_Signs", "E_Signs")
def coll_for(piece):
    if piece.startswith("K_"):
        return "R3_Markers"
    if piece.startswith("X_"):
        return "R3_Clip"
    if piece in HERO3:
        return "R3_Hero"
    if piece in ("D_Props", "E_Props", "E_Gear"):
        return "R3_Props"
    return "R3_Shell"

# Studio colours: hub1_place olive decisions + hub2's Future floor compensation (so the rooms match the placed hub)
STUDIO_RGB3 = {"band_olive": (120, 136, 66), "neon_olive": (88, 101, 48), "floor_field": (76, 62, 50), "floor_border": (46, 38, 30),
               "floor_insert": (94, 80, 66), "disc_plate": (88, 76, 64), "drum_olive": (70, 82, 52)}
NOCOLLIDE_MATS3 = {"neon_lamp", "neon_cream", "neon_olive", "void", "glass", "label_cream", "screen", "hazard", "ceiling_gloss", "sign_board"}
NOCOLLIDE_PIECES3 = ("D_Roof", "D_Trusses", "D_Lights", "D_Lines", "D_Signs", "D_Base", "E_Ceiling", "E_Beams", "E_Lights", "E_Lines",
                     "E_Signs", "E_Base", "E_Helipad")
BOX_PIECES3 = ("D_Floor", "E_Floor", "D_Deck", "D_Pass")

def manifest3(stats):
    out = []
    for st in stats:
        mat = st["material"]; piece = st["piece"]
        base, var = studio_fields(mat) if mat != "clip" else ("SmoothPlastic", "")
        coll = not (mat in NOCOLLIDE_MATS3 or piece.startswith(NOCOLLIDE_PIECES3) or piece.startswith("K_"))
        flat = mat in ("floor_field", "floor_border", "floor_insert", "plate_metal", "wall_dark", "clip")
        fid = "Box" if ((piece in BOX_PIECES3 and flat) or mat == "clip") else "PreciseConvexDecomposition"
        e = dict(st)
        e["rgb_kit"] = list(st["rgb"])
        e["rgb"] = list(STUDIO_RGB3.get(mat, st["rgb"]))
        e["material_studio"] = base
        e["variant"] = var
        e["variant_folder"] = "MaterialService.TacHub1" if var else ""
        e["can_collide"] = coll
        e["collision_fidelity"] = fid if coll else "Box"
        e["cast_shadow"] = not (mat.startswith("neon") or mat in ("glass", "clip"))
        e["transparency"] = 0.6 if mat == "glass" else (1.0 if mat == "clip" else 0.0)
        e["texture_overlay"] = {"hazard": "TX_hazard_stripe 4x1 Top", "grate": "TX_grate_alpha 3x3"}.get(mat, "")
        out.append(e)
    return out

def clear_rooms3():
    for cn in ("R3_Shell", "R3_Hero", "R3_Props", "R3_Markers", "R3_Clip"):
        c = bpy.data.collections.get(cn)
        if c:
            for ob in list(c.objects):
                me = ob.data
                bpy.data.objects.remove(ob, do_unlink=True)
                if me and me.users == 0:
                    bpy.data.meshes.remove(me)

def build_rooms3():
    clear_rooms3()
    ACC.clear()
    build_duels_walls(); build_duels_west(); build_duels_floor(); build_pads(); build_duels_roof(); build_duels_base(); build_deck()
    build_hangar(); build_exfil_floor(); build_pad_walls(); build_exfil_props(); build_markers3()
    stats = finalize()
    man = manifest3(stats)
    with open(KIT + "rooms3_manifest.json", "w") as f:
        json.dump(man, f, indent=1)
    return man

if __name__ == "__main__" or True:
    MAN = build_rooms3()
