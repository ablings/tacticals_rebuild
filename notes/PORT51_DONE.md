# PORT51_DONE: live port 51 (2026-10-30, main PC, systems session)

Work order (Lead's plan, approved by Edward): one live port of MOVE1029 + SURVEY1025 + UI survey r2 to all four places; anything
that doesn't PASS after at most 2 fix rounds is left out. Details: notes/port_manifest.md "Live port 51".

## Published (05:00-05:33)
Tutorial 118492914954668, Ranked 122908502889013, Matchmaking 97339328188402, tacticals lobby 126491009194165: Publish As >
Overwrite > Grant Permissions and Publish. Read back in each publishing window (tools/port_readback.lua): SURVEY1025 round 2, LeaveRule,
GLASS edits, no MOVE1029 / UI r2, no test leftovers, compile all ok. Not done: a fresh File > Open from Roblox read-back.

## Shipped
- **SURVEY1025 round 2** (security + data fixes, notes/survey_fix_1025.md) in the lobby, Tutorial, Matchmaking and Ranked:
  FindMatch refused mid-duel ("You're in a match right now!"), SelectWeapon ownership check in every place, receipts granted only after
  a save holding them landed, AssetCheck parked (lobby), one DataManager everywhere + before-release hook, ranked pending mark from
  another server charged, rewards through PlayerStore, the leave rule (a leave after round 1 = loss, also on disconnect), Studio_
  leaderboards in Studio, Template defaults. Graders: 2026-10-25 PASS 8.8; port-51 combined rounds 1 and 2: "may ship".
- **[GLASS] client edits back in Matchmaking / Ranked** (fix/breakable_glass.lua re-run after the build; live ports 47/48 shipped
  without them because the UI deploy rewrote CoverController / CameraController): a vault / climb / dive on House can't carry a player
  out through a window, barriers aren't camera blockers. Its own installer's edits (graded in port 47), idempotent.

## Left out, and why
- **MOVE1029 (movement rework)**: systems grade round 1 FIX 7.0 (blocking: the server facing gate refused honest peek shots, because
  the client's turn reaches the server 0.17-0.43 s after the shot remote, and the refused shot had already spent its ammo). Round-5
  patch fix/move1029_r5.lua (gate flag-only, alive re-check, pull-up refusal no longer teleports): round 2 **FIX 7.9**: honest shots
  12/12 land, but (a) a faked backwards shot is now accepted and only counted, against Edward's 2026-10-29 correction and Proof Check
  A line 24 as written (Edward must choose: "flag, don't block" vs a deferred refusal); (b) the flag counts every honest quick turn
  (decide it ~0.6 s later instead) and is a Player attribute clients can read; (c) the r5 patch edits inside round 4's blocks, so
  round 4's UNDO would half-undo (fold r5 into tools/move_rework_build.py as round 5). Two rounds used: not in this port.
  Builds with MOVE1029 r4 + r5 + SURVEY1025 are kept in out/port51/move1029_r5/ (not committed; rebuild with the installers).
- **UI survey r2**: UI grade **FIX 7.3** (captures/port51/ui/): ~427 hard text strokes remain in the lobby (blocking rule), and the
  px -> Scale conversion regressed phones (toast text 8 px, crosshair dot 1.4 px, hitmarker 2.9 x 0.7 px, stamina bar 1.8 px) and clips
  the tooltip body ("Invite a"). The fixes are UI design work: the list is in notes/ui_survey_r2.md. Not shippable tonight.
  Its installer had a re-apply bug (3 edits applied again on every run): fixed in fix/ui_survey_r2.lua + tools/ui_survey_r2_build.py.

## Tests (on the port-51 builds)
- Unit / install: SURVEY1025 30/30 (Matchmaking, Ranked, Tutorial), 32/32 (lobby); installers re-run all "=".
- Read-back on every build (tools/port_readback.lua): compile all ok, 0 test marks, no StudioTeleportData / hooks, House without
  the Test-only 1965 / illusion work, lobby TestPlaceId kept, LobbySteamFillRound 1, SmokeAlarmRound 3.
- Bot matches (Matchmaking, with MOVE1029 + SURVEY1025 earlier tonight): House, Arena, Warehouse, Warehouse2 to Victory, no errors;
  ranked bot match (result written); final SURVEY-only Matchmaking build: House bot match clean.
- 2 players (Studio server + 2 clients, lobby pad duel on House): FindMatch offline before, refused mid-duel (both players, R1v1),
  offline after; duel played to the end, both back at the pads.
- All three tutorials ran to the end on the MOVE1029 + SURVEY1025 Tutorial build (flashes, valve shots, frag done for real).
  The shipped Tutorial is the live one + SURVEY1025 (unchanged otherwise).
- Grader round 2 replayed: leave rule on disconnect (one loss), FindMatch refused in a lobby duel, receipts (unit).

## For the next session
- tools/port_prep.sh now builds the match places like tonight: UI deploy from ui as of f714708e~1, [GLASS] re-apply, PLAYQUEUE,
  SWITCHNOW, SURVEY1025, read-back. MOVE1029 (+ r5) and UI r2 are listed there as commented lines for the port that ships them.
- Open minors: lobby BotManager lookup warning per shot / vault; two inert DataManager backups in ServerStorage; the Tutorial
  build from match_place_ref would carry House / Warehouse2 geometry (split_build strips only their MapInfo).
