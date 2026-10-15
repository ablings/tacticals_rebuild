# Hub polish pass (Studio only), after the switch to Future (2026-10-15)
Studio id 8ef4e21a-3525-484b-91af-79d7677aa213 (Tacticals_rebuild.rbxl). Lighting is now Future + Realistic.
Fix, by script (extend fix/place_hub1.lua or add fix/hub2.lua, idempotent, UNDO-able):
1. Floor reads dark navy-blue; RIVALS floors are dark neutral grey (36-62). Retune floor colours/variants so they render neutral.
2. Olive drums/barrels read lime: use the style guide's military green family, not band olive.
3. New sign boards rendered blank in a fresh capture: make sure the SHOP / ARMORY / EXFIL / DUELS text shows (SurfaceGui on a solid
   backing, Face correct, LightInfluence, recapture after a pause).
4. Stray floating letters ("E", "S") and other old LobbyFX decals/lights left where the old walls were: hide them the same UNDO-able
   way, unless a hook needs them (check hooks.md); old Lights folder entries now inside new walls: hide or move to the new lamp fixtures.
5. Add the lamp SurfaceLights/PointLights in the new wall lamps and ceiling strips, RIVALS style (warm white, 0.2-3 brightness, range
   20-60, only ~15 shadowed in the whole lobby); respect the RoomLight logic in hooks.md.
6. The 0.5-stud dark lip on the top landing (U_East__dark_metal): cover it with a thin floor plate of the new kit colours.
Then captures (same cameras as out/hub1/after_*) into out/hub2/ and out/hub2/compare.jpg (hub1 after vs hub2). Report notes/hub2.md.
No saving, no computer use, never touch other studios. Time-box ~60 minutes.
