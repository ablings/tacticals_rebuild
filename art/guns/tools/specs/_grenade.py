# shared grenade fuze: Fuze (static), Spoon (lever, flies off), Pin (shaft + ring, pulled). Coordinates: f forward, z up,
# origin = body centre (the grip). exec()'d by the grenade specs.
import math


def ring(cf, cz, r, wire, n=8):
    out = []
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        p0 = (0.0, cf + r * math.cos(a0) * 1.0, cz + r * math.sin(a0))
        p1 = (0.0, cf + r * math.cos(a1), cz + r * math.sin(a1))
        # stretch each segment 15 % so neighbours overlap at the joints
        d = [(p1[k] - p0[k]) * 0.08 for k in range(3)]
        out.append(CA(tuple(p0[k] - d[k] for k in range(3)), tuple(p1[k] + d[k] for k in range(3)), wire, seg=6, rot=0))
    return out


def fuze(top, spoon_pts, metal="Steel", ring_f=-0.13):
    pz = top + 0.05
    return [
        Part("Fuze", metal, [LZ([top - 0.03, top - 0.03, top + 0.06, top + 0.08, top + 0.08], [0, 0.05, 0.05, 0.035, 0], seg=10),
                             B(-0.035, 0.065, top - 0.02, top + 0.10, 0.06)],
             wrap="B", note="fuze head + striker housing"),
        Part("Spoon", "Steel", [P(spoon_pts, 0.07)], pivot=(0.05, top + 0.09),
             motion="rotate about x away from the body (flies off when released)", explode=(0.12, 0.05, 0),
             note="safety lever"),
        Part("Pin", "Steel", [CA((0, -0.09, pz), (0, 0.075, pz), 0.011, rot=0), CA((0, -0.095, pz), (0, ring_f + 0.01, top + 0.04), 0.011, rot=0)] + ring(ring_f, top - 0.01, 0.055, 0.011),
             pivot=(0.0, pz), motion="translate -z (pull back along the shaft), ring swings about x", explode=(-0.15, 0.05, 0),
             note="cotter pin + pull ring (rests against the body)"),
    ]
