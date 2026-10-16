# Particle cleanup: remove the FX RIVALS doesn't have (2026-10-15)

Edward: remove every particle effect RIVALS doesn't have. RIVALS has 388 ParticleEmitters + 94 Beams, each bound to a purpose
(dummy hit FX, queue holograms, featured displays, jump shards, lamp beams, tightropes, one vent); **no ambient particles**.
Rule applied: keep purpose-bound FX, remove ambient FX. Work done in `Tacticals_rebuild.rbxl` (studio 8ef4e21a...) only; **not saved**.

## 1. Inventory (Edit mode, before the fix)

Classes searched: ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles. Workspace: **72**, all under `Workspace.LobbyMap`
(nothing in Workspace outside LobbyMap, nothing in Lighting, StarterGui, StarterPlayer or ReplicatedFirst instances).
Every host part is invisible (Transparency 1); the effects are free-floating.

| Path (LobbyMap.) | Class x n | Where | Enabled before | Purpose guess | Decision |
|---|---|---|---|---|---|
| FX.DustHall.ParticleEmitter | PE x1, rate 70 | hub centre (0,24,0) | **on** | floating white dust/motes in the hall | REMOVE |
| FX.DustDuels.ParticleEmitter | PE x1, rate 35 | Duels (-117,38,0) | **on** | floating dust in Duels | REMOVE |
| FX.Shafts.Beam | Beam x9 | 5 slanted (-272..-216, y 46-80, Duels west windows), 4 vertical at x -180/-140/-100/-60 (y 30-80) | **on** | decorative god-ray / light-shaft sheets; no lamp or light fixture within 6 studs of either end | REMOVE |
| FX.Steam.ParticleEmitter | PE x8, rate 2.2 | hub floor vents (+-28..83, 4, +-44) | off | steam | REMOVE (kept off, recorded) |
| FX.Arcs.Arc | Beam x16 | (-146,40,0) Duels | off | electric arcs | REMOVE (kept off) |
| FX.EnergyMotes.ParticleEmitter | PE x1, rate 40 | Duels (-143,30,0) | off | drifting motes | REMOVE (kept off) |
| FX.SparkBridgeA / SparkBridgeB / SparkGantry .Sparks | PE x3 (rate 0, burst) | bridges +-49,28 and gantry 21,56,30 | on (burst only), **tagged LobbySpark** | random spark bursts + Flash light fired by LobbyFX every 3-10 s | REMOVE + untag LobbySpark |
| FX.SparkDuels.Sparks | PE x1 | Duels (-128,46,41) | off, already untagged (rooms3) | random sparks | REMOVE (kept off) |
| FX.FX2.Thruster.Thrust | PE x24, rate 6 | 8 thruster clusters at y 21-23, z +-40 | off | decorative thruster exhaust | REMOVE (kept off) |
| FX.Hologram.HoloBase.Beam | Beam x1 | spawn disc (0,2..16,0) | on | light cone of the spawn-disc hologram projector (LobbySpin logo + 2 rings) | **KEEP** (hologram fixture) |
| Duels.Pad_<mode>_<A/B>.Holo.Beam | Beam x6 | Duels queue pads | on | queue-pad hologram beams (QueuePad) | **KEEP** (but see bug below) |
| Duels.SkyBeam.Beam | Beam x1 | (-276, 147..673, 0), outside the building | on | free-standing sky beacon, no fixture or gameplay hook | REMOVE |

Not in the live map (left alone): `ServerStorage.LobbyMap_V2.Ambience` (43), `LobbyMap_V2.Holos` (8), `LobbyMap_V2.Guides` (2),
`RoqerWorld.Archive` (5), `ReplicatedStorage.Repository.Weapons` (26, weapon muzzle/impact FX: gameplay).
Training (Range2, extras, bullseyes, jump pads, tightropes, bins, dummies) and the Heli/Exfil have **no** emitters or beams as
instances; their FX are created at runtime by gameplay scripts (below).

### Runtime-created effects (scripts)

| Script | Creates | Decision |
|---|---|---|
| `StarterPlayerScripts.LobbyFX` | 12 Neon **floor pulse** parts in FX running along the hub seams (x +-27..85, z +-6) | REMOVE (ambient): gated by flag |
| `StarterPlayerScripts.LobbyFX` | spark bursts: `Sparks:Emit(10-22)` + `Flash` tween on a random `LobbySpark` host every 3-10 s | REMOVE (ambient): gated by flag + tags removed |
| `LobbyFX` low-end scaler | only lowers FX emitter Rate / disables Arcs, never enables anything | untouched |
| `Client.Controllers.WeaponController.WeaponEffects`, `ExplosionController`, `GadgetController`, server `GadgetManager` | muzzle/impact/explosion/smoke-grenade FX | KEEP (gameplay, Training dummy hits) |
| `Client.Controllers.PropController` | `puff()` emitter when a prop is shot | KEEP (hit FX) |
| `ReplicatedFirst.LoadingScreen` | only reads emitter textures to preload them | untouched |
| `RoomFX`, `PadFX`, `ExfilFX`, `HeliRotorFX`, `LobbyScreensFX`, `WorldMoodFX` | no particles/beams/trails | untouched |

