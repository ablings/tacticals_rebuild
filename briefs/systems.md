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
