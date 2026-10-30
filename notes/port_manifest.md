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

## Live port 20: weapon abilities + 8 new items (2026-10-19 ~12:45, lead; Edward in this chat: "alright publish it")
- Both copies saved 12:36 (fa7da81: lead 51c7098 / 5549c93 / 124af4b weapon abilities phases 1-3 + new items; UI a35b48e / 8a02193 /
  3c37777 / 6214147 / 8d35ff8 Kit cards + bars, gadget renders, kill-feed kinds, item HUD). Published on the SECOND monitor, each window
  retitled after Grant: tacticals (lobby), Tutorial, Matchmaking, Ranked (port_prep.sh BRING_ARGS=-secondary: split_build,
  deploy_ui --matchmaking|--ranked, all checks true; every copy carries the [ABILITY2] controllers, Shared.Abilities and PumpShotgun).
- Carries: speed ladder, Quickdraw, Whisper, Run and Gun, 30-round Auto Rifle, Precision Rhythm, one-shot Sniper headshot, Revolver
  knockback into cover, Pump Shotgun, Dual Pistols, Fists vault takedown, Knife slide lunge, Bat, Katana parry, Riot Shield, Sticky
  Grenade, Landmine, Medkit, shop items.
- Publish note: Edward had Firefox in front, so the foreground-guarded save refused and computer use couldn't click (Firefox is
  read-only tier); he closed it, then everything went through. Click File and Publish As in one batch with a wait in between.

## Live port 21: match clock, Kit blur, connected item models (2026-10-19 18:54-19:00, UI session on the SHADOW PC; Edward in this chat: "yeah publish on this pc", then "Yes, you publish it")
- First publish from the Shadow PC (Roblox account whitteguy, group gunsy funsy). Working copies saved 18:40 (a2bcff4: UI f27a2d4 / ed50188
  match clock, 474a994 Kit blur, 83d6997 Pump Shotgun / Bat / Riot Shield rebuilt in both copies). Before publishing, the live tacticals Team
  Create session was fingerprinted against the port-20 Tacticals_main_ported.rbxl: identical (no live edits lost).
- Publish files: Tacticals_main_ported.rbxl = copy of Tacticals_rebuild.rbxl (Technology Future); Tutorial / Matchmaking / Ranked_place.rbxl =
  copies of match_place_ref.rbxl, `split_build place <id> <Kind>`, then `deploy_ui.py --matchmaking|--ranked --force` for those two. Instead of
  out/v.lua / v2.lua (not in the repo), each was diffed script-by-script against its port-20 file: only Armory, DuelHUD and the PumpShotgun /
  Bat tool part counts differed (339 scripts each).
