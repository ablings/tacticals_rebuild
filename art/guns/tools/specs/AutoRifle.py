# AutoRifle: 5.56 gas carbine: flat-top upper with red-dot, hollow slotted handguard (barrel shows through the slots),
# dust cover over the ejection port with the bolt carrier behind it, rear T charging handle, curved 30-round mag,
# ambi selector, collapsible stock on a buffer tube. Read off grid/AutoRifle_a/b.png (4.2 studs).
NAME = "AutoRifle"
ORIGIN = (1.30, 0.745)
BORE = 1.205

hg_section = [(-0.135, 1.095), (-0.095, 1.055), (0.095, 1.055), (0.135, 1.095), (0.135, 1.295), (0.095, 1.335), (-0.095, 1.335), (-0.135, 1.295)]
mid = [(2.60, 2.80), (2.86, 3.04), (3.08, 3.27), (3.30, 3.48), (3.53, 3.72)]
low = [(2.66, 2.84), (2.90, 3.08), (3.12, 3.30), (3.34, 3.52), (3.56, 3.74)]
hg_cuts = [B(2.25, 3.90, 1.09, 1.30, 0.20)]
hg_cuts += [B(a, b, 1.16, 1.205, 0.4) for a, b in mid]
hg_cuts += [B(a, b, 1.085, 1.115, 0.4) for a, b in low]
hg_cuts += [B(a, a + 0.12, 1.30, 1.36, 0.10) for a in (2.55, 2.75, 2.95, 3.15, 3.35, 3.55)]

lower = [(1.17, 0.92), (1.52, 0.88), (1.55, 0.70), (1.60, 0.67), (1.86, 0.67), (1.90, 0.72), (1.90, 0.78), (2.32, 0.78),
         (2.36, 0.90), (2.30, 1.10), (1.17, 1.10)]
guard_hole = [(1.60, 0.70), (1.85, 0.70), (1.87, 0.73), (1.87, 0.86), (1.60, 0.86)]
stock = [(0.08, 0.585), (0.17, 0.62), (0.33, 0.92), (0.60, 0.92), (0.75, 0.97), (0.95, 1.07), (0.95, 1.30), (0.08, 1.30)]
mag = [(1.88, 1.10), (2.31, 1.10), (2.32, 0.80), (2.36, 0.45), (2.40, 0.15), (2.38, 0.05), (2.00, 0.04), (1.92, 0.40), (1.89, 0.78)]

