# Systems plan: steam fill (work order "Warehouse 2 steam valve steams the room up", 2026-10-27)

Scope: the match places (Matchmaking / Ranked / Tutorial, byte-identical scripts). Lobby pad duels (ArenaShootables /
ArenaLoader) are not touched this round; the shared modules are written so ArenaLoader can bind the same cloud later.

## Modules
| Module | Where | Change |
|---|---|---|
| `ShootableConfig` | RS.Modules.Shared.Config | new `Steam.Fill` block (all knobs, per quality level) |
| `SteamMask` | RS.Modules.Shared | replaced: classic path byte-for-byte the same maths; fill path = growing, wall-clipped, fading mask; `FillOf`, `Phase`, `Radius`, `Fan`, `ReachAt` for the client and tests |
| `SteamCloud` (new) | RS.Modules.Shared | client visual: builds the cloud from a valve's `SteamAt` / `SteamUntil`, quality-capped, fades, screen wash |
| `SteamCloudController` (new) | StarterPlayerScripts.Client.Controllers | binds every `SteamValve`-tagged valve (skips lobby arenas) |
| `ShootableManager` | GameManager.Managers | scans every placed registry map (Warehouse first); `SteamAt`; fixes the broken hiss line; `ResetAll` clears `SteamAt`; Studio-only test hook |
| `BotConfig` | RS.Modules.Shared.Config | `CoverFolders` + `Warehouse2/CollisionProxies` |

## Remotes
None added. Valve state replicates as attributes on the server's valve model (`SteamAt`, `SteamUntil`, server time).
Test hook: `ServerStorage.SteamFillTestHook` (BindableFunction, created only when `RunService:IsStudio()`).

## Data
No saved data. Map contract: the map model in Workspace carries `SteamFill = true` (a valve can opt out with `SteamFill = false`).

## Events for UI / animation
Attributes on the valve model: `SteamAt` (start), `SteamUntil` (hiss ends); cloud lasts `SteamUntil + Fill.FadeTime`.
`ShootableManager.OnValve` (BindableEvent) now fires (it was skipped by the hiss error).

## Rules
- Server owns the state; the clients only draw. Mask maths shared (`SteamMask`) so the bot, the reload check and the
  footsteps agree with what is drawn (same reach fan, same growth curve).
- Old Warehouse / Tutorial: no `SteamFill` attribute = classic path, unchanged numbers.
- Reset every round (`ResetAll` clears both attributes; clients drop the cloud at once).

## Tests
Unit (Edit, fresh module instances): classic radius unchanged; fill radius grows / holds / fades / ends; wall clips the
fan; opt-out valve; no `SteamAt` fallback. Play: 2 players (both see the cloud, footsteps masked, ends with fade, reset
next round); me + bot (reload in the cloud not heard, control outside heard); Tutorial 3 valve step on the Warehouse.

## Round 3 (Edward's review, 2026-10-27): AI blinded, footsteps muddied (fill maps only)
- `SteamMask`: `InFill(pos)`, `Muffled(source, listener)` (source masked, or listener in a fill cloud), `SightDepth(a, b)` /
  `SightBlocked(a, b)` (studs of steam on the line, the core x3, x strength; blocked at `Fill.Sight.BlindDepth`).
- `BotManager`: `smokeBlocks` asks `SightBlocked`; footsteps use `Muffled(walker, bot)`; `HearNoise(pos, r, quiet)`: quiet
  (reloads, from CombatManager) is not heard by a bot in the steam. `FootstepController` -> `SteamCloud.FootstepScale`
  (EqualizerSoundEffect `SteamMuffle` + `Fill.Footsteps.Volume`). Classic jet unchanged. Tests: 50/50 unit; Play results in
  notes/steam_fill.md.

