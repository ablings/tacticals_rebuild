# Publish 2026-10-30 afternoon: live port 52 + Test port 53 (systems session, main PC)

Edward: "publish what the workers are asking you to publish" (the Lead's plan). Permission rule for out/port51/clk.py was in
`.claude/settings.local.json` at the start. Play lock `publish52`.

## Part 1: Live port 52 (Performance settings), DONE 16:18-16:30
- Tutorial 118492914954668, Ranked 122908502889013, Matchmaking 97339328188402, tacticals lobby 126491009194165: the port-52 files from
  3b606197 unchanged, each read back after the upload (same three [PERFSET] hashes, park, PlaceId; port-51 state otherwise; compile ok
  353 / 364 / 364 / 394). Entry: notes/port_manifest.md "Live port 52". No movement update, no UI r2.

## Part 2: Test port 53 (Test place 99722095417844)
Build `out/publish53/Test_53.rbxl` = out/move_feel/Test_movefeel.rbxl (move feel, reload variants, ANIMFINAL r2, MOVE1029 r4, House 1965 +
illusion, admin gate) plus:
- (a) **fix/guns_v2.lua** with the uploaded meshes (commit 5a0869c2). The 3fb039d0 recolour had wiped all 192 mesh ids from DONE.md and
  the manifests, so the builder now also reads `fix/guns_v2_ids.json` (ids from 94e51d3c; geometry identical, colours = the neutral
  3fb039d0 ones). Mesh parts are placed turned 180 deg about Y (the Import 3D fact); Tool.Grip = identity; melee tools (Knife, Katana,
  Bat, RiotShield) built too; Fists (no Handle) and gadgets (no Tool, built in code by HolsterManager) skipped. Sheath / Saya hidden at rest.
- (b) art/anim/reload_variants/install_sources.lua: 38/38 variants carry PublishedId.
- (c) fix/perf_settings_1030.lua: same hashes as live (31203/1651814608, 10073/101658185, 13907/1388818873), rerun all "=".
- (d) kept: House ArtVersion 1965, HouseIllusionKit, HouseFarField, applyMapSky, WallCover, MOVE1029 round 4, admin gate (PlaceKind Test,
  pre.lua: 0 staging maps, which is what Test port 50 had: House is a normal DuelMaps map there), compile all ok (368).

### Tests
- fix/move_feel_1030_tests.lua 342/342, fix/anim_final_1030_tests.lua 51/51, guns_v2 rerun all "=".
- Meshes: 153 MeshParts, all at a uniform 100x MeshSize/Size (no axis swaps); side view on a white plate: every gun coherent, muzzle
  attachment on the drawn barrel side (captures/publish53/white_sheet.png).
- Wraps: Hazard / Carbon texture the A-channel body parts of Pistol / AutoRifle / Sniper (captures/publish53/wraps.png).
- Play, waiting area, every gun (out/publish53/guns_play.txt): equip; full mag -> reload refused; fire to low -> Reload; fire to empty
  -> ReloadEmpty (Revolver Reload, Sniper Reload after ReloadTactical, Shotgun ReloadShell); mag refills each time; the old flash set
  (PointLight + emitters) sits on the new Muzzle (DualPistols on both barrels).
- Melee in hand: knife blade points forward, katana forward-up, bat upright, shield in front.
- Bot match 1v1 on Warehouse, Arena, Warehouse2, House (TestPlaceHook start): Live, 3 shots accepted on each, no console errors
  (captures/publish53/map_House.png).
- Not done: tools/multiplayer.py 2 players (Edward was using Discord on the agents' monitor; extra Studio windows skipped).

### Grade and publish
- Systems grader r1 (xhigh): **FIX 7.9**. Major: the Dual Pistols' left barrel was torn 0.63 studs off its frame in hand: the old
  DualGrip script re-welds parts by their old names and the rebuilt rig only shares LeftBarrel. Fixed in the installer (commit d4d6171b):
  DualGrip skips GunsV2 tools, HolsterManager roots the worn left copy on LeftFrame, the tool is stamped "building" before the first
  write, UNDO puts the flash set back only on its own muzzle. Measured in Play: 0.000 drift on every static part, no DualGripWeld; tests
  still 342/342 and 51/51; UNDO -> reinstall gives the old look exactly (Knife grip, 5 + 5 Dual flash) and then the identical build.
  Not re-graded (HQ's grader checks after). Pre-existing, not this build: about 30 "wrap texture loaded as sound" warnings per Play.
- **Published to the Test place 17:25-17:31** and read back (notes/port_manifest.md "Test port 53"). Test_place.rbxl = this build.

## What Edward can try on Test (`;testplace` from the lobby, then `;testmatch House 1v1 bots`)
- The new guns and melee models in hand: parts move when you fire and reload; wraps still apply.
- Reload with a few rounds left vs. empty: different reloads.
- Settings > Video > Performance: the five rows.

## Open / for the vault
- The 3fb039d0 recolour regenerated DONE.md and the manifests and wiped the uploaded mesh ids; the builder now keeps ids apart
  (fix/guns_v2_ids.json). Rule: generators that rewrite a manifest must carry over fields they don't own (ids).
- When a model is rebuilt with new part names, grep every script for the old names (PAIRS tables, FindFirstChild literals) and
  re-measure every re-weld in Play.
- This Studio has no Publish As shortcut: File > Publish As (the first click on a background Studio only activates it).
- Gadgets (Frag, Smoke, Flash, Sticky, Landmine, Medkit) and Fists have new meshes but no Tool to put them on: they need code work
  (HolsterManager's gadget models, fist wraps on the arms) before they show.
- Live places still have the old gun models; promoting them = guns_v2 + the anim/reload installs per place (Edward's go).
