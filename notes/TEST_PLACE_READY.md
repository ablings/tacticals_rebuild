# Test place ready (2026-10-28, Shadow PC)

- **Place id: 99722095417844** (tacticals experience, universe 10769593848, group gunsy funsy). Live, admins only.
- Lobby entry live: `;testplace` (admins) in the tacticals lobby takes you there. `LobbyConfig.TestPlaceId = 99722095417844`.
- Source file: `Test_place.rbxl` at the repo root (StagingMaps empty).
- **How to stage a map:** notes/test_place.md "Stage a new map" (build it in a copy of Test_place.rbxl at a free spot,
  `python tools/test_place_build.py stage <window> <MapId> [Extra1,Extra2]`, check `;maplist` / `;testmatch <Id> 1v1 bots` in Play,
  save, copy over Test_place.rbxl, Publish As > gunsy funsy > tacticals > the Test place > Overwrite > Grant).
  In Publish As the place is listed as **Test**.
- How to promote a staged map to Matchmaking / Ranked / the lobby: notes/test_place.md "Promote a map to the live places".
