# Pistol: polymer striker-fired service pistol (no hammer: striker-fired). Coordinates read off grid/Pistol.png
# (f from the rear, z from the bottom, studs; 1.2 studs long). Controls on the left side (real right-hand layout),
# ejection port on the right.
NAME = "Pistol"
ORIGIN = (0.25, 0.24)          # grip centre -> Handle; bore axis lands at y = 0.46 like the old model

BORE = 0.70
SW = 0.165                     # slide width
FW = 0.15                      # frame width at the dust cover

frame_outline = [(0.04, 0.03), (0.35, 0.03), (0.44, 0.33), (0.80, 0.33), (0.84, 0.36), (0.84, 0.50), (0.86, 0.505),
                 (1.13, 0.505), (1.15, 0.53), (1.15, 0.625), (0.08, 0.625), (0.03, 0.592), (0.045, 0.565), (0.15, 0.49)]
guard_hole = [(0.51, 0.36), (0.78, 0.36), (0.80, 0.385), (0.80, 0.485), (0.51, 0.485)]
grip_panel = [(0.055, 0.045), (0.335, 0.045), (0.415, 0.31), (0.41, 0.43), (0.19, 0.50), (0.155, 0.48)]


def serrations(f0, n, pitch, side):
    """slanted cuts through the slide skin (RIVALS method: slots, not modelled ribs)"""
    out = []
    for i in range(n):
        a = f0 + i * pitch
        pts = [(a, 0.632), (a + 0.022, 0.632), (a + 0.052, 0.722), (a + 0.030, 0.722)]
        out.append(P(pts, 0.04, x=side * (SW / 2)))
    return out


slide_section = [(-SW / 2, 0.61), (SW / 2, 0.61), (SW / 2, 0.718), (SW / 2 - 0.022, 0.745), (-SW / 2 + 0.022, 0.745), (-SW / 2, 0.718)]

PARTS = [
    Part("Frame", "Polymer", [
        P(frame_outline, FW, cut=[P(guard_hole, 0.4)] + [B(f, f + 0.035, 0.49, 0.517, 0.4) for f in (0.90, 0.97, 1.04)]),
        P(grip_panel, 0.18, cut=[B(0.05, 0.40, 0.10, 0.46, 0.06, x=0.105), B(0.05, 0.40, 0.10, 0.46, 0.06, x=-0.105)]),
    ], wrap="A", note="frame + dust cover + rail + raked grip; grip panels are inset (stipple patches)"),
    Part("Slide", "Gunmetal", [
        PF(slide_section, 0.09, 1.16, cut=serrations(0.17, 5, 0.04, 1) + serrations(0.17, 5, 0.04, -1) +
           [B(0.54, 0.71, 0.665, 0.80, 0.1, x=0.05), C(1.10, 1.20, BORE, 0.02)]),
        P([(0.115, 0.735), (0.195, 0.735), (0.195, 0.79), (0.115, 0.79)], 0.12, cut=[B(0.10, 0.21, 0.765, 0.80, 0.03)]),
        B(1.08, 1.13, 0.735, 0.79, 0.04),
    ], pivot=(0.62, BORE), motion="translate +z (back) up to 0.30: blowback, rack, lock open", wrap="A", explode=(0.0, 0.22, 0),
        note="rear serrations, ejection port (right), rear notch + front post sights"),
    Part("Barrel", "DarkSteel", [
        T(0.95, 1.19, BORE, 0.034, 0.019),
        B(0.50, 0.96, 0.62, 0.735, 0.118),
        C(1.06, 1.17, 0.645, 0.018),
    ], wrap="B", note="static: barrel crown, chamber hood (shows in the port), recoil spring guide"),
    Part("Mag", "Polymer", [
        P([(0.10, 0.03), (0.30, 0.03), (0.396, 0.455), (0.206, 0.455)], 0.12),
        P([(0.06, -0.0), (0.345, 0.0), (0.345, 0.04), (0.06, 0.042)], 0.17),
    ], parent="Handle", pivot=(0.30, 0.455), motion="translate down the grip axis (-y, +0.23 z per stud): drop out / insert",
        explode=(-0.10, -0.32, 0), note="magazine body (inside the grip) + flared base plate"),
    Part("MagRelease", "DarkSteel", [B(0.39, 0.46, 0.38, 0.44, 0.175, x=-0.0175)], pivot=(0.425, 0.41, -0.08),
         motion="translate +x 0.03 (pressed in)", explode=(0, 0, -0.12), note="cross-bolt: button on the left side behind the trigger guard, runs through the frame"),
    Part("SlideStop", "DarkSteel", [CX(0.585, 0.556, 0.02, -0.098, 0.0), B(0.64, 0.70, 0.60, 0.64, 0.045, x=-0.0675),
                                    P([(0.585, 0.538), (0.735, 0.565), (0.735, 0.618), (0.60, 0.618)], 0.022, x=-0.089)],
         pivot=(0.585, 0.556, -0.08), motion="rotate about x, lever tip up 12 deg (slide lock)", explode=(0, 0.05, -0.15),
         note="left side lever on its cross pin, with the inner tab that catches the slide"),
    Part("Trigger", "DarkSteel", [P([(0.545, 0.63), (0.578, 0.63), (0.578, 0.50), (0.588, 0.44), (0.628, 0.385), (0.612, 0.378),
                                     (0.566, 0.43), (0.545, 0.47)], 0.035),
                                   P([(0.40, 0.43), (0.505, 0.43), (0.505, 0.488), (0.56, 0.488), (0.56, 0.52), (0.40, 0.52)], 0.03)],
         pivot=(0.56, 0.495), motion="rotate about x, bottom back 15 deg (pull)", note="blade + hidden trigger bar inside the frame", explode=(0, -0.12, 0)),
    Part("Round", "Brass", [L([0.21, 0.31, 0.335, 0.36], [0.024, 0.024, 0.019, 0.0], 0.455, rot=0)],
         parent="Mag", pivot=(0.285, 0.455), motion="rides in the mag top at rest; animate to ShellEject on fire / show in the hand on reload",
         explode=(0, 0.2, 0.0),
         note="9mm cartridge"),
]

ATTACH = {
    "Muzzle": ("Barrel", (1.195, BORE)),
    "Grip": ("Handle", (0.25, 0.24)),
    "ShellEject": ("Slide", (0.625, 0.75, 0.07)),
    "Mag": ("Mag", (0.20, 0.02)),
    "SlideGrab": ("Slide", (0.26, 0.68)),
}
