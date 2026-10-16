# Sky backdrop: TimesSquare out, floating base platforms in (2026-10-16)

Edward: the TimesSquare towers "just don't fit the theme or look of the game". Only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a).
Not saved. No computer use, no imports.

| What | Path |
|---|---|
| Studio script (idempotent, UNDO flag) | `fix/backdrop_sky.lua` -> `python tools/run_luau.py fix/backdrop_sky.lua [UNDO]` |
| Blender kit (queued for import) | `tools/backdrop_kit.py` -> `kit/backdrop.blend`, `kit/backdrop.fbx`, `kit/backdrop_manifest.json` |
| Captures | `python tools/backdrop_capture.py <prefix> [names]` (11 views incl. the 3 ExfilFX cutscene frames + 4 details) |
| Sheet | `python tools/backdrop_sheet.py` -> **`out/polish/backdrop/sheet.jpg`** (BEFORE / AFTER / cutscene / details / Blender kit) |
| Blender preview | `out/polish/backdrop/bl_preview.png` |

## 1. TimesSquare hidden (kept, not deleted)
- References checked first (all scripts grepped for TimesSquare / CityBillboard / Billboards / TrafficLane / City): only
  `Client.Controllers.BillboardController` uses it, through the **`CityBillboard`** tag; `fix/polish_exfil.lua` (HIDE_TIMESSQUARE, off) and
  `fix/polish_final.lua` (SurfaceLights off) use `FindFirstChild`; `ServerStorage._DevTools.LobbyMerge` is an edit-time tool.
- BillboardController builds a runtime `BillboardGui_Live` SurfaceGui (LightInfluence 0, Brightness 2.2) on every tagged part; a
  SurfaceGui still draws on a Transparency-1 part, so hiding the parts is not enough. The script therefore **takes the CityBillboard tag
  off the 9 billboard parts** (kept in attribute `Backdrop_Tags`): the controller simply finds nothing, no errors. Play check: 0
  `BillboardGui_Live` created, 0 tagged.
- 29 parts Transparency 1 / CanQuery false / CastShadow false, 20 SurfaceGuis disabled (originals in `Backdrop_Orig`). The 9
  TimesSquare SurfaceLights stay as polish_final left them (off). Keep `HIDE_TIMESSQUARE = false` in polish_exfil: backdrop_sky owns it.
- UNDO restores 49 instances and re-tags 9 (tested), and removes `Polish.Backdrop`.

## 2. The replacement: `Workspace.LobbyMap.Polish.Backdrop` (326 Parts)
A distant sky-base skyline seen from the Exfil pad, hangar and cutscene, RIVALS craft (chamfered 45-degree slab edges, neutral greys
163 / 124 / 84 / 58, thin olive band 138,130,60 and cream lines, readable silhouettes), our palette:
| Group | Where (deck top) | Reads as |
|---|---|---|
| HangarDeck | (300, 12, -120), 130 x 80, SE ~170 studs from the pad | chamfered deck with an olive edge band, warm-grey hangar shed with a chamfered roof, dark door + cream frame facing the pad, H-07 plate, apron lines, cargo, 3 pylons; two stepped hulls with sage Neon anti-grav rings + thruster pods |
| CommsIsland | (470, 50, 55), 52 x 52, far east and high | the landmark on the horizon: cream radome, 64-stud lattice mast with olive/cream bars, 2 mast dishes, a ground dish, a hut; cream Neon ring under it |
| LandingPad | (245, 2, 120), d 66, NE, low | dark pad with cream ring, H facing the base, 8 cream/sage Neon beacons, olive edge band, kiosk on an outrigger; cone hull + sage ring. It is the background of the cutscene lift |
| FuelDepot | (360, -6, -290), 74 x 46, far SE, low | three cream/sage tanks with dark-olive bands on saddles, sphere tank, pipe run, pylon |
| Cables | hangar NW pylon -> landing-pad mast, hangar SW pylon -> depot | sagging dark cables (8 segments each). A hangar -> comms cable was tried and dropped: it crossed the whole pad sky |
| Clouds | 11 long N-S banks at y -50..-25 under everything | flat base discs + low rounded tops sunk into them, soft blue-white 236,239,242 / 208,215,224, puffs T 0.06; they veil the City backdrop's tower tops (y -53) |

