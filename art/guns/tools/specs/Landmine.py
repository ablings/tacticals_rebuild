# Landmine: low round pressure trap: grey body, raised dark pressure plate, rotary arming switch, safety pin with ring,
# Neon indicator light on the top rim. Origin = body centre (held flat in the hand, placed on the floor).
import os
exec(open(os.path.join(os.path.dirname(__file__), "_grenade.py")).read())
NAME = "Landmine"
ORIGIN = (0.0, 0.0)
PARTS = [
    Part("Body", "MidGrey", [LZ([-0.08, -0.08, 0.04, 0.06, 0.06], [0.0, 0.30, 0.30, 0.27, 0.0], seg=16)], wrap="A", note="disc body"),
    Part("Plate", "Polymer", [LZ([0.03, 0.03, 0.10, 0.10], [0.0, 0.10, 0.10, 0.0], seg=12)], pivot=(0.0, 0.10),
         motion="translate -y 0.025 when stepped on", explode=(0, 0.15, 0), wrap="B", note="pressure plate"),
    Part("ArmSwitch", "DarkSteel", [B(0.27, 0.35, -0.03, 0.03, 0.07), C(0.34, 0.37, 0.0, 0.04, seg=8, rot=0)], pivot=(0.30, 0.0),
         motion="rotate about z (its own axis) 90 deg: safe / armed", explode=(0.15, 0, 0), note="rotary arming switch"),
    Part("SafetyPin", "Steel", [CA((0, -0.40, 0.0), (0, -0.27, 0.0), 0.012, rot=0)] + ring(-0.455, 0.0, 0.055, 0.011),
         pivot=(-0.30, 0.0), motion="translate +z (pull out backward) to arm", explode=(-0.15, 0, 0), note="pin + ring"),
    Part("Indicator", "Glow", [CZ(-0.198, 0.03, 0.075, 0.022, x=0.198, rot=0)], wrap="skip",
         note="Neon indicator: dark = safe, lit = armed; switch Color / Material"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "Trigger": ("Plate", (0.0, 0.10)), "Blast": ("Body", (0.0, 0.0))}
