# SemiAuto: semi-automatic marksman rifle: dark receivers, olive furniture, side charging handle (left, folds out and
# pulls back), dust cover over the port with the bolt carrier behind it, straight 20-round mag, skeleton stock with an
# adjustable cheek riser, hollow slotted handguard, two-port brake, 4x scope with recessed glass on two rings.
# Read off grid/SemiAuto_a/b.png (4.9 studs).
NAME = "SemiAuto"
ORIGIN = (1.42, 0.40)
BORE = 0.86
SZ = 1.34                     # scope axis

hg_section = [(-0.135, 0.76), (-0.095, 0.72), (0.095, 0.72), (0.135, 0.76), (0.135, 0.96), (0.095, 1.0), (-0.095, 1.0), (-0.135, 0.96)]
hg_cuts = [B(2.58, 4.55, 0.75, 0.97, 0.20)]
hg_cuts += [B(2.70 + i * 0.20, 2.86 + i * 0.20, 0.845, 0.88, 0.4) for i in range(8)]
hg_cuts += [B(2.80 + i * 0.20, 2.96 + i * 0.20, 0.765, 0.79, 0.4) for i in range(8)]
hg_cuts += [B(2.90 + i * 0.20, 3.04 + i * 0.20, 0.93, 0.955, 0.4) for i in range(7)]
lower = [(1.30, 0.60), (1.66, 0.60), (1.68, 0.45), (1.72, 0.42), (2.02, 0.42), (2.05, 0.46), (2.05, 0.60), (2.52, 0.60),
         (2.56, 0.68), (2.52, 0.81), (1.30, 0.81)]
guard_hole = [(1.73, 0.45), (2.0, 0.45), (2.02, 0.48), (2.02, 0.58), (1.73, 0.58)]
stock = [(0.08, 0.22), (0.16, 0.27), (0.80, 0.27), (0.82, 0.33), (0.98, 0.66), (1.08, 0.72), (1.08, 0.93), (0.08, 0.93)]
SC_F = [1.24, 1.25, 1.60, 1.66, 1.70, 2.70, 2.78, 3.07, 3.08]
SC_R = [0.095, 0.117, 0.117, 0.075, 0.065, 0.065, 0.145, 0.145, 0.13]

scope_body = L(SC_F, SC_R, SZ, seg=12)
scope_body.cut = [C(3.05, 3.12, SZ, 0.12, seg=12), C(1.20, 1.27, SZ, 0.08, seg=12)]

