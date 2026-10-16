# Overnight polish: morning report for Edward (2026-10-16)

All work is in the local copy `Tacticals_rebuild.rbxl`. Nothing was published. Every change is an idempotent fix script in `fix/`
with an UNDO flag. **Everything, including the final pass, is saved (03:03) and committed.** Studio is in Edit mode.

**All rooms side by side:** `out/polish/lobby_rooms.jpg` (one capture per room from its main entrance, at player height, in Play).

## What each room became
| Room | Identity | Sheet |
|---|---|---|
| Hub | Command deck. Warm hall, olive bands, insignia banners, sun shafts onto the spawn disc, a coloured bar under each exit sign. | `out/polish/hub/sheet.jpg`, `out/polish/olive.jpg` |
| N/S gates | Airlock bulkheads. Near-black ribbed walls, cool strips, GO/STOP lights, hazard sills, each framing its destination. | `out/polish/gates/sheet.jpg` |
| Outfitters (Shop) | Warm cosmetic boutique. Camo mannequins, headgear walls, dog-tag cases, a spotlit featured stage, a checkout counter. No guns. | `out/polish/shop/sheet3.jpg` |
| Armory | Cool gunmetal vault. 20 swap-ready weapon slots (placeholder rifles), eye-level pegboard niches, the dais spotlit. | `out/polish/armory/sheet3.jpg` (+ `sheet2.jpg`), swap guide `notes/armory_weapon_slots.md` |
| Duels | Arena deck. Dark room, light cones on bright pads, cream vs olive team frames, mode plates, ARENA DECK board. | `out/polish/duels/sheet2.jpg` |
| Exfil | Outdoor sky edge. Amber hazard bands, runway studs, windsock, cargo dolly, fuel-drum truck, stencilled container. | `out/polish/exfil/sheet.jpg` |
| Training | Your grid range, touched up: quadrant codes A olive / B cream / C sage / D warm grey, sector letters, bin frames. | `out/polish/training/sheet.jpg` |
| Showroom | Photo studio seen through the Kit camera: cream cyclorama, soft key, rim and background light. | `out/polish/showroom/sheet.jpg` |
| Final pass | Olive Neon made olive (it read lime), smaller and dimmer hub hologram rings, 15 useless lights off, Duels doorway streaks fixed. | `out/polish/final/sheet_fixes.jpg`, `notes/polish_final.md` |

Every room reads as itself. The closest pair is **Outfitters vs Armory**. They share the same shell: a beamed ceiling, the
eye-level olive band and the white floor lines. Light temperature and props are what separate them.

## Logic status
- **Final Play lap** (character at player height): spawn, Outfitters, Armory, Duels (stairs, a pad queued, west deck), Exfil
  (hangar, pad edge, cutscene to Training), Training (all 4 quadrants, a bin to Sniper, dummies) and back. Nothing was blocked,
  floating or clipping.
- **Checks:** every check passes: check_hub1, rooms2, rooms3, training, and all eight check_polish_* (0 clips, routes clear, hooks
  intact). The console shows only the known baseline (MatchmakingManager MemoryStore, UIBlox warnings, AssetCheck 1/1154).
- **Lights:** none were added all night. In Edit, 99 were enabled and now 84. In Play at the hub, 59 and now 44.

## Decisions for you
1. **Ad board DevProductId:** `AdBoard.DevProductId = 0`, so the board shows COMING SOON. Give a product id to turn on rewarded ads
   (`notes/features_done.md`).
2. **Crate colour:** crates are now dark olive (78,82,46 in the Armory, 104,88,40 elsewhere). The other option is RIVALS' crate
   green (65,94,56).
3. **(Done 2026-10-16: replaced by a sky-base backdrop, `notes/backdrop_sky.md`.)** TimesSquare towers: from the Exfil pad they fill the whole east sky. Set `HIDE_TIMESSQUARE = true` in `fix/polish_exfil.lua`
   and re-run to hide them (UNDO-able). The sheet shows the pad both ways.
4. **Queue-pad Holo beam bug** (from before the polish): the 6 pad Holo beams render outside the Duels hall, because their
   Attachments hold world coordinates as local offsets. The fix is in `notes/particles.md`. Not done because it is your FX.
