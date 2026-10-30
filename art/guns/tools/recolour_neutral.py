"""One-off (2026-10-30): move every spec off the lobby palette onto neutral white / grey / black (Edward: skins and wraps add
the colour). Also rewrites gunkit's PALETTE so the lobby colours can't come back by accident."""
import re, glob, os
HERE = os.path.dirname(os.path.abspath(__file__))
p = os.path.join(HERE, "gunkit.py")
s = open(p).read()
start = s.index("PALETTE = {")
end = s.index("}", start) + 1
s = s[:start] + '''PALETTE = {
    # neutral base (Edward 2026-10-30: gear is white / grey / black; skins and wraps add the colour)
    "White":     (210, 212, 215),
    "LightGrey": (152, 154, 158),
    "Grey":      (112, 114, 118),
    "MidGrey":   (80, 82, 86),
    "DarkGrey":  (52, 54, 58),
    "Polymer":   (28, 29, 31),
    "Gunmetal":  (54, 57, 62),
    "Steel":     (110, 112, 118),
    "DarkSteel": (20, 21, 23),
    "Rubber":    (36, 36, 38),
    # functional accents only
    "Lens":      (40, 70, 90),
    "Brass":     (168, 144, 96),
    "Bore":      (8, 8, 9),
    "Glow":      (230, 236, 240),
}''' + s[end:]
open(p, "w").write(s)

DEFAULT = {"OliveLt": "Grey", "Olive": "MidGrey", "Tan": "Grey", "Cream": "White", "Sage": "LightGrey", "Ash": "LightGrey", "Wood": "Polymer"}
OVER = {("Knife", '"Grip"'): "Polymer", ("Katana", '"Saya"'): "Polymer", ("Bat", '"Band"'): "DarkGrey",
        ("Medkit", '"InjectorCap"'): "DarkGrey", ("RiotShield", '"Rim"'): "LightGrey", ("DualPistols", 'pre + "Slide"'): "LightGrey",
        ("PumpShotgun", '"SaddleShells"'): "Grey", ("PumpShotgun", '"LoadShell"'): "Grey"}
WORDS = {"olive drab": "grey", "dark olive": "dark grey", "olive": "grey", "cream": "white", "warm grey": "light grey",
         "sage": "light grey", "ash wood": "light grey", " tan ": " grey "}
for f in glob.glob(os.path.join(HERE, "specs", "*.py")):
    g = os.path.basename(f)[:-3]
    s = open(f).read()
    s = re.sub(r'Part\(([^,]+), "(OliveLt|Olive|Tan|Cream|Sage|Ash|Wood)"',
               lambda m: 'Part(%s, "%s"' % (m.group(1), OVER.get((g, m.group(1).strip()), DEFAULT[m.group(2)])), s)
    for a, b in WORDS.items():
        s = re.sub(a, b, s, flags=re.I)
    open(f, "w").write(s)
    print(g, sorted(set(re.findall(r'Part\([^,]+, "(\w+)"', s))))
