# Armory round 2: fresh-eyes review (2026-10-15 night)

Reviewer: a different agent from the builder. Studio 8ef4e21a only; nothing saved. Captures: `out/polish/armory/rv2_*.png`
(the 8 standard cameras of `tools/polish_armory_capture.py`), contact sheet `out/polish/armory/rv2_contact.jpg`.

## Logic (all pass, so no fix script)
- `check_polish_armory`: 0 clips (186 probes), 20 slots ok, 0 joints in weapons, 0 baked weapon meshes visible, 0 new lights,
  10 shadow casters, hooks GunWall_Kit / Armory_Dais (OpenPanel=Kit, enabled), NPC_Supply OpenPanel=Shop, FeaturedScissors Spin 25.
- `check_rooms2`: FAILS 0 (FeaturedScissors vs dais 12 spin poses: 0 hits; both NPCs stand on their plates).
- Play walk: hub -> doorway (0,-74) -> west niches (-26,-92) -> gun-wall front (-2,-105) -> east niches (25.2,-96.3): all reached.
  FeaturedScissors turned 24.9 deg/s with the rifle on the axis (pivot 0.21 off in z, no visible wobble). 67 enabled lights in Play
  (unchanged). Console: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154 texture, UIBlox warnings).

## Findings, prioritised (taste; none is a bug)
1. **The featured weapon is lost on its dais.** One placeholder rifle (MaxLength 5.9) over a ~9-stud dais, and the dark-olive crate stack
   directly behind it at the same height swallows its silhouette from the entrance and dais cameras. Move or lower the crates behind
   the dais (`A_Props` cluster at about (-10,-102)) or raise MaxLength to ~7 and lift the slot 0.5; RIVALS keeps a clean dark backdrop
   behind its featured item.
2. **The olive wall band dominates.** The full-height lime-olive band (138,156,74 under neutral light renders yellow-green) runs round
   the whole room at eye level and is the loudest thing in every capture. The identity says olive racks and sage glow as accents.
   Dark olive (107,122,58) or a thinner band would let the weapons lead.
3. **Gun-wall rifles rest on their magazines.** `Align = Bottom` puts the lowest point (the magazine) on the rail, so each receiver
   hangs ~0.6 above the rail with no visible support. Two small pegs under the receiver (as in the niches) or a `RestOn = "Receiver"`
   option in `Apply()` would read as hung, not floating.
4. **Baked peg bosses on the gun-wall plate.** Grey bolt heads from the old baked guns are part of `A_GunWall__wall_plate` and sit
   between the new rifles at (-3.7,9.1), (-5.7,7.9), (-6.1,7.9), (-14.3,5.0) (identified by camera ray). Small; could be covered by the
   peg hardware of point 3.
5. **High lockers read as black vents.** The round-1 bays now carry `LOCKER W-0n` plates, but from the floor the louvred panels read as
   dark vents with lime frames. Fine, but they repeat the lime of point 2 eight more times.
6. The supply-clerk tag (3.6 x 0.72 studs) is now correctly under the SUPPLY sign; no clipped letters.

## Swap-readiness
Re-checked: 20 slots, config module present, `Apply()` documented and tested by the builder (Sniper / Pistol round trip). Nothing new.
