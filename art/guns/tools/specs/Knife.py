# Knife: fixed-blade field knife: grey grip with finger grooves and a lanyard hole, steel clip-point blade with a grind
# line (two-thickness blade, the flat-lowpoly way), finger guard, pommel cap, sheath (hidden at rest, for draw / holster).
# Read off ref/Knife_side.png; 1.9 studs long like the old knife. f = toward the tip, z = spine up, edge down.
NAME = "Knife"
ORIGIN = (-0.42, 0.0)
grip = [(-0.85, -0.07), (-0.62, -0.10), (-0.47, -0.075), (-0.33, -0.105), (-0.17, -0.075), (-0.02, -0.09), (-0.02, 0.085),
        (-0.30, 0.08), (-0.62, 0.09), (-0.82, 0.08), (-0.86, 0.03)]
blade_flat = [(0.0, -0.02), (0.72, -0.02), (0.95, 0.0), (0.62, 0.06), (0.0, 0.06)]
blade_edge = [(0.02, -0.10), (0.70, -0.10), (0.86, -0.065), (0.95, 0.0), (0.72, -0.01), (0.02, -0.01)]
PARTS = [
    Part("Grip", "Polymer", [P(grip, 0.16, cut=[CX(-0.78, 0.0, 0.026, -0.2, 0.2, seg=8), B(-0.70, -0.10, -0.06, 0.06, 0.06, x=0.09),
                                              B(-0.70, -0.10, -0.06, 0.06, 0.06, x=-0.09)])],
         wrap="A", note="grip with finger grooves, lanyard hole, inset panels"),
    Part("Blade", "Steel", [P(blade_flat, 0.035), P(blade_edge, 0.014), B(-0.10, 0.02, -0.06, 0.05, 0.03)], wrap="A",
         note="clip-point blade: flat (0.035) above the grind line, thin edge bevel (0.014) below; tang into the grip"),
    Part("Guard", "DarkSteel", [P([(-0.03, -0.14), (0.025, -0.14), (0.025, 0.10), (-0.03, 0.10)], 0.07)], wrap="B"),
    Part("Pommel", "DarkSteel", [P([(-0.93, -0.06), (-0.84, -0.075), (-0.83, 0.075), (-0.92, 0.06)], 0.15)], wrap="B"),
    Part("Sheath", "Polymer", [P([(-0.06, -0.15), (0.80, -0.14), (1.02, -0.02), (0.75, 0.10), (-0.06, 0.10)], 0.08),
                               B(0.05, 0.30, -0.12, 0.08, 0.10)], pivot=(0.0, 0.0), visible=False,
         motion="hidden at rest; for draw / holster: slides off along +z (-f) from the blade", explode=(0, -0.35, 0),
         note="sheath with belt clip; set Transparency 1 at rest"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "Tip": ("Blade", (0.95, 0.0)), "EdgeMid": ("Blade", (0.45, -0.10)), "Lanyard": ("Grip", (-0.78, 0.0))}
