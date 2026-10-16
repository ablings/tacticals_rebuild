# Exfil helicopter: real reference (UH-60 Black Hawk class) and the stud scale

Reference type: **Sikorsky UH-60 Black Hawk** layout (twin-engine military utility helicopter; fits a sky military base, and the cutscene
"jump in through the open cabin door" is exactly how a Black Hawk is boarded). Only public dimensions and layout facts were used; the
model is own geometry and the reference drawings on the sheet are own line drawings from these numbers (no photos copied).

## Real dimensions (published figures)
| Item | Real | Source |
|---|---|---|
| Fuselage length (nose to tail) | 15.26 m (50 ft 1 in) | migflug.com, airvectors.net |
| Length with rotors turning | 19.76 m (64 ft 10 in) | airvectors.net |
| Fuselage width | 2.36 m (7 ft 9 in) | migflug.com |
| Main rotor diameter | 16.36 m (53 ft 8 in), 4 blades, swept-back tips | migflug.com |
| Tail rotor diameter | 3.35 m (11 ft), 4 blades on crossed beams, **canted 20 deg**, on the **starboard** side of the pylon | migflug.com |
| Height to the rotor head | 3.76 m (12 ft 4 in) | airvectors.net |
| Overall height (top of the tail rotor) | 5.13 m (16 ft 10 in) | airvectors.net |
| Wheel track / wheelbase | 2.70 m / 8.83 m (UH-60J figures; US airframe similar) | armsnet mirror (treat as approximate) |
| Cabin door opening (known layout values, approximate) | ~1.75 m wide x 1.37 m high, sliding aft | general reference |

Layout facts modelled: blunt nose with a two-pane windscreen and eyebrow windows, cockpit doors with large windows and small lower
windows, a gunner window each side between the cockpit door and the cabin door, large **sliding** cabin doors (port one open, slid aft
on its rails), flat-sided cabin with rounded roof shoulders, a long tapering tail cone rising to a **swept tail pylon**, the tail rotor
on the starboard side canted 20 deg, a **horizontal stabilator** at the foot of the pylon below the tail rotor disc, **fixed main wheels**
on short stubs just forward of the cabin door, a tail wheel under the tail cone, two **engine nacelles** either side of the main
transmission fairing on the roof with **exhausts angled outward-aft**, a short mast with an elastomeric hub and a bifilar absorber on
top, upper and lower **wire-strike cutters**, blade antennas, steps, red (port) / green (starboard) position lights and anti-collision
beacons on the pylon top and the belly.

Ratios that drive the silhouette (real): rotor diameter / fuselage length 1.07; fuselage length / width 6.5; mast at ~0.3-0.35 of the
fuselage from the nose; tail rotor hub at ~0.95; rotor head height / fuselage width 1.6; tail rotor top is the highest point.

## Stud scale (what the pad allows) and what was changed
Fixed by the hooks and the pad: mast at (133, 0) (attribute `Mast`), rotor plane at y ~10.2, CabinPoint (132.4, 4.2, 0.4) with a
standing R15 (feet ~1.2, head ~6.4), old footprint z -14..23, x 119..147, pad walls z +-26, clip x 151.4.

| Axis | Scale | Result |
|---|---|---|
| Length (z) | **2.29 studs/m** | fuselage 31.5 studs (nose z -12.95 .. tail pylon z 22.75) |
| Height (y) | **2.74 studs/m** | rotor head at 10.3 above the pad (real 3.76 m), tail rotor top 12.9 (real 5.13 m) |
| Width (x) | **3.05 studs/m** | fuselage 7.2 wide (real 2.36 m) |

Changes from true proportions, all forced by the player:
1. **Cross-section ~1.3x fuller than true** (width and cabin height): an R15 must stand in the cabin (5.35 clear, real cabin 1.37 m
   would be 3.1 studs at the length scale). This is the usual stylised-military look (chunky, readable) and matches RIVALS' chunky props.
2. **Cabin door 5.2 wide x 5.1 high** (real 1.75 x 1.37 m, ratio 1.3:1) so the jump-in reads; still slid aft on its rails.
3. **Main rotor 31 studs** (r 15.5) instead of 37.5 at the length scale (0.83x): r 16 grazed the EXFIL sign board during the lift
   (the lift rolls the disc up on the hangar side); r 15.5 is 6.7 studs clear of the ExfilFX camera (22.2 from the mast in plan) and
   1.5 clear of the tail rotor in plan.
4. Tail rotor r 3.6 (true at the length scale: 3.84), hub 1.7 out from the pylon (real ~1.0 m equivalent) so the canted disc clears the fin.
5. Tail cone a little shorter and the cabin a little longer than true: the constant cabin section runs z -7.3..7.0 so the open door leaf
   (slid aft, z 3.15..8.35) still sits on full-width fuselage.
6. Stabilator chord moved 0.8 forward of the pylon trailing edge (z 19.7..21.45) so its port tip clears the crate stack at the north
   wall (x 127.7-130.5, z >= 21.6).
