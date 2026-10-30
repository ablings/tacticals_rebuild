# RiotShield: curved tactical shield (2.2 x 3.6 like the old one): near-black body, light grey rim, view window (glass),
# flashlight top right with a glowing lens, vertical back grip on two standoffs. f = forward (shield in front of the hand).
NAME = "RiotShield"
ORIGIN = (0.0, 0.0)
SHEET_VIEW = "front"
HW, Z0, Z1, T = 1.1, -1.9, 1.7, 0.08


def front(x):
    return 0.55 - 0.15 * (x / HW) ** 2


def band(x0, x1, f_out, f_in, n=8):
    xs = [x0 + (x1 - x0) * i / n for i in range(n + 1)]
    return [(x, front(x) + f_out) for x in xs] + [(x, front(x) - T - f_in) for x in reversed(xs)]


corners = [PF([(-1.3, 1.42), (-1.3, 1.9), (-0.82, 1.9)], -1, 2), PF([(1.3, 1.42), (1.3, 1.9), (0.82, 1.9)], -1, 2),
           PF([(-1.3, -1.70), (-1.3, -2.1), (-0.9, -2.1)], -1, 2), PF([(1.3, -1.70), (1.3, -2.1), (0.9, -2.1)], -1, 2)]
window = PF([(-0.65, 1.15), (0.65, 1.15), (0.65, 1.40), (-0.65, 1.40)], -1, 2)
LX, LZc = 0.93, 1.50


def diag(p0, p1, inward):
    """rim strip along a chamfer edge p0 -> p1 (x, z), 0.13 wide (0.03 out, 0.10 in), straight in f at the corner depth"""
    import math as _m
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    ln = _m.hypot(dx, dz)
    nx, nz = -dz / ln * inward, dx / ln * inward
    ext = 0.06
    a = (p0[0] - dx / ln * ext, p0[1] - dz / ln * ext)
    b = (p1[0] + dx / ln * ext, p1[1] + dz / ln * ext)
    pts = [(a[0] - nx * 0.03, a[1] - nz * 0.03), (b[0] - nx * 0.03, b[1] - nz * 0.03), (b[0] + nx * 0.10, b[1] + nz * 0.10), (a[0] + nx * 0.10, a[1] + nz * 0.10)]
    fm = front(0.97)
    return PF(pts, fm - T - 0.03, fm + 0.03)


corner_strips = [diag((-HW, 1.42), (-0.82, Z1), -1), diag((HW, 1.42), (0.82, Z1), 1),
                 diag((-HW, -1.70), (-0.90, Z0), 1), diag((HW, -1.70), (0.90, Z0), -1)]
PARTS = [
    Part("Shield", "Polymer", [PT(band(-HW, HW, 0, 0, 12), Z0, Z1, cut=corners + [window])], wrap="A",
         note="curved shield body (sagitta 0.15), chamfered corners, window cut through"),
    Part("Rim", "LightGrey", [PT(band(-HW - 0.03, -HW + 0.10, 0.02, 0.02, 4), -1.70, 1.42),
                          PT(band(HW - 0.10, HW + 0.03, 0.02, 0.02, 4), -1.70, 1.42),
                          PT(band(-0.82, 0.82, 0.025, 0.025, 12), Z1 - 0.10, Z1 + 0.03),
                          PT(band(-0.90, 0.90, 0.025, 0.025, 12), Z0 - 0.03, Z0 + 0.10)] + corner_strips,
         wrap="B", note="raised rim: side, top and bottom strips + diagonal corner strips"),
    Part("Window", "Lens", [PT(band(-0.68, 0.68, -0.025, -0.025, 8), 1.13, 1.42)], wrap="skip", note="view window glass"),
    Part("Grip", "DarkSteel", [CZ(0.0, -0.28, 0.28, 0.05, rot=0), B(-0.03, front(0) - T + 0.02, 0.20, 0.28, 0.07),
                               B(-0.03, front(0) - T + 0.02, -0.28, -0.20, 0.07)], wrap="B", note="vertical back grip on two standoffs"),
    Part("Light", "DarkSteel", [L([front(LX) - 0.04, front(LX) + 0.24], [0.055, 0.055], LZc, x=LX, seg=8),
                                B(front(LX) - 0.05, front(LX) + 0.06, 1.42, 1.50, 0.08, x=LX)],
         wrap="B", note="flashlight + mount"),
    Part("LightLens", "Glow", [L([front(LX) + 0.23, front(LX) + 0.255], [0.045, 0.045], LZc, x=LX, seg=8)], parent="Light",
         wrap="skip", note="Neon lens: switch Material / Color to turn the light on and off"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "Bash": ("Shield", (front(0), 0.0)), "LightBeam": ("LightLens", (front(LX) + 0.26, LZc, LX))}
