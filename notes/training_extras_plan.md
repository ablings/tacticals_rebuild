# Training extras: implementation plan (Step 2 scripts, 2026-10-15)

Plan only: no code has been written and no Studio window was used. Source: the read-only dump `out/survey/src/*.lua`.
Inputs: `brief_training.md` (Edward's answers, build order), `training_spec.md`, `hooks.md`.
Rules: own code only. RIVALS is described only as a player sees it. Every feature sits behind a flag. Test in the local copy
(`Tacticals_rebuild.rbxl`) only, never in the live place. Order follows the brief's Build order step 2.

---

## 0. How Tacticals works today (findings)

### 0.1 Bootstrapping
- **Server:** `ServerScriptService.ServerScripts.[Server] Init` calls `ModuleLoader._Init(script:GetDescendants())` and then
  `_Start()`. Every top-level ModuleScript under `GameManager/Managers` loads and its `.Start()` runs in a `task.spawn`.
  Modules find each other with `shared.Get("Name")`. The name must be unique. `ModuleLoader.Get` **warns** when a module is
  missing.
- **Client:** the `StarterPlayerScripts.Client` LocalScript does the same over `Client/Controllers/*` and `Client/GUIs/*`.
  Combat controllers start with `require(Shared.TrainingGate)`. They use its proxied `RunService`, `UserInputService` and
  `ContextActionService`, and `Gate.CharacterAdded`, so **nothing they bind runs unless `player:GetAttribute("InTraining")`**.
  The gate also turns the combat UI (`HUD`, `Hotbar`, `Vitals`, ...) on and the lobby UI off.
- `StarterPlayerScripts.RoomFX` is a plain LocalScript and is not loaded by ModuleLoader.

### 0.2 Weapons: fire, hit detection, damage (`WeaponController` client, `CombatManager` server, `WeaponUtil` shared)
1. Client `WeaponController.fire()` runs these checks: alive, `ReplicatedStorage.CombatEnabled ~= false`, fire interval,
   not reloading, ammo, **not `CoverController.IsHopping()`** (so no shooting in the air), then blind-fire or vault rules.
   `_Shoot` then calls `computeShot`. That function gets the muzzle origin and the camera aim point (`CameraController.GetAimPoint`),
   applies spread, and checks `IsMuzzleReachable`. It raycasts from the muzzle while excluding your own character.
   **It sends `hitPart` only if the hit belongs to a Model with a Humanoid** (`WeaponUtil.GetCharacterFromPart`). Either way
   it always sends `hitPosition` (the first thing the ray hit).
2. `Combat.FireWeapon:FireServer(shotId, origin, direction, hitPart, hitPosition)`. Also client side:
   `PropController.OnLocalShot(origin, endPos)` (Warehouse props only; idle in the lobby).
3. Server `CombatManager.onFire` runs these checks in order: rate limiter (24/s), equipped tool state, increasing shotId,
   vector sanity, `CombatEnabled`, reloading, ammo, fire interval. **Ammo is spent here.** Then origin ≤ 8 studs from the head
   and muzzle reachability. Then `WeaponFired:FireAllClients` for effects, and **`afterShot(origin, endPos, player, config)`**.
   `afterShot` calls `shared.Get("ShootableManager").OnShot(origin, endPos, shooter)` for **every shot that passed the fire
   checks, hits and misses alike**. `endPos` is the client's claimed `hitPosition`, or `origin + direction * Range` when
   there is none. **The lobby place has no ShootableManager**, so this hook is free. Today every shot logs a `Get(...)
   returned nil` warning for ShootableManager and BotManager.
4. Character hits only: the server checks that the hit point lies on the ray (1 stud), is within Range, is within
   `part.Size/2 + 6` of the part, and that `WeaponUtil.IsPathClear` passes (a raycast that excludes players and `Bot`-tagged
   models only). Then `zone = GetHitZone(part)` (Head/Body/Limb/Extremity), `damage = WeaponConfig.DamageAt(config, zone,
   distance)` (falloff), `victimHumanoid:TakeDamage`, and `HitConfirm:FireClient(shooter, zone, damage, killed)`. That event
   drives `HUD.ShowHitmarker(zone, killed)` (hit sound plus marker). Finally **`victimCharacter.OnHit:Fire(player, zone, damage,
   distance, DisplayName)`** runs if the victim Model has a BindableEvent named `OnHit`. The client never sends damage.
5. Damage per shot (body/head): Pistol 30/60 @0.2 s, Suppressed 38/76 @0.28, Revolver 75/150 @0.45, Mini Uzi 14/28 @0.07,
   Auto Rifle 21/42 @0.11, Semi-Auto 45/90 @0.30, Sniper 110/220 @1.3. Ranges are 200-600 (the Mini Uzi only reaches **200**).

### 0.3 Health, dummies, Training (`TrainingManager`, server)
- Constants: `ENEMIES, HEAL_DELAY, CORPSE_TIME, RESPAWN_DELAY, HEALTH = 24, 2.5, 3, 2, 150`, `FLOOR_Y = 600`,
  `HANGAR = (112, 3.5, 0)`.
- `freeSpot()` picks a random child of `Training.EnemySpots` that is not in `used[spot]`. **It assumes every child is a
  BasePart**: a sub-folder would be picked as a spot and `spot.Position` would error.
- `spawnEnemy()` clones `ServerStorage.RangeAssets.Dummy`, paints it red, sets 150 HP and Health display None, pivots it to
  the spot (feet at spot.Y - 3, the spot's rotation) and anchors the root. It adds a `BillboardGui "Readout"` on the Head and a
  `BindableEvent "OnHit"`. The handler pops the damage number in the zone colour and heals to full 2.5 s after the last hit.
  On `Died`: "ELIMINATED", ragdoll, fade after 3 s, destroy, then 2 s later `used[spot] = nil; spawnEnemy()`. So a spot stays
  reserved for about 5.7 s after the kill.
- `Start()` spawns `ENEMIES` dummies once `LobbyMap.Training` exists. There is a safety loop every 0.3 s: a training player
  below y 585 goes back to an arrival point, and a non-training player above y 540 has their tools stripped and goes to the
  HANGAR.
- Player health: 100 HP (`HealthBarController`). **There is no fall damage anywhere in the dump.**

### 0.4 How weapons and kits are given
- On every `CharacterAdded` with `InTraining`, `CombatManager.onCharacterAdded` waits for `character.Ready` (PlayerRegistry),
  then calls `GiveWeapon(player, player:GetAttribute("Loadout") or "Pistol")` and `EquipTool`.
- `CombatManager.SetWeapon(player, weaponId, equip?)` is the server API to swap guns. It sets the `Loadout` attribute,
  destroys every tool that has `WeaponId`, gives the new one (full magazine and reserve) and re-equips it if the old one was
  drawn.
- `Combat.SelectWeapon` remote (the Z key): it requires the id to be in `WeaponConfig.Loadout` and `PlayerStore.Owns`. It is
  allowed when `CombatEnabled ~= true`, which is always the case in the lobby place. Then `SetWeapon`.
- Gadget and melee come from the player attributes `KitGadget` and `KitMelee` (GadgetManager and MeleeManager refill on change).
  Those attributes are written by `PlayerStore.ApplyLoadoutAttributes` (Armory "Equip", which persists to the DataStore).
- **Finding (out of scope, report to Edward):** the Armory writes `KitWeapon`, but training spawns read `Loadout`, which only
  `SetWeapon` writes. As far as the dump shows, **the gun equipped in the Armory never reaches Training**: you get the Pistol
  until you press Z. Z also cycles through *all* 7 guns, and the server silently rejects unowned ones, so **Z gets stuck on
  the first gun you do not own**. Weapon bins (feature 8) avoid both problems.

### 0.5 Movement (`MovementController`, `CoverController`, client)
- Roblox's jump is off: `UseJumpPower = false`, `JumpHeight = 0`. Space is handled by `CoverController.onJumpKey`. It vaults
  low cover; otherwise it makes a **2.2-stud hop** (`JumpHeight = HopHeight`, `ChangeState(Jumping)`, back to 0 after 0.15 s).
  Hop is blocked for 0.45 s after a shot. Vaults drive the root CFrame directly in the `Physics` state.
- `MovementController` only writes `WalkSpeed` each frame (walk 12.5, sprint 23, crouch 6). The slide writes velocity
  itself. Being in Jumping/Freefall exits cover, and `IsHopping()` (Jumping/Freefall) blocks firing.
- Public APIs useful here: `CoverController.IsInCover/IsMoving/IsVaulting/IsHopping`, `MovementController.IsSliding/StopSprint`,
  `CameraController.SetMouseFree(bool)`, `shared.Get("HUD").ShowHitmarker(zone, killed)`.
- Keys already taken: E = cover dash, Q cover, C crouch, G gadget, F quick melee (**F is passed to a ProximityPrompt whenever
  a prompt with KeyCode F is shown**, see HotbarController), Z weapon cycle, M leave training, 1-3 hotbar.

### 0.6 Damage-number UI today
- Only the server-built `Readout` BillboardGui on each training dummy (zone-coloured TextLabels float up and fade), plus the
  client hitmarker. There is no screen-space damage feed and no DPS display.

### 0.7 RoomFX (client)
- Tagged `RoomLight` parts with `Room = "Training"` are lit while the **camera** is within 175 of (0, 606, 0). This is
  checked every 0.5 s. The light budget is about 45 enabled.

---

## 1. Shared flag module (do this first)

**New `ReplicatedStorage.Modules.Shared.Config.TrainingConfig`** (ModuleScript; not auto-loaded; required by server and client):
```lua
local C = {
  AliveDummies = 35,                 -- was 24 (TrainingManager ENEMIES)
  GalleryFill  = true,
  RoomFXBox    = true,
  Bullseyes    = { Enabled = true, Count = 120, Radius = 1.5, Respawn = 3, MaxRange = 600 },
  DpsDummies   = { Enabled = true, Window = 3, MinSpan = 1, Idle = 2.5, Hold = 2 },
  JumpPads     = { Enabled = true, Cooldown = 0.6, Headroom = 7 },
  Tightropes   = { Enabled = true },
  SwapBins     = { Enabled = true, AllowUnowned = false, Reach = 12 },
  CeilingY     = 648,                -- floor 600 + 48 (Edward)
}
-- Play-mode kill switch without editing code: ReplicatedStorage:SetAttribute("TX_Bullseyes", false) etc.
function C.On(name) local a = game:GetService("ReplicatedStorage"):GetAttribute("TX_" .. name)
  if a ~= nil then return a end; local v = C[name]; return type(v) == "table" and v.Enabled or v == true end
return C
```
- **Geometry isolation:** every extra's parts live in `LobbyMap.Training.Extras.<Feature>` (`JumpPads`, `Tightropes`,
  `SwapBins`, `TargetSpots`, `DpsSpots`). A new server module **`Managers/TrainingExtrasManager`** reads the flags at Start.
  For each disabled feature it moves that folder to `ServerStorage._TrainingExtrasOff` (reversible, nothing deleted), so a
  disabled feature leaves no geometry, prompts or spots behind.
- Every new module checks `TrainingConfig.On(...)` in `Start()` and returns at once when off. A missing config
  (`pcall(require)` fails) means "all off, old behaviour".

---

## 2. Feature 1: alive dummies 24 -> 35

| | |
|---|---|
| Script | `Managers/TrainingManager` (server) |
| Change | line 10: `ENEMIES` comes from `TrainingConfig.AliveDummies` (fallback 24). In `Start()`, warn when `#spots < ENEMIES` (the extra dummies would silently never spawn). |
| Data | `Training.EnemySpots`: the spec gives 44 spots (16 gallery + 28 arena). 35/44 means 80 % filled. Do **not** go above about 40 alive with 44 spots: respawns need free spots, and a reserved spot stays blocked for about 5.7 s. |
| Side | server only |
| Flag | `AliveDummies` (set to 24 to revert) |

Risks: 35 anchored R15 rigs plus up to 10 DPS rigs gives about 45 Humanoids. They are anchored, so the server cost is small.
Each has a BillboardGui with MaxDistance 300, which costs the client little. **Test:** Play, enter Training, then on the
server run `#workspace.LobbyMap.Training:GetChildren()` filtered by Name == "TrainingEnemy". Expect 35. Kill 5 and expect 35
again after about 6 s, with no warnings.

## 3. Feature 2: keep the 16 gallery spots filled

As a player sees it in RIVALS, the distance gallery always has a dummy at every marker.
| | |
|---|---|
| Script | `TrainingManager.freeSpot()` (server) |
| Data | Mark gallery spots with the **attribute `Gallery = true`** on the spot Part, and keep them direct children of `EnemySpots`. That is the builder's job. A sub-folder `EnemySpots/Gallery` is also accepted (code below), but the attribute is preferred. |
| Change | (a) Gather spots with `GetDescendants()`, keeping BaseParts only. That fixes the folder crash. (b) If `GalleryFill` is on and a free gallery spot exists, return a random free gallery spot. Otherwise pick any free spot, as today. (c) Optional `GALLERY_RESPAWN = 1` s instead of 2 when the freed spot is a gallery spot, so the lane is never empty for long. |
| Side | server only |
| Flag | `GalleryFill` |

```lua
local function isGallery(s) return s:GetAttribute("Gallery") == true or (s.Parent and s.Parent.Name == "Gallery") end
-- in freeSpot: build `gal` and `all` lists of free BaseParts; if TrainingConfig.On("GalleryFill") and #gal > 0 then return gal[rand] end
```
Why it stays full: the initial loop fills the 16 gallery spots first. A killed gallery dummy keeps its spot reserved until
its own respawn, and that respawn comes back to the only free gallery spot, which is that same one. So the gallery is
missing at most one dummy, and only for about 4.7-5.7 s after each kill. **Test:** Play, count the dummies on spots with
`Gallery` (expect 16). Kill all 16 with the Sniper. Every one comes back within about 6 s, and the arena count stays 19.
Also test with a sub-folder layout to check (a).

## 4. Feature 3: RoomFX Training radius for the 256 x 256 arena + 224 x 72 gallery

Footprint: x -128..352, z -128..128, floor y 600, ceiling 648. A single sphere would need its centre at (112, 612, 0) and a
radius of about 275. That **reaches the Showroom camera at (0, ~410, 8)** (about 231 away), so the Training lights would
switch on while someone uses the Kit menu and break the about-45-light budget.
| | |
|---|---|
| Script | `StarterPlayerScripts.RoomFX` (client LocalScript) |
| Change | Add `ROOM_BOX = {Training = {Vector3.new(-140, 588, -140), Vector3.new(364, 660, 140)}}` (12-stud margin). In the loop: if the room has a box and `TrainingConfig.On("RoomFXBox")`, `on = p` is inside the box. Otherwise use the old sphere test. Keep `CENTRES.Training` and `ROOM_RADIUS` as the fallback. |
| Data | Training `RoomLight` parts anywhere inside the box. Count them against the budget (≤ about 16 for Training, because the other rooms are off while you are up there). |
| Flag | `RoomFXBox` (off = old 175 sphere) |

**Test:** Play, enter Training, walk to the gallery end (x about 340) and to the corners (±125, ±125): the lights stay on.
Open the Kit menu in the lobby (Showroom camera): the Training lights are off. Count enabled lights with a client command
(`Light.Enabled`) in each place.

## 5. Feature 4: floating 1-HP bullseye targets

As a player sees it in RIVALS: many small round bullseye targets float all over the arena at different heights and always
face you. One hit pops them with a small burst and a hit sound, and after a few seconds they reappear.

**Design (own code): no Humanoid.** Make them anonymous parts that are hit-tested on the server through the free
`ShootableManager.OnShot` hook. They need no CombatManager edit, give no kill credit, and cost much less than 120+ Humanoids.
| Piece | Where | What |
|---|---|---|
| `Managers/ShootableManager` (new, server, about 10 lines) | lobby place only | `OnShot(origin, endPos, shooter)` forwards to `shared.Get("TrainingTargetsManager").OnShot`. Name chosen to fit the existing `afterShot` hook; this also stops one warning per shot. |
| `Managers/TrainingTargetsManager` (new, server) | | builds the targets, runs the hit test and respawns |
| `Controllers/TrainingTargetsController` (new, client, gated) | | pop burst and sound, shooter hitmarker |
| RemoteEvent `Events.Training.TargetPop` | created by the server module if missing | server -> shooter: `(position)` |
| Spots | `Training.Extras.TargetSpots` (1-stud invisible Parts, CanCollide/CanQuery/CanTouch off) | placed by the builder, or by a one-off Studio generator (scatter `Count` points 8-40 above each walkable surface, ≤ CeilingY - 4, ≥ 3 studs from any part via `GetPartBoundsInRadius`, not within 8 of Arrivals) |

**Target instance** (server, one per spot): `Part` Ball, size 2 x Radius, Transparency 1, Anchored, **CanCollide false,
CanQuery false, CanTouch false**, CastShadow false, attribute `NotCover`, tag `TrainingTarget`. It carries a BillboardGui
(Size `fromScale(3, 3)`: in a BillboardGui, Scale means studs, which follows the Scale-only UI rule; LightInfluence 0,
MaxDistance 350). Inside are 4 concentric Frames with `UICorner(1, 0)` in red (196,40,40) and cream (236,232,218). A
BillboardGui faces the camera by itself, so it always faces you at no script cost and needs **no asset upload**.

**Hit test** (`OnShot`, server):
```
if not shooter or not shooter:GetAttribute("InTraining") then return end
seg = endPos - origin; len = seg.Magnitude; if len < 0.1 or len > MaxRange + 1 then return end
dir = seg / len; best = nil
for each live target t: v = t.Position - origin; a = v:Dot(dir)
  if a > 0 and a < len + Radius and (v - dir*a).Magnitude <= Radius + 0.25 then keep the smallest a
if best and WeaponUtil.IsPathClear(origin, origin + dir*(a - Radius)) then pop(best, shooter)
```
- CanQuery false means bullets and the aim ray pass through, so targets never block shots, aim, cover raycasts or the camera.
  The client `endPos` is whatever is behind. A dummy or wall in front ends the segment before the target, so the target is
  correctly not hit. A target in front of a dummy pops **and** the dummy takes the bullet. That is acceptable for a range;
  note it for Edward.
- `pop`: set attribute `Popped = true`, `Billboard.Enabled = false`, `TargetPop:FireClient(shooter, pos)`. After `Respawn`
  (3 s) clear the flag and re-enable it. All clients watch `Popped` (attribute signal on the tagged parts) and play a burst
  of 6-8 small red and cream shards (Debris 1.5 s) and a pop sound. The shooter also gets
  `shared.Get("HUD").ShowHitmarker("Head", true)` (the existing hit sound and kill colour).
- Count: `Count` (start at 120; RIVALS-like density over 65k studs² of arena is about 180). Server cost is one dot-product
  loop per shot, only for training shooters, about 120 checks per shot, which is negligible. Optional: bucket by 32-stud
  grid cells if Count goes past 300.

Risks: **anti-exploit**. `endPos` is client-claimed and `OnShot` gets no `direction`. An exploiter could aim a fake segment at
any target, but `IsPathClear` stops shots through walls, and the rate is bounded by ammo and fire rate (afterShot runs after
those checks). The only gain would be popping practice targets. **If targets ever give score or quest stats**, add
`direction` to the hook (one line in `afterShot`) and require `dir:Dot(direction) > 0.999`. **Perf:** 120 BillboardGuis
with 4 Frames each = 480 GuiObjects, fine. MaxDistance culls far ones.

**Test (Play, 1 client):** 120 targets visible and facing the camera from every side. Pistol shot pops one: hitmarker, burst,
it comes back after 3 s. A shot through a wall at a target behind it does nothing. Shooting a dummy behind a target pops the
target and damages the dummy. Hip fire spread misses register correctly. In the lobby (`InTraining` false) nothing happens.
`TX_Bullseyes = false` on ReplicatedStorage before Play gives no targets and no errors. Output shows no `Get("ShootableManager")` warnings.

## 6. Feature 5: infinite-HP damage-test dummies with a DPS readout

As a player sees it in RIVALS: a different-looking dummy that never dies, with a number overhead that shows your damage per
second while you shoot it.
| Piece | What |
|---|---|
| `Managers/TrainingDpsManager` (new, server) | spawns one DPS dummy per `Training.Extras.DpsSpots` child (6-10; the spec's SE free-fire field lines at 25/50/75/100 and the gallery mouth suit them). These are **not** counted in `AliveDummies` and **not** in `EnemySpots`. |
| Dummy | clone `RangeAssets.Dummy`, name `DpsDummy`, own paint (dark olive 107,122,58 body, near-black limbs, so it differs from the red enemies), same pivot formula as TrainingManager, root anchored, `MaxHealth = Health = 1e6`, `DisplayDistanceType None`, `BreakJointsOnDeath false`, `SetStateEnabled(Dead, false)`. |
| Hit hook | its own `BindableEvent "OnHit"`. CombatManager already fires it (step 0.2.4), so there are **no CombatManager edits**. The handler records `{t = os.clock(), dmg}`, pops the zone-coloured damage number (own copy of the small popup helper; TrainingManager is not touched), and sets `hum.Health = hum.MaxHealth`. |
| Readout | BillboardGui `DpsReadout` on the Head: Size `fromScale(7, 2.6)` (studs), StudsOffsetWorldSpace (0, 3.6, 0), AlwaysOnTop, LightInfluence 0, MaxDistance 300. Big label `"184 DPS"` in cream; small label `"LAST 21 · TOTAL 1,450"` in sage. |
| Rolling window | A burst starts at the first hit after `Idle` (2.5 s) with no hits. `span = clamp(now - burstStart, MinSpan 1, Window 3)`, `dps = Σ dmg(t ≥ now - span) / span`. Samples older than Window are dropped. One server loop at **5 Hz** writes the text only when it changes. After Idle with no hits, the last value is held greyed for `Hold` (2 s) and then reset to `0 DPS`. |
| Multi-shooter | Damage from all shooters is combined (simple). Optional: show only the most recent shooter's damage by keying samples by player. |

Expected readings (body, close range, every shot landing): Mini Uzi about 200, Auto Rifle about 190, Pistol at max rate 150,
Semi-Auto 150, Revolver about 167, Sniper about 85. Falloff lowers these at range.
Risks: `TakeDamage` respects ForceFields (there are none on dummies). The `HitConfirm` killed flag stays false. The
HealthBar UI is unaffected. Bandwidth from 10 dummies × 5 Hz text is negligible. **Test:** Mini Uzi body shots on the
DPS dummy at 10 studs settle at 190-200 within 3 s. Stop: the value holds, greys out and resets. Sniper headshot shows 220
and the dummy never ragdolls. Two clients (Test > Clients and Servers, 2 players) shooting together roughly add up. The
popup colour matches the zone. Flag off gives no DPS dummies and no errors.

## 7. Feature 6: jump pads

As a player sees it in RIVALS: step on a glowing pad and get thrown high in an arc onto a rooftop or tower.
Constraint: Tacticals' Space hop is 2.2 studs, so the pad must move the character itself. **The character is client-owned
(network ownership), so the launch must be client side.** A server velocity write would be overwritten or rubber-band.
| Piece | What |
|---|---|
| `Controllers/TrainingPadsController` (new, client, `TrainingGate` proxies) | detects the pad and launches |
| Pad | Part tagged `TrainingJumpPad` in `Extras.JumpPads`. CanCollide true, height ≤ 0.6, attribute `NotCover` (so it is never vaulted or used as cover), Neon olive ring plus a cream arrow decal. Attributes: **`LandAt` (Vector3, world landing point)**, optional `Apex` (studs above the higher of start and landing, default 6). |
| Detection | Heartbeat (gated): a raycast down 3.5 studs from the root, with an Include list of tagged pads. Fire when it hits a pad, the humanoid is grounded, and the pad's cooldown has passed. Skip if `CoverController.IsMoving()/IsVaulting()` or `MovementController.IsSliding()` (the slide writes velocity itself). If `IsInCover()`, leave cover first (or skip). |
| Launch | `g = workspace.Gravity`. `h = max(start.Y, LandAt.Y) - start.Y + Apex`, clamped so `start.Y + h ≤ CeilingY - Headroom (7)`. `vy = sqrt(2gh)`, `T = vy/g + sqrt(2g(h - Δy))/g`, `vxz = Δxz / T`. Then `hum:ChangeState(Freefall)`, `root.AssemblyLinearVelocity = vxz + (0, vy, 0)`. **Hold the horizontal component**: Humanoid air control would otherwise pull it back toward WalkSpeed, so each Heartbeat for up to T + 0.3 s set `vel = Vector3(vxz.X, vel.Y, vxz.Z)` until the state is Landed/Running. Play a whoosh sound and a short Neon pulse locally. |
| Server | None. Pads add no remote and no trust. Movement is client-authoritative in Roblox anyway. The existing y-585 and y-540 rules still apply. |

Interaction with Tacticals' rules: you **cannot fire mid-flight** (`IsHopping` is true in Freefall). That keeps the house rule;
ask Edward whether pads should allow it, which would mean an `IsPadFlight()` exception in WeaponController. Cover exits on
Freefall automatically. There is no fall damage. Ceiling 648: a floor-to-roof pad (Δy 24, Apex 6) peaks at 630 (vy about
108 at gravity 196.2). Roof-to-tower pads must keep the tower tops ≤ about 636.
Risks: a launch while a vault is driving the CFrame (prevented by the skip), double-launch (the cooldown handles it),
clipping under the ceiling (the clamp handles it), and different gravity (it is read at runtime). **Test:** each pad from
standing, walking, sprinting, crouched and after a slide lands within 3 studs of `LandAt`. It never hits the ceiling and
cannot be fired from inside cover. Spam Space on the pad: one launch per cooldown. Shooting mid-air is blocked (house rule).
Lobby players never see pads (y > 540 rule). Flag off: the pads are stashed and no launches happen.

## 8. Feature 7: tightropes

As a player sees it in RIVALS: thin ropes strung between high tops that you simply walk across. No balance minigame is
visible; you fall if you step off.
**Plan: geometry only, no balance or slow code.** Tacticals' slow walk (12.5) and crouch-walk (6) already give enough control.
- Each rope is two Parts in `Extras.Tightropes`. The visual is a cylinder about 0.5 thick (rope colour, `CanCollide false`,
  `CanQuery false`). The walk surface is an invisible box **1.2 wide × 0.4 tall** (CanCollide true, **CanQuery true**,
  Transparency 1) with attribute **`NotCover`**, so Space never vaults it, Q never snaps to it, and E-dash never targets it.
- Keep CanQuery on for the walk box. Humanoid floor detection and `CoverController.isGrounded`/hop raycasts need it to count
  as ground. It is thin, so it blocks very few shots.
- Endpoints: roof deck (+24) or tower tops. With the ceiling at 648, **towers must stay ≤ about +36** to keep 12 studs of
  headroom. That replaces the spec's 60-stud towers, which conflict with Edward's ceiling. Reach the tops by jump pads or
  truss/ramp.
- A fall drops 24-36 studs to the floor or a roof: no damage, and it is still above y 585.
- Optional later (behind `Tightropes` flag, client): if tests show too many falls, add a soft rope assist that halves the
  lateral MoveDirection while the FloorMaterial part is a rope. Do not build it unless Edward asks.
**Test:** walk, sprint and crouch across each rope. Footsteps play (check FootstepController sounds for the walk box
material; use Metal or Concrete). Space on a rope does a hop, not a vault. Q next to a rope does not take cover. Falling
off lands safely. Shots past a rope are not blocked by the visual.

## 9. Feature 8: weapon-swap bins

As a player sees it in RIVALS: bins around the range with a "Change Weapons" prompt that opens a weapon picker. You pick one
and it is in your hands straight away.
**Phase A (recommended, minimal): client UI plus the existing `Combat.SelectWeapon` remote.** No server code. The remote
already enforces `WeaponConfig.Loadout`, `PlayerStore.Owns` and a 4/s rate limit, and it calls `SetWeapon`, which swaps and
re-equips a drawn gun and refills ammo.
| Piece | What |
|---|---|
| Bin | Model in `Extras.SwapBins` (an olive weapon crate). Its CanCollide body may count as low cover, which suits Tacticals. A `ProximityPrompt` has ActionText "Change Weapon", ObjectText "Weapon Crate", **KeyboardKeyCode F** (E is cover dash; HotbarController already passes F to a shown F-prompt), HoldDuration 0, MaxActivationDistance 8, RequiresLineOfSight false. Attribute `TrainingBin = true`. |
| `Controllers/TrainingBinsController` (new, client, gated) | `ProximityPromptService.PromptTriggered` for prompts with `TrainingBin`: open the picker and call `CameraController.SetMouseFree(true)`. Picker = ScreenGui `WeaponBin` built in design px and converted to **Scale** (Edward's rule). It shows 7 cards from `WeaponConfig.Loadout` with DisplayName and type. Owned cards come from the client PlayerData registry; unowned ones are dimmed with a lock and "Unlock in SUPPLY". Click or 1-7 → `Combat.SelectWeapon:FireServer(id)`, then close (Esc / F / walk > 10 studs also close) and `SetMouseFree(false)`. |
| Feedback | `player:GetAttributeChangedSignal("Loadout")` gives a toast "SNIPER equipped". HotbarController already refreshes on `Loadout`. |

**Phase B (only if Edward wants it):** trying unowned guns, or swapping gadget/melee. Add `Managers/TrainingBinsManager` with
a new remote `Events.Training.SwapWeapon(id)`. Server checks: `InTraining`, rate limit 4/s, root within `Reach` (12) of a
bin, id in Loadout, `Owns` unless `AllowUnowned`. Then `shared.Get("CombatManager").SetWeapon(player, id, true)`. For an
unowned trial, set a player attribute `TrialWeapon` and revert on Leave (TrainingManager.leave strips tools anyway). Gadget
and melee swaps must **not** use the Armory "Equip" handler (it writes the DataStore). Instead set `KitGadget`/`KitMelee`
for the session only, which GadgetManager and MeleeManager already listen to. Note that `ApplyLoadoutAttributes` would
overwrite them on the next Armory equip.
Risks: SelectWeapon works anywhere, so Phase A gives the bins no exclusivity (Z already did that). That does not matter for
the lobby place. Phase B adds a proximity check. Changing gun mid-reload cancels the reload (SetWeapon destroys the tool):
expected. **Test:** F at a bin opens the picker with the mouse free. Picking an owned gun swaps it in hand with a full
magazine and the hotbar shows it. Picking an unowned gun is refused with a toast and no swap. Walking away closes the picker.
E near a bin still dashes and does not open the bin. Holstered (1) and then pick: the new gun stays holstered. Rapid clicks
stay within the rate limit. Leave and re-enter Training: you respawn with the last picked gun (`Loadout` attribute).

---

## 10. New and changed files (summary)

| File | Side | Status |
|---|---|---|
| `ReplicatedStorage.Modules.Shared.Config.TrainingConfig` | shared | new (flags) |
| `...Managers.TrainingManager` | server | edit: ENEMIES from config; `freeSpot` descendants + gallery-first; optional gallery respawn 1 s |
| `StarterPlayerScripts.RoomFX` | client | edit: Training box test behind a flag |
| `...Managers.TrainingExtrasManager` | server | new: stashes the geometry of disabled features |
| `...Managers.ShootableManager` | server | new: 10-line shim to TrainingTargetsManager (lobby place only) |
| `...Managers.TrainingTargetsManager` | server | new: bullseyes |
| `...Managers.TrainingDpsManager` | server | new: DPS dummies |
| `...Managers.TrainingBinsManager` | server | Phase B only |
| `Client.Controllers.TrainingTargetsController` | client | new: pop FX + hitmarker |
| `Client.Controllers.TrainingPadsController` | client | new: launches |
| `Client.Controllers.TrainingBinsController` | client | new: picker UI |
| `Events.Training.TargetPop` (+ `SwapWeapon` in Phase B) | remotes | created at runtime by the server module if missing |
| `LobbyMap.Training.Extras.{TargetSpots, DpsSpots, JumpPads, Tightropes, SwapBins}`; `Gallery` attribute on 16 EnemySpots | map | builder (Step 1 geometry) |

**Unchanged:** CombatManager, WeaponController, WeaponUtil, CoverController, MovementController, HUD, TrainingGate,
ExfilFX. Every hook used is one that already exists (`OnHit`, `afterShot` → `ShootableManager.OnShot`, `SelectWeapon`,
`SetWeapon`, `HUD.ShowHitmarker`, `CameraController.SetMouseFree`, `NotCover`).

## 11. Cross-cutting risks
- **Server authority:** dummy damage stays fully validated in CombatManager. Bullseyes use a claimed segment plus a server
  wall check: low stakes, no rewards (section 5). Bins use the existing validated remote. Pads are client movement, as all
  Roblox movement is.
- **Performance:** about 45 anchored Humanoids, 120 bullseye billboards, 10 DPS labels updated at 5 Hz, and one
  Heartbeat raycast for pads on each training client. All small. Watch the light budget (RoomFX box).
- **Streaming is off.** If it is ever turned on, the client controllers must use CollectionService tag signals (planned:
  `TrainingTarget`, `TrainingJumpPad`) rather than folder scans.
- **Module names** must be unique per side (ModuleLoader skips duplicates). Check that no `ShootableManager` exists in the
  lobby place before adding the shim.
- **Ceiling 648 vs the spec's 60-stud towers:** cap towers at about +36 (affects tightropes and pads).
- **Order of work:** the geometry agent is editing the local copy now. Write the script changes only after the room is
  built and saved, one feature per Play test, and save after each passing feature (File > Save to File only).

## 12. Play-mode test routine (each feature)
1. Open `Tacticals_rebuild.rbxl` (local copy). Test > Start (or Clients and Servers with 2 players for DPS and bins).
2. PLAY > TRAINING (or the heli). Confirm `InTraining` and the combat HUD.
3. Run the feature's test list above. Watch Output for `[CombatManager] Rejected shot` (Studio logs reasons) and ModuleLoader warnings.
4. Run again with `ReplicatedStorage:SetAttribute("TX_<Feature>", false)` set before Start. The old behaviour must come back
   with no errors.
5. Leave with [M]: tools are stripped and no training UI (picker, readouts) stays on screen.

## Edward's answers (2026-10-15)
1. Jump pads exist **only in Training** (never in matches or the rest of the lobby). Shooting while airborne from a Training jump pad: **yes** (relax the no-shooting-in-air rule only for jump-pad launches in Training, behind the
   JumpPads flag; restore the normal rule on landing).
2. Weapon bins: **let players try guns they don't own** (do the optional second phase: a server-authorised Training-only trial that
   never grants ownership, ends when the player leaves Training or picks another bin; verify the shop/ownership data is never written).
3. **No collaterals**: a bullet that pops a bullseye stops there (no damage to a dummy behind it), and vice versa a dummy hit stops the
   bullet before any bullseye behind it. First thing hit wins.