PARTS = [
    Part("Upper", "Tan", [
        B(1.15, 2.36, 1.07, 1.335, 0.26, cut=[B(1.77, 2.06, 1.10, 1.21, 0.12, x=0.11)]),
        B(1.15, 3.81, 1.33, 1.375, 0.12, cut=[B(1.10, 3.90, 1.345, 1.36, 0.02, x=0.06), B(1.10, 3.90, 1.345, 1.36, 0.02, x=-0.06)]),
        B(1.30, 1.62, 1.15, 1.29, 0.06, x=0.135),
    ], wrap="A", note="upper receiver, ejection port (right), top rail with side grooves, forward-assist housing"),
    Part("Lower", "Tan", [P(lower, 0.24, cut=[P(guard_hole, 0.4)])], wrap="A", note="lower receiver, mag well, trigger guard"),
    Part("Grip", "Polymer", [P([(1.25, 0.97), (1.52, 0.91), (1.33, 0.32), (1.24, 0.27), (1.00, 0.37)], 0.20,
                               cut=[B(1.05, 1.45, 0.40, 0.85, 0.06, x=0.115), B(1.05, 1.45, 0.40, 0.85, 0.06, x=-0.115)])],
         wrap="B", note="raked pistol grip with inset panels"),
    Part("Handguard", "Tan", [PF(hg_section, 2.30, 3.80, cut=hg_cuts)], wrap="A",
         note="hollow octagonal handguard: M-LOK slots go through, barrel and gas block show inside"),
    Part("Barrel", "DarkSteel", [
        T(2.30, 3.92, BORE, 0.036, 0.016),
        B(3.50, 3.62, 1.08, 1.31, 0.205),
        T(3.86, 4.20, BORE, 0.062, 0.03),
    ], wrap="B", note="barrel, gas block, birdcage flash hider"),
    Part("BufferTube", "DarkSteel", [C(0.40, 1.40, 1.17, 0.075, rot=0), C(0.95, 1.16, 1.17, 0.10, rot=0)], wrap="B", note="buffer tube + castle nut"),
    Part("Stock", "Tan", [P(stock, 0.22, cut=[P([(0.19, 0.80), (0.38, 1.0), (0.19, 1.0)], 0.4)])], pivot=(0.60, 1.17),
         motion="translate along the buffer tube +z 0.25 (collapse / extend)", wrap="A", explode=(-0.25, 0, 0), note="skeleton stock"),
    Part("ButtPad", "Rubber", [B(0.0, 0.10, 0.58, 1.30, 0.24)], parent="Stock", wrap="B"),
    Part("Optic", "DarkSteel", [
        B(1.72, 2.10, 1.37, 1.47, 0.14),
        L([1.73, 1.75, 2.07, 2.10], [0.075, 0.098, 0.098, 0.11], 1.585, seg=10),
        CZ(1.92, 1.67, 1.72, 0.04), CX(1.92, 1.585, 0.04, 0.09, 0.135),
    ], wrap="B", note="red-dot: mount, tube, turrets"),
    Part("OpticLens", "Lens", [L([2.06, 2.08], [0.092, 0.092], 1.585, seg=10)], parent="Optic", wrap="skip", note="glass, WrapSkip"),
    Part("Mag", "Polymer", [P(mag, 0.15), P([(1.985, 0.0), (2.40, 0.01), (2.40, 0.07), (1.99, 0.06)], 0.17)], pivot=(2.10, 0.98),
         motion="drop out down/forward along its curve; new mag rocked in about x at the well", explode=(0.05, -0.4, 0),
         note="curved 30-round polymer mag + base plate"),
    Part("ChargingHandle", "DarkSteel", [B(1.11, 1.50, 1.255, 1.335, 0.06), B(1.11, 1.17, 1.29, 1.40, 0.26), B(1.10, 1.20, 1.335, 1.385, 0.05, x=-0.10)],
         pivot=(1.14, 1.33), motion="translate +z 0.45 (pull back), release forward", explode=(-0.3, 0.1, 0), note="T-handle + latch"),
    Part("BoltCarrier", "DarkSteel", [B(1.35, 2.08, 1.09, 1.215, 0.24), B(1.35, 1.50, 1.20, 1.265, 0.06), C(2.06, 2.13, 1.16, 0.035, rot=0)], pivot=(1.70, BORE),
         motion="translate +z 0.45 per shot (shows through the open port)", explode=(0, 0.35, 0.0), note="carrier + bolt head"),
    Part("DustCover", "DarkSteel", [B(1.76, 2.07, 1.08, 1.215, 0.03, x=0.13), B(1.885, 1.92, 1.08, 1.11, 0.06, x=0.10)], pivot=(1.915, 1.09, 0.135),
         motion="rotate about z (the barrel axis) 100 deg down: springs open on the first shot / charge", explode=(0, 0, 0.12)),
    Part("Trigger", "DarkSteel", [P([(1.63, 1.10), (1.67, 1.10), (1.67, 0.86), (1.70, 0.79), (1.72, 0.73), (1.705, 0.725), (1.66, 0.80), (1.63, 0.86)], 0.035),
                                   B(1.45, 1.67, 1.02, 1.05, 0.03)],
         pivot=(1.65, 0.95), motion="rotate about x, bottom back 12 deg", explode=(0, -0.2, 0), note="blade + hidden tail under the selector cam"),
    Part("Selector", "DarkSteel", [CX(1.47, 1.0, 0.022, -0.14, 0.14), P([(1.40, 0.985), (1.53, 0.985), (1.53, 1.015), (1.40, 1.015)], 0.02, x=0.135),
                                   P([(1.47, 0.985), (1.56, 0.985), (1.56, 1.015), (1.47, 1.015)], 0.02, x=-0.135),
                                   B(1.44, 1.50, 0.90, 1.10, 0.04)],
         pivot=(1.47, 1.0), motion="rotate about x 45/90 deg (safe / semi / auto)", explode=(0, 0, 0.15), note="ambi levers on a cross drum"),
    Part("MagRelease", "DarkSteel", [CX(1.845, 1.0, 0.03, -0.10, 0.145)], pivot=(1.845, 1.0, 0.13), motion="translate -x 0.03 (pressed)",
         explode=(0, 0, 0.2), note="button on the right, cross-bolt to the mag catch"),
    Part("BoltCatch", "DarkSteel", [P([(2.15, 0.94), (2.26, 0.96), (2.22, 1.07), (2.17, 1.06)], 0.025, x=-0.13), CX(2.20, 1.0, 0.018, -0.14, 0.0), B(2.06, 2.12, 1.05, 1.12, 0.07, x=-0.075)],
         pivot=(2.20, 1.0, -0.12), motion="rotate about x 10 deg (paddle up locks the bolt back)", explode=(0, 0, -0.15), note="left side paddle"),
    Part("Round", "Brass", [L([1.97, 1.985, 2.18, 2.22, 2.27], [0.005, 0.03, 0.03, 0.02, 0.0], 1.07, rot=0)], parent="Mag", pivot=(2.10, 1.07),
         motion="rides in the mag top; animate to ShellEject", explode=(0, 0.3, 0), note="5.56 round"),
]

# hollow the red-dot tube's front so the lens sits recessed in it
PARTS[[p.name for p in PARTS].index("Optic")].solids[1].cut = [C(2.05, 2.15, 1.585, 0.088, seg=10)]

ATTACH = {
    "Muzzle": ("Barrel", (4.20, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Upper", (1.92, 1.20, 0.16)),
    "Mag": ("Mag", (2.20, 0.03)),
    "Handguard": ("Handguard", (3.0, 1.06)),
    "AimPoint": ("Optic", (1.75, 1.585)),
}
