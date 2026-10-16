# Overnight polish plan (Edward, 2026-10-15 evening)

Edward's ask: polish the lobby overnight with the RIVALS lobby as the reference. Make aesthetically pleasing changes, make **every room
look different, not the same**, and keep everything **logically sound**. Coordinate with the UI session so we don't overlap.

**Blueprint vs theme (Edward, mid-planning):** the RIVALS lobby is the *aesthetics blueprint*: how it is built, its detail density,
lighting method, material variety, line work and readability. The *theme* is ours and should set the game apart from RIVALS: a
floating sky military base in Tacticals' olive/cream. Copy RIVALS' craft, never its subject matter. Every polish choice should make
the base read more military-sky (insignia, stencils, ops screens, cargo, hangar/runway gear, sky views), not more RIVALS.

## Ground rules for the night
- Work target: `Tacticals_rebuild.rbxl`, Studio id **8ef4e21a-3525-484b-91af-79d7677aa213** (second monitor, XF243Y P).
  RIVALS reference: **2e616d06-6bfd-4b39-a751-ddccf8eb9187**, read-only, never saved. The replica window **82b89850** belongs to the UI
  session: don't touch it.
- **No computer use** while the UI session is driving the primary monitor (UG25I) for RIVALS UI capture all night. Everything goes
  through the Studio MCP (execute_luau, screen_capture, start_stop_play, character_navigation) and the Blender MCP.
- **Captures:** Studio MCP screen_capture of a minimised or covered window returns blank white. Run
  `pwsh -NoProfile -File tools/show_studio.ps1 tacticals` (or `rivals`) first. It shows that window on the second monitor with
  SWP_NOACTIVATE, so it never takes focus from the UI session.
- Saves and Import 3D need the screen. Batch them: at the end of each room, message the UI session
  (`local_f4630eda-86ab-4003-89fd-fb92f76724bc`) asking it to pause. Wait for its OK, then save, and Import 3D any queued kit FBX
  (Creator = Gunsy Funsy). Message it again when done. If there is no OK, keep working: every change is a committed, idempotent
  script and can be replayed after a Studio crash.
- Every change lives in `fix/polish_<room>.lua`. Scripts are idempotent and UNDO-able, with originals stored in attributes. Hide old
  geometry, never delete it. No RIVALS ids, meshes or code. Never add kid-friendly elements RIVALS lacks. No ambient particles.
- Builder and reviewer are different agents. After each room: captures, a ref-vs-ours sheet in `out/polish/<room>/`, a commit, the
  vault round log in `building-practice/tacticals/Tacticals Lobby Rebuild.md`, and lessons in the workflow pages.

## Screen schedule with the UI session (Edward, 22:16)
The UI session owns the screen by default. Tacticals gets windows of up to 15 minutes at **23:00, 00:30, 02:00, 03:30, 05:00 and
06:30**. The UI session stops computer use about 2 minutes before each window. I take the screen (second monitor only) to save and
Import 3D, then message "screen free", or "skip" if there's nothing to do. Edward had the UI session halt first so he could grant
the overnight computer-use permissions (Roblox Studio, Blender 5.2).

Saving when the computer-use lock is still held by the paused UI session: front the Tacticals window (AppActivate). Check the
foreground title is `...Tacticals_rebuild.rbxl - Roblox Studio`, send Ctrl+S with SendKeys (that is Save to File for a place
opened from file), then check the .rbxl modified time and that the foreground title didn't change, meaning no dialog opened.

## Room identities (same RIVALS language, a different mood per room)
Shared language everywhere: near-black floors, mid-grey walls, Neon accent lines, the olive/cream palette as thin lines only. The
rooms differ by **light colour/temperature, key material, signature prop and accent ratio**:

| Room | Identity | Light | Key material / props | Accent |
|---|---|---|---|---|
| Hub (command deck) | Heart of the base: open, bright, the spawn disc as the hero | warm sun from the skylights, warm-white ceiling strips | concrete panels, olive bands, flag/insignia banners, ops screens | olive dominant, cream lines |
| N/S gate corridors | Airlock bulkheads: short, tight, transitional | cool white strips, door status lights | ribbed corrugated metal, hazard-stripe sills | near-black + cream hazard |
| Shop (quartermaster) | Warm store: inviting, retail-like | warm 3000K pools over counters and shelves | wood shelving, cream counter, price boards, crates of stock | cream dominant, olive trim |
| Armory (weapons bay) | Darker gunmetal vault: cool and focused | cool 6500K rack lights, a hard spotlight on the featured weapon | dark metal, perforated rack panels, gun racks | olive racks, sage glow |
| Duels (arena deck) | Dramatic: dark room, light pools per pad, the arena feel | low ambient, strong overhead cones per pad | dark floor, team lines olive vs cream (instead of RIVALS purple/gold) | high-contrast lines |
| Exfil hangar + helipad | Outdoor sky edge: wind, runway lights | daylight, amber runway/beacon lights | hazard markings, windsock, tie-downs, fuel/cargo carts | amber + cream |
| Showroom | Clean photo studio (camera set) | soft key + rim, cyclorama | cream cyclorama, plinth | minimal |
| Training | Clinical range, grid tiles (current standard) | cool even light | grid tiles; quadrants A-D each colour-coded within the palette | per-quadrant code |

Check the room analogues in RIVALS before each room (lobby, shop counter, weapon displays, duel pads, training) and copy their
*method*: how much accent, where the light pools, and how props cluster.

## Logically sound (the checklist every room passes)
1. Walkability: every door is open, clear height is at least 10, no invisible blockers, no props blocking paths; Play-mode walk
   at player height with `character_navigation`.
2. Nothing floats or clips: props sit on floors, no z-fighting (decoration 0.03+ bigger than its wall, floor insets 0.04+ proud).
3. Every light has a visible source; no light leaks through walls; shadow-casting light count stays modest.
4. Signs and screens face the way players arrive; wayfinding matches the real room.
5. All hooks from `notes/hooks.md` still work; check_hub1 / check_rooms2 / check_rooms3 / check_training pass; no new console
   errors in Play.

## Order
1. Shop  2. Armory  3. Duels  4. Exfil  5. Gate corridors  6. Hub  7. Training touch-up  8. Showroom  9. Final whole-lobby lap
   (fresh agent) + a sheet of every room side by side to prove they read differently.
Open questions for Edward (don't block on them): ad DevProductId, crate colour, TimesSquare towers, queue-pad Holo beam bug.

## Progress
(append one line per finished room: time, commit, sheet path, saved yes/no)
- Shop: 22:22 fix/polish_shop.lua (warm 3000K pendants + shelf washes, cream walls/counter, wood top + shelving, boards, stock clusters, entry bins, A-frame, mat); checks pass, Play walk OK; sheet out/polish/shop/sheet.jpg (Studio captures blank: ray-render after frames, light not yet judged); saved: no. Notes: notes/polish_shop.md
- Shop round 2 (lead review): real captures via tools/show_studio.ps1; warm Plastic ceiling/beams, boards with item rows + picture lights, centre pendant removed (hid SUPPLY), pools measured +13..44; sheet rebuilt with real before/after/RIVALS; saved: no.
