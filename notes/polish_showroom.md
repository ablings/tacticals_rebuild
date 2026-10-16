# Overnight polish: Showroom as a clean photo studio

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). No computer use, no
imports, no particles.

| What | Path |
|---|---|
| Polish (idempotent, UNDO flag) | `fix/polish_showroom.lua` -> `python tools/run_luau.py fix/polish_showroom.lua [UNDO]` |
| Check (read-only) | `fix/check_polish_showroom.lua` |
| Captures from the hook camera | `python tools/polish_showroom_capture.py <prefix> [wide]` -> `out/polish/showroom/<prefix>_cam.png` (+ `_blur`) |
| Sheet | `python tools/polish_showroom_sheet.py` -> **`out/polish/showroom/sheet.jpg`** |

## What players actually see (read from LobbyUIController.Armory)
`Armory.Open` sets a Scriptable camera at **CameraPoint's CFrame with FOV 40**, draws the item in a full-screen ViewportFrame lit
along KeyLight -> DisplayPoint, puts a **BlurEffect 16** on the world and a 0.7 UI backdrop tint over it. So the room is only ever
a soft, tinted background: tone and gradient matter, detail doesn't. The capture tool sets FOV 40 and writes a blurred copy; the
sheet also has the real Kit menu in Play (opened with E at the Armory dais).
Frame (rays at FOV 40): the bench fills the bottom edge, the back wall (z 33) the rest, x -24.5..24.5, y ~401..418. The floor
behind the bench is never in frame.

## What changed
1. **Cyclorama**: cream back panel at z 30 (54 wide, to y 425.5), a radius-6 cove of 8 segments down to the floor at z 24, two side
   wings. SmoothPlastic, no shadows cast, nothing collides or is queryable. All 54 frame rays past the plinth land on the cyc.
2. **Props hidden**: the SR_Props crate / case / rack stacks (8 merged meshes) stood at the frame's side edges in front of the sweep.
3. **Plinth**: the stage bench: cream top, warm-grey body, the Metal front plate and the blank front label (both rendered sky-blue)
   to warm Plastic, the front Neon strip off-glow; the thin olive band is the one accent.
4. **Light (own lights only, count unchanged: 6 RoomLight + KeyLight)**: KeyLight neutral-warm 255,244,228, Brightness 2.6, angle
   60 -> 75 (soft); Pendant1/2 -> cool rim lights high behind the display (+-6, 411.5, 15); Pendant3/4 -> background light low
   behind the plinth (+-5, 401.2, 21.5) in small near-black lamp cans with a Neon lens (hidden from the camera by the plinth),
   giving the warm pool on the cove behind the item; Fill neutral.
- **Colour by measurement**: the first cream (232,228,216) rendered cool white 221,229,229 (sky fill); 60% correction still rendered
  neutral (near white the render compresses). Final paint 244,214,180 renders **225,224,213 (back) / 236,232,221 (cove)**, cream.

## Checks
- `check_polish_showroom`: hooks DisplayPoint (0,406.3,8), CameraPoint (0,407.4,-5), BenchTop (0,404.1,8.5; top 404.40 = kit bench
  top), KeyLight (-3,413.8,-1) with its SpotLight: all unchanged; 6 Showroom RoomLight lights (was 6); CameraPoint -> DisplayPoint and
  KeyLight -> DisplayPoint clear (the ViewportFrame's LightDirection is unchanged); 54/54 frame rays on the cyc; **0 clips**; support
  0 bad; 0 new lights / emitters / collidable / queryable.
- **Play**: E at the Armory dais opens the Kit menu: camera Scriptable at (0,407.4,-5), FOV 40, held there; the Pistol sits over the
  cream studio with its fake shadow on the plinth (`play_kit_menu_after.jpg`; before: `play_kit_menu_before.jpg`). Console baseline.
- UNDO round trip: 26 instances restored, Polish.Showroom removed, re-applied identically.
- Note for test scripts: triggering the dais prompt with `InputHoldBegin/End` from a script opened the menu and then left the camera
  in Custom behind the player; a real key press (E) works. Use the keyboard tool for UI tests.
