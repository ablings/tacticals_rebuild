# Tutorial UI redesign brief (2026-10-21, main PC lead, from notes/tutorial_ui/ captures)

Edward: the tutorial UI "looks out of place and AI-looking". Goal: it should look like part of the game's HUD, not a chat assistant
on top of it. Keep Tacticals' identity (serious tan / dark green, the TACTICALS logo). RIVALS is inspiration for clarity and feel only.
The loading logo slash/shatter (states 1-3) and the cinematic opening run are good: keep them.

## What reads as "AI" / out of place (by capture state)
1. **The chat card (6-18):** a wide glass card of full sentences plus a floating Builderman portrait and a name pill reads like a support
   chatbot. Instructions sit in the bottom centre, far from the thing you're meant to look at, and over the hotbar zone on 4:3.
2. **An off-palette blue everywhere:** the name pill, the objective pill, [Key] words, the cover SelectionBox, the COVER billboard and the
   gadget zone are all (90-124, 170-200, 255) blue. No other screen uses it, so the tutorial looks like a different game.
3. **Three font families** (Builder Sans, Gotham Black / Medium / Bold) on one screen, none of them the HUD's.
4. **Debug-looking world markers:** a SelectionBox wireframe + flat tint on cover (8) and a plain Neon disc for zones. They look like
   Studio selection, not a game marker.
5. **Typewriter text with a tick sound:** another chatbot cue, and it makes players wait to read.
6. **Wordy lines:** "Look at the glowing crate and press [E] to run to it." The action is buried in a sentence.
7. **ELIMINATED stamp (14-15):** a different red and font from our in-match kill feedback.
8. **The end (17-18):** "Taking you to the lobby..." in the same card, so finishing has no payoff moment.
9. **Offset sizing** on the card (660 px wide): breaks the Scale-only rule, and on 4:3 it collides with the hotbar.

## The redesign
**A. Objective strip, the hero (replaces the card).** Top centre, under the timer/score area, Scale only:
- a big **keycap badge** (our key-badge style; the device's glyph from InputActions: keyboard key, pad button glyph, or for touch a
  ring that pulses ON the real on-screen button), then **2-4 words** in caps ("TAKE COVER", "SLIDE", "VAULT THE WALL"),
  then step pips at the right (●●●○○○);
- in: slide down + fade (0.25 s, Quint out); the keycap breathes (a slow scale pulse) until pressed;
- pressing the key: the keycap squashes (the hotbar kick spring: damper 0.75, ω 20), then it turns green with a check, a short
  satisfying confirm sound, a pip fills, the strip slides up and the next one drops in. That pause is the reward beat (about 0.5 s).
**B. The Instructor speaks as RADIO SUBTITLES, not a card.** Lower third, one line, max ~8 words, no portrait or typewriter:
  a small callsign tag ("INSTRUCTOR" in our dark green / tan) + the line, fading in and out on its own timer. It suits a tactical
  game (comms), and it's optional to read: the strip already says what to do. Keep the world bubble over him ("On the move!") in
  the same font / colours.
**C. In-world markers in our palette.** One "do this" accent colour (amber / warm yellow from the style tokens; green = done, red =
only enemies):
- target cover: a Highlight outline (no SelectionBox, no surface tint) + a floating keycap billboard ON the object ("E") with a small
  distance-scaled chevron; the outline pulses once when it appears;
- zones: a thin ring decal on the floor + soft vertical light, not a Neon disc;
- the enemy keeps the red outline.
**D. One font family**, the HUD's (check 3 Style Tokens). Caps for verbs; no Gotham / Builder mix.
**E. Short lines.** Rewrite TutorialConfig lines as verb + key ("[E] RUN TO THE CRATE"); the subtitle carries the flavour
("Nice. Now move like you mean it."). The Touch variants say "TAP" and point at the button.
**F. Kill moment.** Use our real in-match kill feedback (kill-feed style + hitmarker + damage number) and a short "TARGET DOWN"
banner in the HUD font; keep the grey killcam.
**G. Finish screen (new):** "TRAINING COMPLETE" with the skills learned as ticked icons (Cover / Slide / Vault / Shoot), an XP / reward
line if there is one, and a big PLAY button that shows the countdown to the lobby teleport (auto-continues).
**H. Layout:** Scale only (Kit.toScale), safe areas; nothing overlaps the hotbar, health or touch buttons; check 1920x1080, 4:3
tablet and phone.

## Server side (ask the lead)
TutorialConfig needs, per step: a short `Objective` (2-4 words), the `Key` action name (so the client draws the right device glyph),
and a short `Subtitle`. If the client can't derive them from `waitFor`, the lead adds these fields to the Step payload.

## Grading (as agreed)
Fresh-context subagent graders score every state 0-10 on (a) interactivity / feedback, (b) kid-friendliness (tap size >= 44 px on
phone, few words, icons, obvious next action), (c) cohesion / "AI look" vs our HUD and RIVALS. Iterate until all >= 8, then
before/after sheets + grade tables to Edward. Then the same process for the lobby.
