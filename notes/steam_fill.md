# Steam fill: the valve steams the room up (Warehouse 2), 2026-10-27 [STEAMFILL]

Work order (Lead, approved by Edward): on Warehouse 2 the steam valve fills the area with a cloud while it keeps masking noise
the way Tutorial 3 teaches. The old Warehouse and the tutorial keep the classic jet. Sheet: `notes/steam_fill_sheet.jpg`
(frames in `captures/steam_fill/`). Plan: `briefs/systems.md`.

## Round 3 (Edward's review, 2026-10-27): "yes it should be blinded by the steam; the steam should muddy up footstep sounds
## so they are very faint and you can't hear people"
Fill maps only (Warehouse 2); the classic jet (the Warehouse, Tutorial 3) is unchanged. Sheet: `notes/steam_fill_r3_sheet.jpg`
(built by `tools/steam_fill_r3_sheet.py` from the Play-test logs below).
- **The AI is blind in the steam.** BotManager's sight test (`smokeBlocks`, used by `CanSee`) now also asks
  `SteamMask.SightBlocked(eye, target)`: the sight line's studs inside the cloud are added up (the thick core within
  `Sight.CoreRadius` of the cloud's centre counts `CoreWeight` x, everything x the cloud's strength, so it thins in the fade);
  at `Sight.BlindDepth` studs the AI can't see. Result: you're hidden in the valve corner (after 2 studs of core) and anywhere
  6+ studs into the haze; someone just inside the edge stays visible; an AI standing in the steam can't see out.
