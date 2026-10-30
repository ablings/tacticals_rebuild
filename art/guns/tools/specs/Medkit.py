# Medkit: hard olive case carried by the handle on the lid: flat lid hinged at the back edge, two front latches, cream cross on
# the front between the latches, inside an auto-injector (with cap) and a bandage roll the hand takes out. f = case length.
NAME = "Medkit"
ORIGIN = (0.0, 0.035)
SEAM = -0.07
cross = [(-0.012, -0.33), (0.012, -0.33), (0.012, -0.292), (0.04, -0.292), (0.04, -0.268), (0.012, -0.268),
         (0.012, -0.23), (-0.012, -0.23), (-0.012, -0.268), (-0.04, -0.268), (-0.04, -0.292), (-0.012, -0.292)]
PARTS = [
    Part("Body", "Olive", [B(-0.25, 0.25, -0.40, SEAM, 0.24, cut=[B(-0.22, 0.22, -0.37, 0.0, 0.18)]),
                           B(-0.26, 0.26, -0.42, -0.38, 0.26)], wrap="A", note="case tray + base rim"),
    Part("Lid", "Olive", [B(-0.25, 0.25, SEAM - 0.002, -0.05, 0.24)], pivot=(0.0, SEAM, -0.12),
         motion="rotate about z (the case length) 110 deg up-back on its rear hinge", explode=(0, 0.18, 0), wrap="A", note="flat lid"),
    Part("Cross", "Cream", [P(cross, 0.03, x=0.12)], parent="Body", wrap="B", note="cream cross on the front"),
    Part("Handle", "Polymer", [PF([(-0.11, -0.075), (0.11, -0.075), (0.11, 0.055), (-0.11, 0.055)], -0.03, 0.03,
                                  cut=[PF([(-0.08, -0.09), (0.08, -0.09), (0.08, 0.015), (-0.08, 0.015)], -0.1, 0.1)])],
         parent="Lid", pivot=(0.0, -0.06), motion="rotate about x 90 deg to fold flat on the lid", explode=(0, 0.1, 0),
         note="carry handle across the lid, feet over the side walls"),
    Part("LatchL", "DarkSteel", [B(-0.2325, -0.1975, -0.13, -0.035, 0.03, x=0.125)], parent="Body", pivot=(-0.215, -0.13, 0.13),
         motion="rotate about z 120 deg outward-down to unlatch", explode=(0, 0, 0.12)),
    Part("LatchR", "DarkSteel", [B(0.1975, 0.2325, -0.13, -0.035, 0.03, x=0.125)], parent="Body", pivot=(0.215, -0.13, 0.13),
         motion="rotate about z 120 deg outward-down to unlatch", explode=(0, 0, 0.12)),
    Part("Injector", "Sage", [L([-0.23, -0.22, 0.06, 0.07], [0.0, 0.03, 0.03, 0.0], -0.32, x=-0.05, rot=0)], parent="Body",
         pivot=(-0.08, -0.32, -0.05), motion="the hand takes it out: free move; stab = translate along -z", explode=(0, 0.3, 0), note="auto-injector"),
    Part("InjectorCap", "Olive", [L([0.05, 0.06, 0.12, 0.13], [0.0, 0.034, 0.034, 0.0], -0.32, x=-0.05, rot=0)], parent="Injector",
         pivot=(0.09, -0.32, -0.05), motion="pull off along -z before use", explode=(0.12, 0.3, 0)),
    Part("Bandage", "Cream", [CX(0.0, -0.31, 0.045, -0.095, 0.115, seg=10)], parent="Body", pivot=(0.0, -0.31),
         motion="the hand takes it out; unroll = rotate about x", explode=(0, 0.25, 0), note="bandage roll"),
]
ATTACH = {"Grip": ("Handle", ORIGIN), "LidOpen": ("Lid", (0.0, -0.05, 0.12)), "InjectorTip": ("Injector", (-0.23, -0.32, -0.05))}
