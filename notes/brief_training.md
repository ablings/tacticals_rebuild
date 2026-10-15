# Training room (Edward, 2026-10-15): keep the current Tacticals Training look as the standard

Edward: "the training room in the actual map is a good standard for what it should look like with grid tiles". RIVALS also builds its
range in Studio with Parts and a 5x5 grid Texture. So Training (floating, floor y 600, 172 x 238, ceiling ~636) is NOT rebuilt from a new
kit. Keep its geometry, layout and grid-tile treatment. Only:
1. Check how it renders under the new lighting (Future + Realistic, RIVALS values): it was designed under the old lighting; adjust
   colours/texture tints/transparency so the grid tiles read the way they did (compare with captures of the live place's Training,
   read-only, and the survey captures) and fit the rebuild palette (neutral greys, the olive accent band where a band exists, cream
   lines; no lime). Respect the RoomLight logic (lights only switch on near the Training centre during play).
2. Fix anything broken (z-fighting, gaps, floating parts) without changing the layout.
3. Keep every hook (FLOOR_Y 600, Arrivals, EnemySpots, TrainingArrive, y>540 / y<-25 logic, RoomLight Training (0,606,0) r175).
Idempotent, UNDO-able script fix/place_training.lua; before/after captures out/training/ (lights forced on for the captures, restored
after); report notes/training.md. No extra kid-friendly elements.
