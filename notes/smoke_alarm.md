# Smoke alarms on the House (2026-10-28) [SMOKEALARM]

Work order (Lead plan, approved by Edward), Edward: "a smoke alarm that can be shot out, maybe two of them, that do a light beep;
shooting it out will also muddy footsteps like the warehouse map". Two shootable ceiling smoke alarms on the new map House, in the
match places and in lobby pad duels. Built on top of breakable glass round 1 (`notes/breakable_glass_DONE.md`).

## What it does
- **Chirp:** each alarm gives a quiet, positional low-battery chirp (a 0.14 s pip of the beep the gadgets already use live,
  rbxassetid://9117197553, pitch 2.9, volume 0.16, heard to ~45 studs) every 25-40 s, a new random gap every time and per alarm
  (the first one 4-40 s into the round, so the two never chirp together). The red LED blinks with it.
- **Shot** (a bullet, a melee swing that reaches it, or a blast in reach; never through a wall, a floor or a ceiling): it blares for 7 s (a real alarm's
  "temporal three": three 0.42 s tones, a pause, again; volume 0.75, heard to ~130 studs), the LED flashes with it, a short burst of
  sparks, and the housing drops open on a hinge (the green circuit board and the battery show).
- **While it blares** footsteps and reloads within 28 studs (flat) on its floor are masked, for players and the AI, exactly the steam
  valve's way (`SteamMask`): the AI doesn't hear a step or a reload whose source is in the blare, or when the AI itself stands in it;
  players hear other people's steps there muffled and very faint (match places: the steam's EQ muffle, x0.06; lobby: x0.04), and
  standing in the blare you can't hear people either. Gunshots, glass, blasts and fire never ask the mask (unchanged).
- **Then** it's broken and silent for the rest of the round (no more chirps, no mask). **Every round resets it.**
- **Scope:** all state is attributes on the server's alarm model (no remotes). In a match place there is one match per server; in the
  lobby the state is on that arena's Solid twin and only that match's players (and spectators) bind its Visual twin (ArenaLoader),
  so only they hear and see it. The mask is positional, so another arena's alarm never masks yours (unit test).
- Not cover: every part is CanCollide off and carries `NotCover`.

## Where (and why)
| Alarm | Plan (x, y) | Height | World (match places, ORIGIN -650, 1.2, -450) |
|---|---|---|---|
| `SmokeAlarm_G` | 0, 0 (cross hall) | on the ground-floor ceiling, 13 (underside of Slab_LD) | -650, 14.2, -450 |
| `SmokeAlarm_U` | 0, 0 (landing) | on the upper ceiling, 26 (underside of Ceiling_U) | -650, 27.2, -450 |
- Spawns are point-symmetric about the plan centre (A living room -35, -19; B kitchen 35, 19), so the centre is the only spot that is
  exactly as far from both (39.8 studs); two alarms elsewhere could only be fair as a mirrored pair, which would give each team "its"
  alarm. One per floor on the centre line: each team reaches each alarm in the same time.
- The ground alarm's 28-stud mask covers the cross hall, the foyer's back half, the back hall and the near halves of the living room
  and kitchen, never a spawn (39.8 > 28). The upper one covers the landing and the doors of the bedrooms off it; the mask band (16
  below to 2 above the alarm) keeps each alarm on its own floor (the landing is not masked by the ground alarm, tested).
- The cross hall's display column (0..8) leaves 5 studs below the alarm; the two room lights per hall sit at x +-4.5, so the alarm sits
  between them. Found by name at install time (`COLP_Slab_LD`, `COLP_Ceiling_U`), so a moved House moves its alarms.

## Model
Parts only, own work: `Base` plate (white cylinder 1.4 x 0.12), `Cover` housing (1.16 x 0.34) with `CoverRing` and `CoverButton`,
`Led` (0.14 ball, dark red; Neon red + a 5-stud red PointLight when lit), and inside, hidden while shut, `Board` (green) and
`Battery`. All anchored, CanCollide / CanTouch off, CanQuery on (a bullet stops at it), CastShadow off, `NotCover`. The model:
`Shootables/SmokeAlarm_G|U`, attributes `Shootable = "SmokeAlarm"`, `NotCover`, `SmokeAlarmInstall = 1`, `SmokeAlarmModel = "1b"`.

