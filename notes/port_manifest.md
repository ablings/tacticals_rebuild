# Port to the main game (Edward 2026-10-16)

Edward's call: once both sessions are done with what can be done on the copy, port everything (map + UI) into the main game
(place 126491009194165) by **swapping in the whole Workspace.LobbyMap** plus the changed scripts and UI. Edward publishes
himself; we never publish.

## Steps
1. **Freeze the copy:** both sessions finish, run every check, save `Tacticals_rebuild.rbxl`, and commit.
2. **Edward opens the main game in Studio** (File > Open from Roblox), in a separate window next to the copy. We then run
   `list_roblox_studios` for its id.
3. **Back up the main game first** (Edward 2026-10-16: "store the main game in the rebuild file in case anything goes wrong"):
   - Save a whole-file snapshot: File > Save to File as `Documents/tacticals_rebuild/backup/main_before_port_<date>.rbxl`.
     This is local only and isn't published.
   - Store a copy inside the rebuild file, so it travels with it: copy the main game's `Workspace.LobbyMap`, `Lighting`
     children, and every script we will change (with their current sources) into `Tacticals_rebuild.rbxl` as
     `ServerStorage._MainGame_<date>` (LobbyMap, Lighting, Scripts/<full path names>, plus a README StringValue listing
     what came from where).
   - Save the rebuild file and commit.
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

## What was actually done (2026-10-16 13:28-13:40, lead)
- Opened the main game from Studio Home ("tacticals", gunsy funsy, place 126491009194165). It's a **Team Create** place: any edit
  would sync to the cloud, so nothing was edited there. File > Download a Copy to `backup/main_before_port_2026-10-16.rbxl`,
  then Close Place.
- Diffed the main game against the rebuild (`tools/dump_scripts.lua`, service trees):
  - **The main game was unchanged since the 2026-10-14 download.** LobbyMap had 7539 descendants. All 20 scripts that differ
    match our saved originals (_RebuildRemoved *_Orig, _TX_Originals, _Pre43, ui/_survey baselines; the LobbyFX difference
    is our own earlier overlap/lap edits). No instance exists only in the main game, apart from `Lighting.Atmosphere`, which
    our lighting pass removed on purpose.
  - So the rebuild is a strict superset of the main game, and no merging was needed.
- Stored the main game inside the rebuild, as Edward asked: `ServerStorage._MainGame_2026-10-16` holds:
  - its LobbyMap, copied by clipboard (7536 instances). Tags were moved to `_Tags` attributes, its 3 scripts are disabled
    and its prompts are off.
  - `Lighting.LightingJSON`: Soft style, Brightness 1, Exposure 0.6, ShadowMap, plus its 8 Lighting children.
  - a README.
- Saved the rebuild at 13:38 and copied it to **`Tacticals_main_ported.rbxl`**: the port result, with Technology Future.
- **Edward publishes:** open `Tacticals_main_ported.rbxl`, then File > Publish to Roblox As > the existing "tacticals" place.
  Because the place uses Team Create, check that no collaborator has unsaved work open before overwriting.

## Live port (2026-10-16 15:03-15:08, lead; Edward: "full permission to port everything to the tactical lobby and save")
- Froze both sessions and saved the copy at 15:03 (it includes the Showroom armory nook and UI deploys up to 14). Copied it to
  Tacticals_main_ported.rbxl.
- The live place was found open in a Studio window (Team Create). Checked it read-only: scripts identical to the 13:31 baseline,
  LobbyMap 7539, PlaceVersion 256. Closed it with no edits.
- Opened Tacticals_main_ported.rbxl, then File > Save to Roblox As > gunsy funsy > tacticals > the place "tacticals" (not "tutorial
  spot / matchmaking test") > Overwrite. Roblox asked "Some assets need permission to load": granted (Grant Permissions and
  Publish).
- Verified on the place: PlaceId 126491009194165, PlaceVersion 258, LobbyMap 16983, Polish (10 areas), Heli.HX,
  `_MainGame_2026-10-16`, [MM] and [EXFIL] leave markers, UIKit.CodesScreen.
- Rollback: Creator Hub > tacticals > place > Version History, restore version 256. Or open
  `backup/main_before_port_2026-10-16.rbxl` and save it over the place.
- Whether that save also made it live depends on Roblox's Save vs Publish for Team Create places. To be sure, Edward opens the
  place and uses File > Publish to Roblox.

## Live port 2 (2026-10-16 17:01-17:07, lead; Edward: "push these changes to the main game so me and my friend can test")
- The copy was saved at 17:01 (in-lobby duels phases 1-2, UI deploys up to 17+, NoMap pads) and copied to Tacticals_main_ported.rbxl.
- Killed the Team Create window left from port 1 (stuck on "Applying script changes"). Its pending drafts were the 15:08 content
  and could have overwritten the new upload later.
