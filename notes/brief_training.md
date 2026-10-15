# Training room: Parts-first in Studio, the RIVALS way (Edward, 2026-10-15)

RIVALS built its shooting range in Studio with Parts (Lobby.ShootingRange: 374 Parts vs 70 MeshParts; ~1,180 Parts carry a 5x5 grid
Texture at ~0.75 transparency, grey-tinted; read notes/rivals_style.md on textures and the range). Build Tacticals' Training (floating,
floor y 600, 172 x 238, ceiling ~636) the same way: Parts for floor, walls, cover blocks, barriers, platforms, lane markings; our own
uploaded grid texture TX_overlay_grid (tex/asset_ids.json) on the range boxes the way RIVALS does; Tac material variants and the
palette (neutral greys, olive band at the RIVALS height, cream lines, military-green crates; meshes only where Parts can't do it, e.g.
reuse kit props already imported: crates, drums). Keep the cover layout roughly where it is (gameplay), keep every hook in hooks.md
(FLOOR_Y 600, Arrivals, EnemySpots, TrainingArrive, the y>540 and y<-25 logic, RoomLight Training centre (0,606,0) r175). Hide (UNDO-able)
the old Training geometry it replaces. Idempotent script fix/place_training.lua; checks fix/check_training.lua; before/after captures
out/training/. No extra kid-friendly elements RIVALS doesn't have.
