# Overnight polish plan (Edward, 2026-10-15 evening)

Edward's ask: polish the lobby overnight with the RIVALS lobby as the reference. Make aesthetically pleasing changes, make **every room
look different, not the same**, and keep everything **logically sound**. Coordinate with the UI session so we don't overlap.

**Blueprint vs theme (Edward, mid-planning):** the RIVALS lobby is the *aesthetics blueprint*: how it is built, its detail density,
lighting method, material variety, line work and readability. The *theme* is ours and should set the game apart from RIVALS: a
floating sky military base in Tacticals' olive/cream. Copy RIVALS' craft, never its subject matter. Every polish choice should make
the base read more military-sky (insignia, stencils, ops screens, cargo, hangar/runway gear, sky views), not more RIVALS.

## Ground rules for the night
- Work target: `Tacticals_rebuild.rbxl`, Studio id **8ef4e21a-3525-484b-91af-79d7677aa213** (second monitor, XF243Y P).
  RIVALS reference: **2e616d06-6bfd-4b39-a751-ddccf8eb9187**, read-only, never saved. The replica window **82b89850** belongs to the UI
  session: don't touch it.
- **No computer use** while the UI session is driving the primary monitor (UG25I) for RIVALS UI capture all night. Everything goes
  through the Studio MCP (execute_luau, screen_capture, start_stop_play, character_navigation) and the Blender MCP.
- **Captures:** Studio MCP screen_capture of a minimised or covered window returns blank white. Run
  `pwsh -NoProfile -File tools/show_studio.ps1 tacticals` (or `rivals`) first. It shows that window on the second monitor with
  SWP_NOACTIVATE, so it never takes focus from the UI session.
- Saves and Import 3D need the screen. Batch them: at the end of each room, message the UI session
  (`local_f4630eda-86ab-4003-89fd-fb92f76724bc`) asking it to pause. Wait for its OK, then save, and Import 3D any queued kit FBX
  (Creator = Gunsy Funsy). Message it again when done. If there is no OK, keep working: every change is a committed, idempotent
  script and can be replayed after a Studio crash.
- Every change lives in `fix/polish_<room>.lua`. Scripts are idempotent and UNDO-able, with originals stored in attributes. Hide old
  geometry, never delete it. No RIVALS ids, meshes or code. Never add kid-friendly elements RIVALS lacks. No ambient particles.
- Builder and reviewer are different agents. After each room: captures, a ref-vs-ours sheet in `out/polish/<room>/`, a commit, the
  vault round log in `building-practice/tacticals/Tacticals Lobby Rebuild.md`, and lessons in the workflow pages.

## Screen schedule with the UI session (Edward, 22:16)
The UI session owns the screen by default. Tacticals gets windows of up to 15 minutes at **23:00, 00:30, 02:00, 03:30, 05:00 and
06:30**. The UI session stops computer use about 2 minutes before each window. I take the screen (second monitor only) to save and
Import 3D, then message "screen free", or "skip" if there's nothing to do. Edward had the UI session halt first so he could grant
the overnight computer-use permissions (Roblox Studio, Blender 5.2).

Saving when the computer-use lock is still held by the paused UI session: front the Tacticals window (AppActivate). Check the
foreground title is `...Tacticals_rebuild.rbxl - Roblox Studio`, send Ctrl+S with SendKeys (that is Save to File for a place
opened from file), then check the .rbxl modified time and that the foreground title didn't change, meaning no dialog opened.

**00:10:** the UI session finished for the night and both monitors are ours. Schedule windows are no longer needed: the lead
saves (Ctrl+S, checking Edit mode first) after each finished room. Don't touch RIVALS in the Player on the primary monitor or the
replica Studio 82b89850.

## Room identities (same RIVALS language, a different mood per room)
Shared language everywhere: near-black floors, mid-grey walls, Neon accent lines, the olive/cream palette as thin lines only. The
rooms differ by **light colour/temperature, key material, signature prop and accent ratio**:

| Room | Identity | Light | Key material / props | Accent |
|---|---|---|---|---|
| Hub (command deck) | Heart of the base: open, bright, the spawn disc as the hero | warm sun from the skylights, warm-white ceiling strips | concrete panels, olive bands, flag/insignia banners, ops screens | olive dominant, cream lines |
| N/S gate corridors | Airlock bulkheads: short, tight, transitional | cool white strips, door status lights | ribbed corrugated metal, hazard-stripe sills | near-black + cream hazard |
| Shop (UGC / cosmetic shop) | Warm boutique for avatar cosmetics (the main game already has its own shop): presented like RIVALS' UGC shop stage and market hall | warm 3000K pools, spotlit featured stage | mannequins/avatar plinths with military camo outfits, helmets, patches, dog tags; featured-item stage; screens; wood + cream | cream dominant, olive trim |
| Armory (weapons bay) | Darker gunmetal vault: cool and focused | cool 6500K rack lights, a hard spotlight on the featured weapon | dark metal, perforated rack panels, gun racks | olive racks, sage glow |
| Duels (arena deck) | Dramatic: dark room, light pools per pad, the arena feel | low ambient, strong overhead cones per pad | dark floor, team lines olive vs cream (instead of RIVALS purple/gold) | high-contrast lines |
| Exfil hangar + helipad | Outdoor sky edge: wind, runway lights | daylight, amber runway/beacon lights | hazard markings, windsock, tie-downs, fuel/cargo carts | amber + cream |
| Showroom | Clean photo studio (camera set) | soft key + rim, cyclorama | cream cyclorama, plinth | minimal |
| Training | Clinical range, grid tiles (current standard) | cool even light | grid tiles; quadrants A-D each colour-coded within the palette | per-quadrant code |

Check the room analogues in RIVALS before each room (lobby, shop counter, weapon displays, duel pads, training) and copy their
*method*: how much accent, where the light pools, and how props cluster.

## Logically sound (the checklist every room passes)
1. Walkability: every door is open, clear height is at least 10, no invisible blockers, no props blocking paths; Play-mode walk
   at player height with `character_navigation`.
2. Nothing floats or clips: props sit on floors, no z-fighting (decoration 0.03+ bigger than its wall, floor insets 0.04+ proud).
3. Every light has a visible source; no light leaks through walls; shadow-casting light count stays modest.
4. Signs and screens face the way players arrive; wayfinding matches the real room.
5. All hooks from `notes/hooks.md` still work; check_hub1 / check_rooms2 / check_rooms3 / check_training pass; no new console
   errors in Play.

**Edward 22:55:** the Shop is a UGC/cosmetic shop, not a supply store. The rounds 1-2 supply dressing (ammo, rations, price boards)
must be reworked into cosmetic displays (Shop round 3, after the Armory). Keep the warm light, ceiling and wood/cream materials.

**Edward 23:05:** the featured weapon and every weapon in the Armory (racks, bays, gun wall) are PLACEHOLDERS until he picks the real
ones. Armory round 2 makes them swap-ready: each weapon sits in a named slot Model (`WeaponSlot_<area>_<n>`) with an Attachment/anchor
pose and a `WeaponId` attribute. One config module (`ArmoryWeaponSlots`) lists slot -> model, and a short swap guide goes in
notes. Keep one consistent neutral placeholder look (e.g. the same rifle everywhere) and leave the featured-weapon hook working.

## Order
1. Shop  2. Armory (round 2 = swap-ready weapon slots, after Shop round 3)  3. Duels  4. Exfil  5. Gate corridors  6. Hub  7. Training touch-up  8. Showroom  9. Final whole-lobby lap
   (fresh agent) + a sheet of every room side by side to prove they read differently.