- Published with File > Publish As > gunsy funsy > tacticals > Overwrite > Grant Permissions and Publish, one place at a time, a screenshot
  before every click: tacticals (lobby), Tutorial, Matchmaking, Ranked. Read back from each reopened cloud place through the MCP: place ids
  126491009194165 / 118492914954668 / 97339328188402 / 122908502889013, PlaceKind, the new DuelHUD + Armory, shotgun 9 / bat 6 / shield 4 parts.
  Versions not read back from Creator Hub (not logged in on the Shadow PC's browser).
- Shadow PC notes: the reopened cloud windows show "Applying script changes. Studio will close automatically when complete." on close; the
  lobby was re-read after that and still carried the new build. tools/split_build.py and run_luau_at.py now find mcpcli.py under ~ (were
  hard-coded to C:\Users\aroki).

## Live port 22: Dual Pistols L/R fire, Training trial picker for every slot (2026-10-19 20:40-20:48, Shadow PC lead; Edward in this chat: "go ahead and publish")
- Working copies: lobby saved 20:31 (3a468aa: TrialItem server + the UI's bc44ae7 picker, 21ea714 Dual Pistols), match 20:38 (UI deploy incl.
  bc44ae7's GamepadNavController). Both checked against the repo before copying (49/49, 72/72).
- Publish files built as in port 21. Script-by-script diff vs the port-21 files: lobby = TrainingBinsManager, TrainingBinsController,
  GamepadNavController, WeaponController, WeaponEffects (373 scripts); Tutorial / Matchmaking / Ranked = GamepadNavController, WeaponController,
  WeaponEffects (339 each). Nothing else.
- Published (Publish As > gunsy funsy > tacticals > Overwrite > Grant): tacticals, Tutorial, Matchmaking, Ranked; each read back from the reopened
  cloud place (place id, PlaceKind, the three client hashes, TrainingBinsManager in the lobby). Versions not read from Creator Hub.
- The port-21 cloud windows never finished "Applying script changes" (hung ~90 min, no edits in them) and were force-closed before this publish;
  the port-22 cloud windows were force-closed after the read-back.

## Live port 23: movement spec, draw time + crosshair ring, Training picker flow (2026-10-19 21:29-21:32, Shadow PC lead; Edward: "once you get to a reasonable spot start publishing then continue")
- Working copies saved 21:08 (6582c77), both 49/49 and 72/72 against the repo before copying. Carries: [MOVE2] movement numbers + multipliers
  (068cd91), DrawTime + server draw check + Xhair countdown attributes (ed4f0db), TrialKit (62f0de1), UI 2fb87c0 Kit speed bars,
  62c611e crosshair ring, 303d0bc picker flow.
- Diff vs port 22: lobby 16 scripts (Cover/Melee/Movement/Weapon configs, WeaponAbilities, MoveGuard, CombatManager, TrainingBinsManager,
  Camera/Hotbar/Movement/Weapon controllers, Armory, TrainingBinsController, HUD, LobbyMovement); match places the same minus the two
  Training scripts. Nothing else.
- Published tacticals, Tutorial, Matchmaking, Ranked (Publish As > gunsy funsy > tacticals > Overwrite > Grant); each read back (place id,
  PlaceKind, WeaponController / HUD / MovementConfig hashes, CombatManager draw check, lobby TrainingBinsManager). All Studio windows closed after.

## Live port 24: reload cancel, base speeds -20%, 5 s map vote, rematch, MM_FailReason + MATCH FOUND (2026-10-19 22:03-22:07, Shadow PC lead; Edward: "once you get to a reasonable spot start publishing then continue")
- Working copies saved 21:48 (port 24 freeze commit), 50/50 and 72/72 against the repo. Carries: aa077f1 reload cancel, ac780fd base speeds
  -20% + MatchCore.waitVote, 10751a7 rematch (no cap, votes reset per game), c025ec9 MM_FailReason, UI MatchFoundGate (961f071 / 3a01d8b) and
  the rematch DuelHUD (7b46ce9).
- Diff vs port 23: lobby = Cover/Movement configs, LobbyDuelManager (vote block), MatchmakingManager ([MMFAIL]), MatchCore, MatchFoundGate (new),
  WeaponController, WeaponEffects, DuelHUD; match places = configs, RoundManager (rematch) + its split backup, MatchCore, WeaponController,
  WeaponEffects, DuelHUD. Nothing else.
- Published tacticals, Tutorial, Matchmaking, Ranked; read back from each (place id, PlaceKind, WeaponController / MatchCore / MovementConfig
  hashes, rematch fix in the match places, [MMFAIL] + MatchFoundGate in the lobby). The Ranked comparison window hung on a dialog twice
  (port 23 and 24) and was restarted; screenshot it next time.

## Live port 25: holstered kit on the body (2026-10-19 22:22-22:27, Shadow PC lead; Edward: "once you get to a reasonable spot start publishing then continue")
- Working copies as of 2dfc99b (HolsterManager installed in both, tested in Training and in a 1v1 match). Diff vs port 24: only the new
  ServerScriptService.HolsterManager in every place. Published tacticals, Tutorial, Matchmaking, Ranked; read back (HolsterManager hash in all four).
- The window that hung at every 8th Studio open is Studio's "Low System Resources" dialog: click Proceed (Edward pointed it out).

## Live port 26: Practice Range map, draw from the holster, overnight UI (2026-10-20 ~02:25, main PC lead; Edward in the lead's chat: "model this map ... then publish changes", then "whatever you disagree with on the floor plan just do i am going to sleep")
- Working copies saved 02:17 by the UI session (9f14db8). Published on the second monitor, each window retitled after Grant: tacticals (lobby),
  Tutorial, Matchmaking, Ranked (port_prep.sh BRING_ARGS=-secondary: split_build, deploy_ui --matchmaking|--ranked, all checks true).
  Verified per copy: DuelMaps Warehouse + PracticeRange (Matchmaking / Ranked / lobby; Tutorial strips DuelMaps as always), Workspace.PracticeRange,
  applyMapEnv x3 in RoundManager, CameraController follows ArenaMap, DrawBackLeft PublishedId set, no StudioTeleportData.
- Carries: Practice Range (open-roofed whitebox from Edward's floor plan, 1v1 / 2v2 / 3v3, per-map spawns + lighting; lobby duels 2v2 / 3v3
  pads now open), the 4 draw-from-holster animations, the UI's kill-feed silhouettes + screen-size audit fixes + map-vote aerial card, HUD fit
  (tutorial panel above the hotbar, bigger NOISE meter above HEALTH).

## Live port 27: Practice Range white + training grid (2026-10-20 ~12:00, main PC lead; Edward in the lead's chat: "go")
- From 4d299fd (both copies saved 10:5x). Published on the second monitor, each retitled after Grant: tacticals (lobby), Tutorial,
  Matchmaking, Ranked (port_prep.sh, all checks true; 485 grid textures on Workspace.PracticeRange, applyMapEnv x3).
- Ranked: Studio died with "Device encountered an error: Device removed (0x887a0006)" (GPU) as Publish As opened. The file had already been
  saved by port_prep, so it was reopened, re-verified (v.lua all true) and published from the reopened window.
- Carries: every Practice Range object white SmoothPlastic with the training room's greybox grid (rbxassetid://86361987736184, 5-stud tiles,
  dark at 0.32), one textured floor slab, lobby duel layers re-split.

## Live port 28: controller layout, live picks, restyle, kill feed, results stats, in-match settings (2026-10-20 ~17:30, main PC lead; Edward in the lead's chat: "go")
- From d4ad50b (both copies saved). Published on the second monitor, each retitled after Grant: tacticals (lobby), Tutorial, Matchmaking,
  Ranked (port_prep.sh, all checks true; MatchCore [STATS] + [KILLFEED] present in every copy, applyMapEnv x3, ArenaMap camera).
- Carries: UI (RIVALS controller layout + pad HUD, results glyphs, picker cursor / stays open / next-round label, Leave only solo/test, the
  serious restyle 3bfcb2a / 684d72e in muted tan + dark green, kill-feed silhouettes, DuelHUD headshot line / match point / round fade /
  avatar, in-match Settings gear db66db9, NOISE hidden); lead (live picks queued to round end, Kill payload weapon = item + noscope,
  results Assists / DamageDealt / DamageTaken).

## Live port 29: round flow, gadget throws, hub settings, Device, UI badges (2026-10-20 ~23:28, main PC lead; Edward in the lead's chat: "go")
- From 7514fa9 (both copies saved). Published on the second monitor, each retitled after Grant: tacticals (lobby), Tutorial, Matchmaking,
  Ranked (port_prep.sh, all checks true; [ROUNDFLOW] + DeviceBridge in every copy, HubSettingsBridge lobby only by design, applyMapEnv x3,
  ArenaMap camera, [STATS] / [KILLFEED]).
- Windows' On-Screen Keyboard sat over the Publish dialog part way through; Edward closed it and the publish carried on.
- Carries: UI c8d5798 (badges, device icons, throw tracer, Kit models, field-green buttons, TACTICALS logo on match-search / loading /
  teleport; the teal-fixed logo frame art is still an upload pending), lead (swap weapon until you move or fire, guns fire in RoundEnd
  with no damage, stronger gadget throws 36..105 studs/s + thrown Landmine, hub settings as server attributes, player attribute Device).

## Pending for port 30
- Lobby working copy: deploy the teal-fixed logo frame (UI 03e505a, rbxassetid://78445006727868: lobby/Logo.lua UIKit.Logo + intro/LoadingScreen.lua
  IMG.Backdrop) with ui/deploy_ui.py on the lobby Studio before saving. Match copy already has it (UI session deployed to 7a8bab8a).

## Live port 30: full-strength throws, rematch fix, Dual Pistols grip, UI overnight (2026-10-21 ~12:05, main PC lead; Edward in the lead's chat: "publish it if you haven't")
- Working copies: lobby saved 02:32:55 (UI a173046), match saved 02:34:46 (544a718). A GPU reset ("Device removed") at about 11:5x had
  killed every Studio, so the copies were published from the saved files (nothing unsaved was lost). Published on the second monitor,
  each retitled after Grant: tacticals (lobby), Tutorial, Matchmaking, Ranked (port_prep.sh, all checks true; out/c30.lua in every
  copy: THROWNOW + Frag fuse 2, DualGrip, ROUNDFLOW, STATS, DeviceBridge; match places also REMATCHEARLY + TUTSTUDIO; no test attrs).
- Carries: lead (THROWNOW: every gadget thrown at full strength on press, no charge / roll; Frag fuse 2 s; REMATCHEARLY: Rematch
  pressed during the results counts; DUALGRIP: Dual Pistols left gun in the left hand; TUTSTUDIO Studio-only; abilities installer
  tidy), UI (teal logo frame 03e505a, any-map HUD readability, 3D results character, Shop break-out tiles, Kit Inspect greyed when
  locked + 4:3 fit + green lip, D-pad up Settings in a match, button hover sheen).
- Pending: the 4:3 tutorial cover box overlaps the hotbar during the tutorial itself (UI).

## Live port 31: pre-round, auto-ready, RoundEnd utility, gadget hold, D-pad dash, solid map vote, climb (2026-10-21 ~13:56-14:10, Shadow PC lead; Edward in the lead's chat: "once you get to a reasonable spot start publishing then continue")
- From 7a1a01f (both working copies saved 13:54). Copied to Tacticals_main_ported / Tutorial / Matchmaking / Ranked, built with
  port_prep.sh (Shadow paths; the Ranked window listed as "Game" in MCP, so its split/deploy/save were run by hand), every copy checked
  with out/c31.lua (all true), Publish As > gunsy funsy > tacticals > Overwrite > Grant Permissions and Publish. Tutorial, Matchmaking and
  Ranked read back from the reopened cloud windows (c31 all true); the lobby window retitled "tacticals".
- Carries: crouch/slide track fix (tracks load after Ready), no Ready button (3rd pick = ready), [PREROUND] 5 s countdown + kit locks at
  Live + no aim / melee before Live, gadgets in RoundEnd + cleared at each countdown, MaxHoldTime 5, dash on D-pad up (Settings = hold
  View/Select, Training picker = D-pad down), map vote on the solid backdrop, [CLIMB].
- Pending: CoverClimb has no PublishedId (Edward's group upload): live climbs move without the animation until then.

## Live port 32: weapon feel, RIVALS throws, cooking, wraps v1, hit info, streaming, auto-pay, boards, UI round 3 (2026-10-21 ~19:35-19:50, Shadow PC lead; Edward: "yes you hand off after publishing aswell")
- From the saved working copies (lobby + match, UI 409ec47 + lead 2fed912 / 8123e14). Tacticals_main_ported + Tutorial / Matchmaking /
  Ranked built with port_prep (Shadow paths; Ranked by hand), every copy checked with out/c32.lua (33 checks, all true), Publish As >
  gunsy funsy > tacticals > Overwrite > Grant Permissions and Publish. Tutorial / Matchmaking / Ranked read back from the cloud
  (c32 all true; PlaceKind Matchmaking / Ranked).
- The first lobby attempt stalled: the Claude app sat topmost over Studio and took the clicks; Edward minimized it and it went through.
- Carries: see notes/handoff/HANDOFF_LEAD.md "What shipped in ports 31-32"; UI rounds 1-3 (RIVALS pass) from the UI session.

## Pending for port 33 (lobby copy a41052e)
- [DUELSPEC] Duels TV spectator eye (dc5293b, fix/duels_tv_spectators.lua applied + saved by the UI session). Live check after the port:
  a 2v2 pad duel with someone spectating -> the row shows the eye + count; nobody watching -> "ON A PAD".
- UI session's hub screens pass (0c79a92) and later UI blocks: see notes/handoff/HANDOFF_UI.md.
- 262fd64 (UI): AI-tells pass 2 (tutorial, font sweep, tooltip, Kit bubbles). The match place also has [CALLOUTSTYLE]
  (fix/stealth_callout_style.lua, place-only StealthController: tutorial enemy bubble with a red lip + Oswald). It's already in
  match_place_ref, and port_prep copies match_place_ref, so the port carries it; just check it's there (StealthController source has "[CALLOUTSTYLE]").

## Live port 33 (2026-10-22 ~17:10, main PC lead; Edward in the lead's chat: "go")
- From the saved working copies: lobby a670323, match c316dd5 (the UI session's later unsaved / uncommitted edits were NOT included:
  port_prep's deploy_ui reads the shared working tree, so Matchmaking / Ranked were re-deployed from a clean `git worktree` at
  c316dd5). Published on the XF243Y monitor: tacticals (lobby), Tutorial, Matchmaking, Ranked; each retitled after Grant.
- Checked every copy with out/c33.lua (THROWNOW, COOK, RTHROW, DualGrip, Wraps, ROUNDFLOW, STATS, Device; match places also
  REMATCHEARLY, TUTSTUDIO, CALLOUTSTYLE; lobby HubSettings + DUELSPEC) and out/pre.lua.
- The saved match copy carried `StudioTutorialServer = true` (a test attribute; only read in Studio): cleared in all three match copies
  before publishing (out/clear_test_attrs.lua). Also needs clearing in match_place_ref itself (UI session).
- Carries: UI revamp (tutorial redesign, lobby Phase A + B 1-5, AI-tells passes, RIVALS spacing / nameplates / kill banner, Rubik,
  4:3 pinning, hidden in-match missions / free-reward / login UI), DUELSPEC, CALLOUTSTYLE, hub screens.
- Lessons: the UI session's Studio kept jumping in front of the publish window on the shared monitor (two mis-clicks into it, no
  change); click one step at a time and zoom the title bar first. The Claude app window over Studio swallowed menu-bar clicks until
  Edward minimised it.
- Live check pending: the Duels TV spectator eye (2v2 pad duel + a spectator).

## Live port 34 (2026-10-23 ~02:30, main PC lead; Edward in the lead's chat: "push changes" / "go")
- From the saved working copies: lobby 5fb3a68, match 35ea957 (UI session minimised its Studios and held its saves during the
  publish; Matchmaking / Ranked UI re-deployed from a clean worktree at 5fb3a68). Published on XF243Y: tacticals, Tutorial,
  Matchmaking, Ranked; each retitled after Grant; no stray clicks this time.
- Checked every copy with out/c34.lua (= c33 + ECON2 config / lobby / match + MatchQuestFeed + a loadstring compile of every
  script: "compile all ok" in all four) and out/pre.lua (no test attributes).
- Carries: ECON2 (scissors economy v2: match 10/5/15, daily tiers 100/200/300, weekly -> per-weapon contracts, Legendary 7,500,
  Robux packs 1,000-12,500, +100 per level; login streak; free daily claim; reroll 250; level-up skip 1,000; in-match task feed;
  leaderboard live level) + the UI session's rounds (Kit contracts / level-up buy, Missions streak / reroll / contracts, Shop,
  Codes, Settings, hub polish, new scissors glyphs, contract weapon icons, Shop gear tiles, Codes gift).
