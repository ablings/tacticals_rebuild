# Bat: light grey baseball bat: knob, thin handle with grip tape, taper, thick rounded barrel with a burned band.
# 2.9 studs like the old bat. f = toward the barrel end.
NAME = "Bat"
ORIGIN = (-0.45, 0.0)
FS = [-1.0, -0.995, -0.955, -0.925, -0.90, 0.25, 0.85, 1.45, 1.80, 1.86, 1.89, 1.90]
RS = [0.0, 0.085, 0.09, 0.05, 0.045, 0.05, 0.095, 0.132, 0.132, 0.12, 0.08, 0.0]
PARTS = [
    Part("Bat", "LightGrey", [L(FS, RS, 0.0, seg=12)], wrap="A", note="one lathe: knob, handle, taper, barrel, rounded end"),
    Part("GripTape", "Polymer", [L([-0.90, -0.89, 0.12, 0.13], [0.0, 0.051, 0.054, 0.0], 0.0, seg=12, rot=0)], wrap="B",
         note="grip tape sleeve over the handle"),
    Part("Band", "DarkGrey", [L([1.18, 1.19, 1.28, 1.29], [0.0, 0.127, 0.129, 0.0], 0.0, seg=12, rot=0)], wrap="B", note="burned band"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "Tip": ("Bat", (1.90, 0.0)), "SweetSpot": ("Bat", (1.45, 0.0)), "Trail0": ("Bat", (0.5, 0.0))}
