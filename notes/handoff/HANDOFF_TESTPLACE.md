# Handoff: Test place work order, main PC -> Shadow PC (2026-10-28 ~19:30)

Edward (in HQ, mid-task): "save what you are doing close the studio and continue on the shadow pc".

## Done (committed, main PC)
- All code: commit be7c91bf "Test place code [TESTPLACE]" (PlaceKind Test, split routing, fix/test_place_install.lua,
  scripts/testplace/RoundManager_block.lua, scripts/admin/Commands/TestPlace.lua, fix/test_lobby_install.lua, fix/stage_map.lua,
  tools/test_place_build.py, tools/test_place_cap.py). Notes: notes/test_place.md, briefs/systems_test_place.md.
- Tested in a Test place copy (Studio Play, one client): every map (Warehouse 2 as a STAGING map, Arena 2v2, Warehouse 3v3,
  Arena 1v1) to results and back; nothing saved (profile before = after; results TestMatch/TestPlace, 0 XP/scissors, Saved false;
  view-only profiles); refusals; ;endmatch; gate (;simlevel none -> no body, notice, back-to-lobby x2, kick). Details in
  notes/test_place.md "Tests". Install idempotent, UNDO = exact before-hash.
- NOT saved: out/test_place/Test_place.rbxl (save refused: Edward's Discord was in front; no focus stealing). It is rebuilt by
  script in ~5 min (below). Two of my Studio windows may still be open on the main PC: "Test_place.rbxl" and "Server"
  (a test session); both can be closed without saving.

## To do on the Shadow PC
1. `git pull`. Rebuild the Test place copy (notes/test_place.md "Rebuild"): `cp match_place_ref.rbxl out/test_place/Test_place.rbxl`,
   open it, `split_build.py place <id> Test`, `test_place_build.py place Test_place.rbxl`, `deploy_ui.py <id> --matchmaking`,
   `run_luau_at.py <id> fix/switch_now.lua`, `out/test_place/pre.lua`-style check (file is in out/, not in git: compile all ok, no
   Studio marks, StagingMaps empty). Save, `cp out/test_place/Test_place.rbxl Test_place.rbxl`.
   - If the House session published Matchmaking / Ranked in the meantime, match_place_ref.rbxl then has the House: fine (Test gets
     it as a live map).
2. Still open tests: `multiplayer.py start Test_place --players 2` (the main PC's Studio player-count box was 0: set it to 2): one
   admin + one with `;simlevel none <player2>` (rejected, player 1 unaffected), then both admins: `;testmatch Arena 1v1 admins`.
   Lobby: install fix/test_lobby_install.lua in a lobby copy, Play: `;testplace` with id 0 -> "not set up"; with an id -> the Studio
   line; refusals (on a pad / in a duel).
3. Publish (Edward's go is in the work order): Test_place.rbxl > Publish As > gunsy funsy > tacticals > "Add as a new place" named
   **Test**; read back the PlaceId from the cloud window.
4. Lobby-only port: **wait for the House session's "done" + commit hash** (it is publishing the House to Matchmaking / Ranked /
   lobby and owns Tacticals_rebuild.rbxl until then; it asked us not to build the lobby port before that). Then on the
   latest Tacticals_rebuild.rbxl: `test_place_build.py lobby <window> --id=<Test place id>`, Play test, save, copy to
   Tacticals_main_ported.rbxl + `tools/set_technology.py` Future, Publish As > tacticals > Overwrite > Grant, read back.
5. Manifest "Live port 46" + notes/TEST_PLACE_READY.md (place id, how to stage a map: notes/test_place.md). The House map builder
   waits on that file.
