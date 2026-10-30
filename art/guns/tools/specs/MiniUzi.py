# MiniUzi: compact open-bolt machine pistol: boxy stamped receiver with ribbed top cover, top cocking knob, mag through
# the grip, grip safety, selector, folding wire stock. Read off grid/MiniUzi.png (2.1 studs with the stock open).
NAME = "MiniUzi"
ORIGIN = (1.09, 0.53)
BORE = 0.99
SX = 0.085                     # stock rail x offset

lower = [(0.975, 0.44), (1.20, 0.44), (1.205, 0.74), (1.23, 0.665), (1.47, 0.665), (1.50, 0.70), (1.50, 0.85), (0.96, 0.85),
         (1.0, 0.79), (1.0, 0.62)]
guard_hole = [(1.25, 0.69), (1.45, 0.69), (1.47, 0.72), (1.47, 0.83), (1.25, 0.83)]


def stock_side(x):
    r = 0.018
    return [CA((x, 0.78, 0.99), (x, 0.045, 0.935), r, seg=6), CA((x, 0.77, 0.89), (x, 0.045, 0.69), r, seg=6),
            CA((x, 0.04, 0.66), (x, 0.04, 1.045), r, seg=6), CA((x, 0.03, 1.035), (x, 0.10, 1.035), r, seg=6)]


PARTS = [
    Part("Receiver", "Gunmetal", [
        B(0.80, 1.80, 0.837, 1.0, 0.20, cut=[B(1.37, 1.55, 0.925, 0.985, 0.1, x=0.09)]),
        B(0.86, 1.80, 0.99, 1.115, 0.19, cut=[B(0.92, 1.77, z, z + 0.014, 0.03, x=s * 0.095) for z in (1.03, 1.06, 1.09) for s in (1, -1)] +
          [B(1.0, 1.62, 1.095, 1.14, 0.03)]),
        B(0.74, 0.82, 0.83, 1.05, 0.22),
        P([(0.88, 1.10), (0.95, 1.10), (0.95, 1.17), (0.88, 1.17)], 0.10, cut=[B(0.87, 0.96, 1.14, 1.20, 0.03)]),
    ], wrap="A", note="stamped receiver, ribbed top cover (3 slots a side), ejection port (right), cocking slot, rear plate, rear sight"),
    Part("LowerFrame", "Polymer", [
        P(lower, 0.18, cut=[P(guard_hole, 0.4), B(1.02, 1.18, 0.47, 0.80, 0.06, x=0.105), B(1.02, 1.18, 0.47, 0.80, 0.06, x=-0.105)]),
    ], wrap="A", note="grip + trigger guard, inset grip panels"),
    Part("Barrel", "DarkSteel", [
        C(1.79, 1.905, 0.985, 0.064),
        T(1.90, 2.10, BORE, 0.043, 0.02),
        P([(1.89, 1.03), (1.97, 1.03), (1.97, 1.13), (1.945, 1.17), (1.91, 1.17), (1.89, 1.10)], 0.11, cut=[B(1.88, 1.99, 1.06, 1.20, 0.05)]),
        B(1.92, 1.945, 1.03, 1.14, 0.025),
    ], wrap="B", note="barrel nut, barrel, hooded front sight"),
    Part("Mag", "DarkSteel", [B(1.02, 1.18, 0.02, 0.84, 0.13), B(1.005, 1.195, 0.0, 0.04, 0.15)], pivot=(1.10, 0.84),
         motion="translate -y (straight down out of the grip)", explode=(0, -0.35, 0), note="32-round stick mag + base plate"),
    Part("CockingKnob", "DarkSteel", [CZ(1.32, 1.07, 1.20, 0.018, rot=0), CZ(1.32, 1.19, 1.245, 0.042, seg=10)],
         pivot=(1.32, 1.10), motion="translate +z (back) 0.35 along the top slot, snap forward", explode=(0, 0.12, 0)),
    Part("Trigger", "DarkSteel", [P([(1.30, 0.86), (1.34, 0.86), (1.34, 0.78), (1.36, 0.72), (1.345, 0.705), (1.32, 0.76), (1.30, 0.80)], 0.035),
                                   B(1.15, 1.31, 0.832, 0.86, 0.03)],
         pivot=(1.32, 0.83), motion="rotate about x, bottom back 15 deg", explode=(0, -0.15, 0), note="blade + hidden trigger bar"),
    Part("Selector", "DarkSteel", [CX(1.33, 0.87, 0.022, -0.12, 0.0), P([(1.33, 0.855), (1.44, 0.862), (1.44, 0.888), (1.33, 0.89)], 0.02, x=-0.11)],
         pivot=(1.33, 0.87, -0.1), motion="rotate about x 30 deg (safe / semi / auto)", explode=(0, 0, -0.15), note="left side"),
    Part("GripSafety", "Polymer", [P([(0.95, 0.61), (1.005, 0.61), (1.03, 0.80), (0.975, 0.83)], 0.12)], pivot=(0.995, 0.80),
         motion="rotate about x, bottom in 8 deg when gripped", explode=(-0.12, 0, 0)),
    Part("Stock", "DarkSteel", stock_side(SX) + stock_side(-SX) + [CX(0.04, 0.665, 0.02, -SX, SX), CX(0.775, 0.94, 0.03, -0.11, 0.11)],
         pivot=(0.775, 0.94), motion="rotate about x ~185 deg to fold under the receiver", explode=(-0.2, 0, 0),
         note="folding wire stock: two rails a side, butt loop, hinge pin"),
    Part("Round", "Brass", [L([1.0, 1.10, 1.12, 1.145], [0.022, 0.022, 0.017, 0.0], 0.82, rot=0)], parent="Mag", pivot=(1.07, 0.82),
         motion="rides in the mag top; animate to ShellEject", explode=(0, 0.25, 0)),
]

ATTACH = {
    "Muzzle": ("Barrel", (2.10, BORE)),
    "Grip": ("Handle", ORIGIN),
    "ShellEject": ("Receiver", (1.46, 0.96, 0.11)),
    "Mag": ("Mag", (1.10, 0.02)),
    "StockButt": ("Stock", (0.04, 0.85)),
}
