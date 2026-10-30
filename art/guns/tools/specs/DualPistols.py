# DualPistols: a matched pair of compact striker pistols with ported compensators, white slides, flared mag wells.
# Read off grid/DualPistols.png (1.2 image studs) and scaled to compact size (SCALE 0.875 -> 1.05 studs long).
# Right pistol hangs off the Handle; the left pistol is a full copy under its own root part LeftFrame (1.1 studs to the
# left, as the old tool), so it can be animated to / welded on the left hand.
NAME = "DualPistols"
SCALE = 0.875
ORIGIN = (0.24, 0.219)
BORE = 0.745
SW, FW = 0.165, 0.15
ST, SB = 0.824, 0.695
DX = -1.1 / SCALE              # left pistol offset in image units

frame_outline = [(0.05, 0.10), (0.40, 0.10), (0.46, 0.42), (0.78, 0.42), (0.80, 0.45), (0.80, 0.585), (0.82, 0.59),
                 (1.04, 0.59), (1.06, 0.61), (1.06, 0.705), (0.08, 0.705), (0.0, 0.648), (0.015, 0.628), (0.13, 0.575)]
flare = [(0.0, 0.06), (0.42, 0.06), (0.42, 0.13), (0.405, 0.15), (0.03, 0.15), (0.0, 0.13)]
guard_hole = [(0.52, 0.445), (0.76, 0.445), (0.78, 0.47), (0.78, 0.582), (0.52, 0.582)]
grip_panel = [(0.06, 0.155), (0.39, 0.155), (0.445, 0.41), (0.44, 0.53), (0.18, 0.60), (0.14, 0.58)]
slide_section = [(-SW / 2, SB), (SW / 2, SB), (SW / 2, ST - 0.025), (SW / 2 - 0.022, ST), (-SW / 2 + 0.022, ST), (-SW / 2, ST - 0.025)]


def cuts(f0, n, pitch, side, x0):
    return [P([(f0 + i * pitch, 0.715), (f0 + i * pitch + 0.02, 0.715), (f0 + i * pitch + 0.05, 0.81), (f0 + i * pitch + 0.03, 0.81)],
              0.04, x=x0 + side * SW / 2) for i in range(n)]


