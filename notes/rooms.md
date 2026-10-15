# Tacticals lobby: rooms at a glance (survey 2026-10-14)

Details in `layout.md` (geometry) and `hooks.md` (script dependencies). Plans: `out/survey/plan_*.png`; captures:
`out/survey/cap_*.png`; sheets `out/survey/contact_plans.png`, `contact_captures.png`. +Z = north.

| Area | Purpose now | Size (walkable) / heights | Contents |
|---|---|---|---|
| Hub hall | Spawn, social space, wayfinding to every wing | 172 x 82 (x -86..86, z -41..41); floor 0; catwalks 31; roof 68-73 | Spawn disc + hologram (FX.Hologram) at the centre, 24 floor-prop clusters, crate/cart clutter along the pod bands, kit walls (shop-front bays, pods, catwalks, piers, windows), roof gantries with a moving crane and a circling drone, sky-window screens, beacons, running lights |
| West landing + stairs | Climb to Duels | landing y 4 (x -84..-80); twin 4-wide stairs to y 16 | DUELS sign, stair light, NPC_DuelsOfficer at the top (opens PLAY) |
| Duels | Lobby queue pads (1v1, 2v2, 3v3 x2 each) -> match teleport | 46 x 86 (x -138..-92, z -43..43); floor 16; walls ~70 | 6 pad models (team plates, barriers, holo boards), team-coloured neon, sky beam |
| Energy wall + West deck | Scenic dead end (view out of the base) | gap 9 wide; deck 45 x 60 at y 16 | Energy wall with arcs/motes FX; invisible fence |
| North corridor + Shop | Item shop | corridor 10 x 20 x 12 h; room ~59 x 41, ceiling 13-14 | Counter prompt (Browse SUPPLY -> Shop panel), racks/pedestals, crates, NPC_Quartermaster (opens Kit) |
| South corridor + Armory | Loadout / kit | corridor 10 x 20 x 12 h; room ~61 x 45, ceiling 22 | Gun wall prompt + dais prompt (Kit panel), weapons display tables, spinning featured scissors, benches, NPC_Supply (opens Shop) |
| Exfil tunnel + hangar + pad | Entrance to Training (heli cutscene) | tunnel 22 w x 18 h; hangar x 104..126 roof 21; pad x 126..152 open | Helicopter, ExfilBarrier touch strip, hangar respawn point (112,3.5,0) |
| Training (y 600) | Shooting range with cover, 24 respawning dummies | 172 x 238, ceiling 36 above floor | 4 quadrants of blocks / low walls / pillars, divider walls with windows, centre ring, 16 arrival points, 336 enemy spots |
| Showroom (y 400) | Backdrop for the Kit menu's 3D item viewer (camera only) | ~60 x 54 x 28, non-colliding | Bench, pendant lights, ARMORY sign, display/camera markers |
| City / Times Square | Skyline seen below and around the floating base | City ground y -310; Times Square y -96..144 to the east | Building blocks, 9 animated billboards |

## Main player route
1. Spawn on the hub disc (0,0,0); face along the hall.
2. North 45 studs through the N gate -> Shop (buy) ; or south through the S gate -> Armory (kit). Both are dead-end rooms, back the same way.
3. West: riser -> landing -> stairs -> Duels (stand on a team plate to queue; full pad -> countdown -> match teleport).
   The PLAY menu queues online without walking anywhere.
4. East: tunnel -> hangar -> touch the barrier at the pad -> helicopter cutscene -> Training at y 600; LEAVE / [M] -> hangar.
5. Showroom is never walked to: opening the Kit menu swaps the camera to it.
