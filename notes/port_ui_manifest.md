# UI port manifest (UI session) - everything the UI work added or changed outside Workspace

For the port of Tacticals_rebuild.rbxl to the main game (Edward's call, see notes/port_manifest.md for the map side).
State as of commit `a332412` (2026-10-16), deployed to 8ef4e21a. Sources of truth: `tacticals_rebuild/ui/`, and
`python ui/deploy_ui.py <studio_id>` writes exactly the list below (it replaces Source, or creates the instance).
Easiest port: run `deploy_ui.py` against the main game's Studio window, plus the two runtime notes at the bottom.

## Added (new instances)
| Path | Class | Source file | What it is |
|---|---|---|---|
| `StarterPlayer.StarterPlayerScripts.PadUI` | LocalScript | `ui/pads/PadUI.client.lua` | on-pad bay box, deploy screen (pads + online Found/Teleporting), JOIN boxes; disables `PadQueueUI` at runtime; Studio-only `PadUITestHook` |
| `StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyHudController` | ModuleScript | `ui/hud/LobbyHudController.lua` | scissors pill, daily missions + TO PADS, searching plate, RIVALS-style player list, top-right inset bars; Hide HUD / Hide Missions / Padded HUD / Lobby Data settings |
| `StarterPlayer.StarterPlayerScripts.Client.Controllers.SettingsEffectsController` | ModuleScript | `ui/settings/SettingsEffectsController.lua` | Optimized Lighting / Textures; nests `SoundService.World` under `SoundService.Effects` (SFX volume) |
| `ReplicatedStorage.UIKit.PlayScreen` | ModuleScript | `ui/play/PlayScreen.lua` | full-screen PLAY (3D squad cards, casual / ranked, search + cancel) |
| `ServerScriptService.PublicStats` | Script | `ui/hud/PublicStats.server.lua` | `Level` / `Wins` player attributes from the profile (read-only) |
| `ReplicatedStorage.Modules.Shared.Binds` | ModuleScript | `ui/settings/Binds.lua` | Settings > Hotkeys -> key per action (config key as fallback); used by the [SET] controllers |

## Replaced (existing instances, Source overwritten)
| Path | Source file | Change |
|---|---|---|
| `StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyUIController` | `ui/lobby/LobbyUIController.lua` | top-left card hidden (`PlayerCard`); `Open("Play")` opens `UIKit.PlayScreen`; one full-screen menu at a time (`LobbyUI.CloseScreens`); old top-centre queue pill retired; tooltips hidden when a menu opens; toasts obey Delivery Mode. Keeps the Tacticals session's `[NPC]` NPC_OpensPanel guard. |
| `ReplicatedStorage.UIKit.SettingsData` | `ui/settings/SettingsData.lua` | rows translated to Tacticals (hotkeys = real actions; RIVALS-only rows dropped; storage keys unchanged so saved profiles load) |
| `ReplicatedStorage.Modules.Shared.Config.SettingsConfig` | `ui/settings/SettingsConfig.lua` | dropped the Emotes volume group line |

## [SET] gameplay scripts (Source replaced; handed over by the Tacticals session 2026-10-16)
`deploy_ui.py` backs each original up once to `ServerStorage._RebuildRemoved.SET_<name>_Orig` (UNDO = copy its Source back).
All under `StarterPlayer.StarterPlayerScripts.Client.Controllers`; sources in `ui/set/` (baselines are the first commit of each file).
| Script | What it now reads |
|---|---|
| CameraController | Sensitivity, While Aiming / Scoped, Horizontal / Vertical, Inverted X / Y, Toggle Aim; Aim + Shoulder Swap binds |
| ExplosionController | Camera Shake |
| FlashController | Dark Blinds, Camera Shake (stun sway) |
| WeaponController (+ child WeaponEffects) | Fire / Reload / Equip Gun / Cycle Weapon binds; Hide Muzzle Flashes |
| MovementController | Sprint / Crouch / Slide binds, Toggle Sprint, Auto Sprint (default off), Toggle Crouch (default on = old behaviour), Easy Slide |
| CoverController | Take Cover / Crouch / Dash / Jump-Vault binds, Sprint bind + Auto Sprint |
| HotbarController | Gun Bash / Equip Gun / Melee / Gadget binds, Scroll Equip; hint strip shows your binds; **restyled** (RIVALS-like row, Scale) |
| GadgetController | Throw Gadget bind |
| HealthBarController | **restyled** (RIVALS-like, Scale) |
| TrainingBinsController | **restyled** weapon crate picker (3D guns, dark glass, no olive) |

## Match place (separate place: not ported by this script)
It calls `SettingsConfig.Apply`, so the attributes are there; its copies of the scripts above need the same [SET] reads,
plus the `Binds` module. Rows that only matter there: Hide Teammate Display, Gameplay HUD (Default / Minimal), Damage
Numbers (+ colours), Damage Flashing (+ colours). Raise with Edward.

Training leave: the corner's Leave button needs `PlayerGui.ExfilFade.LeaveTraining` (BindableEvent) from ExfilFX ([EXFIL], Tacticals session);
without it the button stays hidden and ExfilFX's own LEAVE [M] button is used.

## Patched (one line, by `deploy_ui.py` PATCHES)
| Path | Patch |
|---|---|
| `ReplicatedStorage.Modules.Shared.Config.LobbyConfig` | `LobbyConfig.StudioSoloStart = true` -> `false` (only matters in Studio: a bay no longer starts with one player) |

## Runtime-only (nothing to copy, just know it happens)
- `PadUI` sets `PlayerGui.PadQueueUI.Enabled = false` (the old side panel).
- `LobbyHudController` calls `StarterGui:SetCoreGuiEnabled(PlayerList, false)` (our list replaces Roblox's).
- `PlayScreen` turns `TextChatService.ChatWindowConfiguration.Enabled` off while it is open and back after.
- UI icons used: Roblox client textures `rbxasset://textures/ui/...` (no uploads) and existing meshes (`ReplicatedStorage.UIIcons`, `Repository`).

## Not touched by the UI session
Workspace (all map work is the Tacticals session's), PadBoards, QueueManager, MatchmakingManager (Tacticals session's [MM]), ExfilFX ([EXFIL]).
