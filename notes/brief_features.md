# Feature pass (Edward's picks from notes/rivals_diff.md, 2026-10-15)

Picked: **3, 4, 14, 18, 19, 20, 21, 23, 26, 27**, plus the effects **29-32 restyled to our map's theme** (Edward: "for the effects i want
them to be in theme with the map built previously": olive (111,114,57 band / 66,72,36 Neon) / cream (236,232,218) / warm white /
near-black, floating sky military base; NOT RIVALS' purple/gold). Read notes/rivals_diff.md for each item's RIVALS reference and effort.

| # | Item | Work |
|---|---|---|
| 3 | Drop pits + teleporter back to the Duels start | Studio geometry/kit frame + small script (touch -> teleport to the Duels landing) |
| 4 | Range entrance screen showing who's in Training | SurfaceGui screen at the Training entrance (hangar/exfil side), script reads players in Training |
| 14 | Top-player reward stand | kit plinth/pedestal + the existing LobbySpin tag; shows the top player's reward model |
| 18 | Leaderboard TVs | screen part LobbyMap.Signs.Screen_Leaderboard (existing leaderboard code already there) |
| 19 | Live duels TV | screen showing current duel matches/scores from the queue/match state |
| 20 | Likes-goal board + rewarded video-ad board | boards; likes goal from a configurable value (no API for live likes inside a game: use a config/attribute Edward can update); video-ad board only if Roblox's rewarded ads API is usable in this place: otherwise a stub + note |
| 21 | DUELS sign with a live screen | the hub DUELS sign gets a screen with queue counts |
| 23 | Wayfinding labels and floor arrows/chevrons | labels over routes + floor chevrons in cream, to Shop/Armory/Duels/Exfil/Training |
| 26 | TVs on articulated arms | kit model (wall/ceiling arm + TV) used by 18/19/21/4 where they fit |
| 27 | Industrial props | kit: containers, pipes, power boxes, intercoms, in the palette, placed along walls/corridors/hangar |
| 29 | Truss spotlights | warm-white spot fixtures on the trusses aimed at spawn and the showcases (real SpotLights, shadows only on 1-2) |
| 30 | Beacons | military sky-base style (e.g. slow amber/red aviation beacons on masts and the hangar edge), no purple |
| 31 | Sparkles / hologram cones on interactables | cream/olive cones and subtle sparkles on the interactables (shop counter, armory dais, reward stand, holograms) |
| 32 | Vent puff | subtle, bound to real vents only |

Rules: own assets only (no RIVALS ids/code); uploads under Gunsy Funsy; all Studio work in Tacticals_rebuild.rbxl only, idempotent
UNDO-able scripts, script edits marked `[FEAT]` behind flags; screens use Scale-only UI (Edward's rule); keep every hook; re-run all
check_*.lua; captures for Edward.