def pistol(pre, x0, root):
    fr = pre + "Frame" if pre else "Frame"
    parent = root
    parts = [
        Part(fr, "Polymer", [
            P(frame_outline, FW, x=x0, cut=[P(guard_hole, 0.4, x=x0)] + [B(f, f + 0.035, 0.575, 0.602, 0.4, x=x0) for f in (0.86, 0.93, 0.99)]),
            P(grip_panel, 0.18, x=x0, cut=[B(0.05, 0.43, 0.20, 0.52, 0.06, x=x0 + 0.105), B(0.05, 0.43, 0.20, 0.52, 0.06, x=x0 - 0.105)]),
            P(flare, 0.195, x=x0),
        ], parent="Handle", wrap="A",
            pivot=None if not pre else (0.24, 0.219, x0),
            motion="static" if not pre else "whole left pistol: animate / weld to the left hand (pivot = its grip centre)",
            note="compact frame, rail, flared mag well, stippled inset panels"),
        Part(pre + "Slide", "LightGrey", [
            PF([(x0 + a, b) for a, b in slide_section], 0.083, 1.04,
               cut=cuts(0.15, 5, 0.04, 1, x0) + cuts(0.15, 5, 0.04, -1, x0) + cuts(0.85, 3, 0.04, 1, x0) + cuts(0.85, 3, 0.04, -1, x0) +
               [B(0.40, 0.70, 0.745, 0.90, 0.1, x=x0 + 0.05)]),
            P([(0.13, 0.81), (0.20, 0.81), (0.20, 0.865), (0.13, 0.865)], 0.12, x=x0, cut=[B(0.12, 0.21, 0.84, 0.88, 0.03, x=x0)]),
            B(0.96, 1.02, 0.81, 0.865, 0.045, x=x0),
        ], parent=fr, pivot=(0.60, BORE, x0), motion="translate +z (back) up to 0.28", wrap="A", explode=(0, 0.22, 0),
            note="white slide, front + rear slanted cuts, ejection port, optic-cut rear"),
        Part(pre + "Barrel", "DarkSteel", [
            T(0.90, 1.08, BORE, 0.032, 0.018, x=x0),
            B(0.38, 0.91, 0.69, 0.81, 0.118, x=x0),
            C(0.98, 1.07, 0.655, 0.018, x=x0),
        ], parent=fr, wrap="B", note="static barrel, chamber hood, guide rod"),
        Part(pre + "Comp", "Steel", [
            B(1.03, 1.20, 0.64, 0.825, 0.17, x=x0, cut=[B(1.08, 1.115, 0.78, 0.90, 0.11, x=x0), B(1.135, 1.17, 0.78, 0.90, 0.11, x=x0),
                                                    B(1.08, 1.115, 0.70, 0.78, 0.3, x=x0), B(1.135, 1.17, 0.70, 0.78, 0.3, x=x0),
                                                    C(1.17, 1.25, BORE, 0.022, x=x0)]),
        ], parent=pre + "Barrel", wrap="B", note="ported compensator: two top ports, two side windows (the RIVALS inset method)"),
        Part(pre + "Mag", "Polymer", [
            P([(0.10, 0.06), (0.36, 0.06), (0.437, 0.45), (0.197, 0.45)], 0.12, x=x0),
            P([(0.05, 0.0), (0.33, 0.0), (0.33, 0.065), (0.06, 0.065)], 0.15, x=x0),
        ], parent=fr, pivot=(0.31, 0.43, x0), motion="translate down the grip axis", explode=(-0.08, -0.35, 0)),
        Part(pre + "MagRelease", "DarkSteel", [B(0.39, 0.45, 0.44, 0.51, 0.175, x=x0 - 0.0175)], parent=fr, pivot=(0.42, 0.475, x0 - 0.08),
             motion="translate +x 0.03 (pressed in)", explode=(0, 0, -0.12), note="extended cross-bolt"),
        Part(pre + "SlideStop", "DarkSteel", [CX(0.62, 0.635, 0.02, x0 - 0.098, x0), B(0.63, 0.69, 0.675, 0.715, 0.045, x=x0 - 0.0675),
                                              P([(0.43, 0.66), (0.62, 0.63), (0.64, 0.655), (0.63, 0.70), (0.45, 0.70)], 0.022, x=x0 - 0.089)],
             parent=fr, pivot=(0.62, 0.635, x0 - 0.08), motion="rotate about x, lever tail up 12 deg", explode=(0, 0.05, -0.15),
             note="extended lever reaching back to the thumb"),
        Part(pre + "Trigger", "DarkSteel", [P([(0.548, 0.70), (0.63, 0.70), (0.63, 0.60), (0.578, 0.58), (0.625, 0.47), (0.61, 0.462), (0.548, 0.57)], 0.035, x=x0,
                                              cut=[P([(0.565, 0.565), (0.60, 0.495), (0.592, 0.49), (0.558, 0.555)], 0.1, x=x0)]),
                                            P([(0.38, 0.44), (0.51, 0.44), (0.51, 0.585), (0.56, 0.585), (0.56, 0.62), (0.38, 0.62)], 0.03, x=x0)],
             parent=fr, pivot=(0.56, 0.58, x0), motion="rotate about x, bottom back 12 deg", explode=(0, -0.12, 0),
             note="flat skeleton trigger + hidden trigger bar"),
        Part(pre + "Round", "Brass", [L([0.22, 0.32, 0.345, 0.37], [0.024, 0.024, 0.019, 0.0], 0.43, x=x0, rot=0)], parent=pre + "Mag",
             pivot=(0.30, 0.43, x0), motion="rides in the mag top; animate to ShellEject", explode=(0, 0.2, 0)),
    ]
    return parts


PARTS = pistol("", 0.0, "Handle") + pistol("Left", DX, "Handle")

ATTACH = {
    "Muzzle": ("Comp", (1.20, BORE)),
    "LeftMuzzle": ("LeftComp", (1.20, BORE, DX)),
    "Grip": ("Handle", ORIGIN),
    "LeftGrip": ("LeftFrame", (0.24, 0.219, DX)),
    "ShellEject": ("Slide", (0.55, 0.83, 0.07)),
    "LeftShellEject": ("LeftSlide", (0.55, 0.83, DX + 0.07)),
    "Mag": ("Mag", (0.19, 0.02)),
    "LeftMag": ("LeftMag", (0.19, 0.02, DX)),
}