- Live checks: weapon contracts paying (needs real weapon kills), the +100 level-up scissors (bot matches never pay), the Duels
  TV spectator eye. Known gap: the match places' after-match lobby has no RerollQuest / LevelUpItem / ClaimDailyFree handlers
  (those live in the hub's LobbyManager); its UI should hide or route those buttons to the hub.

## Live port 35 (2026-10-23, main PC lead; Edward pre-approved in the lead's chat: "you have the greenlight to publish as soon as he's done")
- From the saved working copies at f5fb645 (UI session: "done f5fb645", Studios minimised). Published on XF243Y: tacticals,
  Tutorial, Matchmaking, Ranked; each retitled after Grant; Matchmaking / Ranked UI from a clean worktree at f5fb645.
- Every copy: out/c35.lua (c34 + ARENAFIRST / REVOLVER2 / BESTOF3) all present where expected, "compile all ok"; out/pre.lua clean.
- Carries: lead ARENAFIRST (pad-duel map clones before the preload: the mobile / fresh-account void), REVOLVER2 (knockback on the 2nd
  consecutive Revolver hit, no aim), BESTOF3 (Rematch off once a side has 2 series wins: RematchAllowed false, "Series decided"),
  ECON2 handlers in the after-match lobby; UI mobile fixes (touch buttons, Sprint, auto sprint, auto shoot, double tap on), RIVALS
  layout, MATCH POINT / SUDDEN DEATH ribbon, pad-duel results (no Rematch / Play Again), nameplate rules, Revolver ring removed.
- Live checks: the pad-duel map on a phone (no void), Revolver knockback only on the 2nd hit, Rematch after a 2-0 / 2-1 series.

## Live port 36 (2026-10-23, main PC lead; Edward in the lead's chat: "go and keep going")
- From the pinned working copies: lobby b3086ba, match 38f58a5 (UI session minimised its Studios; Matchmaking / Ranked UI from a
  clean worktree at b3086ba). Published on XF243Y: tacticals, Tutorial, Matchmaking, Ranked; each retitled after Grant
  ("Grant Permissions and Publish" also granted the 3 new gunsy funsy images under Asset Privacy).
- Every copy: out/c35.lua all present where expected, compile all ok; out/pre.lua clean. NEW: a full bot match in the Matchmaking copy
  (Loading -> Live -> kill -> results -> post-match lobby) with the console read: no game errors (51 lines; the only "error" is the
  MCP proxy's own connect message). StudioTeleportData cleared before saving.
- Carries (UI): mobile tutorial redo (real touch buttons ringed), Rubik font fix (Rubik.json never existed: 34 labels were Source
  Sans), matchmaking rounds m1-m28 (Match found screen, MATCH POINT bar, timer, killer card linger, death wash, smaller hotbar /
  hint strip, vote plates, m9 runtime-error fix), lobby rounds r12-r24 + menus e4-e22 (Ranked / Party / Notify / PlayerCards /
  Tooltip), Notify blur no-hang. Lead: none new (RoundEndDelay kept at 3; RIVALS ~5 is Edward's call).
- Live checks: the 3 new images show for a non-group account; the mobile tutorial on a phone.

## Live port 37 (2026-10-23, main PC lead; Edward: "go and keep going")
- From pinned 4bffcd0 (both .rbxl; includes e23). Published on XF243Y: tacticals, Tutorial, Matchmaking, Ranked; each retitled.
- Every copy: c35 all present where expected + compile all ok; pre.lua clean; bot match in the Matchmaking copy ran to the
  post-match lobby with a clean console (51 lines, MCP proxy only).
- Carries (UI): live port 36 check fixes (Party Friends grid not stretched, handles / online lines; inbox age chip off the reward
  boxes; weekly-contract check vs wide rewards; Ranked tile badges = fire shield in every state), e23 inbox / toast icon tile.
- Blocker hit + workaround: computer use was held by the UI session (Obsidian sync / closing the player). The lock cleared ~30 s
  after it ended its turn; the minimised Studio window was restored with user32 ShowWindow(9) (bring_primary alone didn't).

## Live port 38 (2026-10-23, main PC lead; Edward: "keep going") - LOBBY ONLY
- Lobby from pinned 12ff656 (UI "Live-like data round": Warlord leaderboard rows 56 px on a fixed canvas, row plates, top-3 colours).
  match_place_ref unchanged since 4bffcd0 (port 37), so Tutorial / Matchmaking / Ranked were not republished.
- Lobby copy: c35 all present + compile all ok; pre.lua clean. Published tacticals; retitled after Grant.
- Note: once the File menu closed before the Publish As click (the click hit the Toolbox, no change); clicking File and Publish As in
  one batch avoids it.

## Live port 39 (2026-10-23, main PC lead; Edward: "keep going")
- From pinned 81e1f10 (UI "Live-like data rd4", both .rbxl). Published tacticals, Tutorial, Matchmaking, Ranked; each retitled.
- Every copy: c35 + compile all ok; pre.lua clean; Matchmaking bot match to the post-match lobby, console clean (52 lines, MCP only).
- Carries (UI): real-data fixes (inbox fixed canvas, rows reachable; leaderboard no shrink on reopen; party grid no rebuild mid-pop;
  toast bursts no longer 37 s; placed Ranked tile emblem); match Notify (toast burst + inbox canvas).

## Live port 40 (2026-10-23, main PC lead; Edward: "keep going")
- From pinned e80af80 (UI rd5, both .rbxl): inbox close no longer errors (local canvas ref), refits on the unscaled canvas, toast
  burst timing, leaderboard reset to #1 + cached headshots, Ranked rules strip / peak by ELO, opaque modals; match Notify.
- Published tacticals, Tutorial, Matchmaking, Ranked; each retitled. Matchmaking / Ranked UI deployed from a clean worktree at e80af80.
- Every copy: c35 + compile all ok; pre.lua clean; test attrs none. Matchmaking bot match to post-match, OpenInbox/CloseInbox true,
  console clean (51 lines, MCP only).

## Live port 41 (2026-10-23, main PC lead; Edward: "keep going")
- From pinned 321f03d (UI rd6, both .rbxl; Notify only): inbox / toast reward count under its icon, thousands commas.
- Published tacticals, Tutorial, Matchmaking, Ranked; each retitled. Matchmaking / Ranked UI deployed from a clean worktree at 321f03d.
- Every copy: c35 + compile all ok; pre.lua clean; test attrs none. Matchmaking bot match (bo3 data) to Victory / MatchEnd,
  console clean (53 lines, MCP only).

## Live port 42 (2026-10-23 / 25, main PC lead; Edward: "keep going", then "publish it now")
- Lobby + Tutorial from pinned ba2b83c (UI rd8: live inbox refresh, one toast sound per burst, leaderboard / ELO plate polish),
  published 2026-10-23 20:00. Matchmaking / Ranked held while Edward was gaming (publishing takes the mouse), then published
  2026-10-25 with rd8 + PLAYQUEUE (8e951ba): Play Again queues from the match server (MatchmakingManager installed by
  fix/play_again_queue.lua, now run by port_prep), the search pill over Victory / Defeat, a match found = a new match server.
- Every copy: c35 (+ PLAYQUEUE true / mm / pill, test false) + compile all ok; pre.lua clean. Matchmaking bot match (rd8) to
  MatchEnd, console clean (52 lines). PLAYQUEUE Studio-tested on out/pq copies with an in-memory MemoryStore stand-in.
- Live check for Edward: two accounts, finish a match, Play Again on both -> matched into a new Matchmaking server.

## Live port 43 (2026-10-27, Shadow PC, Edward: publish now)
- Edward ~00:47: "Shadow PC now: start straight away and stop cleanly by 01:50 if it isn't finished". Systems session on the Shadow PC,
  account whitteguy, group gunsy funsy. Source: the working copies as committed at b183b90 (match_place_ref.rbxl saved 22:45 = 9daafeb,
  Tacticals_rebuild.rbxl saved 22:52 = 4ba8475).
- What the copies carry since port 42 (git log 4ca70e6..b183b90, place files): only [ARENANAME] (a466ec4) and [ARENAV2] (9daafeb / 4ba8475).
  The match-place build also installs, as port_prep.sh does today: PLAYQUEUE round 6 (fix/play_again_queue.lua, rounds 2-6 = systems grader
  fixes since port 42's round 1) + SWITCHNOW round 5 (fix/switch_now.lua, Edward's Switch Weapons request) + the UI at b183b90 (its
  MatchFlowUI carries the SWITCHNOW client). NOT installed: SURVEY1025 (fix/survey1025_*.lua, 503ee89: security + data fixes "for port 43"
  in notes/survey_fix_1025.md, but not marked pending here and not named in this publish order) -> still to port, lead's call.
- Shadow PC tooling: helper copies in out/port43 (split_build / run_luau_at / deploy_ui with Shadow paths, an MCP client that lists tools
  before calling: the stdio proxy answered "Unable to reach Roblox Studio" until tools/list had run). Repo tools unchanged.
- Checks per copy (out/port43/check.lua, the stand-in for out/c35.lua / pre.lua, which live only on the main PC): DuelMaps = Arena,
  Warehouse; Workspace.Arena LayoutVersion 2 with 105 parts; no PracticeRange outside the ServerStorage archives; no StudioTeleportData /
  Studio / Test attributes; compile all ok.
- **Matchmaking** (97339328188402), published 01:07: match_place_ref copy -> split_build Matchmaking -> deploy_ui --matchmaking (67 + 16 [SET])
  -> PLAYQUEUE 1-10+ module + -> SWITCHNOW (RoundManager=5) -> checks all ok (345 scripts). Bot match (StudioTeleportData me + bot, Arena
  voted in MapVote): map Arena, 5 rounds to Victory 5-0 -> MatchEnd; console clean (58 lines: the known sound "Asset type does not match"
  preload lines, KitGuard / Rematch / MenuPrewarm logs, no errors). StudioTeleportData cleared, saved, Publish As > gunsy funsy > tacticals
  > Matchmaking > Overwrite > Grant Permissions and Publish; window retitled "Matchmaking". Read back from the cloud window: same checks.
- **Ranked** (122908502889013), published 01:12: match_place_ref copy -> split_build Ranked -> deploy_ui --ranked (67 + 16 [SET]) -> PLAYQUEUE
  1-10+ module + -> SWITCHNOW (RoundManager=5) -> checks all ok (345 scripts; no Play test: the bot-match check is Matchmaking's, same build
  path). Saved, Publish As > gunsy funsy > tacticals > Ranked > Overwrite > Grant; window retitled "Ranked"; read back from the cloud window:
  same checks.
- **Tutorial** (118492914954668), published 01:16: match_place_ref copy -> split_build Tutorial (DuelMaps moved to ServerStorage._SplitStripped
  by design: Warehouse, Arena) -> SWITCHNOW (RoundManager=5) -> checks all ok (343 scripts; Workspace.Arena v2 105 parts). Saved, Publish As >
  gunsy funsy > tacticals > Tutorial > Overwrite > Grant; window retitled "Tutorial"; read back from the cloud window: same checks.
- **tacticals lobby** (126491009194165), published 01:26: Tacticals_main_ported.rbxl = copy of Tacticals_rebuild.rbxl (4ba8475) with
  Technology Future (tools/set_technology.py, as in earlier ports). Checks: DuelMaps Arena + Warehouse (Arena modes 1v1/2v2/3v3, Warehouse
  1v1), _DuelSource.Arena 105 parts LayoutVersion 2, ServerStorage.DuelMaps.Arena Solid 103 (101 parts + 2 spawns), no PracticeRange outside
  the archives, no test marks, compile all ok (377 scripts). No SWITCHNOW / SURVEY1025 in the lobby (as live). Play: DuelTestHook bots 2v2 ->
  D1 "arena Arena"; me on Pad_2v2_A with duel solo -> D2 "arena Arena", client "[ArenaLoader] Arena loaded for D2 (1504 instances)", me in the
  slot (5000, 43, 0). Console 28 lines: only the known AssetCheck diagnostic (1/1161 texture in Studio; SURVEY1025 parks it). Play stopped,
  Edit clean (DuelTestSolo / StudioTeleportData nil). Saved, Publish As > gunsy funsy > tacticals > tacticals > Overwrite > Grant; window
  retitled "tacticals"; read back from the cloud window: same checks.
- All four places published and read back, 01:07-01:26. Cloud windows closed (mine only; the map builder's six Studios untouched).
- Live checks for Edward: a lobby pad duel and a Matchmaking match on the Arena (new layout, look E surfaces, grid image granted); Switch
  Weapons mid-round swaps at once in Matchmaking / Ranked; Play Again still queues from the results screen.

### Carried by live port 43: Practice Range renamed to Arena [ARENANAME] (2026-10-26, Shadow PC systems session; planned by the lead, approved by Edward)
- Edward: rename the map "Practice Range" to "Arena" "so the confusion disappears in all code and labels" (the lobby's Training
  room was also called the practice range). Working copies changed and saved: Tacticals_rebuild.rbxl (lobby) and match_place_ref.rbxl
  (match). Matchmaking / Ranked / Tutorial get it at the next port (they are copied from match_place_ref), with Edward's go.
- Names: registry id + folder ReplicatedStorage.DuelMaps.Arena (DisplayName "Arena"), Workspace.Arena (match), ServerStorage._DuelSource.Arena.Arena
  and ServerStorage.DuelMaps.Arena (lobby). The bare name "Arena" is safe: the other "Arena"s are prefixes (ArenaLoader, ArenaMap...,
  DuelArena), keyword values (MatchFlow kind "Arena", the test Teleport "Arena"), or LobbyMap.Training.Arena, looked up only inside
  Training; no script searches "Arena" recursively (scanned in both copies). Training and the Warehouse are untouched.
- How: fix/rename_arena.lua (in place, idempotent, UNDO) in both copies, then fix/duel_split_map.lua with ONLY = "Arena" in the lobby
  (layers identical before / after: Visual 594, Solid 109 instances, same positions, lighting, modes). fix/map_practice_range.lua is
  now fix/map_arena.lua (history in its header). Two toasts reworded: "That teleport isn't open yet." / "Exfil isn't open yet."
- Tested: match copy 1v1 me + bot: the vote shows Arena (aerial render) + Warehouse + Random; Arena won; both spawned inside with the
  Arena lighting (ClockTime 15.2, exposure -0.55); 2 rounds to Victory 2-0, Output clean. Lobby: 2v2 pad duel with test bots
  ("Map: Arena", ArenaLoader "Arena loaded for D1", played to 2-0) and a 3v3 bot duel (all 6 inside). StudioTeleportData cleared.
- Port checks: verify DuelMaps Warehouse + Arena, Workspace.Arena (no PracticeRange anywhere outside the ServerStorage archives).
  Old MatchHistory entries keep the map name "Practice Range" (saved player data, history).
- Left as they are on purpose (Edward's call): the pad message "ARENAS FULL - WAITING" (LobbyDuelManager / lobby_duels_install,
  a string the pad UI and boards show) and the Studio test-server button "BACK TO ARENA" (RangeKitController; goes to the chosen
  map's spawns). Both use "arena" as the generic word for a duel slot / the match, which can now read like the map's name.
- Graded: roblox-systems-grader round 1 FIX 9.1 (builder fallback could hit ArenaLoader's clone; fixed e9a1024), round 2 PASS 9.2.

### Carried by live port 43: Arena v2 layout [ARENAV2] (2026-10-26, Shadow PC map builder; layout approved by Edward 2026-10-26)
- What: the Arena rebuilt to the approved v2 layout (notes/arena_v2_plan.md): 3 lanes, 3 twin windows (centre + 2 lane gates),
  A's 5-high perch + B's 5-high ledge with 22.6° ramps, 25 pillars / 15 walls / 21 low walls; look E surfaces (warm greys, solid
  cover 13 % darker, soft world-aligned grid from our image 86361987736184). Plain Studio Blocks + 2 Wedges, collision = what you see.
- How: fix/map_arena.lua (layout block generated from notes/maps/arena_v2_layout.json by tools/arena_v2_lua.py). Idempotent. First
  run moves v1 + its DuelMaps entry to ServerStorage._ArenaV1_Backup; UNDO = true puts them back.
- Names kept: Workspace.Arena (Floor / Box / Cover / MatchSpawns), MatchSpawns.SpawnA (-670, 0.6, 0) / SpawnB (-530, 0.6, -2.5) facing
  the middle, ReplicatedStorage.DuelMaps.Arena + MapInfo (same Lighting, Size, KillDepth, modes 1v1/2v2/3v3).
  Cover hooks: NotCover on floor, box, decks, curbs, ramps; sills / parapets / pillars / walls / low walls are normal cover.
- Match copy (match_place_ref.rbxl): built + saved 2026-10-26 22:45. Checks: read-back = plan exactly; arena_v2_check on the built
  geometry 0 errors / 0 warnings; MapAudit 0 FAIL / 0 WARN; Play lap passed (see the report in notes/arena_v2_build.md).
- Lobby copy (Tacticals_rebuild.rbxl): duel source rebuilt by fix/map_arena.lua (v1 source in ServerStorage._ArenaV1_Backup), then
  fix/duel_split_map.lua with ONLY = "Arena": Visual 105 parts / 1504 instances, Solid 101 parts (17 NotCover) + 2 spawns, every
  Solid twin = its Visual part. Lobby 3v3 duel (;duelsolo path, me + 5 bots): all 6 on the planned spots, cover / vault / ramp work in
  the slot. Saved 2026-10-26 22:52.
- Port checks: Workspace.Arena:GetAttribute("LayoutVersion") == 2, 105 parts; ServerStorage._ArenaV1_Backup present (can be dropped
  from the published copies once Edward is happy); no StudioTeleportData.

## Live port 44 (2026-10-27, Shadow PC systems session; Edward: "can the map be published as a new map to tacticals?", plan approved)
- What: the new 1v1 map **Warehouse 2** (notes/warehouse2_build.md, round 9 = final look, night look B) in the map vote of
  Matchmaking and Ranked, plus the steam fill it uses ([STEAMFILL] round 5, notes/steam_fill.md). Lobby and Tutorial not
  republished (below).
- Working copy match_place_ref.rbxl (b7eb241): ServerStorage.Warehouse2Kit (22 models / 45 MeshParts + SurfaceAppearances, the
  modeler's Import 3D under gunsy funsy) copied from a private copy of out/warehouse2/Warehouse2_build.rbxl with
  SerializationService through the MCP (base64 in 90,000-char chunks: execute_luau output stops at 100,000 chars); fingerprint
  identical (112 items). fix/map_warehouse2.lua -> Workspace.Warehouse2 + Warehouse2Exterior + DuelMaps.Warehouse2, identical to the
  build copy's round 9 (2,611 items, same hash). fix/steam_fill.lua round 5 after it: 18 edits + 3 modules, hash 984f43e0 -> 2692c1f8,
  second run all "=", fix/steam_fill_tests.lua 63/63. Lighting file values unchanged (= live port 43).
- Matchmaking / Ranked (a758252 / 3216c6f): match_place_ref copy -> split_build -> deploy_ui --matchmaking / --ranked (67 + 16 [SET])
  -> PLAYQUEUE 1-10 + module -> SWITCHNOW (CombatManager 2- = the hub anchor, as always). Shadow helpers in out/port43, checks
  out/port44/check.lua.
- Checks per place (out/port44/check.lua): DuelMaps = Arena, Warehouse, Warehouse2 (DisplayName "Warehouse 2", Modes 1v1, night
  ClockTime 0); Workspace.Warehouse2 905 parts / 77 MeshParts, SteamFill, Indoor; Door_S / Door_N Open=false, Shutter colliding;
  Warehouse2Exterior; 6 shootables; Arena v2 105 parts; no PracticeRange outside archives; no StudioTeleportData / test marks;
  SteamFillRound 5; compile all ok (348 scripts); no scripts in the map / kit but the MapInfo module.
- Matchmaking bot match (StudioTeleportData me + bot): vote screen shows Random / Arena / Warehouse / Warehouse 2
  (captures/port44/mm_vote_warehouse2.png); Warehouse2 voted; night lighting live (Ambient 38,41,50, OutdoorAmbient 84,88,100);
  me and the bot on Warehouse2.MatchSpawns inside the hall; doors shut and solid; 5 rounds to Victory 5-0 -> MatchEnd; lighting back to
  the place defaults in the after-match lobby; Rematch in the same server, Arena voted: Arena lighting (ClockTime 15.2, exposure
  -0.55) and Arena spawns. Output 60 lines, no errors (known sound preload / KitGuard / MenuPrewarm lines).
- Tutorial: split_build Tutorial still strips every DuelMaps entry (scratch copy: Warehouse, Arena, Warehouse2 in
  ServerStorage._SplitStripped), so Warehouse 2 never reaches it. The working copy's shared scripts DID change (steam fill: the
  classic valve's hiss error and misplaced jet fixed on every map, Tutorial 3 included), so the live Tutorial keeps the old valve
  until its next republish; nothing in it breaks. A Tutorial build from this copy also carries Workspace.Warehouse2 (unused).
- **Matchmaking** (97339328188402), published 23:55: Publish As > gunsy funsy > tacticals > Matchmaking > Overwrite > Grant Permissions
  and Publish (also grants the Warehouse 2 mesh / texture assets). Read back from the cloud window (PlaceId 97339328188402): DuelMaps
  Arena, Warehouse, Warehouse2; PlaceKind Matchmaking; Warehouse2 905 parts / 77 MeshParts, doors shut; no test marks; compile all ok
  (348 scripts).
- **Ranked** (122908502889013), published 23:58: same path > Ranked > Overwrite > Grant. Read back (PlaceId 122908502889013): same checks,
  PlaceKind Ranked. No Play test (same build path as Matchmaking, as in port 43).
- Not published: lobby (the vote runs in the match places), Tutorial (above). Grading: a systems grader was started before publishing
  but stopped with the session restart; Edward: publish on the session's own checks, HQ grades after.
- Live checks for Edward: a Matchmaking or Ranked 1v1 shows Warehouse 2 in the vote; on it the hall is at night, doors stay shut,
  shooting a steam valve fills the room with steam.
- Open: the Warehouse 2 vote tile has no picture (shows the roof from above; needs an own capture uploaded under the group);
  steam is the next small job (thickening); GadgetManager.mapFolder / PropController still look only at Workspace.Warehouse
  (grenade / smoke walls and prop noise on the other maps, as on the Arena since port 43); steam fill two-player test still open.

## Live port 45 (2026-10-28, Shadow PC systems session; Edward: "warehouse 2 was never published to the lobby", plan approved) - LOBBY ONLY
- What: Warehouse 2 in the lobby's pad duels (the lobby keeps every map for pad duels; port 44 put it in Matchmaking / Ranked only),
  with its night lighting, shut doors and steam fill in the duel slot. Commit 59b5544 (lobby copy saved 10:32).
- Since live port 43 the lobby copy had NOT changed (Tacticals_rebuild.rbxl untouched since 4ba8475 = port 43's source; no
  pending sections). The House / smoke alarms (held by Edward) were built in their own copies (out/house/lobby.rbxl) and are NOT in
  it: check House=false/false. SURVEY1025 still not in the lobby (as live).
- Lobby copy: ServerStorage.Warehouse2Kit from port 44's serialized kit (out/port44/kitimport.lua, 112 items) -> fix/map_warehouse2.lua
  (new lobby path: _DuelSource.Warehouse2.{Warehouse2, Warehouse2Exterior}, doors ScriptOnly; 905 parts / 77 MeshParts, 2,610
  instances = the match copy) -> fix/duel_split_map.lua ONLY = "Warehouse2" (new MAPS entry, 1v1, night Lighting = the installer's
  NIGHT; Visual 905 parts, Solid 122 parts + 2 spawns; the hall only, so arena slot spacing is unchanged) -> fix/lobby_steam_fill.lua
  round 1 [LOBBYSTEAM] (shared SteamMask / SteamCloud / Fill config byte-identical to the match places; ArenaShootables / ArenaLoader /
  FootstepController edits; idempotent; UNDO back to hash 8ae303f0).
- Pad duel test (Studio Play, me on Pad_1v1_A, DuelTestSolo bot): vote listed Arena / Warehouse / Warehouse 2; Warehouse2 won; me on
  spawn A, bot on spawn B inside the hall (captures/port45/lobby_duel_wh2_spawnA.png); my client at night (ClockTime 0, ambient
  38,41,50, Duel* effects) while the server Lighting (= every hub player's) stayed ClockTime 12 / ambient 121 the whole match; the
  swap is ArenaLoader's, local to the match's clients. Doors: no prompt, shutters collide, a ray from mid-hall hits them. Valve S2
  shot: cloud emitters live, fill reaches 6 and 25 studs, not the far end, footsteps muffled; played to Victory -> MatchEnd, back at
  the pads with lobby lighting. Output: no errors ("D1 arena Warehouse2: 0 doors, 4 barrels, 2 valves").
- **tacticals lobby** (126491009194165), published 10:36: Tacticals_main_ported.rbxl = copy of Tacticals_rebuild.rbxl (59b5544) with
  Technology Future (tools/set_technology.py); checks (out/port45/check.lua) all ok; Publish As > gunsy funsy > tacticals > tacticals >
  Overwrite > Grant Permissions and Publish (grants the Warehouse 2 meshes to the lobby). Read back from the cloud window (PlaceId
  126491009194165): DuelMaps Arena, Warehouse, Warehouse2 (1v1, ClockTime 0), doors ScriptOnly + colliding, LobbySteamFillRound 1,
  no House, no test marks, compile all ok (379 scripts). Cloud window closed untouched.
- Not done: a two-player Studio run (hub player beside a duel); the evidence for "hub unaffected" is the server Lighting plus the
  client-only swap. The lobby AI is not blinded by steam (match places' BotManager edit has no lobby twin). The Warehouse 2 vote tile
  still has no picture (as in Matchmaking).
- Live checks for Edward: a 1v1 pad duel, vote Warehouse 2: night hall, doors stay shut, shooting a valve fills that end with steam;
  a friend in the hub keeps daylight.

## Live port 46 (2026-10-28, Shadow PC systems session; Edward: the Test place work order, his go to publish it + the lobby change) - NEW Test place + LOBBY ONLY
- **Test place (NEW): 99722095417844** in tacticals (universe 10769593848, gunsy funsy), published 17:57 with Publish As > gunsy funsy >
  tacticals > Add as a new place > Grant Permissions and Publish. Source: Test_place.rbxl (commit dd380aa) = match_place_ref.rbxl
  (port 44 state) + `split_build.py place <id> Test` + `test_place_install.lua` round 2 + `deploy_ui.py --matchmaking` +
  `fix/switch_now.lua`; StagingMaps empty; compile 353 ok, no Studio marks. Read back from the retitled cloud window: PlaceId
  99722095417844, GameId 10769593848, PlaceKind Test. Renamed "Test" on Creator Hub (Chrome, Edward's
  logged-in browser); the universe's place list reads 99722095417844:Test, the other five names unchanged.
- **tacticals lobby** (126491009194165), published 18:09: Tacticals_main_ported.rbxl = Tacticals_rebuild.rbxl (ce90e6a) with Technology
  Future. Lobby = live port 45 + `fix/test_lobby_install.lua` only (LobbyConfig.TestPlaceId = 99722095417844, AdminFramework
  Commands/TestPlace). House=false/false. Publish As > gunsy funsy > tacticals > tacticals > Overwrite > Grant Permissions and Publish.
  Read back from the cloud window: PlaceId 126491009194165, DuelMaps Arena / Warehouse / Warehouse2, LobbySteamFillRound 1, no House,
  TestPlaceId 99722095417844, the command module present, compile all ok (381 scripts).
- Matchmaking, Ranked and Tutorial unchanged.
- Tests: notes/test_place.md "Tests" (two-player Server + Clients on the Shadow PC; lobby Play).
- Live check for Edward: in the lobby type `;testplace` (admins only) -> you land in the Test place's waiting area; `;maplist`,
  `;testmatch Arena 1v1 bots`.

## Live port 47 (2026-10-28 20:09-20:40, House map builder; Edward: "Publish now; upload the tile in Browser 1") - House: Matchmaking + Ranked + LOBBY
- What: the new duel map **House** (two-storey modern house, extra map in the vote; every other map stays; Tutorial unchanged) with
  breakable window glass (fix/breakable_glass.lua round 1). Grade: round 5 PASS 8.6, Edward's changes after the sheets, round 6 items
  fixed (notes/house_build.md). Smoke alarms are NOT in this port (separate work, not approved).
- match_place_ref.rbxl (af5ac0d): fix/breakable_glass.lua (match, hash 858f3888 -> 1e6ec360) + tools/house_kit_copy.py from
  out/house/build.rbxl (fingerprint MATCH: 625 instances, 391 MeshParts, 166 SA) + fix/map_house.lua (301 gameplay parts, 448 art parts,
  28 windows, 8 doors, 37 lights; BotConfig CoverFolders += House/CollisionProxies). Read-back 0 differences, walk-through 0, art fit 0.020.
- **Matchmaking** (97339328188402), published 20:09: copy of match_place_ref -> tools/port_prep.sh Matchmaking (split_build, deploy_ui
  --matchmaking, PLAYQUEUE, SWITCHNOW) -> bot match: vote listed Warehouse/Arena/Warehouse2/House, House won, me on A (-34,-19) and
  MatchBot on B (34,19), doors Front/Back Locked, EN Closed, the rest Open, clock 16.2. Publish As > gunsy funsy > tacticals > Matchmaking
  > Overwrite > Grant Permissions and Publish. Read back from the cloud window (tools/house_cloud_readback.lua): PlaceId 97339328188402,
  DuelMaps Warehouse,Arena,Warehouse2,House; PlaceKind Matchmaking; House 615 parts / 273 MeshParts, 293 proxies, 28 windows, 8 doors;
  HouseExterior 166; HouseKit 625; Image rbxassetid://115831329348823; StudioTeleportData nil; 352 scripts, 0 test marks.
  Console: one old "not authorized to grant ... asset 16049574146" (an asset already in the pre-House Matchmaking place, not House) and the
  old WrapConfig "Asset type does not match" lines (pre-existing).
- **Ranked** (122908502889013), published 20:15: same path > Ranked. Read back: same numbers, PlaceKind Ranked.
- **tacticals lobby** (126491009194165), published 20:38: on top of live port 46 (ce90e6a, ;testplace). Tacticals_rebuild.rbxl:
  fix/breakable_glass.lua (hub, hash 6be35ab4 -> 0f5497cf) -> tools/duel_map_port.py match_place_ref -> lobby House House,HouseExterior
  (1,163 instances, 0 missing meshes; no older _DuelSource.House existed) -> fix/house_lobby_prep.lua (exterior folded in, ground/street
  cut to 320, 4 far poles cut; footprint 321 x 360) -> fix/duel_split_map.lua with ONLY = "House" (visual 740 parts, solid 331, modes
  1v1/2v2/3v3). Pad duel (Studio, DuelTestSolo, standing on Pad_1v1_A.Team1): D1 at 4000,100,0, vote House won, me on A (-34,-19), the
  bot on B (34,19), 28 glass + 61 window barriers + 8 doors in the Solid layer, my client at clock 16.2. Test flag cleared, saved 20:32,
  copied to Tacticals_main_ported.rbxl + Technology Future (tools/set_technology.py ... 4). Publish As > gunsy funsy > tacticals >
  tacticals > Overwrite > Grant. Read back (tools/house_cloud_readback_lobby.lua): PlaceId 126491009194165; DuelMaps Warehouse(1v1),
  Arena(1v1,2v2,3v3), Warehouse2(1v1), House(1v1,2v2,3v3); House image set; _DuelSource.House 869 parts / 527 MeshParts; TestPlace command
  + TestPlaceId 99722095417844 kept; ArenaShootables LobbySteamFillRound 1 kept; 383 scripts, 0 test marks.
- Publish notes: Studio's "Auto Recovery File Found" prompt can open off-screen as a borderless 366x40 window that holds the place
  window disabled (Ctrl+S does nothing). Never hide it: bring it on screen and press Ignore. With Studio windows of other sessions open,
  a "front" can lose to their modal dialogs: minimize other Studio windows during Publish As (restore after).
- Live checks for Edward: a Matchmaking or Ranked 1v1 shows House in the vote with its picture; in the house: spawns in the living room
  and the kitchen facing into the room, front/back doors locked, shooting a window breaks the glass but nobody can climb out; a 1v1 pad
  duel in the lobby can vote House.

## Live port 48 (2026-10-28 20:40-20:56 Shadow PC time, House map builder; Edward: "GO FOR IT", then "publish") - House smoke alarms: Matchmaking + Ranked + LOBBY
- What: the two shootable ceiling smoke alarms on House (notes/smoke_alarm.md, installer round 3; systems grader round 2 FIX 8.7, 0
  blocking / 0 major, round-3 minors fixed). On top of live port 47. Tutorial unchanged. Nothing else changed.
- match_place_ref.rbxl (cee3123): fix/smoke_alarm.lua, hash 90fedd14 -> 82903312, tests 47/47.
- **Matchmaking** (97339328188402): copy of the committed port-47 Matchmaking_place.rbxl + the same install (82903312, 47/47); bot match
  on House (shot -> 7 s blare, mask near / not far, housing open, round end -> whole). Publish As > gunsy funsy > tacticals > Matchmaking >
  Overwrite > Grant. Read back (tools/house_cloud_readback.lua): PlaceId 97339328188402, DuelMaps Warehouse,Arena,Warehouse2,House,
  PlaceKind Matchmaking, House 629 parts (+14 = the alarms), 30 shootables (28 windows + 2 alarms), doors Front/Back Locked, EN Closed,
  rest Open, image 115831329348823, 354 scripts (+2), 0 test marks, SmokeAlarmRound 3, 2 alarms.
- **Ranked** (122908502889013): same path; read back the same numbers, PlaceKind Ranked.
- **tacticals lobby** (126491009194165): Tacticals_rebuild.rbxl + fix/smoke_alarm.lua (hub, installer fix 5baa675: the lobby has the fill
  steam, so FillMuffled is hooked instead of the old footstep line; 4c250da8 -> 5192cd63, 47/47) + fix/duel_split_map.lua ONLY = "House"
  (visual 754 / solid 345). Pad duel on House (D2): shot, mask, reset next round. Copied to Tacticals_main_ported.rbxl + Technology
  Future, Publish As > ... > tacticals (search "tacticals") > Overwrite > Grant. Read back: PlaceId 126491009194165, DuelMaps incl.
  House(1v1,2v2,3v3), TestPlace command + id kept, ArenaShootables LobbySteamFillRound 1 kept, 384 scripts, 0 test marks, alarms
  visual 2 / solid 2, round 3, DuelTestSolo nil.
- Incident, no harm: the first File click hit a stale Studio window (Tacticals_main_ported opened before port 47, no House) and opened
  its "Publish with version notes" dialog; cancelled with the Publish button still disabled. Rule: minimize every other Studio window
  before Publish As, and screenshot the File menu (the window title in it) before clicking Publish As.
- Live checks for Edward: in a House match a small white alarm sits on the hall ceiling and the landing ceiling; every half-minute or so
  one chirps (red light blinks); shoot one: it blares ~7 s, the cover drops open, and footsteps near it go quiet; next round it's back.

## Test port 49 (2026-10-29 02:24-03:06, main PC, House map builder; work order: Lead's plan approved by Edward, "publish to the admin-only TEST place ONLY"; Edward 02:00: "Go now") - House 1965 restyle: TEST PLACE ONLY
- What: the House duel map with the gritty 1965 test-site art (art/house/v2, harvest-gold kitchen per Edward, fix65 closed-base
  dining set), breakable glass, both smoke alarms; map grade r4 PASS 8.7 (notes/house_build.md "1965 test-site restyle").
- **Not touched:** match_place_ref, Matchmaking, Ranked, Tutorial, the tacticals lobby (they keep the clean House of ports 47/48).
- Pre-checks: git pull (merged the Shadow PC's harvest-gold recolour), no repo-root .lock newer than 30 min (all from 19:57-20:32),
  no other session mid-port (last port 48, 20:56), no Studio window on a live place or another Test place copy.
- Test_place.rbxl (from dd380aa7) copied to out/house/Test_place_stage.rbxl: fix/breakable_glass.lua (match, 4c4066b8 -> 71373f28),
  tools/house_kit_copy.py build -> stage (MATCH: 832 instances, 465 MeshParts, 278 SA, hash 275383555), fix/map_house.lua (live
  spot -650, 1.2, -450), fix/smoke_alarm.lua (90fedd14 -> 82903312, both alarms). Read-back 0 differences, art fit 0.020.
- **Installed as a normal DuelMaps map, not in StagingMaps.** Staging was tried first (TARGET staging works: StagingMaps.House with
  House + HouseExterior), but the Test place refuses a staging map whose world box overlaps another map: the exterior set (~1800
  studs) overlaps Arena at any nearby spot; at a far spot (ORIGIN_MODE test, z -3200) it placed, but ShootableManager arms glass /
  alarms only at server start (known limit in notes/test_place.md), so a staged House had no working windows or alarms
  (GlassTestHook "no player / window", SmokeAlarmTestHook alarms []). On the Test place the live-place vote never runs (admins pick
  maps with ;testmatch), so a DuelMaps entry there is still admin-only.
- Studio Play on the copy: TestPlaceHook start House 1v1 bots -> "Starting a 1v1 test match on House", phase Playing, me on spawn A
  side, bot on B, clock 15.5, doors Front/Back Locked, EN Closed, rest Open; glass shot -> broken (client: pane hidden, shards shown);
  SmokeAlarm_G shot -> blaring, AlarmBroken true; 2 alarms registered. Play stopped, StudioTeleportData nil. Saved, copied over
  Test_place.rbxl.
- Publish As > gunsy funsy > tacticals > **Test** > Overwrite > Grant Permissions and Publish ("tacticals is ready to test"); the
  permissions prompt opened on the right monitor behind Edward's game (moved it by window handle). Read back from the cloud window
  "Test (placeId: 99722095417844)" (tools/house_cloud_readback.lua): PlaceKind Test; DuelMaps Warehouse, Arena, Warehouse2, House;
  House 754 parts / 398 MeshParts, 293 proxies, 28 windows + 2 alarms, 8 doors as briefed; ArtVersion 1965; 4 fix65 kit pieces;
  MapInfo clock 15.5; HouseKit 832; image set; GlassController present; StudioTeleportData nil; 359 scripts, 0 test marks.
- How Edward plays it: in the tacticals lobby type `;testplace` (admins), then in the Test place `;testmatch House 1v1 bots`
  (or 2v2 / 3v3, `admins` for other admins). Promote later with notes/test_place.md "Promote a map to the live places".

## Test port 50 (2026-10-29 08:17-08:25, main PC, House map builder (illusion pass); work order: Lead's plan approved by Edward, "publish it to the admin-only TEST place only") - House: the world outside the windows: TEST PLACE ONLY
- What: House's exterior made a complete world from every window (illusion grade r4 **PASS 8.8**, notes/house_build.md
  "Illusion pass"): fix/map_sky.lua [MAPSKY] (per-map Sky / Atmosphere / backdrop models / look-only Hide in RoundManager's
  applyMapEnv, restored after the match) + fix/house_illusion.lua [ILLUSION] (porch, stoop, driveway, gravel strip; HouseFarField
  = 54 mid pieces + ground ring to r 4,000 + three mountain tiers, only in Workspace while House is loaded; own sky house_sky4;
  Atmosphere 0.25 / 0.3 / haze 0.7 / (222,198,158); Hide Baseplate, R15, AnimRig; masts and water tower moved in to ~245 studs).
  Kit meshes art/house/illusion (Import 3D, gunsy funsy) live in ServerStorage.HouseIllusionKit (not script-rebuildable: carry it).
- **On top of** the systems session's Test publish of 04:28 (MOVE1029; not in this manifest): its installers were re-run on this
  copy first: fix/move_rework_1029.lua (round 4), fix/noclimb_1029.lua, art/anim/pullup_lean/install_sources.lua,
  fix/house_wallcover.lua; fix/move_rework_1029_tests.lua 92 passed, 0 failed.
- **Not touched:** match_place_ref, Matchmaking, Ranked, Tutorial, the tacticals lobby (the lobby part of fix/map_sky.lua is NOT
  ported: lobby pad duels on House keep the lobby sky until House is promoted).
- Pre-checks: git pull (in sync), no repo-root .lock newer than 30 min, no session mid-port (MOVE1029 ended; its Test window and
  the House builder's read-back window belonged to processes killed by the 05:00 GPU crash), out/test_place/pre.lua: PlaceKind
  Test, DuelMaps Warehouse/Arena/Warehouse2/House, StagingMaps 0, StudioTeleportData nil, no hooks, compile all ok (360).
  BrokenGlass 22 x 0.82 / 6 x 0.30 (= port 49), 0 capture marks, no MapSky / _HouseEnvSaved / _PlaceSkyPark saved.
- File: out/house_illusion/Test_place_illusion.rbxl (saved 07:39) copied over Test_place.rbxl (old one kept as
  out/house_illusion/Test_place_before_port50.rbxl). Publish As > gunsy funsy > tacticals > **Test** > Overwrite > Grant
  Permissions and Publish ("tacticals is ready to test"); console: the old "permission to use asset 16049574146" line only.
- Read back from a fresh cloud window (tools/house_cloud_readback.lua + out/house_illusion/readback_ill.lua): PlaceId
  99722095417844, PlaceVersion 8, PlaceKind Test; DuelMaps Warehouse, Arena, Warehouse2, House; House 754 parts / 398 MeshParts /
  293 proxies / 30 shootables / 8 doors as briefed (Front/Back Locked, EN Closed, rest Open); HouseExterior 141 (+Illusion_Near 7);
  HouseKit 832; HouseIllusionKit 3; RoundManager applyMapSky 1 definition + call + Hide; MapInfo Sky house_sky4, Atmosphere as
  above, Backdrop + Hide, WallCover line kept; HouseFarField 130 parts, 0 flag errors, in MapBackdrops (not Workspace);
  Mast_South at plan (36, -240); CoverConfig MoveRework1029Round 4, WallProxy 67, NoClimb 283; 360 scripts, 0 test marks.
- How Edward sees it: in the tacticals lobby `;testplace` (admins), then `;testmatch House 1v1 bots`; look out of any window,
  also with graphics quality turned down to 1.

## Live port 51 (2026-10-30 02:04-05:33, main PC, systems session; work order: Lead's plan approved by Edward, "one live port of MOVE1029 + SURVEY1025 + UI survey r2 to all four places; anything that doesn't PASS after 2 rounds is left out") - SURVEY1025 + [GLASS] restore: lobby + Tutorial + Matchmaking + Ranked
- **Shipped:** SURVEY1025 round 2 (fix/survey1025_security.lua + fix/survey1025_data.lua: FindMatch refused mid-duel, SelectWeapon
  ownership everywhere, receipts granted after the save landed, AssetCheck parked, one DataManager + before-release hook, ranked
  mark charge, rewards via PlayerStore, leave rule, Studio_ boards, Template defaults); in Matchmaking / Ranked also
  fix/breakable_glass.lua re-run (the [GLASS] Cover / Camera client edits that live ports 47/48 lost to the UI deploy).
- **Left out:** MOVE1029 (systems grade r1 FIX 7.0, r2 FIX 7.9 after the fix/move1029_r5.lua patch: the server facing gate is
  flag-only, so a faked backwards shot lands and is only counted, against the 2026-10-29 correction as written: Edward decides) and
  UI survey r2 (UI grade FIX 7.3: hard strokes remain, phone sizes regressed, tooltip clipped). Why and what's next: notes/PORT51_DONE.md.
- Pre-checks: git pull (up to date), repo-root .locks all from 10-29 (no session mid-port), latest live = port 48, Test ports 49/50
  untouched (House 1965 / illusion stay Test-only: read-back shows no ArtVersion, no HouseIllusionKit, no applyMapSky).
- Builds: the committed port-48 files (git HEAD) + the installers above, each re-run all "=" (SURVEY1025 tests 30/30 match places,
  32/32 lobby); Tacticals_main_ported.rbxl = Tacticals_rebuild.rbxl + Technology Future. match_place_ref.rbxl unchanged (SURVEY1025
  refuses non-split places by design; tools/port_prep.sh now runs it after the split).
- Tests: notes/PORT51_DONE.md (bot matches on all 4 maps, ranked bot match, 2-player lobby pad duel incl. FindMatch refused mid-duel,
  all three tutorials, two systems grader rounds, one UI grade). Final SURVEY-only Matchmaking: House bot match clean.
- Publish As > gunsy funsy > tacticals > <place> > Overwrite > Grant Permissions and Publish ("tacticals is ready to test"), in order:
  **Tutorial** (118492914954668), **Ranked** (122908502889013), **Matchmaking** (97339328188402), **tacticals lobby**
  (126491009194165). Read back with tools/port_readback.lua in each publishing window after the upload (PlaceId set by the upload):
  PlaceKind right, DuelMaps Warehouse/Arena/Warehouse2/House (match places + lobby), Survey1025 security 2 / data 2, LeaveRule, GLASS
  client edits (Matchmaking / Ranked / lobby), SmokeAlarmRound 3, lobby LobbySteamFillRound 1 + TestPlaceId 99722095417844 + AssetCheck
  parked, no MOVE1029 / UI r2 code, StudioTeleportData nil, no hooks, 0 test marks, compile all ok (Tutorial 353, Ranked 364,
  Matchmaking 364, lobby 394). NOT done: a read-back from a fresh File > Open from Roblox window (the shared screen was contended).
- Publish notes: the permission prompt opened on Edward's monitor once (moved by window handle); another agent's "Convert To Package"
  dialog sat topmost over the agents' monitor: moved MY dialog with MoveWindow instead of touching theirs; a "Share Game" notice
  rendered invisibly and blocked Ctrl+S on Tutorial (closed with WM_CLOSE). Publish dialog: the Overwrite button is at window
  (870, 719), not where a half-size screenshot suggests.
- Live checks for Edward: in a lobby pad duel, Play > a queue says "You're in a match right now!"; leaving a casual match after
  round 1 costs the streak; buying credits still grants once.
- Rollback: Creator Hub > tacticals > each place > Version History, restore the version before 2026-10-30 05:00.

## Port 52 PREPARED, NOT PUBLISHED (2026-10-30 11:40-12:00, main PC, systems session; Edward: "go" on notes/perf_settings_1030.md) - [PERFSET] Performance settings: all five places
- What: Settings > Video > Performance: Optimized Lighting (now also lamp shadows, and kept off when a match map turns shadows on:
  bug fixed), Optimized Textures (every map), Fewer Lights, Low Effects, Hide Far Screens; all off by default (notes/perf_settings_1030.md).
- Built on the committed port-51 files (git HEAD 7524f3f4, Test = port 50 c12c0a43) + `fix/perf_settings_1030.lua`, run twice in each
  (second run all "="): Tutorial_place, Ranked_place, Matchmaking_place, Test_place, Tacticals_rebuild (-> Tacticals_main_ported =
  copy + tools/set_technology.py Future), and the source copy match_place_ref. Same three source hashes in every place
  (SettingsData 31203/1651814608, SettingsEffectsController 10073/101658185, ExplosionController 13907/1388818873).
- Checks: Play smoke in Tutorial, Ranked, Matchmaking, Test and the lobby (tools/perf_settings_smoke.lua): 5/5 rows; all on -> GlobalShadows
  off, lamp shadows 0, far lamps off; all off again -> the exact start state; no new console errors (Ranked / Matchmaking: the known
  "infinite yield on HUD" of a Studio server without a match). Saved files checked offline (tools/perf_settings_filecheck.py):
  [PERFSET] x16 + the rows + _PerfSetOrig in all seven; port-51 HEAD has none.
- NOT PUBLISHED: the Publish As step was refused by this session's permission check ("Production Deploy"). To publish, in this
  order: Tutorial (118492914954668), Ranked (122908502889013), Matchmaking (97339328188402), Test (99722095417844), tacticals lobby
  (126491009194165): open the file, Alt+Shift+P > gunsy funsy > tacticals > <place> > Overwrite > Grant Permissions and Publish;
  read back with tools/perf_settings_hash.lua (expects the hashes above, park true, the PlaceId).
- Rollback after a publish: Creator Hub > Version History, the version before this one; or UNDO = true in fix/perf_settings_1030.lua.