- **Footsteps are muddied and very faint** when the walker is in the steam, when the listener is in it ("you can't hear
  people": the hiss around you drowns the room out; knob `Footsteps.ListenerInSteam`), or when `Footsteps.ThroughDepth` (6)
  studs of steam lie between them (the same weighted depth as the AI's sight; added after the round-3 grader). One rule,
  `SteamMask.FillMuffled`, for players and the AI (`Muffled` = the classic jet's `IsMasked(source)` or `FillMuffled`). Players: `FootstepController` asks `SteamCloud.FootstepScale(sound, pos, own)`: an
  `EqualizerSoundEffect` (`SteamMuffle`) on that footstep Sound cuts the highs (-40 dB) and mids (-18 dB), and the volume is
  x`Footsteps.Volume` (0.06; your own steps x`OwnVolume` 0.5, muffled). AI: footsteps and reloads (`HearNoise(..., quiet = true)`, set by
  CombatManager's reload line) follow `SteamMask.Muffled(source, listener)`. Gunshots, breaks and blasts never ask (unchanged).
- Classic jet: other people's steps x0.04 inside its 22-stud mask while it hisses (no muffle, no listener rule, no sight block),
  exactly as before; Tutorial 3 plays as before.
- The masking still lasts until the fade ends (round 2 rule); sight comes back gradually as the haze thins.

## What it does
- Shoot a valve on a map with `SteamFill = true`: the same hiss + jet as before, then over ~3 s a cloud billows out of the
  valve and fills the room: thick at the valve (the corner is hidden), a light haze across the room (a player at mid range
  stays visible). The hiss lasts `Fill.Duration` (7 s); then it thins away over `Fill.FadeTime` (3 s).
- The cloud is drawn by each client from two replicated attributes on the server's valve model: `SteamAt` (shot) and
  `SteamUntil` (hiss ends). Every client of the match, spectators and late joiners too, builds the same cloud (checked:
  a second, late-built cloud had identical emitter positions). Nothing is sent per frame; no new remote.
- The cloud stops at walls (a fan of 24 rays from just in front of the valve; a part 16+ studs long is a wall, cover and
  pillars are not), so it fills the valve's room, not the next one.
- Noise mask = the cloud: footsteps and reloads of anyone inside are masked for players and the AI. It grows from 8 to 30
  studs with the billow, is clipped by the same walls, covers up to 14 studs above the floor, and covers the whole cloud
  until it has faded (the work order: "masking ends with the fade"; the haze thins evenly, it doesn't shrink). The screen
  wash (the picture greys slightly, fading in over the last 4 studs of the edge, off while dead) shows only while you are masked (`SteamMask.Inside`, the same test the
  server and the AI use). Gunshots, explosions, fire and everything else stay audible (unchanged code).
- Rule difference to know: on Warehouse 2 the steam keeps covering you for 3 s after the hiss stops (while the haze
  thins). Tutorial 3's line "The steam only covers you while it's hissing" is shown only on the Warehouse, whose classic
  valve still works exactly that way.
- Resets every round (`ShootableManager.ResetAll` clears both attributes; clients drop the cloud at once).
- Maps without the attribute (the Warehouse, the tutorial) take the classic path: jet + hiss, 22-stud mask while it hisses.

## Old valve bugs fixed on every map (seen live in the test copy before the install)
1. `ActivateValve` errored on every shot (`v.SoundTrim.Play(hiss)` -> "attempt to index nil with 'Play'"): no hiss, the
   jet never switched off until the next round, `OnValve` never fired.
2. The jet's Attachment got its `WorldCFrame` before it had a parent, so it was taken as relative to the valve body: the jet
   drew at twice the valve's position (S1's floated mid-room by the loading bay, 45 studs away; S2's outside the map).
   Players shooting the valve in Tutorial 3 saw nothing at the valve. Now: hiss + jet at the valve, off after 7 s.
   (The lobby's ArenaLoader has the same parent-order bug in `bindValve`; not touched this round, see Open.)
3. Once the hiss bug was fixed, the looped hiss kept playing at volume 0 for the rest of the round: it now stops after its fade.

## Turning it on (map builder)
1. The map model in Workspace of the match places is named `Warehouse2` and carries the attribute `SteamFill = true`
   (bool). One valve can opt out with `SteamFill = false` on the valve model.
2. Valves: `Shootables/SteamValve_*` models with `ValveBody` + `Wheel` parts (the jet points from the body toward the
   wheel), exactly like the Warehouse.
3. Walls the steam must stop at go in `Warehouse2/CollisionProxies` (the fan only reads that folder when it exists).
4. The map is in the registry (`ReplicatedStorage.DuelMaps.Warehouse2.MapInfo`, `WorkspaceName = "Warehouse2"`):
   ShootableManager now scans every registry map placed in Workspace (Warehouse first), so its valves and barrels work and
   explosions use its walls. Its props let bullets through but make no noise for the AI yet (only the Warehouse's props
   break on screen; see Open).

5. Bots: `BotConfig.CoverFolders` already lists `Warehouse2/CollisionProxies` (a missing folder is skipped).
6. A valve attribute `MaskRadius` (a legacy attribute the old Warehouse's valves carry too) is read by no script: the radius
   is `Fill.MaskRadius` in the config, so mask and drawn cloud stay the same size.

## Config knobs (`ShootableConfig.Steam.Fill`)
| Knob | Default | Meaning |
|---|---|---|
| `Enabled` | true | false = every map plays the classic jet |
| `Duration` | 7 | hiss / hold time on a fill map |
| `GrowTime` / `FadeTime` | 3 / 3 | billow out / thin away |
| `Radius` | 30 | how far the haze spreads (walls stop it sooner) |
| `MaskStartRadius` / `MaskRadius` | 8 / 30 | mask at the shot / when full |
| `MaskHeight` / `MaskEdge` | 14 / 2 | studs above the floor masked / slack at a wall |
| `CentreOut`, `FanHeight`, `FanRays`, `WallMinLength`, `WallPad` | 3, 6, 24, 16, 1 | cloud shape (rays) |
| `Color`, `LightInfluence` | (205,210,215), 1 | look (lit by the room only: no glow in the dark) |
| `ScreenWash` | 0.45 | standing inside greys the picture slightly (0 = off; never shows more than normal) |
| `Sight.BlindDepth` | 6 | studs of steam an AI sight line may cross before it's blocked (round 3) |
| `Sight.CoreRadius` / `CoreWeight` / `Step` | 9 / 3 / 0.5 | the thick core around the cloud's centre counts 3 x; sample spacing |
| `Footsteps.ListenerInSteam` | true | standing in the steam you can't hear people either (false: only steps in / through it) |
| `Footsteps.ThroughDepth` | 6 | steps (and reloads, for the AI) on the far side of this much steam are muffled too (0 = off) |
| `Footsteps.Volume` / `OwnVolume` | 0.06 / 0.5 | muffled footsteps: others' / your own (yours end up 0.5 x 0.7 x 0.5 = 0.175) |
| `Footsteps.HighGain` / `MidGain` / `LowGain` | -40 / -18 / -2 dB | the muffle (EqualizerSoundEffect `SteamMuffle` on the footstep Sound) |
| `LowQualityAt` | 4 | saved graphics 1..4 = Low (also touch-only devices, `_ForceTouch`, < 40 fps) |
| `Quality.High / Low` | 170 / 60 puffs | live particle budget; Low = 7 emitters, bigger denser puffs (hides the corner as well) |
Studio test override: player attribute `SteamFillQuality = "High" | "Low"`.

## Files
- `fix/steam_fill.lua` installer, **round 5** (= round 3 after two graders; 18 text edits: round 2's 12 + BotManager 3,
  CombatManager 1, FootstepController 2; hash before 159e89d8 -> installed e7c76e50; UNDO back to 159e89d8). Rounds 3 (84b6012)
  and 4 (29c4b22) existed only on this test copy and were UNDOne with their own installers. **Install on the match places
  (Matchmaking / Ranked / Tutorial) after `fix/map_warehouse2.lua`; nothing is installed on them yet.** Round 2 was only
  ever on the main PC's test copy; a round-2 stamp is refused (UNDO it with `git show 2d05a52:fix/steam_fill.lua`).
- (round 2 text, kept for history:) installer (built by `python tools/steam_fill_build.py [--run <studio_id> [UNDO]]` from
  `fix/steam_fill/*.lua`). Match places only (refuses the hub). Idempotent; checks every anchor in every target, plus the
  two new module names, before writing; stamps `SteamFillRound = 2` on ShootableManager BEFORE the first write (an
  interrupted run can be re-run or undone) and refuses any other round; UNDO restores the exact original (hash b7069a20
  on the test copy; installed = 5ed79770). Round 1 only ever existed on the test copy. Run order: after every earlier match-place installer (it anchors on today's text).
  **Changing an installed edit's text: UNDO with the installer that wrote it first**, then install the new one.
- `fix/steam_fill/`: `SteamMask.lua` (replaces the shared module), `SteamCloud.lua` (new, client), `SteamCloudController.lua`
  (new, Client.Controllers), `ShootableConfig_Fill.lua` (the config block), `TestHook.lua` (Studio-only test hook).
- `fix/steam_fill_tests.lua` unit tests (Edit mode, fresh module clones, fake valves far away; cleans up).
- `tools/steam_fill_testmap.lua` TEST ONLY: a "Warehouse2" stand-in (Warehouse copy +400 Z, SteamFill, own spawns, registry
  entry). Never run it on a shipped place; the real Warehouse 2 replaces it.
- Studio-only hook `ServerStorage.SteamFillTestHook` (`valves`, `shoot`, `activate`, `reset`, `radius`, `masked`, `bots`,
  `botAt`, `ammo`), created only when `RunService:IsStudio()`.

## Round 3 grader (roblox-systems-grader, xhigh): FIX 8.9, nothing blocking. Fixed in round 4:
1. code after a comment on the CombatManager line (`--[[ABILITY]] --[[STEAMFILL quiet]] end`): the tag is gone;
2. the steam sight test cost ~150 raycasts (349 us through the core): per-valve lookups hoisted, the line clipped to the cloud's
   circle before sampling -> **13.5 us through the core, 5.6 us for 60 studs of haze, 5.4 us missing** (one raycast 2.8 us);
   a unit test checks it against a brute-force walk with `Inside` on 4 lines;
3. comments said "as blind as players" and "in or through": reworded; "through" is now real (`ThroughDepth`);
4. the test hook re-implemented the hearing rule: `hears` now runs the AI's real `_perceive` and `HearNoise`.
Open from it: the two-player run (C2). Its note: after 5 s without seeing or hearing you, the AI's old hunt logic heads for
your true position +-15 studs, so a blind AI still drifts toward someone hiding in the steam (not changed: older behaviour).

## Round 4 grader (roblox-systems-grader, xhigh, fresh): FIX 8.4, nothing blocking. Fixed in round 5:
1. an and/or with a possibly-false middle (`cfg and FillMuffled(...) or false`, SteamCloud): plain if;
2. the SightDepth test was looser than it looked (Step 1 sampling of the core edge: up to 2.15 studs off, 2 blind/seen flips in
   300 random lines): the cloud's AND the core's circles are now exact chords, only the wall fan and the height band are
   sampled, Step 0.5; the test is 60 seeded random lines + a vertical + a zero-length line against a 6000-sample brute force
   (all within 0.75 studs, no flips away from the threshold);
3. ThroughDepth silently needed the Sight block: SightDepth uses DEFAULT_SIGHT when a map has none (SightBlocked still needs it);
4. the hook's `hears` probe could leave the AI hunting: it now restores heardAt / noiseAt / lastKnown / noisePos.
Kept: `BotConfig.CoverFolders` lists `Warehouse2/CollisionProxies` by path, as the work order asked (the existing entry is a path too).
Open from it: the two-player run, phone frame time.

## Round 5 results (same copy)
- UNDO round 4 (`git show 29c4b22`) -> 159e89d8; install round 5 -> e7c76e50; second run all "="; UNDO -> 159e89d8; re-install.
- Unit tests **63/63**.
- Play, Warehouse 2 (real `_perceive` via the hook): steps heard with no steam, not through the steam (both outside, cloud between),
  heard after the fade. SightDepth cost: 17.6 us through the core, 6.1 us for 60 studs of haze, 5.2 us missing (one raycast 2.3 us).
  Output: no errors from this work.

## Round 4 results (same copy)
- UNDO round 3 -> 159e89d8; install round 4 -> db0c45b8; second run all "="; UNDO -> 159e89d8; re-install db0c45b8.
- Unit tests **61/61**.
- Play, Warehouse 2: AI and me each just outside the cloud on opposite sides (38 studs apart, the cloud between): the AI's real
  `_perceive` hears my steps with no steam, **not through the steam**, and again after the fade. My client: the AI's steps
  through the steam 0.03 muffled from 6.1 s (as the cloud grew in between) to 13.3 s, 0.50 from 13.6 s (the thinning haze
  drops under ThroughDepth just before the fade ends); no screen wash (I was outside).
- The CombatManager line installed: `...SoundScale or 1), true) --[[ABILITY]] end`.

## Round 3 test results (Shadow PC; own copy `out/steam_fill/test.rbxl` copied from Matchmaking_place.rbxl 01:05, no lock;
## the REAL Warehouse 2 installed on it with `fix/map_warehouse2.lua`, which carries `SteamFill = true`)
- Installer: install 18 edits + mask + 2 modules; second run all "="; UNDO -> original hash 159e89d8; re-install 14173ab7.
- Unit tests **50/50** (`fix/steam_fill_tests.lua`; 18 new: InFill in / out / past a wall; Muffled by source and by listener;
  sight through the core blocked; 4 studs of haze = depth 4, visible; 8 studs blinds; half-faded haze thins to 4; clear after;
  the classic jet never blinds, never muffles a listener, still masks a walker; `Enabled = false` never blinds).
- Me + AI on Warehouse 2 (real map vote, practice bot, valve S1, cloud radius 30): see the table on the sheet.
  Sight (bot 38 studs from the cloud centre): no steam all seen; full cloud: core blind (depth 41.8), 20 studs out blind (9.8),
  3 studs in seen (2.8), outside seen; AI in the core can't see out (35.4); mid-fade (strength 0.47) the core still blind (16.0),
  the mid haze seen again (2.9); after: all seen.
- Hearing (hook, same positions): steps / reload not heard with me in the steam or the AI in the steam (full cloud, fade);
  heard before and after. **Real reload remote** (`Combat.ReloadWeapon`, Pistol): no steam heard; me in the steam not heard;
  AI 3 studs inside the edge, me outside 13 studs away: not heard; after the fade heard.
- Footsteps on my client (AI walking, scripted timeline, every step the client played): 0.50 walk / 0.16 sneak with no steam;
  **0.03 / 0.01 with the muffle on** from the moment the growing cloud reached the AI; with the AI outside and me in the core
  during the fade: 0.03 muffled; 0.50 again at the first step after the fade (14.1 s). The screen wash was on exactly while I
  stood in the steam.
- Round reset (kill -> round 2): SteamAt / SteamUntil cleared, valve re-armed, no cloud drawn on the client.
- Tutorial 3 on the Warehouse (my copy set to PlaceKind Tutorial + StudioTutorialServer for the test, then restored): valve
  activated -> the slide step ("SlidIntoCover") came next; classic radius 22, jet + hiss, no cloud, no muffle; me 20 studs
  from the valve: steps and reload masked, sight depth 0; 8.5 s later radius 0, jet and hiss off.
- An autonomous-AI damage run was inconclusive (the practice bot didn't fire at all in 5 s, even without steam); the sight
  samples matched (20/20 seen in the open, 2/20 in the haze as it moved in).
- **Not run: Studio server + 2 players.** On this PC too only the Server window opened (the place's
  `TestService.NumberOfPlayers` was 0; setting it to 2 didn't help; the ribbon's player-count box isn't reachable by UI
  Automation, and this session has no desktop control).

## Round 2 test results (own copy `out/steam_fill/test.rbxl`, copied from Matchmaking_place.rbxl 02:38, no lock)
- Installer round 1: a foreign round stamp is refused; one broken anchor refuses with nothing written.
- Installer round 2: install 12 edits + mask + 2 modules, second run all "=", UNDO back to the original hash; a foreign
  `SteamCloud` module refuses with nothing written; a simulated half install (stamp set, a module missing) UNDOes and
  re-installs cleanly.
- Unit tests 32/32 (classic radius 22 unchanged and no fade; fill radius 8 -> 24.5 at 1.5 s -> 30, held until the fade
  ends, then 0; wall clamps the fan to 8.5, a crate doesn't, also when the valve carries SteamFill itself; floor above not
  masked; opt-out; `Enabled = false`; reset; `SteamAt` fallback; Inside = IsMasked). Round-1 tests failed against the old
  code (proves they test something).
- Timeline (round 2, me 18 studs from the cloud centre, sampled every 0.5 s on server + client): masked from 1.0 s to 9.5 s,
  radius 0 at 10.0 s; the screen wash on in exactly the same samples; hiss 0.9 until 7.0 s, stopped at 8.0 s; cloud gone 10.5 s.
- Me + AI match on the stand-in (real map vote, AI = BotManager practice bot 15.8 studs away): reload heard with no steam,
  **not heard in the full cloud** (masked, radius 30), heard again after the fade. Timed on the server clock.
- Footsteps of another character (the AI walking inside the cloud), measured on my client: 0.85 before, 0.006..0.034 in the
  cloud (x0.04), 0.85 after the fade.
- Round reset: the next round cleared `SteamAt` / `SteamUntil` and re-armed the valve; a reset mid-cloud removes it at once.
- Real gunshot through `Combat.FireWeapon` at the valve activates it (classic and fill).
- Tutorial 3 on the Warehouse (no SteamFill): valve line -> valve fired -> "Now move!" slide line; no cloud, 22-stud mask,
  0 once the hiss stops; jet at the valve; hiss plays.
- Output log after the install: no errors from this work (the asset-type and KitGuard lines were there before). Before the
  install: the ShootableManager:337 error on every valve shot.
- **Not run: Studio server + 2 players.** `multiplayer.py start` launched only the Server window twice (no player
  windows, 330 s wait; Studio's count `rbxRibbonNumPlayer` is 2; the Edit log shows only `StartServerAction`). Covered
  single-player instead: late-built cloud identical to the live one, other-character footsteps masked on my client.

## Systems grader
Round 1: FIX 8.2 (installer could half-install; mask vs drawn cloud timing; no 2-player run; pcall around an index;
valve-level SteamFill lost the walls; real map's per-valve MaskRadius; silent hiss loop; Warehouse 2 props half a feature;
unused `opts.body`; phone frame time). Round 2 fixed all but the 2-player run and the phone frame time (both below).
Round 2: FIX 9.0, no code blockers; only the 2-player run open. Small items fixed after it: wash fades in at the edge and
ignores a dead body; notes reworded; the test copy's StudioTeleportData set back to the 1v1 JSON.

## Open
- Two-player check in Studio when Server + Clients launches players again (or a live two-PC test after Edward publishes).
- Lobby pad duels: ArenaShootables doesn't tag its valves `SteamValve` (so lobby valves never mask noise) and ArenaLoader
  places the jet attachment before parenting (same far-off jet). If Warehouse 2 goes into the lobby: tag + `SteamAt` in
  ArenaShootables, `SteamCloud.Bind(solidValve)` in ArenaLoader's `bindValve` (the solid valve carries the attributes and the shape).
- ~~The AI's eyes ignore the cloud~~ (Edward: blind it; done in round 3).
- The AI is blind 6+ studs into the haze, while players still see each other at mid range there: the AI is a little weaker
  than a player in the steam (by Edward's choice). `Sight.BlindDepth` is the knob.
- Other players: the muffle is client-side and only for footsteps (gun and reload sounds of other players are as before).
- Warehouse 2 props: bullets pass through them, but they neither break on screen nor alert the AI until PropController
  binds every placed map (then add them to ShootableManager's noisy `props`). DoorManager drives the Warehouse's shutters only.
- Phone frame time not measured (Low caps 60 puffs, up to 30 studs across; overdraw with the camera inside is the cost).
- Other players never hear your reload (it is a client-only sound); "reload masking" is for the AI only, as before.
