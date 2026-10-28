# Breakable glass: DONE (2026-10-28), for the House map builder

The conventions are final (round 1). Full notes: `notes/breakable_glass.md`.

1. **Window** = a Model under the map's `Shootables` folder with attribute `Shootable = "Glass"`.
   - child `Glass`: the pane (Part / MeshPart, or a Model of parts). Authoring collision doesn't matter: the game turns it off.
   - child `BrokenGlass` (optional): jagged leftovers, authored VISIBLE; the game hides them until the pane breaks.
2. **Barrier** = a Part tagged `WindowBarrier` filling each opening (at least as thick as the wall). The game makes it invisible and
   puts it in the `WindowBarrier` collision group (blocks players and the AI only; every bullet, the camera and the cover probe pass).
   Leaving it in CollisionProxies is fine (never a cover spot). Railings may use the same tag.
3. **Door** = a Model with attribute `DoorState = "Closed" | "Open" | "Locked"`. Only read for now (no mechanic): give doors real
   collision yourself.
4. The map must be in the MapRegistry and placed in Workspace of the match places.
5. Lobby duels: the same window name under `Shootables` in both Solid and Visual; barrier in Solid only; inside the arena box.
6. Install: `fix/breakable_glass.lua` (Edit mode) on each match place after steam fill r5, and on the hub. Idempotent, UNDO-able.
