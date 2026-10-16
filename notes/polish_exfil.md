# Overnight polish: Exfil hangar + helipad (the outdoor sky edge)

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS (2e616d06) was
only read (two outdoor-edge captures by the range hills). No computer use, no imports, no RIVALS ids. Parts, SurfaceGuis and our
own `TX_hazard_stripe` texture only.

| What | Path |
|---|---|
| Polish script (idempotent, UNDO flag, optional `HIDE_TIMESSQUARE`) | `fix/polish_exfil.lua` -> `python tools/run_luau.py fix/polish_exfil.lua [UNDO]` |
| Check (clips, support, hooks, ExfilFX camera + heli lift sweep, walk routes; read-only) | `fix/check_polish_exfil.lua` |
| Captures (8 cameras incl. the ExfilFX cutscene camera) | `python tools/polish_exfil_capture.py <prefix> [names]`, `... ref <name> x,y,z lx,ly,lz` |
| Sheet | `python tools/polish_exfil_sheet.py` -> **`out/polish/exfil/sheet.jpg`** (BEFORE / AFTER / more / no-TimesSquare option / RIVALS) |

## Identity
The base's **outdoor sky edge**: daylight, wind, runway gear. **Amber + cream** accents (the only amber room): the Shop is cream and
warm, the Armory gunmetal, the Duels deck charcoal with team pads, the hub olive. RIVALS method (its outdoor edge by the range): open
bright sky, a landmark mast with a red light, very few props, the view is the feature.

## What changed
1. **Accents** (10 property records, originals in `PolishExfil_Orig`): the olive bands of `E_Walls / E_Piers / E_Portal / E_Mouth /
   E_PadWalls / E_Gear` -> amber hazard paint 212,122,42 (renders 160-188, 111-130, 46-53: amber, not lime or yellow; the first try
   196,134,50 rendered ochre-yellow, so G was pulled down by the measured ratio). Olive Neon on the open-edge kerb line, the EXFIL board
   outline and the mast strips -> amber Neon 190,108,26. `Exfil.L_Hangar` light 222,228,196 (green cast) -> daylight 255,246,232.
2. **Runway lights** (`Polish.Exfil.RunwayLights`, 36 studs, Neon only, no Light instances): along the open edge inside the kerb (x 150.25),
   along both pad side walls (z +-25.7) and lead-in studs along the tunnel lane (z +-9.7) from the hub. Each stud is placed only where the
   footprint is clear floor (ray grid).
3. **Windsock** (`Windsock`): 10-stud mast at (149.4, 18.5) with amber/near-black foot bands, an amber obstruction lamp, swivel arm, and a
   five-segment amber/cream fabric sock streaming south (wind from the north), drooping. Clear of the rotor disc, the tail and the lift sweep.
4. **Hazard markings** (`Hazard`): amber/near-black hazard band inside the open edge (x 148.55-149.25, z -21..21), deck stencils
   "ROTOR AREA · KEEP CLEAR" (south route, x 130.6) and "DECK EDGE · NO STEP" (amber, x 147.4), both read from the hangar; 5 tie-down eyes
   round the H (one dropped where the skid stands).
5. **Ground gear** (`GroundGear`): a cargo dolly with two strapped dark-olive crates ("EXFIL · 04"), hazard side rails and a tow bar at
   (133.2, -23.1) beside the south route (route stays 6+ wide), and a fuel-drum hand truck against the north wall at (132.6, 22.3).
   Dolly deck/crates and truck plate/drums collide (8 parts).

144 new parts, 0 new lights, enabled lights 99 in Edit (unchanged). Nothing under `Exfil`, `Heli`, `FX2` or `Rooms3.X_Clip` was touched.

