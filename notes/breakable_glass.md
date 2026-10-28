# Breakable window glass, 2026-10-28 [GLASS]

Work order (Lead plan, approved by Edward): "windows let bullets through and the glass breaks, but not the frame, so nobody can
leave". A general shootable for the new map House (map builder waits for `notes/breakable_glass_DONE.md`).
Picture: `captures/breakable_glass/glass_before_after.png` (match place, one real pistol shot).

## Conventions (for map builders)
| Piece | How | What the game does with it |
|---|---|---|
| **Window** | a Model under the map's `Shootables` folder, attribute `Shootable = "Glass"` (string) | found by attribute, never by name |
| `Glass` | child: a Part / MeshPart, or a Model / Folder of parts (the panes) | made CanCollide / CanQuery / CanTouch **off** at run time: never stops a bullet, the cover probe, the camera or a player |
| `BrokenGlass` | optional child: part or model, the jagged leftovers, authored **visible** | hidden while the pane is whole, shown when it breaks |
| **Barrier** | a Part tagged `WindowBarrier` filling the opening (at least the wall's thickness) | set at run time: Transparency 1, CanCollide on, CanTouch / CanQuery off, collision group `WindowBarrier` |
| **Door** (later) | a Model with attribute `DoorState = "Closed" \| "Open" \| "Locked"` | read by `Openings.DoorState`; `Openings.OnDoorState` is the empty hook a door mechanic goes into |
- Window frames are ordinary map walls (they stay). Railing barriers may use the same tag (blocks bodies only).
- The map must be a MapRegistry entry placed in Workspace of the match places (ShootableManager scans every placed registry map).
- Lobby pad duels: the window model exists under `Shootables` with the **same name** in both the Solid and the Visual layer; the
  barrier only in Solid. The window must be inside the arena box (MapInfo.Size + 20 studs), like every arena shootable.

## How it works
- **Why a collision group:** `CanQuery = false` does nothing while `CanCollide` is on (measured: a CanCollide + !CanQuery part is
  still hit by Raycast, Spherecast and GetPartBoundsInBox). The barrier sits in the group `WindowBarrier`, which collides only with
  `Characters` (players and the AI, PlayerRegistry / BotManager) and `DuelQueued` (lobby pads). Every ray and spatial query in the
  game uses the `Default` group, so bullets (client and server), the AI's sight and shots, the cover probe and the camera never see it.
  The installer registers the group in the place; the server sets it again at start.
- **Breaking (server):** ShootableManager (match places) / ArenaShootables (lobby, per arena) test every intact pane against
  - every shot: the segment from the muzzle to where the bullet stopped (`OnShot`, players and the AI);
  - every blast: closest point of the pane within the blast `Radius`, no wall between (`Explode`: frags, barrels, gadgets);
  - every melee swing after its wind-up: MeleeManager calls `ShootableManager.OnMelee(root, look, reach, angle)` (lobby: the stub
    routes it to the duel arena at that point).
  The first one sets `GlassHitAt`, `GlassHitDir`, `GlassCause` (Shot / Melee / Blast), `GlassBrokenAt` (server time) and then
  `GlassBroken = true`. The hit itself is untouched: the bullet goes on and the hit behind the glass lands. Match places: the AI hears
  a pane break (`NoiseRadius`) and `ShootableManager.OnGlass` fires (window, cause, by).
- **Look (client):** Match places: `WindowGlassController` binds every window ShootableManager tagged `WindowGlass`. Lobby duels:
  `ArenaLoader` binds the Visual twin of each Solid window (only that match's players have the clone, so only they see it).
  `Openings.BindClient`: pane `LocalTransparencyModifier` 1, BrokenGlass 0, and for a break under `ShatterWindow` s old: ~18 glass
  shards from the pane (thrown along the hit), a glitter puff, the game's own Glass impact sounds (ImpactSounds, two layers, lower
  pitch). Late joiners see it broken without the shatter. No new remote: all from replicated attributes.
- **Scope:** one match per match server (attributes on the map everyone in it sees); lobby duels per arena (Solid attributes; only
  bound clients draw them).
- **Reset:** `ShootableManager.ResetAll` / `ArenaShootables:ResetAll` (every round) set `GlassBroken = false` and clear the rest.
- **Nobody leaves:** physics stops walking, jumping and the cover dash (MoveTo) at the barrier. Vault, climb and dive move the body
  by CFrame (no physics), so CoverController stops them itself (`Openings.BarrierBetween` each frame) and the AI's vault refuses an
  arc through a barrier (`Openings.BarrierOnArc`). The camera's own box test for CanCollide/!CanQuery blockers skips barriers, and
  the AI's cover finder never makes a barrier a cover spot.

## Config (`ShootableConfig.Glass`)
| Knob | Default | Meaning |
|---|---|---|
| `Enabled` | true | false: panes never break (bullets still pass) |
| `HitPadding` | 0.1 | studs around a pane for the bullet test |
| `MeleeReach` | 1.5 | a swing reaches a pane this much further than a body |
| `BlastScale` | 1 | panes break within blast Radius x this |
| `NoiseRadius` | 50 | the AI hears a break this far (match places) |
| `Shards` / `ShardLife` | 18 / 2.5 | shards per window, seconds |
| `ShatterWindow` | 1.5 | only a break this recent plays the shatter |
| `SoundVolume` / `SoundPitch` | 1.3 / 0.8 | x the Glass impact set |
| `BarrierGroup` / `CharacterGroups` | "WindowBarrier" / {"Characters","DuelQueued"} | the barrier's group and what it blocks |

## Files
- `fix/breakable_glass.lua` installer **round 1**, one file for both kinds of place (finds out which: hub = LobbyMap + ArenaShootables).
  Built by `python tools/breakable_glass_build.py [--run <studio_id> [UNDO] [DRY]]` from `fix/breakable_glass/*.lua`. Edit mode.
  Match places need steam fill round 5 first (it anchors on that text; asserts the stamp). Checks every anchor (found once, at a
  token boundary) in every target and the new module names, compiles every edited source, then stamps `GlassRound = 1` on
  ShootableManager before the first write; refuses another round or an unstamped `[GLASS]` edit. UNDO restores the exact text.
  - Match: 15 edits (ShootableConfig, MeleeManager, CameraController, CoverController x3, BotManager x2, ShootableManager x7) +
    `Shared.Openings` + `Controllers.WindowGlassController` + the collision group.
  - Hub: 16 edits (ShootableConfig, MeleeManager, CameraController, CoverController x3, ShootableManager stub, ArenaShootables x6,
    ArenaLoader x3) + `Shared.Openings` + the collision group. (`scripts/duels/*` in the repo were not touched: the installer edits
    the place's scripts; refresh the repo copies when the hub is ported.)
- `fix/breakable_glass/`: `Openings.lua` (the rules), `WindowGlassController.lua`, `ShootableConfig_Glass.lua`, `TestHook.lua`
  (Studio-only `ServerStorage.GlassTestHook`: windows / shoot / melee / blast / reset).
- `fix/breakable_glass_tests.lua` unit tests (Edit mode, fresh module clones, fake windows 3000 studs up, cleans up).
- `tools/breakable_glass_testwindow.lua` TEST ONLY: a wall with a 6 x 5 window (Glass, BrokenGlass, barrier) on a test copy.

## Tests (own copies: `out/breakable_glass/test.rbxl` from Matchmaking_place.rbxl 01:43 (no newer lock), saved with the install +
## test window; `out/breakable_glass/lobby_test.rbxl` from Tacticals_main_ported.rbxl 04:55 Oct 27 (its lock is from Oct 25))
- Installer, match: DRY all anchors; install 15+ ; second run all "="; UNDO back to the before hash (4c4066b8); reinstall abaf35e0.
  Hub: install 16+, second run all "=", UNDO back to 1168fe70, reinstall b17cf410.
- Unit tests **59/59** on both places (glass ignored by rays; barrier ignored by default / exclude / include rays, spherecast and box
  query, hit by a Characters-group ray; group collides with Characters, not Default; shot / blast / melee hit tests incl. wall and
  angle; Break once, Reset, Enabled = false; DoorState reader; BindClient hide/show, shatter only when fresh, late bind; barrier path
  checks: through / beside / hugging and moving away / along / into, vault arc).
- **Bot match (match place, StudioTeleportData me vs bot):** real `FireWeapon` pistol shot through the window at the bot behind it:
  client ray passed glass + barrier, server accepted the hit (150 -> 120), pane broken (cause Shot), my client hid it, 18 shards.
  Melee (hook from 2.5 studs) broke it; a frag 14 studs off did not, 5 studs off did. Next round (real kill) -> GlassBroken false,
  pane back on my client. AI's ray through the window hits me; `WeaponUtil.IsPathClear` true.
  Barrier: walking (driven Move) stopped at the sill/barrier; **vault (real Space key) at the sill: barrier on -> stopped at
  z -551.7 (barrier far face -549.5); barrier off on that client -> went through to -548.2.** Output: no errors from this work.
- **Lobby pad duel (Pad_1v1_A, DuelTestSolo, Warehouse arena D1 at 4000,100,0):** Solid glass CanQuery off, barrier group set;
  Visual clone bound (9 dynamic pieces incl. the window). Real pistol shot through it: hit the bot (150 -> 120), Solid GlassBroken,
  Visual pane hidden + broken look + 18 shards. Real kill -> round 2: reset on server and client. Real melee remote ("Quick", F with
  the pistol) broke it (cause Melee). Frag 5 studs off broke it (cause Blast). Vault at the lobby sill didn't start even with the
  barrier off (inconclusive there; the guard is the same code as the match place's).
- **Not run: Studio server + 2 players.** `multiplayer.py start test.rbxl --players 2` opened only the Server window twice
  (player count 0; `TestService.NumberOfPlayers = 2` in the place didn't help), as in the steam fill work. Stopped after the second
  try as the vault says. "Both see it break" is covered by design (replicated attributes) and the late-bind unit test, not by a
  second window. Needs the player-count box set to 2 by hand (Edward) or a live two-PC test.

## Grader
Not run by this session: HQ runs a fresh roblox-systems-grader after it (HQ's instruction for this session overrides the work
order's "run the grader" step).

## Open
- Two-player Studio check (see Tests).
- Not installed on Matchmaking / Ranked / Tutorial / the hub: install with the rest of the House port, after steam fill r5 on the
  match places. The installer is the deliverable; the shipped place files were not opened.
- Thrown grenades fly through the opening without breaking the pane (only their blast breaks it). Bullets, melee, blasts as ordered.
- Doors: the DoorState reader only; no collision / tween yet.
- Lobby repo copies `scripts/duels/ArenaShootables.lua` / `ArenaLoader.client.lua` don't carry the [GLASS] edits (scripts/ was off
  limits this session).

## Lessons (for the vault, no game names)
- `CanQuery = false` has no effect on a part with `CanCollide = true`: raycasts, spherecasts and box queries still hit it. A
  "players only" wall needs a collision group that collides with the characters' group and not with `Default` (the group every
  query uses by default); characters must sit in their own group for this to work.
- A scripted move (vault, climb, dive, AI vault: CFrame each frame, often anchored) ignores physics, so a players-only wall must be
  checked by the move itself (segment vs the tagged walls' boxes), or players pass through it.
- A camera that ray-tests "CanCollide but not CanQuery" boxes itself (to see blockers raycasts miss) must skip players-only walls.