Open questions for Edward (don't block on them): ad DevProductId, crate colour, TimesSquare towers, queue-pad Holo beam bug.

## Progress
(append one line per finished room: time, commit, sheet path, saved yes/no)
- Shop: 22:22 fix/polish_shop.lua (warm 3000K pendants + shelf washes, cream walls/counter, wood top + shelving, boards, stock clusters, entry bins, A-frame, mat); checks pass, Play walk OK; sheet out/polish/shop/sheet.jpg (Studio captures blank: ray-render after frames, light not yet judged); saved: no. Notes: notes/polish_shop.md
- Shop round 2 (lead review): real captures via tools/show_studio.ps1; warm Plastic ceiling/beams, boards with item rows + picture lights, centre pendant removed (hid SUPPLY), pools measured +13..44; sheet rebuilt with real before/after/RIVALS; saved: no.
- Shop review (fresh agent): notes/review_shop.md; no clear bugs (0 clips, Play walk OK, hooks/console baseline), so no fix script; taste list + the cosmetic/UGC-shop rework list (Edward's correction) for a later agent.
- Armory: fix/polish_armory.lua (gunmetal envelope, cool 6500K Neon, sage rack glow, L_Dais hard featured key +16.5 levels, 8 slotted weapon bays with guns and RACK/SN stencils, floor stencils, ammo stock); 0 new lights; checks pass (check_polish_armory 0 clips, rooms2 FAILS 0, rooms3/hub1/training OK), Play walk OK, UNDO round trip OK; sheet out/polish/armory/sheet.jpg; saved: no. Notes: notes/polish_armory.md
- Armory review (fresh agent): notes/review_armory.md; logically sound (Play walk, 0 clips, hooks/console baseline), no fixes needed; taste list (reads navy not gunmetal, bays too high/small, thin gun wall, SUPPLY CLERK tag under the sign, kelly-green crates) + a weapon-slot swap-readiness table (weapons are placeholders: bay guns are separate weld-free Models but lack anchors; gun wall/racks/benches are baked into merged meshes).
- Shop round 3 (UGC/cosmetic shop): fix/polish_shop3.lua (supply dressing and every gun hidden UNDO-ably; camo-mannequin outfit walls, headgear walls, dog-tag/insignia glass cases, FEATURED/NEW DROPS screens, spotlit Spin featured stage with rope line, counter as checkout, NPC as OUTFITTER, OUTFITTERS sign, the review's taste fixes); lights net 0; checks pass (check_polish_shop 0 clips, rooms2 FAILS 0, rooms3/hub1/training OK, Play walk OK, Shop_Counter opens ShopUI2), UNDO round trip OK; sheet out/polish/shop/sheet3.jpg; saved: no. Notes: notes/polish_shop.md round 3
- Armory round 2 (swap-ready weapons): fix/polish_armory2.lua; 20 WeaponSlot_* (Featured inside FeaturedScissors, GunWall 9, RackW/E 8 eye-level pegboard niches replacing the rack units, Bench 2), config ServerStorage.ArmoryWeaponSlots + Apply(), swap guide notes/armory_weapon_slots.md; baked guns hidden; high bays -> ammo lockers; navy -> neutral gunmetal (blue-minus-red +30..46 -> 0..+9, measured); SUPPLY CLERK tag in studs; crates dark olive. Shop camo 662 -> 139 parts. Checks pass (0 clips, rooms2 FAILS 0, rooms3/hub1/training OK, Play walk OK, dais + gun-wall E open Kit), lights net 0, UNDO round trip OK; sheet out/polish/armory/sheet2.jpg; saved: no.
- Armory round-2 review (fresh agent): notes/review_armory2.md; logically sound (0 clips, rooms2 FAILS 0, Play walk, spin, console baseline), no fixes; taste list (featured rifle lost on the dais against crates, lime band dominates, gun-wall rifles rest on their magazines, baked peg bosses between them).
- Duels: fix/polish_duels.lua (arena deck: measured charcoal envelope + near-black floor, per-team pads cream vs olive with fitted panel-line insets, Neon frames, reticle emblems and glow pools, a gantry rig with 12 lamps + light shafts, mode plates, ARENA DECK board, lane lines; D_Lines hidden; PadBoards red/blue -> cream/olive); lights 102 -> 99 (Edit), 0 new; check_polish_duels 0 clips, rooms2/rooms3 FAILS 0, hub1/training OK, Play walk stairs/pads/energy wall OK, Pad_3v3_B queued (Team2Count 0->1), Duels TV + strip update, UNDO round trip OK; sheet out/polish/duels/sheet.jpg; saved: no. Notes: notes/polish_duels.md
- Duels review (fresh agent): notes/review_duels.md; logically sound (check_polish_duels 0 clips, Play walk hub -> door -> pads -> west deck -> back, console baseline), no fixes; taste list (full-cream lane lines out-shine the pads, olive frames read lime under the lamps, small mode plates / briefing text).
- Armory round 3 (small fixes): fix/polish_armory3.lua (re-run order armory -> armory2 -> armory3): dark featured backdrop behind the dais, gun-wall rifles seated via anchor/Gap + pegs (Apply() unchanged, tested), 8 old gun-support pins capped (the round dots are TacConcretePanels rivets); 0 clips, 20 slots ok, Play walk + spin OK, UNDO round trip OK; sheet out/polish/armory/sheet3.jpg; saved: no.
- Exfil: fix/polish_exfil.lua (outdoor sky edge: amber hazard bands + amber Neon replace olive, daylight hangar fill, 36 amber runway/lead-in studs, windsock, edge hazard band, deck stencils, tie-downs, cargo dolly, fuel-drum truck); 144 parts, 0 new lights; check_polish_exfil 0 clips, ExfilFX camera + lift sweep clear, routes clear; rooms2/rooms3 FAILS 0, hub1/training OK; Play walk to the pad edge (clip wall holds), cutscene -> Training OK; console baseline; UNDO round trip OK; sheet out/polish/exfil/sheet.jpg; saved: no. TimesSquare hide is an option flag for Edward. Notes: notes/polish_exfil.md
- Exfil review (fresh agent): notes/review_exfil.md; logically sound (0 clips, Play walk hub -> tunnel -> pad edge, cutscene -> Training OK, console baseline), no fixes; taste/design list (walking back from the pad through the barrier launches the cutscene; windsock too big on the edge walk; blank container labels; lime greens in daylight). TimesSquare untouched.
- Duels round 2: fix/polish_duels2.lua (re-run after polish_duels.lua): measured brightness ladder (cream frames > olive frames > lanes ~140 > chevrons ~105), team B olive 94,99,46 (renders olive, not lime), 1.5x mode plates readable from the aisle above the PadBoards, two-line ARENA DECK board; check_polish_duels 0 clips, Pad_1v1_A queued in Play, UNDO round trip OK; sheet out/polish/duels/sheet2.jpg; saved: no.
- Gate corridors: fix/polish_gates.lua (airlock bulkheads: ribbed walls, near-black band and ribs, cool recess strips, status lights, cream/near-black hazard sills, destination bay in the Shop cream / Armory gunmetal, Shop doorway frame cream, SHOP sign -> OUTFITTERS); 64 parts, 0 lights; check_polish_gates 0 clips, clearance unchanged, rooms2/rooms3 FAILS 0, hub1/training OK, Play walk hub <-> Shop and hub <-> Armory OK, console baseline, UNDO round trip OK; sheet out/polish/gates/sheet.jpg; saved: no. Notes: notes/polish_gates.md
- Gates review (fresh agent) + Exfil fixes + Hub: notes/review_gates.md (sound; the N corridor junction box was walk-through -> fix/polish_gates2.lua makes it collide, width 9.54); fix/polish_exfil2.lua (windsock 7-stud mast on the NE kerb behind the rail, container plates + painted cargo stencils; barrier-from-both-sides left for Edward); fix/polish_olive.lua (lobby-wide olive: band 111,114,57 -> 138,130,60 renders olive G/R 1.10, neon, disc, crates, drums, container; 152 parts, room-specific recolours skipped) and fix/polish_hub.lua (command deck: warmed envelope, warm-white lamps, warm skylight + 3 sun shafts, cream hologram, 8 insignia banners, destination-colour sign bars, OUTFITTERS stencil); 48 parts, 0 lights; check_polish_hub 0 clips, all checks pass, Play walk OK, console baseline, UNDO round trips OK; sheets out/polish/hub/sheet.jpg + out/polish/olive.jpg; saved: no. Notes: notes/polish_hub.md
- Hub review (fresh agent): notes/review_hub.md; logically sound (check_polish_hub 0 clips / hooks / 9 routes, Play walk, console baseline), no fix script. The "Path Blocked" Duels-hall -> spawn walk is not an obstruction: the doorway is 10.8 wide, Path.Blocked fired 0 times, the same 108-stud trip from the hall centre-line succeeds in one call; from z 16 the walker cuts the corner and pins on the door jamb (and the planner prefers a jump over the top-landing rail + 12-stud drop to the stairs). Taste: hologram rings fill ~30% of the disc view, olive Neon reads yellow-green.
- Training touch-up: fix/polish_training.lua (quadrants A olive / B cream / C sage / D warm grey: per-quadrant wall bands with near-black edges between the corner bastions, bastion + tower bands, 8 big wall letters placed by visibility scan, 8 floor plates at the plaza exits, gallery band near-black; bin frames + WEAPON SWAP stencils; grid lines 58/0.45 -> 34/0.32; field boards off the band); 141 parts, 0 lights, nothing collides, no gameplay moved; check_polish_training 0 clips, check_training ALL OK; Play: exfil cutscene -> Training, 4 quadrants walked, dummies 35 + respawn 4.5 s, bin -> Sniper, console baseline; Play grid measured (no clipping, walls p95 216); UNDO round trip OK; sheet out/polish/training/sheet.jpg; saved: no. Notes: notes/polish_training.md
- Showroom: fix/polish_showroom.lua (photo studio judged from CameraPoint at FOV 40 + blur: cream cyclorama with cove, SR_Props hidden, plinth cream/warm grey with the olive band as the one accent, KeyLight soft, Pendant1/2 rim, Pendant3/4 background light in lamp cans, Fill neutral; light count unchanged); check_polish_showroom hooks unchanged, sight lines clear, 54/54 frame rays on the cyc, 0 clips; Play Kit menu opens at CameraPoint over the studio; UNDO round trip OK; sheet out/polish/showroom/sheet.jpg; saved: no. Notes: notes/polish_showroom.md
- Final lap (fresh agent): fix/polish_final.lua (olive Neon 84,88,48 -> 88,88,66 measured in Play: G/R 1.12 B/R 0.24 -> 1.00 / 0.47 like the band, 39 parts incl. features-kit bright olive and 5 lime leftovers; hologram rings 10 / 7.4 at T 0.78 (gate-view coverage 7.4% -> 3.2%); 6 hub-wall PointLights lighting through the wall + 9 TimesSquare SurfaceLights (0.07-level impact) off: Edit 99 -> 84, Play hub 59 -> 44, none added; Duels doorway streak Textures hidden); full Play lap OK (spawn, Outfitters, Armory, Duels pad queue + west deck, Exfil pad edge + cutscene, Training 4 quadrants + bin + dummies, back); all checks pass before and after, console baseline, UNDO round trip OK; sheets out/polish/lobby_rooms.jpg + out/polish/final/sheet_fixes.jpg; morning report notes/overnight_report.md; saved: no. Notes: notes/polish_final.md

## Edward's morning decisions (2026-10-16)
- Outfitter and Armory NPCs are dialogue-only. The Shop_Counter, GunWall_Kit and Armory_Dais panel prompts are removed for now
  (flagged, UNDO-able; UI code and Showroom are kept for later).
- TimesSquare towers don't fit: hide them and replace with a floating-sky-base backdrop (Blender kit + Parts blockout).
- Hub lights: no room-based switching (RIVALS lobby: 69 lights, 55 on, 18 shadowed, no per-room toggling found in our survey);
  keep RoomFX as is.
