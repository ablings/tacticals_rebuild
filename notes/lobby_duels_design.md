# Lobby duels: design (in-lobby pad matches on the Warehouse)

Status: **phase 1 built 2026-10-16, phase 2 built 2026-10-16** (see `notes/lobby_duels_phase1.md`; what differs from this design is in §0 below). The facts behind it
are in `notes/lobby_duels_survey.md`. The UI side is in `notes/ui_match_hud.md` (UI session); UI asks in `notes/lobby_duels_ui_requests.md`.

## 0. Changes since the design (2026-10-16)

### Phase 2 (2026-10-16, notes/lobby_duels_phase2.md)
- Doors / barrels / valves per arena (`ArenaShootables`); state on the Solid models, drawn by ArenaLoader. Not `ArenaDoors` +
  `ArenaShootables` as in §7: one module, and no `SolidId` follow loop (the client tweens from attributes).
- Effects scoped with `MatchState.FireScoped` (§3 "FireMatch"); gadget rays / FX per arena via `LobbyDuelManager.RayFilter / FXFolder`.
- §4 "Death in a round" / §8 respawn risk: solved by a pre-yield pivot in CharacterAdded + a server re-load into the Hold before the
  auto respawn (Player.RespawnLocation doesn't work for a hidden spawn). The Bench is the slot's `Hold`.
- Reward cooldown in the profile (`DuelPairs`), not per server.
- Map folders: name = id, `Modes` attribute authoritative; maps can be added / removed at runtime (`MapRegistry.Changed`).
- Arena lights: per-map `LightBudget` in the split (2 shadowed 120-degree spots instead of 8 shadowed point lights).

### Map registry (Edward via the lead: the Warehouse is a blueprint for MECHANICS, not for layout)
Every future map has its own layout and size, so **no duel code assumes Warehouse geometry, names or dimensions**.
- `ReplicatedStorage.DuelMaps.<MapId>` (Folder, attrs `DisplayName`, `Image`, `Modes` "1v1,..."):
  - `MapInfo` (ModuleScript, generated): `Id, DisplayName, Image, Modes = {...}, Size (bounding box), SpawnSpacing, KillDepth,
    WorkspaceName (name of the client clone), Dynamic (folders whose parts follow their Solid twin, phase 2), SourceOrigin`.
  - `Visual` (Model, client clone), `Lighting` (Configuration: Lighting attrs + effect children).
- `ServerStorage.DuelMaps.<MapId>.Solid` (Model): the collision shell + `Spawns` (`A1, A2.., B1..` markers; a team with one marker lines
  teammates up beside it, `SpawnSpacing` apart).
- Both layers are re-centred on build: template origin (0,0,0) = footprint centre at floor level, so an arena is placed with
  `PivotTo(CFrame.new(slotOrigin))` and never needs the old `TemplatePivot`.
- `MapRegistry` (`ReplicatedStorage.Modules.Shared.MapRegistry`): `List / Get / ForMode(mode) / HasMode(mode) / SlotSpacing()`.
  The vote list, the loader, the slot allocator and the spawn logic read only this. Slot spacing = max(1000, biggest footprint + 700).
- Built by `fix/duel_split_map.lua` from `ServerStorage._DuelSource.<MapId>`; one `MAPS` entry per map (model name, spawn marker paths,
  modes, lighting values). Porting a map from the match place is `tools/duel_map_port.py` (script serialisation, no clipboard).
- The dead/waiting "Bench" is no longer part of a map: LobbyDuelManager makes a `Hold` floor per slot (60 under the slot origin).

### Modes per map
- The **Warehouse is 1v1 only** (`Modes = {"1v1"}`): its size suits 1v1; 2v2 / 3v3 get their own maps later.
- MapVote's `MapList` = maps whose `Modes` include the match mode; "Random" picks among those.
- A pad mode with **no eligible map never starts an in-lobby match**: the pad stays a queue but doesn't count down. LobbyDuelManager
  sets `NoMap = true` + `NoMapText = "No maps yet for 2v2"` on the pad Model; QueueManager's `bayIsFull` [DUEL] returns false for it and
  the `QueueState` rows carry `noMap`. PadUI shows "NO 2V2 MAPS YET" (UI session, deploy 16).

### Entry point name
- The hand-off is **`LobbyDuelManager.StartMatch(pad, mode, teams)`**, not `Start(...)` as in §4/§7: ModuleLoader calls every
  manager's `.Start()` at boot, so a gameplay `Start` collides with it.

### Lead defaults on the open questions (§9) - Edward may change any of them
1. Rewards: XP + scissors + gun XP + stats exactly as a casual online match (`MatchConfig.Rewards`), but **at most one reward per opponent
   pair per 10 minutes** (`DuelRewardCooldown = 600`, per lobby server; the summary carries `RewardCooldown = true` when skipped).
2. Pad duels are **casual only, never ranked** (`DuelRanked = false`).
3. Leaving mid-match = a **loss for the leaver (no rewards) and a win for the other side** (forfeit).
4. The vote shows **Warehouse + Random** (eligible maps + Random).
5. **Up to 6 concurrent arenas** (`MaxArenas = 6`; the allocator is written for N).
6. Spectate (phase 3) from **both** the Duels TV and a pad prompt; the spectator's character **stays in the lobby**.
7. Restyle the Warehouse later. 8. The collision shell is acceptable. 9. MatchCore in the match place comes later (phase 4).

Edward's request:
- The duel **pads** (QueueManager, 6 pads: 1v1/2v2/3v3) run the whole match **inside the lobby server**, with no teleport, on a port
  of the match map. "Garage" is the match place's `Workspace.Warehouse`; nothing is called Garage in either place.
- The map **loads only on the clients of the players and spectators**, so the lobby doesn't lag.
- **PLAY** (MatchmakingManager, global queue) keeps teleporting to the match place.
- Both flows look like RIVALS: teleport/loading screen, map vote (Warehouse + Random), loadout pick, rounds, results.

## 1. Recommended architecture (one paragraph)

Each pad match gets an **arena slot** far outside the lobby. The arena is split in two layers:
- **Visual layer, client only.** All 518 instances, made non-colliding. It sits as a template in `ReplicatedStorage.DuelMaps.Warehouse.Visual`.
  The template is never in Workspace, so it is never rendered or simulated. Only the duelists' and spectators' clients clone it into their
  own Workspace at the slot's offset, and they destroy it after.
- **Solid layer, server.** Just the 107 invisible collision parts: proxies, prop and barrel colliders, door shutters, spawns. The server
  parents it into `Workspace.DuelArenas.<matchId>`.
  - It must be in the server's Workspace. Grenades are server-simulated physics, and shot, melee and smoke wall checks are server
    `workspace:Raycast` calls. A WorldModel or client-only collision would let grenades fall through the floor and bullets go through walls.
  - Cost to a lobby client: about 107 invisible, anchored, shadowless parts per live arena, at least 4,000 studs away. Nothing is drawn.
    For comparison, the lobby is 7,644 parts.

All match state lives on a per-match state object, `ReplicatedStorage.LobbyDuels.<matchId>`. It carries the same attribute names the match
place puts on `ReplicatedStorage`. One HUD (the UI session's) serves both places.

The round rules move out of the match place's `RoundManager` into a shared `MatchCore` module that both places run:
- one instance per match in the lobby;
- one per server in the match place.

## 2. Arena instancing

- **Slots:**
  - Slot origin = `Vector3.new(4000 + 1000 * (slot - 1), 100, 0)`, slots 1..`MaxArenas` (default **6**, one per pad).
    Lobby parts end at x 621, so slot 1 is more than 3,300 studs from the lobby.
  - Slots are 1,000 apart. That is more than the longest weapon range (600) plus the 120-stud arena, so no ray from one arena reaches another.
  - Ground y is 100. That keeps clear of three existing rules:
    - LobbyFallCatch (y < -25 → hub spawn);
    - FallenPartsDestroyHeight (-500);
    - TrainingManager's "not in training and y > 540 → hangar".
  - Offset = `slotOrigin - templatePivot`, where the template pivot is the Warehouse pivot (-84.2, 9.4, 7.5) with its floor top at y 0.
- **Not visible from the lobby:**
  - The Visual layer never exists on lobby clients.
  - The Solid layer is invisible.
  - Duelists' characters are 4,000+ studs away, and lobby clients also hide them (see §4).
  - The Warehouse is enclosed (COLP_Ceiling, walls, shutters + OutOfBounds at both doors), so duelists don't see out either.
- **Floor:**
  - The match place's Warehouse also stands on a 2048-stud Baseplate. The Solid layer gets its own **`KillFloor`**: invisible,
    CanCollide false, CanTouch true, 40 studs under the arena floor, 400 x 1 x 400.
  - Anything that slips through counts as dead (`hurt` → 0) instead of falling 600 studs.
  - LobbyDuelManager also checks `root.Y < slotY - 30`.
- **Slot exhaustion:** if every slot is busy when a pad finishes its countdown, the bay stays in `Countdown` showing **"ARENAS FULL - WAITING"**
  and re-checks every second. Players can step off as usual (it cancels as today).

## 3. Client-only map loading

### Where the template lives (decision: ReplicatedStorage)
| Option | Lobby client cost | Complexity | Verdict |
|---|---|---|---|
| **`ReplicatedStorage.DuelMaps.Warehouse.Visual`** | ~518 instances in memory (a few hundred KB). Meshes/SA textures are only fetched when first rendered or preloaded. No render, physics or script cost | trivial: `Clone()` + reparent | **recommended** |
| Per-player delivery: server parents a clone into `player.PlayerGui` (replicates only to that player), the client moves it to Workspace | zero for non-participants | more moving parts: a race with ResetOnSpawn, cleanup, a send per match | keep as the plan B if there are many maps |
| WorldModel / server-only | n/a | the server still needs collision in Workspace (grenades, rays) | rejected as the *only* layer (see §1) |
| StreamingEnabled + `ModelStreamingMode.PlayerSpecific` / `RequestStreamAroundAsync` | would hide the Solid layer too | **not applicable:** streaming is off, and turning it on breaks dozens of direct `WaitForChild`/`FindFirstChild` paths (hooks.md §4) | rejected |

### The two layers (built once by an edit-time split script, `fix/duel_split_map.lua`, with UNDO)
- **`ReplicatedStorage.DuelMaps.Warehouse`** (Folder, attrs `DisplayName = "Warehouse"`, `Image = <asset id>`, `TemplatePivot` (CFrame)):
  - `Visual` (Model): the whole Warehouse with **every BasePart CanCollide/CanQuery/CanTouch = false**. ProximityPrompts are removed (the
    real ones are in Solid). Lights, SurfaceAppearances and the crate SurfaceGuis stay.
    - Each part that has a twin in Solid gets attribute `SolidId = n`.
  - `Lighting` (Configuration): the match place's Lighting values plus clones of Sky / Atmosphere / Bloom / MapGrade.
    ArenaLoader swaps them in locally and restores the lobby's afterwards.
- **`ServerStorage.DuelMaps.Warehouse.Solid`** (Model), cloned by the server per match:
  - The 107 parts that collide, query or touch, with names, sizes, CFrames, CanCollide/CanQuery/CanTouch, CollisionFidelity and
    Shootables/Props folder structure kept.
  - **Transparency 1, CastShadow false.** SurfaceAppearances, SurfaceGuis and lights are removed. MeshParts keep the MeshId, which collision needs.
  - Each part has `SolidId = n`.
  - Plus:
    - `Spawns/SpawnA`, `Spawns/SpawnB` (from MatchSpawns);
    - `Bench`: a sealed 12 x 8 x 12 invisible box 60 studs under the floor, for dead or respawned players (§5);
    - `KillFloor`;
    - the doors' `Panel` ProximityPrompts.

### Loading and unloading (client `ArenaLoader`)
1. It watches `DuelMatch` / `DuelSpectate` on the LocalPlayer and the state object's `MapChosen` + `ArenaOrigin`.
2. When both are set: `ContentProvider:PreloadAsync(visual meshes + SA)` behind the loadout screen, then
   `clone = DuelMaps[map].Visual:Clone()`, `clone:PivotTo(CFrame.new(ArenaOrigin) * templateRotation)`, and name it **`Warehouse`**.
   - It is parented to `workspace`, so `CoverController`'s existing `workspace.Warehouse` lookups (Props/Shootables excluded from cover)
     keep working unchanged. Only one arena is ever loaded per client.
3. It swaps Lighting (local), then sends `MatchFlow:FireServer(matchId, "Loaded")`.
4. **Dynamic pieces follow the Solid layer:**
   - Each RenderStepped, a visual part with `SolidId` that is in the "dynamic" list (door shutters, barrel bodies) copies its Solid
     twin's CFrame. Doors tween on the server and replicate.
   - Barrel explode/reset: the server sets attribute `Exploded` on the Solid barrel model; the client hides or shows its visual barrel.
   - Steam: the client reads the existing `SteamUntil` attribute and plays the jet locally.
   - Door LEDs: attribute `DoorOpen`.
5. It unloads when `DuelMatch`/`DuelSpectate` clears, or when the state object is destroyed: destroy the clone, restore Lighting.

### Physics, anti-cheat and other players
- **Own character:** client-simulated. It collides with the replicated Solid layer exactly as the server sees it. No divergence.
- **Other players' characters:** replicated as usual, so they are visible to everyone in the same arena.
- **Projectiles and gadgets:** server-owned grenades bounce on the Solid layer. Smoke cells stop at its walls (`mapRay` must read the arena's
  `CollisionProxies`, §7).
- **Server validation stays authoritative:** `IsPathClear`, muzzle checks and melee wall checks hit the Solid layer, which is in `workspace`.
- **Cross-arena and lobby isolation:** a [DUEL] guard in Combat, Melee, Shootable and Gadget damage. Damage only applies when the attacker and
  the victim have the same `DuelMatch` (or neither has one, as in Training). A duelist can never hurt a lobby player, and the other way round.
- **Doors and shootables state:** server state only. Clients render it from attributes and the Solid twin's CFrame. Nothing about the state is client-trusted.
- **What non-participants see:** nothing. Lobby clients don't have the Visual layer. The Solid layer is invisible. Duelists are 4,000+
  studs away, and `NameplatesController` [DUEL] hides plates of anyone with `DuelMatch` unless the local player is in or spectating that
  match. An optional `DuelVisibility` client script sets `LocalTransparencyModifier = 1` on such characters, as a belt-and-braces measure
  against FOV tricks or zoomed scopes.
- **Leftover cost per live match on every lobby client:** the Solid layer (~110 instances), the duelists' characters and remote traffic
  (`WeaponFired`/`Explosion`/`FlashDetonated` are FireAllClients). The [DUEL] edits narrow those three to match members + spectators in
  the lobby (`MatchCore.FireMatch`), so lobby clients get no combat traffic.

## 4. Match flow (lobby)

| # | MatchState / MatchPhase | What happens |
|---|---|---|
| 0 | (pad) | QueueManager as today: zones, slots, the 5 s countdown. A step-off cancels. |
| 1 | `Loading` / `Loading` (≤3 s) | QueueManager's `deploy(bay)` calls `LobbyDuelManager.Start(bay, teams, ranked)` instead of teleporting (flag `LobbyConfig.PadDuelsInLobby = true`; false = the old teleport). The server reserves a slot, creates the state object, sets player attrs (`DuelMatch`, `InDuel`, `Team`, `InMatch`...) and keeps roots anchored (`Deploying` stays true). The client shows the teleport/loading card (same screen as the match place). The bay is released (slots freed, `resetBay(bay, false)` without kick-off, 3 s cooldown), so the pad is free for the next group while this match runs. |
| 2 | `MapVote` / `MapVote` (10 s) | `MapList` = `[{id="Warehouse", name, image}]`; the UI adds "Random". Votes come in through MatchFlow. Most votes wins, ties random, Random resolves to a real map. Then `MapChosen` is set. Skipped (MapChosen set at once) if `LobbyConfig.DuelMapVote == false`. |
| 3 | `Loadout` / `Loadout` (15 s, ends early when everyone is `Ready` **and** `Loaded`) | The server publishes `OwnedItems` + current `Kit*` and validates `Pick`. `ArenaOrigin` is set at the phase start, so clients load the arena **behind the loadout screen**. The Solid layer is parented now. At the deadline, a client that hasn't sent `Loaded` gets 5 s more, then counts as left (forfeit for that player). |
| 4 | `Countdown` / `Playing` (3 s) | Per round `MatchCore.playRound`: `ResetAll` shootables/doors/smoke **of this arena**, then `LoadCharacter` + `PivotTo(spawnFrame)` + freeze, as the match place does. The client fades in from black. |
| 5 | `Live` / `Playing` (90 s) | Combat on (`CombatEnabled` on the state object). Win checks as in RoundManager. |
| 6 | `RoundEnd` / `Playing` (3 s) | Score, announce. Loop to 4 until `RoundsToWin`, or `MaxRounds` 9. |
| 7 | `MatchEnd` / `Ended` (12 s) | `MatchResults` per player. Rewards are written through `PlayerStore` (Replica, so the lobby HUD updates). |
| 8 | (return) | Fade out. `LoadCharacter` at the bay's `stepOffCFrame` (or the Duels hall start if the pad is busy). Clear the attrs, unload the arena on clients, destroy the Solid layer + state object, free the slot. TrainingManager strips the tools again by itself. |

### Port vs adapt (match place → lobby)
| Piece | Plan |
|---|---|
| `playRound`, `playMatch`, team helpers, win rules, draw/timeout/forfeit, `MaxRounds`, kill tally (`hookDeaths`), `eloDelta`, `award` maths | **Port** into `MatchCore` (shared ModuleScript, identical source in both places; hash-checked with `tools/dump_scripts.lua`). Every `ReplicatedStorage:SetAttribute` becomes `ctx.state:SetAttribute`, `Announce:FireAllClients` becomes `ctx.fire`, `spawnFrame` becomes `ctx.spawnFrame`, and the profile access becomes `ctx.profile` (match: raw `DataManager:Get`; lobby: `PlayerStore` writes). |
| `runMatchServer` (arrival, kicks, teleport back) | **Match place only**; it calls MatchCore. |
| `applyOwnedLoadout` | **Adapt:** becomes `MatchCore.applyKit(player, picks, owned)`. It sets `KitWeapon/KitMelee/KitGadget` **and** mirrors `Loadout = KitWeapon`, which CombatManager and KitGuard read. |
| MapVote / Loadout phases | **New** in MatchCore, used by **both** places (the match place gets the RIVALS flow too). |
| `MatchConfig` pass 38 fields (Rewards, ResultsTime, MaxRounds, StartingRating, PlayerHealth) | **Copy** the match place's MatchConfig to the lobby (superset; the lobby's TestMode line is irrelevant there) + `DuelMapVote`, `MapVoteTime 10`, `LoadoutTime 15`, `LoadingTime 3`. |
| CombatManager / MeleeManager pass 38 friendly-fire + `LastHitZone/LastAttackKind/LastAttacker` | **Port** the missing lines to the lobby copies, reading `MatchState.For(player)` instead of global `LiveMatch`. |
| ShootableManager | **Adapt:** turn it into a per-arena object `ArenaShootables.new(solidRoot, ctx)` (valves, barrels, props, fires, burn). The lobby stub's Training bullseye hook stays in `ShootableManager.OnShot`, which also routes a shot to the arena whose slot box contains `origin`. |
| DoorManager | **Adapt:** `ArenaDoors.new(solidRoot)`, with `CloseAll()` called by MatchCore per round (the match place forgot to). |
| GadgetManager | **Small edits:** `mapRay` uses the arena's `CollisionProxies` found from the grenade's position (slot lookup); `ClearAll(region)` only clears cells/grenades inside the arena's box. |
| PlayerRegistry `MaxHealth 150` | **Adapt:** LobbyDuelManager sets `MaxHealth/Health = MatchConfig.PlayerHealth` on round spawn; return-to-lobby `LoadCharacter` restores 100. |
| KitGuard | **Port** to the lobby, gated by `InDuel` + `MatchState.For(p).LiveMatch`. |
| BotManager, TutorialManager, RangeManager, FiringRange, AnimRig | **Not ported.** |

### Edge cases
- **A pad player steps off during the countdown:** unchanged (the countdown is cancelled, "Someone stepped off").
- **No free slot at countdown end:** stays in Countdown, "ARENAS FULL" (§2).
- **Leave mid-match:**
  - The HUD's LEAVE sends `("Leave")`. The player counts as not present: if their whole team is gone, the other team wins by forfeit
    (RoundManager's rule).
  - The leaver gets no rewards and returns to the lobby at once.
  - A **leave penalty** is an open question.
- **Disconnect:** `PlayerRemoving` means not present, same as leave. The profile is released by DataManager as usual. A match with a whole team gone ends.
- **Death in a round:**
  - The lobby has `CharacterAutoLoads = true`, so Roblox respawns the player at the lobby spawn after `RespawnTime`.
  - LobbyDuelManager hooks `CharacterAdded` for `InDuel` players. Mid-round, the new character goes straight to the arena **Bench**,
    anchored, with tools stripped, so it never appears in the lobby.
  - The player gets `Alive = false`. The client spectates live teammates (RIVALS), or anyone once the whole team is dead.
  - The next round's `LoadCharacter` + `PivotTo` brings them back.
  - Lobby players may see the duelist's lobby-spawn frame for at most one tick; `PivotTo` happens in the same CharacterAdded callback.
- **Falling out:** KillFloor or the y check counts as a death.
- **A spectator joins or leaves:** `("Spectate", matchId)` / `("StopSpectate")`. The client loads or unloads the arena and nothing else changes.
  Spectators are capped at `DuelMaxSpectators = 12` per match. They are dropped automatically when the match ends.
- **Duelists:** can't spectate, can't join pads, PLAY, Training or Exfil while `InDuel`. The [DUEL] guards go in QueueManager.findSlotAt,
  MatchmakingManager search, `Events.Training.Enter` and ExfilBarrier. The UI session hides those buttons.
- **The server shuts down mid-match:** nothing is saved for that match. Rewards are only written at MatchEnd.
- **The same player in two matches:** impossible; `Start` refuses players that already have `DuelMatch`.
- **A ranked pad:** handled by MatchCore's Elo, if Edward wants ranked pads (open question).

## 5. Spectators

- **Entry points:**
  1. A **WATCH** row button on the Duels TV (`LobbyScreensController`). `LF_LiveDuels` gains in-lobby matches: `{id, mode, a = names, b = names, score, lobby = true}`.
  2. A "WATCH" ProximityPrompt (attr `DuelWatch = <bay key>`) on each pad's Holo while its last match is live.
  3. A PadUI side button.
  All three send `MatchFlow:FireServer(matchId, "Spectate")`.
- **Server:** validates the cap, that the player is not `InDuel`, `Deploying` or `InTraining`, and that the match is past MapVote. Then it sets
  `player.DuelSpectate = matchId` and adds the player to the match's fan-out list. **The spectator's character stays where it is in the lobby**
  (root anchored by the server while spectating, so it can't be pushed). Other lobby players see them standing at the TV, like RIVALS.
- **Client:**
  - ArenaLoader loads the arena (the same path as duelists).
  - The camera goes to `Scriptable` follow-cam on `SpectateTarget`. This is client-local; Q/E cycle through alive players of the match,
    and the camera snaps to the next one on a death.
  - The duel HUD shows in spectator mode (no hotbar).
- **StopSpectate or match end:** unload, restore the camera, unanchor.

## 6. Interface contract (for the UI session)

Aligned to `notes/ui_match_hud.md`. **Its names are kept.** The match place's existing names are kept alongside where they already exist
(no renames on either side). Lobby-only items are marked (L).

### State object
- Match place: `ReplicatedStorage`.
- Lobby: `ReplicatedStorage.LobbyDuels[<id>]`, a **Configuration** named by matchId (e.g. `"D12"`).
  - Its id = `player.DuelMatch`, falling back to `player.DuelSpectate` (L).
  - The resolver is in the shared module `ReplicatedStorage.Modules.Shared.MatchState`: `MatchState.For(player) -> Instance?`,
    `MatchState.MatchId(player) -> string?`, `MatchState.Role(player) -> "Player" | "Spectator" | nil`.
  - The server uses it too.

| Attribute | Type | Notes |
|---|---|---|
| `MatchId` (L) | string | = the object's Name |
| **`MatchPhase`** | "Loading" / "MapVote" / "Loadout" / "Playing" / "Ended" | the UI's flow screens (from ui_match_hud.md). "Playing" covers Countdown/Live/RoundEnd. |
| **`PhaseEndsAt`** | server time | **always equal to `StateEndsAt`** (both are written by one `setState`). |
| `MatchState` | "Loading" / "MapVote" / "Loadout" / "Countdown" / "Live" / "RoundEnd" / "MatchEnd" (+ "Waiting", "Tutorial", "Cancelled" in the match place) | **existing match place name**, fine-grained; the in-duel HUD uses it. New values only extend it. |
| `StateEndsAt` | server time | existing; the round timer = `StateEndsAt - workspace:GetServerTimeNow()` in Countdown/Live/RoundEnd. |
| `MapList` / `MapVotes` / `MapChosen` | JSON / JSON / id | as ui_match_hud.md. `MapVotes` = `{mapId: [userId...]}`. "Random" is never in MapList (the UI adds it); a vote for "Random" is stored under `"Random"`. |
| `RoundNumber` | int | existing |
| `RoundsToWin` | int | new (3) |
| `ScoreA` / `ScoreB` | int | existing |
| `MatchMode` / `MatchRanked` | "1v1"... / bool | existing |
| `CombatEnabled` | bool | existing; in the lobby it is per match (read by the [DUEL] combat edits) |
| `LiveMatch` | bool | existing (true on every real match; friendly fire is off) |
| `TeamA` / `TeamB` | JSON `[userId...]` in slot order | new: team boxes and the scoreboard, without scanning players (also covers players who left) |
| `ArenaOrigin` (L) | Vector3 | the slot origin; set at the Loadout start |
| `Spectators` (L) | int | count, for "N watching" |

### Player attributes
| Attribute | Type | Notes |
|---|---|---|
| `DuelMatch` (L) | matchId | player of that match (from Loading until the return) |
| `DuelSpectate` (L) | matchId | spectating that match |
| `InDuel` (L) | bool | true while `DuelMatch` is set; the gate for TrainingGate and lobby systems |
| `Team` | "A" / "B" | existing |
| `Level` | number | `LobbyConfig.AccountLevel(XP)`, set by the server at match start (both places; the match place gets a `LobbyConfig` copy for Items + levels) |
| `OwnedItems` | JSON list of item ids | from profile `Owned` + every `LobbyConfig.Items[id].Default`. **Not from TeleportData.** TeleportData carries only the equipped `Loadouts`; the match place reads the shared profile itself. |
| `KitWeapon` / `KitMelee` / `KitGadget` | item id | the UI's names. The server also mirrors **`Loadout = KitWeapon`** (the existing gameplay attribute CombatManager/KitGuard read). The UI should read the Kit names only. |
| `LoadoutReady` | bool | new: set by `("Ready")`, for the "ready" ticks on the team boxes |
| `InMatch` | bool | existing |
| `RoundWins` | int | existing (= the team score) |
| `MatchKills` | int | existing |
| `MatchDeaths` | int | new |
| `Alive` | bool | new: true at round spawn, false on death or when benched. The HUD's alive/dead pips and spectate target list use it (the Humanoid isn't reliable: dead lobby duelists respawn on the Bench). |
| `SmokeCharges` / `FlashCharges` / `FragCharges` | int | existing |

### `ReplicatedStorage.MatchFlow` (RemoteEvent, both places)
- **Client → server**, as ui_match_hud.md (lobby: matchId first; the server ignores a matchId that isn't the sender's own):
  - `("Vote", mapId)`: MapVote phase only, one vote per player, changeable.
  - `("Pick", slot, itemId)`: Loadout phase. Slot is "Weapon" / "Melee" / "Gadget". It is validated against Owned + Defaults + `Items[id].Slot`.
  - `("Ready")`.
  - `("Loaded")` (L): the arena has finished loading on this client.
  - `("Leave")`: forfeit and return (lobby) / back to the lobby (match place, after MatchEnd or as a forfeit).
  - `("Spectate")` (L): matchId = the match to watch. `("StopSpectate")` (L).
- **Server → client:** `MatchFlow:FireClient(player, matchId?, kind, data)`, with matchId nil in the match place.
  - `"Kill"`: `{killer = userId, victim = userId, weapon = id, headshot = bool, kind = "Gun"|"Melee"|"Burn"|"Explosion"}`, for the kill feed.
    Sent to match members + spectators.
  - `"Arena"` (L): `{map, origin}`, a redundant nudge when `ArenaOrigin` is set (the loader also works from the attributes alone).
  - `"Return"` (L): the fade-out cue just before the return to the lobby.

### Existing events kept, both places
- `ReplicatedStorage.Events.Match.MatchAnnounce(title, subtitle)` and `Events.Match.MatchResults(summary)`, with the same payloads as today.
  - `summary` = `{Won, Draw, Mode, Ranked, Score = {A, B}, Team, Kills, Headshots, Deaths, XP, Scissors, Multiplier, GunXP, Weapon, RatingChange, Saved}`.
  - In the lobby the folder is created by LobbyDuelManager and the events go only to that match's players + spectators.
    `summary` gets `MatchId`.

### In-duel HUD inputs (concrete)
- **Round banner:** `MatchState`, `RoundNumber`, `StateEndsAt`, `MatchAnnounce`.
- **Score:** `ScoreA`, `ScoreB`, `RoundsToWin`, your `Team`.
- **Team pips (alive/dead):** `TeamA`/`TeamB` order + each player's `Alive`. A missing player = left.
- **Kill feed:** `MatchFlow "Kill"`.
- **Spectate:**
  - Role from `MatchState.Role(LocalPlayer)`.
  - The target is client-local (the HUD owns it): cycle over `Alive` players of the match (dead duelists: own team first).
  - The HUD exposes `PlayerScripts.DuelSpectate` (BindableFunction: `Get() -> userId`, `Set(userId)`) so the camera code and the HUD agree.
- **Results:** `MatchResults` in `MatchEnd`.
- **Leave:** `MatchFlow "Leave"`.

### Renames
**None.** Two aliases are written by the server so both sides keep working:
- `PhaseEndsAt == StateEndsAt`;
- `Loadout == KitWeapon` (the gameplay mirror).

## 7. Code plan

### New
| Module | Side | Job |
|---|---|---|
| `ServerScriptService...Managers.LobbyDuelManager` | lobby server | slots, `Start(bay, teams, ranked)`, state objects, the MatchFlow handler, Solid layer clone/destroy, bench/kill-floor, spectators, return to the pads, `LF_LiveDuels` feed. Runs one `MatchCore` per match. |
| `ServerScriptService.Shared.MatchCore` | both servers (identical copy) | phases (Loading/MapVote/Loadout), rounds, win rules, kill tally, `award`, `applyKit`, `FireMatch`. Context object injected per match. |
| `ReplicatedStorage.Modules.Shared.MatchState` | both, client + server | `For(player)`, `MatchId`, `Role`, `SameMatch(a, b)`, `ArenaOf(position)` (lobby slot lookup) |
| `ArenaShootables`, `ArenaDoors` | lobby server | per-arena versions of ShootableManager / DoorManager |
| `StarterPlayerScripts.ArenaLoader` | lobby client | load/unload Visual, the Lighting swap, the dynamic follow, `Loaded`, spectator camera, fades |
| `StarterPlayerScripts.DuelVisibility` (optional) | lobby client | hides other matches' characters |
| `fix/duel_split_map.lua` (+ UNDO) | edit time | builds `ReplicatedStorage.DuelMaps.Warehouse` + `ServerStorage.DuelMaps.Warehouse.Solid` from the copied-in Warehouse |

### Small marked edits (`-- [DUEL]`; originals backed up to `ServerStorage._RebuildRemoved.DUEL_<name>_Orig` like the other passes; `fix/duel_edits.lua UNDO`)
- **Lobby:**
  - `QueueManager.deploy`: hand off to LobbyDuelManager when `PadDuelsInLobby`; `findSlotAt`/`JoinPad`/`QuickJoin` refuse `InDuel`/`DuelSpectate`.
  - `TrainingManager` safety loop: skip `InDuel` (no strip, no hangar); `enter` refuses `InDuel`.
  - `LobbyFallCatch`: skip `InDuel`.
  - `CombatManager`:
    - reload/melee gates become `InTraining or InDuel`;
    - `CombatEnabled`/`InfiniteAmmo`/`LiveMatch` read from `MatchState.For(player)` (fallback ReplicatedStorage);
    - port the pass 38 friendly fire + `LastHitZone/Kind`;
    - add the `SameMatch` damage guard;
    - narrow `WeaponFired` to `FireMatch` in arenas.
  - `MeleeManager`: same.
  - `GadgetManager`: `CombatEnabled` per match, `LiveMatch` charges, arena `mapRay`, `ClearAll(region)`, `FlashDetonated` narrowed.
  - `ShootableManager` (stub): route to `ArenaShootables` by origin.
  - `PlayerRegistry`: none (health set by LobbyDuelManager).
  - `MatchConfig`: replaced by the match place's superset + duel keys.
  - `TrainingGate.On()`: `InTraining == true or InDuel == true`. This one line turns on every combat controller for duelists.
    Training-only controllers (TrainingBins/Pads/Targets) already test `InTraining` themselves.
  - `NameplatesController`: hide other matches' duelists.
  - `MatchmakingManager` search: refuse `InDuel`.
  - `ExfilFX` / `Events.Training.Enter`: refuse `InDuel`.
  - `LobbyFeaturesManager`: in-lobby matches in `LF_LiveDuels`.
- **Match place** (when Edward wants the RIVALS flow there too; its own pass, own backups):
  - `RoundManager` → thin wrapper on `MatchCore` (arrival, kicks, teleport back stay);
  - `ReplicatedStorage.MatchFlow` RemoteEvent;
  - a `LobbyConfig` copy (Items, AccountLevel) for `OwnedItems`/`Level`/validation;
  - `DoorManager.CloseAll` per round.
  - CombatManager, Melee and Gadget get the same `MatchState.For` reads. On that place `For` returns ReplicatedStorage, so their behaviour is identical.

### Porting the Warehouse
1. Copy `Workspace.Warehouse` + `Workspace.MatchSpawns` from `match_place_ref.rbxl` into the lobby copy. Use Studio Explorer copy/paste
   between the two windows (the computer-use route port_manifest.md uses, Ctrl+C/Ctrl+V only, when the UI session allows it), or Edward does it.
   Script cloning can't cross DataModels.
2. Park it in `ServerStorage._DuelSource.Warehouse`.
3. Run `fix/duel_split_map.lua`, which produces both layers. Spawns are re-expressed relative to the template pivot.
4. Asset permissions: the two places are in one universe (ReserveServer to it works), so the meshes and SA textures load in the lobby.
   Verify with the existing AssetCheck.
5. **Restyle later** to the Tacticals look (olive/cream accents, RIVALS treatment): edit only the Visual layer. The Solid layer must keep
   its geometry, or re-run the split.

### Build order (each phase testable)
1. **Phase 1: 1v1, one arena, no vote/picker.**
   - Split map, `MatchState`, `MatchCore` (rounds only), LobbyDuelManager (slot 1), ArenaLoader (load/unload + Lighting), the
     TrainingGate/Training/FallCatch/Combat [DUEL] edits.
   - Test: Studio **Test > 2 players** (take `tools/play_lock.py take map` first), pad 1v1 A, then rounds to 3, results, back on the pad.
     Verify the lobby client sees no Visual layer (count `workspace.Warehouse` on a third client = nil), shots through walls are rejected,
     a grenade bounces, and a death goes to the Bench.
   - Measure the arena's triangles/draw calls with SceneAnalysisService on a duelist client.
2. **Phase 2: 2v2/3v3, concurrency, the full flow.**
   - All 6 slots, `SameMatch` guards, `FireMatch`, `ArenaShootables`/`ArenaDoors`, MapVote + Loadout + Loaded gating, `OwnedItems`/`Level`, rewards via PlayerStore.
   - Test: 3+ clients, two matches at once, a barrel in one doesn't affect the other, a forfeit by leaving, a disconnect, ARENAS FULL with `MaxArenas = 1`.
3. **Phase 3: spectate.** Duels TV WATCH, the Holo prompt, the spectator camera, `Spectators` count, the cap.
4. **Phase 4: polish.**
   - Fades and sound, the `DuelVisibility` belt-and-braces, `LF_LiveDuels` rows, KitGuard port, the "LIVE" holo on a pad.
   - Restyle the Warehouse, then the match place MatchCore migration (shared HUD in both places).

## 8. Risks

- **The Solid layer replicates to everyone** (~107 invisible parts per live match, max 6). This is the price of server-authoritative
  grenades and wall checks. It is negligible next to the lobby's 7,644 parts, but it is not literally "client only". The only way to avoid
  it is StreamingEnabled with PlayerSpecific models, which breaks the lobby.
- **`CharacterAutoLoads = true` in the lobby:** dead duelists respawn in the lobby for a tick before the Bench `PivotTo`.
  `Players.RespawnTime` and `CharacterAutoLoads` are global, so they can't fix it per player. If the flash shows, the alternative is
  "soft death": a lethal hit sets Health to 1, ragdolls the player and benches them without a Roblox death, so there is no respawn.
  Decide in phase 1 by testing.
- **Global combat attributes:** missing a `ReplicatedStorage` read (e.g. in a client controller: `WeaponController` reads global
  `CombatEnabled`) means combat isn't paused in countdowns. Phase 1 greps every `GetAttribute("CombatEnabled"|"LiveMatch"|"InfiniteAmmo"|"MatchState")`
  in both client and server and routes them through `MatchState.For`.
- **The lobby lighting swap:** client-side Lighting changes are fine, but other lobby effects (WorldMoodFX, `UIWorldBlur`/`UIWorldGrade`,
  `Lobby_Bloom`) must be paused or restored correctly. `Lighting.Technology` can't change at runtime: the Warehouse renders with the lobby's
  technology (Future once set).
- **Two copies of the combat managers drifting:** MatchCore must stay byte-identical between the places (hash check in the port checklist).
- **Exploits:** client `Pick`/`Vote` are validated server-side. `Loaded` can only delay a match by 5 s. Spectators can't send combat.
- **Lobby server load:** each match runs the same server code as a match server (rounds, shot validation, grenade physics). Six 3v3 matches
  = 36 combatants on one lobby server. Phase 2 measures the server heartbeat; `MaxArenas` can drop.

## 9. Open questions for Edward

1. **Rewards on pad duels:** the same as matches (XP, scissors, gun XP, quest stats), reduced, or none? Friends can farm each other on pads.
2. **Ranked pads:** do lobby pads stay casual only, or do ranked bays count for rating?
3. **Leave penalty** for quitting a pad duel mid-match?
4. **Map vote** with only one real map: show it anyway (Warehouse + Random), or skip straight to loadout until there's a second map?
5. **Max concurrent pad matches:** 6 (one per pad) OK? More pads later = more slots.
6. **Spectating:** from the Duels TV + a WATCH prompt at the pad: both? Does the spectator's character stay standing in the lobby (RIVALS), or hide?
7. **Restyle the Warehouse** to the Tacticals palette now (phase 4), or keep it as the match place has it?
8. **Is the ~100 invisible-part collision shell per live match** acceptable as "no lobby lag" (see the risks)?
9. **The match place gets the same vote + loadout flow** through MatchCore: OK to change its RoundManager in a later pass (backups kept)?

## Edward 2026-10-16 (after the design)
- **Maps are data-driven.** The Warehouse/"Garage" is a blueprint for *mechanics* only; every future map has its own layout and
  size. Nothing may hard-code Warehouse geometry. A map registry `ReplicatedStorage.DuelMaps.<MapId>` (MapInfo: name, image,
  Modes, spawns per team, bounds, visual vs collision folders, slot footprint) drives loading, slots, spawns and the vote list.
- **The Warehouse is 1v1 only** (its size suits 1v1; 2v2/3v3 get their own maps or versions later). MapList is filtered by mode. A pad whose
  mode has no eligible map gets `NoMap = true` and doesn't count down; the UI shows "no maps yet".
- Lead defaults for the open questions: casual only; rewards like a casual online match capped at once per opponent pair per 10 min;
  leaving counts as a loss; vote shows Warehouse + Random; 6 arenas max; spectate from the TV and a pad prompt, with the spectator's character
  staying in the lobby; restyle later; the collision shell is OK (Edward: "yes"); MatchCore in the match place later.

## Spectating: PAUSED (Edward 2026-10-16 ~17:05)
Paused before any code. Notes for when it resumes:
- DuelHUD's spectate list (aliveList) only has real Players with Alive == true, so bots (negative ids, DuelBot_<id>_<n> models in
  workspace.DuelArenas.<id>) can't be followed. MatchCore sets Alive on the bot model, not a Player.
- Server: match.spectators, the Spectators count, playersOf(match, true) fan-out, endMatch clearing DuelSpectate and MatchState.Audience
  already exist. Missing: the Spectate/StopSpectate handler (onFlow drops non-duelists), disconnect cleanup, the cap, the
  lobby freeze, and the entry points (pad prompt, Duels TV).
- Client: ArenaLoader already loads for DuelSpectate, but it sends Loaded for spectators too (harmless; should be skipped). The camera
  restore isn't written.
