# Overnight polish: final whole-lobby lap, cross-room fixes, distinctness sheet (2026-10-16, fresh agent)

Script `fix/polish_final.lua` (run LAST; UNDO flag; originals in attribute `PolishFinal_Orig`). Sheets: `out/polish/lobby_rooms.jpg`
(one Play capture per room, labelled; `python tools/final_rooms_sheet.py`) and `out/polish/final/sheet_fixes.jpg` (before/after).
New helper `tools/play_pixels.py`: mean rendered colour per part from a **Play** capture (client camera, CanQuery-off parts queried).
Check outputs before/after in `out/polish/final/pre_*.txt` / `post_*.txt`. Not saved.

## 1. Lap in Play (character_navigation at player height)
Route: spawn -> N gate -> Outfitters (centre, west, east) -> hub -> S gate -> Armory (centre, west, east bench) -> hub -> Duels
stairs -> door -> Pad_1v1_A (queued, `QueueMode=1v1`; off the pad it cleared) -> aisle -> west pass -> west deck (x -159) -> back ->
hub -> tunnel -> hangar -> pad (south of the barrier) -> pad edge -> back to the hangar -> walked into the barrier (+X) -> cutscene ->
Training (`InTraining=true`, plaza) -> the four quadrants (+-70, +-70) -> plaza bin (F, 7 -> Sniper in hand, `TrialWeapon=Sniper`)
-> a dummy (35 dummies alive, none floating) -> Leave (M) -> hangar (112,3,0), tools cleared -> tunnel -> spawn.
Nothing blocked; every leg walked first time except one (below). Console at baseline both sessions.

| # | Where | Finding | Verdict |
|---|---|---|---|
| L1 | Duels door, hub side | The 7-deep doorway reveal (`H_DuelsDoor__trim_metal`) rendered as radial brown streaks in Play: two `Tac_trim_Left/Right` Textures on a MeshPart whose reveal faces point along z, so the texture lands edge-on. | **Fixed** (Textures hidden). |
| L2 | Hub wall bays N/S | 6 old-lobby `Lights.PointLight` (y 6, z +-51, x +-42..83, Shadows off) sit in 1-stud invisible hosts 2 studs behind the hub wall kick: their light came through the wall onto the hub floor with no visible source. Rooms2 had hidden the other 4 of the set. | **Fixed** (off). |
| L3 | Hub spawn | Hologram rings swept across the gate views (review_hub taste item). | **Fixed** (smaller, dimmer). |
| L4 | Lobby-wide | Olive Neon rendered chartreuse (B/R 0.24) next to the khaki band (review_hub, review_duels, review_shop). | **Fixed** (measured). |
| L5 | Duels aisle centre | One `character_navigation` to the aisle disc (-115,19,0) answered "Can not find a route"; from the aisle at x -125 the same target walked, and the disc is a 0.26-thick SmoothPlastic plate at floor height. Pathfinder hiccup, not a blocker. | No change. |
| L6 | Exfil pad edge | Walking at the edge the character steps up onto the 4.7-high pad-wall trim (`E_PadWalls__trim_metal`, x 151.2); `X_Clip` still holds. Same as before the polish. | Note for Edward. |
| L7 | Outfitters | The featured stage (turntable inside a rope line) is walkable: a player can stand on the spinning stage next to the mannequin. | Note for Edward. |
| L8 | Training bin | The bin prompt key is F, which is also Quick Melee in Training (HUD). F opened the picker as designed; flagging the shared key. | Note for Edward. |
| L9 | Exfil | `ExfilBarrier` is ForceField material at T 0.2: it reads as a faint glass sheet across the hangar mouth in the Exfil view. Deliberate (a visible exfil zone), left. | Note. |
| L10 | Lights | Hub-area lights (24 `Hub2Add` surface lights, spot rig, WalkFill...) are not `RoomLight`-tagged, so they stay on everywhere: 63 lights enabled with the camera in Training. Turning them off by area needs a RoomFX change (game code). | Edward decision. |

Nothing else floated, clipped or z-fought along the route; the room checks below confirm 0 clips everywhere.

