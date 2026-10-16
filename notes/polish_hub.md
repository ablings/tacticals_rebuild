# Overnight polish: Hub (command deck) + lobby-wide olive tone

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS (2e616d06) was
only read (four captures round its central disc, `out/polish/hub/ref_hub*.png`). No computer use, no imports, no RIVALS ids.

| What | Path |
|---|---|
| Lobby olive tone (idempotent, UNDO flag) | `fix/polish_olive.lua` -> `python tools/run_luau.py fix/polish_olive.lua [UNDO]` |
| Hub polish (run after polish_olive) | `fix/polish_hub.lua` -> `python tools/run_luau.py fix/polish_hub.lua [UNDO]` |
| Check (clips, support, hooks, budget, walk routes; read-only) | `fix/check_polish_hub.lua` |
| Captures (12 cameras: disc -> each gate, wide, disc, ceiling, reward stand, boards, tunnel) | `python tools/polish_hub_capture.py <prefix> [names]`, `... ref|cam <name> x,y,z lx,ly,lz` |
| Sheet | `python tools/polish_hub_sheet.py` -> **`out/polish/hub/sheet.jpg`** (BEFORE / AFTER, Play from the disc toward each gate, close-ups, RIVALS) |
| Olive strip | **`out/polish/olive.jpg`** (hub, Armory, Shop, Duels, Exfil, Training: before / after polish_olive) |

## Olive tone (`fix/polish_olive.lua`)
Measured with `tools/part_pixels.py`: the shared `band_olive` 111,114,57 rendered G/R 1.27-1.39 (lime; the Armory band
82,106,59), the disc centre 112,126,62 rendered 163,186,114, `neon_olive` 66,72,36 rendered green, `crate_green` 65,94,56
rendered kelly green 27,63,42. Target: the loading-screen olive 138,156,74 (G/R 1.13, B/R 0.54).
Method: **one trial frame with a different candidate on each mesh** (4 band values, disc, two Neon values, crate, drum), measured
in one capture, then picked:

| Paint | Before | After | Renders (after) |
|---|---|---|---|
| band_olive (52 meshes) | 111,114,57 / 120,136,66 | **138,130,60** | hub 72-110, 79-119, 39-56 (G/R 1.10); Armory 109,123,62 (G/R 1.13, B/R 0.57) |
| neon_olive (33) | 66,72,36 / 88,101,48 | **84,88,48** / 96,100,54 | 88,90,38 rendered gold (B at 0.4): blue raised |
| disc_center (3) | 112,126,62 | **90,96,36** | 142,159,88 (the hero disc, lit by SpawnTop: ratio ~1.6) |
| crate_green + crate_trim (54) | 65,94,56 | **104,88,40** | dark olive, not kelly |
| drum_olive (8) / container_olive (1) | 70,82,52 / 88,98,58 | 100,84,38 / 104,94,46 | dark olive |
| Wayfinding label edge (Neon) | 138,156,74 | 96,100,54 | |

Skipped on purpose (35 parts): anything under `LobbyMap.Polish`, and every part another polish pass recoloured
(`PolishExfil_Orig` amber, `PolishDuels_Orig` dark-olive bands, `PolishGates_Orig` near-black band, `PolishArmory2_Orig` crates,
`PolishShop3_Orig`). The check confirms 0 olive records on another room's recolour.

## Hub (`fix/polish_hub.lua`)
Identity: the heart of the base, open and bright, the disc as the hero, olive dominant with cream lines.
1. **Envelope warmed** (116 Hub1 meshes + LapFix infill): the hub rendered cool (B-R +12..+23 on the walls). Every neutral wall /
   trim / ceiling / stair / plate mesh x (1.14, 1, 0.89) = 60% of the measured render-ratio correction. Walls now render B-R -2..-12
   (warm grey, e.g. 76,73,66). Floors keep their hub2 compensation.
2. **Warm-white lamps**: ceiling strips, wall capsules, bridge / catwalk and tunnel Neon 161,157,145 -> 182,164,132.
3. **Sun**: skylight glass 150,190,215 -> warm-clear 232,220,196; three vertical warm light shafts (Beams 255,232,192, FaceCamera,
   transparency 0.8 -> 0.98, from y 67.2 to the floor round the disc; the sun is overhead at ClockTime 12). The spawn hologram's
   green-grey tint (decals, beam, rings, PointLight colour) -> cream.
