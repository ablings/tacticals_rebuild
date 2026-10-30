# Sniper: bolt-action precision rifle on an grey aluminium chassis: skeleton stock with adjustable cheek piece, rubber
# butt pad, octagonal receiver (bolt shows through the port), bolt with a ball-knob handle, detachable box mag, folding
# bipod (two legs, folded forward), heavy barrel with a three-port brake, long scope on two rings with flip-up caps (open).
# Read off grid/Sniper_a/b.png (6.2 studs).
import math
NAME = "Sniper"
ORIGIN = (1.48, 0.41)
BORE = 0.87
SZ = 1.26

stock = [(0.10, 0.10), (0.25, 0.10), (0.28, 0.13), (0.72, 0.13), (0.85, 0.25), (1.30, 0.48), (1.30, 0.78), (0.25, 0.78), (0.25, 0.86), (0.10, 0.86)]
stock_hole = [(0.38, 0.24), (0.72, 0.24), (0.82, 0.32), (1.10, 0.48), (1.10, 0.66), (0.38, 0.66)]
chassis = [(1.10, 0.50), (1.80, 0.50), (2.20, 0.53), (2.75, 0.55), (2.95, 0.58), (4.70, 0.58), (4.73, 0.62), (4.73, 0.81), (4.70, 0.84), (3.05, 0.84), (2.95, 0.80), (1.10, 0.80)]
ch_cuts = [B(3.0, 4.8, 0.62, 0.85, 0.12)] + [B(3.15 + i * 0.25, 3.33 + i * 0.25, 0.685, 0.725, 0.4) for i in range(6)]
guard = [(1.80, 0.52), (1.80, 0.40), (1.84, 0.36), (2.10, 0.36), (2.13, 0.40), (2.13, 0.52)]
guard_hole = [(1.85, 0.385), (2.09, 0.385), (2.105, 0.41), (2.105, 0.51), (1.85, 0.51)]
rec_section = [(-0.10, 0.82), (-0.06, 0.78), (0.06, 0.78), (0.10, 0.82), (0.10, 0.94), (0.06, 0.98), (-0.06, 0.98), (-0.10, 0.94)]
SC_F = [1.40, 1.41, 1.90, 1.95, 2.00, 3.05, 3.45, 4.0, 4.02]
SC_R = [0.105, 0.125, 0.125, 0.075, 0.065, 0.065, 0.15, 0.15, 0.135]
scope_body = L(SC_F, SC_R, SZ, seg=12)
scope_body.cut = [C(3.98, 4.10, SZ, 0.125, seg=12), C(1.36, 1.44, SZ, 0.095, seg=12)]


def cap(hf, hz, ang_deg, r):
    """open flip-up cap: a disc hinged at (hf, hz), standing at ang_deg from the +f axis in the side plane"""
    a = math.radians(ang_deg)
    d = (math.cos(a), math.sin(a))
    n = (math.sin(a), -math.cos(a))
    cf, cz = hf + d[0] * r, hz + d[1] * r
    t = 0.015
    return [CA((0, cf - n[0] * t, cz - n[1] * t), (0, cf + n[0] * t, cz + n[1] * t), r, seg=12),
            CX(hf, hz, 0.022, -0.035, 0.035)]


def leg(x):
    return [CA((x, 4.08, 0.555), (x, 4.95, 0.555), 0.03, rot=0), CA((x, 4.94, 0.555), (x, 5.20, 0.555), 0.022, rot=0),
            CA((x, 5.19, 0.555), (x, 5.25, 0.555), 0.04, rot=0)]


