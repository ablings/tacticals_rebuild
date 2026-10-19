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

## Live port 9: place split + lobby (2026-10-17 00:36-00:49, lead; Edward: "go")
- Saved both working copies at 00:36. Tutorial_place, Matchmaking_place and Ranked_place.rbxl are copies of match_place_ref,
  converted with `tools/split_build.py place <id> <Kind>`.
- Each was published with Publish As → gunsy funsy → tacticals → **Add as a new place**, then File → Publish (Activity History v3 each):
  - **Tutorial: 118492914954668** (default name "ocxa's Place: 10172026_1")
  - **Matchmaking: 97339328188402** ("…_2")
  - **Ranked: 122908502889013** ("…_3")
  - Rename them in Creator Hub → Places (Edward).
- Lobby `LobbyConfig.TutorialPlaceId` / `MatchmakingPlaceId` / `RankedPlaceId` are set (also in fix/split_lobby_install.lua). The lobby
  was published as **v277**. Live check: PlaceIdFor gives the three ids, and RoundsToWin = 5.
- The lobby v277 also carries: ranked v3, first to 5, the dive fix, the faster lobby load, the free cursor, the camera fix and the ranked UI.
- The old combined place "tutorial spot / matchmaking test" (81861384114744) is no longer routed to; it's kept as a fallback.

## Live port 10: overnight security + touch (2026-10-17 04:08-04:18, lead; Edward: "go go go u have full screen access")
- UI session FREEZE + "touch emulator OK" (Device Simulator) first; both copies saved 04:08 with `tools/save_studio.ps1` (foreground check).
- Copies: Tacticals_main_ported.rbxl (lobby); Tutorial / Matchmaking / Ranked / OldCombined_place.rbxl from match_place_ref, converted
  with `tools/split_build.py place <id> <Kind>` (OldCombined = Matchmaking kind).
- Published (Publish As > gunsy funsy > tacticals > Overwrite > Grant Permissions and Publish), each seen in Activity History and the
  place id checked through the MCP studio list:
  - tacticals (lobby) **v279** (prev v277, mine)
  - Tutorial 118492914954668 ("_1") **v4**, Matchmaking 97339328188402 ("_2") **v4**, Ranked 122908502889013 ("_3") **v4**
  - tutorial spot / matchmaking test 81861384114744 **v115** (prev v113, mine): now the secured Matchmaking build (no forged matches).