Other LobbyFX ambience (spinning holograms, chevron scroll, spawn ripple decal, sky windows, flight HUDs, tickers, cart UI,
crane/drone, breathing/flicker glows) is not particle FX and was left as is.

## 2. Changes (`fix/particles_fix.lua`, idempotent, UNDO-able)

- **65 effects disabled**: every effect under `LobbyMap.FX` except `FX.Hologram`, plus `Duels.SkyBeam`. Each gets
  `PFX_OrigEnabled` (original Enabled) and `PFX_Removed = true`; emitters are also `:Clear()`ed. 7 kept (Hologram + 6 pad Holo beams).
  The script reports any effect outside these groups as `UNCLASSIFIED` (none now).
- **Tags**: `LobbySpark` removed from FX.SparkBridgeA, SparkBridgeB, SparkGantry (stored in attribute `PFX_Tags`).
- **LobbyFX** (3 edits, each marked `[PFX]`; original backed up as `ServerStorage._RebuildRemoved.PFX_LobbyFX_Orig`, disabled):
  `local PFX_AMBIENT = workspace:GetAttribute("PFX_AmbientFX") == true` after the FX lookup; the pulse loop iterates
  `(PFX_AMBIENT and {-6, 6} or {})`; the spark loop uses `PFX_AMBIENT and CSvc:GetTagged("LobbySpark") or {}`.
  Workspace attribute `PFX_AmbientFX = false`. (First attempt used `--` line comments, which swallowed the rest of the pulse
  line -> `LobbyFX:25: Expected <eof>`; fixed with `--[[ ]]` block comments and verified in Play.)
- Run: `python tools/run_luau.py fix/particles_fix.lua`. Re-running reports "LobbyFX already patched", same counts.

### Undo
`python tools/run_luau.py fix/particles_fix.lua UNDO` restores every Enabled from `PFX_OrigEnabled`, re-adds the tags from
`PFX_Tags`, restores the LobbyFX source from the backup (and deletes it), and clears `workspace.PFX_AmbientFX`.
Tested: apply -> UNDO -> apply gives identical results. To turn only the runtime pulses/sparks back on without undoing,
set `workspace.PFX_AmbientFX = true` (and re-tag the spark hosts).

## 3. Play test (2026-10-15)

- After ~12 s in Play (client): **7 active effects**, exactly the kept ones (spawn hologram beam + 6 pad Holo beams);
  floor pulses 0; LobbySpark tagged 0; LobbyFX runs (LobbyFXLow false, 191 fps, HoloLogo spinning).
- Training: `Events.Training.Enter` -> character at (-13, 603, 5), InTraining true, 35 dummies, Pistol given, still 7 active
  effects (none idle on dummies). Hit FX are created by WeaponEffects/PropController at runtime and were not touched
  (not fired by hand in this test).
- Console: no LobbyFX/particle errors. Pre-existing only: MatchmakingManager fails to load in an unpublished place
  (MemoryStoreService), UIBlox FoundationProvider warnings, robloxstudio-mcp proxy register warning.
- Captures (eye height, in Play) in `out/particles/`: `pfx_hub_1.png`, `pfx_hub_west_1.png`, `pfx_hangar_1.png`,
  `pfx_duels_1.png`, `pfx_training_1.png`: no specks, dust, steam, sparks or floating shafts visible.

## 4. Checks re-run after the fix
- `check_hub1`: all hooks ok (FX folder present, LobbySpawn x1, QueuePad 6, ExfilBarrier, prompts, NPCs), crane/drone no hits.
  (Its "LobbyFX pulse y 0.08" line reads the source constant; pulses are now flag-gated off.)
- `check_rooms2`: FAILS 0. `check_rooms3`: FAILS 0 (step-off notes unchanged from before). `check_training`: ALL OK.

## Pre-existing bug found (not fixed, outside this task)
All 6 kept **pad Holo beams render in the wrong place**: their Attachments' local `Position` holds world coordinates, so the beams
sit at double the pad position (e.g. Pad_3v3_A at (-228, 45..48, -57) instead of near (-114, 21..24, -29); the 1v1 ones also
still use the pre-rooms3 Holo x -92.8). They float outside the Duels hall, so the queue holograms show no beam at the pads.
Fix suggestion: set each Attachment's `Position` to the intended offset in Holo space (e.g. `Holo.CFrame:PointToObjectSpace(...)`).
