# Lobby UI revamp: audit + brief (2026-10-21, UI session, Shadow PC)

Edward asked for the tutorial revamp first, then the lobby, using the same process. The tutorial is done (`notes/tutorial_ui/grades.md`).
This page holds the lobby audit of `sheet_before.jpg` (7 states, Studio Play, 1436x786) by three fresh grader subagents.

| # | State | Interactivity | Kid-friendly | Cohesion / not AI |
|---|---|---|---|---|
| 1 | Hub HUD | 6 | 6 | 6 |
| 2 | PLAY | 6 | 6 | 5 |
| 3 | Shop (Featured) | 6 | 5 | 3 |
| 4 | Missions | 6.5 | 5 | 6 |
| 5 | Settings | 7 | 5 | 5 |
| 6 | Codes | 7 | 7 | 4 |
| 7 | Kit (armory) | 6 | 3 | 5 |
| | **Mean** | **6.4** | **5.3** | **4.9** |

Grader size readings come from the downscaled sheet, so their "px" numbers run about 2x too small. The kid grader's phone point is still real: the lobby is one 16:9 Scale canvas, so on an 844-pt-wide phone PLAY is about 110x29 pt, under the 44 pt tap minimum.

## Phase A: fixes inside the current look (no reversals; the UI session can start)

1. **Readability floor:** no text under about 14 px at 1080p (status lines, "0 searching", mission tasks, Kit stats, Codes help).
   Tap targets at least 44 pt on a phone for PLAY, close buttons and buy buttons.
2. **PLAY first** (hub):
   - Make PLAY clearly the biggest button.
   - Make the whole 1v1 / 2v2 / 3v3 card the button, with a full-width PLAY strip at the bottom of each card.
   - Ranked shows a level progress bar ("LV 1 / 50") instead of the bare lock text.
3. **State everywhere:**
   - Shop items you can't afford: dimmed, with the price in red.
   - Robux prices are visibly different from scissors prices (Robux glyph and a different button tone).
   - Missions: a visible empty bar track, and a CLAIM state on done cards.
   - Settings: on/off pill switches with ON / OFF text.
   - Codes: Redeem stays disabled while the box is empty, with an inline result ("+500" / "Invalid code").
4. **Missions:** the weekly row is cut off at the bottom. Fit both rows on screen, or add a scroll fade.
5. **Kit:**
   - Distinct icons for Skin / Wrap / Finisher / Cutscene, each with a lock badge and its unlock level (the ⊗ reads as broken).
   - A solid weapons list.
   - A shorter right panel: name, three stat bars and one big EQUIP / EQUIPPED.
6. **Codes:** a shorter panel, the X docked in its corner, and an empty-state line.

## Phase B: style reversals (NEED EDWARD'S OK; each one undoes a shipped, approved choice)

1. **Close buttons:** replace the RIVALS big red X square, which floats outside every menu, with an X inside the panel corner.
   Graders flagged it in every menu. Edward chose the RIVALS X on 2026-10-16.
2. **Icon set:** replace the glossy 3D-rendered dock / tab icons (Kit gun, clipboard, crate, gear, dog tags; Settings tabs) with one flat
   cream monoline set (RIVALS-inspired 3D renders today).
3. **Shop colours:**
   - Drop the purple item tiles and the neon-lime price buttons for dark plates with a rarity edge and the field-green gradient.
   - Drop the condensed outlined heading face (tabs, "FOUNDER'S BUNDLE", Missions headers) for Montserrat Heavy.
4. **One button system:** field-green gradient for primary, dark plate + hairline for secondary. "» To Pads «" becomes secondary
   (or merges into PLAY: two "go play" buttons confuse kids).
5. **Panels:** the tutorial's language for lobby panels: dark plate, small radius, amber accent = "do this", olive = done.

## Process (same as the tutorial)
- Capture before and after per state, then three fresh graders (interactivity / kid / cohesion) with motion notes and 2x zoom insets.
- Iterate on consensus fixes. Stop when the means plateau, and report honestly to Edward with sheets and grade tables.
