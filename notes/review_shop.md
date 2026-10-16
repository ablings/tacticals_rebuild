# Shop review (fresh eyes, 2026-10-15 night)

Reviewer: a different agent from the Shop builder. Studio 8ef4e21a only, captures after `tools/show_studio.ps1 tacticals`.
No edits to the Shop: no clear bug was found, so there is no `fix/polish_shop_review.lua`.

Captures (edit-time, Future): `out/polish/shop/review_entry.jpg`, `review_counter.jpg`, `review_ne.jpg` (NE corner looking at the
door), `review_se.jpg` (SE corner looking at the counter), `review_gate.jpg` (hub approach at z 30 through the N gate).

## Logic checklist
| Check | Result |
|---|---|
| Walk in Play (character_navigation) | hub (0,30) -> shop door (0,72) -> counter front (3,97.5) -> west staff side (-12,104.8) -> east staff side (18.4,104.5) -> west corner (-20,78.9) -> east corner (19.2,81.8) -> back to hub (0,30.9): all reached. (24,80) / (-24,80) are taken by the wall racks and pedestals, not a blocked path. |
| Clipping | `check_polish_shop` 0 clips; a second test (GetPartsInPart on a probe 0.12 smaller than each of the 289 Polish.Shop parts, old meshes made queryable) also 0. |
| Floating | every floor group rests on the floor (bottom 0.03 over floor 0.02). The CounterPendants "bottom 0.10" and AFrame "-0.14" in the check output are bounding-box artefacts of the first rotated part (cords span 10.95-13.15 under a 13.15 ceiling; A-frame legs stand on the floor). |
| Lights | 4 new lights, all in visible fixtures, RoomLight Room=Shop (8 Shop hosts, 40 in all); 9 shadow casters in LobbyMap. In Play 67 lights enabled (budget comment ~45): lobby-wide issue, not the Shop's. |
| Signs face arrivals | SUPPLY, boards, A-frame, bin placards all read from the door. |
| Hooks | Interact.Shop_Counter (3,3,101.8) OpenPanel=Shop enabled; NPC_Quartermaster (10,3.25,106.7) OpenPanel=Kit; Spot_ShopCounter in place. |
| Console in Play | baseline only (MatchmakingManager MemoryStore, AssetCheck 1 texture failure, UIBlox FoundationProvider warnings). |

## Prioritised list for the lead (taste; not acted on)
1. **QUARTERMASTER tag over the 02 REQUISITION board.** From the entrance and from the counter the NPC's BillboardGui sits right on the
   board's item rows (review_entry, review_counter, review_se). Either move board 2 to the free span east of the NPC, or lift/offset
   the NPC tag (the tag is a hook; the board is not, so moving the board is the cheap fix).
2. **The counter truss spot (Spot_ShopCounter, 3,11,97.5) hangs in the sightline to SUPPLY.** From the door and from the hub
   approach it reads as a dark blob directly above the sign (review_entry, review_gate). Move it 2-3 studs west/east or raise it into
   the ceiling grid; its light stays.
3. **Warm identity is weak at distance.** In captures the walls read white-cool, the coffers and beams still blue-grey; the pools only
   show near the counter. The Shop vs Armory contrast will depend on this. Try a darker, more yellow cream on the upper wall
   (~200,188,160) and warmer coffer panels; check with a capture, not by value.
4. **Guns in the Shop.** The entrance-west gun rack, the gun on the featured pedestal and the rifles on the cream pedestals (pre-polish
   Rooms2 dressing) make the Shop read as a weapons room. With the Armory now the weapons vault, swap these for supply goods (kit bags,
   plate carriers, med kits) so each room owns its subject.
5. **Pendant shades read lime**, not olive, under their own warm light (review_counter). Darker olive (86,98,52) or a near-black shade
   with an olive band would sit better.
6. **Countertop in four runs** reads as loose planks between the metal plates from low angles. Could carry one olive edge strip
   across the plates to tie them together.
7. Minor: the east crate cluster sits tight against the east pier trim (no clip, but 0.0x gap reads as touching from the NE corner).