## Logic checks
- `check_polish_exfil`: **0 clips** (142 probes; floor-contact probes of flat studs on the floor meshes' collision hulls are counted as contact;
  the first runs found the drum truck under the tail walk line and a wheel in the north crate: moved). Support bad 0.
  Hooks: ExfilBarrier tag + CanTouch at (127.5, 6.45, 0) size 0.3 x 13.2 x 24 unchanged, HatchPoint / CabinPoint unchanged, Heli Mast /
  TailHub / TailAxis + 6 rotor parts, 0 polish attributes inside Heli, L_Hangar / L_Pad RoomLight Room=Exfil, X_Clip collides.
  **ExfilFX camera path** (start shot + lift e 0..2.6, +3/-2) hits on new parts: 0. **Heli lift sweep** (ExfilFX's own transform on clones)
  overlaps with new parts: 0. Walk routes (block cast 2 x 4.5 x 2, collidable): hub -> tunnel -> hangar respawn, hangar -> barrier face,
  hangar -> pad round the barrier (z -18), open edge south -> north, pad north side (z 16), pad -> hub: all clear.
- `check_rooms2` FAILS 0, `check_rooms3` FAILS 0 (tunnel end 17.93, hangar mouth 16.92, barrier reachable at z -10..10), `check_hub1` hooks
  ok / nothing new flagged, `check_training` ALL OK.
- **Play walk**: hub -> tunnel -> hangar (111.2, 3.0, -4.1) -> (120, -18) -> pad (147, -18) -> open edge (149.2, 3.0, 11.2). Pushing off the
  edge: stopped at x 151.4 by the invisible clip wall (the player can hop onto the kerb, as before). **Cutscene**: walking into the
  barrier switched the camera to Scriptable in 0.2 s, the lift camera ran (120.0, 14.2, -24.4 mid-lift), `InTraining` = true and the player
  landed in Training at (-12.9, 603.1, 5.4).
- Console in Play: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154, UIBlox warnings, ProfileService offline).
- UNDO round trip: restored 10 instances, removed Polish.Exfil; re-applied: 144 parts, 10 records.

## For the lead / Edward
- **TimesSquare towers (open question, lap1 R1):** from the pad the cream/black TimesSquare blocks fill the whole east sky. The sheet's
  "no TimesSq." row shows the pad with them hidden: open sea and sky, which is the Exfil identity. Set `HIDE_TIMESSQUARE = true` in
  `fix/polish_exfil.lua` and re-run to hide them UNDO-ably (only CityBillboard FX use them). Not done: Edward's call.
- The windsock is static (no script). A slow sway could be added to LobbyFX later; it is purpose-bound, not an ambient particle.
- Queued for import: nothing.

## Round 2 (small fixes from notes/review_exfil.md, 2026-10-16 night): `fix/polish_exfil2.lua`
Re-run order: polish_exfil.lua -> polish_exfil2.lua (polish_exfil rebuilds Polish.Exfil, Round2 lives inside it).
- **Windsock**: the round-1 sock (10-stud mast, 1.3-stud sock on the open-edge walk at (149.4, 18.5)) is hidden (`PolishExfil2_Orig`)
  and rebuilt in `Polish.Exfil.Round2.Windsock` on the kerb behind the edge rail and the clip wall (152.25, 1.4, 24.8): 7-stud mast,
  sock 0.75 tapering to 0.38 in five 0.62 segments, streaming south over the kerb. Out of reach (players stop at x 151.4) and out of
  the edge view; still reads as the corner landmark next to the red beacon post. Captures `out/polish/exfil/x2_edge.png`, `x2_padview.png`.
- **Container labels**: the label MeshPart's query hull is its bounding box (rays "hit" a 10 x 1.6 plate that isn't there), so the two
  visible plates were measured from captures: north 3.8 x 0.7 (x 115..119, y 5.62..6.32), west end 0.8 x 0.8 (z 14.8..15.63,
  y 4.73..5.51). Near-black text on the plates (TCU 204117 22G1; 22G1 / C20) and warm-grey painted markings on the skin (SKY BASE
  LOGISTICS, MAX GROSS / TARE / NET, TCU 204117 on the doors). Captures `x2_north.png`, `x2_west.png`.
- `check_polish_exfil` after: 0 clips (160 parts), support 0, hooks unchanged, ExfilFX camera path 0 hits, lift sweep 0, 6 routes clear,
  new collidable 8 (the old mast's 2 off, the new mast's 2 on). UNDO round trip: 15 restored, Round2 removed; re-applied identically.
- **Left for Edward: the barrier fires from both sides.** Walking back from the pad to the hangar through `ExfilBarrier` (x 127.5,
  z -12..12) launches the cutscene. Options: ExfilFX fires only when the character moves +X (`root.AssemblyLinearVelocity.X > 0`)
  or was west of the barrier on touch; or an "EXFIL ZONE" floor cue facing the pad. Not changed (it is game code / design).