- Reopened the live place fresh: version 258, unchanged since port 1 (LobbyMap 16983, [MM], [EXFIL] leave). Closed it.
- Save to Roblox As > gunsy funsy > tacticals > tacticals > Overwrite, then Grant Permissions and Publish. Version is now **260**.
  Verified on the place: DuelMaps.Warehouse Modes=1v1, LobbyDuelManager, DuelHUD, DuelTestSolo not set.
- Closing it hung again on "Applying script changes": a Team Create artefact after an overwrite. Killed it; it held no edits.
- Rollback: Version History 258 (port 1) or 256 (pre-port).

## Live port 3 (2026-10-16 18:02-18:06, lead; Edward: "go for it")
- Copy saved 18:02 (admin framework, arena props + camera fixes, admin speed in Training) -> Tacticals_main_ported.rbxl.
- Live check before overwrite: version 261 (= our 260 plus a Team Create autosave), LobbyMap 16983, DuelMaps present. No outside changes.
- Save to Roblox As > gunsy funsy > tacticals > **tacticals** row (the row thumbnails had swapped; chose by name) > Overwrite >
  Grant Permissions and Publish. Verified: PlaceId 126491009194165, **version 263**, AdminFramework + DuelMaps present.
- Rollback: Version History 261/260 (port 2), 258 (port 1), 256 (pre-port).

## Live port 4: lobby + match place (2026-10-16 19:22-19:30, lead; Edward: "wait publish as soon as both fixes are in and tested")
- Saved both working copies at 19:22. Port files: Tacticals_main_ported.rbxl, and Match_ported.rbxl (= match_place_ref.rbxl).
- **Lobby:** live was at 264 (= our 263 plus an autosave), unchanged. Overwrote it. Now **version 266**: settings fix, admin, all UI.
- **Match place (81861384114744, "tutorial spot / matchmaking test"):** checked the live place against our copy and backups.
  - Every script on live matched our copy or a saved original. The only two that didn't (SettingsBridge "pass 43", LoadingScreen)
    are the originals the UI session replaced, so nothing on the live place had changed since the 15:24 download.
  - Overwrote it. Now **version 103**: ServerScriptService.Shared.MatchCore, RoundManager [MATCH], MatchState, MatchFlowUI, DuelHUD,
    AdminFramework, Warehouse.CamSkin, and StudioTeleportData not set.
- Rollback: lobby Version History 264/263; match place version 102 (or the local backup/match_place_2026-10-16.rbxl).

## Live port 5: published (2026-10-16 19:57-20:03, lead; Edward: "you can edit the official files now")
- Root cause of the stuck Shop/Missions menus (found by the UI session): a stale saved `ReplicatedStorage.ReplicaRemoteEvents` folder
  in both places, which sometimes made ReplicaController bind to dead remotes. Removed in both; the menu fail-safe is also in.
- The data-release-on-teleport edits (fix/data_release_install.lua) were UNDONE in both places before saving: still untested.
- Lobby: Save to Roblox As → tacticals → Publish → **version 269** (stale folder gone, verified).
- Match place: Save to Roblox As → tutorial spot / matchmaking test → Publish → Activity History "published to version **108**" 8:02 PM.
- **Lesson:** "Save to Roblox As" only SAVES (the versions are stored, but servers keep running the last published one). Always follow it
  with File → Publish in the opened place, and confirm in Activity History ("published to version N").

## Live port 6: published (2026-10-16 20:15-20:18, lead)
- Saved both working copies at 20:15: headshot crosshair (UI), DataManager.ReleaseForTeleport plus the reload-on-failure (`[DATA]`),
  and the HitConfirm headshot 4th argument.
- Used File → **Publish As** (not Save As), which publishes directly. The local-file "Publish" opens a new-experience form; use
  "Update existing experience..." there.
- Activity History: tacticals **published to version 271** (8:16 PM); tutorial spot / matchmaking test **published to version 109** (8:18 PM).

## Live port 7: published (2026-10-16 20:28-20:32, lead)
- Headshot hit marker and crit numbers only when `headshot == true`, so backstabs no longer count (UI session follow-up).
- Published: tacticals **v273** (8:30 PM), tutorial spot / matchmaking test **v111** (8:31 PM), both seen in Activity History.
- The lobby Studio had closed itself earlier; it was reopened as **829eb64d** (tools/*.py updated).

## Live port 8: published (2026-10-16 21:09-21:14, lead; Edward: "you can use my screen now")
- Settings v2 migration (old RIVALS Equip Melee "Three" → Two, Utility "Four" → Three), live re-apply of settings, SettingsScreen
  reload, and the CinematicCamera bob/breathing fix (UI session).
- Published: tacticals **v275** (9:12 PM), tutorial spot / matchmaking test **v113** (9:13 PM), both seen in Activity History.