## 2. Checks (before and after polish_final: identical except the expected light count)
check_hub1 hooks ok, LobbySpawn 1, QueuePad 6, ExfilBarrier 1, RoomLight 43, crane/drone no hits; check_rooms2 FAILS 0; check_rooms3
FAILS 0; check_training ALL OK; check_polish_armory / duels / exfil / gates / hub / shop / showroom / training CLIPS 0, routes 0
blocked, 0 new lights. Enabled lights in Edit 99 -> 84. Console (Play): MatchmakingManager MemoryStore, UIBlox FoundationProvider
warnings, AssetCheck 1/1154: the baseline. UNDO round trip: 58 restored (lights back to 99), re-applied identically.

## 3. Cross-room fixes (`fix/polish_final.lua`)
1. **Olive Neon** (trial frame in Play, two candidates per capture on the disc ring and the floor lines, measured with
   `tools/play_pixels.py`): 84,88,48 -> 90,101,22 (G/R 1.12, B/R 0.24, chartreuse); 100,90,66 -> gold; 92,88,60 -> 99,91,43;
   88,88,64 -> 102,102,44 (1.00 / 0.43); 90,88,68 -> 95,91,55 (0.96 / 0.58). **88,88,66** chosen; the band renders G/R 0.99,
   B/R 0.50. After: disc ring 100,100,48 (1.00 / 0.47), floor lines 89,90,50 (1.00 / 0.56), Shop signs G/R 0.96, Armory signs 1.03,
   Duels signs 1.09. Scope: the 22 shared `*__neon_olive` parts polish_olive set, the 12 features-kit "bright" olive (96,100,54 ->
   100,99,75), and 5 leftovers: `Polish.Duels...BoardBottomLine`, `Polish.Armory...EdgeL/R/T` (round-1 lime 90,106,42) and the
   Shop stage `DaisRing` (107,122,58 Neon read lime). Deliberate accents left: Duels team-B frames, hub DUELS sign bar, gate GO
   lights, Armory sage glows, Training codes / pad rings / range lines, Exfil amber.
2. **Hologram rings**: ring1 15.3 x 0.16 -> 10 x 0.09, ring2 11 x 0.12 -> 7.4 x 0.07, T 0.5 -> 0.78. Measured in the hub toN view
   against a rings-hidden frame: changed pixels 7.4% -> 3.2%, contrast 62 -> 36 levels. Ring1 now frames the logo.
3. **Lights** (none added): the 6 hub-wall PointLights (L2) and the 9 TimesSquare billboard SurfaceLights (x 357-382; on vs off from
   the Exfil pad: mean change 0.07 levels, nothing a player can reach is lit; no script touches them) switched off. Play, camera at
   the hub: 59 -> 44 enabled. Measured and kept: Hub2Add ceiling lights (+4.8 on the upper hall when off), Hub2Add wall lights
   (small floor pools, +1.2 mean / p95 7), RoomLight hosts (RoomFX switches them by room).
4. **Duels doorway** (L1): `H_DuelsDoor__trim_metal` Textures on Left/Right faces Transparency 1.

## 4. Distinctness verdict (`out/polish/lobby_rooms.jpg`)
- **Hub (command deck)**: reads as the heart of the base: tall warm-grey hall, olive bands, banners, the disc and hologram as the
  hero, every exit signed. Distinct.
- **N/S gates (airlocks)**: near-black ribbed bulkheads, cool strips, hazard sills, a framed view of the destination. The most
  different space after Training. Distinct (the two gates are twins by design).
- **Outfitters**: warm boutique: amber ceiling, cream walls, mannequins, the spotlit featured stage, checkout counter. Reads as a
  cosmetic shop, not a supply store.
- **Armory**: cool gunmetal vault, white strips, gun wall, pegboard niches, the dais. Reads as the weapons room.
  **Closest pair: Outfitters vs Armory** share the same shell (beamed ceiling grid, the eye-level olive band, the white floor
  lead-in lines from the gate); they differ by light temperature and props. The olive band is the loudest thing in both (review
  item, still open): darkening the band in one of them (Armory dark olive) would separate them further.
- **Duels (arena deck)**: dark room, light cones on bright pads, cream vs olive team frames, sky through the glazing. Distinct.
- **Exfil**: outdoor daylight, amber bands and runway studs, the heli. Distinct; the TimesSquare towers fill the sky behind it.
- **Training**: white clinical grid range with quadrant codes. Distinct.
- **Showroom**: cream cyclorama photo studio through the Kit camera. Distinct.
