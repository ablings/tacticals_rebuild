# Katana: curved single-edge blade (two-thickness: flat + edge bevel), round guard, brass collar, black wrap over white ray
# skin with diamond windows (inset method), end cap, grey scabbard (hidden at rest, for draw / sheath).
# 4.0 studs long like the old katana. f = toward the tip, z = spine up.
import math
NAME = "Katana"
ORIGIN = (-0.55, 0.0)
BL = 2.9


def curve(f):
    return 0.13 * (max(f, 0.0) / BL) ** 2


fs = [0.1 + i * (BL - 0.1) / 8 for i in range(9)]
spine = [(f, curve(f) + 0.055 - 0.015 * f / BL) for f in fs]
edge = [(f, curve(f) - 0.06 + 0.01 * f / BL) for f in fs]
tip = (BL + 0.1, curve(BL) + 0.005)
flat = [(f, (curve(f) - 0.015)) for f in fs]
blade_flat = flat + [tip] + list(reversed(spine))
blade_edge = edge + [tip] + list(reversed([(f, z + 0.01) for f, z in flat]))
saya = [(f, curve(f) - 0.085) for f in [0.0] + fs] + [(BL + 0.14, curve(BL))] + list(reversed([(f, curve(f) + 0.08) for f in [0.0] + fs]))
diamonds = []
for i in range(7):
    c = -0.95 + 0.06 + i * 0.13
    for s in (1, -1):
        diamonds.append(P([(c - 0.05, 0.0), (c, 0.05), (c + 0.05, 0.0), (c, -0.05)], 0.03, x=s * 0.06))
PARTS = [
    Part("Tsuka", "White", [B(-0.98, 0.01, -0.06, 0.06, 0.104)], wrap="B", note="ray-skin core of the grip"),
    Part("Wrap", "Polymer", [B(-0.96, 0.005, -0.075, 0.075, 0.12, cut=diamonds)], wrap="A", note="black wrap with diamond windows"),
    Part("Kashira", "DarkSteel", [B(-1.04, -0.95, -0.08, 0.08, 0.13)], wrap="B", note="end cap"),
    Part("Tsuba", "DarkSteel", [L([-0.03, 0.02], [0.16, 0.16], 0.0, seg=12)], wrap="B", note="round guard"),
    Part("Habaki", "Brass", [B(0.0, 0.13, -0.075, 0.07, 0.065)], wrap="B", note="blade collar"),
    Part("Blade", "Steel", [P(blade_flat, 0.04), P(blade_edge, 0.015), B(-0.5, 0.12, -0.04, 0.04, 0.03)], wrap="A",
         note="curved blade, flat above the temper line, thin edge bevel below; tang into the grip"),
    Part("Saya", "Polymer", [P(saya, 0.09)], pivot=(0.0, 0.0), visible=False,
         motion="hidden at rest; for draw / sheath: slides along the blade curve (translate -z, follow the sori)", explode=(0, -0.3, 0),
         note="scabbard; set Transparency 1 at rest"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "Tip": ("Blade", (BL + 0.1, curve(BL))), "EdgeMid": ("Blade", (1.5, curve(1.5) - 0.06)),
          "Trail0": ("Blade", (0.2, 0.0)), "Trail1": ("Blade", (BL, curve(BL)))}