# Warehouse 2 doors (map builder, round 6, 2026-10-27): contract for DoorManager
Edward: "the door should be openable via scripts for animating/cutscene purposes but in game it should remain closed".
Built by `fix/map_warehouse2.lua`; proven in a Play server by `tools/wh2_door_test.lua` (both doors roll up and back down, the
top edge never moves, a body fits through only when open, closed again = the built shutter exactly).

## What the map gives you
- `Workspace.Warehouse2.Interactive.Door_S` (BAY 01, team A's south end) and `Door_N` (BAY 02, team B's north end). Models,
  tag **`Warehouse2Door`** (`CollectionService:GetTagged("Warehouse2Door")`).
- Model attributes: `Open` (bool, false as built), `Moving` (bool), `OpenHeight` (studs the bottom edge rises, 14.04),
  `RollTime` (suggested seconds, 4), `Bay` ("01" / "02"), `End` ("A" / "B").
- `Shutter` (Part, the model's PrimaryPart): the curtain, 20.5 x 14.39 x 0.3 in the wall's reveal. CanCollide / CanQuery /
  CanTouch on (stops players and shots), attributes `NotCover = true`, `ImpactSound = "Metal"`, `ClosedSize` (Vector3) and
  `ClosedCFrame` (CFrame) = the shut state. Slats are SurfaceGuis drawn from the bottom edge up, so they ride with the bottom
  bar when the part shrinks. **No ProximityPrompt**: players can never open it.
- Behind each door: `Workspace.Warehouse2Exterior` (the lit night yard, trailer, containers, fence; OutOfBounds caps). It is
  what a cutscene shows; it is unreachable while the doors are shut.

## How to roll it (the only thing a script changes is the Shutter's Size and CFrame)
Open = shrink the Shutter from the bottom to `ClosedSize.Y - OpenHeight` (0.35 of curtain stays under the head) while its top
edge stays where it is; close = back to `ClosedSize` / `ClosedCFrame`. Tween Size and CFrame together with the same easing: the
top (CFrame.Y + Size.Y / 2) then never moves, so nothing pokes out of the drum, the hood or the roof. Set `Moving` while it rolls
and `Open` when it ends.
```lua
local TweenService = game:GetService("TweenService")
local function rollDoor(door: Model, open: boolean, seconds: number?)
	local shutter = door:FindFirstChild("Shutter")
	if not shutter or door:GetAttribute("Moving") or door:GetAttribute("Open") == open then return nil end
	local closedSize, closedCF = shutter:GetAttribute("ClosedSize"), shutter:GetAttribute("ClosedCFrame")
	local h = open and (closedSize.Y - door:GetAttribute("OpenHeight")) or closedSize.Y
	door:SetAttribute("Moving", true)
	local tween = TweenService:Create(shutter, TweenInfo.new(seconds or door:GetAttribute("RollTime") or 4,
		Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Size = Vector3.new(closedSize.X, h, closedSize.Z),
		CFrame = closedCF + Vector3.new(0, (closedSize.Y - h) / 2, 0),
	})
	tween.Completed:Once(function()
		door:SetAttribute("Open", open)
		door:SetAttribute("Moving", false)
	end)
	tween:Play()
	return tween
end
```
- Close instantly (round start / reset): `shutter.Size, shutter.CFrame = ClosedSize, ClosedCFrame`; `Open = false`,
  `Moving = false` (cancel a running tween first).
- Server-side if the door must also stop players / shots while it moves; a client-only cutscene can roll a local copy.

## What DoorManager needs (today it only looks at Workspace.Warehouse)
1. Also collect the doors tagged `Warehouse2Door` (no Panel / prompt / LED on these; skip the prompt wiring for them).
2. `DoorManager.Open(doorOrName, seconds?)` / `DoorManager.Close(doorOrName, seconds?)` (or `SetOpen`) for cutscenes, using
   the code above; return the tween so a cutscene can wait on it.
3. `CloseAll()` (already called by RoundManager `onRoundStart`) closes the Warehouse 2 doors too, instantly, so every round
   starts with both shut.
4. Keep the Warehouse's prompt doors as they are (the Tutorial map).
