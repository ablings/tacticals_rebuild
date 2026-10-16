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

---

# Round 2 (2026-10-16): the Showroom as a small sky-base ARMORY NOOK (Edward approved)

Round 1's cream cyclorama read as a grey wash once the UI blurred it. RIVALS' Weapons screen shows the weapon in a **sharp, lit
little room**, so round 2 builds one in the Tacticals palette. Only `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved.**

| What | Path |
|---|---|
| Build (idempotent, UNDO -> back to round 1) | `fix/polish_showroom2.lua` -> `python tools/run_luau.py fix/polish_showroom2.lua [UNDO]` (run after polish_showroom.lua) |
| Check (read-only) | `fix/check_polish_showroom2.lua` |
| Captures | `python tools/polish_showroom_capture.py <prefix> [wide]` (Edit, hook camera); Play captures by hand (below) |
| Sheet | `python tools/polish_showroom2_sheet.py` -> **`out/polish/showroom/sheet2.jpg`** |

## How the Kit menu uses the room (read from LobbyUIController.Armory, unchanged)
- Camera: Scriptable at **CameraPoint's CFrame**, FOV 40, never moves (no orbit). The **item turns** (drag, Inspect 360, fling),
  zooms toward the camera (wheel, up to 2.2x) and slides in/out along screen-right (+-16). It is drawn in a full-screen
  ViewportFrame, so world geometry never occludes it and world lights never light it (its light is Ambient/LightColor +
  LightDirection = KeyLight -> DisplayPoint, read once at build).
- Item size: `min(7.5, natural*3.2) * zoom` corner to corner (zoom 1.05 grenades/fists, 0.95 guns) -> **at most 7.875 diag,
  sphere r 3.94** around DisplayPoint. Largest measured: Fists 7.65, AutoRifle/Sniper/SemiAuto/MiniUzi ~7.13.
- Fake shadow: parts at `BenchTop top + 0.03` = 404.43. BenchTop, DisplayPoint, CameraPoint, KeyLight: untouched (check passes).
- UI cover (1268x785): list panel = left 21 %, cards = right 20 %, slot bar bottom centre -> the set reads mostly in the centre
  and the upper third, so the window, vent and rack top shelves sit high.

## What was built (`LobbyMap.Polish.Showroom2`, 351 parts, all CanCollide/CanQuery/CanTouch false, NotCover)
- **Depth layers**: foreground = the bench (SR_Stage restyled: steel-grey top, dark olive front, olive line) with a sage cutting
  mat (grid + stencil, the shadow surface), a desk lamp (screen right) and a tool tray with oil bottle/brush/rag (screen left);
  mid-ground = the weapon; background = the nook wall at **z 21 (13 studs behind the weapon)** with cheeks at x +-15.
- **Wall**: mid-cream plate (own panel-lines + grime overlays) over a dark olive wainscot and an olive rail, seams, dark crown,
  a cable run (tray, 3 clipped cables, drops to a 240V junction box and the vent).
- **Pegboard** (slotted, olive frame, shadow-board outlines): 2 wrenches, 3 screwdrivers, MAINT LOG clipboard, ear defenders,
  3 spare magazines, a cable spool. No weapons. Strip lamp above it.
- **Window** onto the sky (screen-left high): gradient + clouds + a distant floating pad, chamfered dark frame, mullions,
  glass, cream sill, "OBS PORT 2 - ALT 4,000 FT". **Vent** (screen-right high): 6 chamfered slats, duct to the tray.
- **Rack** (screen right): 3 shelves with olive lips, ammo cans, hard case, OPTICS box, radio, helmet, SPARES/FILTERS boxes,
  spool, warm LED under the top shelf. **Crates**: TAC-04 SUPPLY + 7.62 crate + case (screen left), FRAGILE crate (right).
- **Light** (8 Showroom RoomLights, was 6, budget +3): KeyLight warm 255,228,194 b2.4 angle 70 (shadows); Pendant1 = cool window
  daylight; Pendant2 = strip lamp; Pendant3 = desk lamp; Pendant4 = rack LED; Fill dim cool 0.32; **new** WorkLight (cool spot
  on the crate stack aimed at the wall = rim) and BulkheadLamp (warm, caged, right cheek). Every light has a visible source.
- Round 1's cyclorama + lamp cans: **hidden** (Transparency 1), not deleted.
- Colour by measurement: this set renders paint ~1.3x brighter and bluer (olive 138,156,74 -> 185,204,112), so paints are the
  palette divided by that (olive paint 104,114,46 renders ~146,165,73; wall 196,172,134 renders ~198,194,169 cream).

## Checks (`check_polish_showroom2`)
Hooks unchanged; 8 Showroom RoomLights / 8 lights, 0 untagged; 0 collide/query/touch; **only the Mat lies inside the item sphere**
(it is the bench surface, 1.89 below DisplayPoint, same as the bench itself); frame rays 16:9: 80 set + 37 bench, 0 gaps;
21:9: 84 set + 31 bench, 2 floor rays at the bottom corners (under the UI panels). Play console: baseline only.

## Blur / DOF values for the UI session (tested live in Play, not written to scripts)
Today the room gets ArmoryBackgroundBlur 16 **plus** UIWorldBlur 9.8 (ShowBackdrop("Armory", 0.7) -> 14*0.7) plus a 55 % wash.
Recommended (sheet2 "AFTER" captures):
- `Armory.BACKGROUND_BLUR = 0` (or ArmoryBackgroundBlur.Enabled = false).
- `UITheme.ShowBackdrop("Armory", 0.35)` -> UIWorldBlur **4.9**, wash 27 %, vignette 21 %, grade -0.021 / sat -0.0875.
  (Equivalent alternative tested: ArmoryBackgroundBlur 3 with UIWorldBlur 0.) Total world blur stays <= ~5.
- Add a **DepthOfFieldEffect named `ArmoryDOF`** (not "ArmoryBlur": backgroundBlur() destroys a DOF by that name), enabled only
  while the Kit menu is open: `FocusDistance = (CameraPoint - DisplayPoint).Magnitude` (13.05), `InFocusRadius = 6`,
  `FarIntensity = 0.5`, `NearIntensity = 0`. The item is in a ViewportFrame, so DOF never touches it; Roblox DOF is subtle at
  this distance (even Far 1 / radius 2 only softens the wall), so it is safe and just takes the edge off the far wall.

## Test notes
- **The MCP execute_luau resets CameraType Scriptable -> Custom after each call** ("The execute_luau changed camera type.
  Resetting ..." in the console). That is why script-opened Kit menus ended up behind the player. Open the menu with
  `Players.LocalPlayer.ArmoryTestHook:Invoke("Enter")` (Studio-only BindableFunction), then hold the camera with
  `RunService:BindToRenderStep("CapHold", Last, set Scriptable + CameraPoint CFrame + FOV 40)` before `screen_capture`;
  `ArmoryTestHook:Invoke("Select", id)` switches items. The first capture after Play start can catch the GF intro card: wait ~5 s.
- SurfaceGuis can be missing from the first Edit capture straight after a rebuild: capture again a few seconds later.
- RIVALS reference: its Studio was not open, so no reference column.
