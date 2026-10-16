# Port to the main game (Edward 2026-10-16)

Edward's call: once both sessions are done with what can be done on the copy, port everything (map + UI) into the main game
(place 126491009194165) by **swapping in the whole Workspace.LobbyMap** plus the changed scripts and UI. Edward publishes
himself; we never publish.

## Steps
1. **Freeze the copy:** both sessions finish, run every check, save `Tacticals_rebuild.rbxl`, and commit.
2. **Edward opens the main game in Studio** (File > Open from Roblox), in a separate window next to the copy. We then run
   `list_roblox_studios` for its id.
3. **Back up the main game first:** File > Save to File as `Documents/tacticals_rebuild/backup/main_before_port_<date>.rbxl`.
   This is local only and isn't published.
4. **Diff before overwriting:** for every script we changed, compare the main game's current source with the copy's original.
   The originals are the backups in `ServerStorage._RebuildRemoved.*_Orig`, or the 2026-10-14 download.
   - Equal: safe to replace.
   - Different: Edward changed it in the live game since the download. Merge our marked edit into his version instead of
     overwriting, and flag it.
5. **Swap the map:**
   - Rename the main game's `Workspace.LobbyMap` to `LobbyMap_PrePort` and park it in ServerStorage. Don't delete it.
   - Copy the copy's `Workspace.LobbyMap` across with Studio Explorer copy/paste between the two windows (computer use,
     Ctrl+C / Ctrl+V only).
   - Tags, attributes and the asset ids (all group-owned, uploaded under Gunsy Funsy) travel with it.
6. **Copy the map-side extras outside Workspace:**
   - `ServerStorage.ArmoryWeaponSlots` (the weapon slot config).
   - `ServerStorage._RebuildRemoved`: Heli_Old, the *_Orig backups and the hidden kit stand-ins that UNDO needs. Optional,
     but keeps UNDO working.
   - Lighting: values from `notes/rivals_style.md` / CLAUDE.md lighting state, Lighting children (Atmosphere, Sky), and
     Technology Future (Edward sets it by hand, or `tools/set_technology.py` on a saved file).
   - MaterialService variants used by the map, if any.
7. **Scripts (map side), each a small marked edit; apply the same edit, don't overwrite:**
   - `StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyUIController`: `[NPC]` guard. The UI session also changed
     this file, so take it from its manifest.
   - `PadBoards`: team colours cream/olive.
   - `StarterPlayer.StarterPlayerScripts.ExfilFX`: `[EXFIL]` lift path (from the lift-path pass).
   - `ServerScriptService...Managers.MatchmakingManager`: `[MM]` offline-safe init (`fix/mm_offline_safe.lua`).
   - Others listed in `notes/hooks.md` change log ([TX] TrainingConfig/Training extras, [FEAT] features: leaderboard,
     duels TV, reward stand, ad board, PublicStats if map-side, [PFX] particles, RoomFX). Walk the whole hooks.md log.
8. **UI side:** from the UI session's `notes/port_ui_manifest.md`: StarterGui, ReplicatedStorage.UIKit, client controllers,
   PadUI, LobbyHudController, PublicStats, the LobbyConfig patch.
9. **Verify in the main game's Studio, without publishing:**
   - all check_* scripts;
   - a Play lap: spawn, every room, a duel pad, the exfil cutscene to Training, dummies/bins;
   - console against the baseline;
   - asset check, so no texture/mesh fails from group permissions.
10. **Save locally:** File > Save to File as `backup/main_after_port_<date>.rbxl`. Hand over to Edward to review and publish.

## Risks
- Anything Edward changed in the live LobbyMap after 2026-10-14 is replaced. The old map is kept as `LobbyMap_PrePort` in
  ServerStorage, so it can be compared and restored.
- Assets must be usable by the main game: all uploads are under the Gunsy Funsy group, which owns the game.
- `StreamingEnabled` and Workspace settings in the main game may differ from the copy, so compare them.
