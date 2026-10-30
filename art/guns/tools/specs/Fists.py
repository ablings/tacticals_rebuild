# Fists: padded fingerless hand wraps for both blocky hands: grey wrap shell with three wrap grooves, near-black knuckle
# pad + wrist strap. Frame = the right grip point (Roblox RightGripAttachment): the arm runs back along -f, the knuckles
# face +z (the character's front at rest). The left pair sits 3 studs to the left and follows Hand.L in Blender.
NAME = "Fists"
ORIGIN = (0.0, 0.0)
SHEET_VIEW = "persp"
FOLLOW = {"LeftWrap": "Hand.L"}


def wrap(x0):
    grooves = []
    for f in (-0.40, -0.28, -0.16):
        grooves += [B(f, f + 0.035, 0.515, 0.6, 1.2, x=x0), B(f, f + 0.035, -0.6, -0.515, 1.2, x=x0),
                    B(f, f + 0.035, -0.6, 0.6, 0.1, x=x0 + 0.565), B(f, f + 0.035, -0.6, 0.6, 0.1, x=x0 - 0.565)]
    return B(-0.55, 0.03, -0.53, 0.53, 1.06, x=x0, cut=grooves)


def pad(x0):
    return [B(-0.30, 0.0, 0.50, 0.59, 0.86, x=x0), B(-0.56, -0.44, -0.555, 0.555, 1.11, x=x0)]


PARTS = [
    Part("RightWrap", "MidGrey", [wrap(0.0)], wrap="A", note="right hand wrap (static on the right grip)"),
    Part("RightPad", "Polymer", pad(0.0), parent="RightWrap", wrap="B", note="knuckle pad + wrist strap"),
    Part("LeftWrap", "MidGrey", [wrap(-3.0)], pivot=(0.0, 0.0, -3.0), motion="follows the left hand (weld to the left arm's grip point)",
         wrap="A", explode=(0, 0, -0.3), note="left hand wrap"),
    Part("LeftPad", "Polymer", pad(-3.0), parent="LeftWrap", wrap="B"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "RightKnuckles": ("RightPad", (-0.15, 0.6)), "LeftKnuckles": ("LeftPad", (-0.15, 0.6, -3.0))}