- Carries: [SECURE] (MatchSpec, HitRewind, MoveGuard, dodge guard, pass confirm), leaderboard decay, touch controls (InputActions,
  TouchFire, TouchStick, UI session's touch HUD / Layout Editor / Touch tab), Exfil one-way, holo beams, dais clip, UI deploys to 2c8a186.
- Old servers were not force-shut (none expected at 04:00). If anyone reports "WRONG SERVER" on ranked, restart servers in Creator Hub.

## Live port 11: match features (2026-10-17 04:48-04:55, lead; Edward: kill-cam / opening run / victory / crit marker)
- UI FREEZE at 52135e5 (incl. the WeaponController TrainingPadsController line a555ea2). Both copies saved 04:48.
- Published, each checked in Activity History: tacticals (lobby) **v281** (prev v279), Tutorial ("_1") **v6**, Matchmaking ("_2")
  **v6**, Ranked ("_3") **v6** (prev v4 each, mine). The old combined place stays v115 (the secured casual build, no new features).
- Carries: MatchCore kill-cam (SpectateTarget / SpectateReason), round-1 RunIn opening run (RunInClient), final-round Victory
  (WinnerTeam / Winner), the UI session's kill-cam card / victory screen / crit hitmarker, LobbySocial Challenge (lobby),
  tutorial touch lines, TouchStick RunIn gate.

## Live port 12: parties, aim assist, touch icons (2026-10-17 17:53-18:00, lead; Edward: "publish port 12 to both games")
- Both working copies saved 17:53 (incl. the UI session's 39a81ef touch icons / RIVALS buttons / Layout Editor), publish files
  rebuilt from them. Published, each in Activity History: tacticals (lobby) **v283** (prev v281; a stray upload dialog at 17:52
  was closed without granting and never published), Tutorial **v8**, Matchmaking **v8**, Ranked **v8**.
- Places renamed in Creator Hub (Edward): 118492914954668 = **Tutorial**, 97339328188402 = **Matchmaking**,
  122908502889013 = **Ranked**. The old combined place keeps its name ("tutorial spot / matchmaking test", v115).
- Carries: parties (PartyService / LobbyParty / [PARTY] matchmaking + the UI's party screen), aim assist (AimAssist module,
  camera hook, right-stick look, Aim Assist setting, ;aimassist / ;aimnpc), smoke + wall + dead checks, scoreboard, controller
  menus, UI sounds, touch icons.

## Live port 13: tutorial load gate, loadout picker, dock bubbles (2026-10-17 20:51-22:03, lead; Edward: "go publish port 13")
- Both working copies saved 20:51 (UI 6a8af2d loadout pick + dock bubbles; tutorial_wait_loaded fix). Published, each confirmed
  (Activity History / Creator Hub version history, published tick): tacticals (lobby) **v287**, Tutorial **v10**,
  Matchmaking **v10**, Ranked **v10**.
- Notes: a v285 at 18:04 on the lobby was not published by this session (likely the 17:52 stray upload); v287 supersedes it.
  The publish was interrupted three times (Discord on top of Studio taking clicks, Valorant's Vanguard blocking simulated
  input with UIPI, a GPU "DXGI swapchain" error after the Tutorial publish). Lesson: only drive Publish As when Edward is off
  the PC; check the foreground with a screenshot right before every click batch, not just the window title.

## Live port 14: post-match pseudo lobby, result screen, tutorial auto-start fix (2026-10-18 01:23-02:41, lead; Edward: "go")
- Both working copies saved 01:23 (UI a5254be / 4662bcb / 23e8ed7 / 96985bb result + post-match screens; lead 6645356
  post-match installer, a6bf11d tutorial clientLoaded fix). Published to all four places (each window retitled to the place
  name after Grant Permissions and Publish): tacticals (lobby), Tutorial, Matchmaking, Ranked. Expected versions lobby v289,
  the others v12; not yet read back from Creator Hub version history.
- Carries: post-match phase 1 (series of max 3, rematch votes n/needed with a 3 s countdown, Unavailable at 2 wins / 3 games
  / a player gone, To Hub, Play Again with hub AutoQueue), the RIVALS result screen (ranked rank page, ELO pill, tier bar),
  the post-match UI, and the fix for the live v10 tutorial that never auto-started (half-applied clientLoaded edit).
- Ran clean this time with Edward off the PC (Discord was on top once before Ranked; refocused Studio, checked by screenshot).

## Next port (15) checklist: after-match lobby
- Matchmaking / Ranked copies are made from match_place_ref (already has the map, server systems, hooks, assets, and the UI
  session's client). After `split_build place <id> <Kind>`, also run `python ui/deploy_ui.py <sid> --matchmaking` / `--ranked`
  (UI session's match deploy), then save and publish. Lobby: Tacticals_rebuild has fix/party_regroup.lua + the UI's Kit fix c040abb.

## Live port 15: after-match lobby, career stats, Kit statistics (2026-10-18 13:43-14:02, lead; Edward: "publish port 15")
- Both working copies saved 13:43 (UI d6fcf9b Kit Statistics + Duel History, 6dd04b6 RoomFX shift, c040abb Kit icon fix; lead
  after-match lobby phase 2, career stats e329354, audio preload fix 61a1a78). Published, each window retitled to the place name
  after Grant Permissions and Publish: tacticals (lobby), Tutorial, Matchmaking, Ranked. Matchmaking / Ranked: split_build, then
  the UI's `deploy_ui.py <sid> --matchmaking|--ranked`, checked (career / pseudo lobby / postmatch / preload fix / PseudoLobbyMap
  false / SettingsApply) before saving. Versions not read back from Creator Hub yet.
- Two monitors now: the Claude app covers the right one and computer-use captures showed Studio under it while input went to
  Claude (a few clicks, Escape, Alt+F, Alt+Shift+P; nothing typed). Fix: `tools/bring_primary.ps1 <title>` moves the Studio
  window and its popups (the permission prompt opens on the right monitor) onto the primary, then verify with a real capture.

## Live port 16: RIVALS round end, Switch Weapons, 1:1 spectate, notifications, party Whoops (2026-10-18, lead; Edward: "go")
- Working copies saved (lobby 2b73448 incl. the UI's 0b85ff8; match f02eb8f). Published, each retitled after Grant Permissions and
  Publish: tacticals (lobby), Tutorial, Matchmaking, Ranked. Matchmaking / Ranked: split_build, then `deploy_ui.py --matchmaking|
  --ranked` (56 files + 15 [SET]), checked career / pseudo lobby / postmatch / preload / CamSync / RichNotify / streak.
- Carries (lead): Switch Weapons (Pick in RoundEnd / Countdown), WinStreak, FindMatch party refusals, CamSync relay + Watched,
  RichNotify (Task Completed / Item Unlocked / Code Redeemed / Level Up / Rank Up). (UI): round end / killer card / hit vignette /
  switch picker, party crown + Whoops, Notify banner + Inbox + News, spectate camera client, ScopeController, silhouette icons,
  rank divisions, streak flame, RIVALS top-right corner.
- Publish note: twice the File-menu click and the Publish As click in one batch missed (menu not open yet); one step at a time
  with a screenshot between works. The stray clicks only selected parts / moved the editor camera.

## Live port 17: one corner gear (2026-10-18, lead; Edward: "go save and publish port 17")
- Both copies saved with the UI's c5da767 (Inbox + News inside the lobby HUD's corner gear, the separate row gone). Published, each
  retitled after Grant: tacticals (lobby), Tutorial, Matchmaking, Ranked; Matchmaking / Ranked with deploy_ui --matchmaking|--ranked
  and the usual checks. New tools/port_prep.sh does open / split_build / deploy / verify / save / bring-to-primary per place.
- Publish note: click the Studio title bar before File (the first click into a fresh window only focuses it).

## Live port 18: aim assist v2, no aiming while reloading (2026-10-18, lead; Edward AFK: "when you are done you are free to publish the port")
- Both copies saved (a46fec5: lead aff42ae aim assist v2 + command; UI 9397c78 + 83d2778 no ADS while reloading). Published, each retitled after
  Grant: tacticals (lobby; Roblox answered 'server busy, retrying' once, a second Grant went through), Tutorial, Matchmaking, Ranked
  (port_prep.sh: split_build, deploy_ui --matchmaking|--ranked, checks).

## Live port 19: movement, aim pose, peek fairness, hit debug (2026-10-18 ~20:00, lead; Edward: "push the changes to the main game")
- Both copies saved (the match save needed retries: Discord / the Claude app took the foreground). Published on the SECOND monitor
  (Edward on YouTube on the main one; bring_primary.ps1 -secondary, port_prep.sh BRING_ARGS=-secondary), each retitled after Grant:
  tacticals (lobby), Tutorial, Matchmaking, Ranked; all checks true (career / pseudo lobby / postmatch / preload / CamSync / RichNotify /
  streak / hitdebug / AimRaised / HitboxClean / JumpFeel / LobbyMovement).
- Carries: lobby movement + slide (+ touch Slide), JumpFeel 0.75, slide -> sprint / jump-cancel, E-cancel keeps moving, lunge dive, floor
  cover aim, aim pose in the real lean, invisible-head fix, AimRaised, lag-comp cap 0.25 s, hats not hittable, ;hitdebug.
