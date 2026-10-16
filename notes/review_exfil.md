# Exfil (outdoor sky edge): fresh-eyes review (2026-10-16 night)

Reviewer: a different agent from the builder. Studio 8ef4e21a only; nothing saved. Captures: `out/polish/exfil/rv_*.png` (the 8
cameras of `tools/polish_exfil_capture.py`), contact sheets `out/polish/exfil/rv_contact.jpg` (tunnel, hangar, mouth, pad) and
`rv_contact2.jpg` (padS, edge, cutcam, high), Play frames `rv_play_edge` / `rv_play_training` (MCP tool-results only).

## Logic (all pass, so no fix script)
- `check_polish_exfil`: 0 clips (142 probes, 144 parts), support bad 0, hooks unchanged (ExfilBarrier tag + CanTouch at
  (127.5, 6.45, 0), HatchPoint / CabinPoint, Heli Mast / TailHub / TailAxis + 6 rotor parts, L_Hangar / L_Pad RoomLight Exfil,
  X_Clip collides), 0 new lights (99 enabled in Edit), ExfilFX camera path 0 hits, heli lift sweep 0 overlaps, 6 routes clear.
  Its "hangar respawn: solid parts in body box 9" line is bounding boxes of merged `E_Props` / `E_Piers` / `E_Walls` meshes (box
  query, lesson 7.7k); the ray down from (112, 6, 0) lands on `E_Floor__floor_insert` at 0.03 and the spot is clear.
- Play walk: hub -> tunnel (96, 2) -> hangar -> (120, -18) -> pad (147, -18) -> open edge (148.9, 3.0, 9.1): all reached.
- Cutscene (once): camera Scriptable at once, player lifted with the heli (155, 13.7, 0.4 mid-lift), then `InTraining` = true at
  (9.9, 603.1, 9.9); Training HUD, LEAVE [M] and the over-shoulder camera came up normally.
- Console in Play: baseline only (MatchmakingManager MemoryStore, UIBlox FoundationProvider warnings, ProfileService offline,
  AssetCheck 1/1154 texture).
- Amber reads amber (not lime, not yellow) on the bands, kerb Neon and EXFIL board; the runway studs, KEEP CLEAR / DECK EDGE
  stencils and tie-downs read from the hangar. The room is clearly different from the cream Shop, gunmetal Armory and charcoal Duels.

## Findings, prioritised (taste or design; none is a clear bug)
1. **Walking back from the pad to the hangar can launch the cutscene.** The barrier spans z -12..12 at x 127.5 and fires from
   either side. A character_navigation from the pad (131, -16) to the hangar (124, -5) cut through its south end and took me to
   Training. This is how the original worked (no change by the polish), but a player who has looked round the pad and walks
   back to the hub down the middle gets exfilled. Options for Edward: fire only when moving +X (ExfilFX checks
   `root.AssemblyLinearVelocity.X > 0`, or position x < 127.5 on touch), or a floor cue on the pad side ("EXFIL ZONE" facing west).
2. **The windsock is too big and sits on the edge walk.** At the open edge in Play the amber/cream sock fills the top of the
   view, and the five chunky segments read as a striped drum. Slimmer segments (taper to ~0.5 of the mouth) and the mast moved
   into the north-east corner (behind the kerb line) would keep it as a landmark, out of the way.
3. **Blank cream label plates on the hangar container** (`IndustrialProps.F_Container20__label_cream`, a features-kit prop): two
   white rectangles with nothing on them read as missing stickers next to the stencilled dolly crates. A SurfaceGui stencil
   ("SKY BASE · CARGO 20 / TARE 2200") would finish it.
4. **Greens go lime in the daylight room**: the container (`container_olive` 88,98,58 Metal) and the pod-band ends visible at the
   top corners of the tunnel view are the most saturated things in the hangar. Use the measured-ratio method (lesson 7.7i) or
   Plastic on the container; the tunnel ends belong to the hub pass.
5. **TimesSquare towers** fill the east sky from the pad (cream/black slabs). Left as they are: Edward's decision.

## Not touched
Nothing changed in Exfil.