PARTS = [
    Part("Chassis", "Grey", [P(chassis, 0.22, cut=ch_cuts), P(guard, 0.06, cut=[P(guard_hole, 0.2)])], wrap="A",
         note="aluminium chassis: mag well, trigger guard, U-channel fore-end with slots through"),
    Part("Stock", "Grey", [P(stock, 0.20, cut=[P(stock_hole, 0.4)])], wrap="A", note="skeleton stock"),
    Part("ButtPad", "Rubber", [B(0.0, 0.11, 0.08, 0.88, 0.24)], wrap="B"),
    Part("CheekPiece", "Polymer", [B(0.42, 1.13, 0.82, 0.95, 0.17), CZ(0.62, 0.74, 0.84, 0.02, rot=0), CZ(0.86, 0.74, 0.84, 0.02, rot=0)],
         parent="Stock", pivot=(0.78, 0.82), motion="translate +y 0.1 (adjust)", explode=(0, 0.15, 0), wrap="B"),
    Part("Grip", "Polymer", [P([(1.40, 0.53), (1.72, 0.52), (1.60, 0.25), (1.53, 0.02), (1.30, 0.0), (1.25, 0.08)], 0.20,
                               cut=[B(1.30, 1.62, 0.10, 0.45, 0.06, x=0.115), B(1.30, 1.62, 0.10, 0.45, 0.06, x=-0.115)])], wrap="B"),
    Part("Receiver", "Gunmetal", [PF(rec_section, 1.85, 3.0, cut=[B(2.25, 2.70, 0.83, 0.925, 0.11, x=0.085)]),
                                  B(2.05, 3.03, 0.975, 1.02, 0.12, cut=[B(2.0, 3.1, 0.99, 1.005, 0.02, x=0.06), B(2.0, 3.1, 0.99, 1.005, 0.02, x=-0.06)])],
         wrap="A", note="octagonal receiver, ejection port (right), top rail"),
    Part("Barrel", "DarkSteel", [L([2.85, 2.95, 5.80], [0.0, 0.068, 0.068], BORE),
                                 B(5.78, 6.20, 0.78, 0.96, 0.18, cut=[B(5.86 + i * 0.1, 5.92 + i * 0.1, 0.81, 0.93, 0.4) for i in range(3)] +
                                   [C(6.15, 6.25, BORE, 0.03)])],
         wrap="B", note="heavy barrel (free-floated in the channel), three-port brake"),
    Part("Scope", "Polymer", [scope_body, CZ(2.53, 1.32, 1.45, 0.08, seg=10), CX(2.53, SZ, 0.065, 0.05, 0.16, seg=10)], wrap="B",
         note="long scope: eyepiece, tube, turrets, objective bell"),
    Part("ScopeRings", "DarkSteel", [B(f, f + 0.09, 1.015, 1.20, 0.14) for f in (2.17, 2.83)] +
         [L([f, f + 0.09], [0.085, 0.085], SZ, seg=12) for f in (2.17, 2.83)], wrap="B"),
    Part("ScopeLensFront", "Lens", [L([3.975, 3.995], [0.129, 0.129], SZ, seg=12)], parent="Scope", wrap="skip"),
    Part("ScopeLensRear", "Lens", [L([1.425, 1.435], [0.099, 0.099], SZ, seg=12)], parent="Scope", wrap="skip"),
    Part("ScopeCapRear", "DarkSteel", cap(1.40, SZ + 0.125, 50, 0.12), parent="Scope", pivot=(1.40, SZ + 0.125),
         motion="rotate about x: open 50 deg up-forward (rest) / closed over the eyepiece (-130 deg)", explode=(0, 0.15, 0)),
    Part("ScopeCapFront", "DarkSteel", cap(4.02, SZ + 0.15, 120, 0.135), parent="Scope", pivot=(4.02, SZ + 0.15),
         motion="rotate about x: open 120 deg (rest) / closed over the objective", explode=(0, 0.15, 0)),
    Part("Bolt", "Steel", [C(1.80, 2.75, BORE, 0.055, rot=0), C(1.76, 1.92, BORE, 0.075)], pivot=(2.0, BORE),
         motion="rotate about z 70 deg (lift), translate +z 0.55 (back), reverse", explode=(-0.45, 0, 0), note="bolt body + rear shroud"),
    Part("BoltHandle", "DarkSteel", [CA((0.05, 2.0, 0.85), (0.15, 1.98, 0.67), 0.022, rot=0), S(1.98, 0.63, 0.065, x=0.15, seg=8, rings=6)],
         parent="Bolt", pivot=(2.0, BORE), motion="rides the bolt (same pivot); lift + pull", explode=(0, 0, 0.12), note="handle + ball knob (right)"),
    Part("Mag", "Polymer", [B(2.22, 2.69, 0.17, 0.62, 0.18), B(2.21, 2.70, 0.14, 0.18, 0.20)], pivot=(2.45, 0.62),
         motion="translate -y (straight down)", explode=(0, -0.3, 0), note="detachable 5-round box"),
    Part("MagRelease", "DarkSteel", [P([(2.14, 0.40), (2.19, 0.40), (2.23, 0.53), (2.16, 0.53)], 0.04)], pivot=(2.18, 0.52),
         motion="rotate about x, bottom forward 15 deg (paddle)", explode=(0, -0.1, 0)),
    Part("Trigger", "DarkSteel", [P([(1.92, 0.62), (1.96, 0.62), (1.96, 0.50), (1.98, 0.44), (1.99, 0.40), (1.975, 0.395), (1.94, 0.46), (1.92, 0.52)], 0.035)],
         pivot=(1.94, 0.58), motion="rotate about x, bottom back 8 deg", explode=(0, -0.15, 0)),
    Part("BipodMount", "DarkSteel", [B(3.98, 4.18, 0.44, 0.60, 0.12)], wrap="B"),
    Part("BipodLegL", "DarkSteel", leg(-0.028), pivot=(4.10, 0.555, -0.028), motion="rotate about x 90 deg down (deploy) and splay 15 deg out",
         explode=(0, -0.15, -0.1), note="telescoping leg + foot"),
    Part("BipodLegR", "DarkSteel", leg(0.028), pivot=(4.10, 0.555, 0.028), motion="rotate about x 90 deg down (deploy) and splay 15 deg out",
         explode=(0, -0.15, 0.1)),
    Part("Round", "Brass", [L([2.27, 2.285, 2.52, 2.57, 2.63], [0.005, 0.034, 0.034, 0.022, 0.0], 0.58, rot=0)], parent="Mag",
         pivot=(2.45, 0.58), motion="rides in the mag top; shown in the port on the bolt cycle", explode=(0, 0.35, 0), note=".308 round"),
]

ATTACH = {
    "Muzzle": ("Barrel", (6.20, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Receiver", (2.47, 0.88, 0.12)),
    "Mag": ("Mag", (2.45, 0.15)),
    "BoltKnob": ("BoltHandle", (1.98, 0.63, 0.15)),
    "AimPoint": ("Scope", (1.40, SZ)),
    "ScopeGlare": ("Scope", (4.0, SZ)),
}
