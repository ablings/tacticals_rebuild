# Handoff: Shadow PC -> main PC (2026-10-27 ~01:30, live port 43; Edward: "Shadow PC now: start straight away and stop cleanly by 01:50")

(The previous handoff of 2026-10-19 is in git history.)

## Live now: all four places, nothing left to publish on the main PC
Published from the Shadow PC (account whitteguy, group gunsy funsy) with File > Publish As > gunsy funsy > tacticals > <place> >
Overwrite > Grant Permissions and Publish, each read back from its cloud window. Details: notes/port_manifest.md, "Live port 43".

| Place | Place id | Published | Built from |
|---|---|---|---|
| Matchmaking | 97339328188402 | 01:07 | match_place_ref.rbxl (9daafeb) + split_build + deploy_ui --matchmaking + PLAYQUEUE r6 + SWITCHNOW r5; bot match on the Arena to MatchEnd |
| Ranked | 122908502889013 | 01:12 | same, deploy_ui --ranked |
| Tutorial | 118492914954668 | 01:16 | match_place_ref + split_build Tutorial + SWITCHNOW r5 |
| tacticals (lobby) | 126491009194165 | 01:26 | Tacticals_rebuild.rbxl (4ba8475), Technology Future; pad duel loads the Arena |

Carried: [ARENANAME] (Practice Range -> Arena) and [ARENAV2] (Arena v2 layout). Both moved out of Pending in the manifest.

## Still to port (not published, on purpose)
- **SURVEY1025** (fix/survey1025_security.lua + fix/survey1025_data.lua, 503ee89; notes/survey_fix_1025.md): security + data fixes, written
  "for port 43" but not marked pending in the manifest and not in this publish order. Lead's call; run order in that note. The live match
  places now carry PLAYQUEUE round 6 (not round 1), so no "UNDO round 1 first" step is needed there any more.
- **SWITCHNOW in the lobby**: the match places have it (server + MatchFlowUI client); the lobby copy doesn't (fix/switch_now.lua also patches
  the hub's LobbyDuelManager). Lobby duels behave as before.

## Notes for the main PC
- The six Studios the map builder had open on the Shadow PC were not touched. Mine are closed.
- Shadow PC tooling for ports: out/port43 (not in git): copies of split_build / run_luau_at / deploy_ui with Shadow paths and an MCP client
  that calls tools/list before tools/call (rivals_practice/mcpcli.py got "Unable to reach Roblox Studio" from the stdio proxy otherwise).
  The repo's tools are unchanged.
- out/c35.lua / v.lua / v2.lua / pre.lua exist only on the main PC; port 43 used out/port43/check.lua instead (DuelMaps, Workspace.Arena
  LayoutVersion + parts, PracticeRange names, test attributes, StudioTeleportData, compile all).
- Live checks for Edward: a lobby pad duel and a Matchmaking match on the new Arena (grid image granted on all four); Switch Weapons swaps at
  once mid-round in Matchmaking / Ranked; Play Again still queues from the results screen.
