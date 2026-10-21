# Tutorial UI redesign — grade history (2026-10-21)

Each round was graded by **three fresh subagent reviewers** that had not seen earlier rounds, one per angle. Each reviewer scored the 12 tutorial states 0–10 against the before sheet and `redesign_brief.md`.
Means per round:

| Round | Commit | Interactivity / feedback | Kid-friendly | Cohesion / not AI-looking |
|---|---|---|---|---|
| r1 | 07aab35 | 6.3 | 7.4 | 6.8 |
| r2 | 87071f5 | 7.2 | 7.4 | 7.6 |
| r3 | 93acd23 | 7.75 | 7.5 | 7.67 |
| r4 | f719880 | 7.67 | 7.8 | **8.0** |
| r5 | 6f4fb1b | 7.96 | 7.75 | 7.75 |
| r6 | 3919dec | 7.67 | 7.9 | 7.8 |
| r7 | 3591f78 | 7.83 | 7.6 | 7.58 |
| r8 | 05476b5 | **8.1** | 7.7 | **8.04** |

**Final.** After r8, the duplicate Q badge on the finish card was merged into one COVER badge, the only issue all three r8 reviewers raised. The final sheet is `sheet_after_desktop_final.jpg`, and the side-by-side is `before_after_tutorial.jpg`.

## r8 per-state scores

| # | State | Interactivity | Kid | Cohesion |
|---|---|---|---|---|
| 1 | Spot the target | 7.5 | 8 | 8 |
| 2 | Lean out | 8 | 7 | 8 |
| 3 | Get behind it | 8.5 | 8 | 8 |
| 4 | Dash to the crate | 8.5 | 7 | 8 |
| 5 | Run + slide | 8 | 7 | 8.5 |
| 6 | Dash to the wall | 8 | 7 | 8 |
| 7 | Dash, looked at | 8.5 | 8 | 8.5 |
| 8 | Jump over | 8 | 8 | 8 |
| 9 | Aim + shoot | 8 | 7 | 8 |
| 10 | Target down | 8.5 | 9 | 8.5 |
| 11 | Training complete | 8.5 | 8 | 7.5 → duplicate Q fixed after grading |
| 12 | Loading | 7.5 | 8 | 7.5 → same fix |

## Why the loop stopped short of "every state ≥ 8"

From r4 onwards the means moved by about ±0.3 between rounds, with new reviewers each time. Several asks also contradicted each other between rounds, so following one would undo another:

| Topic | Reviewers asked for… | …and later reviewers asked for |
|---|---|---|
| Lean step wording | "LEAN" (r3) | "PEEK" (r4, r5, r6) |
| Loading button | dim it (r3) | keep it full colour (r5) |
| Step count | add "3/7" (r4) | remove it, pips alone (r8) |
| Done ticks | tan (r3) | olive (r7) |

The remaining kid-friendly notes mostly ask for things the run already does in motion, which the stills cannot show:
- On RUN + SLIDE, SHIFT lights first and C only after you're running.
- The key to press next breathes.
- Hitmarkers show on every hit.

Two notes are open design choices for Edward:
- The lean and slide steps have no marker in the world. You lean out of the cover you're already in, and you can slide anywhere.
- On a PC, the aim/fire mouse icons could say RIGHT CLICK / LEFT CLICK instead.

## What changed from before (summary)

- **Objective strip.** The chat card is replaced by one top-centre strip:
  - the key(s) to press, with a short verb under each;
  - 2–4 words of instruction;
  - an "n/7" count and step pips.
- **One colour rule everywhere.**
  - Amber means the key to press next, in the strip and on the object in the world. On a look-at step it waits until you look at the target.
  - Olive means done.
  - Red means the enemy only: his outline, his red corner brackets and his shouts.
  - Cream means a key that isn't active yet, matching the hotbar's key badges.
- **Feedback.**
  - Keys breathe while waiting and squash when pressed.
  - Pressing early shakes the strip and says "LOOK AT IT!".
  - Done turns the keys olive with checks and a chime.
  - On the spot step, his brackets snap shut and the key reads SPOTTED.
  - The kill reads TARGET DOWN, punches in, then holds slightly larger.
- **Instructor.** A radio subtitle in the lower third: a dark-green callsign tag on a solid plate sized to the words. There is no typewriter effect, and the tag, plate and words fade together.
- **Finish.**
  - An off-centre card with the TACTICALS logo.
  - The keys you learned, each with an olive check.
  - An olive PLAY button that counts down "PLAY IN n", then shows three loading dots.
- **Trap found.** The match place's legacy `UIStyleController` turns any warm (amber/orange) UI navy as it is created. The tutorial UI is now tagged `KeepColors`. Any new amber UI in the match place needs the same tag.
