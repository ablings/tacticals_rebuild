# Armory review (fresh eyes, 2026-10-15 night)

Reviewer: a different agent from the Armory builder. Studio 8ef4e21a only; captures after `tools/show_studio.ps1 tacticals`
(`python tools/polish_armory_capture.py rev`, one warm-up frame first). No taste edits; no clear bug was found, so there is no
Armory fix script from this review.

Captures (edit-time, Future): `out/polish/armory/rev_entry.png`, `rev_gate.png`, `rev_dais.png`, `rev_gunwall.png`, `rev_west.png`,
`rev_east.png`, `rev_sw_corner.png`, `rev_se_corner.png`; contact sheet `out/polish/armory/rev_contact.jpg`.

## Logic checklist
| Check | Result |
|---|---|
| Walk in Play (character_navigation, x3 speed) | hub -> doorway (0,-74) -> gun-wall front (-1.9,-104.7) -> west back (-22,-100) -> NPC/counter side (7,-104) -> east benches (22.5,-82.6) -> hub (0,-30): all reached, no blockers. |
| Clipping / support | `check_polish_armory`: 0 clips (97 probes). Bays W02/W03/E02/E03 rest on `A_Lights__trim_metal` (1.65 proud of the wall) rather than the wall body: intended (the bay sits on the most proud hit), no gap visible. Crate-on-crate "NOTHING" is the check excluding Polish parts. |
| Lights | 0 new lights; 67 enabled in Play (same as before the pass; lobby budget comment ~45 is a lobby-wide issue). 9 shadow casters. Every light has a visible fixture. |
| Signs face arrivals | ARMORY, SUPPLY, floor stencils (WEAPONS BAY S-2, CLEAR ALL WEAPONS...) all read from the doorway. |
| Hooks | GunWall_Kit and Armory_Dais OpenPanel=Kit enabled; NPC_Supply OpenPanel=Shop (pre-existing swap, Edward's call); FeaturedScissors Spin=25; 5 RoomLight Armory hosts. Prompts seen in Play near the dais: Armory_Dais, GunWall_Kit, NPC_Supply Talk, AdBoard Watch ad. |
| Console in Play | baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154 texture failure, UIBlox FoundationProvider warnings). |

## Prioritised list (taste; recommend, not acted on)
1. **The envelope reads navy, not gunmetal.** Sampled on rev_entry: floor 29,45,62, wall 46,65,70, ceiling 45,59,74, gun wall 51,69,86
   (blue roughly 2x red) although the part colours are near-neutral (floor 48,50,53). Metal/TacMetal picks up the blue sky
   specular, exactly the Shop round-2 "cold ceiling" problem. Fix: ceiling and upper walls to Plastic (or a matte metal variant), and
   pull the blue channel of the walls 4-8 below red/green so the room lands on cool *grey* metal; check by sampling the same boxes.
2. **Weapon bays sit at 10-15 studs.** From the floor they read as small dark posters with tiny guns (rev_dais, rev_east); RIVALS
   shows weapons at eye level on dark pegboard. Recommend (next Armory round): replace the two rack units per side wall with
   eye-level pegboard niches (centre ~5-6 studs), guns at 1.3-1.5x their current scale, each niche with its own cool strip; keep
   the high bays only if they still read, or turn them into stencilled ammo-locker doors.
3. **Gun wall reads empty.** A large slotted grid with small grey guns spread thinly (rev_gunwall); the two floor up-lights draw
   more attention than the guns. Fewer, larger weapons grouped in the centre third, lit by the existing L_GunWall, would make it
   the room's backdrop.
4. **The hero dais shows red scissors** (`FeaturedScissors`, a hook with Spin=25). The hardest light in the room lands on a joke
   prop, the only red in the room. Swap the model's contents for a featured rifle while keeping the model name and `Spin` attribute.
5. **SUPPLY CLERK tag hangs under the SUPPLY sign** (rev_entry, rev_east): two labels saying the same thing stacked, and the tag
   loses a letter ("SU PLY CLERK") from the entrance (3D-depth-tested BillboardGui; same artefact as QUARTERMASTER in the Shop).
   Drop the tag text to the role ("ARMORER") or raise/offset the tag clear of the sign; the sign alone already names the counter.
6. **Saturated kelly-green crates** (AmmoStock F_Crate4A and the older green crates by the east wall) read toy-green against the cool
   room. Recolour toward RIVALS' NosCrate 65,94,56 or dark olive 107,122,58.
7. Minor: ceiling Neon strips are dense and pure white; with item 1 fixed the room may read better with them a step down
   (206,222,240 -> ~180,192,205) so the sage rack glow and the dais key stay the brightest things.
8. Minor: the gate approach (rev_gate) shows the corridor with a bright warm-grey wall face either side of the gunmetal room;
   the gate-corridor pass should carry the gunmetal (noted by the builder too).

## Weapons are placeholders (Edward): swap-readiness of the slots
Edward has not picked the weapons yet, so the featured scissors and every gun are placeholders; items 3-4 above are about the
*presentation* (size, grouping, light), not which weapon is shown. How easy each slot is to swap (read 2026-10-15):

| Where | Structure | Swap-ready? |
|---|---|---|
| 8 weapon bays (`Polish.Armory.WeaponBays.BayW01..E04`) | each bay Model holds its frame parts, two named gun Models (`Gun_Sniper` / `Gun_AutoRifle` / `Gun_SemiAuto`) and two `Peg` parts per gun | **Mostly.** Each gun is its own Model, anchored, **0 welds/constraints**. But: no PrimaryPart and no anchor marker (the pivot is the bounding-box centre, e.g. BayW01 sniper at -29.93,13.75,-72.13), the slot isn't named by position (Gun_* names are the weapon, not the slot), the pegs are loose siblings, and the gun is scaled/flipped per bay inside `polish_armory.lua` (a new weapon needs that fit logic again). Fix for the swap pass: wrap each gun in `Slot_W01_A/B` with an invisible `Anchor` part (CFrame = mount point, attribute `MaxLength`), and have one helper fit any model to an anchor. |
| Featured dais (`Rooms.Armory.FeaturedScissors`, hook, Spin=25) | Model, 10 descendants, no PrimaryPart, 0 welds, pivot (-10,3.4,-96) | **Yes, by contents:** RoomFX spins any Model with `Spin` about its pivot, so a new weapon can replace the children (keep the Model name/attribute) with its pivot set to the dais axis. Add an `Anchor` part for the height. |
| Gun wall, the two rack units per side, the bench guns, the display cases | baked into the merged per-material Rooms2 meshes (`A_GunWall__case_dark/drum_olive/...`, `A_Racks`, `A_Benches`, `A_Displays`) | **No.** The guns are triangles inside shared material meshes with the racks/tables; they can't be swapped one by one. Hide those meshes (or the gun materials) and rebuild these slots as separate Models with anchors, like the bays. |
| `Rooms.Armory.WeaponsDisplay` (12 named weapon models on 4 tables) | hidden (0 visible parts), the source the bay guns were cloned from | A ready catalogue of named weapon models; a good source for the swap helper once Edward picks. |

## Verdict
Logically sound: walkable, no clips, hooks and console at baseline, no new lights. Identity is clearly different from the Shop
(cool, dark, metal), but it currently reads "navy" rather than "gunmetal", and the weapons themselves are too small/high to be the
subject. Items 1-4 are the next Armory round.