## Correction (Edward via the lead): the Shop is a UGC / COSMETIC shop
The lobby Shop sells avatar items, skins and cosmetics; the game's own main shop covers everything else. So the current
supply-store dressing is off-target, and items 4-6 above become part of a rework. **Nothing was changed** (bugs only, and none
found); a later agent reworks it. Blueprint: RIVALS UGC shop stage + market hall (`out/polish/shop/ref_ugc_stage.png`,
`ref_market_hall.png`). There a cosmetic is presented as a **lit exhibit, not as stock**: a recessed dark stage behind a big portal
with a hanging sign, curtains, a truss with 2-3 hard spots, a glowing logo wall, the items floating/rotating mid-stage, rope-and-
post queue line in front, and the hall around it kept dark so the stage pops.

### What has to change (for the rework agent)
| Now (Polish.Shop / Rooms2 S_*) | Cosmetic shop version (military theme, own assets) |
|---|---|
| `Counter` goods (uniform stack, ammo can, ledger, RATIONS box) | clear the top; keep the wood/cream counter as the **checkout desk** with a terminal and a small "CHECKOUT" screen; the Shop_Counter prompt (OpenPanel=Shop) stays |
| `WallShelfW/E` (ammo cans, rations, canteens, med kits) | **outfit walls**: 3-4 dress forms / headless R15 mannequins per side in camo outfits (woodland, desert, urban, olive drab) built from the NPC rig or Parts, each on a low plinth with a cream name plate and price tag in R$ |
| `Boards` "01 FIELD STOCK" / "02 REQUISITION" item lists | **cosmetic boards / screens**: "FEATURED THIS WEEK", "NEW DROPS" with item thumbnails (needs own images via codex/Creator Hub, Gunsy Funsy), a rotating screen (F_Screen16x9 from FeaturesKit) for the daily items, countdown line |
| `StockClusters` (pallets, crates, ammo case) | remove from the sales floor; at most one **shipping-crate prop** stencilled "NEW SEASON" by the back door |
| `EntryBins` (FIELD RATIONS, CANTEENS) | two **glass display cases** at the entrance with small cosmetics: dog tags on chains, unit patches, rank insignia, beret/cap (Parts + SurfaceGui text), each with a top-down spot or Neon base |
| `AFrame` "QUARTERMASTER / OPEN / DAILY ISSUE · RATIONS · AMMO" | A-frame text: "UNIFORM & COSMETICS / NEW DROPS DAILY" |
| centre featured pedestal (gun) + gun racks / rifles on cream pedestals | a **featured stage**: one mannequin in the current featured outfit (helmet, goggles, plate carrier skin) on the round pedestal, hard key spot + rim light, slow Spin attribute (RoomFX already spins models with `Spin`), rope posts around it as in RIVALS; guns leave the Shop entirely (the Armory owns weapons) |
| `CounterPendants` warm pools | keep the warm 3000K identity but move the light **onto the products**: spots on the featured stage and the outfit walls, the counter pendants dimmer |
| `NPC_Quartermaster` (OpenPanel=Kit, kit lines) | a **tailor / outfitter** NPC with cosmetic TalkLines; OpenPanel should probably become Shop (Edward to confirm, see hooks.md "looks swapped") |
| back wall SUPPLY sign | "OUTFITTER" / "UNIFORMS" sign (or a glowing insignia logo wall like RIVALS' "UGC" neon), olive/cream Neon outline |
- Keep: room shell, warm cream envelope, wood counter, mat, olive trim. Theme stays military: camo, helmets, patches, dog
  tags, insignia, berets; nothing kid-like RIVALS lacks; no ambient particles (RIVALS' stage sparkles are display-bound, so a
  purpose-bound sparkle on the featured stage only would be within the rule, lead's call).
- Item 1 (QUARTERMASTER tag over board 2) and item 2 (truss spot in the SUPPLY sightline) still apply to the new layout.

## Verdict
Logically sound: walkable, no clips, hooks and console as baseline. Visually it reads as a store (counter, boards, goods), but the
warm/cream identity needs items 3 and 4 to clearly separate it from the cool Armory.
