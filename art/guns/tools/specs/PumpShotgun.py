# PumpShotgun: tactical 12-gauge pump: receiver with ejection port (right) and loading port underneath, shell lifter,
# tube magazine, ribbed fore-end pump on action bars, cross-bolt safety, ghost-ring rear sight, bead front sight,
# synthetic pistol-grip stock with a recoil pad, side saddle (left) with 4 shells. Read off grid/PumpShotgun_a/b.png (3.7).
NAME = "PumpShotgun"
ORIGIN = (0.86, 0.28)
BORE = 0.585
TUBE = 0.445

rec_section = [(-0.11, 0.39), (0.11, 0.39), (0.11, 0.63), (0.08, 0.66), (-0.08, 0.66), (-0.11, 0.63)]
stock = [(0.10, 0.0), (0.73, 0.24), (0.72, 0.18), (0.735, 0.165), (0.92, 0.15), (0.95, 0.20), (1.0, 0.32), (1.10, 0.38),
         (1.22, 0.40), (1.22, 0.62), (1.15, 0.64), (0.92, 0.51), (0.85, 0.555), (0.80, 0.56), (0.12, 0.53)]
guard = [(1.23, 0.41), (1.23, 0.30), (1.27, 0.265), (1.44, 0.265), (1.48, 0.30), (1.48, 0.41)]
guard_hole = [(1.27, 0.29), (1.44, 0.29), (1.455, 0.31), (1.455, 0.40), (1.27, 0.40)]
pump_section = [(-0.11, 0.37), (-0.08, 0.34), (0.08, 0.34), (0.11, 0.37), (0.11, 0.50), (0.08, 0.53), (-0.08, 0.53), (-0.11, 0.50)]
grooves = [B(f, f + 0.025, 0.36, 0.51, 0.04, x=s * 0.125) for f in (2.42, 2.50, 2.58, 2.66, 2.74, 2.82, 2.90, 2.98) for s in (1, -1)]
SADDLE_X = -0.14
SHELLS_F = (1.24, 1.32, 1.40, 1.48)

PARTS = [
    Part("Receiver", "Gunmetal", [
        PF(rec_section, 1.15, 2.05, cut=[B(1.65, 1.92, 0.53, 0.62, 0.1, x=0.10), B(1.50, 1.98, 0.37, 0.42, 0.14)]),
        P(guard, 0.06, cut=[P(guard_hole, 0.2)]),
        P([(1.25, 0.65), (1.45, 0.65), (1.45, 0.72), (1.40, 0.74), (1.36, 0.80), (1.32, 0.80), (1.30, 0.74), (1.25, 0.72)], 0.12,
          cut=[CX(1.34, 0.765, 0.02, -0.2, 0.2)]),
    ], wrap="A", note="receiver, ejection port (right), loading port (bottom), trigger guard, ghost-ring rear sight"),
    Part("Stock", "Polymer", [P(stock, 0.20, cut=[B(0.80, 1.05, 0.22, 0.42, 0.06, x=0.11), B(0.80, 1.05, 0.22, 0.42, 0.06, x=-0.11)])],
         wrap="A", note="synthetic pistol-grip stock, inset grip panels"),
    Part("ButtPad", "Rubber", [P([(0.0, 0.01), (0.10, 0.0), (0.12, 0.53), (0.03, 0.525)], 0.21)], parent="Stock", wrap="B"),
    Part("Barrel", "DarkSteel", [T(2.0, 3.70, BORE, 0.055, 0.035, rot=0), CZ(3.60, 0.62, 0.668, 0.013, rot=0), B(3.51, 3.57, 0.40, 0.62, 0.10)],
         wrap="B", note="barrel, bead sight, barrel clamp"),
    Part("MagTube", "DarkSteel", [C(1.95, 3.58, TUBE, 0.048), C(3.57, 3.63, TUBE, 0.06, seg=10)], wrap="B", note="tube magazine + end cap"),
    Part("Pump", "Polymer", [PF(pump_section, 2.31, 3.17, cut=grooves),
                             B(2.0, 2.32, 0.47, 0.495, 0.02, x=0.065), B(2.0, 2.32, 0.47, 0.495, 0.02, x=-0.065)],
         pivot=(2.74, TUBE), motion="translate +z 0.35 (rack back) and return", wrap="A", explode=(0.35, -0.15, 0),
         note="ribbed fore-end on twin action bars"),
    Part("Lifter", "DarkSteel", [B(1.52, 2.04, 0.385, 0.475, 0.13)], pivot=(1.52, 0.40),
         motion="rotate about x: front end up 15 deg to lift a shell to the chamber", explode=(0, -0.15, 0), note="shell lifter in the loading port"),
    Part("Trigger", "DarkSteel", [P([(1.32, 0.50), (1.355, 0.50), (1.355, 0.38), (1.38, 0.31), (1.365, 0.305), (1.33, 0.37)], 0.035), CX(1.34, 0.42, 0.022, -0.13, 0.03), B(1.20, 1.33, 0.46, 0.49, 0.03)],
         pivot=(1.34, 0.42), motion="rotate about x, bottom back 12 deg", explode=(0, -0.15, 0)),
    Part("Safety", "DarkSteel", [CX(1.58, 0.46, 0.025, -0.13, 0.13)], pivot=(1.58, 0.46), motion="translate x 0.03 (cross-bolt safe / fire)",
         explode=(0, 0, 0.15)),
    Part("SideSaddle", "Polymer", [B(1.19, 1.53, 0.42, 0.635, 0.05, x=-0.125)], wrap="B", note="left side shell carrier"),
    Part("SaddleShells", "Grey", [CZ(f, 0.455, 0.63, 0.034, x=SADDLE_X, rot=0) for f in SHELLS_F], parent="SideSaddle",
         motion="static (hand pulls one for a reload)", wrap="B", note="4 grey hulls"),
    Part("SaddleHeads", "Steel", [CZ(f, 0.42, 0.465, 0.037, x=SADDLE_X, rot=0) for f in SHELLS_F], parent="SideSaddle", wrap="B",
         note="steel shell heads"),
    Part("LoadShell", "Grey", [L([1.73, 1.94, 1.97], [0.034, 0.034, 0.005], 0.44, rot=0)], pivot=(1.85, 0.44),
         motion="the shell the hand carries: rest on the lifter in the loading port; animate from the saddle into the loading port", explode=(0, -0.35, 0),
         note="12-gauge hull"),
    Part("LoadShellHead", "Steel", [L([1.69, 1.735], [0.037, 0.037], 0.44, rot=0)], parent="LoadShell", wrap="B"),
]

ATTACH = {
    "Muzzle": ("Barrel", (3.70, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Receiver", (1.78, 0.58, 0.13)),
    "Mag": ("Receiver", (1.74, 0.38)),
    "Pump": ("Pump", (2.74, 0.34)),
}