4. **Insignia banners** (8, `Polish.Hub.Banners`): 5 x 12.5 olive Fabric banners on the upper N/S walls (N x -70/-40/40/70,
   S x -70/10/40/70: the S wall has a tilted lamp board at x -46..-36), each placed where a ray grid finds one flat wall plane, on a rod
   with brackets and a bottom batten. Artwork in a Scale-only SurfaceGui: cream border, TACTICALS, a winged roundel with three
   chevrons, SKY BASE / DECK NORTH|SOUTH, rank bars.
5. **Wayfinding**: a Neon bar under each gate sign in the destination room's colour (OUTFITTERS warm cream 160,138,108, ARMORY cool
   white 136,144,150, EXFIL amber 190,108,26 = the Exfil Neon, DUELS cream + olive halves = its teams); the N floor stencil SHOP ->
   OUTFITTERS (stencil part 5 -> 8.4 wide) so floor and sign agree.

48 new parts (3 invisible shaft carriers), 0 lights added (the hologram PointLight only changes colour), 0 collidable, 0 queryable.

## Logic checks
- `check_polish_hub`: **0 clips** (45 visible parts; the 8 banner probes that overlap `H_WallLights__neon_lamp` are its hull:
  the 174-stud merged mesh, no ray hits it near any banner, listed as hull-only). Support 0 bad (banners on the wall, brackets touch,
  bars on their plates, shafts end at y 0.8). Hooks: 1 enabled LobbySpawn, fall-catch (0,4,0) lands on the disc at 0.52, QueuePad 6,
  ExfilBarrier 1, RoomLight 43 (all with Room), LobbySpin 4, LobbyScreen 10, LF_Beacon 8, CityBillboard 18, Screen_Leaderboard, reward
  stand SpinRoot, hologram, sign texts OUTFITTERS / ARMORY / EXFIL / DUELS, floor stencil OUTFITTERS, AssetCheck names 4/4. Budget:
  0 lights / emitters in Polish.Hub, 99 enabled lights in Edit (unchanged). Routes from the disc: N -> Shop, S -> Armory, W riser
  foot, E tunnel -> hangar, round the reward stand, to the leaderboard / TV / likes / ad walls: all clear. Crane (x 17..25, z <= 36.4)
  and drone (y ~20) sweeps can't reach the banners (z 43.6+, y 39.2+).
- `check_rooms2` FAILS 0, `check_rooms3` FAILS 0, `check_hub1` nothing flagged (crane / drone no hits), `check_training` ALL OK,
  `check_polish_shop` / `armory` / `exfil` / `gates` 0 clips, `check_polish_duels` 0 clips (its one support line, Lanes.Lane gap
  -0.002, predates this pass).
- **Play walk** (character_navigation): disc -> Shop (0,70) -> Armory (0,-72) -> round the reward stand (-15,-33) -> leaderboard side
  (-50,30) -> stairs -> top landing (-88,16,0) -> tunnel -> hangar (109.1, 3.0, -5.0, not exfilled) -> Duels hall beside the pit
  (-106.3, 19.07, 16.5: on the floor) -> landing -> disc. One navigation call from the Duels hall straight to the disc reported
  "Path Blocked" and stopped on the top landing; the same trip in two legs (landing, then disc) worked (pathfinder leg length, not a
  blocker). 59 enabled lights in Play. Console: baseline only.
- Play frames from the disc toward each gate: `out/polish/hub/play_toN|S|E|W.jpg`.
- UNDO round trip: hub UNDO restored 130, olive UNDO 152, 0 attributes left, band back to 111,114,57; re-applied identically.

## For the lead / Edward
- UNDO order: polish_hub UNDO, then polish_olive UNDO (olive first on re-apply).
- The disc centre is still the brightest olive in the hall (lit by SpawnTop): that is the hero; dim it (disc 80,86,32) if it reads
  too strong in Play.
- The hub screens (leaderboard, Duels TV, likes, ad, training) stay the ops/briefing screens; no new screens were added.
- Queued for import: nothing.