Backdrop only: every part Anchored, CanCollide / CanQuery / CanTouch false, CastShadow false, NotCover; **0 Light objects, 0
emitters/beams** (Neon only). Measured in the captures (`tools/part_pixels.py`): hull greys render blue-shifted by the Atmosphere haze
(84 -> 60,88,112 at ~200 studs), the olive band 127,146,95 (G/R 1.15, sage-olive in haze), clouds 219,229,236, deck sides 105,132,152:
the haze sets the depth order (pad nearest and darkest, comms island palest).

## Composition (checked from where players look)
- Exfil pad / edge: the comms mast is the one landmark at the centre of the east sky, the hangar deck to the right of the windsock corner,
  the landing pad left, clouds as a band below the rail; most of the sky stays open (the Exfil identity is "open sky edge").
- Hangar and tunnel: the comms island and the landing pad's mast sit in the hangar mouth over the helicopter, small.
- Hub east end: through the tunnel only a sliver of sky: nothing changes there (same as before).
- Cutscene (ExfilFX start, lift e=1, e=2.6): the landing pad and comms island frame the lifting helicopter; nothing crosses the camera
  path (check_polish_exfil: camera-path hits 0, lift sweep 0, everything is CanQuery false anyway).
- Before: TimesSquare's black/cream blocks filled 40-70% of every one of those frames.

## Blender kit (queued for import, needs the screen + Edward's OK)
- `kit/backdrop.fbx` + `kit/backdrop.blend` (collections B_Kit / B_Markers), built by `tools/backdrop_kit.py` on the hub_kit helpers:
  the same 4 platforms at the blockout sizes, each authored at its own pivot (deck top centre) and slid along +X (0 / 190 / 300 / 430);
  `<piece>__<material>` colour-split meshes, bevelled slabs/boxes, lathed pad/hull/rings, revolved tanks/radome/dishes; K_Scale6 (10-stud
  cube at (0,150,0)) + K_Marker6. 49 meshes; tris per piece: HangarDeck 3,408, CommsIsland 4,636, LandingPad 3,888, FuelDepot 5,012;
  **max 1,200 tris per mesh** (budget 20k).
- `kit/backdrop_manifest.json`: per piece `place_world` (= the blockout position) and `pivot_fbx_studio`; per mesh centre_rel_pivot, size,
  Studio material and colour. Import (Gunsy Funsy, Insert Using Scene Position), then hide the matching Parts groups (HangarDeck,
  CommsIsland, LandingPad, FuelDepot); Cables and Clouds stay Parts. A placement script is not written yet.
- The Blender MCP's background mode (`execute_blender_code_for_cli`) failed ("Blender executable not found": no BLENDER_PATH set), and
  using the GUI Blender would have touched Edward's open scene, so the kit was built with the same script in background Blender
  (`blender -b --factory-startup --python tools/backdrop_kit.py`), as the earlier kits were.

## Checks
- check_polish_exfil: 0 clips (141 probes), hooks unchanged, ExfilFX camera path 0 hits, lift sweep 0, 6 routes clear.
  check_hub1 ok, check_rooms2 FAILS 0, check_rooms3 FAILS 0, check_training ALL OK.
- Play (play lock taken / released): walked hub -> hangar -> through the barrier: camera Scriptable at 3.2 s, lift shot ran,
  `InTraining` true, landed in Training (0, 603.1, 14). Console = baseline (MatchmakingManager MemoryStore, UIBlox warnings,
  AssetCheck 1/1154, ProfileService offline, plus an MCP proxy register line).
- Idempotent (re-run rebuilds the folder, 0 tags parked on re-runs), UNDO round trip OK.

## Open for Edward
- The City backdrop (dark towers far below, y -310..-53) is unchanged; the clouds now hide most of it from player views. For a pure
  sky base it could be hidden too (one line, UNDO-able).
- The cables read as power lines; drop them if the sky should be emptier.
- `tools/show_studio.ps1` failed once tonight because two Studio windows matched `*Tacticals_rebuild*` (the UI session's?); captures
  still worked because the window was already visible. It needs `| Select-Object -First 1` if that recurs.