PARTS = [
    Part("Upper", "Gunmetal", [
        B(1.30, 2.58, 0.78, 1.0, 0.24, cut=[B(2.05, 2.38, 0.82, 0.875, 0.12, x=0.11)]),
        B(1.38, 4.45, 0.995, 1.04, 0.12, cut=[B(1.30, 4.50, 1.01, 1.025, 0.02, x=0.06), B(1.30, 4.50, 1.01, 1.025, 0.02, x=-0.06)]),
    ], wrap="A", note="upper receiver, ejection port (right), full-length top rail"),
    Part("Lower", "Gunmetal", [P(lower, 0.24, cut=[P(guard_hole, 0.4)])], wrap="A", note="lower receiver, mag well, trigger guard"),
    Part("Grip", "Olive", [P([(1.35, 0.80), (1.62, 0.80), (1.62, 0.66), (1.50, 0.30), (1.45, 0.04), (1.30, 0.03), (1.17, 0.15)], 0.20,
                             cut=[B(1.20, 1.52, 0.12, 0.55, 0.06, x=0.115), B(1.20, 1.52, 0.12, 0.55, 0.06, x=-0.115)])],
         wrap="B", note="olive pistol grip, inset panels"),
    Part("Handguard", "Olive", [PF(hg_section, 2.55, 4.46, cut=hg_cuts)], wrap="A", note="hollow handguard, three slot rows through"),
    Part("Barrel", "DarkSteel", [
        L([2.45, 2.50, 2.63], [0.0, 0.045, 0.045], BORE, rot=0), T(2.62, 4.65, BORE, 0.045, 0.02, rot=0),
        B(4.20, 4.32, 0.74, 0.98, 0.205),
        B(4.62, 4.90, 0.77, 0.95, 0.17, cut=[B(4.67, 4.73, 0.81, 0.91, 0.4), B(4.77, 4.83, 0.81, 0.91, 0.4), C(4.85, 4.95, BORE, 0.025)]),
    ], wrap="B", note="barrel, gas block, two-port brake"),
    Part("BufferTube", "DarkSteel", [C(0.40, 1.62, 0.85, 0.065, rot=0), C(1.0, 1.27, 0.85, 0.085, rot=0)], wrap="B"),
    Part("Stock", "Olive", [P(stock, 0.22, cut=[P([(0.30, 0.40), (0.70, 0.40), (0.86, 0.66), (0.30, 0.66)], 0.4),
                                                  B(0.30, 0.70, 0.29, 0.34, 0.4)])],
         pivot=(0.70, 0.85), motion="translate along the buffer tube +z 0.2 (length of pull)", wrap="A", explode=(-0.25, 0, 0),
         note="skeleton precision stock"),
    Part("ButtPad", "Rubber", [B(0.0, 0.10, 0.22, 0.93, 0.24)], parent="Stock", wrap="B"),
    Part("CheekRiser", "Olive", [B(0.28, 0.92, 0.95, 1.02, 0.18), CZ(0.43, 0.88, 0.97, 0.02, rot=0), CZ(0.78, 0.88, 0.97, 0.02, rot=0)],
         parent="Stock", pivot=(0.60, 0.95), motion="translate +y 0.1 (adjust)", wrap="A", explode=(0, 0.15, 0)),
    Part("Scope", "Polymer", [scope_body, CZ(2.15, 1.38, 1.47, 0.075, seg=10), CX(2.15, SZ, 0.06, 0.05, 0.15, seg=10)], wrap="B",
         note="4x scope: eyepiece, tube, objective bell, elevation + windage turrets"),
    Part("ScopeRings", "DarkSteel", [B(1.62, 1.69, 1.035, 1.325, 0.14), B(2.80, 2.87, 0.99, 1.325, 0.14)] +
         [L([f, f + 0.07], [0.075, 0.075], SZ, seg=12) for f in (1.62, 2.80)], wrap="B"),
    Part("ScopeLensFront", "Lens", [L([3.04, 3.06], [0.124, 0.124], SZ, seg=12)], parent="Scope", wrap="skip"),
    Part("ScopeLensRear", "Lens", [L([1.255, 1.265], [0.084, 0.084], SZ, seg=12)], parent="Scope", wrap="skip"),
    Part("Mag", "Polymer", [P([(2.06, 0.03), (2.45, 0.03), (2.45, 0.60), (2.38, 0.82), (2.06, 0.82)], 0.15), B(2.05, 2.46, 0.0, 0.05, 0.17)], pivot=(2.25, 0.82),
         motion="translate -y (straight down), new mag pushed up", explode=(0, -0.35, 0), note="straight 20-round box mag"),
    Part("ChargingHandle", "DarkSteel", [B(1.82, 1.98, 0.88, 0.94, 0.03, x=-0.125),
                                         P([(1.84, 0.88), (2.02, 0.89), (2.02, 0.93), (1.84, 0.94)], 0.04, x=-0.14),
                                         B(1.83, 2.10, 0.80, 0.87, 0.13, x=-0.055)],
         pivot=(1.90, 0.91, -0.13), motion="rotate the lever out about z 70 deg, translate +z 0.4 (pull), return",
         explode=(0, 0, -0.2), note="non-reciprocating side charger (left) + hidden link to the carrier"),
    Part("BoltCarrier", "DarkSteel", [B(1.55, 2.48, 0.79, 0.88, 0.20), C(2.47, 2.63, BORE, 0.03, rot=0)], pivot=(2.0, BORE),
         motion="translate +z 0.45 per shot", explode=(0, 0.3, 0)),
    Part("DustCover", "DarkSteel", [B(2.03, 2.39, 0.80, 0.88, 0.03, x=0.13), B(2.07, 2.10, 0.80, 0.83, 0.13, x=0.065)],
         pivot=(2.215, 0.81, 0.135), motion="rotate about z 100 deg down: springs open on the first shot", explode=(0, 0, 0.15)),
    Part("Trigger", "DarkSteel", [P([(1.78, 0.81), (1.86, 0.81), (1.86, 0.70), (1.82, 0.58), (1.84, 0.52), (1.86, 0.46), (1.845, 0.455), (1.80, 0.53),
                                     (1.78, 0.58)], 0.035), B(1.60, 1.82, 0.72, 0.75, 0.03)],
         pivot=(1.80, 0.76), motion="rotate about x, bottom back 10 deg (match trigger)", explode=(0, -0.2, 0)),
    Part("Selector", "DarkSteel", [CX(1.63, 0.70, 0.022, -0.14, 0.14),
                                   P([(1.56, 0.685), (1.69, 0.685), (1.69, 0.715), (1.56, 0.715)], 0.02, x=0.135),
                                   P([(1.60, 0.685), (1.67, 0.685), (1.67, 0.715), (1.60, 0.715)], 0.02, x=-0.135),
                                   B(1.60, 1.66, 0.60, 0.81, 0.04)],
         pivot=(1.63, 0.70), motion="rotate about x 90 deg (safe / fire)", explode=(0, 0, 0.15), note="ambi safety"),
    Part("MagRelease", "DarkSteel", [CX(2.08, 0.70, 0.03, -0.10, 0.145)], pivot=(2.08, 0.70, 0.13), motion="translate -x 0.03 (pressed)",
         explode=(0, 0, 0.2), note="button on the right, cross-bolt catch into the mag"),
    Part("BoltCatch", "DarkSteel", [P([(2.27, 0.66), (2.39, 0.68), (2.35, 0.79), (2.30, 0.78)], 0.025, x=-0.13),
                                    CX(2.32, 0.72, 0.018, -0.14, 0.0), B(2.33, 2.39, 0.76, 0.83, 0.07, x=-0.075)],
         pivot=(2.32, 0.72, -0.12), motion="rotate about x 10 deg", explode=(0, 0, -0.15), note="left paddle"),
    Part("Round", "Brass", [L([2.12, 2.135, 2.35, 2.39, 2.44], [0.005, 0.034, 0.034, 0.022, 0.0], 0.78, rot=0)], parent="Mag",
         pivot=(2.28, 0.78), motion="rides in the mag top; animate to ShellEject", explode=(0, 0.3, 0), note=".308 round"),
]

ATTACH = {
    "Muzzle": ("Barrel", (4.90, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Upper", (2.28, 0.85, 0.16)),
    "Mag": ("Mag", (2.25, 0.02)),
    "Handguard": ("Handguard", (3.40, 0.72)),
    "AimPoint": ("Scope", (1.24, SZ)),
}
