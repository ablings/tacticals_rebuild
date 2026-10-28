# House layout: READY (2026-10-28, map builder)

Final for the modeler and systems:
- Layout data: `notes/maps/house_layout.json` (version 1). Plan: `notes/house_plan.md`, `notes/maps/house_plan.png`.
- Kit list (every mesh, size = its collision box): `briefs/kit-house.json`.
- Windows: 28 openings in `openings[]` (kind "window"; 2 interior gallery windows marked interior). Each opening: wall, axis,
  line, a..b along the wall, z0..z1, wall faces t0..t1. Glass goes in the frame per the breakable-glass convention; the
  builder adds the player-only barrier `Bar_<window id>` (CanCollide on, CanQuery off) filling the opening.
- Checker: `python tools/house_check.py` -> PASS (fair spawns 1v1/2v2/3v3 within 10 %, no spawn sight, landing can't see a spawn).
Coordinates: plan x east, y north, z up; world = ORIGIN + (x, z, -y).