## Config (`ShootableConfig.SmokeAlarm`; defaults in `Shared.SmokeAlarm`)
| Knob | Value | Meaning |
|---|---|---|
| `Enabled` | true | false: plain props |
| `ChirpMin` / `ChirpMax` | 25 / 40 | seconds between chirps |
| `ChirpVolume` | 0.16 | quiet location cue |
| `BlareTime` | 7 | seconds it blares |
| `BlareVolume` | 0.75 | |
| `MaskRadius` | 28 | studs (flat) masked while it blares |
| `MaskBelow` / `MaskAbove` | 16 / 2 | the band around the alarm's height: its own floor only |
| `ListenerInBlare` | true | standing in it you can't hear people either |
| `HitPadding` | 0.3 | studs around the parts for the bullet test |
| `BlastScale` | 1.25 | blasts break alarms within Radius x this (round 3: a frag on the floor under it reaches) |
Module-only knobs: `ChirpPitch` 2.9, `ChirpLength` 0.14, `ChirpRollOff` 3-45, `BlarePitch` 2.2, `BlareRollOff` 10-130, the blare
pattern (`BlareOn` 0.42, `BlareOff` 0.12, `BlarePause` 0.55), `MeleeReach` 0 (round 2; was 1.5), `FirstChirpMin` 4, LED colours.

## Server state and events (for UI / animation)
On the alarm model the server owns: `AlarmPos` (Vector3), `ChirpAt` (server time of the last chirp), `AlarmBroken` (bool),
`BlareAt` / `BlareUntil` (server time), `AlarmCause` ("Bullet" | "Melee" | "Blast"). Tag `SmokeAlarm`. No remotes: the clients
react to the attributes (a late joiner never hears an old chirp: only one under 1 s old plays).

