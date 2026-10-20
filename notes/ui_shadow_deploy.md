# Shadow PC: queued UI deployed to the working copies (2026-10-19 ~18:40, UI session on the Shadow PC)

Edward cleared Studio on the Shadow PC. Deployed the three queued items to the two local working copies and saved them
(Save to File only). **Nothing published**; the live Tacticals place (also open in Studio here) was not touched.
Sheet: `notes/ui_shadow_deploy_sheet.jpg`.

## Studio ids (this session, change on reopen)
- Lobby `Tacticals_rebuild.rbxl`: b18c60c4-2f4d-4b8a-856b-90130642bedf
- Match `match_place_ref.rbxl`: 27451635-243a-4d39-a238-abda90b83ab8

## What ran
1. **Live == repo check** before deploying: every deploy target's live Source fingerprint against the repo. Only
   `match/DuelHUD.client.lua` and `lobby/Armory.lua` differed, and both matched the versions just before f27a2d4 / 474a994
   exactly (port 20, nobody edited them). Lobby 47/49, match 70/72 identical.
2. `python ui/deploy_ui.py <lobby> --force` (31 files + 18 [SET]) and `<match> --match --force` (57 + 15). After: 49/49 and 72/72.
3. Model rebuild in both places: `ONLY = { PumpShotgun = true, Bat = true, RiotShield = true }` + `tools/new_weapons/build_new_items.lua`.
   Snapshot before/after: same attributes, Grip, Handle sounds (shotgun Empty/Fire/Reload, melee Hit/Swing), one Muzzle in the
   shotgun, no non-part children lost. Connectivity check (part AABBs touching): each tool is ONE piece. DualPistols
   (LeftBarrel.Muzzle) and Katana untouched.
4. Play checks (play lock `ui`, released):
   - Kit screen (lobby, `ArmoryTestHook`): BlurEffect `ArmoryBackgroundBlur` 8 on, `ArmoryDOF` far 0.85 / focus 13.05 / radius 3;
     the three items render as solid silhouettes (locked) in the Showroom, background blurred, item sharp.
   - Match clock (match, StudioTeleportData 1v1 vs bot, RoundTime 20): countdown 3.1 -> 0.2 in tenths (white), live round
     19.3 ... 5.3 white, **4.9 turns red** (235,70,60) to 0.3; RoundEnd shows the hourglass + white tenths. No 3-2-1 / FIGHT /
     ROUND n banners seen. StudioTeleportData cleared afterwards.

## Notes for the next session
- **MCP execute_luau in the Client VM resets the camera when the call returns** (Kit camera went back to Custom behind the
  player after each call). Drive the Kit with `task.delay` inside one call and screenshot after it returns.
- `require(Armory)` from execute_luau gets a fresh, un-Init'd module copy (`ctx` nil): use `Players.LocalPlayer.ArmoryTestHook`.
- `screen_capture` during Play does not draw the Kit's ViewportFrame item; use a real window screenshot.
- The match copy auto-starts the cover tutorial objective in Studio ("Press [Q] to step out of cover"), pre-existing.
- The Shadow PC vault was not synced yet (no `Lobby UI Kit.md`, no `building-practice/tacticals/`), so the vault lesson is here
  until it syncs.
