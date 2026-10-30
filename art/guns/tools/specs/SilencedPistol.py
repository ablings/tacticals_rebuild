# SilencedPistol: full-size polymer pistol (grey frame) with a threaded barrel and a screw-on suppressor, suppressor-height
# sights, front + rear serrations, extended magazine. Read off grid/SilencedPistol.png (1.9 studs long with the suppressor).
NAME = "SilencedPistol"
ORIGIN = (0.22, 0.314)         # grip centre; bore lands at y = 0.46

BORE = 0.774
SW = 0.165
FW = 0.15
ST, SB = 0.84, 0.705           # slide top / bottom

frame_outline = [(0.0, 0.12), (0.33, 0.12), (0.46, 0.425), (0.78, 0.425), (0.81, 0.45), (0.81, 0.60), (0.83, 0.61),
                 (1.15, 0.612), (1.17, 0.635), (1.17, 0.72), (0.06, 0.72), (0.03, 0.735), (0.005, 0.715), (0.045, 0.665), (0.125, 0.58)]
guard_hole = [(0.51, 0.452), (0.76, 0.452), (0.785, 0.48), (0.785, 0.598), (0.51, 0.598)]
grip_panel = [(0.012, 0.135), (0.318, 0.135), (0.44, 0.42), (0.44, 0.52), (0.17, 0.60), (0.13, 0.575)]


def cuts(f0, n, pitch, side, slant=0.0):
    out = []
    for i in range(n):
        a = f0 + i * pitch
        out.append(P([(a, 0.725), (a + 0.018, 0.725), (a + 0.018 + slant, 0.825), (a + slant, 0.825)], 0.04, x=side * SW / 2))
    return out


slide_section = [(-SW / 2, SB), (SW / 2, SB), (SW / 2, ST - 0.025), (SW / 2 - 0.022, ST), (-SW / 2 + 0.022, ST), (-SW / 2, ST - 0.025)]
SUP = [1.21, 1.23, 1.275, 1.70, 1.70, 1.716, 1.716, 1.745, 1.745, 1.761, 1.761, 1.893, 1.90, 1.90, 1.875, 1.875]
SUR = [0.0, 0.044, 0.085, 0.085, 0.078, 0.078, 0.085, 0.085, 0.078, 0.078, 0.085, 0.085, 0.077, 0.024, 0.024, 0.0]

PARTS = [
    Part("Frame", "MidGrey", [
        P(frame_outline, FW, cut=[P(guard_hole, 0.4)] + [B(f, f + 0.035, 0.597, 0.624, 0.4) for f in (0.90, 0.97, 1.04)]),
        P(grip_panel, 0.18, cut=[B(0.03, 0.42, 0.20, 0.55, 0.06, x=0.105), B(0.03, 0.42, 0.20, 0.55, 0.06, x=-0.105)]),
    ], wrap="A", note="grey polymer frame, rail, stippled inset grip panels"),
    Part("Slide", "Gunmetal", [
        PF(slide_section, 0.055, 1.177, cut=cuts(0.11, 5, 0.034, 1) + cuts(0.11, 5, 0.034, -1) + cuts(0.96, 3, 0.034, 1) +
           cuts(0.96, 3, 0.034, -1) + [B(0.42, 0.66, 0.765, 0.90, 0.1, x=0.05), C(1.10, 1.20, BORE, 0.026)]),
        P([(0.085, 0.83), (0.165, 0.83), (0.165, 0.905), (0.085, 0.905)], 0.12, cut=[B(0.07, 0.18, 0.87, 0.92, 0.03)]),
        B(1.085, 1.145, 0.83, 0.905, 0.045),
    ], pivot=(0.62, BORE), motion="translate +z (back) up to 0.30: blowback, rack, lock open", wrap="A", explode=(0, 0.25, 0),
        note="front + rear vertical serrations, ejection port (right), tall suppressor sights"),
    Part("Barrel", "DarkSteel", [
        T(0.95, 1.285, BORE, 0.04, 0.022),
        B(0.40, 0.96, 0.712, 0.83, 0.118),
        C(1.06, 1.19, 0.668, 0.02),
    ], wrap="B", note="static: threaded barrel (sticks out past the slide), chamber hood, guide rod"),
    Part("Suppressor", "Polymer", [L(SUP, SUR, BORE - 0.004, seg=12)], parent="Barrel", pivot=(1.23, BORE),
         motion="static (screw on/off: rotate about z, translate -z)", explode=(0.18, 0, 0), wrap="B",
         note="12-sided can, two grooves, recessed bore"),
    Part("Mag", "Polymer", [
        P([(0.06, 0.12), (0.29, 0.12), (0.40, 0.535), (0.17, 0.535)], 0.12),
        P([(0.012, 0.0), (0.31, 0.0), (0.31, 0.145), (0.03, 0.145)], 0.165),
    ], pivot=(0.285, 0.535), motion="translate down the grip axis: drop out / insert", explode=(-0.10, -0.40, 0),
        note="extended magazine with a tall base pad"),
    Part("MagRelease", "DarkSteel", [B(0.36, 0.44, 0.49, 0.55, 0.175, x=-0.0175)], pivot=(0.40, 0.52, -0.08),
         motion="translate +x 0.03 (pressed in)", explode=(0, 0, -0.12), note="cross-bolt, button on the left"),
    Part("SlideStop", "DarkSteel", [CX(0.575, 0.645, 0.02, -0.098, 0.0), B(0.62, 0.68, 0.69, 0.73, 0.045, x=-0.0675),
                                    P([(0.575, 0.627), (0.70, 0.66), (0.70, 0.715), (0.59, 0.715)], 0.022, x=-0.089)],
         pivot=(0.575, 0.645, -0.08), motion="rotate about x, lever tip up 12 deg", explode=(0, 0.05, -0.15)),
    Part("Trigger", "DarkSteel", [P([(0.535, 0.72), (0.568, 0.72), (0.568, 0.60), (0.575, 0.54), (0.615, 0.478), (0.60, 0.47),
                                     (0.553, 0.53), (0.535, 0.57)], 0.035),
                                   P([(0.38, 0.535), (0.505, 0.535), (0.505, 0.60), (0.55, 0.60), (0.55, 0.625), (0.38, 0.625)], 0.03)],
         pivot=(0.55, 0.59), motion="rotate about x, bottom back 15 deg", explode=(0, -0.12, 0), note="blade + hidden trigger bar"),
    Part("Round", "Brass", [L([0.19, 0.29, 0.315, 0.34], [0.024, 0.024, 0.019, 0.0], 0.535, rot=0)], parent="Mag",
         pivot=(0.265, 0.535), motion="rides in the mag top; animate to ShellEject", explode=(0, 0.2, 0), note="9mm cartridge"),
]

ATTACH = {
    "Muzzle": ("Suppressor", (1.90, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Slide", (0.54, 0.85, 0.07)),
    "Mag": ("Mag", (0.16, 0.02)),
    "SlideGrab": ("Slide", (0.19, 0.77)),
}
