# UI survey round 2: the blocking fixes (2026-10-29, UI designer session)

Work order: fix the blocking UI findings from the 2026-10-25 survey (HQ task 20261025065116bc1), ready for a live port,
**not published**. Items 5 (copied RIVALS text) and 7 (RIVALS palette) are untouched (Edward's decisions).

## Status
- Source changes: done and committed (f714708e, 0542c01b).
- Installer: `fix/ui_survey_r2.lua` (built by `tools/ui_survey_r2_build.py`). Offline dry run on the MOVE1029 live builds
  (repo-root Tacticals_main_ported.rbxl / Matchmaking_place.rbxl, saved 04:42-04:55): **0 problems, every edit applies**
  in both places, on top of the MOVE1029, [GLASS] and NoClimb edits (`tools/ui_survey_r2_offline.py`).
- Studio test, audit, captures and grader: **not run yet**. Four working Studio windows were open all morning (House test
  stage, House illusion, two DuelsKitTest) plus three dead "Error" dialogs from the ~05:00 GPU crash. The work order allows
  my one window only with 2 or fewer open.
- The MOVE1029 live port is not published yet either (its session ended after saving the four builds; no port entry).

## What changed (per survey item)
| Item | Fix |
|---|---|
| 1 hard strokes | `Theme.stroke` = 1.5 px @ 0.65 black + `Theme.textStroke(parent, color?)`. Used by Kit.textStroke and Rivals.Kit.textStroke (width ignored), RankedScreen (`stroke()` helper, badge letter, PLAY), PlayRow PLAY, PlayerCards (gold stats, weapon names, action words), HealthBar number (and its on/off fade), Rivals.Toast count, Armory title (fade target = the token), LobbyLabels (both lines + distance fade), Leaderboard board outlines. Level and streak seal numbers keep RIVALS' thick edge (Edward asked for it 2026-10-22) and carry `KeepStroke`. |
| 2 match-only styler | `UIStyleController` is stubbed in the match places (Start does nothing; original in ServerStorage._RebuildRemoved.SET_UIStyleController_Orig). The lobby never had it, so every component now renders the same in all four places. |
| 3 lips / bars | Tooltip "Lip", lobby toast "KindBar" and the ARMORY yellow underline deleted. |
| 4 runtime Offsets | Lobby toast + host (fixed-width pill, text scaled), tooltip (laid out from the screen height every frame, written as Scale), stamina bar, cover hint, scope lens + reticle (px widths as a share of the lens), hitmarker + blocked marker, tutorial target brackets (px floor turned into studs from the camera distance), gamepad selection ring (corner ticks removed: Offset, and the retired 4-corner look). Stored `StarterGui.HUD` / `MainUI`: every Offset converted to Scale of the 1920x1080 design canvas, px-only boxes keep their shape with a UIAspectRatioConstraint. |
| 8 InterfaceController | The lobby's LobbyUI / ShopUI / CutFX skip lines are patched into the match copy. LobbyUI's panel close button is no longer named "Close" (B12). |
| A5 font | Damage numbers: FredokaOne **Regular** (the family ships no Bold). |
| A6 weak tables | CombatFeedback `watched`, Billboard `started`, AimPose `currentPitch` / `raisedAmt`, WeaponEffects `flinchTracks`: strong tables cleared on Destroying (AimPose: dropped when the character leaves). |
| A7 | `StarterGui.MainUI.ResetOnSpawn = false` (it has no scripts). |
| 13 fonts | BayBoards GothamSSm, ExfilFX Oswald, LobbyRangeClient Gotham -> Rubik. |
| 16 Assets | The lobby gets the match places' `UIKit.Assets` (one copy everywhere). |

## Ready for port (when Edward says publish)
1. Build the four places exactly as the MOVE1029 port does (`tools/move_rework_port_build.sh`: split_build -> deploy_ui with
   **pre-f714708e ui** -> breakable_glass -> play_again_queue -> switch_now -> move_rework_1029 (+ tests) -> noclimb ->
   pullup_lean install_sources).
2. **Last:** run `fix/ui_survey_r2.lua` (Studio Edit, execute_luau) in each of lobby, Tutorial, Matchmaking, Ranked. It must
   return `OK ...`; `PROBLEMS` names the script whose anchor moved and changes nothing in it.
3. Never run today's `ui/deploy_ui.py` on a live build: it rewrites whole [SET] scripts from ui/ copies that are behind the
   places (this is how live ports 47/48 lost the [GLASS] edits).
4. Read back: `UIKit.Theme` has `stroke`; `Controllers.UIStyleController` source starts with `-- [UISURVEY]` (match places);
   `StarterGui.MainUI.ResetOnSpawn == false`; `StarterGui.HUD:GetAttribute("UISurveyScale") == true`.

## Tests
(to fill: UI audit counts before / after, Play pass desktop / phone / tablet, sheet notes/ui_survey_r2_sheet.jpg, grader verdict)

## Lessons
- A whole-file deploy from a source folder that isn't the only writer silently rolls back other installers' edits. Ship
  fixes as unique-anchor edits applied last, and dry-run them offline against the build that will ship.
- A styler that runs in some places only makes the same component look different per place; retire it rather than tag
  around it.
