# Start here: House map (handoff main PC -> Shadow PC, 2026-10-28 20:41)

## Done
- House is LIVE (live port 47, commit 2848a4ad): Matchmaking 97339328188402, Ranked 122908502889013, tacticals lobby 126491009194165
  (on top of live port 46 ;testplace). All three read back from the cloud (notes/port_manifest.md "Live port 47").
- Every place file is saved and committed: match_place_ref.rbxl (House installed), Matchmaking_place.rbxl, Ranked_place.rbxl,
  Tacticals_rebuild.rbxl (lobby with House + ;testplace), Tacticals_main_ported.rbxl (Technology Future).
- The House build copy out/house/build.rbxl (the source of HouseKit and of every grade round) is force-added to git so it travels
  (out/ is gitignored; build.rbxl is the one file in it we need).
- Build log: notes/house_build.md; layout source tools/house_layout.py -> tools/house_lua.py -> fix/map_house.lua (generated).

## Half-done / open
- Smoke alarms: LIVE since port 48 (2026-10-28, Shadow PC, commit 33464c9d): Matchmaking, Ranked, lobby; read back.
- 1965 restyle: art/house/v2 by the modeler (recolour pending); fix/map_house.lua carries uncommitted-then-checkpointed 1965 wiring
  from the main PC; its build place is NOT in git. Import + swap is the next map-builder step once the modeler pushes.
- Stale Studio windows on the Shadow PC (Tacticals_rebuild.rbxl, Tacticals_main_ported 'tacticals', Test place) were opened before
  port 47: never save them; close without saving.
- Round-5 minor clips kept on purpose (landing bookcase vs MB casing 0.05; upper vanity 0.32 into the doorway width; foyer bench vs
  front-door casing 0.35).
- Uncommitted art/house/v2/* files belong to the House-1965 modeler session (tacticals-rebuild-16); `sync.py leave` checkpoints them.

## Next step
Nothing pending for the House. If Edward reports a live problem: fix in out/house/build.rbxl via tools/house_layout.py + tools/house_lua.py,
re-run tools/house_check.py, then redo the port (notes/house_build.md "Ready to publish" + notes/port_manifest.md "Live port 47").
Publish As tips: minimize other Studio windows first; Studio's "Auto Recovery File Found" prompt may open off-screen and block Ctrl+S:
bring it on screen and press Ignore, never hide it.
