# Revolver: double-action six-shot, 4" barrel with full underlug, swing-out cylinder on a crane (swings out to the left),
# ejector rod + extractor star, exposed spur hammer, finger-groove wood grip. Read off grid/Revolver.png (1.5 studs).
import math
NAME = "Revolver"
ORIGIN = (0.18, 0.32)
BORE = 0.78
CYL_Z, CYL_R = 0.69, 0.145
CH_OFF = BORE - CYL_Z           # chamber circle radius
F0C, F1C = 0.54, 0.80           # cylinder rear / front

frame_outline = [(0.10, 0.10), (0.27, 0.10), (0.33, 0.40), (0.46, 0.43), (0.47, 0.32), (0.52, 0.275), (0.68, 0.275),
                 (0.74, 0.32), (0.755, 0.47), (0.80, 0.53), (0.92, 0.56), (0.97, 0.60), (0.97, 0.835), (0.40, 0.835),
                 (0.34, 0.80), (0.30, 0.72), (0.22, 0.66), (0.12, 0.50)]
guard_hole = [(0.495, 0.31), (0.69, 0.31), (0.722, 0.35), (0.725, 0.47), (0.495, 0.47)]
grip = [(0.02, 0.0), (0.27, 0.0), (0.30, 0.06), (0.28, 0.12), (0.31, 0.17), (0.29, 0.23), (0.32, 0.28), (0.31, 0.36),
        (0.34, 0.42), (0.44, 0.445), (0.40, 0.50), (0.33, 0.56), (0.25, 0.62), (0.19, 0.665), (0.14, 0.64), (0.08, 0.45), (0.02, 0.18)]


def ang(i, off=0.0):
    return math.radians(90 + 60 * i + off)


chamber_mouths = [C(0.77, 0.82, CYL_Z + CH_OFF * math.sin(ang(i)), 0.03, x=CH_OFF * math.cos(ang(i)), rot=0) for i in range(6)]
flutes = [C(0.60, 0.83, CYL_Z + 0.152 * math.sin(ang(i, 30)), 0.034, x=0.152 * math.cos(ang(i, 30)), rot=0) for i in range(6)]
rounds = []
for i in range(6):
    zc, xc = CYL_Z + CH_OFF * math.sin(ang(i)), CH_OFF * math.cos(ang(i))
    rounds.append(L([0.527, 0.541, 0.541, 0.76, 0.77], [0.031, 0.031, 0.026, 0.026, 0.0], zc, x=xc, rot=0))

PARTS = [
    Part("Frame", "Steel", [
        P(frame_outline, 0.16, cut=[B(0.535, 0.805, 0.545, 0.80, 0.4), P(guard_hole, 0.4), B(0.27, 0.405, 0.62, 0.90, 0.05)]),
    ], wrap="A", note="frame with top strap, cylinder window, round trigger guard, hammer slot"),
    Part("Barrel", "Steel", [
        T(0.79, 1.495, BORE, 0.05, 0.025),
        B(0.96, 1.495, 0.615, 0.76, 0.12, cut=[B(0.95, 1.17, 0.655, 0.725, 0.3)]),
        B(0.96, 1.495, 0.79, 0.835, 0.08),
        P([(1.36, 0.83), (1.47, 0.83), (1.47, 0.878), (1.44, 0.878)], 0.035),
    ], wrap="A", note="barrel tube, full underlug with the ejector-rod slot, top rib, ramp front sight"),
    Part("Grip", "Wood", [P(grip, 0.20, cut=[B(0.05, 0.30, 0.08, 0.50, 0.06, x=0.115), B(0.05, 0.30, 0.08, 0.50, 0.06, x=-0.115)])],
         wrap="A", note="finger-groove wood grip with inset checkering panels"),
    Part("Crane", "Steel", [
        C(0.79, 0.93, 0.585, 0.032, x=-0.04, rot=0),
        B(0.795, 0.83, 0.57, 0.74, 0.09, x=-0.02),
    ], pivot=(0.86, 0.585, -0.04), motion="rotate about z (the bore axis direction) up to 95 deg: swings the cylinder out to the left",
        explode=(0, 0, -0.35), note="yoke: pivot tube + arm to the cylinder axis"),
    Part("Cylinder", "Steel", [
        L([F0C, F1C], [CYL_R, CYL_R], CYL_Z, seg=12),
    ], parent="Crane", pivot=((F0C + F1C) / 2, CYL_Z), motion="rotate about its own axis (z) 60 deg per shot; spin when swung out",
        explode=(0, 0, 0)),
    Part("EjectorRod", "DarkSteel", [
        C(0.78, 1.17, CYL_Z, 0.021, rot=0),
        C(1.12, 1.17, CYL_Z, 0.03, rot=0),
        L([0.528, 0.556], [0.105, 0.105], CYL_Z, seg=12, rot=0),
    ], parent="Cylinder", pivot=(F0C, CYL_Z), motion="translate +z (back) 0.2: pushes the extractor star and the rounds out",
        explode=(0, 0, 0), note="rod + knurl head + extractor star at the cylinder's rear"),
    Part("Rounds", "Brass", rounds, parent="EjectorRod", pivot=(0.65, CYL_Z),
         motion="group of 6 in the chambers: out with the extractor, new set in (speed loader)", explode=(-0.45, 0, -0.35),
         note="six .357 rounds as one piece"),
    Part("Hammer", "DarkSteel", [P([(0.255, 0.84), (0.30, 0.865), (0.35, 0.825), (0.40, 0.72), (0.395, 0.60), (0.34, 0.595),
                                    (0.33, 0.70), (0.29, 0.79)], 0.04),
                                   B(0.39, 0.548, 0.765, 0.795, 0.02)],
         pivot=(0.36, 0.64), motion="rotate about x: cock back 35 deg, fall forward on fire", note="spur hammer + firing-pin nose to the top round", explode=(-0.1, 0.12, 0)),
    Part("Trigger", "DarkSteel", [P([(0.56, 0.53), (0.60, 0.53), (0.60, 0.45), (0.625, 0.37), (0.615, 0.31), (0.597, 0.31),
                                     (0.59, 0.38), (0.565, 0.45)], 0.04),
                                   P([(0.575, 0.52), (0.60, 0.52), (0.60, 0.60), (0.555, 0.70), (0.53, 0.70)], 0.02),
                                   B(0.38, 0.565, 0.60, 0.62, 0.02)],
         pivot=(0.58, 0.50), motion="rotate about x, bottom back 20 deg (double action)", note="blade + the hand (pawl) that turns the cylinder + hidden sear bar to the hammer", explode=(0, -0.15, 0)),
    Part("CylinderLatch", "DarkSteel", [B(0.37, 0.535, 0.61, 0.67, 0.035, x=-0.0875), B(0.37, 0.42, 0.63, 0.68, 0.11, x=-0.045),
                                         C(0.40, 0.60, CYL_Z, 0.012, rot=0)], pivot=(0.425, 0.64, -0.09),
         motion="translate -z (forward) 0.04 to release the cylinder", explode=(0, 0, -0.12), note="thumb latch (left side) + hidden link and centre pin into the cylinder"),
]

# the cylinder carries flutes + chamber mouths (booleans on the 12-sided body)
PARTS[4].solids[0].cut = flutes + chamber_mouths

ATTACH = {
    "Muzzle": ("Barrel", (1.495, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Cylinder", (F0C, CYL_Z, -0.25)),
    "Mag": ("Rounds", (0.52, CYL_Z)),
}