## Files
- `fix/smoke_alarm.lua`: the installer (built by `python tools/smoke_alarm_build.py [--run <studio_id> [UNDO] [DRY]]`, which embeds
  `fix/smoke_alarm/*.lua`). ONE installer for both kinds of place; needs breakable glass round 1 (and steam fill round 5 on a match
  place). Idempotent (second run: every line "="), checks every anchor in every target before writing, token-boundary anchors,
  stamps `SmokeAlarmRound = 1` on ShootableManager before the first write, refuses any other round, UNDO returns the exact "before"
  hash, `DRY` writes nothing. No House in the place: nothing at all is written (round 2).
  - Match places: adds `Shared.SmokeAlarm`, `Client.Controllers.SmokeAlarmController`; edits ShootableConfig (block before the reload
    line), SteamMask (2 edits: `IsMasked` + `FillMuffled` ask SmokeAlarm), ShootableManager (6: require + state, setup + Studio test
    hook in Start, shots, blasts, melee wraps the glass's `OnMelee`, ResetAll); places both alarms in `Workspace.House.Shootables`.
  - Hub: adds `Shared.SmokeAlarm`; edits ShootableConfig, SteamMask (2), FootstepController (2: the listener rule), ArenaShootables
    (7: require, setup per arena, shots, blasts, melee, ResetAll, Destroy), ArenaLoader (2: the Visual twin binds); places both
    alarms in `ServerStorage._DuelSource.House.House.Shootables`. **Then run `fix/duel_split_map.lua` with ONLY = "House"** so the
    Visual / Solid layers carry them (tested: 7 parts each in both layers).
  - Every edit sits BESIDE the glass / steam installers' inserted text, never inside it: glass round 1 still re-runs as all "=" and
    UNDOes fully with this installed (checked on both places). **Exception: `fix/steam_fill.lua` checks SteamMask as a whole module,
    so re-running steam fill needs this UNDOne first** (then re-install this).
- `fix/smoke_alarm/`: `SmokeAlarm.lua` (shared rules + server set + client look), `SmokeAlarmController.lua`, `ShootableConfig_Alarm.lua`
  (the config block), `TestHook.lua` (Studio-only `ServerStorage.SmokeAlarmTestHook`: `alarms`, `shoot`, `chirp`, `reset`, `masked`,
  `spawnai`, `botAt`, `hears` = the AI's real `_perceive` / `HearNoise`, created only when `RunService:IsStudio()`).
- `fix/smoke_alarm_tests.lua`: unit tests (Edit mode, fresh module clones, fake alarms 5000 studs up, cleans up).
- Port order: match_place_ref: steam fill r5 (in) -> breakable glass r1 -> map_house -> **smoke_alarm**; lobby copy: glass r1 (hub)
  -> duel_map_port House -> house_lobby_prep -> **smoke_alarm** -> duel_split_map ONLY = "House".

## Tests (own copies: `out/smoke_alarm/test.rbxl` = Matchmaking_place.rbxl + glass r1 + map_house (gameplay layer, no kit) + this;
## `out/smoke_alarm/lobby_test.rbxl` = the House builder's saved lobby copy + this + duel_split_map House)
- Installer: install / second run all "=" / UNDO back to the before hash / re-install, on both kinds of place; match hashes
  90fedd14 -> d56fc1a0 reproduced on a fresh copy; glass r1 DRY install all "=" and DRY UNDO all "+" with this installed. One anchor
  bug found and fixed this way (the blast line first sat inside the glass's inserted block).
- Unit tests: **35/35** match, **32/32** hub (the three FillMuffled checks need the match places' fill steam).
- Runnable objects vs the original Matchmaking place: only WindowGlassController, Openings (glass), House.MapInfo, HouseBounds
  (House) and SmokeAlarm, SmokeAlarmController (this).
- **Bot match (match place, me + BotManager AI, House voted):** chirps run by themselves (seen at 10 s / 28 s gaps); my client plays
  a natural chirp with the LED on Neon. AI 15 studs away, real `_perceive` + `HearNoise(quiet)`: before the shot steps + reload heard;
  shot (`SmokeAlarmTestHook shoot`, a real `OnShot`) -> 0.5 s, 3.5 s, 6.5 s: neither heard; 8.0 s: both heard again; broken stays.
  After a reset: walker in the blare / AI out: not heard; walker out / AI in: not heard (listener rule); both out: heard; the landing
  above is not masked. Client: blare on in 12/20 samples (the on/off pattern), LED flashing, housing hung 38 deg (now 28).
- **Two players (Studio Server + 2 Players, House voted by both):** a forced chirp of SmokeAlarm_U played on BOTH clients (age
  0.04 / 0.06 s, LED Neon). Player1 walking under the ground alarm, Player2 40 studs away in the living room: P1's steps on P2's client
  0.160 every step with no blare (baseline run); 0.010 muffled during the blare; 0.160 again after it. Shot, then a real round end
  (`MatchTestHook kill`): both clients `AlarmBroken` true, then nil 3.3 s later in the next round, the housing shut on both, score 1-0.
  Test-only RoundManager patch (count Studio players -1 / -2 as real, marker SA2P TEST) reverted: 0 marked scripts left.
- **Lobby pad duel** (`DuelTestHook solo`, House voted, arena D1 at 4000, 100, 0): the clone binds 30 dynamic pieces (28 windows +
  2 alarms); a shot (`DuelTestHook shot`) broke the Solid G (cause Bullet, 7.0 s), U untouched; this client: blare on 10/15 samples,
  masked at 10 and 27 studs, not at 30, not upstairs, listener rule true, housing open. The bot killed -> next round: whole again
  after 3.3 s. Output log: no errors (only the usual ProfileService / MemoryStore offline lines).
- Captures (lobby copy, with the House art): `captures/smoke_alarm/sheet_close.png` (before / broken),
  `captures/smoke_alarm/sheet_wide.png` (the cross hall ceiling before / after); match copy close-ups (no art) `closeup_*.png`.

## Notes and open items
- Studio's footstep sounds: the first two samples of the first two-player run read 0.000 (Player2 had just been moved); the clean
  baseline run read 0.160 on every step. Not from the alarm (it was quiet then).
- Melee reach (round 2, measured in Play through the real `OnMelee`): melee weapons reach 5-7 studs. Downstairs (13-stud ceiling)
  no swing from the floor reaches the alarm (knife 6 and katana 7 both left it whole, standing; a hop of 2.2 next to the column
  could just let a katana reach, computed, not played). Upstairs (12-stud ceiling) a 6.5-7 swing right
  under it does (same room, nothing between). Never from above it, never through a floor (the grader's round-1 major, fixed).
- The one Studio window rule: the session waited ~4 h for two or fewer open windows; it then opened its single window while four
  were open, two of them left behind by sessions that had ended (glass, the kit keeper's test).

## Round 2 (after grader round 1: roblox-systems-grader xhigh, FIX 8.4, 0 blocking, 2 major)
1. **Major, fixed: melee broke the downstairs alarm through the landing's floor** (no wall test; "straight overhead" accepted any
   facing). `Set:Melee` now needs the alarm at or above the head and nothing of the map's collision between (`Set:Blocked`).
2. **Major, fixed: in lobby duels a grenade upstairs broke the alarm below:** the hub's `ArenaShootables:wallBetween` skips every
   horizontal face (written so a floor-level blast isn't stopped by its own floor). The alarm set now has its own wall test,
   `Set:Blocked`, over the map's collision (match: every placed map's CollisionProxies; lobby: the arena's Solid layer), floors
   and ceilings included, the alarms themselves excluded. Used by melee and blasts in both places.
3. Minor, fixed: the listener rule sat behind `Steam.Fill`'s gate in `FillMuffled` (Fill off = the alarm's rule off). The hook is now
   the first line of `FillMuffled` (unit test with Fill off).
4. Minor, fixed: the reach note (above), `MeleeReach` 1.5 -> 0.
5. Minor, fixed: no House in the place = the installer writes nothing at all (returns before any check or write).
6. Minor, fixed: unit tests for a slab between (melee + blast from the floor above), a wall between, Fill off, map not in play.
7. Nit, fixed: a stray model-version attribute on the new ModuleScripts.
8. Nit, fixed: alarms on a map that isn't being played don't chirp (`isLive`: the map named by ReplicatedStorage.ArenaMap).
9. Kept, for Edward's ear: the chirp / blare sound is the game's existing beep (already used live for gadget beeps), pitched.
10. The grader could not repeat the two-player and lobby runs (one-window rule); the evidence is above.

Round 2 results: installer round 2 (round 1 UNDOne on both copies first with `git show 5fe0db6:fix/smoke_alarm.lua`):
match 90fedd14 -> f3eb80c8, hub ebdcaa18 -> 6604b698; second run all "=", UNDO back to the before hash; glass r1 DRY all "=" /
UNDO all "+" on both. Unit tests **42/42** match, **37/37** hub. Play, match place (House voted, the real `OnMelee` / `Explode` /
`OnShot` via the hook): melee from the landing straight over G (3 facings, reach 7) and 4 off facing it: G whole; frag on the
landing over G and 5 off: G whole; knife 6 / katana 7 from the hall floor under G: whole; a MID-AIR frag 6 under G (y 8.5): Blast;
bullet from the hall: Bullet. Lobby pad duel (DuelTestHook explode, arena D1): frag on the landing over G and 5 off: G whole (the U
result there was a mid-air frag; a frag ON the landing floor left U whole at radius 11 x 1); a mid-air frag in the hall: Blast. Output: no errors.

## Round 3 (after grader round 2: roblox-systems-grader xhigh, FIX 8.7, 0 blocking, 0 major; both round-1 majors confirmed fixed
## in lobby Play through the real Combat.Melee remote and ArenaShootables:Explode). No round 4 (speed rule: two grader rounds).
1. Lobby melee after the round: the hub's MeleeManager re-checks only health after the wind-up (older code, not this feature's), so a
   swing finishing after combat ends could still break an alarm. Both melee hooks now skip the alarm when combat is off (lobby: the
   arena state's `CombatEnabled`; match: ReplicatedStorage's). **The older lobby gap itself (the swing still hurts a player) is left
   for its owner: an anchor fix in the hub's MeleeManager adding the [SWITCHNOW]-style CombatEnabled re-check after `task.wait(HitDelay)`.**
   Code-only (the race isn't reachable from a test hook).
2. A frag lying on the floor never reached either ceiling alarm (radius 11; G 12.9-13.0 above the hall floor, U 11.6 above the
   landing): `BlastScale` 1 -> 1.25. Lobby Play: a frag on the open hall floor 13.0 below G: Blast; on the landing floor 2 off G:
   G whole (the slab); behind the display column: whole (the column is between: correct cover).
3. Two players re-run on round 3 (match copy, Server + 2 Players, House voted by both): chirp on both clients (0.04 / 0.05 s, LED
   Neon); P1's steps on P2: baseline 0.160 (two 0.000 start-up samples, also in this no-alarm run), blare 0.010 muffled, after 0.160;
   shot -> both clients broken -> MatchTestHook kill -> next round 3.3 s later both whole, housing shut, score 1-0. Patch reverted.
4. Unit tests: a case decided only by the wall test (in reach, facing, wall between: nothing; same swing without the wall: breaks),
   a frag on the floor 13 below, `Enabled = false` (no break, no mask). **47/47 match, 42/42 hub.**
5. Docs fixed (header, module comment on the melee rule, reach note, test descriptions). Kept: the ArenaShootables melee wrapper sits
   below the "Per frame" header because the glass installer's inserted text ends in the middle of that header line (anchoring
   above it would split the glass's text).
Installer round 3 (round 2 UNDOne first with `git show 4b7a81f:fix/smoke_alarm.lua`): match 90fedd14 -> 82903312, hub ebdcaa18 ->
595894e2; second run all "=", UNDO back to the before hash; glass r1 DRY all "=" on both.

## Grader verdicts
- Round 1 (roblox-systems-grader, xhigh): FIX 8.4 (2 majors: breaking through the floor by melee, and by blast in lobby duels).
- Round 2 (fresh, xhigh): FIX 8.7, 0 blocking / 0 major; both majors confirmed fixed in lobby Play. Its minors are fixed in round 3
  (not re-graded: two grader rounds at most). Still open for its owner: the hub MeleeManager's missing CombatEnabled re-check
  after the wind-up (older code; the alarms are guarded).

## Publish: NOT DONE (2026-10-28 10:55)
The House itself was not published: its map grade ended FIX 8.4 after the 4 allowed rounds, so its publish waits for Edward
(`notes/house_build.md` "Ready to publish"). The alarms ride on that port; nothing of this was installed on match_place_ref, the
lobby copy, or any published place. When Edward says go, add to the House's port steps:
- step 2 (match_place_ref.rbxl), right after `fix/map_house.lua`: `python tools/smoke_alarm_build.py --run <ref id>` (expect round 3
  install, 10 "+", both alarms placed), then `python tools/run_luau_at.py <ref id> fix/smoke_alarm_tests.lua` (47/47).
  port_prep.sh copies the ref, so Matchmaking / Ranked carry it.
- step 4 (lobby), after `fix/house_lobby_prep.lua` and BEFORE `fix/duel_split_map.lua` ONLY = 'House': run the installer on the lobby
  (hub: 14 "+"; if the port already brought the alarms in from the ref it reports them "=") and the tests (42/42); the split then
  copies them into Visual / Solid (7 parts each).
- Read-back: `SmokeAlarmRound` = 3 on ShootableManager; Workspace.House.Shootables.SmokeAlarm_G / _U (match);
  ReplicatedStorage.DuelMaps.House.Visual + ServerStorage.DuelMaps.House.Solid hold both (lobby).
