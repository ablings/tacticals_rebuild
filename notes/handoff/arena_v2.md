# Handoff: Arena v2 build (Shadow PC, 2026-10-26/27)
- Done: Arena v2 built in the match copy and the lobby copy, both saved and pushed. Results: notes/arena_v2_build.md; manifest [ARENAV2] pending (Edward approves ports).
- Open: the roblox-map-grader round 1 (xhigh) started 22:53 had not reported by 00:55. Re-run a fresh grader on the main PC (same brief:
  what was asked = this work order; files = fix/map_arena.lua + tools/arena_v2_*; places = match_place_ref.rbxl, Tacticals_rebuild.rbxl).
  Before saving either place, check ReplicatedStorage.StudioTeleportData is nil and Studio is in Edit (the grader may have play-tested).
- For the lead (script/config changes, not done here): BotConfig.CoverFolders only lists the Warehouse, so bots have no cover on the Arena;
  the crouched head in low cover tops out at 3.8-3.9 above the floor, over the 3.4 low walls (game-wide, Warehouse too).