5. **Exfil barrier fires from both sides:** walking back from the pad to the hangar through it also starts the cutscene.
   Options: fire only when moving +X, or add an EXFIL ZONE floor cue.
6. **(Done 2026-10-16: no NPC or world prompt opens a panel now, `notes/npc_dialogue_only.md`.)** Outfitter NPC opens Kit, not Shop. `NPC_Quartermaster` (in the Shop) opens Kit and `NPC_Supply` (in the Armory) opens Shop.
   They look swapped. Their names and dialogue were updated, but the panel each one opens was not changed.
7. **Rename "SUPPLY CLERK"?** The Armory NPC's tag repeats the SUPPLY sign above it. ARMORER would name the role.
8. **Pistol slot in the Armory glass case:** the case is too shallow for a rifle. Should a 21st slot (a pistol) go there?
9. **Placeholder weapons:** all 20 Armory slots hold the same placeholder rifle. Pick the real weapons; it takes one edit per slot.
10. **Disc-centre brightness:** the spawn disc centre (and the Duels aisle disc) is the brightest olive in its room. Dim it
    (disc 80,86,32) if it reads too strong.
11. **Training B: cream or dark olive?** Cream is the quietest of the four codes on white walls. Dark olive (107,122,58) would be louder.
12. **Light budget:** the hub lights are not RoomLight-tagged, so they stay on everywhere (63 enabled with the camera in Training,
    against the ~45 in the RoomFX comment). Switching them off by area needs a small RoomFX code change.
13. **The olive wall band dominates the Armory** (and the Shop): it is the loudest thing at eye level. A darker band in the Armory
    would let the weapons lead and separate it more from the Outfitters.
14. **Lighting:** `Lighting.Technology` is Future (4) in the saved file (checked with `tools/read_technology.py`; scripts can't
    read it, which is why the lap agent thought it was still ShadowMap). There are two Sky objects (`Sky`, `Lobby_Sky`); pick one.
15. **Small gameplay notes from the lap:** the Outfitters featured stage is walkable (players can stand on the turntable). In
    Training, F is both the bin prompt and Quick Melee. At the Exfil pad edge, players can step onto the pad-wall trim (the clip
    wall still holds).
16. **Taste items still open** (reviews in `notes/review_*.md`): the featured rifle is lost against the crates behind the dais,
    the gate status lights are small, the hazard sills are busy at the hub end, and the windsock is static.

## Re-run order if Studio crashes (all `python tools/run_luau.py fix/<script>`, from tacticals_rebuild)
The place file has everything, including `polish_final` (saved 03:03).
From a pre-polish file, run in this order:
1. `polish_shop.lua`, then `polish_shop3.lua` (re-running polish_shop rebuilds Polish.Shop and drops Round3)
2. `polish_armory.lua`, then `polish_armory2.lua`, then `polish_armory3.lua`
3. `polish_duels.lua`, then `polish_duels2.lua`
4. `polish_exfil.lua`, then `polish_exfil2.lua`
5. `polish_gates.lua`, then `polish_gates2.lua`
6. `polish_olive.lua`, then `polish_hub.lua` (olive first; UNDO in reverse: hub, then olive)
7. `polish_training.lua`
8. `polish_showroom.lua`
9. `polish_final.lua` (**always last**: re-running polish_olive resets the olive Neon)
10. `no_panel_prompts.lua` (2026-10-16: dialogue-only NPCs, counter / gun-wall / dais prompts hidden; independent of the polish scripts)
11. `backdrop_sky.lua` (2026-10-16: TimesSquare hidden + sky-base backdrop; leave `HIDE_TIMESSQUARE = false` in polish_exfil)
12. `place_heli.lua` (2026-10-16: UH-60-class exfil helicopter kit; only after `kit/heli.fbx` has been imported, see `notes/heli_kit.md`;
    then `check_heli.lua`. Independent of the polish scripts; it never touches Exfil / Polish parts)
13. `exfil_lift.lua` (2026-10-16: new ExfilFX lift path for the UH-60 kit, marked `-- [EXFIL]`; backup `_RebuildRemoved.ExfilFX_Orig`;
    after place_heli, then `check_heli.lua` must say RESULT fails 0. Edits only the ExfilFX script, never map parts)

To undo, run the same scripts with `UNDO` in reverse order.
